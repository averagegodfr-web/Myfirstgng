# HATCH OR DIE: Design & Architecture (v0.1 MVP)

Every system in this document is implemented in `src/`. Tuning numbers live in `Config/` so they can change without code changes.

---

## 1. Final game design: the core loop

```
SPAWN → first egg hatches (~10s) → DAY: explore, pick berries, mine crystals, find eggs, feed
      → NIGHT: enemies swarm the camp, creature fights beside you (Torch + commands + ability)
      → DAWN: coins, XP, berries, eggs → EVOLVE when ready → next night is harder → repeat
```

**Two questions drive everything:** *"What will my egg become?"* (hatch rolls, mutations, hidden next forms) and *"Can my creature survive the next night?"* (scaling nights, boss milestones, wipe resets).

**Run structure (decision):** each server shares one night counter. If **every** player is down at the same time during a night, the run resets to Night 1. Creatures, eggs and coins are always kept, so a wipe costs you the run but never your collection. A player who dies at night sits out until dawn and gets no rewards for that night. `HighestNight` is saved per player and shown on the leaderboard.

**A night ends** when its timer runs out *or* when the whole wave (and the boss) is dead. Fighting well makes the night shorter.

## 2. MVP scope (v0.1): what exists

| Area | Shipped |
|---|---|
| Map | 1 forest: Camp, Cabin, Glowcap Cave, Old Ruins, Boss Arena, Hidden Grove, 190 trees, 20 berry bushes, 13 coin crystals, 18 egg spots |
| Eggs | Forest (Common), Ember (Rare), Void (Legendary) |
| Creatures | 3 families (Sprout / Ember / Shade) × 3 stages, 7 mutations, 6 cosmetic auras = 72 discoverable forms |
| Enemies | Crawler (melee swarm), Hunter (telegraphed ranged), Brute (telegraphed AoE smash), plus Elite and Nightmare variants |
| Boss | Rotwood Colossus (nights 10, 20, 25, 30...) |
| Nights | Formula-driven and endless; milestones at 5, 10, 25, 50, 100; random Blood Moons |
| Systems | Egg hatching, following, auto-combat + commands, day/night, spawning, evolution, rewards, coins, saving, shop, gamepasses/products, leaderstats, server announcements |

Not in v0.1 (on purpose): trading, multiple worlds, global cross-server announcements, player-chosen evolution branches, quests/daily rewards, pets beyond one equipped creature.

## 3. Roblox hierarchy

```
ReplicatedStorage
  HatchOrDie (Folder)                 ← attributes: Phase, Night, PhaseEndsAt, Modifier
    Config/ GameConfig, EggData, CreatureData, EnemyData, ShopData, Rarity
    Shared/ Net, Models, Signal
    Remotes/ (created at runtime by Net)
ServerScriptService
  HatchOrDie (Script: bootstrap)
    Registry (ModuleScript)
    Services/ DataService, EconomyService, EggService, CreatureService, EnemyService,
              BossService, CycleService, WorldService, CombatService, ShopService
    Modules/  Effects, Atmosphere
StarterPlayer/StarterPlayerScripts
  HatchOrDieClient (LocalScript)
    UIKit, Hud, Panels, Cinematics
StarterPack
  Torch (Tool)
Workspace
  Map/ Camp, Cabin, Cave, Ruins, BossArena, HiddenGrove, Forest, Paths, Bounds,
       Resources (BerryBush, CoinCrystal), EggSpots, EnemySpawns
  Enemies/, Creatures/, WorldEggs/, Effects/   (runtime)
Lighting: HOD_Atmosphere, HOD_Color, HOD_Bloom   (runtime)
```

## 4. System architecture

The bootstrap `require`s every service into a shared `Registry` (this avoids circular requires), calls every `Init()` (wire signals), then every `Start()` (begin work).

