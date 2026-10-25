class_name OrbitLine
extends MeshInstance3D
## The orbit line in the world (design doc, "Orbit"): near a planet or moon, a faint lane round it at its orbit height,
## in the plane the ship would go round in (Orbit.guide_axis), so the pilot can see where the orbit is and fly up (or
## down) onto it. Seen from below it arches overhead and runs off over the horizon; its edges are brighter than its
## middle. It fades out close to the camera, so it never cuts across the cockpit, and the planet hides its far side.
## Hidden in orbit, while cruising, docked or landed (whenever Orbit offers nothing). One mesh, a ring of unit radius
## and height, built once; each frame only the transform changes, so nothing is allocated. Outside the floating
## origin's world: it is placed from the body's position every frame. Placeholder look until the art style is chosen.

## Pieces round the ring: at Calder's orbit each is about 220 m long and bows out under a metre.
const SEGMENTS := 256
## The lane's width, as a share of its radius (about 50 m round Calder, 16 m round Mote).
const WIDTH_SHARE := 0.006
## The lane's opacity at its edges and down its middle.
const EDGE_ALPHA := 0.55
const MIDDLE_ALPHA := 0.08
## It fades in between these distances (m) from the camera.
const FADE_NEAR := 150.0
const FADE_FAR := 600.0

@export var ship: Ship


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = OrbitLine.build_ring()
	material_override = OrbitLine.build_material()
	visible = false


func _process(_delta: float) -> void:
	var b := ship.orbit.offered if ship != null else null
	visible = b != null
	if b == null:
		return
	var o := ship.orbit
	var r := b.orbit_radius()
	var across := o.insertion.normalized()
	global_transform = Transform3D(Basis(across * r, o.guide_axis * r * WIDTH_SHARE, o.guide_axis.cross(across) * r),
			b.global_position)


## A ring of radius 1 round the y axis, 1 high: three rows of points round it (bottom edge, middle, top edge), the
## edges more opaque than the middle.
static func build_ring() -> ArrayMesh:
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	var white := Color(1.0, 1.0, 1.0, EDGE_ALPHA)
	var middle := Color(1.0, 1.0, 1.0, MIDDLE_ALPHA)
	for i in SEGMENTS + 1:
		var a := TAU * i / SEGMENTS
		var round_point := Vector3(cos(a), 0.0, sin(a))
		points.append(round_point + Vector3(0.0, -0.5, 0.0))
		points.append(round_point)
		points.append(round_point + Vector3(0.0, 0.5, 0.0))
		colours.append(white)
		colours.append(middle)
		colours.append(white)
	var order := PackedInt32Array()
	for i in SEGMENTS:
		for row in 2:
			var k := i * 3 + row
			order.append_array([k, k + 3, k + 1, k + 1, k + 3, k + 4])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = order
	var ring := ArrayMesh.new()
	ring.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return ring


## Unlit, see-through, seen from both sides, in the orbit's colour, fading in away from the camera.
static func build_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = FlightHud.ORBIT_COLOUR
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = FADE_NEAR
	m.distance_fade_max_distance = FADE_FAR
	return m
