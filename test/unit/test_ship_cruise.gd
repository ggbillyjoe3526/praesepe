extends GutTest
## The greybox ship flying under its cruise drive (design doc, "How the cruise drive works"): the drive has the speed,
## so the thrust keys and Z do nothing while it runs; flight assist is on throughout; the engines rumble at the tuned
## share; and dropping out leaves flight assist holding the exit speed. Open space: no places to arrive at.

var _ship: Ship


func before_each() -> void:
	_ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(_ship)
	await wait_physics_frames(2)


func _engage() -> void:
	_ship.input.toggle_cruise = true
	await wait_physics_frames(roundi(_ship.cruise_tuning.charge_time * 60.0) + 2)


func test_engaging_turns_flight_assist_on_and_rumbles() -> void:
	_ship.input.toggle_assist = true
	await wait_physics_frames(2)
	assert_false(_ship.assist_on(), "assist off before cruising")
	await _engage()
	assert_true(_ship.cruise.active(), "cruising")
	assert_true(_ship.assist_on(), "the drive turns flight assist on")
	assert_eq(_ship.thrust_level(), _ship.cruise_tuning.rumble)


func test_thrust_and_z_do_nothing_while_cruising() -> void:
	await _engage()
	for i in 60:
		_ship.input.thrust = Vector3(1, 1, -1)
		_ship.input.toggle_assist = true
		await wait_physics_frames(1)
		assert_true(_ship.assist_on(), "Z ignored (tick %d)" % i)
	assert_true(_ship.cruise.active())
	assert_almost_eq(_ship.linear_velocity, _ship.cruise.velocity, Vector3.ONE * 0.01, "only the drive moves the ship")
	var sideways := _ship.pilot_velocity()
	assert_almost_eq(Vector2(sideways.x, sideways.y), Vector2.ZERO, Vector2.ONE * 0.01, "no strafe from the keys")


func test_dropping_out_leaves_assist_holding_the_exit_speed() -> void:
	await _engage()
	await wait_physics_frames(60)
	assert_gt(_ship.cruise.speed, _ship.cruise_tuning.exit_speed, "faster than the exit speed by now")
	_ship.input.toggle_cruise = true
	await wait_physics_frames(2)
	assert_false(_ship.cruise.active())
	assert_true(_ship.assist_on())
	assert_almost_eq(_ship.held_speed(), _ship.cruise_tuning.exit_speed, 0.01)
	assert_almost_eq(_ship.pilot_velocity().z, _ship.cruise_tuning.exit_speed, 1.0)