| Service | Responsibility | Remotes it owns | Reads / writes |
|---|---|---|---|
| DataService | Load/save profiles, session locking, migrations, autosave, BindToClose, batched client sync, leaderstats | ClientReady, SyncData | whole profile |
| EconomyService | The only place coins and berries change | none | Coins, Berries |
| EggService | Egg inventory, incubator, **server-side hatch roll**, starter egg, auto-hatch | RequestHatch, HatchResult | Eggs, Incubator, Creatures, Discovered |
| CreatureService | Records, equip, world model, follow AI, targeting, attacks, ability, feed, KO/revive, evolve, release, lock, aura | Equip/Feed/SetCommand/SetTarget/UseAbility/Evolve/Release/ToggleLock/EquipAura, Evolved | Creatures, Equipped |
| EnemyService | Data-driven spawn, AI loop, telegraphed attacks, damage, death rewards | none | Stats.Kills (+coins/XP via Economy/Creature) |
| BossService | Colossus patterns, phases, summons, boss bar, rewards | BossBar, Effect | BossesDefeated |
| CycleService | Day/night state machine, lighting, spawner, milestones, dawn rewards, deaths, wipe/reset | NightResult | HighestNight, Stats |
| WorldService | Berry bushes, crystals, daily world eggs, shop NPC | OpenPanel | via Economy/Egg |
| CombatService | Torch hits (server range + facing check) | none (Tool.Activated) | none |
| ShopService | Coin shop, gamepass ownership, ProcessReceipt with receipt de-dupe | BuyItem | Auras, Receipts |

The client (`HatchOrDieClient`) only renders UI, plays cinematics and sends intents. It reads phase state from attributes and creature HP/mode from player attributes, and receives the profile through `SyncData`.

## 5. Data model (saved profile)

```lua
{
  Version = 1,                 -- migrations in DataService.MIGRATIONS
  Coins = 0, Berries = 3,
  Eggs = { { Id = "E…", EggId = "ForestEgg", At = os.time() } },
  Incubator = { EggId, StartedAt, EndsAt } | nil,   -- unix time; survives rejoin
  Creatures = { <CreatureRecord> },
  Equipped = "C…" | nil,
  Auras = { Fire = true },
  Discovered = { ["Sprout:2:Storm"] = true },
  HighestNight = 0, BossesDefeated = 0,
  Stats = { Kills, Hatches, Mutations, Evolutions, NightsSurvived },
  Settings = { Music = true },
  Receipts = { "purchaseId", … },  -- last 50, prevents double-granting
  CreatedAt = os.time(),
}
```
Stored as `{ Data = profile, Lock = { JobId, Time } }` under key `P_<userId>`.

- **Duplicate sessions:** a lock younger than 330s blocks the load. The server retries 6 times, then takes over. A save that finds another server's live lock is skipped, so a stale server can never overwrite newer data.
- **Missing fields:** `reconcile()` fills anything new from the default profile. **Schema changes:** add a `MIGRATIONS[n]` step.
- **Failures:** if the load still fails after retries, the player is kicked with a "your progress is safe" message (this never overwrites data). Unpublished places or places without Studio API access run with saving off and show a warning toast.
- **Shutdown:** `BindToClose` saves everyone in parallel (25s budget). Autosave runs every 120s.

## 6. Egg + creature data

```lua
-- EggData
ForestEgg = { Rarity = "Common", HatchTime = 20, Price = 75,  MutationChance = 0.02,
              Pool = { {Family="Sprout",Weight=70}, {Family="Ember",Weight=25}, {Family="Shade",Weight=5} } }
EmberEgg  = { Rarity = "Rare",   HatchTime = 40, Price = 350, MutationChance = 0.06, Pool = Ember 60 / Sprout 25 / Shade 15 }
VoidEgg   = { Rarity = "Legendary", HatchTime = 75, Price = 2000, MutationChance = 0.18, Pool = Shade 60 / Ember 30 / Sprout 10 }

-- CreatureRecord
{ Id = "C…", Family = "Sprout", Stage = 1, Mutation = nil, XP = 0, StageNights = 0,
  Nights = 0, Kills = 0, Aura = nil, Locked = false, At = os.time() }
```

