# 🥚 HATCH OR DIE ☠️

*Hatch a creature during the day. Your creature keeps you alive at night.*

A complete v0.1 MVP for Roblox. It includes a forest map, 3 eggs, 3 creature families with 3 evolution stages and 7 mutations, 3 enemy types plus a boss, a day/night cycle, saving, a coin shop, and Robux products.

## Install (Roblox Studio, about 2 minutes)

1. Open Roblox Studio and create a new **Baseplate** place.
2. Open the command bar: **View → Command Bar**.
3. Open each file below on GitHub, click **Raw**, select all, copy, paste into the command bar, and press **Enter**. Run them **in order** and wait for the ✅ message in the Output window after each one:

   | Step | File | What it builds |
   |---|---|---|
   | 1 | [`installer/01_Map.lua`](installer/01_Map.lua) | Forest map, camp, cave, ruins, cabin, boss arena, hidden grove, Torch tool |
   | 2 | [`installer/02_Shared.lua`](installer/02_Shared.lua) | Configs, networking and models (ReplicatedStorage) |
   | 3 | [`installer/03_Server.lua`](installer/03_Server.lua) | All server systems (ServerScriptService) |
   | 4 | [`installer/04_Client.lua`](installer/04_Client.lua) | HUD, menus and hatch/evolve cinematics (StarterPlayerScripts) |

   You can also paste [`installer/ALL_IN_ONE.lua`](installer/ALL_IN_ONE.lua) once instead of the four parts.
   Optional extras: [`05_ExportUI.lua`](installer/05_ExportUI.lua) (design the UI in StarterGui) and [`06_ExportAssets.lua`](installer/06_ExportAssets.lua) (edit or replace every model and effect).
4. Press **Play** (F5). Your first egg starts hatching right away.
5. To make saving work: **File → Publish to Roblox**, then **Game Settings → Security → Enable Studio Access to API Services**.

