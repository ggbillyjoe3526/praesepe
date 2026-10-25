# Changelog

What changed in each version, newest first, for players and the owner. Notes for the next version wait in
`changelog.d/` until a release gathers them here.

## 0.1 Dev 1 (2026-10-25)

The first download: an early development build to fly round in. There are no jobs, money, loan or upgrades yet; those
come next (see the wiki's Roadmap). Everything below is new.

### Download and install on Windows
- A Windows installer (`Windows-Setup.exe`) that adds a Start menu shortcut, an optional desktop shortcut and an
  uninstaller, plus a portable zip to play without installing.
- Installing a newer version updates the game in place, and your saved game is never touched by updating or
  uninstalling.

### Start menu and choosing your ship
- The game opens fullscreen on a title screen with Continue, New game, Settings and Quit.
- New game lets you choose your ship (the Hauler for now: great for porters and miners), then starts you docked at
  Halfway Station.
- Continue picks up your saved game exactly where it was saved: in the station's bay, on Tollgate's pad, in orbit or
  out in space at the same spot, facing the same way. It never moves you to a station.
- Starting a new game over a saved one asks first. A saved game that can't be read is never deleted.

### Flying
- Weighty, Newtonian flight. Flight assist is on to start: W and S set your speed and the ship holds it, the thrusters
  cancel any slide, and the ship stops turning when you stop moving the mouse. Press Z to switch it off and drift
  freely, X for a full stop.
- A velocity marker shows where the ship is really going. Stars and drifting space dust show your speed and direction.
- Press R to roll upright: the ship rolls round its nose until the nearest planet or moon is below you and its horizon
  is level. Q or E stops it.

### Your ship, its cockpit and a chase camera
- A small test ship stands in for the Hauler while the flying is tuned, with a simple model of its own: light grey
  with orange panels, a flat windscreen sloping down to the nose, two engine pods with glowing nozzles and short swept
  wings.
- You fly from a simple cockpit: a slim, dark dashboard low across the bottom of the view, showing your speed and
  flight assist, with no frame bars across the window.
- Press V to switch to a chase camera behind the ship. It swings a little behind your turns, and with flight assist
  off it leans toward where the ship is really drifting. It never goes through things: it moves in close instead.
- Hold the right mouse button to look round the cockpit without steering; in the chase view it swings the camera round
  the ship. Let go and the view turns back to the front.
- Your head sways slightly as the engines push, and the view rumbles faintly under thrust and shakes after a bump.
- Press F12 to save a screenshot. A note in the corner says where it went.

### A tiny solar system
- Halfway Station, the planet Calder with its base Tollgate, Calder's moon Mote, and an asteroid belt, The Shingle.
  The names are placeholders.
- Every place has a diamond marker; its name and distance show when you're close (within 5 km), looking toward it,
  aiming at it or cruising to it.
- The Shingle's rocks are different for every world seed, and the same every time you play the same seed. You can
  bump into the ones near you.
- Planets stay round near the edges of the screen: the default field of view is 60° (about 90° across a widescreen
  monitor).

### The cruise drive
- Aim at a place and press F: the drive charges for two seconds, then locks on and flies you there by itself, turning
  the ship to face it, flying round any planet in the way and dropping out when you arrive.
- Once locked, the place's marker turns blue and the dashboard shows the target, how far it is and how long until you
  get there: "TARGET  Mote · 16 km · 18 s".
- Move the mouse to take the steering back. Pressing F with nothing aimed at cruises wherever the nose points. F again
  (or X) drops out whenever you like. It never flies you into anything.

### Docking and landing
- Fly near Halfway Station or down to Tollgate's pad, slow down and press G when the HUD says "G  Dock" or "G  Land".
  Your ship's docking computer flies you in while you watch, with no loading screen.
- Docked, the ship turns to face out of the bay and settles on its floor. Landed, it sits on Tollgate's pad. G again
  undocks or takes off.
- The station's bay and Tollgate's pad shine a faint guide light along the way in, so you can line up by eye. It
  brightens when you're lined up.
- The docking computer carries on at about the speed you were going: it can slow down but never races off faster than
  you were flying. G on the way takes the controls back; X stops.
- Landing is offered close to the pad (within 600 m), not from orbit or high over the base.
- A red "SLOW DOWN" warning shows when you're flying at something faster than you could comfortably stop, with how
  many seconds until you reach it.

### Parking in orbit
- Calder and Mote each have an orbit line up in space: Calder's is 3 km up, Mote's 1.2 km. Once you're up off the
  ground you see it as a faint lane round the planet, with a small ring on the HUD marking where to join it and how far
  to climb ("Orbit  ·  climb 1.2 km").
- Close to the line, press O to park in orbit and stay as long as you like, with the ground drifting slowly past below:
  about 20 minutes round Calder and 14 round Mote. O again, or any thrust key, brings the nose up level and flies you
  out of it.

### Nav computer
- Tab opens the nav computer: a screen on the cockpit dashboard (a card in the chase view) where you pick a place and
  how to arrive there: dock, land at a base, go into orbit or just stop nearby.
- Enter sends the ship there now; Shift+Enter adds it to a plan, so you can queue several trips. The ship flies the
  plan itself: undocking, cruising, orbiting, docking and landing.
- Touch the controls and the plan pauses, leaving the ship to you; P resumes. A strip at the top of the screen shows
  what the plan is doing while the screen is closed.

### Saving, and a tow home
- The game saves itself every time you dock or land, and every 3 minutes while you fly, without a stutter.
- Quitting to the title or the desktop saves first (unless you're cruising or the ship is flying itself in or out,
  when your last save stands).
- "Tow me to base" on the pause screen: press it twice and your ship is put straight back at the last station or base
  you docked or landed at, and the game saves there. It's free for now; once there is money it will cost a small
  towing fee.

### Settings
- Esc pauses, and so does switching away from the game. The pause screen has Settings, the tow home, Quit to title and
  Quit to desktop.
- The settings menu has four pages, each with a button to put its settings back to their defaults:
  - **Display:** fullscreen, exclusive fullscreen or a window, which display to use, V-Sync and a frame-rate limit.
  - **Interface:** the size (90% to 125%) of the HUD, its text and the menus, and when place markers and names show
    (Always, Near or looked at, or Off).
  - **Comfort:** field of view (50° to 90°), camera shake, head bob and reduce motion.
  - **Controls:** mouse sensitivity, invert mouse, and every key the game uses.
- F11 or Alt+Enter switches between fullscreen and a window at any time.
- While the game is in the background it draws fewer frames, so your PC stays cooler.

### A player wiki
- The game has a wiki on GitHub: what's in the game, every key and setting, the places in the solar system, the test
  ship's numbers, how cruising, docking, landing, orbit and the nav computer work, these patch notes, the roadmap and
  an FAQ.