- **Stats are derived, never stored:** `base × StageMult(1 / 1.9 / 3.3) × (1 + mutation bonus 10–20%)`.
- **Evolution:** Baby→Teen needs 100 XP and 1 night survived. Teen→Adult needs 450 XP and 3 nights. The player presses Evolve (a deliberate "event" moment). Each evolution has a 5% chance to **mutate** if the creature isn't already mutated.
- **Mutation weights:** Storm 30, Inferno 28, Crystal 20, Plague 14, Void 6, Rainbow 1.6, Celestial 0.4 (about 1 in 1250 Void-Egg hatches).
- **Discovery:** the next evolution's name shows as `???` until you've discovered it. The collection counter shows `Discovered X / 72`.
- **Duplicates** are fine: every hatch is a unique instance (different mutation rolls, future trading). Release gives coins by rarity × stage. Locked creatures can't be released.
- **Odds are shown in-game** for every egg (required by Roblox for random items bought with Robux).

## 7. Day/night system

| Phase | Length | What happens |
|---|---|---|
| Day 1 | 40s | First hatch completes, bushes near camp, world eggs spawn |
| Day | 50s | Explore / gather / feed / evolve. Timer turns red under 12s |
| Night | 85s (150s boss nights) | Enemies spawn from 14 edge points in groups over 60% of the night |
| Dawn | instant | Rewards, dead players respawn, creatures fully heal |

The clock moves continuously (7.5 → 17.8 by day, sunset → 4.5 by night). Lighting presets: Day, Night, BloodMoon, Nightmare, Apocalypse. The HUD shows `☀️ DAY 7 / PREPARE • 0:42` → `🌙 NIGHT 7 / SURVIVE • 1:10`, plus a big center title at each change.

## 8. Combat (v1)

**Semi-automatic, which matches the game's simplicity.** The creature auto-targets the nearest enemy within 40 studs of its owner. The player steers it:
- **Follow** (no attacking) / **Attack** (default) / **Defend** (only enemies within 16 studs of you)
- **Tap an enemy** to focus it (switches to Attack).
- **Ability (Q):** Sprout *Thorn Burst* (AoE ×2.5 + heals you), Ember *Fire Nova* (AoE ×2.2), Shade *Shadow Pounce* (teleport, single target ×4.5).
- **Feed (F):** +20 XP and 35% heal. Feeding a knocked-out creature revives it at 40%. KO otherwise recovers after 25s.
- **Torch:** 12 damage (+8% per night) in a 10-stud frontal arc, 0.45s cooldown. It's also your light at night.

Hit detection is a server-side distance/facing check (no client-reported hits). Enemies and creatures are anchored and moved by CFrame at ground height (no physics, no pathfinding), which keeps things cheap on mobile.

## 9. Enemies

| Enemy | HP | Dmg | Speed | Behavior | From night |
|---|---|---|---|---|---|
| Crawler | 38 | 7 | 17 | Fast melee swarm | 1 |
| Hunter | 34 | 9 | 13 | Keeps 30 studs away; eye flashes white 0.8s, then fires a **dodgeable** projectile | 3 |
| Brute | 240 | 26 | 8.5 | Red circle telegraph 1.0s → AoE smash | 5 |

Variants multiply one model: **Elite** (×2.3 HP, ×1.5 dmg, gold, ×3 rewards) from night 6; **Nightmare** (×3.2 HP, red, ×5 rewards) from night 50. Adding an enemy means one `EnemyData` entry plus a shape in `Models.BuildEnemy`.

**Night formula:** HP × (1 + 0.16(n−1)), damage × (1 + 0.09(n−1)), count = (6 + 2.5n) × (1 + 0.45 per extra player), max alive = min(10 + 2n, 40). Milestones: Night 5 Alpha Brute; Night 10/20/25/30... boss; 50 Nightmare (permanent red fog + Nightmare variants); 100 Apocalypse (orange sky, ×2 rewards); random 20% **Blood Moon** from night 4 (+30% enemies, ×1.5 rewards).

## 10. First boss: the Rotwood Colossus

