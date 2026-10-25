extends GutTest
## The greybox ship in orbit round a plain planet (design doc, "Orbit"): the orbit has the velocity, the ship's
## attitude turns with it so its view of the planet holds still, and every key that flies the ship leaves orbit
## without a lurch: O and W level the nose out and fly on without sinking, X stops, Z drifts. A save keeps the orbit.

var _ship: Ship
var _planet: CelestialBody


func before_each() -> void:
	_planet = CelestialBody.new()
	_planet.display_name = "Test planet"
	_planet.radius = 6000.0
	_planet.orbit_altitude = 1500.0
	_planet.orbit_speed = 90.0
	add_child_autofree(_planet)
	_ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(_ship)
	_ship.global_position = Vector3(0, 0, 7500.0)
	_ship.orbit.bodies.append(_planet)
	_ship.linear_velocity = Vector3(-80, 0, 0)
	_ship.model.set_speed = 0.0
	await wait_physics_frames(2)


func _enter() -> void:
	_ship.input.toggle_orbit = true
	for i in 1800:
		await wait_physics_frames(1)
		if _ship.orbit.settled() and not _ship.orbit.turning:
			return


## Waits while the ship levels out to leave orbit (a few seconds at most).
func _level_out() -> void:
	for i in 300:
		if _ship.orbit.phase != Orbit.Phase.LEAVING:
			return
		await wait_physics_frames(1)


func _down_angle() -> float:
	return (-_ship.global_basis.z).angle_to(_planet.global_position - _ship.global_position)


func test_settles_and_keeps_its_view_of_the_planet() -> void:
	await _enter()
	assert_true(_ship.orbit.settled(), "settled")
	assert_false(_ship.orbit.turning, "turned to face along the orbit")
	assert_true(_ship.assist_on())
	var view := _down_angle()
	var height := _planet.surface_distance(_ship.global_position)
	await wait_physics_frames(600)
	assert_almost_eq(_down_angle(), view, deg_to_rad(0.5), "the view of the planet holds still")
	assert_almost_eq(_planet.surface_distance(_ship.global_position), height, 1.0, "the height too")
	assert_almost_eq(_ship.speed(), _planet.orbit_speed, 0.05)
	assert_almost_eq(_ship.pilot_spin(), Vector3.ZERO, Vector3.ONE * 0.001, "no spin against the orbit")


func test_o_levels_out_and_flies_on_without_sinking() -> void:
	await _enter()
	var height := _planet.surface_distance(_ship.global_position)
	_ship.input.toggle_orbit = true
	await wait_physics_frames(2)
	assert_eq(_ship.orbit.phase, Orbit.Phase.LEAVING, "levelling out first")
	await _level_out()
	assert_false(_ship.orbit.active(), "then out of orbit")
	assert_true(_ship.assist_on())
	assert_almost_eq(_ship.held_speed(), _planet.orbit_speed, 1.0, "flight assist holds the orbit's whole speed")
	assert_lt(rad_to_deg(_ship.linear_velocity.angle_to(-_ship.global_basis.z)), 1.0, "along the nose")
	for i in 10:
		await wait_physics_frames(60)
		var now := _planet.surface_distance(_ship.global_position)
		assert_gt(now, height - 1.0, "never sinking toward the planet (%.1f m, from %.1f m)" % [now, height])
		height = now


func test_w_levels_out_and_flies_on() -> void:
	await _enter()
	var height := _planet.surface_distance(_ship.global_position)
	_ship.input.thrust.z = 1.0
	await wait_physics_frames(2)
	assert_eq(_ship.orbit.phase, Orbit.Phase.LEAVING, "thrust leaves orbit, levelling out first")
	await _level_out()
	assert_false(_ship.orbit.active())
	await wait_physics_frames(60)
	_ship.input.thrust = Vector3.ZERO
	await wait_physics_frames(120)
	assert_gt(_ship.held_speed(), _planet.orbit_speed, "W speeds up from the orbit's speed")
	assert_almost_eq(_ship.speed(), _ship.held_speed(), 0.5)
	assert_gt(_planet.surface_distance(_ship.global_position), height - 1.0, "and the ship hasn't sunk")


func test_x_leaves_and_stops() -> void:
	await _enter()
	_ship.input.full_stop = true
	await wait_physics_frames(2)
	assert_false(_ship.orbit.active())
	assert_eq(_ship.held_speed(), 0.0)
	await wait_physics_frames(400)
	assert_lt(_ship.speed(), 0.5, "comes to a stop")


func test_z_leaves_and_drifts() -> void:
	await _enter()
	var before := _ship.linear_velocity
	_ship.input.toggle_assist = true
	await wait_physics_frames(2)
	assert_false(_ship.orbit.active())
	assert_false(_ship.assist_on(), "flight assist off")
	await wait_physics_frames(60)
	assert_almost_eq(_ship.linear_velocity, before, Vector3.ONE * 0.05, "drifting on the way it was going")


func test_the_cruise_drive_takes_over_from_the_orbit() -> void:
	await _enter()
	_ship.input.toggle_cruise = true
	await wait_physics_frames(roundi(_ship.cruise_tuning.charge_time * 60.0) - 10)
	assert_true(_ship.orbit.active(), "still in orbit while the drive charges")
	assert_eq(FlightHud.mode_of(_ship), FlightHud.Mode.CHARGING, "and the HUD says the drive is charging")
	await wait_physics_frames(14)
	# Nothing in the drive's way here (it knows no places), so it engages and the orbit gives way.
	assert_true(_ship.cruise.active(), "the drive engages")
	assert_false(_ship.orbit.active(), "and the ship leaves orbit")


func test_a_save_keeps_the_very_same_orbit() -> void:
	_planet.id = &"test_planet"
	assert_eq(SaveGame.orbit_state(_ship.orbit), {}, "not in orbit yet")
	await _enter()
	var saved := SaveGame.orbit_state(_ship.orbit)
	assert_eq(saved.body, "test_planet")
	assert_eq(saved.radius, _ship.orbit.radius)
	var axis := _ship.orbit.axis
	assert_eq(saved.axis, [axis.x, axis.y, axis.z])
	assert_eq(SaveGame.ship_state(_ship).orbit, saved)
