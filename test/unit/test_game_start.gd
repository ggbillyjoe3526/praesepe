extends GutTest
## Starting a game (design doc, "Starting a game"): a new game starts in the chosen ship on a fresh world, docked at
## Halfway Station through the arrival function (so it autosaves); continuing puts back the saved world and the ship
## exactly where it was saved: at its berth without announcing an arrival, or out in space at the same true place,
## heading, velocity, spin and flight assist, never moved to a station, and back into orbit if it was orbiting. A save
## with nothing usable docks it at Halfway Station quietly.

const DT := 1.0 / 60.0

var _world: Node3D
var _origin: FloatingOrigin
var _ship: Ship
var _arrivals: Arrivals
var _station: Port
var _pad: Port
var _arrived: Array[Port] = []
var _resumed: Array[Port] = []
var _seed_before: int = 0


func before_each() -> void:
	_seed_before = Game.world_seed
	_arrived.clear()
	_resumed.clear()
	_world = Node3D.new()
	add_child_autofree(_world)
	# A station out in space (Halfway Station's port id) and a base's pad on a planet, all in true coordinates.
	var station := Landmark.new()
	station.display_name = "Test Station"
	_world.add_child(station)
	station.global_position = Vector3(16000, 1000, 0)
	_station = _port(station, Port.Kind.DOCK, GameStart.START_PORT, Transform3D(Basis(Vector3.UP, -PI / 2.0),
			Vector3.ZERO))
	var planet := CelestialBody.new()
	planet.display_name = "Test Planet"
	planet.radius = 6000.0
	_world.add_child(planet)
	planet.global_position = Vector3(0, 0, 40000)
	var base := Landmark.new()
	base.display_name = "Test Base"
	base.position = Vector3(6000, 0, 0)
	planet.add_child(base)
	_pad = _port(base, Port.Kind.PAD, &"test_base", Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3(5, 0, 0)))
	_ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	_world.add_child(_ship)
	_origin = FloatingOrigin.new()
	_origin.world = _world
	_origin.focus = _ship
	add_child_autofree(_origin)
	_arrivals = Arrivals.new()
	_arrivals.ship = _ship
	_arrivals.tuning = load("res://game/arrival/arrival_tuning.tres")
	_arrivals.ports = [_station, _pad] as Array[Port]
	add_child_autofree(_arrivals)
	Events.arrived.connect(_on_arrived)
	Events.resumed_at.connect(_on_resumed)


func after_each() -> void:
	Events.arrived.disconnect(_on_arrived)
	Events.resumed_at.disconnect(_on_resumed)
	GameStart.pending = false
	GameStart.mode = GameStart.Mode.NEW
	GameStart.ship_id = GameStart.DEFAULT_SHIP
	GameStart.saved = {}
	Game.start_world(_seed_before)


func _port(parent: Node3D, kind: Port.Kind, id: StringName, at: Transform3D) -> Port:
	var p := Port.new()
	p.kind = kind
	p.id = id
	p.transform = at
	parent.add_child(p)
	return p


func _on_arrived(port: Port) -> void:
	_arrived.append(port)


func _on_resumed(port: Port) -> void:
	_resumed.append(port)


## The ship's true position (the floating origin's offset plus where it is).
func _true_position() -> Vector3:
	var t := _origin.true_position(_ship.global_position)
	return Vector3(t[0], t[1], t[2])


## A saved game out in space: `at` (true position), facing `turn`, moving and spinning, flight assist as given.
func _space_save(at: Vector3, turn: Quaternion, velocity: Vector3, spin: Vector3, assist: bool, held: float,
		orbit: Dictionary = {}) -> Dictionary:
	return {
		"v": 2,
		"world": {"world_seed": 777, "clock": 1234.5, "streams": {}},
		"berth": "",
		"ship": {
			"model": "hauler",
			"at": [at.x, at.y, at.z],
			"turn": [turn.x, turn.y, turn.z, turn.w],
			"velocity": [velocity.x, velocity.y, velocity.z],
			"spin": [spin.x, spin.y, spin.z],
			"assist": assist,
			"held": held,
			"orbit": orbit,
		},
	}


func test_a_new_game_starts_on_its_seed_docked_at_halfway_station_and_saves() -> void:
	GameStart.new_game(&"hauler", 4242)
	assert_eq(Game.world_seed, 4242)
	assert_eq(Game.clock, 0.0, "a new world's clock starts at zero")
	assert_eq(GameStart.ship_id, &"hauler")
	assert_true(GameStart.pending)
	var began := GameStart.begin(_ship, _origin, _arrivals)
	assert_false(GameStart.pending, "taken once")
	assert_eq(began, GameStart.Began.DOCKED_NEW)
	assert_eq(_arrivals.stage, Arrivals.Stage.DOCKED)
	assert_eq(_ship.berth, _station)
	assert_eq(_arrived, [_station] as Array[Port], "arrived through the arrival function, so the autosave writes")
	assert_almost_eq(_ship.global_position, _station.global_position, Vector3.ONE * 0.001)
	assert_lt(_ship.global_position.length(), 1.0, "the world is centred on the ship")
	assert_almost_eq(_true_position(), Vector3(16000, 1000, 0), Vector3.ONE * 0.01)


func test_continuing_restores_the_world_and_the_ship() -> void:
	var data := _space_save(Vector3(20000, 0, 0), Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO, true, 0.0)
	GameStart.continue_game(data)
	assert_eq(GameStart.mode, GameStart.Mode.CONTINUE)
	assert_eq(Game.world_seed, 777)
	assert_almost_eq(Game.clock, 1234.5, 0.001)
	assert_eq(GameStart.ship_id, &"hauler")
	data["ship"].erase("model")
	GameStart.continue_game(data)
	assert_eq(GameStart.ship_id, GameStart.DEFAULT_SHIP, "a save without a ship is flown in the default one")


