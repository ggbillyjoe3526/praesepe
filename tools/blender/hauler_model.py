"""Builds the Hauler's placeholder model in Blender: the ship as the chase camera sees it ("Exterior") and the cockpit
round the pilot ("Cockpit"). Run ship_reference.py first (it makes the collections and the reference shapes), then
this; running it again rebuilds both collections from scratch. export_ship.py then writes the .glb files.

Everything is placed in Godot's coordinates (x right, y up, z back, metres from the ship's centre) through
ship_reference.to_blender, so the numbers read the same as the game's scenes. The model follows the owner's
references and notes (2026-10-25): a small, simple ship, light grey with orange panels and a few glowing strips, two
engines on the sides at the back, short swept wings; a flat windscreen sloping down to the nose in front of a taller
back half, with flat side windows and no frame bars in the pilot's view; inside, a slim dashboard low across the bottom
of the view. Kept round the game's fixed points: the pilot's eye, the dashboard and nav computer screens, the
collision shapes and the bay floor berth (the underside at y = -1.2). check_cockpit() proves nothing in the cockpit
pokes through its walls, floor or glass.
"""

import math

import bmesh
import bpy
from mathutils import Vector

import ship_reference as ref

# The glass sits on the sill, the top edge of the cockpit's walls, which runs straight from beside the nose to the
# front of the taller back half: (z, half width, height).
SILL_FRONT = (-6.1, 1.16, 0.62)
SILL_BACK = (-2.5, 1.68, 0.92)
# The windscreen's top edge, ahead of the pilot's head (z, half width, height), and the back of the flat roof window
# behind it, where the taller back half begins.
WINDSCREEN_TOP = (-3.2, 1.3, 1.85)
ROOF_BACK = (-2.5, 1.3, 1.9)
# The cockpit's walls stand this far inside the sill; its floor and how far forward and back it reaches.
WALL = 0.06
CABIN_FLOOR = 0.0
CABIN_FRONT = -6.04
CABIN_BACK = -2.52

# The lower hull from nose to tail: (z, half width, top, bottom, chamfer), Godot. Where the cockpit is, the top's flat
# part ends at the sill (half width minus chamfer).
HULL_SECTIONS = (
	(-7.25, 0.22, 0.22, -0.32, 0.08),
	(-6.6, 0.9, 0.45, -0.6, 0.15),
	(SILL_FRONT[0], SILL_FRONT[1] + 0.18, SILL_FRONT[2], -0.8, 0.18),
	(SILL_BACK[0], SILL_BACK[1] + 0.22, SILL_BACK[2], -1.1, 0.22),
	(1.0, 1.9, 0.95, -1.12, 0.25),
	(5.6, 1.35, 0.9, -0.85, 0.25),
	(6.2, 0.95, 0.62, -0.6, 0.18),
)
# The taller back half, sitting on the lower hull: (z, roof half width, roof height). Its sides run down to the edge
# of the lower hull's top.
UPPER_SECTIONS = (
	(ROOF_BACK[0], ROOF_BACK[1], ROOF_BACK[2]),
	(1.5, 1.3, 1.9),
	(4.6, 0.95, 1.55),
	(6.0, 0.55, 1.1),
)
# Engine pods either side at the back: centre x and y, front and back z, radius.
POD_X = 2.25
POD_Y = -0.05
POD_FRONT = 0.6
POD_BACK = 7.1
POD_RADIUS = 0.72

COLOURS = {
	# name: (base colour, roughness, metallic, emission colour, emission strength, alpha)
	"Hull": ((0.62, 0.63, 0.65), 0.55, 0.1, None, 0.0, 1.0),
	"Trim": ((0.11, 0.12, 0.135), 0.6, 0.2, None, 0.0, 1.0),
	"Accent": ((0.9, 0.42, 0.07), 0.5, 0.0, None, 0.0, 1.0),
	"Glass": ((0.04, 0.07, 0.1), 0.05, 0.3, None, 0.0, 0.35),
	"Glow": ((0.4, 0.85, 1.0), 0.4, 0.0, (0.4, 0.85, 1.0), 4.0, 1.0),
	"Engine": ((0.45, 0.7, 1.0), 0.4, 0.0, (0.45, 0.7, 1.0), 8.0, 1.0),
	"NavRed": ((1.0, 0.15, 0.1), 0.4, 0.0, (1.0, 0.15, 0.1), 5.0, 1.0),
	"NavGreen": ((0.15, 1.0, 0.3), 0.4, 0.0, (0.15, 1.0, 0.3), 5.0, 1.0),
	"Cabin": ((0.09, 0.095, 0.105), 0.8, 0.0, None, 0.0, 1.0),
	"Panel": ((0.19, 0.2, 0.215), 0.65, 0.1, None, 0.0, 1.0),
	"Screen": ((0.012, 0.018, 0.028), 0.15, 0.0, (0.01, 0.025, 0.045), 1.0, 1.0),
}


