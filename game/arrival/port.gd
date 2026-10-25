class_name Port
extends Marker3D
## A place where a ship docks or lands (design doc, "Docking and landing"): a station's docking bay or a base's landing
## pad. The marker is where the ship is held while it is there, its nose along the marker's -z and its top along +y.
## It sits in the station's or base's own scene, so it moves with it (and with the floating origin).
##
## The ship is offered docking or landing (Arrivals) when it is close enough and slow enough. For a dock, close enough
## is `offer_range` metres from the marker; for a pad on a planet or moon, it is `offer_range` metres above that
## body's surface, anywhere round it, so approaching the planet is enough to see the prompt to land at its base.
## Docking or landing, the ship flies itself in (Approach): round the station or planet to the port's gate, out along
## the way out where nothing is in the way, then straight in along it. Leaving, it is eased out along the way out
## (forward out of a bay, straight up off a pad) for `exit_distance` metres, speeding up to `exit_speed`, before the
## pilot has it back.

enum Kind { DOCK, PAD }

@export var kind: Kind = Kind.DOCK
## Its name in save files. Never change it once players have saves.
@export var id: StringName = &""
## How close (m) the ship must be to be offered it: from the marker for a dock, above the body's surface for a pad.
@export var offer_range: float = 1500.0
## Beyond offer_range but within this (m), the HUD says how much closer to come.
@export var hint_range: float = 3500.0
## The ship must be slower than this (m/s) to be offered it.
@export var max_speed: float = 100.0
## Leaving: how far (m) the ship is eased out, and how fast (m/s) it is going by then.
@export var exit_distance: float = 60.0
@export var exit_speed: float = 20.0
## How far out (m) along the way out the gate is, where the final leg in starts. It must be clear of everything at
## the station or base, and so must everything as far from the station's or planet's centre as it is (Port.centre):
## the way to it keeps at least that far out.
@export var approach_distance: float = 220.0

## The station or base it belongs to (its nearest Landmark ancestor), and the planet or moon it stands on (its nearest
## CelestialBody ancestor), or null for a station in space.
var place: Landmark
var body: CelestialBody


func _ready() -> void:
	var node := get_parent()
	while node != null:
		if place == null and node is Landmark:
			place = node
		if node is CelestialBody:
			body = node
			break
		node = node.get_parent()


## The name the HUD and messages use: the station's or base's.
func place_name() -> String:
	return place.display_name if place != null else String(id)


## How far (m) `point` is from being offered it: from the marker for a dock, the height above the surface for a pad.
func distance(point: Vector3) -> float:
	return body.surface_distance(point) if body != null else point.distance_to(global_position)


## Where the final leg in starts (world space): approach_distance out along the way out.
func gate() -> Vector3:
	return global_position + exit_direction() * approach_distance


## What the way to the gate goes round (world space): the centre of the planet or moon a pad stands on, or of the
## station a dock belongs to.
func centre() -> Vector3:
	if body != null:
		return body.global_position
	return place.global_position if place != null else global_position


## Which way (world space, unit) the ship leaves.
func exit_direction() -> Vector3:
	return global_basis.y if kind == Kind.PAD else -global_basis.z
