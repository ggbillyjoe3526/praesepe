# FAQ

## Is there a download?

Yes, for Windows (64-bit). The first one is **0.1 Dev 1**, an early development build. Each version is on the
[Releases page](https://github.com/ggbillyjoe3526/project-praesepe/releases) as a Windows installer (`Windows-Setup.exe`, with a Start menu shortcut and an uninstaller) and
a portable zip to play without installing: unzip it anywhere and run `ProjectPraesepe.exe`. Installing a newer version
updates the game in place and never touches your saved game. The [Patch Notes](Patch-Notes) say what's in each
version.

## Windows says "Windows protected your PC"

The game isn't code-signed, so Windows SmartScreen warns you the first time you run the installer or the game. Click
**More info**, then **Run anyway**.

## What can I do in the game right now?

Fly, cruise between five places, dock, land and park in orbit. There are no jobs, money or upgrades yet. See
[Home](Home#where-the-game-is-now) and the [Roadmap](Roadmap).

## Does the game save?

Yes: it saves itself every time you dock or land ("Game saved" on screen), every 3 minutes while you fly (paused time
doesn't count), and when you choose **Quit to title** or **Quit to desktop** on the pause screen, so a crash never
loses more than a few minutes. (While the cruise drive is on, or the ship is flying itself in or out of a dock, quitting
keeps your last save instead.) Press **Continue** on the start menu to carry on exactly where you saved: docked,
landed, in orbit or out in space, facing the same way. You have one saved game; **New game** asks before replacing it.
Your settings are saved separately.

## Where are my saves, settings and screenshots?

On Windows, in `%APPDATA%\ProjectPraesepe`: `savegame.json` is your game, `settings.json` your settings, and the
`screenshots` folder holds the pictures you take with **F12** (named by the date and time). When you take one, a
note in the corner of the screen shows exactly where it went. The game writes saves safely: it keeps one backup, and if a file is ever damaged it sets it aside and never
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