# --- Materials ------------------------------------------------------------------------------------------------------

def material(name):
	"""A shared material, made once. Single sided (back faces culled) so glass and shells are invisible from inside."""
	found = bpy.data.materials.get(name)
	if found is not None:
		return found
	colour, rough, metal, glow, strength, alpha = COLOURS[name]
	mat = bpy.data.materials.new(name)
	mat.use_backface_culling = True
	mat.diffuse_color = (*colour, alpha)
	tree = mat.node_tree if mat.node_tree is not None else None
	if tree is None:
		mat.use_nodes = True
		tree = mat.node_tree
	bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	if glow is not None:
		bsdf.inputs["Emission Color"].default_value = (*glow, 1.0)
		bsdf.inputs["Emission Strength"].default_value = strength
	if alpha < 1.0:
		bsdf.inputs["Alpha"].default_value = alpha
		mat.surface_render_method = "BLENDED"
	return mat


# --- Mesh helpers (Godot coordinates in, Blender objects out) -------------------------------------------------------

def make(name, coll, verts, faces, mat, smooth=False, fix_normals=True):
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata([ref.to_blender(v) for v in verts], [], faces)
	if fix_normals:
		bm = bmesh.new()
		bm.from_mesh(mesh)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		bm.to_mesh(mesh)
		bm.free()
	mesh.materials.append(material(mat))
	if smooth:
		mesh.shade_smooth()
	else:
		mesh.shade_flat()
	obj = bpy.data.objects.new(name, mesh)
	coll.objects.link(obj)
	return obj


def face_toward(obj, godot_point):
	"""Turns a flat part's faces to look toward a point (Godot), so a single-sided panel shows from that side."""
	target = ref.to_blender(godot_point)
	if sum((target - p.center).dot(p.normal) for p in obj.data.polygons) < 0.0:
		obj.data.flip_normals()
	return obj


def face_away(obj, godot_point):
	face_toward(obj, godot_point)
	obj.data.flip_normals()
	return obj


def bevel(obj, width=0.015, segments=2):
	mod = obj.modifiers.new("Bevel", "BEVEL")
	mod.width = width
	mod.segments = segments
	mod.limit_method = "ANGLE"
	mod.angle_limit = math.radians(35.0)
	return obj


def prism_x(profile, x0, x1):
	"""A closed solid: a side profile [(y, z)] extruded across from x0 to x1."""
	n = len(profile)
	verts = [(x0, y, z) for y, z in profile] + [(x1, y, z) for y, z in profile]
	faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
	faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
	return verts, faces


def box(centre, size):
	cx, cy, cz = centre
	hx, hy, hz = (s * 0.5 for s in size)
	verts = [(cx + x, cy + y, cz + z) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
	faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
	return verts, faces


def octagon_tube(cx, cy, z0, z1, r0, r1, segments=8):
	"""A tube along z with flat ends, `segments` sides, radius r0 at z0 and r1 at z1, turned so a side is on top."""
	verts = []
	for z, r in ((z0, r0), (z1, r1)):
		for i in range(segments):
			a = math.tau * (i + 0.5) / segments
			verts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z))
	n = segments
	faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
	faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
	return verts, faces


def transformed(verts, pivot, yaw_deg, shift=(0.0, 0.0, 0.0), mirror=False):
	"""Verts turned `yaw_deg` about a vertical axis through `pivot`, then moved; mirrored across x = 0 if asked."""
	a = math.radians(yaw_deg)
	out = []
	for x, y, z in verts:
		dx, dz = x - pivot[0], z - pivot[2]
		nx = pivot[0] + dx * math.cos(a) + dz * math.sin(a) + shift[0]
		nz = pivot[2] - dx * math.sin(a) + dz * math.cos(a) + shift[2]
		out.append((-nx if mirror else nx, y + shift[1], nz))
	return out


