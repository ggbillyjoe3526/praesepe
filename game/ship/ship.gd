class_name Ship
extends RigidBody3D
## A flyable ship. Every physics tick it reads `input` (filled by PilotControls or an autopilot), asks its FlightModel
## for the accelerations and adds them to its velocity; the physics engine moves it and handles bumps. Gravity and
## damping are off: in space nothing slows the ship but its own thrusters.
## The ship also says where its cameras sit (the pilot's eye in the cockpit, the chase camera behind it) and how hard it
## was last bumped, for camera shake.
## While its cruise drive (CruiseDrive) runs, the drive sets the ship's speed and direction and flight assist only
## turns it; the thrust keys and Z do nothing until it drops out.

signal assist_changed(on: bool)
## The cruise drive charged, engaged, refused or dropped out (CruiseDrive.Event), at `place` where there is one.
signal cruise_changed(event: CruiseDrive.Event, place: Landmark)

@export var tuning: ShipTuning
@export var cruise_tuning: CruiseTuning
## The pilot's eye in the cockpit (game/camera/cockpit_camera.gd).
@export var eye: Node3D
## Where the chase camera sits when the ship flies straight (game/camera/chase_camera.gd).
@export var chase_anchor: Node3D

var input: ShipInput = ShipInput.new()
var model: FlightModel
var cruise: CruiseDrive
## How suddenly the ship's velocity changed in the last physics step for a reason other than its own thrusters, such
## as a bump (m/s). Zero in open space.
var jolt: float = 0.0
var _expected_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_physics_priority = FlightOrder.SHIP
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	model = FlightModel.new(tuning)
	cruise = CruiseDrive.new(cruise_tuning)


func _physics_process(delta: float) -> void:
	# Nothing but a collision changes the velocity between the last tick's thrust and now.
	jolt = linear_velocity.distance_to(_expected_velocity)
	var was_on := model.assist
	var was_cruising := cruise.active()
	cruise.step(global_position, linear_velocity, -global_basis.z, input.toggle_cruise, input.full_stop, jolt, delta)
	input.toggle_cruise = false
	var stopping := input.full_stop
	if was_cruising or cruise.active():
		# The drive has the speed; flight assist only turns the ship. X still stops it once it has dropped out.
		input.thrust = Vector3.ZERO
		input.toggle_assist = false
	if cruise.event == CruiseDrive.Event.ENGAGED:
		model.set_assist(true, 0.0)
	model.step(pilot_velocity(), pilot_spin(), input, delta)
	if model.assist != was_on:
		assist_changed.emit(model.assist)
	var b := global_basis
	var w := model.angular_accel
	angular_velocity += b * Vector3(w.x, -w.y, -w.z) * delta
	if cruise.active():
		model.linear_accel = Vector3.ZERO
		linear_velocity = cruise.velocity
	elif was_cruising:
		model.linear_accel = Vector3.ZERO
		linear_velocity = cruise.velocity
		if not stopping:
			model.set_speed = cruise.exit_speed
	else:
		var a := model.linear_accel
		linear_velocity += b * Vector3(a.x, a.y, -a.z) * delta
	_expected_velocity = linear_velocity
	if cruise.event != CruiseDrive.Event.NONE:
		cruise_changed.emit(cruise.event, cruise.place)


## The ship's velocity in the pilot's frame: x right, y up, z forward.
func pilot_velocity() -> Vector3:
	var v := global_basis.transposed() * linear_velocity
	return Vector3(v.x, v.y, -v.z)


## The ship's spin in the pilot's frame (rad/s): x pitch up, y yaw right, z roll right.
func pilot_spin() -> Vector3:
	var w := global_basis.transposed() * angular_velocity
	return Vector3(w.x, -w.y, -w.z)


func speed() -> float:
	return linear_velocity.length()


func assist_on() -> bool:
	return model.assist


## The forward speed (m/s) flight assist is holding.
func held_speed() -> float:
	return model.set_speed


## How hard the thrusters are pushing, 0 to 1 of the main engine's push.
func thrust_level() -> float:
	if cruise.active():
		return cruise_tuning.rumble
	return clampf(model.linear_accel.length() / tuning.forward_accel, 0.0, 1.0)
