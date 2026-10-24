extends GutTest
## Seeds are law (design doc, "Seeded generation"): the same world seed replays the same draws, and the streams are
## independent of each other.


func _draws(rng: RandomNumberGenerator, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(rng.randi())
	return out


func test_same_seed_same_stream_same_draws() -> void:
	var a := Seeds.stream(Seeds.stream_seed(1234, &"contracts"))
	var b := Seeds.stream(Seeds.stream_seed(1234, &"contracts"))
	assert_eq(_draws(a, 20), _draws(b, 20))


func test_streams_and_seeds_differ() -> void:
	assert_ne(Seeds.stream_seed(1234, &"contracts"), Seeds.stream_seed(1234, &"world"))
	assert_ne(Seeds.stream_seed(1234, &"contracts"), Seeds.stream_seed(1235, &"contracts"))


func test_stream_seeds_never_change() -> void:
	# Pinned values: if these change (new constants, a new derivation or an engine PRNG change), every saved seed gives
	# a different world. Change them only on purpose.
	assert_eq(Seeds.name_hash(&"world"), 0x37A3E893)
	assert_eq(Seeds.stream_seed(0, &"world"), 3106713684)
	assert_eq(Seeds.stream_seed(Seeds.MAX_SEED, &"contracts"), 614400176)
	assert_eq(Seeds.stream(Seeds.stream_seed(0, &"world")).randi(), 368859715)


func test_seeds_stay_32_bit() -> void:
	for s: int in [0, 1, Seeds.MAX_SEED, -1, 0x1_0000_0001]:
		var v := Seeds.stream_seed(s, &"events")
		assert_between(v, 0, Seeds.MAX_SEED)


func test_game_streams_restart_with_the_world() -> void:
	Game.start_world(42)
	var first := _draws(Game.rng(&"contracts"), 5)
	Game.rng(&"world").randi()
	Game.start_world(42)
	assert_eq(_draws(Game.rng(&"contracts"), 5), first, "drawing from another stream moved nothing")
	assert_eq(Game.clock, 0.0)


func test_fx_draws_never_move_gameplay_draws() -> void:
	Game.start_world(7)
	var plain := _draws(Game.rng(&"world"), 5)
	Game.start_world(7)
	for i in 50:
		Game.rng(Game.FX_STREAM).randf()
	assert_eq(_draws(Game.rng(&"world"), 5), plain)


func test_a_kept_generator_follows_a_new_world() -> void:
	Game.start_world(5)
	var kept := Game.rng(&"events")
	var first := kept.randi()
	Game.start_world(5)
	assert_eq(kept.randi(), first, "the generator someone kept was reseeded in place")


func test_snapshot_and_restore_continue_the_same_draws() -> void:
	Game.start_world(1234)
	Game.rng(&"world").randi()
	Game.rng(&"contracts").randi()
	Game.skip_time(90.5)
	# through JSON, as a save file stores it
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Game.snapshot()))
	var expected := _draws(Game.rng(&"contracts"), 5) + _draws(Game.rng(&"world"), 5)
	Game.start_world(999)
	Game.restore(saved)
	assert_eq(Game.world_seed, 1234)
	assert_eq(Game.clock, 90.5)
	assert_eq(_draws(Game.rng(&"contracts"), 5) + _draws(Game.rng(&"world"), 5), expected)


func test_restore_ignores_bad_values() -> void:
	Game.restore({"world_seed": 3, "clock": "soon", "streams": {"world": "not a number", "made_up": "12"}})
	assert_eq(Game.world_seed, 3)
	assert_eq(Game.clock, 0.0)
	Game.start_world(3)
	var fresh := _draws(Game.rng(&"world"), 3)
	Game.restore({"world_seed": 3, "streams": {"world": "not a number"}})
	assert_eq(_draws(Game.rng(&"world"), 3), fresh, "an unreadable state starts that stream fresh")
	Game.restore({"world_seed": [1, 2], "clock": {"a": 1}})
	assert_eq(Game.world_seed, 0, "a damaged seed starts seed 0, never a script error")
	assert_eq(Game.clock, 0.0)


func test_skip_time_only_moves_forward() -> void:
	Game.start_world(1)
	Game.skip_time(3600.0)
	Game.skip_time(-10.0)
	assert_eq(Game.clock, 3600.0)
