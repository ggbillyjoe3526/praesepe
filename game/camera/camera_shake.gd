class_name CameraShake
extends RefCounted
## Camera shake for the ship cameras (project instructions, "camera shake slider"): a low rumble while the thrusters
## push, and a wobble after a bump that dies away. Presentation only: its noise is seeded once from Game.FX_STREAM and
## it never touches gameplay. The physics tick reports what the ship felt (feel()), each frame moves the wobble on
## (advance()), and both cameras read the same angles(), scaled by the player's shake setting.

## How quickly the rumble follows the thrusters (s).
const RUMBLE_EASE := 0.2
## Where on the noise each axis reads, far enough apart to move independently.
const AXIS_GAP := 97.0
## Roll wobbles less than pitch and yaw.
const ROLL_SHARE := 0.5

## A bump's share of the strongest shake, 0 to 1; it dies away at CameraTuning.bump_decay per second.
var trauma: float = 0.0
## The thrusters' push, 0 to 1, eased so the rumble never starts or stops with a jolt.
var rumble: float = 0.0

var _rumble_target: float = 0.0
var _noise: FastNoiseLite
var _time: float = 0.0


func _init(seed_value: int) -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = seed_value


## What the ship felt this physics tick: `jolt` (m/s, Ship.jolt) and the thrusters' push (0 to 1).
func feel(jolt: float, thrust: float, tuning: CameraTuning) -> void:
	var span := maxf(tuning.bump_full - tuning.bump_floor, 0.001)
	trauma = maxf(trauma, clampf((jolt - tuning.bump_floor) / span, 0.0, 1.0))
	_rumble_target = clampf(thrust, 0.0, 1.0)


## Moves the wobble on by `delta` seconds of game time.
func advance(delta: float, tuning: CameraTuning) -> void:
	_time += delta * tuning.shake_speed
	trauma = maxf(trauma - tuning.bump_decay * delta, 0.0)
	rumble = lerpf(rumble, _rumble_target, Smoothing.factor(delta, RUMBLE_EASE))


## The shake now, as small turns in radians (x pitch, y yaw, z roll), times `amount` (the player's setting, 0 to 1).
## A bump grows with the square of its trauma, so small knocks stay small.
func angles(tuning: CameraTuning, amount: float) -> Vector3:
	var size := (deg_to_rad(tuning.bump_angle) * trauma * trauma + deg_to_rad(tuning.rumble_angle) * rumble) * amount
	if size <= 0.0:
		return Vector3.ZERO
	return Vector3(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(_time, AXIS_GAP),
			_noise.get_noise_2d(_time, AXIS_GAP * 2.0) * ROLL_SHARE) * size
