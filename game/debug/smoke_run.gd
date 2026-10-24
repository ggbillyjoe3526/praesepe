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
## It checks the cameras on the way: the dashboard shows the speed, the pilot's head sways back and the engines rumble
## while speeding up, the chase camera lags behind a turn and settles straight behind again, leans toward the drift
## with flight assist off, and pulls in when a wall is put behind the ship (and eases out once it is gone).
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
## When, while speeding up, the head sway and the rumble are checked.
const SWAY_CHECK := 120
## How far (m) behind the ship the test wall goes, and how long the camera gets to react to it and to its going.
const WALL_DISTANCE := 11.0
const WALL_TICKS := 30
const CLEAR_TICKS := 150
## How far apart (m) the ship's true movement and its velocity may be in one tick.
const STEP_SLACK := 0.05

var ship: Ship
var origin: FloatingOrigin
var pause: PauseScreen
var cameras: ShipCameras

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
var _wall: StaticBody3D
var _check_eye_on_frame: bool = false


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
		0: # Speed up to the top speed with flight assist on, in the cockpit.
			input.thrust.z = 1.0
			_top_speed = maxf(_top_speed, ship.speed())
			if _phase_ticks == SWAY_CHECK:
				_check_cockpit_under_thrust()
			if _phase_ticks >= ACCELERATE:
				_expect(absf(ship.speed() - ship.tuning.max_speed) < 0.5, "reaches the top speed (%.2f m/s)" % ship.speed())
				_check_dashboard()
				_next()
		1: # Let go: assist holds the speed.
			if _phase_ticks >= HOLD:
				_expect(absf(ship.speed() - ship.held_speed()) < 0.5, "holds its speed (%.2f, set %.2f)" % [ship.speed(),
						ship.held_speed()])
				_expect(ship.held_speed() > ship.tuning.max_speed - 1.0, "keeps the set speed (%.2f)" % ship.held_speed())
				_start_forward = _forward()
				cameras.set_view(ShipCameras.View.CHASE)
				_expect(cameras.current() == cameras.chase and cameras.chase.current, "switches to the chase camera")
				_expect(_chase_lag() < 0.1, "starts the chase camera straight behind (%.2f degrees off)" % _chase_lag())
				_next()
		2: # Turn right, watched from the chase camera.
			input.turn.y = 1.0
			if _phase_ticks >= TURN:
				var lag := _chase_lag()
				_expect(lag > 1.0 and lag < 20.0, "chase camera lags a little behind the turn (%.2f degrees)" % lag)
				_expect(cameras.chase.is_position_in_frustum(ship.global_position), "stays in the chase camera's view")
				_next()
		3: # Let go: assist stops the turn and lines the motion up with the nose.
			if _phase_ticks >= SETTLE:
				var spin := ship.angular_velocity.length()
				var slip := rad_to_deg(ship.linear_velocity.angle_to(_forward()))
				_expect(spin < 0.002, "stops turning (%.4f rad/s)" % spin)
				_expect(_forward().angle_to(_start_forward) > deg_to_rad(30.0), "has turned")
				_expect(slip < 1.0, "moves along its nose again (%.2f degrees off)" % slip)
				_expect(_chase_lag() < 0.5, "chase camera settles straight behind (%.2f degrees off)" % _chase_lag())
				_expect(cameras.chase.lean < 0.01, "chase camera doesn't lean with assist on (%.3f)" % cameras.chase.lean)
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
				_expect(cameras.chase.lean > 0.9, "chase camera leans toward the drift (%.3f)" % cameras.chase.lean)
				input.full_stop = true
				_next()
		5: # Full stop: assist comes back on and brings the ship to rest.
			if _phase_ticks == 1:
				_expect(ship.assist_on(), "full stop turns flight assist on")
			if ship.speed() < 0.05 and ship.angular_velocity.length() < 0.001:
				_put_wall()
				_next()
			elif _phase_ticks >= STOP_LIMIT:
				_expect(false, "comes to a full stop (%.2f m/s, %.4f rad/s)" % [ship.speed(),
						ship.angular_velocity.length()])
				_next()
		6: # A wall behind the ship: the chase camera comes in front of it, then eases out once it is gone.
			if _phase_ticks == WALL_TICKS:
				var back := cameras.chase.global_position - ship.global_position
				var behind := back.dot(ship.global_basis.z)
				_expect(cameras.chase.reach < 0.6, "pulls the chase camera in for the wall (reach %.2f)" % cameras.chase.reach)
				_expect(behind < WALL_DISTANCE - 0.5, "keeps the chase camera in front of the wall (%.2f m behind)" % behind)
				_wall.queue_free()
			if _phase_ticks >= WALL_TICKS + CLEAR_TICKS:
				_expect(cameras.chase.reach > 0.95, "eases the chase camera back out (reach %.2f)" % cameras.chase.reach)
				cameras.set_view(ShipCameras.View.COCKPIT)
				_expect(cameras.current() == cameras.cockpit and cameras.cockpit.current, "switches back to the cockpit")
				_next()
		7: # Pause: the ship and the clock stand still until resumed.
			_paused_at = ship.global_position
			_paused_clock = Game.clock
			_paused_frames = 0
			pause.open()
			_next()
		8:
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


## Speeding up in the cockpit: the camera is at the eye, the head is pushed back a little, and the engines rumble.
func _check_cockpit_under_thrust() -> void:
	var cockpit := cameras.cockpit
	_expect(cameras.current() == cockpit and cockpit.current, "starts in the cockpit")
	_expect(cockpit.sway.z > 0.02 and cockpit.sway.length() <= cockpit.tuning.head_sway_max + 0.001,
			"pushes the pilot's head back a little (%.3f m)" % cockpit.sway.z)
	_expect(cameras.shake.rumble > 0.5, "rumbles under thrust (%.2f)" % cameras.shake.rumble)
	_check_eye_on_frame = true


## The cameras are placed each frame from the ship's drawn position, so where they are is checked in a frame (after
## ShipCameras has placed them), not in a physics tick.
func _process(_delta: float) -> void:
	if not _check_eye_on_frame:
		return
	_check_eye_on_frame = false
	var eye := ship.get_global_transform_interpolated() * ship.eye.position
	var off := cameras.cockpit.global_position.distance_to(eye)
	_expect(off < cameras.cockpit.tuning.head_sway_max + 0.001, "keeps the camera at the pilot's eye (%.3f m off)" % off)


func _check_dashboard() -> void:
	var shown := (ship.get_node(^"Cockpit") as CockpitDisplay).shown()
	var speed := FlightHud.speed_text(roundi(ship.speed()))
	var assist := FlightHud.assist_text(true, roundi(ship.held_speed()))
	_expect(shown[0] == speed and shown[1] == assist, "shows its speed on the dashboard (%s / %s)" % [shown[0],
			shown[1]])


## How far (degrees) the chase camera's heading is from the ship's nose.
func _chase_lag() -> float:
	return rad_to_deg(cameras.chase.heading_forward().angle_to(_forward()))


## A wall across the way behind the ship, where the chase camera wants to be. It goes in the floating origin's world,
## like everything solid.
func _put_wall() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 60.0, 1.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	_wall = StaticBody3D.new()
	_wall.add_child(shape)
	origin.world.add_child(_wall)
	_wall.global_transform = Transform3D(ship.global_basis, ship.global_position + ship.global_basis.z * WALL_DISTANCE)


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
