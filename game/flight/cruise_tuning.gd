class_name CruiseTuning
extends Resource
## How one ship's cruise drive behaves (design doc, "Cruise drive"). One file per ship, like
## `game/ship/greybox_cruise_tuning.tres`; the values and the reasons for them are in DESIGN.md, "Cruise drive
## tuning". Change a value there and here together.

@export_group("Engaging")
## How long (s) the drive charges after F before it takes over. The ship flies normally meanwhile.
@export var charge_time: float = 2.0
## It won't engage when the nose points at something it would reach within this (s), at the ship's own forward speed
## or min_speed, whichever is more.
@export var engage_look_ahead: float = 5.0

@export_group("Locking on")
## Pressing F with the nose within this (degrees) of a place's marker, or on a planet's or moon's disc, locks the drive
## onto it: it flies there by itself. The marker nearest the nose wins; a disc counts only with no marker that close.
@export var lock_cone: float = 4.0
## Locked on, how quickly (s) the nose is turned to follow the way the ship is going.
@export var lock_turn_time: float = 0.6
## Locked on, the drive goes round a planet, moon or station in its way, keeping this far above its surface: this many
## of its radii, and never less than its arrival zone (Landmark.drop_distance).
@export var clearance: float = 1.0
## Locked onto a place on a planet's surface (a base), the drive flies straight at it once it sees it at least this
## high (degrees) above the place's horizon; lower, it goes round the planet first.
@export var approach_angle: float = 15.0

@export_group("Speed (m/s)")
## The slowest the drive goes, close to anything. Faster than normal flight, so cruising always gains time.
@export var min_speed: float = 300.0
## The fastest it goes, in open space.
@export var max_speed: float = 5000.0
## The drive's speed is the distance (m) to the nearest surface divided by this (s): far from everything it is fast,
## and it slows down smoothly on the way in, so every trip ends with a few seconds of approach.
@export var approach_time: float = 6.0
## How quickly (s) the speed follows that target: it changes by at most its own size over this time.
@export var ramp_time: float = 1.5
## How quickly (s) the direction of travel follows the nose when turning.
@export var align_time: float = 0.4

@export_group("Dropping out")
## The forward speed (m/s) the ship keeps after dropping out, held by flight assist.
@export var exit_speed: float = 200.0
## The drive drops out when it would reach a surface in less than this (s), even where it wasn't heading.
@export var safety_time: float = 2.5
## The forward speed (m/s) after such a safety drop, slow enough to turn away with room to spare.
@export var safety_exit_speed: float = 50.0
## A bump harder than this (m/s, Ship.jolt) drops the drive out.
@export var bump_limit: float = 3.0

@export_group("Feel")
## How hard the engines rumble while cruising, 0 to 1 of a full-thrust rumble (camera shake).
@export var rumble: float = 0.3