- Awakens 6s into night 10 in the stone circle, with a server-wide announcement and camera shake. HP 3200 × (1 + 0.6 per extra player) × night scaling.
- **Slam:** red circle (1.3s) → AoE + knockback → **its Core glows yellow for 3s and takes ×2.5 damage.** This is the "weakness window" that teaches players to dodge, then punish.
- **Root Line:** red lane toward a ranged target (1.1s) → wooden spikes erupt. It punishes players who stand at range.
- **Summons** a Crawler brood at 70% and 40%.
- **Enrage** under 50%: faster movement, shorter telegraphs, head catches fire, eyes turn red.
- **Rewards** (everyone in the server): 300 coins, a **Void Egg**, +150 creature XP, BossesDefeated +1. The night ends 12s after the kill. If the Colossus survives until dawn it retreats with no reward.

## 11. Economy (one currency: Coins)

| Source | Amount |
|---|---|
| Survive night n | 25 + 12n coins (×1.5 Blood Moon), +45+10n creature XP, +2 berries |
| Kills | Crawler 3 / Hunter 5 / Brute 15 (+10% per night, ×3 Elite) |
| Coin crystal | 8–15 (60s regrow) |
| Boss | 300 + Void Egg |
| Egg rewards | Forest Egg on nights 3, 6, 9…; Ember Egg on night 5 and every 7th |

Night 1 ≈ 55 coins total, Night 5 ≈ 140, Night 10 ≈ 400 + boss. **Sinks:** eggs (75 / 350 / 2000), berries (30 for 5), cosmetic auras (600–1800). Ember Egg ≈ night 4, Void Egg ≈ first boss (or ~night 13 by saving). Late game stays balanced because every reward scales linearly with night while the best sinks are cosmetic (auras) and collection (Void Eggs hunting 0.4% Celestials).

## 12. UI

- **HUD:** phase banner + timer (top), objective line, boss bar, currencies (top-left: 🪙 🍓 🏆), creature card (left: name in rarity color, stage, HP bar, XP/nights bar, EVOLVE button), commands + Feed + round Ability button with cooldown sweep (bottom-right), menu bar (🥚 Eggs with badge / 🐲 Creatures / 🛒 Shop), incubator progress bar, toasts (top-right), announcements, big phase titles, night-result card, death overlay.
- **Eggs panel:** a card per egg type with spinning 3D egg, count, hatch time, **odds**, and a Hatch/Buy button.
- **Creatures panel:** collection grid sorted equipped → rarity → stage, and a detail pane with a spinning model, stats, ability, next form (`???` until discovered), Equip / Evolve / Lock / Release, and aura picker.
- **Shop:** tabs Eggs / Boosts / Cosmetics / Robux. Unaffordable items are greyed out. No pop-ups.
- **Cinematics:** hatch reveal (egg shakes 3× (5× for Epic+) → "SOMETHING RARE..." rays → white flash → spinning creature + rarity + mutation + NEW DISCOVERY) and evolution reveal (pulsing flashes → new form).

## 13. Monetization (convenience, cosmetics, prestige, never raw power)

| Product | Type | Suggested price | Why it's fair |
|---|---|---|---|
| VIP | Gamepass | 299 R$ | Tag, Golden Aura (cosmetic), +1 Forest Egg per dawn (≈ saves 75 coins/night) |
| 2× Hatch Speed | Gamepass | 99 R$ | Time only |
| Auto Hatch | Gamepass | 199 R$ | Convenience |
| +25 Creature Slots | Gamepass | 79 R$ | Collection |
| Ember Egg Pack | Dev product | 149 R$ | 3 Ember Eggs + 200 coins; all obtainable free |
| Galaxy Aura | Dev product | 129 R$ | Cosmetic only |

Mutations can't be bought directly (they can only be rolled), and their stat bonus is capped at +20%. These are starting price points to A/B test; nothing here guarantees revenue.

## 14. Development roadmap