def both_sides(name, coll, verts, faces, mat, **kw):
	"""The part as given on the right (_R) and mirrored on the left (_L)."""
	right = make(name + "_R", coll, verts, faces, mat, **kw)
	left = make(name + "_L", coll, [(-x, y, z) for x, y, z in verts], faces, mat, **kw)
	return right, left


# --- The glass ------------------------------------------------------------------------------------------------------

def lerp(a, b, t):
	return a + (b - a) * t


def sill(z):
	"""The sill's half width and height at z, along the cockpit."""
	t = (z - SILL_FRONT[0]) / (SILL_BACK[0] - SILL_FRONT[0])
	return lerp(SILL_FRONT[1], SILL_BACK[1], t), lerp(SILL_FRONT[2], SILL_BACK[2], t)


def cabin_half_width(z):
	return sill(z)[0] - WALL


GLASS_INSIDE = (0.0, 1.0, -4.3)


def glass(coll):
	"""Flat panes, no frames: the windscreen sloping down to the nose, a roof window over the pilot's head, and a
	side window each side from the sill up to them. Their faces point outward, so from inside they are clear."""
	b = (SILL_FRONT[1], SILL_FRONT[2], SILL_FRONT[0])
	c = (WINDSCREEN_TOP[1], WINDSCREEN_TOP[2], WINDSCREEN_TOP[0])
	e = (ROOF_BACK[1], ROOF_BACK[2], ROOF_BACK[0])
	f = (SILL_BACK[1], SILL_BACK[2], SILL_BACK[0])
	panes = []
	ws = [(-b[0], b[1], b[2]), (b[0], b[1], b[2]), (c[0], c[1], c[2]), (-c[0], c[1], c[2])]
	panes.append(make("Windscreen", coll, ws, [(0, 1, 2, 3)], "Glass"))
	roof = [(-c[0], c[1], c[2]), (c[0], c[1], c[2]), (e[0], e[1], e[2]), (-e[0], e[1], e[2])]
	panes.append(make("RoofWindow", coll, roof, [(0, 1, 2, 3)], "Glass"))
	side = [(b[0], b[1], b[2]), (c[0], c[1], c[2]), (e[0], e[1], e[2]), (f[0], f[1], f[2])]
	panes += both_sides("SideWindow", coll, side, [(0, 1, 3), (1, 2, 3)], "Glass")
	for pane in panes:
		face_away(pane, GLASS_INSIDE)
		pane.visible_shadow = False
	return panes


def well_cutter(coll):
	"""The shape cut out of the lower hull for the cockpit: inside the sill, from the floor up. Not exported; the
	hull's Boolean uses it, and the cut walls and floor take its material."""
	plan = [(cabin_half_width(z), z) for z in (CABIN_FRONT, CABIN_BACK)]
	outline = [(-plan[0][0], plan[0][1]), (plan[0][0], plan[0][1]), (plan[1][0], plan[1][1]), (-plan[1][0], plan[1][1])]
	verts = [(x, CABIN_FLOOR, z) for x, z in outline] + [(x, 3.0, z) for x, z in outline]
	faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
	obj = make("Cutter_CockpitWell", coll, verts, faces, "Cabin")
	obj.display_type = "WIRE"
	obj.hide_render = True
	return obj


# --- The outside ----------------------------------------------------------------------------------------------------

def hull_section(z, w, top, bottom, c):
	"""The hull's cross-section at z: an eight-sided outline, clockwise from the top right seen from the front."""
	return [(w - c, top, z), (w, top - c, z), (w, bottom + c, z), (w - c, bottom, z),
		(-(w - c), bottom, z), (-w, bottom + c, z), (-w, top - c, z), (-(w - c), top, z)]


def hull(coll, cutters):
	verts = []
	for section in HULL_SECTIONS:
		verts += hull_section(*section)
	n, count = 8, len(HULL_SECTIONS)
	faces = [tuple(range(n)), tuple(range(count * n - 1, (count - 1) * n - 1, -1))]
	for s in range(count - 1):
		a, b = s * n, (s + 1) * n
		faces += [(a + i, a + (i + 1) % n, b + (i + 1) % n, b + i) for i in range(n)]
	obj = make("Hull", coll, verts, faces, "Hull")
	cut = obj.modifiers.new("CockpitWell", "BOOLEAN")
	cut.operation = "DIFFERENCE"
	cut.solver = "EXACT"
	cut.material_mode = "TRANSFER"
	cut.object = well_cutter(cutters)
	return obj


