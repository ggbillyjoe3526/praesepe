# Project Praesepe: notes for Claude

The design doc is the source of truth: `DESIGN.md` (with the decisions log, open decisions and naming list at the
end). Where the design doc and the code disagree, the design doc wins. `README.md` covers controls, layout and debug
flags. The project instructions hold the full rules; this file holds what is specific to the repo.

## Repo notes
- **Godot 4.7.2-stable**, standard build, typed GDScript, Forward+, Jolt physics at a fixed 60 Hz tick. The version is
  pinned in `project.godot` (`config/features`) and `GODOT_VERSION` in `.github/workflows/ci.yml`; they change
  together, and only with the owner.
- **Cloud sessions:** the SessionStart hook (`.claude/hooks/session-start.mjs`) installs that Godot as `godot` on PATH.
  Export templates are not installed. Cloud machines have no GPU: never judge feel or report frame rates from here.
- **Checks** (CI runs all of them on every pull request): `tools/smoke_test.sh` (import, then `-- --smoke`, fails on
  any script error or `ERROR:` line), `tools/unit_tests.sh` (Gut, tests in `test/unit/`), `gdlint game test tools`
  (settings in `gdlintrc`), `tools/changelog.sh check`.
- **Seeds are law:** gameplay draws only from `Game.rng(<stream>)` (`game/core/game.gd`); presentation uses
  `Game.FX_STREAM`. Never the global `randi()`/`randf()`.
- **Event bus:** systems hear about docking, landing and saving through the `Events` autoload
  (`game/core/events.gd`); every docking and landing goes through `Arrivals.arrive()` (`game/arrival/arrivals.gd`).
- **Saves** go through `SaveFile` (`game/save/save_file.gd`): atomic write, read-back check, one backup, damaged copies
  set aside and never deleted.
- **Changelog:** never edit `CHANGELOG.md` in a feature pull request. Add one new file `changelog.d/<short-name>.md`
  (`changelog.d/README.md`).
- **Git:** branch from the latest `main`, open a pull request; the owner merges. Never push to `main`, never create a
  tag unless the owner asks for a release.
- **Reading big files:** a hook stops whole-file reads over 40 KB; grep, then read with offset and limit.
- **Exit-time leak warnings** (`RID allocations ... leaked at exit`, `ObjectDB instances were leaked`) at the end of
  a headless run are known and are not script errors.
- **Reused code:** some systems come from the owner's other Godot games (katanashotgun, Airsoft-Next); each file says
  where it came from. More is waiting in the project files under `reference/` (its `README.md` says what and when).

## Review agents (`.claude/agents/`)
Before marking a pull request that touches code ready: the `critic` and `qa-review` agents, plus `perf-review` when
it touches flight, rendering, effects, the world or per-frame UI. Their models follow the owner's policy
(2026-10-23): critic on Opus 5.5, qa-review and perf-review on Sonnet 5.5, changelog and triage on Haiku 5.5 (under
100k tokens of context).
