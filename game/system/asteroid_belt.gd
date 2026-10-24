class_name AsteroidBelt
extends Landmark
## An asteroid belt (design doc, "The tiny solar system"): a ring of rocks round its centre, flat in its own x-z plane,
## whose place is authored and whose rocks come from the world seed (BeltLayout), so the same seed always gives the
## same belt. Built once when it enters the scene:
## - Drawn in BeltTuning.chunks pieces round the ring, each piece one MultiMesh close up (lumpy rocks) and one far away
##   (simple shapes), so a few draw calls cover thousands of rocks and pieces out of view aren't drawn. A faint haze
##   along the band shows the belt from afar, where single rocks are too small to see.
## - Only the rocks near the ship are solid: a fixed pool of sphere bodies is moved onto the nearest ones every few
##   ticks, a body staying on its rock while that rock stays near. Nothing is created or freed in flight.
## For the cruise drive its surface is the band's edge: inside the band counts as inside the belt.

@export var tuning: BeltTuning
@export var rock_material: Material
@export var haze_material: Material
## Whose surroundings are made solid (the player's ship). SolarSystem sets it.
var focus: Node3D

var layout: BeltLayout
## How many rocks are solid now.
var solid_count: int = 0

var _bodies: Array[StaticBody3D] = []
var _colliders: Array[CollisionShape3D] = []
var _shapes: Array[SphereShape3D] = []
## Per pool body: the rock it stands in for, or -1 when it is off. Per rock: its body, or -1.
var _solid_rock: PackedInt32Array = PackedInt32Array()
var _slot_of: PackedInt32Array = PackedInt32Array()
## Per rock: the pick it was last wanted in (_stamp), so picks never need clearing.
var _wanted: PackedInt32Array = PackedInt32Array()
var _stamp: int = 0
var _best: PackedInt32Array = PackedInt32Array()
var _best_d: PackedFloat32Array = PackedFloat32Array()
var _ticks: int = 0


func _ready() -> void:
	layout = BeltLayout.generate(tuning, Game.world_rng(tuning.feature))
	_build_chunks()
	_build_haze()
	_build_pool()


## How far (m) `point` is from the band; zero inside it.
func surface_distance(point: Vector3) -> float:
	var local := to_local(point)
	var out_r := absf(Vector2(local.x, local.z).length() - tuning.ring_radius) - tuning.half_width
	var out_y := absf(local.y) - tuning.half_height
	return Vector2(maxf(out_r, 0.0), maxf(out_y, 0.0)).length()


## The home pocket, where the rocks are closest together.
func marker_position() -> Vector3:
	return to_global(layout.pocket_centres[0])


## Its marker shows the distance to the home pocket it points at.
func marker_distance(point: Vector3) -> float:
	return point.distance_to(marker_position())


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if focus == null or _ticks % tuning.solid_every != 0:
		return
	var at := to_local(focus.global_position)
	if surface_distance(focus.global_position) > tuning.solid_reach:
		_set_solid_none()
		return
	_pick_nearest(at)


## The rocks within reach of `at` (belt space), nearest first, up to the pool's size, made solid.
func _pick_nearest(at: Vector3) -> void:
	var found := 0
	var reach_sq := tuning.solid_reach * tuning.solid_reach
	var centre := BeltLayout.chunk_at(at, tuning.chunks)
	for step in 3:
		var rocks: PackedInt32Array = layout.chunk_rocks[posmod(centre + step - 1, tuning.chunks)]
		for i: int in rocks:
			var d := at.distance_squared_to(layout.positions[i])
			if d > reach_sq:
				continue
			# Insert into the nearest-first list, dropping the farthest once it is full.
			var slot := mini(found, _best.size() - 1)
			if found == _best.size() and d >= _best_d[slot]:
				continue
			while slot > 0 and _best_d[slot - 1] > d:
				_best[slot] = _best[slot - 1]
				_best_d[slot] = _best_d[slot - 1]
				slot -= 1
			_best[slot] = i
			_best_d[slot] = d
			found = mini(found + 1, _best.size())
	_stamp += 1
	for k in found:
		_wanted[_best[k]] = _stamp
	# Rocks that stay solid keep their bodies, so nothing the ship touches moves under it; only the freed bodies move
	# onto the newly near rocks.
	for k in _solid_rock.size():
		var i := _solid_rock[k]
		if i >= 0 and _wanted[i] != _stamp:
			_free_slot(k)
	var free := 0
	for n in found:
		var i := _best[n]
		if _slot_of[i] >= 0:
			continue
		while _solid_rock[free] >= 0:
			free += 1
		_solid_rock[free] = i
		_slot_of[i] = free
		_shapes[free].radius = layout.solid_radius(i)
		_bodies[free].position = layout.positions[i]
		_colliders[free].disabled = false
	solid_count = found


