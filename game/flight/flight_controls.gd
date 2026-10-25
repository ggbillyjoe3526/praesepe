class_name FlightControls
extends Resource
## How the mouse and keys steer, and how the mouse looks round the cockpit while the look button is held
## (game/flight/flight_controls.tres; DESIGN.md, "Flight tuning"). Not per ship: the same for every ship. The player's
## sensitivity multiplies mouse_gain and look_gain, and inverting is theirs too (Settings › Controls).

## How far one pixel of mouse movement pushes the stick (a full push is 1).
@export var mouse_gain: float = 0.004
## How quickly the stick drifts back to the centre once the mouse stops (per second; 0 keeps it where it was left).
## With assist on, the ship stops turning as it does.
@export var stick_return: float = 3.0

@export_group("Looking round")
## How far (degrees) one pixel of mouse movement turns the pilot's head while the look button is held.
@export var look_gain: float = 0.1
## The furthest the head turns (degrees): left or right, up, and down.
@export var look_side_max: float = 140.0
@export var look_up_max: float = 70.0
@export var look_down_max: float = 45.0
## How quickly (s) the head turns back to the front once the look button is let go.
@export var look_return_time: float = 0.2
