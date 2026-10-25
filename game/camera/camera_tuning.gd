class_name CameraTuning
extends Resource
## How the ship cameras move (game/camera/camera_tuning.tres; DESIGN.md, "How the cameras work"). Shared by every
## ship: where the pilot's eye and the chase camera sit is part of each ship's scene (its Eye and ChaseAnchor markers).
## Change a value there and here together.

@export_group("Cockpit: head sway")
## How far the pilot's head is pushed (m) per m/s² of thrust, the opposite way to the push.
@export var head_sway: float = 0.0012
## The furthest the head moves (m).
@export var head_sway_max: float = 0.06
## How quickly the head follows a push (s); larger is softer.
@export var head_sway_time: float = 0.15

@export_group("Camera shake")
## The engines' rumble at full thrust (degrees of wobble).
@export var rumble_angle: float = 0.12
## A hard bump's wobble (degrees).
@export var bump_angle: float = 2.0
## A sudden change of velocity (m/s, in one tick) that counts as the hardest bump. Thrusters never cause one.
@export var bump_full: float = 6.0
## Changes smaller than this (m/s in one tick) are ignored.
@export var bump_floor: float = 0.3
## How quickly a bump's shake dies away (of a full bump, per second).
@export var bump_decay: float = 1.6
## How fast the wobble moves (noise steps per second).
@export var shake_speed: float = 22.0

@export_group("Chase camera")
## How far behind the ship's turn the camera lags (s): it reaches the ship's heading this long after a steady turn.
@export var chase_lag: float = 0.18
## Reduce motion multiplies the lag by this, so the camera swings less.
@export var chase_lag_reduced: float = 0.5
## How far the camera looks down at the ship (degrees).
@export var chase_look_down: float = 9.0
## With flight assist off, the share of the angle between the nose and the ship's motion the camera turns toward the
## motion, up to `lean_max` degrees.
@export var lean_share: float = 0.5
@export var lean_max: float = 25.0
## The lean starts at this speed (m/s) and is full from `lean_full_speed`.
@export var lean_min_speed: float = 5.0
@export var lean_full_speed: float = 40.0
## How long (s) the lean takes to come in or go when flight assist changes.
@export var lean_blend: float = 0.6
## The camera keeps this far (m) from anything between it and the ship.
@export var clip_radius: float = 0.5
## After being pushed in by something in the way, how long (s) it takes to ease back out.
@export var clip_ease_out: float = 0.5
