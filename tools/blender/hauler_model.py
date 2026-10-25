"""Builds the Hauler's placeholder model in Blender: the ship as the chase camera sees it ("Exterior") and the cockpit
round the pilot ("Cockpit"). Run ship_reference.py first (it makes the collections and the reference shapes), then
this; running it again rebuilds both collections from scratch. export_ship.py then writes the .glb files.

Everything is placed in Godot's coordinates (x right, y up, z back, metres from the ship's centre) through
ship_reference.to_blender, so the numbers read the same as the game's scenes. The model follows the owner's
references (2026-10-25): a small, simple ship, light grey with orange panels and a few glowing strips, cockpit up front,
two engines on the sides at the back, short swept wings; inside, a slim dashboard low across the bottom of the view and
one canopy with no frame bars in the way. Kept round the game's fixed points: the pilot's eye, the dashboard and nav
computer screens, the collision shapes and the bay floor berth (the underside at y = -1.2).
"""

import math

import bmesh
import bpy
from mathutils import Vector

import ship_reference as ref

# The canopy: part of an ellipsoid (centre, semi-axes, Godot) cut by a plane that rises toward the back, so the glass
# comes down low in front (below the dashboard's top edge, out of sight) and sits higher at the back.
CANOPY_CENTRE = Vector((0.0, 0.85, -3.6))
CANOPY_AXES = Vector((1.6, 1.35, 2.45))
CANOPY_RIM_RISE = 0.0816  # m up per m back
CANOPY_SEGMENTS = 20
CANOPY_RINGS = (0.0, 0.18, 0.36, 0.55, 0.75)
# How far inside the canopy's edge the cockpit's well is cut, and its floor.
WELL_INSET = 0.97
WELL_FLOOR = 0.0

