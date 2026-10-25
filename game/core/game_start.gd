class_name GameStart
## How a game starts (design doc, "Starting a game"). The title screen (game/ui/title_screen.gd) picks new game or
## continue and opens the main scene, which then puts the ship where this says (begin()). Kept in static variables,
## so the choice survives the change of scene.
##
## A new game starts on a fresh world (or the `--seed` one), docked at Halfway Station in the ship the player chose.
## Continuing puts back the saved game exactly as it was saved: the world (seed, clock, random streams), and the ship
## docked or landed where it was, or out in space at the same place, heading and speed, never moved to a station.

enum Mode {
	NEW, ## A new game: docked at START_PORT in `ship_id`.
	CONTINUE, ## The saved game in `saved`.
}

enum Began {
	DOCKED_NEW, ## A new game, docked at Halfway Station (and saved).
	DOCKED, ## Continued at the saved berth (or Halfway Station when the save held no usable place).
	IN_SPACE, ## Continued out in space where it was saved.
	NOWHERE, ## No port to start at (a broken scene): the ship stays where it was.
}

## Where a new game starts (the port's id: Halfway Station's docking bay).
const START_PORT := &"halfway_station"
## The ship a game flies when nothing else was chosen.
const DEFAULT_SHIP := &"hauler"

static var mode: Mode = Mode.NEW
## The ship this game is flown in (ShipClass.id). Saved with the game.
static var ship_id: StringName = DEFAULT_SHIP
## The saved game being continued (SaveGame's data), while mode is CONTINUE.
static var saved: Dictionary = {}


## Starts a new game in `ship`, on the world `seed_value`: the main scene starts it docked at Halfway Station.
static func new_game(ship: StringName, seed_value: int) -> void:
	mode = Mode.NEW
	ship_id = ship
	saved = {}
	Game.start_world(seed_value)


## Continues the saved game `data` (SaveGame's data): its world now, its ship once the main scene opens.
static func continue_game(data: Dictionary) -> void:
	mode = Mode.CONTINUE
	saved = data
	var world: Variant = data.get("world", {})
	Game.restore(world if world is Dictionary else {})
	var ship: Variant = data.get("ship", {})
	var model: Variant = ship.get("model", "") if ship is Dictionary else ""
	ship_id = StringName(model) if model is String and not model.is_empty() else DEFAULT_SHIP


## Puts `ship` where the game starts, with the floating origin centred on it, and says what happened (BEGAN_...). A
## new game docks it at Halfway Station through the arrival function, which autosaves straight away. Continuing
## places it as saved without announcing an arrival (no autosave, no payout): at its berth when it was docked or
## landed; otherwise at its saved place, heading, velocity and spin, with flight assist as it was, and back into
## orbit when it was orbiting (O pressed for the pilot, so the orbit is entered the usual way). A save that names a
## port that no longer exists, or holds no usable place, docks it at Halfway Station instead, quietly.
static func begin(ship: Ship, origin: FloatingOrigin, arrivals: Arrivals) -> Began:
	if mode == Mode.NEW:
		return _dock(GameStart.port(arrivals, START_PORT), origin, arrivals, true)
	var berth := GameStart.port(arrivals, StringName(str(saved.get("berth", ""))))
	if berth != null:
		return _dock(berth, origin, arrivals, false)
	var block: Variant = saved.get("ship", null)
	if block is Dictionary and _place_in_space(block, ship, origin):
		return Began.IN_SPACE
	return _dock(GameStart.port(arrivals, START_PORT), origin, arrivals, false)


## The port among `arrivals`' whose id is `id`, or null.
static func port(arrivals: Arrivals, id: StringName) -> Port:
	if id.is_empty():
		return null
	for p: Port in arrivals.ports:
		if p.id == id:
			return p
	return null


static func _dock(at: Port, origin: FloatingOrigin, arrivals: Arrivals, announce: bool) -> Began:
	if at == null:
		push_error("GameStart: no port '%s' to start at" % START_PORT)
		return Began.NOWHERE
	origin.shift(at.global_position)
	arrivals.arrive(at, announce)
	return Began.DOCKED_NEW if announce else Began.DOCKED


## Places the ship out in space as `block` says. False when its place is missing or unreadable.
static func _place_in_space(block: Dictionary, ship: Ship, origin: FloatingOrigin) -> bool:
	var at := GameStart.numbers(block.get("at"), 3)
	if at.is_empty():
		return false
	var turn := GameStart.numbers(block.get("turn"), 4)
	var facing := Quaternion(turn[0], turn[1], turn[2], turn[3]).normalized() if not turn.is_empty() \
			else Quaternion.IDENTITY
	if not facing.is_normalized():
		facing = Quaternion.IDENTITY
	# The saved place is a true position (the planet's centre is 0, 0, 0); the world is re-centred on it.
	var local := Vector3(at[0] - origin.offset_x, at[1] - origin.offset_y, at[2] - origin.offset_z)
	var assist: Variant = block.get("assist", true)
	var held: Variant = block.get("held", 0.0)
	ship.resume_flight(Transform3D(Basis(facing), local), GameStart.vector(block.get("velocity")),
			GameStart.vector(block.get("spin")), assist if assist is bool else true,
			float(held) if held is float or held is int else 0.0)
	origin.shift(local)
	# In orbit when saved: {"body": ..., "radius": ..., "axis": [...]}, {} when not.
	var orbit: Variant = block.get("orbit", {})
	if orbit is Dictionary and not orbit.is_empty():
		ship.input.toggle_orbit = true
	return true


## `value` as a list of `count` finite numbers, or empty when it isn't one.
static func numbers(value: Variant, count: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if not value is Array or value.size() != count:
		return out
	for n: Variant in value:
		if not (n is float or n is int) or not is_finite(float(n)):
			return PackedFloat64Array()
		out.append(float(n))
	return out


## `value` as a Vector3, or zero when it isn't three finite numbers.
static func vector(value: Variant) -> Vector3:
	var n := GameStart.numbers(value, 3)
	return Vector3(n[0], n[1], n[2]) if not n.is_empty() else Vector3.ZERO