def lower_top(z):
	"""The lower hull's top at z: the half width of its flat part and its height."""
	for (z0, w0, t0, _b0, c0), (z1, w1, t1, _b1, c1) in zip(HULL_SECTIONS, HULL_SECTIONS[1:]):
		if z0 <= z <= z1:
			k = (z - z0) / (z1 - z0)
			return lerp(w0 - c0, w1 - c1, k), lerp(t0, t1, k)
	raise ValueError("z %.2f is off the hull" % z)


def upper_body(coll):
	"""The taller back half: its roof meets the roof window, its front is the cockpit's back wall, and its sides run
	down to the lower hull's top (sunk 2 cm into it)."""
	verts = []
	for z, roof_w, roof_y in UPPER_SECTIONS:
		side_w, side_y = lower_top(z)
		verts += [(roof_w, roof_y, z), (side_w, side_y - 0.02, z), (-side_w, side_y - 0.02, z), (-roof_w, roof_y, z)]
	n, count = 4, len(UPPER_SECTIONS)
	faces = [(0, 1, 2, 3), tuple(range(count * n - 1, (count - 1) * n - 1, -1))]
	for s_ in range(count - 1):
		a, b = s_ * n, (s_ + 1) * n
		faces += [(a + i, a + (i + 1) % n, b + (i + 1) % n, b + i) for i in range(n)]
	return make("UpperBody", coll, verts, faces, "Hull")


def pods(coll):
	for side, name in ((1.0, "R"), (-1.0, "L")):
		x = POD_X * side
		v, f = octagon_tube(x, POD_Y, POD_FRONT, POD_BACK - 0.35, POD_RADIUS * 0.7, POD_RADIUS)
		make("EnginePod_" + name, coll, v, f, "Hull")
		v, f = octagon_tube(x, POD_Y, POD_BACK - 0.35, POD_BACK, POD_RADIUS, POD_RADIUS * 0.92)
		make("EngineCollar_" + name, coll, v, f, "Trim")
		v, f = octagon_tube(x, POD_Y, POD_BACK - 0.2, POD_BACK + 0.03, POD_RADIUS * 0.7, POD_RADIUS * 0.7)
		make("EngineGlow_" + name, coll, v, f, "Engine")
		v, f = octagon_tube(x, POD_Y, POD_FRONT - 0.12, POD_FRONT, POD_RADIUS * 0.45, POD_RADIUS * 0.7)
		make("EngineIntake_" + name, coll, v, f, "Trim")
		# A pylon joining the pod to the hull.
		v, f = box((side * 1.95, POD_Y, 3.6), (0.6, 0.5, 4.2))
		make("Pylon_" + name, coll, v, f, "Trim")
		# An orange band round the pod, and a fin on top.
		v, f = octagon_tube(x, POD_Y, 3.3, 4.1, POD_RADIUS * 0.97 + 0.012, POD_RADIUS * 0.99 + 0.012)
		make("PodBand_" + name, coll, v, f, "Accent")
		fin = [(x - 0.06, POD_Y + 0.6, 4.6), (x - 0.06, POD_Y + 0.6, 6.9), (x - 0.06, 1.75, 6.85), (x - 0.06, 1.75, 6.25),
			(x + 0.06, POD_Y + 0.6, 4.6), (x + 0.06, POD_Y + 0.6, 6.9), (x + 0.06, 1.75, 6.85), (x + 0.06, 1.75, 6.25)]
		make("Fin_" + name, coll, fin, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)],
			"Hull")
		tip = [(x - 0.065, 1.5, 6.29), (x - 0.065, 1.5, 6.87), (x - 0.065, 1.75, 6.85), (x - 0.065, 1.75, 6.25),
			(x + 0.065, 1.5, 6.29), (x + 0.065, 1.5, 6.87), (x + 0.065, 1.75, 6.85), (x + 0.065, 1.75, 6.25)]
		make("FinTip_" + name, coll, tip, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3),
			(3, 7, 4, 0)], "Accent")


