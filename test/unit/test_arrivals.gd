extends GutTest
## Docking and landing (design doc, "Docking and landing"): when a port is offered and why not, the one arrival
## function holding the ship at its berth and telling everyone (Events.arrived), G handing the ship to the way in
## (Approach: its path is tested in test_approach.gd) and G, X or a bump taking it back, settling onto a bay's floor,
## and leaving: lifted off it, eased out along the port's way out, then handed back to the pilot at the port's exit
## speed. Also the speed warning and the guide lights.

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
	_pad.offer_range = 600.0
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


## Notes the hardest knock the ship felt, each tick after the ship has moved, as the cameras do.
class KnockWatch:
	extends Node
	var ship: Ship
	var hardest: float = 0.0

	func _ready() -> void:
		process_physics_priority = FlightOrder.CAMERAS

	func _physics_process(_delta: float) -> void:
		hardest = maxf(hardest, ship.jolt)


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


func test_both_count_from_their_markers() -> void:
	assert_eq(_dock.place.display_name, "Test Station")
	assert_null(_dock.body, "a station is in open space")
	assert_eq(_pad.place.display_name, "Test Base")
	assert_eq(_pad.body, _planet, "the base stands on the planet")
	assert_almost_eq(_dock.distance(_dock.global_position + Vector3(0, 900, 0)), 900.0, 0.01)
	# The pad counts from itself too, as the station's bay does: not from anywhere round its planet.
	assert_almost_eq(_pad.distance(_pad.global_position + Vector3(0, 900, 0)), 900.0, 0.01)
	var far_side := _planet.global_position + Vector3(0, -7000, 0)
	assert_gt(_pad.distance(far_side), _pad.hint_range, "the far side of the planet is far from the pad")
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
	await _place_ship(_pad.global_position + Vector3(300, 400, 0))
	assert_eq(_arrivals.nearest, _pad, "near the pad, landing is offered")
	assert_eq(_arrivals.refusal, Arrivals.Refusal.NONE)
	await _place_ship(_pad.global_position + Vector3(0, 2500, 0))
	assert_eq(_arrivals.nearest, _pad, "high over the base it says how much closer to come")
	assert_eq(_arrivals.refusal, Arrivals.Refusal.TOO_FAR)
	await _place_ship(_planet.global_position + Vector3(0, 0, -6000.0 - 2500.0))
	assert_null(_arrivals.nearest, "2.5 km above the planet but far from the base, it isn't")
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


func test_g_flies_the_ship_in_and_arrives_with_a_soft_touch() -> void:
	# On the dock's line, 20 m out, turned the berth's way: just the last of the final leg.
	_ship.global_basis = _dock.global_basis
	await _place_ship(_dock.global_position + _dock.exit_direction() * 20.0, -_dock.exit_direction() * 5.0)
	_ship.input.dock = true
	await wait_physics_frames(1)
	assert_eq(_arrivals.stage, Arrivals.Stage.APPROACHING)
	assert_eq(_ship.bound_for, _dock)
	assert_eq(FlightHud.mode_of(_ship), FlightHud.Mode.DOCKING, "the dashboard says it is docking")
	_ship.input.thrust.z = 1.0
	_ship.input.toggle_assist = true
	var watch := KnockWatch.new()
	watch.ship = _ship
	add_child_autofree(watch)
	for i in 600:
		await wait_physics_frames(1)
		if _arrivals.stage == Arrivals.Stage.DOCKED:
			break
		assert_true(_ship.assist_on(), "the keys do nothing on the way in")
	assert_eq(_arrivals.stage, Arrivals.Stage.DOCKED, "docks")
	assert_eq(_arrived, [_dock] as Array[Port], "arrives once, through the one arrival function")
	assert_eq(_ship.berth, _dock)
	assert_null(_ship.bound_for)
	await wait_physics_frames(2)
	# The touch the camera feels is the ship's real speed at the berth, never less than touch_speed.
	assert_almost_eq(watch.hardest, _arrivals.tuning.touch_speed, 0.5, "touches the berth softly, felt in the camera")
	assert_almost_eq(_ship.global_position, _dock.global_position, Vector3.ONE * 0.001, "held at the berth")


