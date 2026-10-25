class_name NavTuning
extends Resource
## How the nav computer (NavComputer) flies its orders (design doc, "Nav computer tuning"). One file,
## `game/nav/nav_tuning.tres`; the values and the reasons for them are in DESIGN.md. Change a value there and here
## together.

@export_group("Steering")
## How quickly (s) it turns the nose toward where it is going, as the cruise drive's lock does.
@export var turn_time: float = 0.8
## It starts the cruise drive once the nose is within this (degrees) of the drive's course.
@export var aim_tolerance: float = 5.0
## While the nose is further than this (degrees) from where it is going, it doesn't speed up.
@export var turning_cone: float = 20.0
## How hard it pushes the throttle: full at this many m/s from the speed it wants.
@export var speed_band: float = 10.0

@export_group("Leaving")
## Before cruising it climbs this far (m) clear of a station's or base's surface, so the drive will engage.
@export var clearance: float = 150.0

@export_group("Arriving")
## Closing in on a dock or pad, it slows so it would reach the port's offer range in this (s) at its speed.
@export var close_in_time: float = 8.0
## Within reach of a dock or pad, it flies at this share of the port's top speed for docking or landing.
@export var arrive_speed_share: float = 0.8
## Lining up for orbit, it flies at this share of the orbit's top entry speed.
@export var orbit_speed_share: float = 0.8

@export_group("Giving up")
## A step it can't get on with for this long (s) pauses the plan, saying why.
@export var give_up_time: float = 90.0
## The most orders a plan holds.
@export var max_steps: int = 8
