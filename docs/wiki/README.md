# The player wiki

This folder is the source of the game's GitHub wiki
(<https://github.com/ggbillyjoe3526/praesepe/wiki>). Each `.md` file is one page, named like
`Docking-and-Landing.md` (dashes become spaces in the page title). `Home.md` is the front page, `_Sidebar.md` the menu
on every page and `_Footer.md` the line under it. This README is never published. The layout follows `DESIGN.md`,
"Player wiki". Ported from katanashotgun's `docs/wiki/`.

**Publishing:** `.github/workflows/wiki.yml` pushes the pages to the wiki on every merge to `main` that touches them
(or the changelog, or a scene). Edits made in the wiki's web editor are overwritten, so always edit here. It uses the
workflow's own `GITHUB_TOKEN`; no secret is needed. Actions > Wiki > Run workflow republishes by hand.

**Patch Notes is generated**, never written by hand: `tools/wiki.py build` writes `Patch-Notes.md` from the
`changelog.d/` notes waiting for the next release, then every version in `CHANGELOG.md`. It also stamps the footer
with the version and commit the pages came from.

## Keeping it current

The wiki describes **what is on `main`**: the newest development build (owner's call, 2026-10-25). Any change a player
would notice updates the page that describes it, **in the same pull request**: a control, setting, place, ship stat,
HUD message, job, reward, upgrade or menu. Use the numbers from the code and `DESIGN.md`, and the words the game shows
on screen.

- **Not built yet** goes on `Roadmap.md`, never on another page as if it were playable. When a pull request ships
  something from the Roadmap, it moves it from there to the page that describes it (or a new page). Its "Being built
  now" list holds work already under way (open pull requests and work started on them); drop a line when it merges or
  is dropped.
- **A new kind of content** (contracts, upgrades, events) gets its own page when its first piece ships: Contracts and
  Jobs, Items and Upgrades, Events and Encounters (`DESIGN.md`, "Player wiki"). Then replace its "Coming later" line in
  `_Sidebar.md` with the new page.
- Write for players: second person, plain words, short sentences, keys in bold (**G**). Game names in the game's
  spelling (Halfway Station, The Shingle). No developer words (scenes, tuning files, autoloads) and no file paths
  except save locations.
- Link pages as `[Orbit](Orbit)` or `[Landing](Docking-and-Landing#landing-at-tollgate)` (the anchor is the heading in
  lowercase, spaces as dashes, punctuation dropped).
- A new page gets a line in `_Sidebar.md`.
- Pictures go in `images/` as JPEGs about 1280 px wide (under about 100 KB), shown with
  `![what it shows](images/name.jpg)`. They are published with every page. Replace a picture when the thing it shows
  changes a lot; cloud screenshots are software renders, fine for layout, not for judging looks.

## Checks

`python3 tools/wiki.py check` (the Wiki workflow runs it on every pull request) fails when:

- a link points to a page, heading or picture that doesn't exist,
- a page is missing from the sidebar,
- an in-game name isn't mentioned on any page (the Roadmap, sidebar and footer don't count: a page has to describe it). The names are every `display_name = "..."` in the game's scenes and
  resources (`NAME_SOURCES` in `tools/wiki.py`): today the places; ships, contracts and upgrades should use
  `display_name` too, so they are caught without changing the tool.

On a pull request it also warns when a `changelog.d/` note is added but no wiki page changed.
`python3 tools/wiki.py build build/wiki` writes the pages as they will be published, to preview locally.
