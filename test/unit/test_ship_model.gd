extends GutTest
## The test ship's model (game/ship/models/, built by tools/blender/hauler_model.py) only changes how the ship looks:
## it sits inside the collision shapes, never below the underside the bay floor berth uses, and every surface is
## single sided, so the windows are clear from the cockpit and nothing inside shows through the hull.

## How far the model may reach past the collision shapes (m): the nose and the engine glow by a few centimetres.
const OUTSIDE_SHAPES := 0.1
## The ship's underside (m): the bottom of the hull's collision box, where it rests on a berth.
const UNDERSIDE := -1.2

var _ship: RigidBody3D


func before_each() -> void:
	_ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(_ship)


func test_the_model_fits_the_collision_shapes() -> void:
	var shapes := _bounds_of_shapes()
	var model := _bounds_of_meshes(_ship.get_node(^"Model"))
	model = model.merge(_bounds_of_meshes(_ship.get_node(^"Cockpit/Model")))
	assert_true(shapes.grow(OUTSIDE_SHAPES).encloses(model), "model %s inside shapes %s" % [model, shapes])
	assert_almost_eq(shapes.position.y, UNDERSIDE, 0.001, "the hull's box still ends at the underside")
	assert_gte(model.position.y, UNDERSIDE - 0.001, "nothing hangs below the underside")


func test_every_surface_is_single_sided() -> void:
	var meshes := _ship.find_children("*", "MeshInstance3D", true, false)
	var checked := 0
	for node: Node in meshes:
		var mesh := (node as MeshInstance3D).mesh
		if not (node.owner == _ship.get_node(^"Model") or node.owner == _ship.get_node(^"Cockpit/Model")):
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			assert_eq(material.cull_mode, BaseMaterial3D.CULL_BACK, "%s is single sided" % node.name)
			checked += 1
	assert_gt(checked, 10, "the model's surfaces were found")


func test_the_glass_is_clear_and_casts_no_shadow() -> void:
	var glass := _ship.get_node(^"Model/Exterior_Glass") as MeshInstance3D
	assert_eq(glass.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var material := glass.mesh.surface_get_material(0) as BaseMaterial3D
	assert_ne(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "see-through")


## The collision shapes' bounds in the ship's frame (all are boxes).
func _bounds_of_shapes() -> AABB:
	var bounds := AABB()
	var first := true
	for node: Node in _ship.get_children():
		var shape := node as CollisionShape3D
		if shape == null:
			continue
		var size := (shape.shape as BoxShape3D).size
		var box := shape.transform * AABB(-size * 0.5, size)
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## The meshes' bounds under `root`, in the ship's frame.
func _bounds_of_meshes(root: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := (_ship.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
