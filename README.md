# Mapleview FIFA Soccer (100% Script-Built Roblox Game)

A complete, script-driven Roblox football/soccer game featuring realistic Magnus-effect ball physics, fluid dribbling, curving free kicks with live trajectory preview, pinpoint through-balls, goalkeeper diving saves, procedural stadium & floodlight construction, custom kits, unlockable celebrations, Dream Squad formations, 5v5 & 11v11 competitive modes, global leaderboards, and a championship trophy ceremony.

## Project Structure

- `default.project.json` — Rojo project mapping Roblox services to `src/`.
- `src/ReplicatedStorage/Shared/`
  - `Config.luau` — Pitch dimensions (5v5 & 11v11), ball physics, kick powers, stamina, teams, and coin/ELO rewards.
  - `Catalog.luau` — Unlockable custom kits, goal celebrations, and Dream Squad formations.
  - `Network.luau` — Auto-provisions all `RemoteEvent`s and `RemoteFunction`s at runtime.
  - `BallPhysics.luau` — Shared Magnus-effect curve, aerodynamic drag, grass friction, bounce, and trajectory prediction.
- `src/ServerScriptService/`
  - `StadiumBuilder.luau` — Procedurally builds the mowed-turf pitch, white field markings, goals with nets, corner flags, tiered stands, floodlights, night-match atmosphere, and team spawns.
  - `DataService.luau` — `DataStoreService` player profiles + `OrderedDataStore` Global Leaderboards (with safe Studio fallback).
  - `KitAndCelebrationService.luau` — Applies custom kits & club nameplates to characters and executes procedural goal celebrations.
  - `BallManager.luau` — Server-authoritative ball simulation, dribbling tether, kicks, through-balls, tackles, GK saves, goal detection, and set pieces.
  - `MatchManager.server.luau` — Team balancing, 5v5 / 11v11 mode voting, match clock, half-time, and Championship Trophy ceremony.
- `src/StarterPlayer/StarterPlayerScripts/`
  - `SoccerController.client.luau` — Dribbling, sprint/stamina, hold-to-charge curving shots with live trajectory preview, through-balls, GK dives, and tackles.
  - `HUDController.client.luau` — Broadcast scoreboard, power/curve/stamina meters, goal banner, and Dream Squad / Shop / Leaderboard modal.
  - `VFXController.client.luau` — Ball speed/curve trails, goal confetti, and trophy ceremony fireworks.

## Controls

| Action | Key / Input |
| :--- | :--- |
| **Shoot / Curving Free Kick** | Hold `Left Click` or `E` (release to kick) |
| **Add Curve / Spin** | Hold `A` or `D` while charging a kick |
| **Pinpoint Through-Ball** | Hold `F` (auto-leads nearest forward teammate) |
| **Lob / Cross** | Hold `Right Click` or `Q` |
| **Slide Tackle / Steal** | `R` |
| **Goalkeeper Dive** | `Space` (while inside penalty box) |
| **Sprint** | `Left Shift` |
| **Trigger Celebration** | `G` |
| **Club, Shop & Leaderboards** | `Tab` |

## Setup in Roblox Studio

### Option 1: Rojo (Recommended)
1. Install [Rojo](https://rojo.space/) and run `rojo serve` in this directory.
2. Connect from the Rojo plugin in Roblox Studio and press **Play**.
3. *(Optional)* Enable **Studio Access to API Services** in Game Settings → Security to test `DataStoreService` persistence.

### Option 2: Manual Import
Create the matching `ModuleScript`, `Script`, and `LocalScript` instances in `ReplicatedStorage/Shared`, `ServerScriptService`, and `StarterPlayer/StarterPlayerScripts` and paste each `.luau` file's contents. No external `.rbxm` models or assets are required—the entire stadium, ball, and UI are generated from scripts at runtime.
