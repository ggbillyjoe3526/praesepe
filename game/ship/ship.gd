class_name Ship
extends RigidBody3D
## A flyable ship. Every physics tick it reads `input` (filled by PilotControls or an autopilot), asks its FlightModel
## for the accelerations and adds them to its velocity; the physics engine moves it and handles bumps. Gravity and
## damping are off: in space nothing slows the ship but its own thrusters.

signal assist_changed(on: bool)

@export var tuning: ShipTuning

var input: ShipInput = ShipInput.new()
var model: FlightModel


func _ready() -> void:
	process_physics_priority = FlightOrder.SHIP
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	model = FlightModel.new(tuning)


func _physics_process(delta: float) -> void:
	var was_on := model.assist
	model.step(pilot_velocity(), pilot_spin(), input, delta)
	if model.assist != was_on:
		assist_changed.emit(model.assist)
	var b := global_basis
	var a := model.linear_accel
	var w := model.angular_accel
	linear_velocity += b * Vector3(a.x, a.y, -a.z) * delta
	angular_velocity += b * Vector3(w.x, -w.y, -w.z) * delta


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
