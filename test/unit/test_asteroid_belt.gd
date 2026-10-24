extends GutTest
## The asteroid belt (design doc, "Authored vs. seeded"): the same world seed always builds the same rocks and another
## seed builds different ones; every rock sits inside the band; the home pocket is where the tuning says; only the rocks
## near the ship are solid, never more than the pool holds. Also the generators world features are built from.

const SEED := 1234

var _tuning: BeltTuning
var _saved_seed: int


func before_each() -> void:
	_tuning = load("res://game/system/shingle_belt.tres")
	_saved_seed = Game.world_seed
	Game.start_world(SEED)


func after_each() -> void:
	Game.start_world(_saved_seed)


func _layout(seed_value: int) -> BeltLayout:
	Game.start_world(seed_value)
	return BeltLayout.generate(_tuning, Game.world_rng(_tuning.feature))


func test_the_same_seed_builds_the_same_belt() -> void:
	var a := _layout(SEED)
	var b := _layout(SEED)
	assert_eq(a.count(), b.count())
	assert_eq(a.positions, b.positions)
	assert_eq(a.radii, b.radii)
	assert_eq(a.checksum(), b.checksum())


func test_another_seed_builds_another_belt() -> void:
	assert_ne(_layout(SEED).checksum(), _layout(SEED + 1).checksum())


func test_gameplay_draws_never_move_the_belt() -> void:
	var a := _layout(SEED)
	Game.start_world(SEED)
	for i in 100:
		Game.rng(&"contracts").randi()
	var b := BeltLayout.generate(_tuning, Game.world_rng(_tuning.feature))
	assert_eq(a.checksum(), b.checksum(), "contract draws before building it change nothing")
	var other := BeltLayout.generate(_tuning, Game.world_rng(&"belt:another"))
	assert_ne(a.checksum(), other.checksum(), "another feature name is another belt")


func test_holds_exactly_the_rocks_it_should() -> void:
	var a := _layout(SEED)
	assert_eq(a.count(), _tuning.scattered + _tuning.pockets * _tuning.rocks_per_pocket)
	assert_eq(a.pocket_centres.size(), _tuning.pockets)
	var in_chunks := 0
	for rocks: PackedInt32Array in a.chunk_rocks:
		in_chunks += rocks.size()
	assert_eq(in_chunks, a.count(), "every rock is drawn in exactly one piece")


func test_every_rock_is_inside_the_band_and_sized_right() -> void:
	var a := _layout(SEED)
	var bad := 0
	for i in a.count():
		var p := a.positions[i]
		var r := Vector2(p.x, p.z).length()
		if absf(r - _tuning.ring_radius) > _tuning.half_width + 0.01 or absf(p.y) > _tuning.half_height + 0.01:
			bad += 1
		if a.radii[i] < _tuning.rock_min_radius - 0.01 or a.radii[i] > _tuning.rock_max_radius + 0.01:
			bad += 1
	assert_eq(bad, 0)


func test_the_home_pocket_is_on_the_inner_edge_where_the_tuning_says() -> void:
	var home := _layout(SEED).pocket_centres[0]
	var angle := rad_to_deg(atan2(home.z, home.x))
	assert_almost_eq(angle, _tuning.home_angle, 0.01)
	assert_almost_eq(Vector2(home.x, home.z).length(),
			_tuning.ring_radius - _tuning.half_width + _tuning.pocket_radius, 0.1)
	assert_eq(home, _layout(SEED + 7).pocket_centres[0], "the same on every seed: it is authored")


func test_surface_is_the_band_edge() -> void:
	var belt := _belt()
	var r := _tuning.ring_radius
	assert_eq(belt.surface_distance(Vector3(r, 0, 0)), 0.0, "inside the band")
	assert_almost_eq(belt.surface_distance(Vector3(r - _tuning.half_width - 500.0, 0, 0)), 500.0, 0.1, "inside the ring")
	assert_almost_eq(belt.surface_distance(Vector3(0, _tuning.half_height + 300.0, r)), 300.0, 0.1, "above it")
	assert_almost_eq(belt.marker_position(), belt.layout.pocket_centres[0], Vector3.ONE * 0.01)


