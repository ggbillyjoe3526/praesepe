extends GutTest
## The floating origin (design doc, "Large-world precision"): the world is re-centred on the ship, nothing moves
## relative to anything else, and true positions are kept in 64-bit.

var _origin: FloatingOrigin
var _world: Node3D
var _ship: Node3D
var _buoy: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_ship = Node3D.new()
	_buoy = Node3D.new()
	_world.add_child(_ship)
	_world.add_child(_buoy)
	_origin = FloatingOrigin.new()
	_origin.world = _world
	_origin.focus = _ship
	_origin.threshold = 1000.0
	add_child_autofree(_origin)


func test_stays_put_inside_the_threshold() -> void:
	_ship.position = Vector3(900, 0, 0)
	_origin._physics_process(1.0 / 60.0)
	assert_eq(_origin.shift_count, 0)
	assert_eq(_ship.position, Vector3(900, 0, 0))


func test_recentres_on_the_ship_and_keeps_everything_in_place() -> void:
	_ship.position = Vector3(1200, -40, 300)
	_buoy.position = Vector3(1000, 0, 0)
	_origin._physics_process(1.0 / 60.0)
	assert_eq(_origin.shift_count, 1)
	assert_eq(_ship.position, Vector3.ZERO)
	assert_eq(_buoy.position - _ship.position, Vector3(-200, 40, -300), "the buoy is where it was, seen from the ship")
	var t := _origin.true_position(_buoy.position)
	assert_eq(Vector3(t[0], t[1], t[2]), Vector3(1000, 0, 0))


func test_true_positions_stay_exact_far_out() -> void:
	# A million kilometres in 4 km steps: far past where 32-bit positions lose whole metres.
	for i in 250000:
		_origin.shift(Vector3(4000, 0, 0))
	assert_eq(_origin.offset_x, 1.0e9)
	assert_eq(_origin.true_position(Vector3(0.25, 0, 0))[0], 1.0e9 + 0.25)


func test_wrapped_offset_is_exact_far_out() -> void:
	_origin.offset_x = 1.0e9 + 150.0
	_origin.offset_y = -50.0
	var w := _origin.wrapped_offset(400.0)
	assert_almost_eq(w.x, 150.0, 0.001)
	assert_almost_eq(w.y, 350.0, 0.001)


func test_signals_each_shift() -> void:
	watch_signals(_origin)
	_origin.shift(Vector3(5, 6, 7))
	assert_signal_emitted_with_parameters(_origin, "shifted", [Vector3(5, 6, 7)])
