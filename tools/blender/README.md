# Blender scripts for ship models

The ship and cockpit models are made in Blender and loaded by the game as glTF (`.glb`) files in `game/ship/models/`.
These scripts keep a new model lined up with what the game already uses, so it drops in without changing how the ship
flies, docks or looks through the cameras.

- `ship_reference.py` adds a "Reference" collection (never exported) with the ship's collision shapes, the greybox the
  first model replaced, the pilot's eye, the dashboard and nav computer screens, and cameras that see what the game's cockpit and
  chase cameras see (60° tall, 1920×1080). It also makes the "Exterior" and "Cockpit" collections the export takes.
- `hauler_model.py` builds the Hauler's placeholder model into those collections, and checks that nothing in the
  cockpit pokes through its walls, floor or glass (it prints a `COCKPIT CLIPS` line for each part that does).
- `export_ship.py` writes `<ship>_exterior.glb` and `<ship>_cockpit.glb` from those two collections, joining the parts
  into one mesh per material (named like `Exterior_Glass`) so the game draws few of them.

In Blender's Python console, with this folder on `sys.path`: `ship_reference.build()`, `hauler_model.build()`, then
`export_ship.export("<repo>/game/ship/models", "hauler")`. Blender's `bpy` module from PyPI runs the same scripts
headless, which is how they are checked without a Blender window.

The owner's `.blend` files are never overwritten: each change is saved as a new numbered version
(`hauler_v001.blend`, `hauler_v002.blend`, ...).

## What a ship model must keep

Blender is Z up with the nose along +Y; Godot is Y up with the nose along -Z. Positions below are Blender's (x right,
y forward, z up), in metres, from the ship's centre.

| What | Where / how big | Why |
| --- | --- | --- |
| Collision: hull | Centre (0, 0.5, 0), 4 wide, 13.4 long, 2.4 tall | Bumps and the bay floor berth use these shapes, not the model; the ship's underside is z = -1.2. Mass, centre of mass and inertia are set by hand, so the shapes can follow a new model without changing how it flies |
| Collision: back half | Centre (0, -0.8, 1.55), 3.4 wide, 10.6 long, 0.7 tall | |
| Collision: wings | Centre (0, -2.5, -0.4), 14 wide, 4 long, 0.4 tall | |
| Collision: engine pods | Centres (±2.25, -3.775, -0.05), 1.44 wide and tall, 6.65 long | |
| Collision: pod fins | Centres (±2.25, -5.75, 1.2), 0.14 wide, 2.3 long, 1.1 tall | |
| Pilot's eye | (0, 3.54, 1.15) | Approved framing at 60° (PR #6) |
| Chase camera | (0, -24, 5.3), looking along +Y and 9° down | Approved framing (PR #6) |
| Dashboard screen | Centre (0, 5.146, 0.665), 1.0 × 0.34, tilted back 22.9° | Speed, assist and target text sit on it |
| Nav computer screen | Centre (0, 5.141, 0.667), 1.6 × 0.34, same tilt | Tab turns the middle screen into the nav computer, so the dash needs a flat face at least this big, just behind it |
| Cockpit window | No frame bars in the pilot's view (owner, 2026-10-25); flat panes only, never a curved bubble | The owner's call on v001 |

The visible model should stay close to the collision shapes (a little inside is fine, nothing more than 0.1 m
sticking out of the nearest box, which `test/unit/test_ship_model.gd` checks vertex by vertex), so what the player
sees matches what bumps. Faces are single sided: the exterior hull is never seen from the cockpit as long as nothing
sits between the eye and the window.

## Model rules (project instructions, "Presentation")

Real-world scale in metres; clean object names (`Hull`, `Canopy_Frame`, `Engine_L`); a few shared materials (hull
paint, trim, metal, glass, lights, screen) and no textures unless needed; low poly (exterior about 3,000 to 8,000
triangles, cockpit about 5,000 to 10,000; the Hauler placeholder is deliberately far below that, about 700 and
1,100). No resemblance to ships, names or logos from other games or films.
