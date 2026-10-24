class_name ChaseCamera
extends Camera3D
## The third-person view behind the ship while flying (design doc, "Camera"). It sits at the ship's ChaseAnchor and
## looks down at it a little, but turns a moment behind the ship (CameraTuning.chase_lag), so a turn shows as the ship
## swinging ahead of the camera. With flight assist off it leans toward where the ship is really moving, so a drift
## stays readable; the lean eases in and out when assist changes. Something between the camera and the ship (a buoy, a
## station wall) pulls the camera in at once, never through it; it eases back out once the way is clear.
## ShipCameras sets it up, calls check_clearance() every physics tick and place() every frame while it is the view.

var ship: Ship
var tuning: CameraTuning
var shake: CameraShake
## How far the lean has come in, 0 (assist on) to 1 (assist off).
var lean: float = 0.0
## How much of the way out to the anchor the camera sits, 0 to 1 (less while something is in the way).
var reach: float = 1.0

## The camera's lagging orientation, following the ship's.
var _heading: Quaternion = Quaternion.IDENTITY
## How far out the way is clear, from the last physics tick (0 to 1).
var _clear: float = 1.0
var _cast: ShapeCast3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_cast = ShapeCast3D.new()
	_cast.enabled = false
	_cast.top_level = true
	_cast.max_results = 1
	add_child(_cast)


## Connects the camera to its ship. Called once by ShipCameras.
func setup(to_ship: Ship, with_tuning: CameraTuning, with_shake: CameraShake) -> void:
	ship = to_ship
	tuning = with_tuning
	shake = with_shake
	var ball := SphereShape3D.new()
	ball.radius = tuning.clip_radius
	_cast.shape = ball
	_cast.clear_exceptions()
	_cast.add_exception(ship)


## Starts the camera straight behind the ship, with no lag, the lean matching flight assist, and only as far out as
## the way is clear. Called when the view switches to it, so it never swings in from an old position.
func snap() -> void:
	_heading = ship.get_global_transform_interpolated().basis.get_rotation_quaternion()
	lean = 0.0 if ship.assist_on() else 1.0
	check_clearance()
	reach = _clear


## Looks for anything between the ship and where the camera wants to be. Physics queries belong in the physics tick.
func check_clearance() -> void:
	var from := ship.global_position
	_cast.global_transform = Transform3D(Basis.IDENTITY, from)
	_cast.target_position = Basis(_heading) * ship.chase_anchor.position
	_cast.force_shapecast_update()
	_clear = _cast.get_closest_collision_safe_fraction() if _cast.is_colliding() else 1.0


## Puts the camera in place for this frame, `delta` seconds after the last.
func place(delta: float) -> void:
	var drawn := ship.get_global_transform_interpolated()
	var target := drawn.basis.get_rotation_quaternion()
	lean = lerpf(lean, 0.0 if ship.assist_on() else 1.0, Smoothing.factor(delta, tuning.lean_blend))
	var weight := lean * smoothstep(tuning.lean_min_speed, tuning.lean_full_speed, ship.speed())
	target = ChaseCamera.lean_toward(-drawn.basis.z, ship.linear_velocity, tuning.lean_share,
			deg_to_rad(tuning.lean_max) * weight) * target
	var lag := tuning.chase_lag * (tuning.chase_lag_reduced if Settings.reduce_motion else 1.0)
	_heading = _heading.slerp(target, Smoothing.factor(delta, lag)).normalized()
	# Pulled in at once when something is in the way, eased back out when it is gone.
	reach = _clear if _clear < reach else lerpf(reach, _clear, Smoothing.factor(delta, tuning.clip_ease_out))
	var facing := Basis(_heading)
	var look := facing * Basis(Vector3.RIGHT, -deg_to_rad(tuning.chase_look_down))
	var turn := Basis.from_euler(shake.angles(tuning, Settings.shake_amount()))
	global_transform = Transform3D(look * turn, drawn.origin + facing * ship.chase_anchor.position * reach)


## The direction the camera is heading (its lagging forward, before it looks down at the ship).
func heading_forward() -> Vector3:
	return -(Basis(_heading).z)


## The turn that leans a view facing `forward` toward `velocity`: `share` of the angle between them, at most
## `furthest` radians. No turn when there is no motion, no lean allowed, or the ship moves exactly along its nose or
## exactly backwards (no way to choose a side).
static func lean_toward(forward: Vector3, velocity: Vector3, share: float, furthest: float) -> Quaternion:
	if furthest <= 0.0 or velocity.is_zero_approx():
		return Quaternion.IDENTITY
	var moving := velocity.normalized()
	var axis := forward.cross(moving)
	if axis.length_squared() < 1.0e-8:
		return Quaternion.IDENTITY
	return Quaternion(axis.normalized(), minf(forward.angle_to(moving) * share, furthest))
