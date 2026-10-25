#!/usr/bin/env bash
# Prints the release notes for one version: its CHANGELOG.md section, then how to install. From the owner's
# katanashotgun project. Used by .github/workflows/release.yml (RELEASING.md).
# Usage: tools/changelog_section.sh "0.1 Dev 1"
# Sections start with a heading like "## 0.1 Dev 1 (2026-10-25)". Before a release, `tools/changelog.sh release`
# writes that section from the notes in changelog.d/. If no section matches, the notes still in changelog.d/ are used
# as they are and the run shows a warning.
set -euo pipefail
NAME="$1"
cd "$(dirname "$0")/.."
section_for() {
  awk -v h="## $1" '
    /^## / {
      if (found) exit
      if ($0 == h || index($0, h " (") == 1) { found = 1; next }
    }
    found { print }
  ' CHANGELOG.md
}
section=$(section_for "$NAME")
if [ -z "${section//[[:space:]]/}" ]; then
  section=$(tools/changelog.sh unreleased)
  echo "::warning::CHANGELOG.md has no '## $NAME' section; using the notes in changelog.d/ (run tools/changelog.sh release before releasing)" >&2
fi
if [ -n "${section//[[:space:]]/}" ]; then
  printf '%s\n' "$section"
else
  echo "See CHANGELOG.md for what changed."
fi
cat <<'NOTE'

---
**Windows (64-bit):** download the `Windows-Setup.exe` and run it to install, or the `Windows-Portable.zip` to play
without installing (unzip it anywhere and run `ProjectPraesepe.exe`). Windows may show "Windows protected your PC"
because the game isn't code-signed yet: click **More info**, then **Run anyway**. Your saved game lives in
`%APPDATA%\ProjectPraesepe`, so updating or uninstalling never touches it.
NOTE
