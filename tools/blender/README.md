# Blender scripts for ship models

The ship and cockpit models are made in Blender and loaded by the game as glTF (`.glb`) files in `game/ship/models/`.
These scripts keep a new model lined up with what the game already uses, so it drops in without changing how the ship
flies, docks or looks through the cameras.

- `ship_reference.py` adds a "Reference" collection (never exported) with the ship's collision shapes, the greybox it
  replaces, the pilot's eye, the dashboard and nav computer screens, and cameras that see what the game's cockpit and
  chase cameras see (60° tall, 1920×1080). It also makes the "Exterior" and "Cockpit" collections the export takes.
- `export_ship.py` writes `<ship>_exterior.glb` and `<ship>_cockpit.glb` from those two collections.

The owner's `.blend` files are never overwritten: each change is saved as a new numbered version
(`hauler_v001.blend`, `hauler_v002.blend`, ...).

## What a ship model must keep

Blender is Z up with the nose along +Y; Godot is Y up with the nose along -Z. Positions below are Blender's (x right,
y forward, z up), in metres, from the ship's centre.

| What | Where / how big | Why |
| --- | --- | --- |
| Collision: hull | Centre (0, 0, 0), 4 wide, 12 long, 2.4 tall | Flight, bumps and the bay floor berth use these shapes, not the model; the ship's underside is z = -1.2 |
| Collision: canopy | Centre (0, 3.95, 1.575), 3.2 wide, 2.9 long, 0.75 tall | |
| Collision: wings | Centre (0, -2.5, -0.4), 14 wide, 4 long, 0.4 tall | |
| Pilot's eye | (0, 3.54, 1.15) | Approved framing at 60° (PR #6) |
| Chase camera | (0, -24, 5.3), looking along +Y and 9° down | Approved framing (PR #6) |
| Dashboard screen | Centre (0, 5.146, 0.665), 1.0 × 0.34, tilted back 22.9° | Speed, assist and target text sit on it |
| Nav computer screen | Centre (0, 5.141, 0.667), 1.6 × 0.34, same tilt | Tab turns the middle screen into the nav computer, so the dash needs a flat face at least this big, just behind it |
| Cockpit window | The greybox pillars at x = ±1.6 and roof at z = 1.95 frame the view | Keep the frame lines near these so the cockpit view stays as approved |

The visible model should stay close to the collision shapes (a little inside is fine, nothing big sticking out), so
what the player sees matches what bumps. Faces are single sided: the exterior hull is never seen from the cockpit
as long as nothing sits between the eye and the window.

## Model rules (project instructions, "Presentation")

Real-world scale in metres; clean object names (`Hull`, `Canopy_Frame`, `Engine_L`); a few shared materials (hull
paint, trim, metal, glass, lights, screen) and no textures unless needed; low poly (exterior about 3,000 to 8,000
triangles, cockpit about 5,000 to 10,000). No resemblance to ships, names or logos from other games or films.
