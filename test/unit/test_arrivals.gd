extends GutTest
## Docking and landing (design doc, "Docking and landing"): when a port is offered and why not, the one arrival
## function holding the ship at its berth and telling everyone (Events.arrived), the transition screen covering it,
## and leaving: eased out along the port's way out, then handed back to the pilot at the port's exit speed.

const DT := 1.0 / 60.0

var _ship: Ship
var _arrivals: Arrivals
var _dock: Port
var _pad: Port
var _planet: CelestialBody
var _arrived: Array[Port] = []
var _departed: Array[Port] = []


func before_each() -> void:
	_arrived.clear()
	_departed.clear()
	# A station far out with a dock facing +x, and a planet with a base and its pad.
	var station := Landmark.new()
	station.display_name = "Test Station"
	add_child_autofree(station)
	station.global_position = Vector3(0, 0, -20000)
	_dock = _port(station, Port.Kind.DOCK, &"test_station", Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3.ZERO))
	_planet = CelestialBody.new()
	_planet.display_name = "Test Planet"
	_planet.radius = 6000.0
	add_child_autofree(_planet)
	_planet.global_position = Vector3(0, 0, 20000)
	var base := Landmark.new()
	base.display_name = "Test Base"
	base.position = Vector3(0, 6000, 0)
	_planet.add_child(base)
	_pad = _port(base, Port.Kind.PAD, &"test_base", Transform3D(Basis.IDENTITY, Vector3(0, 5, 0)))
	_pad.offer_range = 4000.0
	_pad.hint_range = 8000.0
	_ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(_ship)
	_arrivals = Arrivals.new()
	_arrivals.ship = _ship
	_arrivals.tuning = load("res://game/arrival/arrival_tuning.tres")
	_arrivals.ports = [_dock, _pad] as Array[Port]
	add_child_autofree(_arrivals)
	Events.arrived.connect(_on_arrived)
	Events.departed.connect(_on_departed)
	await wait_physics_frames(1)


func after_each() -> void:
	Events.arrived.disconnect(_on_arrived)
	Events.departed.disconnect(_on_departed)


func _port(parent: Node3D, kind: Port.Kind, id: StringName, at: Transform3D) -> Port:
	var p := Port.new()
	p.kind = kind
	p.id = id
	p.transform = at
	parent.add_child(p)
	return p


func _on_arrived(port: Port) -> void:
	_arrived.append(port)


func _on_departed(port: Port) -> void:
	_departed.append(port)


func _place_ship(at: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	_ship.global_position = at
	_ship.linear_velocity = velocity
	_ship.model.set_speed = velocity.length()
	await wait_physics_frames(2)


func test_a_dock_counts_from_its_marker_and_a_pad_from_its_planets_surface() -> void:
	assert_eq(_dock.place.display_name, "Test Station")
	assert_null(_dock.body, "a station is in open space")
	assert_eq(_pad.place.display_name, "Test Base")
	assert_eq(_pad.body, _planet, "the base stands on the planet")
	assert_almost_eq(_dock.distance(_dock.global_position + Vector3(0, 900, 0)), 900.0, 0.01)
	# Anywhere round the planet, the pad counts the height above the surface.
	var far_side := _planet.global_position + Vector3(0, -7000, 0)
	assert_almost_eq(_pad.distance(far_side), 1000.0, 0.01)
	assert_almost_eq(_dock.exit_direction(), Vector3(1, 0, 0), Vector3.ONE * 0.0001, "out of the bay: its nose")
	assert_almost_eq(_pad.exit_direction(), Vector3.UP, Vector3.ONE * 0.0001, "off the pad: straight up")


func test_judges_far_then_cruising_then_fast() -> void:
	assert_eq(Arrivals.judge(_dock, 2000.0, 50.0, false), Arrivals.Refusal.TOO_FAR)
	assert_eq(Arrivals.judge(_dock, 1000.0, 50.0, true), Arrivals.Refusal.CRUISING)
	assert_eq(Arrivals.judge(_dock, 1000.0, 150.0, false), Arrivals.Refusal.TOO_FAST)
	assert_eq(Arrivals.judge(_dock, 1000.0, 100.0, false), Arrivals.Refusal.NONE, "at the limit is fine")


func test_offers_the_nearest_port_in_range() -> void:
	await _place_ship(_dock.global_position + Vector3(1200, 0, 0), Vector3(-60, 0, 0))
	assert_eq(_arrivals.nearest, _dock)
	assert_eq(_arrivals.refusal, Arrivals.Refusal.NONE)
	await _place_ship(_dock.global_position + Vector3(3000, 0, 0))
	assert_eq(_arrivals.nearest, _dock, "within its hint range")
	assert_eq(_arrivals.refusal, Arrivals.Refusal.TOO_FAR)
	await _place_ship(_planet.global_position + Vector3(0, 0, -6000.0 - 2500.0))
	assert_eq(_arrivals.nearest, _pad, "2.5 km above the planet, far from the base, the pad is offered")
	assert_eq(_arrivals.refusal, Arrivals.Refusal.NONE)
	await _place_ship(Vector3(0, 0, 0))
	assert_null(_arrivals.nearest, "out between them: nothing")


func test_g_with_nothing_offered_says_why() -> void:
	var refused: Array = []
	_arrivals.refused.connect(func(p: Port, why: Arrivals.Refusal) -> void: refused.append([p, why]))
	await _place_ship(_dock.global_position + Vector3(1000, 0, 0), Vector3(150, 0, 0))
	_ship.input.dock = true
	await wait_physics_frames(1)
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING, "too fast: nothing happens")
	assert_eq(refused, [[_dock, Arrivals.Refusal.TOO_FAST]])


