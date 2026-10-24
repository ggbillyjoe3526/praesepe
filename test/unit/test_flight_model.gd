extends GutTest
## The Newtonian flight model with and without flight assist (design doc, "Flight and camera"), flown directly with
## simple integration at the game's 60 Hz tick. Directions are the pilot's: x right, y up, z forward.

const DT := 1.0 / 60.0

var _tuning: ShipTuning
var _model: FlightModel
var _input: ShipInput
var _velocity: Vector3
var _spin: Vector3


func before_each() -> void:
	_tuning = load("res://game/ship/greybox_ship_tuning.tres")
	_model = FlightModel.new(_tuning)
	_input = ShipInput.new()
	_velocity = Vector3.ZERO
	_spin = Vector3.ZERO


## Flies `seconds` with the current input. Spin is integrated as plain rates (no rotation of the frame), which is all
## these checks need.
func _fly(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_model.step(_velocity, _spin, _input, DT)
		_velocity += _model.linear_accel * DT
		_spin += _model.angular_accel * DT


func test_main_engine_accelerates_at_its_thrust() -> void:
	_input.thrust.z = 1.0
	_fly(1.0)
	assert_almost_eq(_velocity.z, _tuning.forward_accel, 0.01)


func test_never_passes_the_top_speed() -> void:
	_input.thrust = Vector3(1, 1, 1)
	_fly(30.0)
	assert_almost_eq(_velocity.length(), _tuning.max_speed, 0.01)


func test_assist_holds_the_speed_reached() -> void:
	_input.thrust.z = 1.0
	_fly(2.0)
	var reached := _velocity.z
	_input.thrust.z = 0.0
	_fly(5.0)
	assert_almost_eq(_velocity.z, reached, 0.01)
	assert_almost_eq(_model.set_speed, reached, 0.01)


func test_assist_cancels_sideways_drift() -> void:
	_velocity = Vector3(20, -10, 50)
	_model.set_speed = 50.0
	_fly(3.0)
	assert_almost_eq(_velocity.x, 0.0, 0.01)
	assert_almost_eq(_velocity.y, 0.0, 0.01)
	assert_almost_eq(_velocity.z, 50.0, 0.01)


func test_assist_drift_correction_is_thruster_limited() -> void:
	# A big slide takes time to cancel: never faster than the side thrusters allow.
	_velocity = Vector3(60, 0, 0)
	_fly(1.0)
	assert_almost_eq(_velocity.x, 60.0 - _tuning.lateral_accel, 0.01)


func test_braking_runs_into_reverse_up_to_its_limit() -> void:
	_velocity = Vector3(0, 0, 20)
	_input.thrust.z = -1.0
	_fly(10.0)
	assert_almost_eq(_velocity.z, -_tuning.max_reverse_speed, 0.5)
	assert_almost_eq(_model.set_speed, -_tuning.max_reverse_speed, 0.5)


func test_assist_stops_the_turn_when_the_stick_centres() -> void:
	_input.turn = Vector3(1, 1, 1)
	_fly(2.0)
	var rates := _tuning.max_rates()
	assert_almost_eq(_spin.x, rates.x, 0.001)
	assert_almost_eq(_spin.y, rates.y, 0.001)
	assert_almost_eq(_spin.z, rates.z, 0.001)
	_input.turn = Vector3.ZERO
	_fly(1.5)
	assert_almost_eq(_spin.length(), 0.0, 0.0001)


func test_turns_build_up_at_the_turn_acceleration() -> void:
	_input.turn.x = 1.0
	_fly(0.1)
	assert_almost_eq(_spin.x, _tuning.turn_accels().x * 0.1, 0.001)


func test_assist_off_drifts_and_spins() -> void:
	_input.toggle_assist = true
	_fly(DT)
	assert_false(_model.assist)
	assert_false(_input.toggle_assist, "the one-shot is used up")
	_velocity = Vector3(15, 0, 40)
	_input.turn.y = 1.0
	_fly(0.2)
	_input.turn.y = 0.0
	var spinning := _spin
	_fly(3.0)
	assert_eq(_velocity, Vector3(15, 0, 40), "nothing cancels the drift")
	assert_eq(_spin, spinning, "nothing stops the spin")


func test_assist_off_never_spins_past_the_turn_rate() -> void:
	_model.assist = false
	_input.turn.z = 1.0
	_fly(5.0)
	assert_almost_eq(_spin.z, _tuning.max_rates().z, _tuning.turn_accels().z * DT)


func test_assist_on_again_holds_the_current_speed() -> void:
	_model.assist = false
	_velocity = Vector3(0, 0, 70)
	_input.toggle_assist = true
	_fly(DT)
	assert_true(_model.assist)
	assert_almost_eq(_model.set_speed, 70.0, 0.01)


func test_full_stop_turns_assist_on_and_stops() -> void:
	_model.assist = false
	_velocity = Vector3(10, 5, 150)
	_spin = Vector3(0.3, -0.2, 0.5)
	_input.full_stop = true
	_fly(12.0)
	assert_true(_model.assist)
	assert_almost_eq(_velocity.length(), 0.0, 0.01)
	assert_almost_eq(_spin.length(), 0.0, 0.0001)
