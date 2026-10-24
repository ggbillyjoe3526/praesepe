class_name FlightModel
extends RefCounted
## The one Newtonian flight model (design doc, "Flight and camera"). Each physics tick it turns the pilot's input into
## the ship's acceleration, limited by its thrusters (ShipTuning); the physics engine then moves the ship. Nothing here
## touches nodes, so the unit tests fly it directly.
##
## Flight assist on (the default): the ship goes where it points. W and S change the set speed; let go and the ship
## holds that speed along its nose, with its thrusters cancelling any sideways drift and stopping the nose turning when
## the stick is centred. It keeps its weight: every correction is limited by the same thrusters, so a fast turn slides.
## Flight assist off: full drift. Thrust and turning act only while held; the ship keeps its speed, direction and spin.
##
## All vectors are in the pilot's frame: x right, y up, z forward; turning is x pitch up, y yaw right, z roll right.

var tuning: ShipTuning
var assist: bool = true
## The forward speed (m/s) flight assist holds, from -max_reverse_speed to max_speed.
var set_speed: float = 0.0
## This tick's results: acceleration (m/s²) and turn acceleration (rad/s²), pilot frame.
var linear_accel: Vector3 = Vector3.ZERO
var angular_accel: Vector3 = Vector3.ZERO


func _init(ship_tuning: ShipTuning) -> void:
	tuning = ship_tuning


## Switches flight assist. Turning it on holds the current forward speed, so nothing lurches.
func set_assist(on: bool, forward_speed: float) -> void:
	if on and not assist:
		set_speed = clampf(forward_speed, -tuning.max_reverse_speed, tuning.max_speed)
	assist = on


## Works out this tick's accelerations from the ship's velocity and spin (pilot frame) and the input. Uses and clears
## the input's one-shots.
func step(velocity: Vector3, spin: Vector3, input: ShipInput, delta: float) -> void:
	if input.toggle_assist:
		set_assist(not assist, velocity.z)
	if input.full_stop:
		set_assist(true, velocity.z)
		set_speed = 0.0
	input.toggle_assist = false
	input.full_stop = false
	if assist:
		_assisted_thrust(velocity, input.thrust)
		_assisted_turn(spin, input.turn)
	else:
		linear_accel = _direct(input.thrust, _thrust_pos(), _thrust_neg())
		angular_accel = _capped_turn(spin, input.turn)
	_cap_speed(velocity, delta)
	if assist and absf(input.thrust.z) > 0.0:
		# While W or S is held the set speed follows the ship, so letting go holds whatever speed it reached.
		set_speed = clampf(velocity.z + linear_accel.z * delta, -tuning.max_reverse_speed, tuning.max_speed)


## Assist: thrust is direct on any held axis; a released axis is brought to its target (the set speed forward, zero
## sideways and vertically).
func _assisted_thrust(velocity: Vector3, thrust: Vector3) -> void:
	var pos := _thrust_pos()
	var neg := _thrust_neg()
	var target := Vector3(0.0, 0.0, set_speed)
	var a := Vector3.ZERO
	for axis in 3:
		if absf(thrust[axis]) > 0.0:
			a[axis] = thrust[axis] * (pos[axis] if thrust[axis] > 0.0 else neg[axis])
		else:
			a[axis] = clampf((target[axis] - velocity[axis]) / tuning.assist_response, -neg[axis], pos[axis])
	linear_accel = a
	# Braking or reversing never runs past the reverse limit.
	if velocity.z <= -tuning.max_reverse_speed and linear_accel.z < 0.0:
		linear_accel.z = 0.0


## Assist: the stick sets a turn rate and the thrusters chase it, so a centred stick stops the nose.
func _assisted_turn(spin: Vector3, turn: Vector3) -> void:
	var rates := tuning.max_rates()
	var accels := tuning.turn_accels()
	var a := Vector3.ZERO
	for axis in 3:
		var target := clampf(turn[axis], -1.0, 1.0) * rates[axis]
		a[axis] = clampf((target - spin[axis]) / tuning.assist_turn_response, -accels[axis], accels[axis])
	angular_accel = a


## No assist: the stick pushes the turn and nothing stops it, though it never spins past the ship's turn rate.
func _capped_turn(spin: Vector3, turn: Vector3) -> Vector3:
	var rates := tuning.max_rates()
	var a := _direct(turn, tuning.turn_accels(), tuning.turn_accels())
	for axis in 3:
		if absf(spin[axis]) >= rates[axis] and signf(a[axis]) == signf(spin[axis]):
			a[axis] = 0.0
	return a


## Above the top speed, thrust that would go faster is dropped, while thrust that turns or slows still works.
func _cap_speed(velocity: Vector3, delta: float) -> void:
	var next := velocity + linear_accel * delta
	var limit := maxf(tuning.max_speed, velocity.length())
	if next.length() > limit:
		linear_accel = (next.normalized() * limit - velocity) / delta


func _direct(input: Vector3, pos: Vector3, neg: Vector3) -> Vector3:
	var a := Vector3.ZERO
	for axis in 3:
		var v := clampf(input[axis], -1.0, 1.0)
		a[axis] = v * (pos[axis] if v > 0.0 else neg[axis])
	return a


## The thruster limits pushing right, up and forward.
func _thrust_pos() -> Vector3:
	return Vector3(tuning.lateral_accel, tuning.vertical_accel, tuning.forward_accel)


## The thruster limits pushing left, down and backward.
func _thrust_neg() -> Vector3:
	return Vector3(tuning.lateral_accel, tuning.vertical_accel, tuning.reverse_accel)
