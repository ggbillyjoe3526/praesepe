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
- The velocity marker sits where the ship is really going; when it is going backwards a crossed marker shows where it is moving away from.

**Flight tuning**

The values live in `game/ship/greybox_ship_tuning.tres` (per ship) and `game/flight/flight_controls.tres` (mouse). Change them here and there together.

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
| Mouse | 250 px for a full stick, eases back at 3 per second | Shared by every ship |
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
- Comfort settings, on the pause screen until the settings menu exists, saved between sessions: field of view, camera shake, head bob and reduce motion (no shake or head bob, and a chase camera that swings half as much).

**Camera tuning**

The values live in `game/camera/camera_tuning.tres` (shared by every ship). Where the pilot's eye and the chase camera sit is part of each ship's scene (its `Eye` and `ChaseAnchor` markers).

| Value | First value | What it does |
| --- | --- | --- |
| Field of view | 60° (50° to 90°), vertical; 60° is about 90° across on a 16:9 screen | Player setting, both cameras. Wider views stretch round things near the screen's edges, so planets look oval there |
| Pilot's eye | 1.15 m up, 3.54 m forward of the greybox's centre | Greybox ship scene; set so the cockpit window frames the view at 60° as it did at 75° |
| Head sway | 1.2 mm per m/s² of push, at most 6 cm, eased over 0.15 s | 4.8 cm back at full main engine |
| Engine rumble | 0.12° at full thrust | Times the shake setting |
| Bump wobble | Up to 2° for a 6 m/s knock, gone in about 0.6 s; knocks under 0.3 m/s ignored | Times the shake setting |
| Chase camera place | 5.3 m up, 24 m behind, looking 9° down | Greybox ship scene |
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

**How orbit works (first values, to be tuned with the owner)**

Added at the owner's request: a ship can park in orbit round a planet or moon and stay there. It is a simple mode, not
a simulation: the game has no gravity, so nothing ever falls out of orbit.

- Near a planet or moon (below its highest orbit) the HUD offers "O  Enter orbit round Calder". O swings the ship onto
  a circle round it, the way it was heading, at the height where it levels out (raised to the lowest orbit if it is
  under it). The swing is no harder than the side thrusters (25 m/s²), so it feels like a firm push, never a snap.
- Entering, the ship turns to face along the orbit with the planet below and the horizon a little above the middle of
  the cockpit window, so the planet fills the bottom of the view. Moving the mouse stops that turn and leaves the view
  to the pilot.
- In orbit the ship goes round at the body's orbit speed, holding its height, and its view turns with the orbit, so
  the planet stays where it is in the window while the ground slides past. The mouse still turns the ship. The
  dashboard shows "IN ORBIT · O or thrust to leave".
