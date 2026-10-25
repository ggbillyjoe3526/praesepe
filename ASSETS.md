# Assets and third-party code

Every third-party asset, add-on and piece of code in the repo, with its source and licence. Only CC0, CC-BY or SIL
OFL assets; no GPL code in the game.

| Name | What it is | Source | Licence | Author | Ships in the game? |
| --- | --- | --- | --- | --- | --- |
| Gut 9.7.1 | Unit test framework (`addons/gut/`, licence in `addons/gut/LICENSE.md`) | https://github.com/bitwes/Gut, copied from the owner's katanashotgun project | MIT | Tom "Butch" Wesley | No: tests only, excluded in `export_presets.cfg` |
| Anonymous Pro, Courier Prime, Lobster Two | Fonts of Gut's test runner (`addons/gut/fonts/`, licence in `addons/gut/fonts/OFL.txt`) | Bundled with Gut | SIL OFL 1.1 | See `addons/gut/fonts/OFL.txt` | No |
| Inno Setup 6 | Builds the Windows installer; its setup program is inside the `Windows-Setup.exe` download (`installer/ProjectPraesepe.iss`) | https://jrsoftware.org/isinfo.php, installed by the release workflow | Inno Setup License (free, commercial use allowed) | Jordan Russell, Martijn Laan | Installer only |

Code reused from the owner's own games (katanashotgun, Airsoft-Next) is the owner's and is noted in each file's header,
not here.
