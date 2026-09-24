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
4. Press **Play** (F5). Your first egg starts hatching right away.
5. To make saving work: **File → Publish to Roblox**, then **Game Settings → Security → Enable Studio Access to API Services**.

Re-running an installer replaces what it built before, so you can update by pasting the new version.
⚠️ Part 1 clears the terrain and rebuilds `Workspace.Map`.

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