func test_only_the_rocks_near_the_ship_are_solid_and_never_too_many() -> void:
	var belt := _belt()
	var ship := Node3D.new()
	add_child_autofree(ship)
	belt.focus = ship
	ship.global_position = Vector3.ZERO
	await wait_physics_frames(_tuning.solid_every + 1)
	assert_eq(belt.solid_count, 0, "nothing solid far from the band")
	ship.global_position = belt.layout.pocket_centres[0]
	await wait_physics_frames(_tuning.solid_every + 1)
	assert_eq(belt.solid_count, _tuning.solid_rocks, "a full pool in the home pocket")
	var nearest := INF
	for i in belt.layout.count():
		nearest = minf(nearest, belt.layout.positions[i].distance_to(ship.global_position))
	var bodies := belt.find_children("Solid*", "StaticBody3D", false, false)
	assert_eq(bodies.size(), _tuning.solid_rocks, "the pool never grows")
	var closest := INF
	var enabled := 0
	for body: Node in bodies:
		var shape := body.get_child(0) as CollisionShape3D
		if not shape.disabled:
			enabled += 1
			closest = minf(closest, (body as Node3D).position.distance_to(ship.global_position))
	assert_eq(enabled, _tuning.solid_rocks)
	assert_almost_eq(closest, nearest, 0.01, "the nearest rock is among the solid ones")


func test_a_rock_that_stays_near_keeps_its_body() -> void:
	var belt := _belt()
	var ship := Node3D.new()
	add_child_autofree(ship)
	belt.focus = ship
	ship.global_position = belt.layout.pocket_centres[0]
	await wait_physics_frames(_tuning.solid_every + 1)
	var before := _solid_places(belt)
	ship.global_position += Vector3(150, 0, 0)
	await wait_physics_frames(_tuning.solid_every + 1)
	var after := _solid_places(belt)
	var kept := 0
	var moved := 0
	for body: Node3D in before:
		if after.has(body) and after.values().has(before[body]):
			kept += 1
			if after[body] != before[body]:
				moved += 1
	assert_gt(kept, 0, "some rocks are near both times")
	assert_eq(moved, 0, "a rock still near is still on the body it had")


## The pool bodies that are on, and where each one is.
func _solid_places(belt: AsteroidBelt) -> Dictionary:
	var out := {}
	for body: Node in belt.find_children("Solid*", "StaticBody3D", false, false):
		if not (body.get_child(0) as CollisionShape3D).disabled:
			out[body] = (body as Node3D).position
	return out


func test_rock_meshes_face_outwards() -> void:
	var mat := StandardMaterial3D.new()
	for mesh: ArrayMesh in [RockMesh.near_rock(mat), RockMesh.far_rock(mat)]:
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var inward := 0
		for i in range(0, verts.size(), 3):
			var middle := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
			if normals[i].dot(middle) <= 0.0:
				inward += 1
			# Drawn clockwise seen from outside: the winding's own normal points in.
			var wound := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
			if wound.dot(normals[i]) >= 0.0:
				inward += 1
		assert_eq(inward, 0)
	assert_eq(RockMesh.near_rock(mat).surface_get_array_len(0), 80 * 3, "80 faces close up")
	assert_eq(RockMesh.far_rock(mat).surface_get_array_len(0), 8 * 3, "8 far away")


func _belt() -> AsteroidBelt:
	Game.start_world(SEED)
	var belt := AsteroidBelt.new()
	belt.tuning = _tuning
	belt.rock_material = StandardMaterial3D.new()
	belt.haze_material = StandardMaterial3D.new()
	add_child_autofree(belt)
	return belt