func test_g_fades_out_arrives_and_fades_back_in() -> void:
	var screen := TransitionScreen.new()
	add_child_autofree(screen)
	_arrivals.transition = screen
	await _place_ship(_dock.global_position + Vector3(800, 0, 0), Vector3(-50, 0, 0))
	_ship.input.dock = true
	await wait_physics_frames(1)
	assert_eq(_arrivals.stage, Arrivals.Stage.ARRIVING)
	assert_eq(screen.shown()[0], "Docking at Test Station")
	await wait_physics_frames(roundi(_arrivals.tuning.fade_out / DT) + 1)
	assert_eq(_arrived, [_dock] as Array[Port], "arrived once the view is black")
	assert_eq(screen.cover, 1.0)
	assert_eq(screen.shown()[0], "Docked at Test Station")
	await wait_physics_frames(roundi((_arrivals.tuning.hold + _arrivals.tuning.fade_in) / DT) + 1)
	assert_eq(_arrivals.stage, Arrivals.Stage.DOCKED)
	assert_eq(screen.cover, 0.0)
	assert_false(screen.visible, "the view is back")


func test_arriving_holds_the_ship_still_at_the_berth() -> void:
	await _place_ship(Vector3(500, 0, 0), Vector3(30, 0, 0))
	_ship.input.toggle_cruise = true
	await wait_physics_frames(1)
	_arrivals.arrive(_pad)
	assert_eq(_arrived, [_pad] as Array[Port])
	assert_eq(_ship.berth, _pad)
	assert_eq(_ship.cruise.phase, CruiseDrive.Phase.OFF, "the cruise drive stops")
	await wait_physics_frames(30)
	assert_almost_eq(_ship.global_position, _pad.global_position, Vector3.ONE * 0.001, "held at the berth")
	assert_eq(_ship.speed(), 0.0)
	_ship.input.thrust.z = 1.0
	_ship.input.toggle_assist = true
	await wait_physics_frames(10)
	assert_almost_eq(_ship.global_position, _pad.global_position, Vector3.ONE * 0.001, "the keys do nothing")
	assert_true(_ship.assist_on())


func test_leaving_eases_out_and_hands_the_ship_back() -> void:
	_arrivals.arrive(_dock)
	await wait_physics_frames(1)
	_ship.input.dock = true
	await wait_physics_frames(1)
	assert_eq(_arrivals.stage, Arrivals.Stage.LEAVING)
	assert_eq(_departed, [_dock] as Array[Port])
	var last := 0.0
	for i in 600:
		await wait_physics_frames(1)
		if _arrivals.stage != Arrivals.Stage.LEAVING:
			break
		var speed := _ship.speed()
		assert_true(speed >= last - 0.001 and speed <= _dock.exit_speed + 0.001, "speeds up evenly (%.2f)" % speed)
		last = speed
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING)
	assert_null(_ship.berth)
	assert_false(_ship.guided)
	var out := (_ship.global_position - _dock.global_position).dot(_dock.exit_direction())
	assert_almost_eq(out, _dock.exit_distance, 1.0, "out by the exit distance")
	await wait_physics_frames(30)
	assert_almost_eq(_ship.held_speed(), _dock.exit_speed, 0.01, "flight assist holds the exit speed")
	assert_almost_eq(_ship.speed(), _dock.exit_speed, 0.1)


func test_taking_off_rises_and_settles_to_a_hover() -> void:
	_arrivals.arrive(_pad)
	await wait_physics_frames(1)
	_ship.input.dock = true
	for i in 600:
		await wait_physics_frames(1)
		if _arrivals.stage == Arrivals.Stage.FLYING:
			break
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING)
	assert_eq(_ship.held_speed(), 0.0, "straight up is no forward speed")
	await wait_physics_frames(120)
	assert_lt(_ship.speed(), 0.1, "flight assist brings the climb to a hover")


func test_the_one_arrival_function_ends_any_orbit() -> void:
	_ship.orbit.bodies.append(_planet)
	await _place_ship(_planet.global_position + Vector3(0, 0, -7500), Vector3(60, 0, 0))
	_ship.input.toggle_orbit = true
	await wait_physics_frames(2)
	assert_true(_ship.orbit.active())
	_arrivals.arrive(_pad)
	assert_false(_ship.orbit.active())
	assert_eq(_ship.orbit.spin, Vector3.ZERO)
