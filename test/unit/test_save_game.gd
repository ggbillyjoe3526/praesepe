extends GutTest
## The saved game and the autosave (project instructions, "Saves"): arriving at a port writes the game (SaveGame,
## through SaveFile) and says whether it worked; what it writes reads back with the world, the berth, home and the
## ship; a failed write is reported and the game carries on. In flight the game is saved every `interval` of in-game
## time on a worker thread, only while the ship is somewhere loading can put it back (not cruising, nor being flown
## in). Old saves are brought up to date when read; saves from a newer game are refused.

const PATH := "user://test_savegame.json"

var _port: Port
var _saved: Array[bool] = []


func before_each() -> void:
	SaveFile.remove(PATH)
	_saved.clear()
	_port = Port.new()
	_port.id = &"test_port"
	add_child_autofree(_port)
	Events.game_saved.connect(_on_saved)


func after_each() -> void:
	Events.game_saved.disconnect(_on_saved)
	SaveFile.remove(PATH)


func _on_saved(ok: bool) -> void:
	_saved.append(ok)


func _ship() -> Ship:
	var ship: Ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func _autosave(ship: Ship = null) -> Autosave:
	var autosave := Autosave.new()
	autosave.path = PATH
	autosave.ship = ship
	add_child_autofree(autosave)
	return autosave


func test_writes_the_world_the_berth_and_home() -> void:
	assert_true(SaveGame.write(PATH, SaveGame.snapshot(_port, _port)))
	var r := SaveGame.read(PATH)
	assert_true(r.ok)
	assert_eq(r.data.v, SaveGame.VERSION)
	assert_eq(r.data.berth, "test_port")
	assert_eq(r.data.home, "test_port")
	assert_false(r.data.has("ship"), "no ship given, none saved")
	assert_eq(int(r.data.world.world_seed), Game.world_seed)


func test_writes_the_ship_where_it_truly_is() -> void:
	var ship := _ship()
	var origin := FloatingOrigin.new()
	add_child_autofree(origin)
	origin.offset_x = 1.0e9
	origin.offset_z = -2.5
	ship.global_transform = Transform3D(Basis(Vector3.UP, 0.5), Vector3(10.25, -3.0, 7.0))
	ship.linear_velocity = Vector3(1, 2, 3)
	ship.angular_velocity = Vector3(0.1, 0, 0)
	assert_true(SaveGame.write(PATH, SaveGame.snapshot(null, _port, ship, origin)))
	var data: Dictionary = SaveGame.read(PATH).data
	assert_eq(data.berth, "", "flying, no berth")
	assert_eq(data.home, "test_port")
	var saved: Dictionary = data.ship
	assert_eq(saved.model, "hauler")
	assert_eq(saved.at, [1.0e9 + 10.25, -3.0, 4.5], "true position, exact far out")
	var turn := Quaternion(saved.turn[0], saved.turn[1], saved.turn[2], saved.turn[3])
	assert_almost_eq(turn.angle_to(Quaternion(Vector3.UP, 0.5)), 0.0, 0.0001)
	assert_eq(saved.velocity, [1.0, 2.0, 3.0])
	assert_almost_eq(float(saved.spin[0]), 0.1, 0.0001)
	assert_true(saved.assist)
	assert_eq(saved.orbit, {}, "not in orbit")


func test_a_version_1_save_is_brought_up_to_date() -> void:
	var old := {"v": 1, "world": Game.snapshot(), "berth": "halfway_station"}
	assert_true(SaveFile.write(PATH, SaveGame.KIND, 1, old))
	var r := SaveGame.read(PATH)
	assert_true(r.ok)
	assert_eq(r.data.v, SaveGame.VERSION)
	assert_eq(r.data.berth, "halfway_station")
	assert_eq(r.data.home, "halfway_station", "its berth was the last port it arrived at")
	assert_false(r.data.has("ship"), "loading puts it at its berth")


func test_a_save_from_a_newer_game_is_refused() -> void:
	assert_true(SaveFile.write(PATH, SaveGame.KIND, SaveGame.VERSION + 1, {"berth": "x"}))
	var r := SaveGame.read(PATH)
	assert_false(r.ok)
	assert_true(r.newer)


func test_arriving_autosaves() -> void:
	var autosave := _autosave()
	Events.arrived.emit(_port)
	assert_eq(_saved, [true] as Array[bool])
	assert_eq(autosave.last_berth, &"test_port")
	assert_true(SaveGame.read(PATH).ok)
	# A second arrival keeps the first as the backup.
	Events.arrived.emit(_port)
	assert_true(FileAccess.file_exists(PATH + SaveFile.BAK))


func test_a_failed_write_is_reported() -> void:
	var autosave := _autosave()
	autosave.path = "user://no_such_folder/savegame.json"
	Events.arrived.emit(_port)
	assert_eq(_saved, [false] as Array[bool])
	assert_false(autosave.last_ok)


func test_saves_in_flight_every_interval() -> void:
	var ship := _ship()
	var autosave := _autosave(ship)
	autosave.interval = 0.5
	autosave.due = Game.clock + 0.5
	await wait_physics_frames(20)
	assert_eq(autosave.flight_saves, 0, "not yet due")
	await wait_until(func() -> bool: return autosave.flight_saves == 1, 2.0)
	assert_eq(autosave.flight_saves, 1)
	assert_true(autosave.last_ok)
	assert_eq(autosave.last_berth, &"")
	assert_almost_eq(autosave.due, Game.clock + 0.5, 0.2, "the next is a full interval on")
	var r := SaveGame.read(PATH)
	assert_true(r.ok)
	assert_eq(r.data.berth, "")
	assert_true(r.data.has("ship"))


func test_waits_while_cruising_and_while_docked() -> void:
	var ship := _ship()
	var autosave := _autosave(ship)
	autosave.due = Game.clock
	ship.cruise.phase = CruiseDrive.Phase.CRUISING
	assert_false(autosave.can_save_in_flight(), "cruising")
	ship.cruise.phase = CruiseDrive.Phase.OFF
	ship.orbit.phase = Orbit.Phase.ENTERING
	assert_false(autosave.can_save_in_flight(), "swinging into orbit")
	ship.orbit.phase = Orbit.Phase.ORBITING
	assert_true(autosave.can_save_in_flight(), "settled in orbit")
	ship.orbit.phase = Orbit.Phase.OFF
	ship.hold_at(_port)
	assert_false(autosave.can_save_in_flight(), "docked: arriving saved it")
	ship.approach(_port)
	assert_false(autosave.can_save_in_flight(), "being flown in")


func test_save_now_writes_at_once_where_it_can() -> void:
	var ship := _ship()
	var autosave := _autosave(ship)
	assert_true(autosave.save_now(), "flying")
	assert_eq(SaveGame.read(PATH).data.berth, "")
	ship.hold_at(_port)
	assert_true(autosave.save_now(), "docked")
	assert_eq(autosave.last_berth, &"test_port")
	assert_eq(SaveGame.read(PATH).data.berth, "test_port")
	ship.release(Vector3.ZERO)
	ship.cruise.phase = CruiseDrive.Phase.CHARGING
	assert_false(autosave.save_now(), "not while the cruise drive charges")
	assert_eq(SaveGame.read(PATH).data.berth, "test_port", "the last save is kept")
	ship.cruise.phase = CruiseDrive.Phase.OFF
	assert_eq(_saved, [true, true] as Array[bool])