def wings(coll):
	"""Short swept wings from the pods, inside the wing collision box (14 m across, y -0.6 to -0.2, z 0.5 to 4.5)."""
	root_x, tip_x = POD_X + 0.5, 6.85
	plan = ((root_x, 0.9), (tip_x, 3.3), (tip_x, 4.45), (root_x, 4.45))  # (x, z): leading root, leading tip, ...
	top, bottom, tip_drop = -0.22, -0.5, 0.08
	verts = []
	for y_off in (top, bottom):
		for x, z in plan:
			lean = tip_drop * (x - root_x) / (tip_x - root_x)
			verts.append((x, y_off - lean, z))
	faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
	both_sides("Wing", coll, verts, faces, "Hull")
	# The outer part of each wing's top painted orange.
	def on_top(x):
		return top - tip_drop * (x - root_x) / (tip_x - root_x) + 0.012

	panel = [(4.6, on_top(4.6), 2.13), (tip_x - 0.05, on_top(tip_x - 0.05), 3.32),
		(tip_x - 0.05, on_top(tip_x - 0.05), 4.4), (4.6, on_top(4.6), 4.4)]
	for obj in both_sides("WingPanel", coll, panel, [(0, 1, 2, 3)], "Accent"):
		face_toward(obj, (0.0, 50.0, 3.0))
	# Navigation lights on the tips: red on the left, green on the right.
	v, f = box((tip_x + 0.03, -0.44, 3.9), (0.08, 0.1, 0.3))
	make("NavLight_R", coll, v, f, "NavGreen")
	make("NavLight_L", coll, [(-x, y, z) for x, y, z in v], f, "NavRed")


def details(coll):
	"""Orange panels along the nose, glowing strips on the flanks, a dark belly and the landing feet."""
	# Orange stripes along the top of the nose either side of the cockpit, lying on the hull's chamfer.
	for name, side in (("R", 1.0), ("L", -1.0)):
		stripe = []
		for z, w, top, _bottom, c in HULL_SECTIONS[1:4]:
			stripe.append((side * (w - c * 0.15), top - c * 0.85 + 0.012, z))
			stripe.append((side * (w + 0.012), top - c - 0.02, z))
		face_away(make("NoseStripe_" + name, coll, stripe, [(0, 1, 3, 2), (2, 3, 5, 4)], "Accent"), (0.0, -0.5, -4.0))
	# Glow strips along each flank.
	v, f = box((1.915, 0.1, 0.5), (0.03, 0.06, 3.2))
	both_sides("FlankGlow", coll, v, f, "Glow")
	# A dark keel under the hull.
	v, f = box((0.0, -1.14, 0.0), (1.6, 0.06, 9.0))
	make("Keel", coll, v, f, "Trim")
	# Landing feet: the underside rests on them at y = -1.2 (the bay floor berth).
	for i, (x, z) in enumerate(((0.0, -4.3), (-1.2, 3.4), (1.2, 3.4))):
		v, f = box((x, -1.18, z), (0.7, 0.04, 0.5))
		make("Foot_%d" % i, coll, v, f, "Trim")
	# A glowing light on the nose.
	v, f = box((0.0, -0.05, -7.26), (0.25, 0.06, 0.03))
	make("NoseLight", coll, v, f, "Glow")
	# An orange panel on the roof of the back half, and a light bar just behind the roof window.
	v, f = box((0.0, ROOF_BACK[2] + 0.012, -0.2), (2.0, 0.02, 3.2))
	make("RoofPanel", coll, v, f, "Accent")
	v, f = box((0.0, ROOF_BACK[2] + 0.012, -2.2), (0.6, 0.02, 0.08))
	make("RoofGlow", coll, v, f, "Glow")


# --- The cockpit ----------------------------------------------------------------------------------------------------

# The dashboard's face is the plane of the old greybox panel's front face, so the game's dashboard and nav screens sit
# 5 mm and 10 mm in front of it exactly as before. Profiles are (y, z); the dash stands on the cockpit floor.
DASH_CENTRE = ((0.0, -5.92), (0.0, -5.55), (0.30, -5.15), (0.406, -5.042), (0.866, -5.237), (0.60, -5.75))
DASH_HALF_WIDTH = 0.86
WING_PROFILE = ((0.0, -5.38), (0.0, -5.25), (0.25, -5.05), (0.33, -4.98), (0.66, -5.115), (0.52, -5.33))
WING_LENGTH = 0.27
WING_TURN = -25.0
WING_PIVOT = (DASH_HALF_WIDTH, 0.0, -5.1)
# The side consoles beside the seat: from just outside the pilot's knees to near the wall, front and back z, height.
CONSOLE_INNER = 0.95
CONSOLE_GAP = 0.04
CONSOLE_FRONT = -4.7
CONSOLE_BACK = -2.75
CONSOLE_TOP = 0.6


