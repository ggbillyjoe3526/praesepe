class_name OrbitTuning
extends Resource
## How one ship enters and holds an orbit (design doc, "Orbit"). One file per ship, like
## `game/ship/greybox_orbit_tuning.tres`; the values and the reasons for them are in DESIGN.md, "Orbit tuning".
## Each planet or moon sets its own orbit line and speed (CelestialBody). Change a value there and here together.

@export_group("Entering")
## The ship can enter orbit only below this speed (m/s): anything but cruising.
@export var max_entry_speed: float = 250.0
## How hard (m/s²) the thrusters swing the ship's velocity onto the orbit, like a firm push from the side thrusters.
@export var entry_accel: float = 25.0

@export_group("Guide")
## The orbit line and its insertion point show within this many times the orbit's height above the surface.
@export var guide_reach: float = 2.0
## The insertion point sits as far ahead along the orbit as a climb (or descent) this steep (degrees) would take to
## reach the line, so flying at it is a gentle climb into orbit, like a launch.
@export var insertion_climb: float = 30.0
## And never nearer than this (m) ahead, so on the line it is still just ahead.
@export var insertion_lead: float = 400.0

@export_group("Holding")
## How quickly (s) the orbit closes a gap between the ship's height and the orbit's.
@export var settle_time: float = 4.0
## The fastest (m/s) it climbs or sinks to close that gap.
@export var max_climb: float = 30.0
## The ship counts as settled in orbit once its height is within this (m) of the orbit's.
@export var settle_tolerance: float = 5.0
## A bump harder than this (m/s, Ship.jolt) knocks the ship out of orbit.
@export var bump_limit: float = 3.0

@export_group("View")
## On entering, the ship turns to face along the orbit with the planet below, nose dipped so the horizon sits this
## far (degrees) above the middle of the view, a band of planet filling the cockpit window under it (negative puts the
## horizon below the middle). Moving the mouse stops the turn and leaves the view to the pilot.
@export var horizon_above: float = 5.0
## The turn asks for a rate that would close the angle in about this long (s); the ship's own turn limits apply.
@export var turn_time: float = 0.8
## Lined up to within this (degrees) counts as done.
@export var turn_tolerance: float = 0.5

@export_group("Leaving")
## Leaving with O or a thrust key, the ship takes this long (s) to bring its nose up level along its velocity before
## flight assist takes over, so it flies on the way it was going rather than down the dipped nose's line. A turn too
## big to make that fast within the ship's turn rates takes longer.
@export var level_time: float = 1.0
