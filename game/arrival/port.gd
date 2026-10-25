class_name Port
extends Marker3D
## A place where a ship docks or lands (design doc, "Docking and landing"): a station's docking bay or a base's landing
## pad. The marker is where the ship is held while it is there, its nose along the marker's -z and its top along +y.
## It sits in the station's or base's own scene, so it moves with it (and with the floating origin).
##
## The ship is offered docking or landing (Arrivals) when it is within `offer_range` metres of the marker and slow
## enough. Docking or landing, the ship flies itself in (Approach) from where it is, at about the speed it was going:
## round the station or planet to the port's gate, out along the way out where nothing is in the way, then straight in
## along it: nose first into a bay, turning round inside it (`turn_round_at`) so it ends up looking out of the mouth,
## then settling straight down onto the bay's floor (`settle`); or settling straight down onto a pad. Leaving, it lifts
## off the floor first, then is eased out along the way out (forward out of a bay, straight up off a pad) for
## `exit_distance` metres, speeding up to `exit_speed`, before the pilot has it back. A faint light (GuideLight) shines
## out along the way in, so a pilot can line up by eye.

enum Kind { DOCK, PAD }

@export var kind: Kind = Kind.DOCK
## Its name in save files. Never change it once players have saves.
@export var id: StringName = &""
## How close (m) to the marker the ship must be to be offered it.
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
## For a pad: the lowest (m) the gate may sit above it. A ship asked to land from lower than approach_distance above the
## pad goes to a gate at its own height (but never below this, which clears the base's buildings), so it never climbs
## higher than it must. 0 keeps the gate at approach_distance whatever the ship's height (a dock).
@export var low_gate: float = 0.0
## For a bay: how high (m) above the berth the way in runs (the middle of the bay's mouth). The ship comes in at that
## height, turns round over the berth and settles straight down onto the floor, where the marker is; leaving, it lifts
## back up first. 0 for a pad, whose way in already comes straight down.
@export var settle: float = 0.0
## For a bay the ship flies into nose first: how far (m) from the berth it stops and turns round to face out, before
## easing back the rest of the way. 0 for a pad: it comes down already facing the berth's way.
@export var turn_round_at: float = 0.0
## The port's lane: where a ship takes the final leg straight from where it is, because nothing stands between it
## and the line in (inside the bay, or over the pad clear of the buildings round it). Elsewhere it goes to the gate
## first. Half its width (m) across the port (its x axis) and up and down it (its y axis for a dock, z for a pad), from
## the gate in to this far (m) behind the berth (to the bay's back wall, or under the pad's marker).
@export var lane: Vector2 = Vector2(10.0, 10.0)
@export var lane_behind: float = 10.0
@export_group("Guide light")
## The faint light along the way in (GuideLight): its colour, how far (m) out from the port it starts and ends, and how
## wide (m) it is. A reach of 0 leaves the port without one.
@export var guide_colour: Color = Color(0.4, 0.9, 1.0)
@export var guide_start: float = 0.0
@export var guide_reach: float = 400.0
@export var guide_radius: float = 2.0

## The station or base it belongs to (its nearest Landmark ancestor), and the planet or moon it stands on (its nearest
## CelestialBody ancestor), or null for a station in space.
var place: Landmark
var body: CelestialBody
## Set by Arrivals while the ship is in the port's lane or flying itself in: the guide light shines brighter, so the
## pilot sees they are lined up.
var guiding: bool = false:
	set(on):
		if on != guiding:
			guiding = on
			if _light != null:
				_light.wake()


var _light: GuideLight = null


func _ready() -> void:
	var node := get_parent()
	while node != null:
		if place == null and node is Landmark:
			place = node
		if node is CelestialBody:
			body = node
			break
		node = node.get_parent()
	if guide_reach > 0.0:
		_light = GuideLight.new()
		_light.name = "GuideLight"
		_light.port = self
		add_child(_light)


## The name the HUD and messages use: the station's or base's.
func place_name() -> String:
	return place.display_name if place != null else String(id)


## How far (m) `point` is from being offered it: from the marker.
func distance(point: Vector3) -> float:
	return point.distance_to(global_position)


## Where the line in runs from (world space): `settle` above the berth in a bay, the berth itself on a pad.
func lane_origin() -> Vector3:
	return global_position + global_basis.y.normalized() * settle


## Where the final leg in starts (world space): `out` metres (approach_distance unless told) out along the way out.
func gate(out: float = -1.0) -> Vector3:
	return lane_origin() + exit_direction() * (approach_distance if out < 0.0 else out)


## How far out (m) the gate is for a ship asked in from `at` (world space): approach_distance, or for a pad with a
## low_gate, the ship's own height above the pad (round the planet it stands on) within low_gate and approach_distance.
func gate_distance(at: Vector3) -> float:
	if low_gate <= 0.0:
		return approach_distance
	var height := (at - lane_origin()).dot(exit_direction())
	if body != null:
		height = (at - centre()).length() - (lane_origin() - centre()).length()
	return clampf(height, low_gate, approach_distance)


## What the way to the gate goes round (world space): the centre of the planet or moon a pad stands on, or of the
## station a dock belongs to.
func centre() -> Vector3:
	if body != null:
		return body.global_position
	return place.global_position if place != null else global_position


## Which way (world space, unit) the ship leaves.
func exit_direction() -> Vector3:
	return global_basis.y if kind == Kind.PAD else -global_basis.z


## Whether a ship at `at` (world space) is in the port's lane (lane, lane_behind).
func in_lane(at: Vector3) -> bool:
	var along := (at - lane_origin()).dot(exit_direction())
	if along < -lane_behind or along > approach_distance:
		return false
	var local := global_basis.orthonormalized().inverse() * (at - lane_origin())
	var across := Vector2(local.x, local.z if kind == Kind.PAD else local.y)
	return (across / lane).length() <= 1.0