func test_g_on_the_way_in_hands_the_ship_back() -> void:
	var stopped: Array = []
	_arrivals.stopped.connect(func(p: Port, blocked: bool) -> void: stopped.append([p, blocked]))
	await _place_ship(_dock.global_position + Vector3(900, 0, 0), Vector3(-50, 0, 0))
	_ship.input.dock = true
	await wait_physics_frames(30)
	assert_eq(_arrivals.stage, Arrivals.Stage.APPROACHING)
	assert_true(_ship.guided)
	_ship.input.dock = true
	await wait_physics_frames(1)
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING, "G again cancels")
	assert_false(_ship.guided)
	assert_null(_ship.bound_for)
	assert_true(_ship.assist_on())
	assert_eq(stopped, [[_dock, false]])
	assert_true(_arrived.is_empty(), "never arrived")


func test_g_on_the_final_leg_stops_the_ship_short_of_the_berth() -> void:
	# On the dock's line, 40 m out, coming in.
	_ship.global_basis = _dock.global_basis
	await _place_ship(_dock.global_position + _dock.exit_direction() * 40.0, -_dock.exit_direction() * 5.0)
	_ship.input.dock = true
	await wait_physics_frames(10)
	assert_true(_arrivals.approach.final, "on the final leg")
	_ship.input.dock = true
	await wait_physics_frames(1)
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING, "G cancels")
	await wait_physics_frames(300)
	assert_lt(_ship.speed(), 0.1, "and brings the ship to rest rather than carrying on in")
	var along := (_ship.global_position - _dock.global_position).dot(_dock.exit_direction())
	assert_gt(along, 10.0, "short of the berth")
	assert_true(_arrived.is_empty(), "never arrived")


func test_x_on_the_way_in_stops_the_ship() -> void:
	await _place_ship(_dock.global_position + Vector3(900, 0, 0), Vector3(-50, 0, 0))
	_ship.input.dock = true
	await wait_physics_frames(30)
	_ship.input.full_stop = true
	await wait_physics_frames(1)
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING, "X cancels")
	await wait_physics_frames(300)
	assert_lt(_ship.speed(), 0.1, "and brings the ship to rest")


func test_a_bump_on_the_way_in_stops_it() -> void:
	var stopped: Array = []
	_arrivals.stopped.connect(func(p: Port, blocked: bool) -> void: stopped.append([p, blocked]))
	await _place_ship(_dock.global_position + Vector3(600, 0, 0))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 200, 200)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = _dock.global_position + Vector3(500, 0, 0)
	_ship.input.dock = true
	for i in 600:
		await wait_physics_frames(1)
		if _arrivals.stage != Arrivals.Stage.APPROACHING:
			break
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING, "stops at the wall")
	assert_eq(stopped, [[_dock, true]], "says it was blocked")
	assert_true(_arrived.is_empty())


func test_feels_ahead_for_what_is_in_the_way() -> void:
	await _place_ship(_dock.global_position + Vector3(50, 0, 0))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 200, 200)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = _dock.global_position + Vector3(100, 0, 0)
	await wait_physics_frames(2)
	var at := _ship.global_position
	var away := _arrivals._in_the_way(at, Vector3(80, 0, 0))
	assert_almost_eq(away, Vector3(-1, 0, 0), Vector3.ONE * 0.01, "the wall ahead, as the way back out of it")
	assert_eq(_arrivals._in_the_way(at, Vector3(0, 0, 80)), Vector3.ZERO, "nothing along the wall")
	assert_eq(_arrivals._in_the_way(at, Vector3(30, 0, 0)), Vector3.ZERO, "nothing short of the wall (less its reach)")
	assert_eq(_arrivals._in_the_way(at, Vector3.ZERO), Vector3.ZERO, "never the ship itself")
	var close := wall.global_position - Vector3(5, 0, 0)
	assert_almost_eq(_arrivals._in_the_way(close, Vector3(0, 0, 80)), Vector3(-1, 0, 0), Vector3.ONE * 0.01,
			"already within reach of the wall: the wall, whichever way it is going")


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
	await _place_ship(_planet.global_position + Vector3(0, 0, -_planet.orbit_radius()), Vector3(60, 0, 0))
	_ship.input.toggle_orbit = true
	await wait_physics_frames(2)
	assert_true(_ship.orbit.active())
	_arrivals.arrive(_pad)
	assert_false(_ship.orbit.active())
	assert_eq(_ship.orbit.spin, Vector3.ZERO)


