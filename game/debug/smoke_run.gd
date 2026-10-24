class_name SmokeRun
extends Node
## The headless smoke test behind `-- --smoke` (tools/smoke_test.sh): an autopilot flies the ship through the same
## ShipInput a player uses and checks the flight model as it goes. It speeds up to the top speed, lets go (assist holds
## the speed), turns and lets go (assist stops the turn and lines the ship's motion up with its nose), turns flight
## assist off (the ship keeps drifting and spinning), brings it to a full stop, pauses and resumes, and flies far
## enough for the floating origin to re-centre the world at least once. Each tick it also checks the ship's true
## position moved exactly as its velocity says, which catches a bad shift. Any failed check is an error, which fails
## the run; otherwise it prints the result line the script looks for, then quits.
##
## Ticks are physics ticks at 60 Hz. tools/smoke_test.sh runs with `--fixed-fps 60`, so a run is the same every time
## and finishes as fast as the machine allows.

## tools/smoke_test.sh fails unless this line is printed.
const PASS_LINE := "SMOKE: ok"
const ACCELERATE := 600
const HOLD := 180
const TURN := 90
const SETTLE := 600
const SPIN := 30
const DRIFT := 120
const STOP_LIMIT := 900
const PAUSED_FRAMES := 30
## How far apart (m) the ship's true movement and its velocity may be in one tick.
const STEP_SLACK := 0.05

var ship: Ship
var origin: FloatingOrigin
var pause: PauseScreen

var _frames: int = 0
var _phase: int = 0
var _phase_ticks: int = 0
var _failures: int = 0
var _top_speed: float = 0.0
var _start_forward: Vector3 = Vector3.ZERO
var _drift_velocity: Vector3 = Vector3.ZERO
var _last_true: PackedFloat64Array = PackedFloat64Array()
var _last_velocity: Vector3 = Vector3.ZERO
var _paused_at: Vector3 = Vector3.ZERO
var _paused_clock: float = 0.0
var _paused_frames: int = 0


func _ready() -> void:
	# Runs during the pause too, to check that nothing moves and to resume.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = FlightOrder.CONTROLS


func _physics_process(_delta: float) -> void:
	_frames += 1
	if get_tree().paused:
		_while_paused()
		return
	_check_step()
	_phase_ticks += 1
	var input := ship.input
	input.reset()
	match _phase:
		0: # Speed up to the top speed with flight assist on.
			input.thrust.z = 1.0
			_top_speed = maxf(_top_speed, ship.speed())
			if _phase_ticks >= ACCELERATE:
				_expect(absf(ship.speed() - ship.tuning.max_speed) < 0.5, "reaches the top speed (%.2f m/s)" % ship.speed())
				_next()
		1: # Let go: assist holds the speed.
			if _phase_ticks >= HOLD:
				_expect(absf(ship.speed() - ship.held_speed()) < 0.5, "holds its speed (%.2f, set %.2f)" % [ship.speed(),
						ship.held_speed()])
				_expect(ship.held_speed() > ship.tuning.max_speed - 1.0, "keeps the set speed (%.2f)" % ship.held_speed())
				_start_forward = _forward()
				_next()
		2: # Turn right.
			input.turn.y = 1.0
			if _phase_ticks >= TURN:
				_next()
		3: # Let go: assist stops the turn and lines the motion up with the nose.
			if _phase_ticks >= SETTLE:
				var spin := ship.angular_velocity.length()
				var slip := rad_to_deg(ship.linear_velocity.angle_to(_forward()))
				_expect(spin < 0.002, "stops turning (%.4f rad/s)" % spin)
				_expect(_forward().angle_to(_start_forward) > deg_to_rad(30.0), "has turned")
				_expect(slip < 1.0, "moves along its nose again (%.2f degrees off)" % slip)
				input.toggle_assist = true
				_drift_velocity = ship.linear_velocity
				_next()
		4: # Assist off: a short turn left, then let go.
			if _phase_ticks == 1:
				_expect(not ship.assist_on(), "turns flight assist off")
			if _phase_ticks <= SPIN:
				input.turn.y = -1.0
			if _phase_ticks >= SPIN + DRIFT:
				var drift := ship.linear_velocity.distance_to(_drift_velocity)
				_expect(drift < 0.01, "keeps drifting the same way (velocity moved %.4f m/s)" % drift)
				_expect(ship.angular_velocity.length() > 0.1, "keeps spinning (%.3f rad/s)" % ship.angular_velocity.length())
				input.full_stop = true
				_next()
		5: # Full stop: assist comes back on and brings the ship to rest.
			if _phase_ticks == 1:
				_expect(ship.assist_on(), "full stop turns flight assist on")
			if ship.speed() < 0.05 and ship.angular_velocity.length() < 0.001:
				_next()
			elif _phase_ticks >= STOP_LIMIT:
				_expect(false, "comes to a full stop (%.2f m/s, %.4f rad/s)" % [ship.speed(),
						ship.angular_velocity.length()])
				_next()
		6: # Pause: the ship and the clock stand still until resumed.
			_paused_at = ship.global_position
			_paused_clock = Game.clock
			_paused_frames = 0
			pause.open()
			_next()
		7:
			_finish()


func _while_paused() -> void:
	_paused_frames += 1
	if _paused_frames < PAUSED_FRAMES:
		return
	_expect(ship.global_position == _paused_at, "stands still while paused")
	_expect(Game.clock == _paused_clock, "the clock stops while paused")
	pause.close()
	_expect(not get_tree().paused, "resumes")
	# The ship stood still; start the movement check afresh.
	_last_true = PackedFloat64Array()


## The ship's true position should move by its velocity each tick (to within the physics step), whatever the floating
## origin did. A shift that moved the ship differently from the world would show here as a jump.
func _check_step() -> void:
	var now := origin.true_position(ship.global_position)
	if not _last_true.is_empty():
		var moved := Vector3(now[0] - _last_true[0], now[1] - _last_true[1], now[2] - _last_true[2])
		var expected := _last_velocity / Engine.physics_ticks_per_second
		if moved.distance_to(expected) > STEP_SLACK + expected.length() * 0.01:
			_expect(false, "moves by its velocity (moved %s, expected %s, tick %d)" % [moved, expected, _frames])
	_expect(ship.global_position.length() <= origin.threshold + ship.tuning.max_speed, "stays near the origin")
	_last_true = now
	_last_velocity = ship.linear_velocity


func _forward() -> Vector3:
	return -ship.global_basis.z


func _next() -> void:
	_phase += 1
	_phase_ticks = 0


func _expect(ok: bool, what: String) -> void:
	if ok:
		return
	_failures += 1
	push_error("SMOKE: the ship %s: failed" % what)


func _finish() -> void:
	set_physics_process(false)
	_expect(origin.shift_count >= 1, "flew far enough to re-centre the world")
	if _failures > 0:
		push_error("SMOKE: %d checks failed" % _failures)
		get_tree().quit(1)
		return
	var t := origin.true_position(ship.global_position)
	print("%s frames=%d seed=%d clock=%.2f top=%.2f shifts=%d at=(%.3f, %.3f, %.3f)" % [PASS_LINE, _frames,
			Game.world_seed, Game.clock, _top_speed, origin.shift_count, t[0], t[1], t[2]])
	get_tree().quit(0)
