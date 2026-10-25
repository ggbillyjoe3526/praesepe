# Assets and third-party code

Every third-party asset, add-on and piece of code in the repo, with its source and licence. Only CC0, CC-BY or SIL
OFL assets; no GPL code in the game.

| Name | What it is | Source | Licence | Author | Ships in the game? |
| --- | --- | --- | --- | --- | --- |
| Gut 9.7.1 | Unit test framework (`addons/gut/`, licence in `addons/gut/LICENSE.md`) | https://github.com/bitwes/Gut, copied from the owner's katanashotgun project | MIT | Tom "Butch" Wesley | No: tests only, excluded in `export_presets.cfg` |
| Anonymous Pro, Courier Prime, Lobster Two | Fonts of Gut's test runner (`addons/gut/fonts/`, licence in `addons/gut/fonts/OFL.txt`) | Bundled with Gut | SIL OFL 1.1 | See `addons/gut/fonts/OFL.txt` | No |
| Inno Setup 6 | Builds the Windows installer; its setup program is inside the `Windows-Setup.exe` download (`installer/ProjectPraesepe.iss`) | https://jrsoftware.org/isinfo.php, installed by the release workflow | Inno Setup License (free, commercial use allowed) | Jordan Russell, Martijn Laan | Installer only |

## Models made for the game

Made in Blender for this game, by Claude through the Blender tools (the build scripts are in `tools/blender/`) or by the
owner. They are the owner's, like the code; listed so every model is accounted for.

| Name | What it is | Made in | Source files | Ships in the game? |
| --- | --- | --- | --- | --- |
| Hauler placeholder model | The test ship outside (`game/ship/models/hauler_exterior.glb`) and its cockpit (`game/ship/models/hauler_cockpit.glb`); placeholder, art style still open | Blender 5.2 (2026-10-25), from `tools/blender/hauler_model.py` and the owner's reference pictures | The owner's `hauler_v002.blend`; rebuilt by running `ship_reference.py`, `hauler_model.py` and `export_ship.py` | Yes |

Code reused from the owner's own games (katanashotgun, Airsoft-Next) is the owner's and is noted in each file's header,
not here.