def dashboard(coll):
	v, f = prism_x(DASH_CENTRE, -DASH_HALF_WIDTH, DASH_HALF_WIDTH)
	bevel(make("Dash", coll, v, f, "Trim"))
	# A thin orange edge along the bottom of the screen face.
	v, f = box((0.0, 0.405, -5.035), (DASH_HALF_WIDTH * 2.0 - 0.1, 0.012, 0.02))
	make("Dash_Edge", coll, v, f, "Accent")
	# Side sections, turned toward the pilot, each with a small screen.
	v, f = prism_x(WING_PROFILE, DASH_HALF_WIDTH - 0.02, DASH_HALF_WIDTH + WING_LENGTH)
	bevel(make("DashWing_R", coll, transformed(v, WING_PIVOT, WING_TURN), f, "Panel"))
	bevel(make("DashWing_L", coll, transformed(v, WING_PIVOT, WING_TURN, mirror=True), f, "Panel"))
	lo, hi = Vector((0.0, 0.33, -4.98)), Vector((0.0, 0.66, -5.115))
	up = (hi - lo).normalized()
	normal = Vector((0.0, -up.z, up.y))
	mid = (lo + hi) * 0.5 + Vector((DASH_HALF_WIDTH + WING_LENGTH * 0.5, 0.0, 0.0)) + normal * 0.005
	corners = [mid + Vector((dx, 0.0, 0.0)) + up * dy for dx, dy in ((-0.11, -0.1), (0.11, -0.1), (0.11, 0.1), (-0.11, 0.1))]
	screen = [tuple(c) for c in corners]
	for obj in (make("SideScreen_R", coll, transformed(screen, WING_PIVOT, WING_TURN), [(0, 1, 2, 3)], "Screen"),
			make("SideScreen_L", coll, transformed(screen, WING_PIVOT, WING_TURN, mirror=True), [(0, 1, 2, 3)], "Screen")):
		face_toward(obj, ref.EYE)


def consoles(coll):
	"""A console each side, its outer edge following the wall, with a row of lit buttons; stick right, throttle left."""
	outer_front = cabin_half_width(CONSOLE_FRONT) - CONSOLE_GAP
	outer_back = cabin_half_width(CONSOLE_BACK) - CONSOLE_GAP
	plan = ((CONSOLE_INNER, CONSOLE_FRONT), (outer_front, CONSOLE_FRONT), (outer_back, CONSOLE_BACK),
		(CONSOLE_INNER, CONSOLE_BACK))
	v = [(x, CABIN_FLOOR, z) for x, z in plan] + [(x, CONSOLE_TOP, z) for x, z in plan]
	f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
	for obj in both_sides("Console", coll, v, f, "Panel"):
		bevel(obj)
	middle = (CONSOLE_INNER + outer_front) * 0.5
	for i in range(4):
		v, f = box((middle, CONSOLE_TOP + 0.008, -4.45 + 0.16 * i), (0.14, 0.016, 0.06))
		both_sides("ConsoleButton%d" % i, coll, v, f, "Glow")
	v, f = octagon_tube(0.0, 0.0, 0.0, 1.0, 0.025, 0.025)
	stick = [(middle + x, CONSOLE_TOP + z * 0.24, -3.75 + y) for x, y, z in v]  # stood upright
	make("Stick", coll, stick, f, "Trim")
	v, f = box((middle, CONSOLE_TOP + 0.29, -3.75), (0.07, 0.1, 0.09))
	make("Stick_Grip", coll, v, f, "Trim")
	v, f = box((-middle, CONSOLE_TOP + 0.04, -3.75), (0.1, 0.08, 0.3))
	make("Throttle", coll, v, f, "Trim")
	v, f = box((-middle, CONSOLE_TOP + 0.11, -3.7), (0.14, 0.06, 0.08))
	make("Throttle_Grip", coll, v, f, "Accent")


def seat(coll):
	v, f = box((0.0, 0.18, -3.15), (0.3, 0.36, 0.3))
	make("Seat_Base", coll, v, f, "Trim")
	v, f = box((0.0, 0.42, -3.18), (0.58, 0.12, 0.56))
	bevel(make("Seat_Cushion", coll, v, f, "Cabin"), 0.03)
	back = ((0.45, -2.98), (0.45, -2.86), (1.42, -2.68), (1.42, -2.8))
	v, f = prism_x(back, -0.29, 0.29)
	bevel(make("Seat_Back", coll, v, f, "Cabin"), 0.03)
	v, f = box((0.0, 1.33, -2.76), (0.4, 0.16, 0.1))
	make("Seat_Headrest", coll, v, f, "Accent")