func test_settles_onto_a_bays_floor_and_lifts_off_it_leaving() -> void:
	_dock.settle = 12.0
	var up := _dock.global_basis.y
	# On the dock's line (12 m over its floor), 20 m out, turned the berth's way.
	_ship.global_basis = _dock.global_basis
	await _place_ship(_dock.lane_origin() + _dock.exit_direction() * 20.0, -_dock.exit_direction() * 5.0)
	_ship.input.dock = true
	var settled := false
	for i in 1200:
		await wait_physics_frames(1)
		if _arrivals.stage == Arrivals.Stage.DOCKED:
			break
		if _arrivals.approach.settling:
			settled = true
			var rel := _ship.global_position - _dock.global_position
			assert_lt((rel - up * rel.dot(up)).length(), 1.0, "straight down over the berth")
	assert_true(settled, "settles down onto the floor")
	assert_eq(_arrivals.stage, Arrivals.Stage.DOCKED, "docks")
	assert_almost_eq(_ship.global_position, _dock.global_position, Vector3.ONE * 0.001, "on the floor at the berth")
	_ship.input.dock = true
	var lifted := false
	for i in 1200:
		await wait_physics_frames(1)
		if _arrivals.stage != Arrivals.Stage.LEAVING:
			break
		var rel := _ship.global_position - _dock.global_position
		var height := rel.dot(up)
		var out := rel.dot(_dock.exit_direction())
		if height < _dock.settle - 0.01:
			assert_lt(absf(out), 0.01, "lifts straight up first (%.2f m out at %.2f m up)" % [out, height])
		else:
			lifted = true
		assert_lt(_ship.speed(), maxf(_arrivals.tuning.settle_speed, _dock.exit_speed) + 0.01, "gently")
	assert_true(lifted, "lifts to the way out's height")
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING)
	var rel := _ship.global_position - _dock.global_position
	assert_almost_eq(rel.dot(up), _dock.settle, 0.05, "and leaves along the way in's line")
	assert_almost_eq(rel.dot(_dock.exit_direction()), _dock.exit_distance, 1.0, "out by the exit distance")


func test_g_carries_on_at_about_the_speed_the_ship_was_going() -> void:
	await _place_ship(_dock.global_position + Vector3(1000, 0, 0), Vector3(-20, 0, 0))
	_ship.input.dock = true
	var top := 0.0
	for i in 600:
		await wait_physics_frames(1)
		top = maxf(top, _ship.speed())
	assert_eq(_arrivals.stage, Arrivals.Stage.APPROACHING, "still on its way")
	assert_lte(top, Approach.speed_limit(20.0, INF, _arrivals.tuning) + 0.01, "never much faster than it was going")


func test_warns_when_coming_at_something_too_fast() -> void:
	var station := _dock.get_parent() as Landmark
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 200, 200)
	shape.shape = box
	wall.add_child(shape)
	station.add_child(wall)
	wall.global_position = _dock.global_position + Vector3(400, 0, 0)
	# 300 m from the wall: at 80 m/s it would need 256 m and more of hard braking, so that is too fast.
	await _place_ship(_dock.global_position + Vector3(700, 0, 0), Vector3(-80, 0, 0))
	assert_true(_arrivals.warning, "too fast for the wall ahead")
	assert_eq(_arrivals.warning_place, station, "the wall is the station's")
	assert_almost_eq(_arrivals.warning_time, (300.0 - 1.0 - _arrivals.tuning.warn_reach) / 80.0, 0.1,
			"there in under 4 s")
	await _place_ship(_dock.global_position + Vector3(700, 0, 0), Vector3(-20, 0, 0))
	assert_false(_arrivals.warning, "slow enough to stop in time")
	await _place_ship(_dock.global_position + Vector3(700, 0, 0), Vector3(80, 0, 0))
	assert_false(_arrivals.warning, "going away from it")
	await _place_ship(_dock.global_position + Vector3(700, 0, 0), Vector3(0, -80, 0))
	assert_false(_arrivals.warning, "going along it")


func test_lights_the_way_while_lined_up() -> void:
	assert_not_null(_dock.get_node_or_null(^"GuideLight"), "the bay has a guide light")
	assert_not_null(_pad.get_node_or_null(^"GuideLight"), "and so does the pad")
	await _place_ship(_dock.global_position + _dock.exit_direction() * 100.0)
	assert_true(_dock.guiding, "in the dock's lane, its light is lit")
	assert_false(_pad.guiding)
	await _place_ship(_dock.global_position + Vector3(0, 600, 0))
	assert_false(_dock.guiding, "off the line, it isn't")
	_ship.input.dock = true
	await wait_physics_frames(2)
	assert_eq(_arrivals.stage, Arrivals.Stage.APPROACHING)
	assert_true(_dock.guiding, "flying in, it is")
