class_name CockpitCamera
extends Camera3D
## The first-person view from the pilot's seat, the main view (design doc, "Camera"). It sits at the ship's Eye marker
## and turns with the ship. With head bob on, the pilot's head sways a few centimetres against the thrusters' push
## (back when the main engine fires, sideways when sliding), easing in and out so it never jolts. Camera shake turns
## the view by a fraction of a degree. While the pilot looks round (`look`), the head turns. Placed every frame from the ship's drawn (interpolated) transform, so it moves
## exactly with the cockpit around it. ShipCameras sets it up and calls place() while it is the active view.

var ship: Ship
var tuning: CameraTuning
var shake: CameraShake
## Where the head has swayed to, in the ship's frame (m).
var sway: Vector3 = Vector3.ZERO
## Where the pilot is looking (ShipCameras.look).
var look: Vector2 = Vector2.ZERO


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Puts the camera at the eye for this frame, `delta` seconds after the last.
func place(delta: float) -> void:
	var target := Vector3.ZERO
	if Settings.head_moves():
		target = CockpitCamera.sway_target(ship.model.linear_accel, tuning.head_sway, tuning.head_sway_max)
	sway = sway.lerp(target, Smoothing.factor(delta, tuning.head_sway_time))
	var eye := ship.eye.transform
	var turn := Basis.from_euler(shake.angles(tuning, Settings.shake_amount()))
	var head := eye.basis * ShipCameras.head_turn(look) if look != Vector2.ZERO else eye.basis
	global_transform = ship.get_global_transform_interpolated() * Transform3D(head * turn, eye.origin + sway)


## Starts the next place() from a still head.
func settle() -> void:
	sway = Vector3.ZERO


## Where the head is pushed by the thrusters' `push` (m/s², the pilot's frame: x right, y up, z forward): the opposite
## way, `per_accel` metres per m/s², at most `furthest` metres. In the ship's frame (x right, y up, z back).
static func sway_target(push: Vector3, per_accel: float, furthest: float) -> Vector3:
	return (Vector3(-push.x, -push.y, push.z) * per_accel).limit_length(furthest)
