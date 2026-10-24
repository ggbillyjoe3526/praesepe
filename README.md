# Project Praesepe

A casual, first-person space game: buy a ship on a loan, then earn money flying contracts around one solar system.
Working title. Made with Godot 4.7.2, Blender and Claude Code. The design is in [DESIGN.md](DESIGN.md).

**Status:** a tiny solar system to fly around. A greybox ship with a simple cockpit starts next to a space station,
with a planet and its base, a moon and an asteroid belt to cruise to. Newtonian flight, flight assist, a velocity
marker, a cruise drive, a chase camera, comfort settings and pause. No docking or jobs yet.

## Running it
1. Install [Godot 4.7.2-stable](https://godotengine.org/download/archive/4.7.2-stable/) (the standard build, not
   .NET).
2. Open Godot, choose **Import**, and pick this folder's `project.godot`.
3. Press **F5** to play.

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
| F | Cruise drive: charges for 2 s, then flies fast wherever the nose points and drops out by itself on arriving somewhere. F again drops out |
| V | Cockpit or chase camera |
| Esc | Pause; the game also pauses when the window loses focus or lets go of the mouse. The pause screen holds the comfort settings: field of view, camera shake, head bob, reduce motion |
| Click | Capture the mouse again |
| F3 | Debug overlay: frame rate, draw calls, nodes, seed, speed and true position |

How flying, the cruise drive and the cameras work, and their tuning values, are in [DESIGN.md](DESIGN.md) ("Flight and
camera"); the places in the solar system are in "World".

## Debug flags
Given after `--`, for example `godot --path . -- --seed 1234`.

| Flag | What it does |
| --- | --- |
| `--seed <n>` (or `--seed=<n>`) | Starts the world on seed `n` (0 to 4294967295). The same seed gives the same world. Without it, each launch picks a fresh seed, shown on screen. |
| `--smoke` | Runs the headless smoke test: an autopilot flies the ship (speeds up, turns, drifts with assist off, stops, pauses), checking it and both cameras at every step (the chase camera's lag and lean, and that it never goes through a wall), then cruises to the belt, the station, the moon and the base, checking the drive drops out on arriving at each, prints `SMOKE: ok` with the belt's fingerprint, then quits. It never reads or writes your settings. Use with `--fixed-fps 60` before `--`. |
| `--perf` | Logs draw calls and node counts every 2 s and a summary at exit (the F3 overlay's numbers). |

## Tests
| Command | What it checks |
| --- | --- |
| `tools/smoke_test.sh` | Imports the project and runs `--smoke` headless; fails on any script error, `ERROR:` line or failed flight or cruise check, or if a second run on the same seed builds another belt or ends anywhere else. |
| `tools/unit_tests.sh` | The Gut unit tests in `test/unit/`. |
| `gdlint game test tools` | Code style ([gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 4.5.0). |
| `tools/changelog.sh check` | The changelog notes in `changelog.d/`. |

CI runs all four on every pull request. Set `GODOT=/path/to/godot` if `godot` isn't on your PATH.

## Layout
| Path | What lives there |
| --- | --- |
| `game/core/` | The `Game` autoload (world seed, random streams, in-game clock) and launch options. |
| `game/flight/` | The flight model, the cruise drive, the ship's input, the pilot's controls and their tuning. |
| `game/ship/` | The greybox ship, its cockpit and its tuning. |
| `game/camera/` | The cockpit and chase cameras, camera shake and their tuning. |
| `game/system/` | The solar system scene: the planet, its base, the moon, the station, the seeded asteroid belt and their tuning. |
| `game/world/` | The floating origin, space dust, the starfield sky and buoys. |
| `game/hud/` | The flight HUD, velocity marker, the markers on each place and the cockpit's dashboard screen. |
| `game/ui/` | The pause screen and its comfort settings. |
| `game/save/` | Crash-safe save files and the player's settings (the `Settings` autoload). |
| `game/main/` | The first scene. |
| `game/debug/` | The smoke test autopilot and the F3 overlay. |
| `test/unit/` | Unit tests. |
| `tools/` | Test and changelog scripts. |
| `addons/gut/` | The Gut test framework (tests only, never shipped). |
| `changelog.d/` | One changelog note per pull request, gathered into `CHANGELOG.md` at release. |

Saves and settings (`settings.json`) go to the user folder `ProjectPraesepe` (on Windows, `%APPDATA%\Godot\app_userdata\ProjectPraesepe`).