func _set_solid_none() -> void:
	if solid_count == 0:
		return
	for k in _solid_rock.size():
		if _solid_rock[k] >= 0:
			_free_slot(k)
	solid_count = 0


func _free_slot(k: int) -> void:
	_slot_of[_solid_rock[k]] = -1
	_solid_rock[k] = -1
	_colliders[k].disabled = true


func _build_chunks() -> void:
	var near_mesh := RockMesh.near_rock(rock_material)
	var far_mesh := RockMesh.far_rock(rock_material)
	for c in tuning.chunks:
		var rocks := layout.chunk_rocks[c]
		if rocks.is_empty():
			continue
		# Each piece sits at its rocks' middle, so its distance from the camera (for the switch between detailed and
		# simple rocks) is measured from where its rocks are.
		var middle := Vector3.ZERO
		for i: int in rocks:
			middle += layout.positions[i]
		middle /= rocks.size()
		_add_chunk("Chunk%d" % c, rocks, middle, near_mesh, 0.0, tuning.near_distance)
		_add_chunk("Chunk%dFar" % c, rocks, middle, far_mesh, tuning.near_distance, tuning.far_distance)


func _add_chunk(node_name: String, rocks: PackedInt32Array, middle: Vector3, mesh: Mesh, from: float,
		to: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = rocks.size()
	for k in rocks.size():
		var t := layout.rock_transform(rocks[k])
		t.origin -= middle
		mm.set_instance_transform(k, t)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.position = middle
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_begin = from
	instance.visibility_range_end = to
	instance.visibility_range_begin_margin = from * CelestialBody.LOD_HYSTERESIS
	instance.visibility_range_end_margin = to * CelestialBody.LOD_HYSTERESIS
	add_child(instance)


## A flat ring along the band (game/system/belt_haze.gdshader): `HAZE_SEGMENTS` pieces round, one draw call.
func _build_haze() -> void:
	const HAZE_SEGMENTS := 256
	var inner := tuning.ring_radius - tuning.half_width
	var outer := tuning.ring_radius + tuning.half_width
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in HAZE_SEGMENTS:
		var a0 := TAU * s / HAZE_SEGMENTS
		var a1 := TAU * (s + 1) / HAZE_SEGMENTS
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		for v: Vector3 in [d0 * inner, d0 * outer, d1 * outer, d0 * inner, d1 * outer, d1 * inner]:
			st.set_uv(Vector2((v.length() - inner) / (outer - inner), 0.0))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, haze_material)
	var instance := MeshInstance3D.new()
	instance.name = "Haze"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_pool() -> void:
	_best.resize(tuning.solid_rocks)
	_best_d.resize(tuning.solid_rocks)
	_solid_rock.resize(tuning.solid_rocks)
	_solid_rock.fill(-1)
	_slot_of.resize(layout.count())
	_slot_of.fill(-1)
	_wanted.resize(layout.count())
	_wanted.fill(0)
	for k in tuning.solid_rocks:
		var ball := SphereShape3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = ball
		shape.disabled = true
		var body := StaticBody3D.new()
		body.name = "Solid%d" % k
		body.add_child(shape)
		add_child(body)
		_bodies.append(body)
		_colliders.append(shape)
		_shapes.append(ball)
