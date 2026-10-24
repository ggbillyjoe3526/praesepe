class_name BeltLayout
extends RefCounted
## Where every rock of an asteroid belt sits, worked out from the world seed (design doc, "Authored vs. seeded"): the
## same seed and BeltTuning always give the same rocks, in the same order. Positions are in the belt's own space: the
## ring lies flat in its x-z plane around its origin. Built once when the belt is made, never during flight.

## Per rock: its middle, its size (m, radius), and how it is turned and squashed (a rotation times a scale near 1).
var positions: PackedVector3Array = PackedVector3Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var shapes: Array[Basis] = []
## The middle of each pocket; the first is the home pocket the belt's marker points to.
var pocket_centres: PackedVector3Array = PackedVector3Array()
## Which piece of the ring (BeltTuning.chunks) each rock is drawn in, and the rocks in each piece.
var chunk_of: PackedInt32Array = PackedInt32Array()
var chunk_rocks: Array[PackedInt32Array] = []


## The layout for `tuning`, drawing from `rng` (Game.world_rng(tuning.feature)): pockets first, then their rocks, then
## the scattered ones. Changing that order changes every seeded belt.
static func generate(tuning: BeltTuning, rng: RandomNumberGenerator) -> BeltLayout:
	var out := BeltLayout.new()
	var home := deg_to_rad(tuning.home_angle)
	var inner := tuning.ring_radius - tuning.half_width
	out.pocket_centres.append(Vector3(cos(home), 0.0, sin(home)) * (inner + tuning.pocket_radius))
	var spread := maxf(tuning.half_width - tuning.pocket_radius, 0.0)
	for i in range(1, tuning.pockets):
		var angle := rng.randf() * TAU
		var r := tuning.ring_radius + rng.randf_range(-spread, spread)
		var y := rng.randf_range(-0.5, 0.5) * tuning.half_height
		out.pocket_centres.append(Vector3(cos(angle) * r, y, sin(angle) * r))
	for centre: Vector3 in out.pocket_centres:
		for i in tuning.rocks_per_pocket:
			var offset := BeltLayout._in_ball(rng) * tuning.pocket_radius
			offset.y *= tuning.pocket_flatten
			out._add_rock(tuning, rng, centre + offset)
	for i in tuning.scattered:
		var angle := rng.randf() * TAU
		# Two draws added: more rocks along the middle of the band than at its edges.
		var r := tuning.ring_radius + (rng.randf() + rng.randf() - 1.0) * tuning.half_width
		var y := rng.randf_range(-1.0, 1.0) * tuning.half_height
		out._add_rock(tuning, rng, Vector3(cos(angle) * r, y, sin(angle) * r))
	out._sort_into_chunks(tuning.chunks)
	return out


func count() -> int:
	return positions.size()


## The rock's transform for drawing: turned, squashed and sized.
func rock_transform(i: int) -> Transform3D:
	return Transform3D(shapes[i] * radii[i], positions[i])


## The radius (m) of the sphere that stands in for the rock in collisions: a little inside its bumpy surface.
func solid_radius(i: int) -> float:
	var squash := shapes[i].get_scale()
	return radii[i] * minf(squash.x, minf(squash.y, squash.z)) * 0.95


## A short fingerprint of every rock's place and size, so two runs can show they built the same belt.
func checksum() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(positions.to_byte_array())
	hashing.update(radii.to_byte_array())
	return hashing.finish().hex_encode().substr(0, 16)


func _add_rock(tuning: BeltTuning, rng: RandomNumberGenerator, at: Vector3) -> void:
	# Kept inside the band, so the band's edge is where the rocks stop.
	var flat := Vector2(at.x, at.z)
	var r := clampf(flat.length(), tuning.ring_radius - tuning.half_width, tuning.ring_radius + tuning.half_width)
	flat = flat.normalized() * r
	positions.append(Vector3(flat.x, clampf(at.y, -tuning.half_height, tuning.half_height), flat.y))
	var size := pow(rng.randf(), 2.2)
	radii.append(tuning.rock_min_radius * pow(tuning.rock_max_radius / tuning.rock_min_radius, size))
	var squash := Vector3(rng.randf_range(0.8, 1.25), rng.randf_range(0.7, 1.0), rng.randf_range(0.85, 1.2))
	shapes.append(Basis(BeltLayout._turn(rng)) * Basis.from_scale(squash))


func _sort_into_chunks(chunks: int) -> void:
	chunk_rocks.clear()
	for c in chunks:
		chunk_rocks.append(PackedInt32Array())
	chunk_of.resize(positions.size())
	for i in positions.size():
		var c := BeltLayout.chunk_at(positions[i], chunks)
		chunk_of[i] = c
		chunk_rocks[c].append(i)


## Which of `chunks` pieces of the ring a point (belt space) is in, by its angle round the ring.
static func chunk_at(point: Vector3, chunks: int) -> int:
	var turn := fposmod(atan2(point.z, point.x), TAU) / TAU
	return mini(int(turn * chunks), chunks - 1)


## A random point inside a ball of radius 1, evenly spread.
static func _in_ball(rng: RandomNumberGenerator) -> Vector3:
	var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn())
	if dir.length_squared() < 0.000001:
		dir = Vector3.UP
	return dir.normalized() * pow(rng.randf(), 1.0 / 3.0)


## A random rotation, every way equally likely (Shoemake's method).
static func _turn(rng: RandomNumberGenerator) -> Quaternion:
	var u1 := rng.randf()
	var u2 := rng.randf() * TAU
	var u3 := rng.randf() * TAU
	var a := sqrt(1.0 - u1)
	var b := sqrt(u1)
	return Quaternion(a * sin(u2), a * cos(u2), b * sin(u3), b * cos(u3))
