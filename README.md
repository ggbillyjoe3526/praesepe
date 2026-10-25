# Project Praesepe

A casual, first-person space game: buy a ship on a loan, then earn money flying contracts around one solar system.
Working title. Made with Godot 4.7.2, Blender and Claude Code. The design is in [DESIGN.md](DESIGN.md).

**Status:** a tiny solar system to fly around. The game opens on a start menu (Continue, New game, Settings, Quit);
a new game picks the ship (one so far, the Hauler, a greybox with a simple cockpit) and starts docked at a space
station, with a planet and its base, a moon and an asteroid belt to cruise to. Newtonian flight, flight assist, a
velocity marker, a cruise drive, a chase camera, pause and a settings menu. The ship docks at the station, lands at
the base and parks in orbit round the planet or the moon; docking and landing autosave the game, and so does flying,
every 3 minutes, and quitting. Continue puts the ship back exactly where it was saved, out in space too. "Tow me to
base" on the pause screen takes the ship back to its last base. No jobs yet.

## Running it
1. Install [Godot 4.7.2-stable](https://godotengine.org/download/archive/4.7.2-stable/) (the standard build, not
   .NET).
2. Open Godot, choose **Import**, and pick this folder's `project.godot`.
3. Press **F5** to play. The game opens on the title screen: **New game**, choose the ship, and you start docked at
   Halfway Station (G undocks). **Continue** picks up your saved game where it was saved.

## Controls
| Key | Does |
| --- | --- |
| W / S | Speed up / slow down (with flight assist on, let go to hold the speed) |
| A / D | Slide left / right |
| Space / Ctrl (or C) | Slide up / down |
| Mouse | Steer (pitch and yaw); the stick eases back to the centre |
| Q / E | Roll left / right |
| Z | Flight assist on or off |
| X | Full stop (turns flight assist on); in cruise, drops out and stops |
| F | Cruise drive: charges for 2 s, then flies fast and drops out by itself on arriving somewhere. Aimed at a place (its marker is framed and the HUD says "F  Cruise to ..."), it locks onto it and flies there by itself, round any planet in the way; moving the mouse takes the steering back. With nothing aimed at, it goes wherever the nose points. F again drops out |
| O | Enter orbit round the planet or moon you're near, once you're close to its orbit line (fly at the orbit ring on the HUD to get there), and stay there; O again or any thrust key levels the nose out and leaves; X or Z leave at once |
| G | Dock at the station or land at the base when the HUD offers it: the ship flies itself in, and G (or X) on the way takes the controls back; G again undocks or takes off |
| V | Cockpit or chase camera |
| Esc | Pause; the game also pauses when the window loses focus or lets go of the mouse. The pause screen's **Settings** opens the settings menu (Esc goes back); **Tow me to base** (press it twice) puts the ship straight back where it last docked or landed; **Quit to title** and **Quit to desktop** save first (except while cruising or flying itself in or out, when the last save stands). On the start menu, Esc goes back a page |
| F11 or Alt+Enter | Fullscreen or a window |
| Click | Capture the mouse again |
| F3 | Debug overlay: frame rate, draw calls, nodes, seed, speed and true position |

How flying, the cruise drive, orbit and the cameras work, and their tuning values, are in [DESIGN.md](DESIGN.md)
("Flight and camera"); the places in the solar system, docking and landing are in "World".

## Settings
The game starts fullscreen on the main display. Esc, then **Settings**, opens the settings menu:

| Page | Settings |
| --- | --- |
| Display | Window mode (fullscreen, exclusive fullscreen, windowed), display, V-Sync, frame-rate limit |
| Interface | Interface size (the HUD, its text and the menus); place markers and place names, each Always, Near or looked at (close, looked toward, aimed at or cruised to) or Off |
| Comfort | Field of view, camera shake, head bob, reduce motion |
| Controls | Mouse sensitivity, invert mouse, and the list of keys |

Every change shows at once and is saved when the menu closes. A page is one script in `game/ui/settings/` extending
`SettingsPage`, listed in `SettingsMenu.PAGES`.

## Debug flags
Given after `--`, for example `godot --path . -- --seed 1234`.