- O again or any thrust key leaves orbit gently. The ship carries straight on at the velocity it had while its nose
  comes up level along it over 1 s, longer for a bigger turn so it never turns faster than the ship can ("LEAVING
  ORBIT · levelling out"), then flight assist holds that velocity. In orbit
  the nose is dipped toward the planet (more the higher the orbit), so without the level-out the ship would follow its
  nose down into the ground; with it, it flies on level and climbs slowly away. Moving the mouse while it levels out
  hands the ship straight back.
- X (which then stops), Z (which then drifts) or the cruise drive engaging leave orbit at once, keeping the velocity
  the ship had. A hard bump knocks it out of orbit.
- It won't enter while cruising, above 250 m/s, or diving so steeply it couldn't level out 100 m above the surface; a
  message says why.

**Orbit tuning**

The ship's values live in `game/ship/greybox_orbit_tuning.tres` (per ship); each planet's and moon's in the solar
system scene (`game/system/solar_system.tscn`).

| Value | First value | What it does |
| --- | --- | --- |
| Calder's orbits | 500 m to 4 km up, 90 m/s | About 9 minutes round at 1.5 km up |
| Mote's orbits | 300 m to 2.5 km up, 45 m/s | About 6 minutes round at 1 km up |
| Top entry speed | 250 m/s | Anything but cruising |
| Swing onto the orbit | 25 m/s² | No harder than the side thrusters |
| Entry clearance | 100 m | Refuses a dive it couldn't level out of above this |
| Height correction | Closes a gap over 4 s, at most 30 m/s; settled within 5 m | Climbs to the lowest orbit; holds the height |
| Horizon | 5° above the middle of the view | Where the turn on entering puts it |
| Turn on entering | Closes the angle over about 0.8 s, done within 0.5° | Within the ship's own turn limits |
| Bump limit | 3 m/s | A harder knock leaves orbit |
| Level out on leaving | 1 s, easing in and out; longer if the turn would beat the ship's turn rates | O or thrust: nose up along the velocity before flight assist takes over |

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

- The player starts 2 km from Halfway Station with Calder ahead, next to three buoys marking the way to the station.
- The Shingle's rocks come from the world seed: 3000 scattered round the ring and 10 dense pockets of 220, each rock 15 to 110 m in radius (small ones commonest). The first pocket is authored: on the band's inner edge, the one its HUD marker points to. Values in `game/system/shingle_belt.tres`.
- Only the rocks within 2.5 km of the ship are solid (a pool of 48 spheres, picked again every 10 ticks; a sphere stays on its rock while that rock stays near); all are drawn, in 64 pieces round the ring, as lumpy rocks within 9 km and simple shapes out to 70 km, with a faint haze along the band beyond that.
- Calder and Mote are drawn as fine spheres close up and coarse ones from far away (past 40 km and 15 km). The station and base lose their detail at 12 km and 20 km. Everything is visible to 150 km.

**Landing:** for now, approach the planet, see a prompt to land, then a transition screen. Seamless landing is a later goal.

**How docking and landing work (first values, to be tuned with the owner)**

- Halfway Station has an open docking bay on top of its spine, its mouth framed in green. Tollgate has a landing pad.
  Each is a port: where the ship is held while docked or landed.
- Near a port the HUD says what to do: "Fly within 1.5 km of Halfway Station to dock (2.3 km)", then "Slow below
  100 m/s to dock at Halfway Station", then "G  Dock at Halfway Station". Landing at Tollgate is offered anywhere
  within 4 km of Calder's surface, so approaching the planet (or orbiting it) is enough: "G  Land at Tollgate".
  Nothing is offered while the cruise drive charges or runs.
- G fades the view to black ("Docking at Halfway Station"), the ship arrives, the screen says "Docked at Halfway
  Station" and "Game saved", and the view fades back in with the ship held still in the bay, looking out of its mouth
  (or on the pad, facing the hangar). The dashboard shows "DOCKED · G to undock" or "LANDED · G to take off".
- G again leaves: the ship is eased straight out of the bay (or straight up off the pad), speeding up evenly, then
  handed back with flight assist holding the speed it left with (25 m/s out of the bay; a hover above the pad).
- Every docking and landing goes through one arrival function (`Arrivals.arrive`), which tells the rest of the game
  through the event bus (`Events.arrived`). The autosave listens there and writes the game; contracts will too. Seamless
  landing can later replace the fade without touching them.
- Mote has no landing site yet; landing on it comes with surface mining.

**Docking and landing tuning**

The transition's timing lives in `game/arrival/arrival_tuning.tres`; each port's values on the port itself, in the
station's and base's scenes (`game/system/greybox_station.tscn`, `game/system/greybox_base.tscn`).

| Value | First value | What it does |
| --- | --- | --- |
| Docking offered | Within 1.5 km of the bay, below 100 m/s; hints from 3.5 km | The cruise drive drops out about 2.8 km away |
| Landing offered | Within 4 km of Calder's surface, below 100 m/s; hints from 8 km | Cruising to Calder or Tollgate ends inside it |
| Transition | 0.6 s fade out, 1.4 s black, 0.6 s fade in | Names the place and says the game saved |
| Leaving the bay | 60 m, speeding up to 25 m/s (about 5 s) | Clear of the bay's mouth before the pilot has it |
| Taking off | 30 m straight up, speeding up to 15 m/s (about 4 s) | Then flight assist brings it to a hover |

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
- [ ] Landing prompt and transition screen
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
- **One arrival function for landing:** route all landings through a single function that loads the planet scene and places the ship. Seamless landing can later replace its internals without touching jobs, bases or saves.
- **Two controllers with a clean hand-off:** a ship controller and an on-foot controller, with entering and leaving the seat as one well-defined transition.
- **Data-driven contracts:** define contracts as data (verb, origin, destination, reward, steps) so new job types need little new code.
- **Modular on-foot tasks:** drill, collect, carry and scan as separate pieces, ready for helper robots later.
- **Self-contained solar system scene:** keeps a future multi-system universe possible without designing for it now.
- **Seeded generation:** one seed drives every random element so a world can be reproduced.

## Player wiki

A GitHub wiki will document the full game for players. It is written for players, not developers, and kept current as the game changes.

- **Release notes:** what changed in each version, newest first, drawn from the changelog.
- **Getting started:** controls, the first hour, choosing a starter ship, paying off the loan.
- **Ships:** every ship with its role, stats, upgrades and how to get it.
- **Contracts and jobs:** each job type, how it works, rewards and reputation.
- **Locations:** planets, moons, stations and bases, with their environments, services and points of interest.
- **Items and upgrades:** what each upgrade does and where to buy it.
- **Events and encounters:** random events, distress calls, derelicts.
- **Settings and accessibility:** options, comfort settings, key rebinding.
- **Roadmap:** what is planned next, with no promised dates.
- **FAQ and troubleshooting:** common questions, saves, known issues.

The wiki is updated when a player-facing change ships, alongside the changelog. It only describes what is in a released build, never planned features as if they exist (those go on the Roadmap page).

## Future roadmap

The core game comes first. These ideas follow once the first playable is fun, roughly in this order.

1. **Core game:** all three starter ships, every job type (taxi, security, bounty, science), reputation, passengers with personality, contract chaining, random events, radio, photo mode, the full solar system.
2. **Owning more:** buy more ships (outright or on loan), a hangar to store them, buy a station or outpost (bought, not built).
3. **Automation:** helper robots for on-foot work (mining, survey, cargo and repair bots), then hired pilot agents to run other ships.
4. **Expansion:** a jump gate or flight route to new areas, then a universe of predefined solar systems placed by seed.
5. **Later polish:** seamless planet landing, walkable ship interiors, a codex of discoveries, a third-person on-foot view.

## Decisions log

Newest first. Each line: date, the decision, who made it.

- 2026-10-25: The field of view starts at 60° tall (about 90° across on 16:9) instead of 75° (about 106° across), and the slider runs 50° to 90° instead of 60° to 100°: William saw planets turn oval as they moved toward the screen's edges and wants their shape and scale to stay accurate. A flat picture stretches round things near its edges, the more the wider the view; at the side edges of a 16:9 screen the stretch drops from about 70% to about 40% (an ultrawide screen shows more across, so more stretch at its sides), and in the middle planets are round either way. The pilot's eye moves 0.46 m back and the chase camera 1.33 times further out and looking 9° down instead of 8°, so both views frame the cockpit and the ship as they did when approved. Saved settings still on the old 75° move to 60°; any other choice is kept. A lens effect that keeps planets perfectly round everywhere is with William to decide (default, Claude; owner asked for the fix).
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
- Version names and release tags (the other games use "0.1 Dev 1" with tags like `v0.1-dev.1`).

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
