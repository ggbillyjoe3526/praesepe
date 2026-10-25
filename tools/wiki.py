#!/usr/bin/env python3
"""The player wiki: docs/wiki/ holds one Markdown file per page, published to
the repository's GitHub wiki by .github/workflows/wiki.yml on every merge to
main. docs/wiki/README.md explains the conventions. Ported from katanashotgun
(tools/wiki.py), with Praesepe's name sources and a build stamp in the footer.

Usage:
  python3 tools/wiki.py check [--base REF]   CI: links, anchors, the sidebar,
                                             and every in-game name has a page
                                             that mentions it. With --base, warn
                                             when a change adds a changelog note
                                             but leaves the wiki untouched.
  python3 tools/wiki.py build OUT            write the publishable wiki to OUT,
                                             with Patch-Notes.md generated from
                                             CHANGELOG.md and changelog.d/,
                                             and the footer stamped with the
                                             version and commit it came from
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIKI = ROOT / "docs" / "wiki"
# Pages the build writes itself, so links to them are fine.
GENERATED = {"Patch-Notes"}
# Never published: the contributor notes for this folder.
SKIP = {"README.md"}

# Where the player-facing names live. Every name these patterns find must
# appear somewhere in the wiki. Places (planets, moons, stations, bases, the
# belt) carry a `display_name` in their scenes; ships, contracts and upgrades
# defined as .tres resources should use `display_name` too, so they are caught
# here without touching this list. Add a pattern when content gets its name
# some other way.
NAME_SOURCES = [
    "game/**/*.tscn",
    "game/**/*.tres",
]
NAME_RE = re.compile(r'\bdisplay_name\s*=\s*"([^"]+)"')
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
HEADING_RE = re.compile(r"^#{1,6}\s+(.*?)\s*#*\s*$")


def pages() -> dict:
    """Page name -> text, for every published page in docs/wiki/."""
    out = {}
    for f in sorted(WIKI.glob("*.md")):
        if f.name not in SKIP:
            out[f.stem] = f.read_text(encoding="utf-8")
    return out


def slug(heading: str) -> str:
    """The anchor GitHub gives a heading."""
    h = re.sub(r"[*_`]|\[([^\]]*)\]\([^)]*\)", r"\1", heading).strip().lower()
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")


def anchors(text: str) -> set:
    out = set()
    in_code = False
    for line in text.splitlines():
        if line.startswith("```"):
            in_code = not in_code
            continue
        m = None if in_code else HEADING_RE.match(line)
        if m:
            out.add(slug(m.group(1)))
    return out


def norm(s: str) -> str:
    s = s.replace("’", "'").replace("‘", "'").lower()
    return re.sub(r"\s+", " ", s)


def game_names() -> list:
    names = {}
    for pattern in NAME_SOURCES:
        for f in sorted(ROOT.glob(pattern)):
            for n in NAME_RE.findall(f.read_text(encoding="utf-8")):
                names.setdefault(n, f.relative_to(ROOT).as_posix())
    return list(names.items())


def check(base: str = "") -> int:
    bad = 0
    all_pages = pages()
    if "Home" not in all_pages:
        print("::error file=docs/wiki::docs/wiki/Home.md is missing: it is the wiki's front page.")
        return 1
    known = set(all_pages) | GENERATED
    page_anchors = {name: anchors(text) for name, text in all_pages.items()}

    for name, text in all_pages.items():
        path = f"docs/wiki/{name}.md"
        for target in LINK_RE.findall(text):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue  # https:, mailto:
            page, _, anchor = target.partition("#")
            page = page or name
            if page.startswith("images/"):
                # a picture shipped with the wiki (docs/wiki/images/)
                if not (WIKI / page).is_file():
                    print(f"::error file={path}::Image that doesn't exist: ({target}). Put it in docs/wiki/images/.")
                    bad = 1
                continue
            if page not in known:
                print(f"::error file={path}::Link to a page that doesn't exist: ({target}). Pages are file names without .md, like (Locations).")
                bad = 1
            elif anchor and page in page_anchors and anchor not in page_anchors[page]:
                print(f"::error file={path}::Link to a heading that doesn't exist: ({target}). Anchors are the heading in lowercase with dashes for spaces.")
                bad = 1

    sidebar = all_pages.get("_Sidebar", "")
    linked = {t.partition("#")[0] for t in LINK_RE.findall(sidebar)}
    for name in sorted(known):
        if not name.startswith("_") and name not in linked:
            print(f"::error file=docs/wiki/_Sidebar.md::Page {name} isn't in the sidebar. Add a link to it in docs/wiki/_Sidebar.md.")
            bad = 1

    corpus = norm("\n".join(all_pages.values()))
    for n, src in game_names():
        if not re.search(r"(?<!\w)" + re.escape(norm(n)) + r"(?!\w)", corpus):
            print(f"::error file={src}::'{n}' is in the game but no wiki page mentions it. Describe it on the right page in docs/wiki/ (docs/wiki/README.md).")
            bad = 1

    if base:
        changed = subprocess.run(
            ["git", "diff", "--name-only", "--diff-filter=AM", f"{base}...HEAD"],
            cwd=ROOT, capture_output=True, text=True,
        )
        files = changed.stdout.split() if changed.returncode == 0 else []
        notes = [f for f in files if f.startswith("changelog.d/") and not f.endswith("README.md")]
        if notes and not any(f.startswith("docs/wiki/") for f in files):
            print(f"::warning::This change adds a changelog note ({', '.join(notes)}) but no wiki page. If players will notice it, update the page in docs/wiki/ that describes it.")

    if bad == 0:
        print(f"Wiki OK: {len(all_pages)} pages, links and headings resolve, and every in-game name is covered.")
    return bad


def patch_notes() -> str:
    """Patch-Notes.md: the notes waiting for the next release, then every
    released version from CHANGELOG.md. Written once, in the changelog."""
    upcoming = subprocess.run(
        ["bash", "tools/changelog.sh", "unreleased"], cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.strip()
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    m = re.search(r"^## ", changelog, re.M)
    released = changelog[m.start():].strip() if m else ""
    parts = [
        "# Patch Notes",
        "What changed in each version of Project Praesepe, newest first. Downloads will be on the "
        "[Releases page](https://github.com/ggbillyjoe3526/project-praesepe/releases). "
        "What's planned next is on the [Roadmap](Roadmap).",
        "## Coming in the next update",
        "Already in the development build and on its way in the next download:",
        upcoming or "Nothing yet.",
    ]
    if released:
        parts.append(released)
    else:
        parts.append("## Released versions\n\nNone yet: there is no download so far. The first one comes once the "
                     "first playable is ready.")
    return "\n\n".join(parts) + "\n"


def stamp() -> str:
    """The footer's last line: which build these pages describe."""
    m = re.search(r'^config/version="([^"]*)"', (ROOT / "project.godot").read_text(encoding="utf-8"), re.M)
    version = m.group(1) if m else "unknown version"
    log = subprocess.run(["git", "log", "-1", "--format=%h %cs"], cwd=ROOT, capture_output=True, text=True)
    commit, _, day = log.stdout.strip().partition(" ") if log.returncode == 0 else ("", "", "")
    where = f" from commit [{commit}](https://github.com/ggbillyjoe3526/project-praesepe/commit/{commit}), {day}" if commit else ""
    return f"<sub>Describes the development build {version}{where}.</sub>"


def build(out: Path) -> int:
    out = out.resolve()
    if out.exists():
        # only ever replace an earlier build, never a folder that holds
        # anything else (a mistyped OUT like "." or "docs")
        if out in (ROOT, WIKI) or out in ROOT.parents or (any(out.iterdir()) and not (out / "Home.md").is_file()):
            print(f"{out} isn't an earlier wiki build; pick an empty or new folder such as build/wiki", file=sys.stderr)
            return 1
        shutil.rmtree(out)
    shutil.copytree(WIKI, out, ignore=shutil.ignore_patterns(*SKIP))
    (out / "Patch-Notes.md").write_text(patch_notes(), encoding="utf-8")
    footer = out / "_Footer.md"
    if footer.is_file():
        footer.write_text(footer.read_text(encoding="utf-8").rstrip() + "\n\n" + stamp() + "\n", encoding="utf-8")
    print(f"Wrote {len(list(out.glob('*.md')))} pages to {out}")
    return 0


def main(argv: list) -> int:
    if len(argv) >= 1 and argv[0] == "check":
        base = argv[2] if len(argv) >= 3 and argv[1] == "--base" else ""
        return check(base)
    if len(argv) == 2 and argv[0] == "build":
        return build(Path(argv[1]))
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
