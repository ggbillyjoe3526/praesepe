class_name ShipInput
extends RefCounted
## The one input a ship flies by. The pilot's controls (PilotControls) and the autopilot (the smoke test) fill it every
## physics tick and nothing else steers a ship, so a scripted flight goes through exactly the code a player does.
## Directions are the pilot's: x right, y up, z forward.

## Thrust, each axis -1 to 1: x strafe right, y up, z forward (negative is brake or reverse).
var thrust: Vector3 = Vector3.ZERO
## Turning, each axis -1 to 1: x pitch up, y yaw right, z roll right.
var turn: Vector3 = Vector3.ZERO
## Switch flight assist on or off (one-shot: the ship clears it once used).
var toggle_assist: bool = false
## Bring the ship to a stop, turning flight assist on if it was off (one-shot).
var full_stop: bool = false


## Back to no input.
func reset() -> void:
	thrust = Vector3.ZERO
	turn = Vector3.ZERO
	toggle_assist = false
	full_stop = false
