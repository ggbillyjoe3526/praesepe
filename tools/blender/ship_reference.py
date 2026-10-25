"""Sets up a Blender scene to model a ship for Project Praesepe against what the game already has.

Run it inside Blender (Scripting tab, or `blender --python tools/blender/ship_reference.py`). It adds a collection
called "Reference" that is never exported: the ship's collision shapes (what the physics, docking and the bay floor
use), the greybox ship and cockpit it replaces, the pilot's eye, the dashboard screen and the nav computer screen, and
two cameras that see exactly what the game's cockpit and chase cameras see. Running it again replaces the collection.
It also makes the two collections the export takes, "Exterior" and "Cockpit", if they are missing.

Sizes are in metres. Blender is Z up with the ship's nose along +Y; the glTF export turns that into Godot's Y up with
the nose along -Z. Every number here is copied from game/ship/greybox_ship.tscn, game/ship/greybox_cockpit.tscn and
game/camera/camera_tuning.tres; when those change, change this too.
"""

import math

import bpy
from mathutils import Matrix, Vector

# Godot positions (x right, y up, z back) of what the model must fit round.
HULL_SHAPE = ((0.0, 0.0, 0.0), (4.0, 2.4, 12.0))
CANOPY_SHAPE = ((0.0, 1.575, -3.95), (3.2, 0.75, 2.9))
WING_SHAPE = ((0.0, -0.4, 2.5), (14.0, 0.4, 4.0))
EYE = (0.0, 1.15, -3.54)
CHASE_ANCHOR = (0.0, 5.3, 24.0)
CHASE_LOOK_DOWN = 9.0
# The dashboard screen (speed, assist, target) and the nav computer screen in front of it: centre, size, and the tilt
# back about x (degrees, Godot's sign). The model needs a flat face here at least as big as the nav screen.
DASH_SCREEN = ((0.0, 0.665, -5.146), (1.0, 0.34), -22.9)
NAV_SCREEN = ((0.0, 0.667, -5.1414), (1.6, 0.34), -22.9)
# Vertical field of view the game starts at (Settings), and the player's range for it.
FOV_DEFAULT = 60.0
FOV_RANGE = (50.0, 90.0)
# The greybox parts the model replaces: name, Godot centre, size.
GREYBOX_SHIP = (
	("Body", (0.0, 0.0, 1.75), (4.0, 2.4, 8.5)),
	("Nose", (0.0, -0.35, -4.25), (3.6, 1.7, 3.5)),
	("WingLeft", (-4.5, -0.4, 2.5), (5.0, 0.4, 4.0)),
	("WingRight", (4.5, -0.4, 2.5), (5.0, 0.4, 4.0)),
)
GREYBOX_ENGINES = ((-1.3, 0.0, 6.5), (1.3, 0.0, 6.5))
ENGINE_RADIUS = 0.9
ENGINE_LENGTH = 3.0
NOZZLE_BACK = 8.15
GREYBOX_COCKPIT = (
	("DashPanel", (0.0, 0.644, -5.197), (3.0, 0.46, 0.1), -22.9),
	("ConsoleLeft", (-1.3, 0.675, -4.4), (0.5, 0.35, 1.8), 0.0),
	("ConsoleRight", (1.3, 0.675, -4.4), (0.5, 0.35, 1.8), 0.0),
	("PillarLeft", (-1.6, 1.225, -5.4), (0.08, 1.45, 0.08), 0.0),
	("PillarRight", (1.6, 1.225, -5.4), (0.08, 1.45, 0.08), 0.0),
	("TopFront", (0.0, 1.95, -5.4), (3.28, 0.08, 0.08), 0.0),
	("TopLeft", (-1.6, 1.95, -3.95), (0.08, 0.08, 2.9), 0.0),
	("TopRight", (1.6, 1.95, -3.95), (0.08, 0.08, 2.9), 0.0),
)

REFERENCE = "Reference"
EXPORTED = ("Exterior", "Cockpit")


def to_blender(godot):
	"""A Godot position (x right, y up, z back) as a Blender one (x right, y forward, z up)."""
	return Vector((godot[0], -godot[2], godot[1]))


def size_to_blender(godot_size):
	return Vector((godot_size[0], godot_size[2], godot_size[1]))


def collection(name, parent):
	found = bpy.data.collections.get(name)
	if found is None:
		found = bpy.data.collections.new(name)
	if found.name not in parent.children:
		parent.children.link(found)
	return found


def clear(coll):
	for child in list(coll.children):
		clear(child)
		bpy.data.collections.remove(child)
	for obj in list(coll.objects):
		bpy.data.objects.remove(obj, do_unlink=True)


