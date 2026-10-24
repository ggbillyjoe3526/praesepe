class_name RockMesh
## The asteroid shapes, made in code (no model files): a lumpy rock of radius about 1, flat-shaded so its faces catch
## the light, for drawing close up, and a few-faced stand-in for far away. The lumps come from a fixed hash of each
## corner's direction, so every rock mesh is the same on every launch and needs no random numbers. Each rock in a belt
## is this mesh turned, squashed and sized (BeltLayout). Placeholder look until the art style is chosen.

## How far (share of the radius) the lumps push corners in or out.
const LUMPS := 0.22

const _ICOSAHEDRON_FACES: Array[Vector3i] = [
	Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
	Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
	Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
	Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
]
const _OCTAHEDRON_FACES: Array[Vector3i] = [
	Vector3i(0, 2, 4), Vector3i(2, 1, 4), Vector3i(1, 3, 4), Vector3i(3, 0, 4),
	Vector3i(2, 0, 5), Vector3i(1, 2, 5), Vector3i(3, 1, 5), Vector3i(0, 3, 5),
]


## The close-up rock: an icosahedron split once (80 faces), its corners pushed in and out.
static func near_rock(material: Material) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var corners := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	])
	var faces: Array[Vector3i] = []
	var middles := {}
	for f: Vector3i in _ICOSAHEDRON_FACES:
		var a := RockMesh._middle(corners, middles, f.x, f.y)
		var b := RockMesh._middle(corners, middles, f.y, f.z)
		var c := RockMesh._middle(corners, middles, f.z, f.x)
		faces.append_array([Vector3i(f.x, a, c), Vector3i(f.y, b, a), Vector3i(f.z, c, b), Vector3i(a, b, c)])
	for i in corners.size():
		var dir := corners[i].normalized()
		corners[i] = dir * (1.0 + LUMPS * (RockMesh._bump(dir) * 2.0 - 1.0))
	return RockMesh._flat(corners, faces, material)


## The far-away stand-in: an octahedron (8 faces), a little lumpy.
static func far_rock(material: Material) -> ArrayMesh:
	var corners := PackedVector3Array([
		Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(0, -1, 0),
	])
	for i in corners.size():
		corners[i] *= 1.0 + LUMPS * 0.5 * (RockMesh._bump(corners[i]) * 2.0 - 1.0)
	return RockMesh._flat(corners, _OCTAHEDRON_FACES, material)


## The corner halfway along edge a-b, made once and shared by both faces on that edge.
static func _middle(corners: PackedVector3Array, middles: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if middles.has(key):
		return middles[key]
	corners.append(((corners[a] + corners[b]) * 0.5).normalized() * corners[a].length())
	middles[key] = corners.size() - 1
	return corners.size() - 1


## A fixed number from 0 to 1 for a direction.
static func _bump(dir: Vector3) -> float:
	var p := dir * 7.31 + Vector3(3.1, 1.7, 5.3)
	return fposmod(sin(p.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)


## Each face with its own normal (flat shading), wound so it faces outwards.
static func _flat(corners: PackedVector3Array, faces: Array[Vector3i], material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Vector3i in faces:
		var a := corners[f.x]
		var b := corners[f.y]
		var c := corners[f.z]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0.0:
			normal = -normal
			var swap := b
			b = c
			c = swap
		st.set_normal(normal)
		# Godot draws triangles whose corners run clockwise, seen from the front.
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh
