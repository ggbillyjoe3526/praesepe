#!/usr/bin/env bash
# Changelog fragments: each pull request adds one small file to changelog.d/
# instead of editing CHANGELOG.md, so parallel PRs never conflict.
# changelog.d/README.md explains the format.
# Usage:
#   tools/changelog.sh check            CI: every fragment is well formed
#   tools/changelog.sh unreleased       print the fragments as one section body
#   tools/changelog.sh release [NAME]   before a release: move the fragments
#                                       into CHANGELOG.md under "## NAME (date)"
#                                       (NAME defaults to project.godot's
#                                       config/version)
set -euo pipefail
cd "$(dirname "$0")/.."
DIR=changelog.d

# Fragment paths, newest first by the time git first saw them (uncommitted
# ones count as newest), ties and shallow clones falling back to name order.
fragments() {
  local f t now
  now=$(date +%s)
  for f in "$DIR"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = README.md ] && continue
    t=$(git log --no-renames --diff-filter=A -1 --format=%ct -- "$f" 2>/dev/null || true)
    printf '%s\t%s\n' "${t:-$now}" "$f"
  done | sort -t "$(printf '\t')" -k1,1nr -k2,2 | cut -f2
}

unreleased() {
  local f first=1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ $first = 1 ] || echo
    first=0
    # Drop leading and trailing blank lines so fragments join with one gap.
    awk 'NF { p = 1 } p { buf = buf $0 "\n"; if (NF) { printf "%s", buf; buf = "" } }' "$f"
  done < <(fragments)
}

check() {
  local f name bad=0 n=0
  if grep -qE '^## +Unreleased' CHANGELOG.md; then
    echo "::error file=CHANGELOG.md::CHANGELOG.md has an '## Unreleased' section. Put the notes in a new file in $DIR/ instead (see $DIR/README.md)."
    bad=1
  fi
  for f in "$DIR"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    [ "$name" = README.md ] && continue
    n=$((n + 1))
    if ! [[ "$name" =~ ^[a-z0-9][a-z0-9-]*\.md$ ]]; then
      echo "::error file=$f::Fragment names are lowercase words joined by dashes, ending in .md (like cargo-screen.md)."
      bad=1
      continue
    fi
    if ! awk 'NF { exit !/^### [^ ]/ }' "$f"; then
      echo "::error file=$f::A fragment starts with a '### Title' line (see $DIR/README.md)."
      bad=1
    fi
    if ! grep -qE '^- [^ ]' "$f"; then
      echo "::error file=$f::A fragment needs at least one '- ' bullet."
      bad=1
    fi
    if grep -qE '^#{1,2} ' "$f"; then
      echo "::error file=$f::Only '###' headings in a fragment: '#' and '##' would break the release notes."
      bad=1
    fi
  done
  [ $bad = 0 ] || exit 1
  echo "$n changelog fragment(s) OK. The next release notes will read:"
  echo
  unreleased
}

release() {
  local name date body tmp
  name="${1-$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)}"
  if [ -z "$name" ]; then
    echo "No version name given and none in project.godot." >&2
    exit 1
  fi
  date=$(date -u +%Y-%m-%d)
  if awk -v h="## $name" '$0 == h || index($0, h " (") == 1 { f = 1 } END { exit !f }' CHANGELOG.md; then
    echo "CHANGELOG.md already has a '## $name' section." >&2
    exit 1
  fi
  body=$(unreleased)
  if [ -z "${body//[[:space:]]/}" ]; then
    echo "No fragments in $DIR/: nothing to release." >&2
    exit 1
  fi
  # The new section goes above the first existing version section.
  tmp=$(mktemp)
  HEAD="## $name ($date)" BODY="$body" awk '
    !done && /^## / { print ENVIRON["HEAD"] "\n\n" ENVIRON["BODY"] "\n"; done = 1 }
    { print }
    END { if (!done) print "\n" ENVIRON["HEAD"] "\n\n" ENVIRON["BODY"] }
  ' CHANGELOG.md > "$tmp"
  cat "$tmp" > CHANGELOG.md
  rm -f "$tmp"
  fragments | while IFS= read -r f; do rm -f -- "$f"; done
  echo "Added '## $name ($date)' to CHANGELOG.md and deleted the fragments. Review the section, then commit CHANGELOG.md and $DIR/."
}

case "${1-}" in
  check) check ;;
  unreleased) unreleased ;;
  release) shift; release "$@" ;;
  *) sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
