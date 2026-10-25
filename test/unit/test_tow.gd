extends GutTest
## "Tow me to base" (Arrivals.tow, the pause screen's button): it takes the ship to the last port it arrived at (or the
## nearest one if it never has), from whatever it was doing, through the one arrival function, and says so
## (Events.towed, after Events.arrived); never while docked. The button asks for a second press first.

var _ship: Ship
var _arrivals: Arrivals
var _dock: Port
var _pad: Port
var _heard: Array[String] = []


func before_each() -> void:
	_heard.clear()
	var station := Landmark.new()
	station.display_name = "Test Station"
	add_child_autofree(station)
	station.global_position = Vector3(0, 0, -20000)
	_dock = _port(station, Port.Kind.DOCK, &"test_station")
	var planet := CelestialBody.new()
	planet.display_name = "Test Planet"
	planet.radius = 6000.0
	add_child_autofree(planet)
	planet.global_position = Vector3(0, 0, 20000)
	var base := Landmark.new()
	base.display_name = "Test Base"
	base.position = Vector3(0, 6000, 0)
	planet.add_child(base)
	_pad = _port(base, Port.Kind.PAD, &"test_base")
	_ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(_ship)
	_arrivals = Arrivals.new()
	_arrivals.ship = _ship
	_arrivals.tuning = load("res://game/arrival/arrival_tuning.tres")
	_arrivals.ports = [_dock, _pad] as Array[Port]
	add_child_autofree(_arrivals)
	Events.arrived.connect(_on_arrived)
	Events.towed.connect(_on_towed)
	await wait_physics_frames(1)


func after_each() -> void:
	Events.arrived.disconnect(_on_arrived)
	Events.towed.disconnect(_on_towed)


func _port(parent: Node3D, kind: Port.Kind, id: StringName) -> Port:
	var p := Port.new()
	p.kind = kind
	p.id = id
	parent.add_child(p)
	return p


func _on_arrived(port: Port) -> void:
	_heard.append("arrived:" + String(port.id))


func _on_towed(port: Port) -> void:
	_heard.append("towed:" + String(port.id))


func test_never_arrived_goes_to_the_nearest_port() -> void:
	_ship.global_position = Vector3(0, 0, 5000)
	assert_null(_arrivals.home)
	assert_eq(_arrivals.tow_to(), _pad, "the planet's surface is nearer than the station")
	assert_true(_arrivals.can_tow())
	assert_eq(_arrivals.tow(), _pad)
	assert_eq(_heard, ["arrived:test_base", "towed:test_base"] as Array[String], "arrives first, then is towed")


func test_goes_home_from_cruise_and_says_where() -> void:
	_arrivals.arrive(_dock)
	assert_eq(_arrivals.home, _dock, "arriving makes a port home")
	assert_false(_arrivals.can_tow(), "no tow while docked")
	assert_null(_arrivals.tow())
	_arrivals.depart()
	for i in 600:
		await wait_physics_frames(1)
		if _arrivals.stage == Arrivals.Stage.FLYING:
			break
	# Out by the planet, cruising.
	_ship.global_position = _pad.global_position + Vector3(0, 9000, 0)
	_ship.input.toggle_cruise = true
	await wait_physics_frames(2)
	assert_ne(_ship.cruise.phase, CruiseDrive.Phase.OFF)
	assert_true(_arrivals.can_tow())
	_heard.clear()
	assert_eq(_arrivals.tow(), _dock, "home, not the nearest port")
	assert_eq(_heard, ["arrived:test_station", "towed:test_station"] as Array[String])
	assert_eq(_arrivals.stage, Arrivals.Stage.DOCKED)
	assert_eq(_ship.berth, _dock)
	assert_eq(_ship.cruise.phase, CruiseDrive.Phase.OFF, "the cruise drive stops")
	await wait_physics_frames(10)
	assert_almost_eq(_ship.global_position, _dock.global_position, Vector3.ONE * 0.001, "held at the berth")
	assert_eq(_ship.speed(), 0.0)
	assert_lt(_ship.jolt, 0.01, "no bump on arriving")


func test_drops_the_way_in() -> void:
	_arrivals.arrive(_dock)
	_arrivals.depart()
	for i in 600:
		await wait_physics_frames(1)
		if _arrivals.stage == Arrivals.Stage.FLYING:
			break
	# Close to the base and slow: G starts flying in to the pad; the tow goes home to the station instead.
	_ship.global_position = _pad.global_position + Vector3(0, 1000, 0)
	_ship.linear_velocity = Vector3.ZERO
	await wait_physics_frames(2)
	_ship.input.dock = true
	await wait_physics_frames(2)
	assert_eq(_arrivals.stage, Arrivals.Stage.APPROACHING)
	assert_eq(_arrivals.tow(), _dock)
	assert_null(_arrivals.approach)
	assert_null(_ship.bound_for)
	assert_false(_ship.guided)
	assert_eq(_ship.berth, _dock)


func test_the_button_asks_twice() -> void:
	_ship.global_position = Vector3(0, 0, -15000)
	var screen := PauseScreen.new()
	screen.arrivals = _arrivals
	add_child_autofree(screen)
	assert_true(screen.tow_button.visible)
	assert_false(screen.tow_button.disabled)
	assert_eq(screen.tow_button.text, "Tow me to Test Station  ·  free")
	screen.tow_button.pressed.emit()
	assert_eq(screen.tow_button.text, "Press again to be towed to Test Station")
	assert_eq(_heard, [] as Array[String], "the first press only asks")
	screen.tow_button.pressed.emit()
	assert_eq(_heard, ["arrived:test_station", "towed:test_station"] as Array[String])


func test_the_button_is_off_while_docked_and_hidden_without_arrivals() -> void:
	_arrivals.arrive(_pad)
	var screen := PauseScreen.new()
	screen.arrivals = _arrivals
	add_child_autofree(screen)
	assert_true(screen.tow_button.disabled)
	assert_eq(screen.tow_button.text, "Tow me to base  ·  you're at Test Base")
	screen.tow_button.pressed.emit()
	screen.tow_button.pressed.emit()
	assert_eq(_heard, ["arrived:test_base"] as Array[String], "pressing it does nothing")
	var bare := PauseScreen.new()
	add_child_autofree(bare)
	assert_false(bare.tow_button.visible)