def box(name, coll, centre, size, tilt=0.0, wire=True):
	"""A box at a Godot centre and size, tilted back `tilt` degrees about x (Godot's sign) like the dashboard."""
	mesh = bpy.data.meshes.new(name)
	sx, sy, sz = (v * 0.5 for v in size_to_blender(size))
	corners = [Vector((x, y, z)) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
	faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
	mesh.from_pydata(corners, [], faces)
	obj = bpy.data.objects.new(name, mesh)
	obj.matrix_world = Matrix.Translation(to_blender(centre)) @ Matrix.Rotation(math.radians(tilt), 4, "X")
	if wire:
		obj.display_type = "WIRE"
	obj.hide_render = True
	coll.objects.link(obj)
	return obj


def screen(name, coll, centre, size, tilt):
	"""A flat screen at a Godot centre facing the pilot, `size` wide and tall, tilted back like the game's."""
	mesh = bpy.data.meshes.new(name)
	hx, hz = size[0] * 0.5, size[1] * 0.5
	mesh.from_pydata([(-hx, 0, -hz), (hx, 0, -hz), (hx, 0, hz), (-hx, 0, hz)], [], [(0, 1, 2, 3)])
	obj = bpy.data.objects.new(name, mesh)
	obj.matrix_world = Matrix.Translation(to_blender(centre)) @ Matrix.Rotation(math.radians(tilt), 4, "X")
	obj.hide_render = True
	coll.objects.link(obj)
	return obj


def cylinder(name, coll, centre, radius, length):
	"""A cylinder along the ship's length at a Godot centre."""
	mesh = bpy.data.meshes.new(name)
	ring = 16
	verts = []
	for y in (-length * 0.5, length * 0.5):
		for i in range(ring):
			a = math.tau * i / ring
			verts.append((math.cos(a) * radius, y, math.sin(a) * radius))
	faces = [(i, (i + 1) % ring, ring + (i + 1) % ring, ring + i) for i in range(ring)]
	faces += [tuple(range(ring - 1, -1, -1)), tuple(range(ring, 2 * ring))]
	mesh.from_pydata(verts, [], faces)
	obj = bpy.data.objects.new(name, mesh)
	obj.location = to_blender(centre)
	obj.display_type = "WIRE"
	obj.hide_render = True
	coll.objects.link(obj)
	return obj


def camera(name, coll, at, pitch_down):
	"""A camera seeing what the game's camera sees: vertical field of view, looking along the nose."""
	data = bpy.data.cameras.new(name)
	data.sensor_fit = "VERTICAL"
	data.angle_y = math.radians(FOV_DEFAULT)
	data.clip_start = 0.05
	data.clip_end = 2000.0
	obj = bpy.data.objects.new(name, data)
	obj.location = to_blender(at)
	obj.rotation_euler = (math.radians(90.0 - pitch_down), 0.0, 0.0)
	coll.objects.link(obj)
	return obj


def empty(name, coll, at, size=0.15):
	obj = bpy.data.objects.new(name, None)
	obj.empty_display_type = "SPHERE"
	obj.empty_display_size = size
	obj.location = to_blender(at)
	coll.objects.link(obj)
	return obj


def build():
	scene = bpy.context.scene
	scene.unit_settings.system = "METRIC"
	scene.unit_settings.scale_length = 1.0
	scene.render.resolution_x = 1920
	scene.render.resolution_y = 1080
	root = scene.collection
	for name in EXPORTED:
		collection(name, root)
	ref = collection(REFERENCE, root)
	clear(ref)

	shapes = collection("Ref_CollisionShapes", ref)
	box("Ref_HullShape", shapes, *HULL_SHAPE)
	box("Ref_CanopyShape", shapes, *CANOPY_SHAPE)
	box("Ref_WingShape", shapes, *WING_SHAPE)

	grey = collection("Ref_Greybox", ref)
	for name, centre, size in GREYBOX_SHIP:
		box("Ref_Grey" + name, grey, centre, size)
	for i, centre in enumerate(GREYBOX_ENGINES):
		cylinder("Ref_GreyEngine%d" % i, grey, centre, ENGINE_RADIUS, ENGINE_LENGTH)
	for name, centre, size, tilt in GREYBOX_COCKPIT:
		box("Ref_Grey" + name, grey, centre, size, tilt)

	marks = collection("Ref_Marks", ref)
	empty("Ref_Eye", marks, EYE)
	empty("Ref_ChaseAnchor", marks, CHASE_ANCHOR, 0.5)
	screen("Ref_DashScreen", marks, *DASH_SCREEN)
	screen("Ref_NavScreen", marks, *NAV_SCREEN)
	cockpit_cam = camera("Ref_CockpitCamera", marks, EYE, 0.0)
	camera("Ref_ChaseCamera", marks, CHASE_ANCHOR, CHASE_LOOK_DOWN)
	scene.camera = cockpit_cam

	# Never exported, never rendered, and kept out of the way of selecting the model.
	ref.hide_render = True
	for obj in ref.all_objects:
		obj.hide_select = obj.type == "MESH"


if __name__ == "__main__":
	build()
