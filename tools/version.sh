#!/usr/bin/env bash
# Version names and the forms the release pipeline needs (RELEASING.md). From the owner's katanashotgun project,
# taking a tag as well as a name. Versions are named the way players see them ("0.1 Dev 1", "0.1 Beta 2", "0.1";
# DESIGN.md decisions log). This prints, one per line:
#   name=0.1 Dev 1     what players see (in the game, the installer, the release title)
#   tag=v0.1-dev.1     the git tag, also used in the download file names
#   number=0.1.1.1     Windows version number: four numbers that always go up
#   prerelease=true    Dev and Beta builds are GitHub pre-releases
# Usage: tools/version.sh                (reads config/version in project.godot)
#        tools/version.sh "0.1 Beta 2"   (checks and converts a name)
#        tools/version.sh v0.1-beta.2    (checks and converts a tag)
set -euo pipefail
cd "$(dirname "$0")/.."
IN="${1-$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)}"
NUM='(0|[1-9][0-9]{0,3})'
COUNT='([1-9][0-9]{0,3})'
if [[ "$IN" =~ ^v${NUM}\.${NUM}(-(dev|beta)\.${COUNT})?$ ]]; then
  # A tag: v0.1-dev.1 is "0.1 Dev 1".
  MAJOR="${BASH_REMATCH[1]}"; MINOR="${BASH_REMATCH[2]}"; N="${BASH_REMATCH[5]}"
  case "${BASH_REMATCH[4]}" in dev) STAGE=Dev ;; beta) STAGE=Beta ;; *) STAGE="" ;; esac
elif [[ "$IN" =~ ^${NUM}\.${NUM}(\ (Dev|Beta)\ ${COUNT})?$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"; MINOR="${BASH_REMATCH[2]}"; N="${BASH_REMATCH[5]}"; STAGE="${BASH_REMATCH[4]}"
else
  echo "::error::'$IN' is not a version like '0.1 Dev 1', '0.1 Beta 2' or '0.1', or a tag like v0.1-dev.1, v0.1-beta.2 or v0.1 (see RELEASING.md)" >&2
  exit 1
fi
# Windows wants four plain numbers: the third is the stage (1 Dev, 2 Beta, 3 released), the fourth the count, so
# every Dev is below every Beta, which is below the release, which is below the next version's Dev 1.
case "$STAGE" in
  Dev)  NAME="$MAJOR.$MINOR Dev $N";  TAG="v$MAJOR.$MINOR-dev.$N";  NUMBER="$MAJOR.$MINOR.1.$N"; PRE=true ;;
  Beta) NAME="$MAJOR.$MINOR Beta $N"; TAG="v$MAJOR.$MINOR-beta.$N"; NUMBER="$MAJOR.$MINOR.2.$N"; PRE=true ;;
  *)    NAME="$MAJOR.$MINOR";         TAG="v$MAJOR.$MINOR";         NUMBER="$MAJOR.$MINOR.3.0";  PRE=false ;;
esac
printf 'name=%s\ntag=%s\nnumber=%s\nprerelease=%s\n' "$NAME" "$TAG" "$NUMBER" "$PRE"
