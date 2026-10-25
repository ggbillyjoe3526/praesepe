# Project Praesepe – Design Doc

Oct 24, 2026 · @William

## Overview

Project Praesepe (working title, may change) is a casual, first-person space game: buy a ship on a loan, then earn money flying contracts around one solar system. It is a lighter take on No Man's Sky, with no survival, crafting web or base building.

Built with Godot (engine), Blender (models) and Claude Code (development).

**Pillars**

- **Simple, never confusing.** Every job has a clear goal and a short list of steps. If something needs a tutorial, it is too complex.
- **Casual and forgiving.** No fail states that wipe progress. Combat is never required.
- **Play your way.** Haul cargo, mine, fly taxi, hunt bounties or do science. Any ship can do any job.
- **A place worth exploring.** Each planet looks and feels distinct, with its own environment and weather.

**Tone:** relaxed space trucker with a ship to pay off, not a survival story. The player starts somewhere safe.

## Core loop and the loan

The loop: take contracts at a base, fly and complete them, get paid, then spend on loan payments and upgrades.

1. Dock at a base and pick contracts from the job board.
2. Fly out and complete them (deliver, fight, land and interact).
3. Return or arrive at the destination and get paid.
4. Spend money on loan payments, upgrades and repairs.
5. Take bigger or better-paying contracts.

**The starting loan**

- The player picks one of three ships, all the same price, bought with a loan.
- The loan is a push to go earn money, not the end goal. Paying it off should not take long.
- No interest, no repossession, no other complications.
- Payments are made whenever the player wants, at any base.
- After a long grace period, unpaid loans take future earnings automatically until the ship is paid off. Nothing else is lost.
- Later ships can be bought outright or on the same kind of loan.

## Ships

Three starter ships share a price and tier. Each leans toward a play style, but every ship can take every job. The selection screen shows a "Great for:" hint.

| Ship | Great for | Strengths | Trade-offs |
| --- | --- | --- | --- |
| Hauler | Porters / Miners | Large cargo hold, tough hull | Slow, less agile |
| Interceptor | Security / Taxi | Fast, agile, better weapons | Small cargo hold |
| Surveyor | Scientists / Explorers | Better scanners, longer fuel range | Lighter hull, modest cargo |

Upgrades (cargo, engines, scanners, shields, mining laser) let any ship cover its weak spots. Names and exact stats are placeholders.

**The test ship's model** (placeholder, 2026-10-25): the Hauler's look from the owner's reference pictures, made in
Blender by `tools/blender/hauler_model.py` and kept in the owner's `hauler_v002.blend` (on their PC, not in the repo).
Small and simple: light grey with orange panels and a few glowing strips, a flat windscreen sloping down to the nose
in front of a taller back half, flat side windows and a flat roof window, two engine pods with glowing nozzles, short
swept wings; about 14 m long and 14 m across. Inside, a slim dark dashboard low across the bottom of the view (the
dashboard screen where it always was) and side consoles low in the corners, with no frame bars in the pilot's view.
About 700 triangles outside and 1,100 in the cockpit, one mesh per material. The model only changes the look: the
collision shapes follow it (a box for the taller back half, one per engine pod and one per fin), but mass, centre of
mass and inertia stay as approved and the underside stays at 1.2 m below the centre, so flying, docking and the floor
berth are unchanged.

## Starting a game

The game opens on a title screen: the game's name over a slowly turning starfield, and a start menu.