def back_wall(coll):
	"""A dark panel over the cockpit's back wall (the front of the back half), inside the side windows."""
	half = cabin_half_width(CABIN_BACK) - 0.02
	z = CABIN_BACK - 0.01
	outline = [(-half, CABIN_FLOOR + 0.02), (half, CABIN_FLOOR + 0.02), (half, SILL_BACK[2]),
		(ROOF_BACK[1] - 0.06, ROOF_BACK[2] - 0.05), (-(ROOF_BACK[1] - 0.06), ROOF_BACK[2] - 0.05), (-half, SILL_BACK[2])]
	obj = make("BackWall", coll, [(x, y, z) for x, y in outline], [tuple(range(len(outline)))], "Panel")
	face_toward(obj, ref.EYE)


def floor_details(coll):
	"""A raised footrest plate on the cockpit floor."""
	v, f = box((0.0, 0.03, -4.6), (0.9, 0.06, 0.9))
	make("Footrest", coll, v, f, "Panel")


def check_cockpit(cockpit, panes, margin=0.003):
	"""What in the cockpit pokes out of it: [(part, how far, where)] for every part with a corner below the floor, in
	front of or behind the cockpit, through a wall below the sill, or through the glass. Empty when it all fits."""
	depsgraph = bpy.context.evaluated_depsgraph_get()
	planes = []
	for pane in panes:
		mesh = pane.data
		for poly in mesh.polygons:
			planes.append((pane.matrix_world @ poly.center, (pane.matrix_world.to_3x3() @ poly.normal).normalized()))
	problems = []
	for obj in cockpit.all_objects:
		if obj.type != "MESH":
			continue
		mesh = obj.evaluated_get(depsgraph).to_mesh()
		worst, where = 0.0, None
		for vert in mesh.vertices:
			b = obj.matrix_world @ vert.co
			x, y, z = b.x, b.z, -b.y  # Godot
			out = max(CABIN_FLOOR - y, CABIN_FRONT - z, z - CABIN_BACK)
			sill_w, sill_y = sill(min(max(z, SILL_FRONT[0]), SILL_BACK[0]))
			if y < sill_y:
				out = max(out, abs(x) - (sill_w - WALL))
			for point, normal in planes:
				out = max(out, (b - point).dot(normal))
			if out > worst + margin:
				worst, where = out, (round(x, 3), round(y, 3), round(z, 3))
		obj.evaluated_get(depsgraph).to_mesh_clear()
		if where is not None:
			problems.append((obj.name, round(worst, 3), where))
	return problems


# --- Building -------------------------------------------------------------------------------------------------------

def clear(coll):
	for obj in list(coll.all_objects):
		mesh = obj.data if obj.type == "MESH" else None
		bpy.data.objects.remove(obj, do_unlink=True)
		if mesh is not None and mesh.users == 0:
			bpy.data.meshes.remove(mesh)


def build():
	exterior = bpy.data.collections["Exterior"]
	cockpit = bpy.data.collections["Cockpit"]
	cutters = ref.collection("Cutters", bpy.data.collections[ref.REFERENCE])
	for coll in (exterior, cockpit, cutters):
		clear(coll)
	hull(exterior, cutters)
	upper_body(exterior)
	panes = glass(exterior)
	pods(exterior)
	wings(exterior)
	details(exterior)
	dashboard(cockpit)
	consoles(cockpit)
	seat(cockpit)
	back_wall(cockpit)
	floor_details(cockpit)
	problems = check_cockpit(cockpit, panes)
	for name, depth, where in problems:
		print("COCKPIT CLIPS: %s pokes %.3f m out at %s" % (name, depth, where))
	return exterior, cockpit


def triangles(coll):
	"""Triangles the collection exports with, modifiers applied."""
	depsgraph = bpy.context.evaluated_depsgraph_get()
	total = 0
	for obj in coll.all_objects:
		if obj.type != "MESH":
			continue
		mesh = obj.evaluated_get(depsgraph).to_mesh()
		total += sum(len(p.vertices) - 2 for p in mesh.polygons)
		obj.evaluated_get(depsgraph).to_mesh_clear()
	return total


if __name__ == "__main__":
	build()
