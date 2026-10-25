class_name FlightControls
extends Resource
## How the mouse and keys steer (game/flight/flight_controls.tres; DESIGN.md, "Flight tuning"). Not per ship: the same
## for every ship. The player's sensitivity multiplies mouse_gain, and inverting is theirs too (Settings › Controls).

## How far one pixel of mouse movement pushes the stick (a full push is 1).
@export var mouse_gain: float = 0.004
## How quickly the stick drifts back to the centre once the mouse stops (per second; 0 keeps it where it was left).
## With assist on, the ship stops turning as it does.
@export var stick_return: float = 3.0