- **Continue** puts back the saved game exactly as it was saved: the same world (seed, clock, random streams), and the ship docked or landed where it was, or out in space at the same place, heading and speed, with flight assist as it was. A ship saved in orbit goes back into orbit. Loading never moves the ship to a station. Continue only shows when there is a saved game that can be read; one that can't be read is kept in the save folder and the menu says so.
- **New game** opens "Choose your ship": a card for each starter ship with its "Great for:" hint, strengths and trade-offs. The first playable has one, the Hauler (the test ship's placeholder model stands in for it); the Interceptor and the Surveyor join the list when they are built. The game starts on a fresh world (or the `--seed` one), docked at Halfway Station, and saves straight away. Over an existing save the menu asks first: "This replaces your saved game".
- **Settings** opens the settings menu. **Quit** closes the game.
- Esc goes back a page. The pause screen has **Quit to title**. Quitting to the title or the desktop saves first, except while cruising or flying itself in or out, when the last save stands.
- The ships offered live in `game/ship/starter_ships.tres`, one file per ship (`game/ship/hauler.tres`).

## Flight and camera

Flight uses one Newtonian physics model with a flight assist toggle. It should never feel arcade-like.

- **Flight assist on (default):** thrusters automatically cancel drift and rotation when the player lets go. The ship keeps its weight and momentum but stays controllable.
- **Flight assist off:** full drift. For skilled players, combat and tight maneuvers. Switchable mid-flight.
- **Velocity marker:** a cockpit indicator showing where the ship is actually moving versus where it points.
- **Cruise drive:** compressed distances plus a fast travel mode that drops out when something interesting is nearby.

**How it flies (first values, to be tuned with the owner)**

- Flight assist on: W and S change the ship's set speed; let go and it holds that speed along the nose. A, D, Space and Ctrl slide sideways, up and down; let go and the thrusters cancel the slide. The mouse is a stick that eases back to the centre: move it to turn, stop and the turn settles. Q and E roll.
- Every correction uses the same limited thrusters, so a hard turn at speed slides before the ship lines up again. That slide is the ship's weight.
- Flight assist off (Z, switchable mid-flight): nothing is cancelled. The ship keeps its speed, direction and spin until the player counters them.
- X is a full stop: it turns flight assist on and brings the ship to rest.
- R rolls the ship upright (added at the owner's request, 2026-10-25): it rolls round its nose until its top points
  away from the nearest planet or moon, so that body's ground is below and its horizon level, and says which body it
  levelled with ("Rolling level with Calder", then "Level with Calder"). Only the roll changes: the nose stays where it
  points and the mouse still steers. It uses the ship's own roll thrusters, closing the angle at up to the full roll
  rate (a turn over in about 2 s), with flight assist on or off, and stops within 0.5°. Q or E takes over at once. With
  the nose within 10° of straight at the body or away from it no roll is more upright, so it says to pitch toward the
  horizon first. While the orbit turns the ship to face along it, or levels it out to leave, the orbit has the roll.
- Holding the right mouse button looks round instead of steering (added at the owner's request, 2026-10-25): the mouse
  turns the pilot's head (or swings the chase camera round the ship) and the stick eases back to the centre, so the
  ship's turn settles just as when the mouse stops. Let go and the view turns back to the front in about 0.2 s.
- The velocity marker sits where the ship is really going; when it is going backwards a crossed marker shows where it is moving away from.

**Flight tuning**

The values live in `game/ship/greybox_ship_tuning.tres` (per ship) and `game/flight/flight_controls.tres` (mouse and looking round). Change them here and there together.

| Value | Greybox ship | What it does |
| --- | --- | --- |
| Main engine | 40 m/s² | Forward push: 0 to top speed in 5 s |
| Braking | 25 m/s² | Backward push |
| Side and vertical thrusters | 30 m/s² | Sliding, and cancelling drift |
| Top speed | 200 m/s | Normal flight; the cruise drive goes beyond it |
| Top reverse speed | 50 m/s | With flight assist on |
| Turn rates | pitch 50°/s, yaw 35°/s, roll 100°/s | Full stick |
| Turn acceleration | pitch 120°/s², yaw 90°/s², roll 250°/s² | How heavy turns feel to start and stop |
| Assist response | 0.35 s (speed), 0.12 s (turning) | How eagerly assist corrects, within the thruster limits |
| Mouse | 250 px for a full stick, eases back at 3 per second | Shared by every ship; the player's sensitivity setting multiplies it (1× is this) |
| Looking round (right mouse) | 0.1° per px; 140° to either side, 70° up, 45° down; back to the front over 0.2 s | Shared by every ship; the sensitivity setting multiplies it and invert flips it, as for steering |
| Rolling upright (R) | Closes the roll left over 0.4 s, at most the full roll rate; level within 0.5°, rolling under 1°/s (under 0.02°/s with flight assist off, where nothing stops a leftover roll) | Per ship |
| Floating origin | Re-centres beyond 2048 m | Technical, not feel |

**Camera**

- First person is the main view, from a full cockpit.
- Cockpit UI is in the world where possible: cargo on a side screen, contracts on a dashboard panel, the radio as a physical control.
- While flying, the player can switch to a third-person chase camera showing the ship (not the player model).
- The chase camera lags slightly in turns. With flight assist off, it leans toward the velocity direction so drift stays readable.
- On foot is always first person. A third-person on-foot view may come later.

**How the cameras work (first values, to be tuned with the owner)**

- The game starts in the cockpit. V switches to the chase camera and back while flying.
- Cockpit: the speed and flight assist show on the dashboard screen, in the same words as the HUD. The nose mark, the velocity marker and the mouse stick stay on the screen in both views; in the chase view a plate at the bottom shows the speed and flight assist instead of the dashboard.
- Head bob in the cockpit: the pilot's head sways a few centimetres against the thrusters' push (back when speeding up, sideways when sliding), easing in and out.
- Camera shake: a faint rumble while the thrusters push, and a wobble after a bump that dies away in under a second.
- Chase camera: behind and above the ship, looking down at it a little, turning a moment after the ship does. With flight assist off it turns toward where the ship is really moving, by half the angle between nose and motion, at most 25°. Anything between it and the ship pulls it in at once; it eases back out when the way is clear.
- Looking round: while the right mouse button is held, the cockpit camera turns with the pilot's head and the chase
  camera swings round the ship by the same angles, still looking at it. The nose mark stays on the screen, at its edge
  on the side to turn back to when it is out of view.
- Screenshots (added at the owner's request, 2026-10-25): F12 saves the picture on the screen, HUD and all, as a PNG
  in the `screenshots` folder in the user folder (named by the date and time it was taken), and a note in the bottom
  left corner says where for 4 s. It works while paused too, and never holds up flight (the file is written in the
  background).
- Comfort settings, on the Comfort page of the settings menu, saved between sessions: field of view, camera shake, head bob and reduce motion (no shake or head bob, and a chase camera that swings half as much).

**Settings menu**

- The game opens fullscreen (borderless) on the main display. Esc pauses; the pause screen's Settings button opens the settings menu, and Esc or Back goes back. No key hints sit on the screen; a message for the first 8 s says "Esc · pause, settings and controls".
- Pages: **Display** (window mode: fullscreen, exclusive fullscreen or windowed; which display; V-Sync, on by default; frame-rate limit: none by default, or 30, 60, 120, 144, 165 or 240), **Interface** (interface size, 90% to 125%, default 100%: the HUD, its text and the menus together; 3D is unchanged), **Comfort** (as above) and **Controls** (mouse sensitivity 0.25× to 3×, default 1×, times the flight tuning's mouse gain; invert mouse, off; the list of keys, read from the input map). Each page has its own Defaults button.
- F11 or Alt+Enter switches between fullscreen and a window at any time. A window opens at 80% of the display, centred. In the background the game draws at most 30 frames a second.
- Every change shows at once and is saved to `settings.json` when the menu closes. Audio volumes and changing keys join the menu when there is audio and when the HUD prompts can follow a changed key. Graphics quality presets and render scale wait for the open decision on performance targets (the game draws at the display's full resolution until then). A window's size and place are not remembered between launches, and a window mode changed by the system itself (Win+Up, dragging to another display) is not read back.

**Camera tuning**

The values live in `game/camera/camera_tuning.tres` (shared by every ship). Where the pilot's eye and the chase camera sit is part of each ship's scene (its `Eye` and `ChaseAnchor` markers).

| Value | First value | What it does |
| --- | --- | --- |
| Field of view | 60° (50° to 90°), vertical; 60° is about 90° across on a 16:9 screen | Player setting, both cameras. Wider views stretch round things near the screen's edges, so planets look oval there |
| Pilot's eye | 1.15 m up, 3.54 m forward of the ship's centre | Ship scene; set with the 60° view (PR #6), and the cockpit model is built round it |
| Head sway | 1.2 mm per m/s² of push, at most 6 cm, eased over 0.15 s | 4.8 cm back at full main engine |
| Engine rumble | 0.12° at full thrust | Times the shake setting |
| Bump wobble | Up to 2° for a 6 m/s knock, gone in about 0.6 s; knocks under 0.3 m/s ignored | Times the shake setting |
| Chase camera place | 5.3 m up, 24 m behind, looking 9° down | Ship scene |
| Chase lag | 0.18 s (half with reduce motion) | 35°/s yaw shows as about 6° of swing |
| Chase lean (assist off) | Half the drift angle, at most 25°, from 5 m/s, full by 40 m/s, eased over 0.6 s; fades out as the drift goes from sideways to straight backwards | Keeps drift readable, never flips side to side in a spin |
| Chase clearance | 0.5 m from anything in the way, eases back out over 0.5 s | No clipping |

**How the cruise drive works (first values, to be tuned with the owner)**

- F starts the cruise drive charging (2 s, the ship flies normally meanwhile); F again, or X, cancels it.
- Once charged it takes over the speed and goes where the nose points; the mouse still steers. Flight assist stays on and the thrust keys and Z do nothing until it drops out.
- Its speed is the distance to the nearest surface divided by 6 s, from 300 m/s up to 5 km/s: fast in open space, slowing smoothly on the way in, so a trip across the system takes about half a minute and always ends with a few seconds of approach.
- It drops out by itself on arriving at a place (inside the place's arrival zone), leaving the ship at 200 m/s, which flight assist then holds. F drops out at once; X drops out and brings the ship to a stop.
- It never runs into anything: if it would reach a surface in under 2.5 s it drops out at 50 m/s, and a bump drops it out and lets the ship come to rest.
- Leaving a place never counts as arriving there: a place the ship is at when the drive engages counts again once the ship is 250 m beyond its zone.
- It won't engage inside the asteroid belt or among a base's buildings (within 150 m of Tollgate), or when the nose points at something it would reach within 5 s; a message says what is in the way.
- In cruise the dashboard and HUD show "CRUISE · F to drop out" and the speed in km/s, and the space dust fades out (it can't show such speeds) while a coarser cruise dust, specks kilometres apart, fades in so the speed still reads.
- Every place has a marker on the HUD with its name and distance (to the surface, or to the belt's home pocket), so the player can point at it and go.
- **Which markers show** (added at the owner's request, 2026-10-25, because names cluttered the screen): two settings on the settings menu's Interface page, "Place markers" (the diamonds) and "Place names" (the name and distance), each Always, Near or looked at, or Off. Near or looked at shows a place that is within 5 km, whose marker is within 10° of the middle of the view (it stays until 14°, so a name at the edge doesn't flicker), that the nose is aimed at for a lock, or that the cruise drive is locked onto. Markers start on Always and names on Near or looked at. Diamonds and names fade in and out over 0.25 s rather than popping. With markers Off, the place aimed at for a lock still gets its corner brackets (blue when locked). The values are in `game/hud/landmark_markers.gd`.
- **Locking on** (added at the owner's request, 2026-10-25): with the nose within 4° of a place's marker (the nearest one, if several), or else anywhere on a place's disc (a planet or moon, or a station close up), that marker is framed in corner brackets and the HUD offers "F  Cruise" (not while docking or landing is offered, where G is what matters). F then locks the drive onto it: once charged it flies there by itself and the player can sit back. The travel heads for the place (following it over 0.4 s, as when steering), and the nose is turned to follow the travel (closing the angle in 0.6 s), so the place stays ahead in the cockpit window. The locked place's marker turns cruise blue, the readout says "CRUISE LOCKED · F to drop out" and the dashboard (and the chase view's plate) shows "TARGET  Mote · 12 km · 18 s".
- **Time to arrival** (added at the owner's request, 2026-10-25): locked on, the target line ends with about how long
  until the drive arrives, in whole seconds rounded up ("1 min 20 s" from a minute; trips over ten minutes, which this system doesn't have, show no time). It is
  worked out by flying the rest of the trip ahead the way the drive will fly it (the rest of the charge, the way round
  anything in the way, slowing on the way in), afresh every second, and counts down in between; on test trips it is
  within a second of the real time.
- Locked on, it only drops out on arriving at that place: it flies on through other places' zones (so a trip to Tollgate doesn't stop at Calder). A planet, moon or station in the way is flown round, along the shortest way and a planet's radius above it (never closer than its arrival zone): the drive heads along the line that just touches that clearance, follows it, and goes straight once the way is clear. A base on a planet's surface is flown at straight once it is seen at least 15° above its horizon; from lower, or from the far side, the drive goes round the planet first and comes down at it from above. The safety drop still holds.
- Moving the mouse (more than 15% of a full stick push, as with orbit), while the drive charges or cruises, releases the lock, "Lock released · steering yourself": the drive then charges or carries on where the nose points, as without a lock. F or X drop out as usual. Rolling with Q/E doesn't release it. Taking over while inside another place's zone doesn't drop out there (it counts as left behind, like a place the drive starts at), and a ship that reaches its target while still charging has simply arrived. With nothing aimed at, F cruises where the nose points, exactly as before. A place the ship is already at (inside its arrival zone) can't be locked onto.

**Cruise drive tuning**

The values live in `game/ship/greybox_cruise_tuning.tres` (per ship, so an engine upgrade can change them later).

| Value | Greybox ship | What it does |
| --- | --- | --- |
| Charge time | 2 s | From F to taking over |
| Slowest and fastest | 300 m/s to 5 km/s | Always faster than normal flight (200 m/s) |
| Approach time | 6 s | Speed is distance to the nearest surface over this |
| Ramp time | 1.5 s | How quickly the speed follows that |
| Turning | 0.4 s | How quickly travel follows the nose |
| Exit speed | 200 m/s | Held by flight assist after arriving or F |
| Safety | 2.5 s to a surface, then 50 m/s | Drops out before any collision |
| Engage look-ahead | 5 s | Won't engage when the nose points at something it would reach this soon |
| Bump limit | 3 m/s | A harder knock drops it out |
| Rumble | 0.3 of full thrust | Camera shake while cruising |
| Lock cone | 4° | Nose this close to a marker (or on a planet's disc) locks on with F |
| Lock turning | 0.6 s | How quickly the nose follows a locked course |
| Clearance | 1 radius above a planet, moon or station, at least its arrival zone | Locked on, how wide it goes round things in the way |
| Approach angle | 15° | Locked onto a base, it flies straight at it once it sees it this high over its horizon |

**How orbit works (first values, to be tuned with the owner)**

Added at the owner's request: a ship can park in orbit round a planet or moon and stay there. It is a simple mode, not
a simulation: the game has no gravity, so nothing ever falls out of orbit. It keeps the parts of a real orbit a
player can feel, simply: the orbit is up in space, well clear of the air; you get there by climbing to it and turning
along it, like a launch; and going round is slow and calm, the ground drifting past below.

- Each planet and moon has one orbit line, a circle at its orbit height (Calder 3 km up, Mote 1.2 km). From a
  quarter of that height above the surface (so not on take-off or while landing) up to twice it, the orbit shows the
  way there: the line itself, a faint lane round the planet in the orbit's colour, brighter at its edges, in the plane
  the ship would go round in (the way it is heading; it swings round no faster than 15° a second, so small turns and
  wobbles leave it still and a real turn swings it smoothly); and on the HUD a small ring with ticks where the ship would join it ahead, labelled "Orbit  ·  climb 1.2 km" (or "descend"; on the line, "slow down" or "level out" until O
  would work, then just "Orbit").
  The ring is as far ahead as a 30° climb would take to reach the line (at least 400 m ahead), so flying at it is a
  gentle climb into orbit. Off the screen it waits at the edge on the side to turn to. The lane fades out near the
  camera, so it never cuts across the cockpit, and the planet hides its far side.
- "O  Enter orbit" shows only close to the line: within 600 m above or below it round Calder, 300 m
  round Mote, so never near the surface or just after taking off. O anywhere else says how far to climb or descend.
  O swings the ship onto the line shown, the way it was heading, and it settles onto the line's height (climbing or sinking
  at most 30 m/s). The swing is no harder than the side thrusters (25 m/s²), so it feels like a firm push, never a
  snap.
- Entering, the ship turns to face along the orbit with the planet below and the horizon a little above the middle of
  the cockpit window, so the planet fills the bottom of the view, and keeps that view while it settles onto the line.
  Moving the mouse stops that turn and leaves the view to the pilot.
- In orbit the ship goes round at the body's orbit speed, holding the line's height, and its view turns with the
  orbit, so the planet stays where it is in the window while the ground slides past. The mouse still turns the ship.
  The dashboard shows "IN ORBIT · O or thrust to leave". The line and its ring are hidden while in orbit, cruising,
  docked or landed.
- O again or any thrust key leaves orbit gently. The ship carries straight on at the velocity it had while its nose
  comes up level along it over 1 s, longer for a bigger turn so it never turns faster than the ship can ("LEAVING
  ORBIT · levelling out"), then flight assist holds that velocity. In orbit
  the nose is dipped toward the planet (more the higher the orbit), so without the level-out the ship would follow its
  nose down into the ground; with it, it flies on level and climbs slowly away. Moving the mouse while it levels out
  hands the ship straight back.
- X (which then stops), Z (which then drifts) or the cruise drive engaging leave orbit at once, keeping the velocity
  the ship had. A hard bump knocks it out of orbit.
- It won't enter while cruising, above 250 m/s, or climbing or diving so steeply that stopping it would carry the
  ship out of the window round the line; a message says why.

Why these speeds: what makes an orbit look fast is how quickly the ground below sweeps across the view, its speed
over its distance. From the real space station that is about 1° a second, which is why its videos look so calm. The
first orbits here were offered from 500 m up at 90 m/s, about 10° a second, and still over 3° a second at 1.5 km up,
on a planet only 6 km in radius. The planets keep their size (the whole compressed system, the cruise drive and
landing are built round it); instead the orbit is higher and slower, back to about 1° a second.

**Orbit tuning**

The ship's values live in `game/ship/greybox_orbit_tuning.tres` (per ship); each planet's and moon's in the solar
system scene (`game/system/solar_system.tscn`).

| Value | First value | What it does |
| --- | --- | --- |
| Calder's orbit | 3 km up, offered 2.4 to 3.6 km up, 45 m/s | About 21 minutes round; the ground below sweeps about 0.9° a second |
| Mote's orbit | 1.2 km up, offered 0.9 to 1.5 km up, 20 m/s | About 14 minutes round; about 1° a second |
| Guide reach | A quarter to 2 times the orbit's height | Where the orbit line and its ring show (Calder 750 m to 6 km up, Mote 300 m to 2.4 km) |
| Guide swing | 15° a second | How fast the line's plane follows the ship's heading |
| Insertion point | A 30° climb ahead, at least 400 m | Where the ring sits on the line |
| Top entry speed | 250 m/s | Anything but cruising |
| Swing onto the orbit | 25 m/s² | No harder than the side thrusters |
| Too steep | Stopping the climb or dive would leave the window | Refuses rather than overshoot |
| Height correction | Closes a gap over 4 s, at most 30 m/s; settled within 5 m | Onto the line; holds the height |
| Horizon | 5° above the middle of the view | Where the turn on entering puts it |
| Turn on entering | Closes the angle over about 0.8 s, done within 0.5° once settled | Within the ship's own turn limits |
| Bump limit | 3 m/s | A harder knock leaves orbit |
| Level out on leaving | 1 s, easing in and out; longer if the turn would beat the ship's turn rates | O or thrust: nose up along the velocity before flight assist takes over |

**Nav computer (first values, to be tuned with the owner)**

Added at the owner's request (2026-10-25, concept A of three): a screen on the dashboard where the pilot picks where to
go and how to arrive, and the ship flies it. It only gives the orders a pilot would (turn, thrust, F, O, G), so
everything it does follows the same rules and messages as flying by hand.

- Tab opens it. In the cockpit it lights up on the dashboard, in front of the speed screen and wider than it (its top
  line repeats the speed and flight assist), and the mouse is let go so it can be clicked; in the chase view the same screen shows as a card at the bottom left. Tab
  closes it and takes the mouse back. Esc pauses as always (and closes it). The ship keeps flying while it is open.
- **Where to:** the places that have a marker (Calder, Mote, Halfway Station, The Shingle; bases are reached through
  their planet), with their distance. Up and Down, or a click, picks one.
- **Arrive:** the ways the picked place can be arrived at, in a word or two like every prompt in the game (the
  owner's rule, 2026-10-25: "G Dock", not "G Dock at Halfway Station"). Left and Right, or a click, picks one. A
  station: "Dock". A planet with a base: "Land" (with several bases, one button per base, named). A planet or moon:
  "Orbit". Anywhere: "Stop nearby" (cruise there and drop out).
- **Go** (Enter) replaces the plan with that order and starts flying it. **Add** (Shift+Enter) puts it at the end of
  the plan. Each button shows its key first: "Enter Go", "Shift+Enter Add", "P Pause", "Backspace Clear". An order becomes steps: "Cruise to Tollgate" then "Land at Tollgate"; "Cruise to Mote"
  then "Enter orbit round Mote". Leaving a dock or pad comes first by itself ("Undock from Halfway Station", "Take
  off from Tollgate"), including between a docking and the next cruise in a queued plan. Ordered while the docking
  computer is taking the ship in, the plan lets it finish, then leaves. A plan holds up to 8 steps;
  the screen shows 3 on the dashboard and 5 on the card, then "+ 2 more".
- **How each step is flown:** undocking or taking off presses G. A cruise turns the nose onto the cruise drive's
  course and presses F with the drive locked onto that place, so it flies round what is in the way and drops out on
  arriving, as a lock does; starting by a station or base it first climbs 150 m clear so the drive will engage.
  Orbit flies toward the planet or moon and then at the insertion ring on its orbit line, at 80% of the top entry
  speed, presses O as soon as orbit is offered, and is done once the orbit has settled. Docking or landing flies toward the port, slowing to 80 m/s as it
  reaches the docking offer, presses G and lets the docking computer take it in.
- **The plan:** the screen lists the steps, "NOW" on the one being flown, and says what it is doing ("Lining up for
  Tollgate", "Cruising to Tollgate", "Slowing down for Halfway Station"). With the screen closed, a strip at the top
  of the HUD says the same: "NAV 1/2 · Cruising to Tollgate · P Pause".
- **The pilot always wins:** any thrust key, moving the mouse (more than 15% of a full stick, as with orbit and the
  cruise lock), or F, O, G, X or Z pauses the plan and leaves the ship exactly as it is: "NAV PAUSED · You took the
  controls · P Resume". Rolling with Q/E doesn't pause it. P pauses and resumes at any time, open or closed.
  Something the ship can't get past (the cruise drive's safety drop or a bump, a refused cruise, a docking stopped by
  a bump, being knocked out of orbit) pauses it with the game's own message. It only presses G or O once docking or
  orbit is offered, so those are never refused. A step that gets nowhere for 90 s pauses with "taking too long · fly
  closer". Backspace clears the plan.
- The plan is not saved; a loaded game starts with an empty plan, and being towed home drops it. Clearing it leaves
  the ship as it is (a cruise carries on).

**Nav computer tuning**

The values live in `game/nav/nav_tuning.tres`.

| Value | First value | What it does |
| --- | --- | --- |
| Turning | 0.8 s | How quickly it turns the nose to where it is going (within the ship's turn rates) |
| Aim before cruising | 5° | Presses F once the nose is this close to the drive's course; the lock does the rest |
| Turning before speeding up | 20° | Doesn't push forward while the nose is further than this from the way |
| Throttle | Full at 10 m/s off the speed it wants | How firmly it holds a speed |
| Clearance before cruising | 150 m from a station's or base's surface | The drive won't engage among buildings |
| Closing in on a dock or pad | Arrives at the docking offer within 8 s, at 80% of its top speed (80 m/s) | Fast from far away, never too fast to dock |
| Lining up for orbit | 80% of the top entry speed (200 m/s) | Always under the orbit limit |
| Giving up | 90 s on one step | Pauses with a message rather than flying forever |
| Plan length | 8 steps | Keeps the screen and the strip readable |

## Contracts

All jobs come from one contract system built on three verbs. Job types are variations on those verbs.

| Verb | Job types |
| --- | --- |
| Fly from A to B | Porter (packages), cargo delivery, taxi (passengers) |
| Shoot or capture | Security patrols, chasing fugitives, bounty hunting, blasting asteroids |
| Land and interact | Asteroid surface mining, science tasks, station work |

**Rules**

- Combat is never required. Players can play the whole game without firing a weapon.
- Each contract shows its goal, reward and a short task list.
- No contract should need more than a few steps to understand.

**Contract chaining:** players can stack contracts along one route (a delivery, a passenger and a mining stop) and earn a bonus for finishing them in one run.

**Reputation:** each job type has its own reputation. Higher reputation unlocks better-paying and rarer contracts in that line of work.

**Passengers with personality:** taxi fares chat, ask for the scenic route, tip for smooth landings, or occasionally turn out to be fugitives.

**Science jobs** must be interactive, never box-ticking. Each step is a small hands-on action: aiming a scan sweep, drilling a sample on a timing bar, turning a valve. Waiting is skipped with a sleep or end-of-shift button, never real-time.

## On-foot play

The player leaves the ship only when it adds something, never for routine steps.

| Activity | On foot? |
| --- | --- |
| Delivery / porter | No. Cargo transfers automatically on docking. |
| Taxi | No. Passengers board and leave on their own. |
| Security / bounty | No. Ship combat only. |
| Blasting asteroids | No. Ship-mounted mining laser. |
| Mining on an asteroid's surface | Yes. A handheld tool reaches richer deposits. |
| Science | Yes. Space walks, station tasks, field sampling. |
| Bases and stations | Optional. Walk into a small hub, or use a cockpit terminal once docked. |

The hand-off between flying and walking (leaving the seat, exiting the ship) should feel smooth and quick.

On-foot tasks are built as small modules (drill, collect, carry, scan) so helper robots can take over individual pieces later.

## World

The game takes place in one hand-built solar system, compressed so travel never drags.

**Planets and moons**

- Any planet or moon a player could realistically land on can be landed on.
- Each has a distinct look and feel: its own environment, weather and one gameplay twist (eruptions on a lava world, sliding on an ice moon, fuel skimming at a gas giant).
- Each has one base to rest, buy and sell, take and finish jobs, and pay the loan.
- Planets are mostly empty, with points of interest (wrecks, science sites, deposits) to give landings a purpose.

**The tiny solar system (first playable, first values)**

One self-contained scene, `game/system/solar_system.tscn`, compressed to these sizes in metres. Its origin is Calder's centre and the belt lies in Calder's equator plane. The bodies hold still for now (no orbits). The sun, Sorrel, is the light and the disc in the sky, not a place to fly to.

| Place | What it is | Size and place | Arrival zone |
| --- | --- | --- | --- |
| Calder | The planet: blue seas, green land, ice caps, a thin blue glow of air | 6 km radius, at the centre | 2 km above the surface |
| Tollgate | Calder's base: a landing pad, hangar, tower and beacon, all within 150 m of the pad | On Calder's surface, on the side facing the station | 4 km |
| Halfway Station | The space station: a spine, a ring, solar panels and a docking bay with a green frame | 16 km from Calder's centre, 10 km above its surface | 2.5 km |
| Mote | The moon: grey, airless | 1.5 km radius, 31 km from Calder, above the belt's plane | 1.5 km above the surface |
| The Shingle | The asteroid belt: a ring of rocks round Calder | 50 km radius, 6 km wide, 800 m thick | 1.5 km from the band |

- The player starts 2 km from Halfway Station with Calder ahead.
- The Shingle's rocks come from the world seed: 3000 scattered round the ring and 10 dense pockets of 220, each rock 15 to 110 m in radius (small ones commonest). The first pocket is authored: on the band's inner edge, the one its HUD marker points to. Values in `game/system/shingle_belt.tres`.
- Only the rocks within 2.5 km of the ship are solid (a pool of 48 spheres, picked again every 10 ticks; a sphere stays on its rock while that rock stays near); all are drawn, in 64 pieces round the ring, as lumpy rocks within 9 km and simple shapes out to 70 km, with a faint haze along the band beyond that.
- Calder and Mote are drawn as fine spheres close up and coarse ones from far away (past 40 km and 15 km). The station and base lose their detail at 12 km and 20 km. Everything is visible to 150 km.

**Landing:** seamless, with no transition or loading screen (the owner's call, 2026-10-25). Until the owner says otherwise: approach the planet, see a prompt to land, press it, and the ship flies itself down onto the base's pad while the player watches. Docking works the same way.

**How docking and landing work (first values, to be tuned with the owner)**

- Halfway Station has an open docking bay on top of its spine, its mouth framed in green. Tollgate has a landing pad.
  Each is a port: where the ship is held while docked or landed. The docked ship sits on the bay's floor, and the
  landed ship on the pad, not hovering over them.
- Each port shines a faint light along its way in, so the pilot can line up by eye before pressing G: a soft green
  beam straight out of the bay's mouth along the line in, and a thin cyan beam straight up from the pad. Each brightens
  while the ship is lined up in the port's lane, and while the ship flies itself in. The pilot can fly all the way in
  by hand; G is still what docks or lands.
- Near a port the HUD says what to do: "Fly within 1.5 km to dock (2.3 km)", then "Slow below 100 m/s to dock", then
  "G  Dock". Landing works the same way, counted from the pad, but only close to it, never from orbit or high over
  the base: "Fly within 600 m to land (3.1 km)", then "G  Land". The prompts stay short (the owner asked for "G  Dock",
  not "G  Dock at Halfway Station"); the place is named by its marker and on the dashboard. Nothing is offered while
  the cruise drive charges or runs.
- Flying by hand, the HUD warns "SLOW DOWN  ·  Halfway Station in 4 s" (or the planet, moon, base or belt, or
  "Obstacle") in red above the prompts while the ship is coming at something faster than it could comfortably stop:
  anything along its velocity nearer than it would take to stop using half of its weakest thrusters' push (25 m/s²
  on the greybox ship), plus one second at its speed. So at 100 m/s it warns 500 m out, at 50 m/s 150 m out, at
  20 m/s 36 m out, and never below 6 m/s. Not while cruising (the cruise drive keeps itself clear), in orbit or while
  the ship flies itself.
- G hands the ship to its docking computer, and it flies itself in, in real time: no fade, no loading screen, and the
  camera never cuts. The pilot watches from the cockpit or the chase camera (V still switches). The dashboard shows
  "DOCKING · G to cancel" (or "LANDING"), and the HUD "Docking at Halfway Station · G to cancel".
- The docking computer carries on from where the ship is and how it is moving when G is pressed (the owner's call,
  2026-10-25: "the docking/landing assist should proceed from the player's location and velocity ... shouldn't speed up
  significantly"). It can slow down, but never goes more than a quarter faster than the ship was going. So a
  ship at rest still gets there, it may go fast enough to arrive in about 30 s, but no faster than 40 m/s for that
  (and never slower than 5 m/s): slow and close in, it stays slow; at rest 1.5 km out, it goes 40 m/s. Pressed low
  over the planet, it never climbs higher than it must: the pad's gate sits at the ship's own height, but no lower than
  120 m (above Tollgate's tower).
- The way in has two legs. First the ship flies to the port's gate: 180 m out in front of the bay's mouth, or 250 m
  above the pad (lower when the ship is lower, as above). It goes round the station or the planet rather than through them, keeping at least as far from
  their centre as the gate is, so it clears the station's ring and panels and Tollgate's tower. Starting nearer than
  that (low by the base, or tucked in by the station), it first climbs out, away from the bay or pad as well, feeling
  ahead for anything in its way and sliding along it (up the inside of the station's ring and over it rather than
  through a spoke); coming in fast, it brakes before it gets that near. Only a ship already in the port's lane
  (anywhere inside the bay or in front of its mouth, or within 40 m of the line down to the pad) goes straight in from
  where it is.
  It faces where it is going, then, from 600 m before the gate, turns to face along the final leg. At the gate it
  eases round the corner onto the final leg: into the bay nose first, so the pilot watches the bay come up round
  them, or straight down onto the pad already facing the hangar, slowing all the way. If it isn't lined up yet, it
  waits 60 m short until it is, so it never goes in crooked. In the bay it comes in down the middle of the mouth,
  stops 15 m short of the berth, turns round in two quarter turns (a yaw, never a flip), eases back over the berth, so
  the docked view looks out of the mouth, and settles straight down onto the floor (about 6 s). It touches down
  softly, which the camera feels as a gentle bump.
- Its pushes are the ship's own (the main engine's 40 m/s², the ship's turn rates), so the pilot's head sways and the
  engines rumble as in normal flight. Within its speed limit above, it goes faster the farther it has to go, slower
  the closer it goes round a planet or station, and gently (6 m/s²) on the final leg. From the edge of the docking
  offer at 80 m/s it takes about 40 s (the turn round and settling in the bay are about 14 s of that), at 10 m/s
  about 55 s; landing from 60 m up at the edge of the landing offer at 50 m/s about 18 s, from rest there about 30 s.
  Flying closer, or faster (up to 100 m/s), by hand before pressing G makes it shorter.
- G (cancelled) or X (cancelled, then a full stop) hands the ship straight back, as it is moving; so does a bump on
  the way ("Bump! Docking stopped. G to try again"), and the ship then comes to rest. Cancelled on the final leg, it
  comes to rest too, rather than carrying on into the bay or down onto the pad.
- Once there, the ship is held still in the bay, looking out of its mouth (or on the pad, facing the hangar), and the
  HUD says "Docked at Halfway Station · Game saved". The dashboard shows "DOCKED · G to undock" or "LANDED · G to
  take off".
- G again leaves: in the bay the ship first lifts gently off the floor to the middle of the mouth (about 6 s), then
  is eased straight out of the bay (or straight up off the pad), speeding up evenly, then handed back with flight
  assist holding the speed it left with (25 m/s out of the bay; a hover above the pad).
- Every docking and landing goes through one arrival function (`Arrivals.arrive`), which tells the rest of the game
  through the event bus (`Events.arrived`). The autosave listens there and writes the game; contracts will too. How
  the ship gets to its berth (`Approach`) can change without touching them.
- Mote has no landing site yet; landing on it comes with surface mining.

**Docking and landing tuning**

How the ship flies itself in lives in `game/arrival/arrival_tuning.tres`; each port's values on the port itself, in
the station's and base's scenes (`game/system/greybox_station.tscn`, `game/system/greybox_base.tscn`).

| Value | First value | What it does |
| --- | --- | --- |
| Docking offered | Within 1.5 km of the bay, below 100 m/s; hints from 3.5 km | The cruise drive drops out about 2.8 km away |
| Landing offered | Within 600 m of the pad, below 100 m/s; hints from 8 km | Only near the pad, never from orbit; a cruise to Tollgate ends about 4.2 km away, inside the hint |
| Gate | 220 m out from the berth in the bay (180 m in front of its mouth); 250 m above the pad, or the ship's own height if lower, but at least 120 m | Outside everything at the station, above Tollgate's tower (87 m with its beacon); a low ship never climbs more than it must |
| Speed on the way | At most 1.25 times the ship's speed when G was pressed, but at least its way in over 30 s, from 5 to 40 m/s (never over 400 m/s), slowing at 20 m/s²; going round, no faster than half of 40 m/s² can curve it; tucked in among the station's parts, at least 40 m/s on the way out round them | Carries on from the pilot's own speed, never racing off |
| Berths | The bay's on its floor (15.75 m under the middle of its mouth); the pad's on the pad; the ship's underside 5 cm above each | Sits on the ground, not hovering |
| Settling in the bay, lifting off it | Straight down (or up) 15.75 m at up to 4 m/s, speeding up and slowing at 2 m/s², touching at 1.5 m/s; within 0.2 m over the berth. A ship already low in the bay's lane flies in at its own height (at least 3 m up) and settles from there | About 6 s each way, gentle; G pressed on the floor never climbs first |
| Guide lights | Bay: green, 2.5 m round the line in, from its mouth to 400 m out; pad: cyan, 2 m round, straight up 400 m. Faint (strength 0.3), brighter (0.7) while lined up or flying in, easing over 0.4 s; fading out toward the far end and within 30 m of the camera; drawn only within 8 km | Line up by eye; never dazzles when flown through |
| Speed warning | From 6 m/s: anything along the velocity within the stopping distance at half the weakest push (25 m/s² on the greybox), plus 1 s at its speed, swept with a 3 m ball | Warns early enough to brake; quiet when slow or flying alongside things |
| Corner onto the final leg | Starts 80 m from the gate, at 40 m/s | Comes onto the line well before the berth |
| Final leg | Slows at 6 m/s² to touch at 1.5 m/s; waits 60 m short until within 1.5° and 1 m of the line | Never goes in crooked; the touch is a soft bump |
| Turning to face along the final leg | From 600 m before the gate, closing the angle over 0.8 s within the ship's turn rates | Lined up before the final leg |
| Lane | The bay's inside and the space in front of its mouth (25 m either side, 17 m up and down from the middle of its mouth, back to 25 m behind the berth); 40 m round the line over the pad | A ship within it goes straight in; elsewhere it goes to the gate first |
| Turning round in the bay | 15 m short of the berth, two quarter turns (the second from within 10° of the first) | Faces out of the mouth, never flips over |
| Pushes | 40 m/s² (the main engine's) | The head sway and engine rumble feel like flight |
| Feeling ahead | Climbing out from inside the gate's distance: its stopping distance and 20 m more, for a ship reaching 8.5 m from its middle (its wingtips) | Slides along whatever is in the way instead of into it |
| Bump limit | 3 m/s | A harder knock stops the way in |
| Leaving the bay | Lifts off the floor (about 6 s), then 60 m, speeding up to 25 m/s (about 5 s) | Clear of the bay's mouth before the pilot has it |
| Taking off | 30 m straight up, speeding up to 15 m/s (about 4 s) | Then flight assist brings it to a hover |

**Saving and the tow home**

- The game saves itself on every docking and landing, and every 3 minutes of play in flight (paused time doesn't
  count), so quitting or a crash never loses more than that. A save in flight waits until the ship is flying freely
  or settled in orbit: not while the cruise drive charges or runs, the ship swings into orbit or levels out of it, or
  it flies itself in to a berth or out of one. Its file is written in the background, so it never holds up a frame.
- The save holds the world (seed, clock, random streams), the berth ("" in flight), home (the last port the ship
  arrived at), and the ship: which one, where it is in the solar system's own coordinates, which way it faces, how it
  moves, flight assist and the orbit it is settled in (the planet or moon, its height and its axis). Loading (being
  built with the start menu) is to put the ship back exactly there, in space too.
- "Tow me to base" on the pause screen puts the ship straight back at home (the nearest port if it has never docked
  or landed), whatever it was doing, through the one arrival function, so it is docked or landed there and the game
  saves. It asks for a second press first. It isn't offered while docked or landed. It is free until money exists;
  then it costs the towing fee, a small amount set with the economy.

**Authored vs. seeded**

| Authored (same every game) | Seeded (varies by seed) |
| --- | --- |
| Planets, moons, orbits | Asteroid fields |
| Bases and stations | Derelicts and points of interest in space |
| Planet environments | Pirate and hostile spawns |
|  | Comets and random events |
|  | Contract offers |

**Random events:** distress calls, comet flybys, eclipses, lost cargo pods, derelicts with small puzzles.

**Radio and comms:** in-ship radio with music and news that reacts to what the player has done.

**Photo mode:** pause, free camera, filters and capture.

## First playable scope

The goal of the first playable is to prove that flying, delivering and mining are fun in a tiny world.

**In scope**

- [ ] One planet with a base, one moon, one space station, one asteroid belt
- [ ] One ship with a first-person cockpit
- [ ] Newtonian flight with flight assist on/off and a velocity marker
- [ ] Third-person chase camera while flying
- [ ] Cruise drive between locations
- [ ] Docking at the base and station
- [ ] Seamless docking and landing: a prompt, then the ship flies itself in, with no transition or loading screen (the owner's call, 2026-10-25)
- [ ] Parking in orbit round a planet or moon with an "Enter orbit" prompt (added by the owner, 2026-10-24)
- [ ] Contract board with two job types: delivery and asteroid mining
- [ ] Ship mining laser for blasting asteroids
- [ ] On-foot controller: walking into the base and mining on an asteroid's surface
- [ ] Loan with payments at the base
- [ ] Shop with 3–4 upgrades
- [ ] Save and load

**Out of scope for now:** the other two starter ships, combat, taxi, science, reputation, radio, random events, photo mode.

## Technical notes

A few early decisions avoid costly rework later.

- **Large-world precision:** space scenes jitter far from the origin. Plan a floating-origin system or use Godot's double-precision build from the start.
- **One arrival function for landing:** route all landings and dockings through a single function that places the ship at its berth and tells the rest of the game. How the ship gets there (today it flies itself in, seamlessly) can change without touching jobs, bases or saves.
- **Two controllers with a clean hand-off:** a ship controller and an on-foot controller, with entering and leaving the seat as one well-defined transition.
- **Data-driven contracts:** define contracts as data (verb, origin, destination, reward, steps) so new job types need little new code.
- **Modular on-foot tasks:** drill, collect, carry and scan as separate pieces, ready for helper robots later.
- **Self-contained solar system scene:** keeps a future multi-system universe possible without designing for it now.
- **Seeded generation:** one seed drives every random element so a world can be reproduced.

## Player wiki

The GitHub wiki (<https://github.com/ggbillyjoe3526/project-praesepe/wiki>) documents the full game for players. It is
written for players, not developers, and kept current as the game changes.

- **Home:** what the game is and what the current build lets you do.
- **Patch notes:** what changed in each version, newest first, generated from the changelog (with the notes waiting
  for the next release at the top).
- **Getting started:** the first flight; later the first hour, choosing a starter ship and paying off the loan.
- **Controls:** every key.
- **Flying, Cruise drive, Docking and landing, Orbit:** how each works, in the words the game uses.
- **Ships:** every ship with its role, stats, upgrades and how to get it.
- **Contracts and jobs:** each job type, how it works, rewards and reputation (a page once the first job ships).
- **Locations:** planets, moons, stations and bases, with their environments, services and points of interest.
- **Items and upgrades:** what each upgrade does and where to buy it (a page once the shop ships).
- **Events and encounters:** random events, distress calls, derelicts (a page once events ship).
- **Settings and accessibility:** options, comfort settings, key rebinding.
- **Roadmap:** what is being built and planned next, with no promised dates.
- **FAQ and troubleshooting:** common questions, saves, known issues.

**How it stays current:** the pages live in the repository under `docs/wiki/` (one Markdown file per page; its
`README.md` has the conventions) and a workflow publishes them to the wiki on every merge to `main`, so edits made on
GitHub are overwritten. Every pull request a player would notice updates its page in the same pull request, alongside
its changelog note. A check on every pull request fails on broken links or pictures, a page missing from the sidebar,
or a place (any `display_name` in the game's scenes and resources) that no page describes (the Roadmap doesn't count), and warns when a changelog
note arrives without a wiki change.

**What it describes:** the newest development build, what is on `main` (the owner's call, 2026-10-25). Features still
being built or planned go on the Roadmap page, never on other pages as if they were playable. Patch notes keep
released versions apart from what is waiting for the next download.

## Future roadmap

The core game comes first. These ideas follow once the first playable is fun, roughly in this order.

1. **Core game:** all three starter ships, every job type (taxi, security, bounty, science), reputation, passengers with personality, contract chaining, random events, radio, photo mode, the full solar system.
2. **Owning more:** buy more ships (outright or on loan), a hangar to store them, buy a station or outpost (bought, not built).
3. **Automation:** helper robots for on-foot work (mining, survey, cargo and repair bots), then hired pilot agents to run other ships.
4. **Expansion:** a jump gate or flight route to new areas, then a universe of predefined solar systems placed by seed.
5. **Later polish:** walkable ship interiors, a codex of discoveries, a third-person on-foot view.

## Decisions log

Newest first. Each line: date, the decision, who made it.

- 2026-10-25: The test ship gets a placeholder model in place of the greybox: small, light grey with orange panels, a
  flat windscreen sloping down to the nose in front of a taller back half, flat side and roof windows with no frame bars
  in the pilot's view, and a slim dashboard low across the bottom (William's references and notes; he turned down a
  curved bubble canopy and approved v002) (owner). The collision shapes follow the new shape; mass, centre of mass,
  inertia, the eye, the chase camera and the underside stay where they were (default, Claude).
- 2026-10-25: A nav computer to give the ship orders: William asked for "an on screen UI menu" that is "a cockpit instrument" in the cockpit and "a ui element but not too obtrusive" in the chase view, for "destinations, landing/take off assist, entering or leaving orbit", where "the player can queue orders/actions for the ship", and chose concept A (the nav computer screen) of three concepts (owner). Until the owner tunes it: behaviour and values as in "Nav computer"; Tab opens it, arrows pick, Enter goes, Shift+Enter adds to the plan, P pauses and resumes (R is rolling upright), Backspace clears; it flies only through the pilot's own controls (F, O, G, turn and thrust); any pilot input pauses the plan; landing at a base cruises to the base rather than going into orbit first; the ship keeps flying while it is open; the plan is not saved (default, Claude).
- 2026-10-25: A title screen with a start menu (Continue, New game, Settings, Quit), and a new game starts by choosing the ship, then docked at Halfway Station; loading a save puts the ship back where it was saved, even out in space ("if a player saves out in space then they return to those coordinates and not back at a station") (owner). Until the owner says otherwise: the one ship of the first playable is the Hauler, because its jobs are deliveries and mining; a new game saves at once; a new game over a saved game asks first (and isn't offered over a save another program holds or a newer version's); quitting to the title or the desktop saves first; a ship continued out in space carries on at its saved speed and spin; the title screen is a starfield, not the solar system (default, Claude).
- 2026-10-25: The three buoys (grey posts with an orange lamp) between the start and Halfway Station are gone: they were left over from the first flight test, when the sky was empty and they showed movement; the planets, station, belt and space dust do that now. William asked for them to be removed (owner).
- 2026-10-25: Four conveniences join the first playable: the time to arrival next to the distance while the cruise
  drive is locked on, an F12 screenshot key, holding the right mouse button to look round the cockpit without steering,
  and a key that rolls the ship upright against the nearest planet or moon. William approved them from a list of
  quality-of-life ideas (owner). Until the owner tunes them: R is the roll-upright key, it works anywhere against the
  nearest planet or moon (by distance to its surface) and also with flight assist off; looking round reaches 140° to
  either side, 70° up and 45° down, and in the chase view swings the camera round the ship; screenshots go to
  `screenshots` in the user folder named `praesepe_<date>_<time>.png`; values as in "How it flies" and "How the
  cruise drive works" (default, Claude).
- 2026-10-25: The player wiki describes the newest development build (what is merged to `main`), not only released builds, and is updated in the same pull request as each player-facing change: William asked for a wiki "kept up to date as the game is developed. For example, when a new feature/content or any important is changed it will update the wiki." Pages live in `docs/wiki/` and are published to the GitHub wiki on every merge, as in katanashotgun; work still being built or planned stays on the Roadmap page (owner asked; the publishing setup default, Claude).
- 2026-10-25: Version names and tags: players see "0.1 Dev 1", "0.1 Beta 2", then "0.1", tagged `v0.1-dev.1`, `v0.1-beta.2` and `v0.1`, like the owner's katanashotgun; Dev and Beta are GitHub pre-releases. William chose this on 2026-10-25 (owner). A tag on main (or the Release workflow's button) publishes a Windows installer and a portable zip; steps in `RELEASING.md` (default, Claude).
- 2026-10-25: Autosave every few minutes in flight as well as on docking and landing, and a "Tow me to base" button on the pause screen, free until money exists and then the towing fee (owner approved both, 2026-10-25). Until the owner tunes them: every 3 minutes of in-game time; the tow goes to the last port the ship arrived at, or the nearest if none, asks for a second press, and is not offered while docked; the save file goes to version 2 (old saves are brought up to date when read) (default, Claude).
- 2026-10-25: Orbit is up in space and slow: William asked that the orbit prompt "only appear while in space near the orbital trajectory", that orbit be "as realistic as possible while keeping the game simple and easy to control", maybe with "a visual indicator ... that shows the player an orbital insertion route or point", and said orbiting "feels way too fast ... orbiting should feel like the ship is slowly moving around the planet" (owner). Until the owner tunes it: each body has one orbit line (Calder 3 km up at 45 m/s, Mote 1.2 km at 20 m/s), entering is offered only within 600 m (Mote 300 m) of it, a faint lane and an insertion ring show the way there from a quarter of the line's height up, and the ship settles onto the line; the cause of "too fast" was the low height and speed, not the animation, so the planets keep their size (values and reasons in "How orbit works") (default, Claude).
- 2026-10-25: Place names and markers can be hidden: William said the names "are cluttering up the screen too much" and asked for two separate settings and a proximity or look-direction mode (owner). Until the owner tunes it: values as in "How the cruise drive works" (Which markers show); markers default to Always so every place can still be found, names to Near or looked at; with markers Off the place aimed at keeps its corner brackets and the place the drive is locked onto its blue brackets, since they say what F does; a change in the settings menu shows at once behind it, with no fade; the two settings sit on the settings menu's Interface page (default, Claude).
- 2026-10-25: A settings menu replaces the comfort settings on the pause screen, and the game starts fullscreen: William asked that "when booting up the game it should go into full screen on the player's monitor/display", with windowed, V-Sync, frame-rate caps and other basic PC settings "inside a settings menu", the key hints at the top of the screen moved into the controls settings and the comfort settings in their own menu; they also approved a HUD and text size setting for big or high-resolution screens (owner). Until the owner says otherwise: fullscreen means borderless (quick to switch windows), with exclusive fullscreen as a choice; V-Sync on and no frame-rate limit; a window at 80% of the display; 30 frames a second in the background; mouse sensitivity and invert are player settings (invert moves out of the flight tuning); changing keys waits until the HUD prompts can name a changed key, since other work on the prompts is in flight (default, Claude).
- 2026-10-25: Short prompts, and landing only near the pad: William asked to "cut down on the size of buttons", "it doesn't need to say 'G Dock at Halfway Station' it can just be 'G Dock'", and that "the button prompt to land should only appear when the ship is near the landing pad", not high in the atmosphere (owner). Until the owner tunes it: every prompt drops the place's name ("G  Dock", "G  Land", "O  Enter orbit", "F  Cruise", "Docking  ·  G to cancel"); the SLOW DOWN warning keeps it, since it says what is in the way; landing is offered within 600 m of the pad, so not from orbit any more (default, Claude).
- 2026-10-25: Docking and landing as an assist (William asked for these after playing PR #8): each port shines a faint guide light to line up with, G proceeds from the ship's own position and speed instead of speeding up or climbing, the ship settles onto the bay's floor instead of hovering in the bay, and a "SLOW DOWN" warning shows when coming at a surface or station too fast (owner). Until the owner tunes them: values as in "Docking and landing tuning"; landing at Tollgate is now offered near the pad itself (see the entry above), as docking is offered near the bay, rather than anywhere within 4 km of Calder's surface, since the owner asked that landing "work the same as stations" and a docking computer flying round the planet at the pilot's own speed would take minutes; the speed limit is a quarter over the ship's speed, never less than the way in over 30 s (5 to 40 m/s); the lights are the ports' colours (green bay, cyan pad) (default, Claude).
- 2026-10-25: How the ship flies itself in until the owner tunes it: values as in "How docking and landing work"; G hands the ship to a docking computer that goes round the station or planet to the port's gate and then straight in, nose first into the bay and turning round inside it (so the pilot sees where they are going and the docked view still looks out of its mouth), or settling onto the pad; G or X takes the ship back, and a bump stops it; the HUD says where it arrived and that the game saved; landing is still offered anywhere close to Calder, so from the far side the ship flies itself round to Tollgate (default, Claude).
- 2026-10-25: Seamless docking and landing join the first playable, moved up from the future roadmap: after playing PR #5 William said "I want to remove the transitions. The player should be able to enter/land at any station/planet seamlessly. No loading screens." The transition screen is gone (owner).
- 2026-10-25: No lens effect over the picture: William chose the narrower 60° view only. Planets may stretch a little near the screen's edges, in exchange for a sharp picture, straight cockpit lines and no frame-rate cost (owner).
- 2026-10-25: The field of view starts at 60° tall (about 90° across on 16:9) instead of 75° (about 106° across), and the slider runs 50° to 90° instead of 60° to 100°: William saw planets turn oval as they moved toward the screen's edges and wants their shape and scale to stay accurate. A flat picture stretches round things near its edges, the more the wider the view; at the side edges of a 16:9 screen the stretch drops from about 70% to about 40% (an ultrawide screen shows more across, so more stretch at its sides), and in the middle planets are round either way. The pilot's eye moves 0.46 m back and the chase camera 1.33 times further out and looking 9° down instead of 8°, so both views frame the cockpit and the ship as they did when approved. Saved settings still on the old 75° move to 60°; any other choice is kept. A lens effect that would keep planets perfectly round everywhere was offered; William chose the narrower view only (owner asked for the fix; values default, Claude).
- 2026-10-25: The cruise drive locks onto a place: William asked that "when the player aims at a location and enables cruise drive the ship should lock onto the target and fly there" (owner). Until the owner tunes it: values and behaviour as in "How the cruise drive works" (Locking on); the lock is taken when F is pressed, from the place the nose is aimed at; moving the mouse releases it; locked on, the drive arrives only at its target and goes round what is in the way; with nothing aimed at, F cruises where the nose points as before (default, Claude).
- 2026-10-24: Docking, landing and orbit until the owner tunes them: values as in "How docking and landing work" and "How orbit works"; G docks, lands, undocks and takes off, O enters and leaves orbit; landing at a planet's base is offered anywhere close to the planet; the docked ship sits in an open bay on the station (the station's dock is no longer a solid block); the autosave writes the game on every docking and landing (seed, clock, random streams and where the ship is), and loading it comes with save and load (build step 7), so a new launch still starts in flight; the event bus is an autoload, `Events` (default, Claude).
- 2026-10-24: Orbit joins the first playable: William asked for ships to "sit in orbit of objects", not a simulation like Kerbal Space Program, "just a simple 'Enter Orbit' button prompt. The player can enter orbit and stay there" (owner).
- 2026-10-24: The tiny solar system and cruise drive until the owner tunes them: sizes, places and values as in "The tiny solar system" and "How the cruise drive works"; F is the cruise key; the bodies hold still (orbits later); the belt is a ring round the planet beyond the moon, so trips between the other places never cross it; the sun is a light and a sky disc, not a body; the cameras see 150 km; Jolt's speed limit is raised from 500 m/s to 8 km/s for the cruise drive; the names are placeholders the owner can change (default, Claude).
- 2026-10-24: Cameras approved: William played the cockpit and chase camera from PR #3 and said "I'm happy with that" (owner).
- 2026-10-24: Cameras until the owner tunes them: start in the cockpit, V switches to the chase camera; the field of view is vertical, 60° to 100°, starting at 75° (what flight was approved with); shake starts full (it is faint), head bob on, reduce motion off; the comfort settings sit on the pause screen until the settings menu and are saved in `settings.json` in the user folder (default, Claude).
- 2026-10-24: The greybox ship's centre of mass (0, -0.07, 0.41 m) and inertia (about 230 800, 297 800 and 84 000 kg m² around pitch, yaw and roll) stay where they were when flight was approved, so the cockpit canopy's new collision shape changes neither how it flies nor how it spins after a bump; a unit test checks them (default, Claude).
- 2026-10-24: Flight approved: William played the flight from PR #2 and said the controls feel good. "How it flies" and "Flight tuning" are now the baseline; changes to them go to the owner (owner).
- 2026-10-24: Until the owner's flight verdict (build step 4), flight works as described in "How it flies": assist holds a set speed rather than braking when W is released, the mouse is a self-centring stick, assist off lets spin drift too, and X is a full stop. Keys: W/S, A/D, Space/Ctrl (or C), Q/E, Z, X, Esc (default, Claude).
- 2026-10-24: The floating origin re-centres the world when the ship is 2048 m from it; true positions are kept in 64-bit (default, Claude).
- 2026-10-24: Stack fixed: Godot 4.7.2-stable (standard build), typed GDScript, Forward+, Blender models exported as glTF. Desktop only, Windows first, single player, offline (owner, project instructions).
- 2026-10-24: Large-world precision uses a floating origin, not the double-precision build, until the owner decides otherwise (project instructions).
- 2026-10-24: Until the owner decides, losing the ship respawns the player at the last base with a small towing fee (project instructions).
- 2026-10-24: Until the owner decides, versions are named like the other games ("0.1 Dev 1", then Dev 2, Beta 1 and so on); the game starts at 0.1 Dev 1 (default, Claude).
- 2026-10-24: Changelog notes go in `changelog.d/` (one small file per pull request) and are gathered into `CHANGELOG.md` at release, the same system as the owner's other Godot games, so parallel pull requests never collide (default, Claude).

## Open decisions

Questions for the owner. Nothing here is built until it is decided.

- Final title (Project Praesepe is a working title).
- Art style.
- Multiplayer, controller support, Steam, a third-person on-foot view.
- Performance targets (until set: a smooth 60 fps on mid-range hardware, no hitches in flight, docking or landing).
- Double-precision build or floating origin only.
- Target loan payoff time (how many hours of play).
- Respawn rules after losing the ship.

## Naming list

Every name in the game is original. Add each new ship, planet, station, company and character here before using it.

| Name | What it is | Status |
| --- | --- | --- |
| Project Praesepe | Working title | Placeholder |
| Hauler, Interceptor, Surveyor | Starter ship classes | Placeholder |
| Sorrel | The star | Placeholder |
| Calder | The planet | Placeholder |
| Tollgate | Calder's base | Placeholder |
| Mote | Calder's moon | Placeholder |
| Halfway Station | The space station | Placeholder |
| The Shingle | The asteroid belt | Placeholder |