| Flag | What it does |
| --- | --- |
| `--seed <n>` (or `--seed=<n>`) | A new game starts the world on seed `n` (0 to 4294967295). The same seed gives the same world. Without it, each new game picks a fresh seed, shown on the pause screen. Continue always uses the saved game's seed. |
| `--smoke` | Runs the headless smoke test (it skips the title screen and starts in flight next to the station): an autopilot flies the ship (speeds up, turns, drifts with assist off, stops, pauses and opens each page of the settings menu), checking it and both cameras at every step (the chase camera's lag and lean, and that it never goes through a wall), then cruises to the belt, the station, the moon and the base locked onto each (checking the HUD offers it, the nose follows the course and the dashboard names the place; on the way to the station it moves the stick to release the lock), checking the drive drops out on arriving at each, then climbs from under the planet's orbit line to it (checking O is refused and no orbit prompt shows until it is close) and parks in orbit (checking it holds the line's height, speed and view and goes round slowly), leaves it (checking it levels out and doesn't sink), re-enters it, lands at the base from orbit, takes off, cruises to the station, docks and undocks, checking the ship flies itself in without a bump, then the berth and the autosave each time; then stops, saves in flight (checking it reads back with the ship where it was) and is towed home from the pause screen, checking it is docked at the station and saved there; prints `SMOKE: ok` with the belt's fingerprint and when each arrival came, then quits. It never reads or writes your settings or your saved game (its autosaves go to `smoke_savegame.json`). Use with `--fixed-fps 60` before `--`. |
| `--perf` | Logs draw calls and node counts every 2 s and a summary at exit (the F3 overlay's numbers). |

## Tests
| Command | What it checks |
| --- | --- |
| `tools/smoke_test.sh` | Imports the project and runs `--smoke` headless; fails on any script error, `ERROR:` line or failed flight, cruise, orbit, docking or landing check, or if a second run on the same seed builds another belt or ends anywhere else. |
| `tools/unit_tests.sh` | The Gut unit tests in `test/unit/`. |
| `gdlint game test tools` | Code style ([gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 4.5.0). |
| `tools/changelog.sh check` | The changelog notes in `changelog.d/`. |
| `python3 tools/wiki.py check` | The player wiki in `docs/wiki/`: links, pictures, the sidebar, and every place in the game mentioned on a page. `python3 tools/wiki.py build build/wiki` previews the published pages. |

CI runs all five on every pull request (the wiki check in the Wiki workflow, which also publishes the wiki on every merge to `main`). Set `GODOT=/path/to/godot` if `godot` isn't on your PATH.

## Layout
| Path | What lives there |
| --- | --- |
| `game/core/` | The `Game` autoload (world seed, random streams, in-game clock), the `Events` autoload (the event bus: docking, landing, saving), how a game starts (new or continued) and launch options. |
| `game/flight/` | The flight model, the cruise drive, orbit, the ship's input, the pilot's controls and their tuning. |
| `game/arrival/` | Docking and landing: ports, the way in (the ship flying itself to its berth), the one arrival function and their tuning. |
| `game/ship/` | The greybox ship, its cockpit and its tuning, and the starter ships a new game offers. |
| `game/camera/` | The cockpit and chase cameras, camera shake and their tuning. |
| `game/system/` | The solar system scene: the planet, its base and landing pad, the moon, the station and its docking bay, the seeded asteroid belt and their tuning. |
| `game/world/` | The floating origin, space dust, the starfield sky, buoys and the orbit line round a planet. |
| `game/hud/` | The flight HUD, velocity marker, the markers on each place (with the settings for when their names and diamonds show), the orbit insertion marker, the docking, landing and orbit prompts and the cockpit's dashboard screen. |
| `game/ui/` | The title screen (the first scene) and its start menu, the pause screen and its tow home, the fullscreen keys and focus (`WindowWatch`) and, in `settings/`, the settings menu and its pages. |
| `game/save/` | Crash-safe save files, the saved game and its autosave, the player's settings (the `Settings` autoload) and how the display settings reach the window (`DisplayApply`). |
| `game/main/` | The game scene, opened from the title screen. |
| `game/debug/` | The smoke test autopilot and the F3 overlay. |
| `test/unit/` | Unit tests. |
| `tools/` | Test, changelog and wiki scripts. |
| `addons/gut/` | The Gut test framework (tests only, never shipped). |
| `docs/wiki/` | The player wiki, one page per file, published to the [GitHub wiki](https://github.com/ggbillyjoe3526/project-praesepe/wiki) on every merge to `main`. Its `README.md` has the conventions. |
| `changelog.d/` | One changelog note per pull request, gathered into `CHANGELOG.md` at release. |

Saves (`savegame.json`, written on every docking and landing) and settings (`settings.json`) go to the user folder `ProjectPraesepe` (on Windows, `%APPDATA%\Godot\app_userdata\ProjectPraesepe`).
