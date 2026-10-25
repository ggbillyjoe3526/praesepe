# FAQ

## Is there a download?

Not yet. The game is in early development. The first download will be for Windows, on the
[Releases page](https://github.com/ggbillyjoe3526/project-praesepe/releases), once the first playable is ready. The
[Patch Notes](Patch-Notes) will say when.

## What can I do in the game right now?

Fly, cruise between five places, dock, land and park in orbit. There are no jobs, money or upgrades yet. See
[Home](Home#where-the-game-is-now) and the [Roadmap](Roadmap).

## Does the game save?

Yes: it saves itself every time you dock or land ("Game saved" on screen), and every 3 minutes while you fly
(paused time doesn't count), so quitting or a crash never loses more than that. Loading that save isn't in the game yet, so
each launch still starts a fresh flight next to Halfway Station. Your settings are saved separately.

## Where are my saves and settings?

On Windows, in `%APPDATA%\Godot\app_userdata\ProjectPraesepe`: `savegame.json` is your game, `settings.json` your
settings. The game writes saves safely: it keeps one backup, and if a file is ever damaged it sets it aside and never
deletes it.

## What is the world seed?

A number that decides the parts of the world that vary from game to game, like where the rocks of The Shingle lie. The
same seed always gives the same world. It is shown on the pause screen and in the F3 overlay.

## I'm lost or stuck far from anywhere

Pause (**Esc**) and press the tow button, which names where it goes ("Tow me to Tollgate · free"), then press it
again to confirm. It isn't offered while you're docked or landed. Your ship is put straight back at the
last station or base you docked or landed at (or the nearest one), and the game saves there. It's free for now; once
there is money it will cost a small towing fee.

## Can I lose my ship or my progress?

No. Nothing in the game damages your ship yet, and the finished game is designed so failing costs a little money and
time, never your progress.

## Do I have to fight?

Never. There is no combat in the game yet, and when it comes, every way to progress will have a non-combat option.

## Will there be a controller, multiplayer, Mac or Linux?

Windows comes first, then Mac and Linux. Controller support, multiplayer and Steam haven't been decided yet.

## Known issues

- Planets stretch a little near the edges of the screen, more with a wider field of view. That is how a flat picture
  shows round things; a narrower field of view (Settings > Comfort) makes it smaller.
- The ship, station and base are simple stand-in models, and there is no sound yet.
- Names (the game, places, ships) are placeholders.
