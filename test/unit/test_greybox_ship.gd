extends GutTest
## The greybox ship keeps the mass, centre of mass and inertia it had when the owner approved its flight
## (DESIGN.md decisions log, 2026-10-24), whatever collision shapes the cockpit adds. These are the values the physics
## engine worked out for the approved hull and wings, read back per axis of the ship (pitch, yaw, roll), not sorted.

const APPROVED_COM := Vector3(0.0, -0.0651163, 0.406977)
## kg m² about the ship's own x (pitch), y (yaw) and z (roll) axes.
const APPROVED_INERTIA := Vector3(230824.3, 297811.5, 84020.6)


func test_flies_with_the_approved_mass_and_balance() -> void:
	var ship: RigidBody3D = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(ship)
	await wait_physics_frames(2)
	var state := PhysicsServer3D.body_get_direct_state(ship.get_rid())
	var tensor := state.inverse_inertia_tensor.inverse()
	var per_axis := Vector3(tensor.x.x, tensor.y.y, tensor.z.z)
	assert_eq(ship.mass, 20000.0)
	assert_almost_eq(state.center_of_mass_local, APPROVED_COM, Vector3.ONE * 0.001)
	for axis in 3:
		assert_almost_eq(per_axis[axis] / APPROVED_INERTIA[axis], 1.0, 0.005, "axis %d: %.0f" % [axis, per_axis[axis]])
