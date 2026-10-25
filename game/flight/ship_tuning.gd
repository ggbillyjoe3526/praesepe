class_name ShipTuning
extends Resource
## How one ship flies: its thrusters, top speed and turn rates (project instructions, "Tuning values in data"). One
## file per ship, like `game/ship/greybox_ship_tuning.tres`; the values and the reasons for them are in DESIGN.md,
## "Flight tuning". Change a value there and here together.

@export_group("Thrusters (m/s²)")
## The main engine, pushing the nose forward.
@export var forward_accel: float = 40.0
## The braking thrusters, pushing backward.
@export var reverse_accel: float = 25.0
## Sideways thrusters (strafe left and right).
@export var lateral_accel: float = 30.0
## Up and down thrusters.
@export var vertical_accel: float = 30.0

@export_group("Speed (m/s)")
## The top speed in normal flight. The cruise drive will go beyond it later.
@export var max_speed: float = 200.0
## The fastest the ship backs up with flight assist on.
@export var max_reverse_speed: float = 50.0

@export_group("Turning (degrees per second)")
## The fastest the nose turns, for a full stick.
@export var pitch_rate: float = 50.0
@export var yaw_rate: float = 35.0
@export var roll_rate: float = 100.0
## How quickly a turn starts and stops (degrees per second, per second). Lower feels heavier.
@export var pitch_accel: float = 120.0
@export var yaw_accel: float = 90.0
@export var roll_accel: float = 250.0

@export_group("Flight assist")
## How hard flight assist chases its target speed: the time (s) it would take to close a gap at this rate, before the
## thruster limits above cap it. Smaller is snappier.
@export var assist_response: float = 0.35
## The same for turning: how quickly assist settles the nose on the stick's turn rate.
@export var assist_turn_response: float = 0.12

@export_group("Rolling upright")
## R rolls the ship upright (Upright), closing the roll left at a rate that would take this long (s), never faster than
## the full roll rate.
@export var upright_time: float = 0.4
## Upright once the roll left is under this (degrees) and it rolls slower than this (degrees per second).
@export var upright_tolerance: float = 0.5
@export var upright_settled_spin: float = 1.0


## The turn rates as radians per second: pitch up, yaw right, roll right.
func max_rates() -> Vector3:
	return Vector3(deg_to_rad(pitch_rate), deg_to_rad(yaw_rate), deg_to_rad(roll_rate))


## The turn accelerations as radians per second squared, in the same order.
func turn_accels() -> Vector3:
	return Vector3(deg_to_rad(pitch_accel), deg_to_rad(yaw_accel), deg_to_rad(roll_accel))