# The hull from nose to tail: (z, half width, top, bottom, chamfer), Godot. Its top under the canopy follows the rim.
HULL_SECTIONS = (
	(-7.25, 0.22, 0.22, -0.32, 0.08),
	(-6.6, 0.8, 0.5, -0.62, 0.15),
	(-5.95, 1.3, 0.65, -0.82, 0.18),
	(-4.0, 1.78, 0.82, -1.05, 0.22),
	(-1.0, 1.85, 1.07, -1.12, 0.3),
	(2.5, 1.7, 1.12, -1.12, 0.3),
	(5.6, 1.25, 0.9, -0.85, 0.25),
	(6.2, 0.9, 0.62, -0.6, 0.18),
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


# --- The canopy -----------------------------------------------------------------------------------------------------

def rim_y(z):
	return CANOPY_CENTRE.y + (z - CANOPY_CENTRE.z) * CANOPY_RIM_RISE


def rim_point(theta, scale=1.0):
	"""Where the canopy's edge is at angle `theta` round from straight ahead (radians), as a Godot Vector."""
	s, c = math.sin(theta), math.cos(theta)
	ax, ay, az = CANOPY_AXES
	r = 1.0 / math.sqrt((s / ax) ** 2 + (CANOPY_RIM_RISE * c / ay) ** 2 + (c / az) ** 2)
	x = r * s * scale
	z = CANOPY_CENTRE.z - r * c * scale
	return Vector((x, rim_y(z), z))


def on_canopy(v):
	"""`v` (a direction from the canopy's centre) pushed out onto the ellipsoid."""
	d = Vector((v.x / CANOPY_AXES.x, v.y / CANOPY_AXES.y, v.z / CANOPY_AXES.z)).normalized()
	return CANOPY_CENTRE + Vector((d.x * CANOPY_AXES.x, d.y * CANOPY_AXES.y, d.z * CANOPY_AXES.z))


def canopy(coll):
	"""The glass: rings from the rim up to the top, faceted like the hull, with a short skirt sunk into the hull."""
	n = CANOPY_SEGMENTS
	top = Vector((0.0, CANOPY_AXES.y, 0.0))
	rims = [rim_point(math.tau * i / n) for i in range(n)]
	verts = [r - Vector((0.0, 0.06, 0.0)) for r in rims]  # skirt
	for t in CANOPY_RINGS:
		verts += [on_canopy((r - CANOPY_CENTRE).lerp(top, t)) for r in rims]
	verts.append(CANOPY_CENTRE + top)
	rings = len(CANOPY_RINGS) + 1
	faces = []
	for ring in range(rings - 1):
		a, b = ring * n, (ring + 1) * n
		faces += [(a + i, a + (i + 1) % n, b + (i + 1) % n, b + i) for i in range(n)]
	apex = len(verts) - 1
	last = (rings - 1) * n
	faces += [(last + i, last + (i + 1) % n, apex) for i in range(n)]
	obj = make("Canopy_Glass", coll, [tuple(v) for v in verts], faces, "Glass", smooth=True, fix_normals=False)
	# Faces must point out of the canopy so it is see-through from the cockpit.
	mesh = obj.data
	centre = ref.to_blender(CANOPY_CENTRE)
	outward = sum((p.center - centre).dot(p.normal) for p in mesh.polygons)
	if outward < 0.0:
		mesh.flip_normals()
	obj.visible_shadow = False
	return obj


def well_cutter(coll):
	"""The shape cut out of the hull for the cockpit: the canopy's edge (a little inside it) straight down to the
	floor. Not exported; the hull's Boolean uses it, and the cut walls take its material."""
	n = CANOPY_SEGMENTS
	rims = [rim_point(math.tau * i / n, WELL_INSET) for i in range(n)]
	verts = [(r.x, WELL_FLOOR, r.z) for r in rims] + [(r.x, 3.0, r.z) for r in rims]
	faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
	faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
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
		fin = [(x - 0.06, POD_Y + 0.6, 4.6), (x - 0.06, POD_Y + 0.6, 6.9), (x - 0.06, 1.45, 6.85), (x - 0.06, 1.45, 6.2),
			(x + 0.06, POD_Y + 0.6, 4.6), (x + 0.06, POD_Y + 0.6, 6.9), (x + 0.06, 1.45, 6.85), (x + 0.06, 1.45, 6.2)]
		make("Fin_" + name, coll, fin, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)],
			"Hull")
		tip = [(x - 0.065, 1.2, 6.27), (x - 0.065, 1.2, 6.87), (x - 0.065, 1.45, 6.85), (x - 0.065, 1.45, 6.2),
			(x + 0.065, 1.2, 6.27), (x + 0.065, 1.2, 6.87), (x + 0.065, 1.45, 6.85), (x + 0.065, 1.45, 6.2)]
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
	# Orange stripes along the top of the nose either side of the canopy, lying on the hull's chamfer.
	for name, side in (("R", 1.0), ("L", -1.0)):
		stripe = []
		for z, w, top, _bottom, c in HULL_SECTIONS[1:4]:
			stripe.append((side * (w - c * 0.15), top - c * 0.85 + 0.012, z))
			stripe.append((side * (w + 0.012), top - c - 0.02, z))
		face_away(make("NoseStripe_" + name, coll, stripe, [(0, 1, 3, 2), (2, 3, 5, 4)], "Accent"), (0.0, -0.5, -4.0))
	# Glow strips along each flank.
	v, f = box((1.885, 0.1, 0.5), (0.03, 0.06, 3.2))
	both_sides("FlankGlow", coll, v, f, "Glow")
	# A dark keel under the hull.
	v, f = box((0.0, -1.14, 0.0), (1.6, 0.06, 9.0))
	make("Keel", coll, v, f, "Trim")
	# Landing feet: the underside rests on them at y = -1.2 (the bay floor berth).
	for i, (x, z) in enumerate(((0.0, -4.3), (-1.2, 3.4), (1.2, 3.4))):
		v, f = box((x, -1.18, z), (0.7, 0.04, 0.5))
		make("Foot_%d" % i, coll, v, f, "Trim")
	# Glowing nose light and a dorsal light behind the canopy.
	v, f = box((0.0, -0.05, -7.26), (0.25, 0.06, 0.03))
	make("NoseLight", coll, v, f, "Glow")
	# An orange panel on the back of the hull's top, and a raised spine down its middle.
	v, f = box((0.0, 1.125, 2.2), (2.2, 0.02, 3.4))
	make("DorsalPanel", coll, v, f, "Accent")
	v, f = box((0.0, 1.17, 0.6), (0.5, 0.12, 3.0))
	make("Spine", coll, v, f, "Hull")
	v, f = box((0.0, 1.235, 0.4), (0.3, 0.02, 0.6))
	make("SpineGlow", coll, v, f, "Glow")


# --- The cockpit ----------------------------------------------------------------------------------------------------

# The dashboard's face is the plane of the old greybox panel's front face, so the game's dashboard and nav screens sit
# 5 mm and 10 mm in front of it exactly as before. Profiles are (y, z).
DASH_CENTRE = ((0.0, -5.92), (0.0, -5.55), (0.30, -5.15), (0.406, -5.042), (0.866, -5.237), (0.60, -5.75))
DASH_HALF_WIDTH = 0.95
WING_PROFILE = ((0.0, -5.55), (0.0, -5.3), (0.25, -5.05), (0.33, -4.98), (0.70, -5.13), (0.55, -5.45))
WING_LENGTH = 0.42
WING_TURN = -25.0
CONSOLE_PROFILE = ((0.0, -4.85), (0.0, -2.9), (0.6, -2.9), (0.66, -4.5), (0.52, -4.85))