Re-running an installer replaces what it built before, so you can update by pasting the new version.
⚠️ Part 1 clears the terrain and rebuilds `Workspace.Map`. It keeps your studded **Baseplate** as the ground (and creates one if it's missing).

## Using your own models (trees, grass, rocks, decor)

Before running Part 1, put your models in **ServerStorage** like this:

```
ServerStorage
└── MapAssets           (Folder)
    ├── Trees           (Folder)  ← your tree models: replace the built-in trees
    ├── Grass           (Folder)  ← grass clumps: scattered over the ground (walk-through)
    ├── Rocks           (Folder)  ← rocks: replace the built-in rocks
    └── Decor           (Folder)  ← flowers, logs, bushes...: scattered around (walk-through)
```

- Every folder is optional. Put several variants in one folder and they're mixed randomly, with random rotation and slightly random size.
- Copies are anchored and placed on the ground automatically. **Scripts inside your models are removed from the copies** (this protects against free-model viruses).
- The counts are at the top of `01_Map.lua` (`TREE_COUNT = 190`, `GRASS_COUNT = 350`, ...). Lower them if your models have lots of parts.
- Then run Part 1 again. The Output window tells you how many of your models it used.

## Customizing everything

| What | How |
|---|---|
| **Numbers** (timings, prices, speeds, damage, drop rates) | `ReplicatedStorage.HatchOrDie.Config`: `GameConfig`, `EggData`, `CreatureData`, `EnemyData`, `ShopData` |
| **UI** | `installer/05_ExportUI.lua`, see [Editing the UI visually](#editing-the-ui-visually) |
| **Pet / enemy / boss / egg models + effects** | `installer/06_ExportAssets.lua`, see below |
| **Map** | Edit `Workspace.Map` directly in Studio, or build your own, see [Your own map](#your-own-map) |

### Models and effects (ReplicatedStorage.HatchOrDieAssets)

Paste `installer/06_ExportAssets.lua` into the command bar. It creates:

```
ReplicatedStorage.HatchOrDieAssets
├── Creatures
│   ├── Sprout / Baby, Teen, Adult      ← one model per evolution stage
│   ├── Ember  / Baby, Teen, Adult
│   └── Shade  / Baby, Teen, Adult
├── Enemies    / Crawler, Hunter, Brute, RotwoodColossus
├── Eggs       / ForestEgg, EmberEgg, VoidEgg
├── Effects                              ← templates in here are USED (empty = built-in effects)
└── EffectExamples                       ← ready-made templates to drag into Effects
```

**Models:** edit the exported ones, or delete one and drop in your own model with the **same name**.
- The model's **front** is its pivot's front, the blue arrow when you use the Pivot tool. Rotate the pivot if your pet walks sideways.
- **Any size works.** The game centers it, welds it, turns off collisions, and puts the nameplate/health bar right above it.
- **One model for all stages:** make `Creatures/Shade` a Model instead of a folder, and it gets scaled per stage.
- **Special versions:** `Creatures/Sprout/Adult_Celestial` or `Enemies/Brute_Elite` override one mutation or variant.
- **Mutation color:** mutations add particles and a glow. To recolor specific parts too, give them a boolean attribute `Tint = true`.
- **Boss:** if your boss has a part named `Core`, it glows when exposed after a Slam. A Hunter part named `Eye` flashes before it shoots.
- **Animations:** rig your model (Motor6Ds) and put `Animation` objects named `Idle`, `Walk`, `Attack` and/or `Ability` inside it. They play automatically.
- **Scripts** inside models are removed from the in-game copies.
- **To edit:** drag a model into Workspace, change it, then drag it back into its folder.

**Effects:** a template is a Part, Model or Attachment holding ParticleEmitters, Sounds, Lights, Trails or Beams.
- Attributes: `Lifetime` (seconds before cleanup, default 2) and `EmitDuration` (how long emitters stay on, default 0.15).
- Sounds inside a template play automatically. That's how you add sound effects.

| Effect name | When it plays |
|---|---|
| `Hit` | An enemy takes damage |
| `Attack_Sprout`, `Attack_Shade` | Melee creature attacks |
| `Projectile_Ember`, `Projectile_Hunter` | Flies from attacker to target (keep particles Enabled; add a Trail) |
| `Ability_Sprout`, `Ability_Ember`, `Ability_Shade` | Creature abilities (Q) |
| `Attack_Crawler`, `Smash_Brute` | Enemy attacks |
| `EnemySpawn`, `EnemyDeath` | Enemy appears / dies |
| `BossSpawn`, `BossSlam`, `BossSpikes`, `BossDeath` | Boss moments (`BossSpikes` plays along the Root Line) |
| `TorchSwing` | Player swings the torch |
| `Feed`, `Evolve`, `Revive`, `Knockout` | Creature moments |

### Your own map

Edit the generated `Workspace.Map` directly. Just don't re-run Part 1 afterwards, because it rebuilds the map.

To build a map from scratch, the game only needs these inside a `Workspace.Map` Model or Folder. Everything else is decoration.

| Name | What it is |
|---|---|
| `CampCenter` | Part at the center of camp. Enemies with no target walk here |
| `BossArenaCenter` | Part where the boss appears |
| `EnemySpawns` | Folder of Parts where enemies spawn at night |
| `EggSpots` | Folder of Parts where eggs appear each day. Give each a string attribute `Area` = `Forest`, `Cave`, `Ruins`, `Cabin` or `Hidden` (rarer eggs in the special areas) |
| `Resources` | Folder of Models named `BerryBush` (with child parts named `Berry`) and `CoinCrystal`, each with a PrimaryPart |
| `ShopKeeper` | Model with a PrimaryPart. The shop prompt appears on it |
| A `SpawnLocation` | Where players spawn |

The ground's top surface should be at **Y = 0**, or change `GameConfig.GroundY`.

## Editing the UI visually

1. Paste [`installer/05_ExportUI.lua`](installer/05_ExportUI.lua) into the command bar. The whole HUD and menu window appear in **StarterGui → HatchOrDieUI** as normal Frames, TextLabels and TextButtons.
2. Design it however you like in Studio: move, resize, recolor, change fonts, add UIGradients, UIStrokes, ImageLabels, icons, or extra decoration.
3. Press Play. The game uses your version automatically.

**The one rule: keep the element names.** The code finds elements by name, wherever they are in the tree, so you can regroup or re-parent them freely. If you delete one, the game hides that feature and prints a warning instead of breaking.

| Area | Names |
|---|---|
| Top banner | `PhaseBanner` (a UIGradient inside is recolored day/night; delete it to keep your own colors), `PhaseTitle`, `PhaseSub`, `Objective` |
| Boss | `BossBar`, `BossName`, `BossFill` (width = boss health) |
| Currencies | `Coins`, `Berries`, `Best` |
| Creature card | `CreatureCard`, `CreatureName`, `CreatureStage`, `CreatureHPFill`, `CreatureHPText`, `CreatureXPFill`, `CreatureXPText`, `EvolveButton` |
| Actions | `ModeFollow`, `ModeAttack`, `ModeDefend` (add a Color3 attribute `SelectedColor` to pick the highlight color), `FeedButton`, `AbilityButton`, `AbilityCooldown` (height = cooldown left) |
| Menu | `MenuEggs`, `MenuCreatures`, `MenuShop`, `EggBadge`, `Incubator`, `IncubatorText`, `IncubatorFill` |
| Messages | `Toasts` (container), `Announcement`, `BigTitle`, `BigSub`, `NightResult`, `ResultTitle`, `ResultBody`, `DeathOverlay` |
| Menu window | `Window`, `WindowTitle`, `WindowClose`, `WindowContent` (menus are drawn inside this) |
| Optional | `ToastTemplate`: design one notification (with a TextLabel named `Label` inside) and every notification copies it |

Tips:
- **"Fill" bars** (`BossFill`, `CreatureHPFill`, ...) get their width set by the game, so put them inside a background frame.
- **Hidden elements:** the game hides some elements until needed, for example the boss bar and the evolve button. `DeathOverlay` and `Window` are exported hidden, so tick **Visible** to edit them.
- **Hover bounce:** buttons get the bounce effect automatically.

## Controls

| Action | PC | Mobile |
|---|---|---|
| Swing torch | Click (with the Torch equipped) | Tap |
| Send creature at an enemy | Click the enemy | Tap the enemy |
| Creature ability | Q | Ability button |
| Feed creature (XP + heal; revives if knocked out) | F | Feed button |
| Follow / Attack / Defend | 1 / 2 / 3 | Command buttons |
| Pick berries, mine crystals, take eggs, open shop | E (hold) | Tap the prompt |

## Monetization setup (optional)

Create the passes and products in the Creator Dashboard, then paste their IDs into
`src/ReplicatedStorage/HatchOrDie/Config/GameConfig.lua` (`Gamepasses` / `Products`) and regenerate the installers. An ID of `0` shows the item as "Coming soon".

## Project layout

```
src/                          Source of truth (Rojo-compatible layout)
  ReplicatedStorage/HatchOrDie/
    Config/                   GameConfig, EggData, CreatureData, EnemyData, ShopData, Rarity
    Shared/                   Net (remotes), Models (procedural models), Signal
  ServerScriptService/HatchOrDie/
    init.server.lua           Bootstrap (Init all services, then Start)
    Services/                 Data, Economy, Egg, Creature, Enemy, Boss, Cycle, World, Combat, Shop
    Modules/                  Effects (VFX), Atmosphere (lighting presets)
  StarterPlayer/StarterPlayerScripts/HatchOrDieClient/
    init.client.lua           Client entry + input
    Hud, Panels, Cinematics, UIKit
installer/                    Generated command-bar installers (+ hand-written 01_Map.lua)
tools/build_installer.py      Regenerates installer/ from src/
tools/sim/                    Headless smoke test (Lune) that plays nights 1-10 + boss
DESIGN.md                     Game design, architecture, economy, roadmap, test plan
```

## Development

- Edit files in `src/`, then run `python3 tools/build_installer.py` to regenerate the installers.
- Smoke test: `lune run tools/sim/run.luau` (uses [Lune](https://github.com/lune-org/lune)). It runs the real installers, server and client code in a simulated engine. It checks the first hatch, the night/day cycle, combat, dawn rewards, evolution, the shop and exploit guards, save/reload with session locking, the Night 10 boss, the wipe reset, the shutdown save, and that every property written exists in the real Roblox API.
- Rojo users can sync `src/` directly (see `default.project.json`) and skip the installers, except the map (Part 1).
