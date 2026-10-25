# Releasing

How a version of Project Praesepe reaches players. Only the owner releases; Claude never creates a tag.

## What a release gives players
Each release on the [Releases page](https://github.com/ggbillyjoe3526/project-praesepe/releases) has:
- `ProjectPraesepe-v0.1-dev.1-Windows-Setup.exe`: the installer. It installs for the current player only (no
  administrator prompt), adds a Start menu shortcut and optionally a desktop one, and has an uninstaller. Installing a
  newer version over an older one updates it in place.
- `ProjectPraesepe-v0.1-dev.1-Windows-Portable.zip`: the same game, to unzip anywhere and run without installing.
- Release notes: that version's section of `CHANGELOG.md`, then how to install.

Saved games live in `%APPDATA%\ProjectPraesepe`, never in the install folder, so updating or uninstalling never
touches them. Dev and Beta versions are marked as pre-releases.

## Version names
Versions are named the way players see them, and each name has one tag (William's choice, DESIGN.md decisions log,
2026-10-25):

| Name | Tag and file names | Windows version number | On GitHub |
| --- | --- | --- | --- |
| `0.1 Dev 1` | `v0.1-dev.1` | `0.1.1.1` | pre-release |
| `0.1 Beta 2` | `v0.1-beta.2` | `0.1.2.2` | pre-release |
| `0.1` | `v0.1` | `0.1.3.0` | full release |

Windows wants four plain numbers, so the third is the stage (1 Dev, 2 Beta, 3 released) and the fourth the count:
the number always goes up. Check any name or tag with `tools/version.sh "0.1 Beta 2"` or `tools/version.sh v0.1-beta.2`.
The version released is the one in `config/version` in `project.godot`; the workflow also stamps it into the exe's
version number.

## Making a release
1. **Gather the notes (a pull request, Claude does this when the owner asks for a release).** Run
   `tools/changelog.sh release "0.1 Dev 1"`: it moves the notes in `changelog.d/` into a `## 0.1 Dev 1 (date)`
   section of `CHANGELOG.md`. Set `config/version` in `project.godot` to the same name, check the player wiki is
   current, and open the pull request. The owner merges it.
2. **Release (the owner).** Either:
   - **Button:** on GitHub, *Actions → Release → Run workflow*, leave "Use workflow from" on `main` and the version
     empty, tick **Publish**, and *Run workflow*. It releases the version in `project.godot` and creates the tag for
     you.
   - **Tag:** push the version's tag (like `v0.1-dev.1`) on a commit on `main`.

   Don't make the release by hand on the Releases page: the workflow makes it, with the downloads attached.
3. **Wait about 20 minutes.** The workflow runs the smoke test, exports the Windows game, checks the exported game
   flies the same smoke run, builds the installer, installs it on a Windows machine, plays the smoke run with the
   installed game, uninstalls it, and only then publishes. If any step fails nothing is published; the run's page says
   which step and why.

Before building anything, publishing stops with a message if: the tag isn't in the form above or isn't on `main`;
`project.godot` on that commit names another version; `CHANGELOG.md` has no section for it (step 1 wasn't merged);
or, with the button, the version has already been released.

4. **Next version (a small pull request, Claude).** Set `config/version` to the next name (`0.1 Dev 2`) so the game
   shows what is being worked on.

## Trying a build without releasing
*Actions → Release → Run workflow* with **Publish** unticked builds and tests everything and publishes nothing; type a
version to build as another one. The installer and zip are under *Artifacts* at the bottom of the run's page (kept 14 days). Every pull request that
changes the release pipeline does the same.

## The "Windows protected your PC" warning
The installer and game aren't code-signed, so Windows SmartScreen warns the first time a player runs them: *More
info → Run anyway*. The release notes say so. Removing the warning needs a code-signing certificate (yearly cost,
identity checks) and its key stored as a GitHub Secret, with a signing step added to the workflow; that is the owner's
call, and the certificate and key never go in the repo.

## The pieces
| File | What it does |
| --- | --- |
| `.github/workflows/release.yml` | The workflow above. |
| `installer/ProjectPraesepe.iss` | The Inno Setup installer script. Its `AppId` must never change, or updates install side by side. |
| `tools/version.sh` | Turns a name or tag into the other forms. |
| `tools/changelog_section.sh` | Writes the release notes. |
| `tools/make_icon.gd` | Draws the exe, installer and shortcut icon from `icon.svg` (into `build/release/`). |
| `tools/make_notices.gd` | Writes `THIRD_PARTY_NOTICES.txt` (Godot's licences and any shipped third-party asset's) for the downloads. |
| `export_presets.cfg` | The Windows export: x86_64, game packed into the exe, icon and version stamped in. |

To export by hand: run the two `tools/make_*.gd` scripts first (`godot --headless --path . -s res://tools/make_icon.gd`),
then `godot --headless --path . --export-release "Windows Desktop" build/windows/ProjectPraesepe.exe`. Needs the
Godot 4.7.2 export templates.
