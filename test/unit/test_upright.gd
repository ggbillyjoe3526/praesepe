extends GutTest
## Rolling upright with R (design doc, "How it flies"): the greybox ship rolls round its nose until its top points away
## from the nearest planet or moon, with flight assist on or off, leaving the nose where it was; Q or E takes over;
## with the nose straight at the body there is nothing to roll to.

var _ship: Ship
var _planet: CelestialBody
var _moon: CelestialBody
var _events: Array[Upright.Event] = []


func before_each() -> void:
	_planet = _body("Planet", Vector3.ZERO, 6000.0)
	_moon = _body("Moon", Vector3(0, 0, -40000), 1500.0)
	_ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(_ship)
	# 1 km above the planet's surface, over its top, nose along -z (along the horizon): upright as it starts.
	_ship.global_position = Vector3(0, 7000, 0)
	_ship.upright.bodies.append(_planet)
	_ship.upright.bodies.append(_moon)
	_ship.model.set_speed = 0.0
	_events.clear()
	_ship.upright_changed.connect(func(event: Upright.Event, _body: CelestialBody) -> void: _events.append(event))
	await wait_physics_frames(2)


func _body(display_name: String, at: Vector3, radius: float) -> CelestialBody:
	var b := CelestialBody.new()
	b.display_name = display_name
	b.radius = radius
	add_child_autofree(b)
	b.global_position = at
	return b


## The angle (degrees) between the ship's top and the way out from the planet, across the nose.
func _tilt() -> float:
	var up := (_ship.global_position - _planet.global_position).normalized()
	return absf(rad_to_deg(Upright.roll_left(_ship.global_basis, up)))


func _press_and_wait(ticks: int = 600) -> void:
	_ship.input.roll_upright = true
	for i in ticks:
		await wait_physics_frames(1)
		if not _ship.upright.active():
			return


func test_rolls_upright_and_leaves_the_nose_alone() -> void:
	_ship.global_basis = Basis(Vector3.FORWARD, deg_to_rad(130.0))
	var nose := -_ship.global_basis.z
	assert_gt(_tilt(), 120.0, "starts well over")
	await _press_and_wait()
	assert_eq(_events.front(), Upright.Event.ROLLING)
	assert_eq(_events.back(), Upright.Event.LEVEL, "says when it is level")
	assert_lt(_tilt(), _ship.tuning.upright_tolerance, "level with the planet")
	assert_lt((-_ship.global_basis.z).angle_to(nose), deg_to_rad(0.5), "the nose didn't move")
	await wait_physics_frames(60)
	assert_lt(_tilt(), _ship.tuning.upright_tolerance, "and stays level")


func test_rolls_the_short_way_round() -> void:
	_ship.global_basis = Basis(Vector3.FORWARD, deg_to_rad(-40.0))
	_ship.input.roll_upright = true
	await wait_physics_frames(10)
	var spin := _ship.pilot_spin().z
	await _press_and_wait()
	assert_lt(_tilt(), _ship.tuning.upright_tolerance)
	# Tilted 40 degrees one way, it rolls back 40 degrees the other, never round through 320.
	assert_gt(absf(spin), 0.1, "rolling")
	_ship.global_basis = Basis(Vector3.FORWARD, deg_to_rad(40.0))
	_ship.input.roll_upright = true
	await wait_physics_frames(10)
	assert_lt(_ship.pilot_spin().z * spin, 0.0, "the other way for the other side")


func test_with_flight_assist_off_it_still_ends_level_and_still() -> void:
	_ship.input.toggle_assist = true
	await wait_physics_frames(2)
	assert_false(_ship.assist_on())
	_ship.global_basis = Basis(Vector3.FORWARD, deg_to_rad(100.0))
	await _press_and_wait(900)
	assert_eq(_events.back(), Upright.Event.LEVEL)
	assert_lt(_tilt(), 1.0, "level")
	assert_lt(absf(_ship.pilot_spin().z), deg_to_rad(_ship.tuning.upright_still_spin), "not left rolling")
	var tilt := _tilt()
	await wait_physics_frames(600)
	assert_lt(absf(_tilt() - tilt), 0.25, "and doesn't creep off level over 10 s")
	assert_false(_ship.assist_on(), "flight assist stays off")


func test_rolling_with_q_or_e_takes_over() -> void:
	_ship.global_basis = Basis(Vector3.FORWARD, deg_to_rad(130.0))
	_ship.input.roll_upright = true
	await wait_physics_frames(5)
	assert_true(_ship.upright.active())
	_ship.input.turn.z = -1.0
	await wait_physics_frames(1)
	assert_false(_ship.upright.active(), "the pilot's roll ends it")


func test_uses_the_nearest_body_and_refuses_with_the_nose_straight_at_it() -> void:
	assert_eq(Upright.nearest(_ship.upright.bodies, Vector3(0, 0, -36000)), _moon)
	assert_eq(Upright.nearest(_ship.upright.bodies, Vector3(0, 7000, 0)), _planet)
	# Nose straight down at the planet.
	_ship.global_basis = Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
	_ship.input.roll_upright = true
	await wait_physics_frames(2)
	assert_eq(_events.back(), Upright.Event.STRAIGHT)
	assert_false(_ship.upright.active())
	assert_ne(FlightHud.upright_message(Upright.Event.STRAIGHT, "Planet"), "")


func test_every_event_has_words() -> void:
	for event: Upright.Event in Upright.Event.values():
		var words := FlightHud.upright_message(event, "Calder")
		if event == Upright.Event.NONE:
			assert_eq(words, "")
		else:
			assert_ne(words, "", Upright.Event.keys()[event])
			assert_lt(words.length(), 60, words)


func test_stops_and_says_so_when_the_nose_swings_straight_down() -> void:
	_ship.global_basis = Basis(Vector3.FORWARD, deg_to_rad(130.0))
	_ship.input.roll_upright = true
	await wait_physics_frames(3)
	assert_true(_ship.upright.active())
	_ship.global_basis = Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
	await wait_physics_frames(2)
	assert_false(_ship.upright.active())
	assert_eq(_events.back(), Upright.Event.STRAIGHT)
