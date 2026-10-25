extends GutTest
## The game scene starts where GameStart says (design doc, "Starting a game"): continuing a game saved out in space,
## the real solar system comes up on the saved seed with the ship at its saved true place, heading and speed, and the
## HUD says the game was loaded; continuing one saved docked, it is in the station's bay. Opened on its own (F6 in
## the editor), it starts in flight and never writes the save.

var _seed_before: int = 0


func before_each() -> void:
	_seed_before = Game.world_seed


func after_each() -> void:
	GameStart.mode = GameStart.Mode.NEW
	GameStart.ship_id = GameStart.DEFAULT_SHIP
	GameStart.saved = {}
	GameStart.pending = false
	Game.start_world(_seed_before)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_main() -> Node:
	var main: Node = load(TitleScreen.MAIN_SCENE).instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	return main


func test_continuing_in_space_puts_the_ship_back_in_the_real_system() -> void:
	var at := Vector3(14000.0, 9000.0, -2500.0)
	var turn := Quaternion(Vector3.UP, 0.8)
	var velocity := Vector3(0, 0, -30).rotated(Vector3.UP, 0.8)
	GameStart.continue_game({"v": 2, "world": {"world_seed": 4321, "clock": 600.0, "streams": {}}, "berth": "",
			"home": String(GameStart.START_PORT),
			"ship": {"model": "hauler", "at": [at.x, at.y, at.z], "turn": [turn.x, turn.y, turn.z, turn.w],
			"velocity": [velocity.x, velocity.y, velocity.z], "spin": [0, 0, 0], "assist": true, "held": 30.0,
			"orbit": {}}})
	var main := await _open_main()
	var ship: Ship = main.get_node("World/Ship")
	var origin: FloatingOrigin = main.get_node("FloatingOrigin")
	assert_eq(Game.world_seed, 4321)
	var t := origin.true_position(ship.global_position)
	# A few ticks on from where it was saved, along its saved velocity (how many depends on the frames the test took).
	var moved := Vector3(t[0], t[1], t[2]) - at
	assert_lt(moved.length(), velocity.length() * 10.0 / 60.0, "where it was saved")
	assert_almost_eq(moved, velocity.normalized() * moved.length(), Vector3.ONE * 0.05, "moving as it was")
	assert_almost_eq(ship.linear_velocity, velocity, Vector3.ONE * 0.05)
	assert_null(ship.berth)
	var hud: FlightHud = main.get_node("Hud/FlightHud")
	assert_eq(hud.toast_text(), FlightHud.welcome_message(null))
	assert_eq(ship.model_id, &"hauler")
	# Saved again now, it says the same: the autosave's format and the loader agree.
	var arrivals: Arrivals = main.get_node("Arrivals")
	assert_eq(arrivals.home.id, GameStart.START_PORT)
	var again: Dictionary = SaveGame.snapshot(null, arrivals.home, ship, origin)
	var place := GameStart.numbers(again.ship.at, 3)
	assert_lt(Vector3(place[0], place[1], place[2]).distance_to(at), velocity.length() * 10.0 / 60.0, "a few ticks on")
	var facing := GameStart.numbers(again.ship.turn, 4)
	assert_true(Quaternion(facing[0], facing[1], facing[2], facing[3]).is_equal_approx(turn))
	assert_eq(again.home, String(GameStart.START_PORT))
	assert_eq(again.ship.model, "hauler")


func test_continuing_docked_is_in_the_bay() -> void:
	GameStart.continue_game({"v": 1, "world": {"world_seed": 4321, "clock": 600.0, "streams": {}},
			"berth": String(GameStart.START_PORT)})
	var main := await _open_main()
	var ship: Ship = main.get_node("World/Ship")
	var arrivals: Arrivals = main.get_node("Arrivals")
	assert_eq(arrivals.stage, Arrivals.Stage.DOCKED)
	assert_eq(ship.berth.id, GameStart.START_PORT)
	assert_eq(main.get_node("Hud/FlightHud").toast_text(), FlightHud.welcome_message(ship.berth))
	assert_eq(FlightHud.welcome_message(ship.berth), "Welcome back  ·  Docked at Halfway Station")


func test_opened_on_its_own_it_starts_in_flight_and_saves_nothing() -> void:
	var saved := []
	var on_saved := func(ok: bool) -> void: saved.append(ok)
	Events.game_saved.connect(on_saved)
	var main := await _open_main()
	Events.game_saved.disconnect(on_saved)
	var ship: Ship = main.get_node("World/Ship")
	assert_null(ship.berth, "flying at the start point, as before the title screen")
	assert_eq(saved, [], "the player's save is never touched")