func test_continuing_docked_puts_the_ship_back_at_its_berth_without_announcing() -> void:
	GameStart.continue_game({"v": 1, "world": {"world_seed": 9, "clock": 10.0, "streams": {}}, "berth": "test_base"})
	var began := GameStart.begin(_ship, _origin, _arrivals)
	assert_eq(began, GameStart.Began.DOCKED)
	assert_eq(_arrivals.stage, Arrivals.Stage.DOCKED)
	assert_eq(_ship.berth, _pad, "landed where it was saved, not at the station")
	assert_eq(_arrived, [] as Array[Port], "not an arrival: nothing saved again, nothing paid twice")
	assert_eq(_resumed, [_pad] as Array[Port], "but where the ship is still goes on the event bus")
	assert_almost_eq(_ship.global_basis.y, _pad.global_basis.y, Vector3.ONE * 0.001, "upright on the pad")
	var t := _origin.true_position(_ship.global_position)
	assert_almost_eq(Vector3(t[0], t[1], t[2]), Vector3(6005, 0, 40000), Vector3.ONE * 0.01)


func test_continuing_in_space_puts_the_ship_back_exactly_where_it_was() -> void:
	var at := Vector3(23456.25, -1500.5, 3200.75)
	var turn := Quaternion(Vector3(0.3, 1.0, -0.2).normalized(), 1.1)
	var velocity := Vector3(12.0, -3.0, 40.0)
	var spin := Vector3(0.01, 0.2, -0.05)
	GameStart.continue_game(_space_save(at, turn, velocity, spin, false, 0.0))
	var began := GameStart.begin(_ship, _origin, _arrivals)
	assert_eq(began, GameStart.Began.IN_SPACE)
	assert_eq(_arrivals.stage, Arrivals.Stage.FLYING, "flying, not docked")
	assert_null(_ship.berth)
	assert_eq(_arrived, [] as Array[Port])
	assert_almost_eq(_true_position(), at, Vector3.ONE * 0.01, "the same true place")
	assert_lt(_ship.global_position.length(), 0.01, "the world is centred on the ship")
	assert_true(_ship.global_basis.get_rotation_quaternion().is_equal_approx(turn), "facing the same way")
	assert_eq(_ship.linear_velocity, velocity)
	assert_eq(_ship.angular_velocity, spin)
	assert_false(_ship.assist_on(), "flight assist off, as saved")
	await wait_physics_frames(1)
	assert_lt(_ship.jolt, 0.01, "putting it back is no bump")
	assert_almost_eq(_true_position(), at + velocity * DT, Vector3.ONE * 0.05, "and it carries on as it was")


func test_flight_assist_carries_on_holding_its_saved_speed() -> void:
	GameStart.continue_game(_space_save(Vector3(20000, 0, 0), Quaternion.IDENTITY, Vector3(0, 0, -80), Vector3.ZERO,
			true, 80.0))
	GameStart.begin(_ship, _origin, _arrivals)
	assert_true(_ship.assist_on())
	assert_almost_eq(_ship.held_speed(), 80.0, 0.001)
	await wait_physics_frames(30)
	assert_almost_eq(_ship.speed(), 80.0, 0.5, "still holding 80 m/s, not braking to a stop")


func test_saved_in_orbit_presses_o_to_go_back_into_orbit() -> void:
	GameStart.continue_game(_space_save(Vector3(0, 7500, 40000), Quaternion.IDENTITY, Vector3(0, 0, -50), Vector3.ZERO,
			true, 50.0, {"body": "test_planet", "radius": 7500.0, "axis": [1, 0, 0]}))
	GameStart.begin(_ship, _origin, _arrivals)
	assert_true(_ship.input.toggle_orbit, "O is pressed for the pilot, so the orbit is entered the usual way")
	GameStart.continue_game(_space_save(Vector3(0, 7500, 40000), Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO, true,
			0.0))
	GameStart.begin(_ship, _origin, _arrivals)
	assert_false(_ship.input.toggle_orbit, "not in orbit when saved: nothing pressed")


func test_a_save_with_no_usable_place_docks_quietly_at_halfway_station() -> void:
	var data := _space_save(Vector3(20000, 0, 0), Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO, true, 0.0)
	data["ship"]["at"] = ["x", 1, 2]
	GameStart.continue_game(data)
	assert_eq(GameStart.begin(_ship, _origin, _arrivals), GameStart.Began.DOCKED)
	assert_eq(_ship.berth, _station)
	assert_eq(_arrived, [] as Array[Port])


func test_a_berth_that_no_longer_exists_falls_back_to_the_saved_place() -> void:
	var at := Vector3(21000, 10, -30)
	var data := _space_save(at, Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO, true, 0.0)
	data["berth"] = "a_port_since_removed"
	GameStart.continue_game(data)
	assert_eq(GameStart.begin(_ship, _origin, _arrivals), GameStart.Began.IN_SPACE)
	assert_almost_eq(_true_position(), at, Vector3.ONE * 0.01)


func test_reads_numbers_only_when_they_are_all_there() -> void:
	assert_eq(GameStart.numbers([1, 2.5, -3], 3), PackedFloat64Array([1.0, 2.5, -3.0]))
	assert_true(GameStart.numbers([1, 2], 3).is_empty(), "too few")
	assert_true(GameStart.numbers("1,2,3", 3).is_empty(), "not a list")
	assert_true(GameStart.numbers([1, null, 3], 3).is_empty(), "a hole")
	assert_eq(GameStart.vector([1, 2, 3]), Vector3(1, 2, 3))
	assert_eq(GameStart.vector(null), Vector3.ZERO)