| Phase | Tasks | Status |
|---|---|---|
| 0 Foundation | Architecture, Registry bootstrap, Net remotes, DataService (locking, migration) | ✅ P0 |
| 1 Core loop | Day/night, starter egg, hatch, follow, Crawler, survival, wipe | ✅ P0 |
| 2 Progression | Evolution, dawn rewards, inventory, saving, 3 eggs, world eggs | ✅ P0 |
| 3 Combat | Creature attacks, commands, abilities, Torch, Hunter/Brute, variants, boss | ✅ P0 |
| 4 UI | HUD, Eggs/Creatures/Shop panels, cinematics | ✅ P0 |
| 5 Polish | Real SFX/music ids (Easy), creature animations (Medium), mobile layout pass (Medium), better map art (Medium) | P1 |
| 6 Monetization | Create passes/products and paste ids (Easy); global leaderboard via OrderedDataStore (Easy) | P1 |
| 7 Testing | Studio multiplayer test (4 players), mobile device test, exploit pass, perf on low-end | P0 before launch |
| Post-launch | Daily rewards (P2), player-chosen evolution branches (P2), cross-server discovery feed via MessagingService (P2), trading (P3), new worlds (P3) | later |

## 15. Test plan

**Automated:** `lune run tools/sim/run.luau` checks every item below that's marked 🤖.

| System | Checks |
|---|---|
| Install | 🤖 all 4 installers run; hierarchy correct; installed source matches `src/`; every property written exists in the Roblox API |
| Eggs | 🤖 starter egg auto-incubates; hatches ≤12s; auto-equips; reveal sent · 🤖 bought egg lands in inventory · 🤖 `RequestHatch(nil)` ignored · manual: incubate, leave, rejoin after timer → hatches on join |
| Creatures | 🤖 feed adds XP, uses berry · 🤖 evolve only when requirements met; reveal sent · manual: KO + feed revive; can't swap at night; release blocked if locked/equipped |
| Night | 🤖 night falls on timer; enemies spawn; kills counted; dawn rewards; HighestNight saved · 🤖 all players down → Night 1 · manual: Blood Moon visuals |
| Boss | 🤖 spawns night 10, bar reaches client, dies, rewards · manual: telegraphs readable, core window noticeable |
| Economy / exploits | 🤖 server-side prices; fake item tables, bad ids, bogus commands, unowned aura all ignored |
| Saving | 🤖 save on leave releases lock; rejoin restores progress and takes lock; BindToClose saves · manual: two Studio servers with the same account (lock) |
| Purchases | manual (published place): each pass grants its attribute; dev product grants once even if ProcessReceipt runs twice (receipt de-dupe) |
| Performance | manual: 4 players, night 20+, 40 enemies alive on a mobile device; watch server heartbeat in the Developer Console |

## 16. Build these exact things next

The MVP is built. Next steps in order:

1. **Install and play solo in Studio.** Tune `GameConfig` timings if nights feel long or short.
2. **Local server test with 2–4 players** (Test → Start with 4 players). Watch the wipe rule and scaling.
3. **Add audio:** paste sound IDs into `GameConfig.Music` / `Sounds` (hatch, evolve, boss roar, night sting).
4. **Publish, then create the passes/products** and paste their IDs into `GameConfig`.
5. **Mobile pass:** check button sizes on a phone emulator (Test → Device).
6. **Thumbnail + icon:** scared player (left), cracking glowing egg (center), huge mutated creature (right), dark forest and fire. Big text "HATCH OR DIE" and "NIGHT 100".
7. **Soft launch, watch D1 retention and night reached,** then build a daily reward and a global Highest Night leaderboard (OrderedDataStore).

### Viral moments built in
0.4% Celestial hatch with a server-wide announcement · "SOMETHING RARE..." pre-reveal · mutation during evolution · boss awakening + enrage · Blood Moon · the whole server wiping on night 9 · Night 50/100 world transformations.

### Performance notes
Enemies are capped at 40 alive, use CFrame movement (no Humanoids/pathfinding), and every model is a single anchored root with welded parts (one replicated CFrame per model). Damage numbers and effects clean themselves up via Debris. Nothing runs a tight client loop except UI tweening.
