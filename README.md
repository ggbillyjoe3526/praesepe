# Project Praesepe

A casual, first-person space game: buy a ship on a loan, then earn money flying contracts around one solar system.
Working title. Made with Godot 4.7.2, Blender and Claude Code. The design is in [DESIGN.md](DESIGN.md).

**Status:** project skeleton. It boots to a placeholder screen; there is nothing to fly yet.

## Running it
1. Install [Godot 4.7.2-stable](https://godotengine.org/download/archive/4.7.2-stable/) (the standard build, not
   .NET).
2. Open Godot, choose **Import**, and pick this folder's `project.godot`.
3. Press **F5** to play.

## Controls
None yet. Flight controls arrive with the first playable.

## Debug flags
Given after `--`, for example `godot --path . -- --seed 1234`.

| Flag | What it does |
| --- | --- |
| `--seed <n>` (or `--seed=<n>`) | Starts the world on seed `n` (0 to 4294967295). The same seed gives the same world. Without it, each launch picks a fresh seed, shown on screen. |
| `--smoke` | Runs the headless smoke test: plays a few seconds, prints `SMOKE: ok`, then quits. |

## Tests
| Command | What it checks |
| --- | --- |
| `tools/smoke_test.sh` | Imports the project and runs `--smoke` headless; fails on any script error. |
| `tools/unit_tests.sh` | The Gut unit tests in `test/unit/`. |
| `gdlint game test tools` | Code style ([gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 4.5.0). |
| `tools/changelog.sh check` | The changelog notes in `changelog.d/`. |

CI runs all four on every pull request. Set `GODOT=/path/to/godot` if `godot` isn't on your PATH.

## Layout
| Path | What lives there |
| --- | --- |
| `game/core/` | The `Game` autoload (world seed, random streams, in-game clock) and launch options. |
| `game/save/` | Crash-safe save files. |
| `game/main/` | The first scene. |
| `game/debug/` | The smoke test runner. |
| `test/unit/` | Unit tests. |
| `tools/` | Test and changelog scripts. |
| `addons/gut/` | The Gut test framework (tests only, never shipped). |
| `changelog.d/` | One changelog note per pull request, gathered into `CHANGELOG.md` at release. |

Saves and settings go to the user folder `ProjectPraesepe` (on Windows, `%APPDATA%\Godot\app_userdata\ProjectPraesepe`).