def dashboard(coll):
	v, f = prism_x(DASH_CENTRE, -DASH_HALF_WIDTH, DASH_HALF_WIDTH)
	bevel(make("Dash", coll, v, f, "Trim"))
	# A dark top so the glass reflects nothing bright, sitting just on the dash's upper surface.
	top = [(-DASH_HALF_WIDTH + 0.02, 0.866 + 0.004, -5.237), (DASH_HALF_WIDTH - 0.02, 0.866 + 0.004, -5.237),
		(DASH_HALF_WIDTH - 0.02, 0.60 + 0.004, -5.75), (-DASH_HALF_WIDTH + 0.02, 0.60 + 0.004, -5.75)]
	face_toward(make("Dash_Top", coll, top, [(0, 1, 2, 3)], "Cabin"), (0.0, 5.0, -5.4))
	# An orange edge along the bottom of the screen face.
	v, f = box((0.0, 0.405, -5.035), (DASH_HALF_WIDTH * 2.0 - 0.1, 0.012, 0.02))
	make("Dash_Edge", coll, v, f, "Accent")
	# Side sections, turned toward the pilot, each with a small screen.
	pivot = (DASH_HALF_WIDTH, 0.0, -5.1)
	v, f = prism_x(WING_PROFILE, DASH_HALF_WIDTH - 0.02, DASH_HALF_WIDTH + WING_LENGTH)
	wv = transformed(v, pivot, WING_TURN)
	right = bevel(make("DashWing_R", coll, wv, f, "Panel"))
	left = bevel(make("DashWing_L", coll, transformed(v, pivot, WING_TURN, mirror=True), f, "Panel"))
	up = Vector((0.0, 0.70 - 0.33, -5.13 + 4.98)).normalized()
	normal = Vector((0.0, -up.z, up.y))
	mid = Vector((DASH_HALF_WIDTH + WING_LENGTH * 0.5, 0.515, -5.055)) + normal * 0.005
	corners = [mid + Vector((dx, 0.0, 0.0)) + up * dy for dx, dy in ((-0.15, -0.1), (0.15, -0.1), (0.15, 0.1), (-0.15, 0.1))]
	screen = [tuple(c) for c in corners]
	for obj in (make("SideScreen_R", coll, transformed(screen, pivot, WING_TURN), [(0, 1, 2, 3)], "Screen"),
			make("SideScreen_L", coll, transformed(screen, pivot, WING_TURN, mirror=True), [(0, 1, 2, 3)], "Screen")):
		face_toward(obj, ref.EYE)
	return right, left


def consoles(coll):
	v, f = prism_x(CONSOLE_PROFILE, 1.0, 1.45)
	for obj in both_sides("Console", coll, v, f, "Panel"):
		bevel(obj)
	# A strip of glowing buttons on each, and an orange edge.
	for i in range(4):
		v, f = box((1.18, 0.655 - 0.01 * i, -4.3 + 0.18 * i), (0.14, 0.02, 0.06))
		both_sides("ConsoleButton%d" % i, coll, v, f, "Glow")
	# Flight stick on the right, throttle on the left.
	v, f = octagon_tube(1.22, 0.0, 0.0, 1.0, 0.025, 0.025)
	stick = [(x, z * 0.24 + 0.64, -4.0 + (y - 0.0)) for x, y, z in v]  # stand it upright
	make("Stick", coll, stick, f, "Trim")
	v, f = box((1.22, 0.92, -4.0), (0.07, 0.1, 0.09))
	make("Stick_Grip", coll, v, f, "Trim")
	v, f = box((-1.22, 0.7, -4.0), (0.1, 0.08, 0.3))
	make("Throttle", coll, v, f, "Trim")
	v, f = box((-1.22, 0.78, -3.95), (0.14, 0.06, 0.08))
	make("Throttle_Grip", coll, v, f, "Accent")


def seat(coll):
	v, f = box((0.0, 0.18, -3.15), (0.3, 0.36, 0.3))
	make("Seat_Base", coll, v, f, "Trim")
	v, f = box((0.0, 0.42, -3.18), (0.58, 0.12, 0.56))
	bevel(make("Seat_Cushion", coll, v, f, "Cabin"), 0.03)
	back = ((0.45, -2.98), (0.45, -2.86), (1.42, -2.68), (1.42, -2.8))
	v, f = prism_x(back, -0.29, 0.29)
	bevel(make("Seat_Back", coll, v, f, "Cabin"), 0.03)
	v, f = box((0.0, 1.33, -2.7), (0.4, 0.16, 0.1))
	make("Seat_Headrest", coll, v, f, "Accent")


def floor_details(coll):
	"""A raised footrest plate in the cockpit well."""
	v, f = box((0.0, 0.03, -4.6), (0.9, 0.06, 0.9))
	make("Footrest", coll, v, f, "Panel")


# --- Building -------------------------------------------------------------------------------------------------------

def clear(coll):
	for obj in list(coll.all_objects):
		mesh = obj.data if obj.type == "MESH" else None
		bpy.data.objects.remove(obj, do_unlink=True)
		if mesh is not None and mesh.users == 0:
			bpy.data.meshes.remove(mesh)


def build():
	scene = bpy.context.scene
	exterior = bpy.data.collections["Exterior"]
	cockpit = bpy.data.collections["Cockpit"]
	cutters = ref.collection("Cutters", bpy.data.collections[ref.REFERENCE])
	for coll in (exterior, cockpit, cutters):
		clear(coll)
	hull(exterior, cutters)
	canopy(exterior)
	pods(exterior)
	wings(exterior)
	details(exterior)
	dashboard(cockpit)
	consoles(cockpit)
	seat(cockpit)
	floor_details(cockpit)
	scene.render.engine = scene.render.engine  # unchanged; renders are the caller's choice
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
