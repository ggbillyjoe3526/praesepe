class_name Upright
extends RefCounted
## Rolling upright (design doc, "How it flies"): R rolls the ship round its nose until its top points away from the
## nearest planet or moon, so that body's ground is below and its horizon level in the cockpit window. Only the roll
## changes: the nose stays where the pilot points it and the mouse still steers meanwhile. It rolls the way a pilot
## would, through the ship's own roll thrusters (the turn it asks for goes into ShipInput.turn), with flight assist on
## or off, and stops once level. Rolling with Q or E takes over at once. With the nose pointing almost straight at the
## body or away from it no roll makes the ship more upright, so it says so instead. Nothing here touches nodes but
## reading where the bodies are, so the unit tests run it directly. Vectors are in world space.

## What happened this tick. `body` is the planet or moon, where there is one.
enum Event {
	NONE,
	ROLLING, ## R pressed: rolling upright.
	LEVEL, ## Upright: done.
	STRAIGHT, ## R pressed with the nose almost straight at the body or away from it: nothing to roll to.
	NOTHING, ## R pressed with no planet or moon in the system.
}

## The nose within this angle (degrees) of straight at the body or away from it leaves nothing to roll to.
const STRAIGHT_ANGLE := 10.0

## How it rolls (ShipTuning: upright_time, upright_tolerance, upright_settled_spin, and the roll's rate and push).
var tuning: ShipTuning
## Every planet and moon in the solar system (SolarSystem.bodies).
var bodies: Array[CelestialBody] = []
## The planet or moon it is rolling level with, while rolling.
var body: CelestialBody = null
var event: Event = Event.NONE
## The planet or moon the last event was about, for its message.
var about: CelestialBody = null


func _init(ship_tuning: ShipTuning) -> void:
	tuning = ship_tuning


func active() -> bool:
	return body != null


## One physics tick: the ship is `at` with attitude `ship_basis`, rolling at `roll_spin` (rad/s, pilot frame: roll
## right). `press` is R this tick; `pilot_roll` is the pilot's own roll (Q or E), which takes over.
func step(ship_basis: Basis, at: Vector3, press: bool, pilot_roll: float, roll_spin: float) -> void:
	event = Event.NONE
	if press:
		var nearest := Upright.nearest(bodies, at)
		about = nearest
		if nearest == null:
			event = Event.NOTHING
			body = null
			return
		body = nearest
		event = Event.ROLLING
		if is_nan(Upright.roll_left(ship_basis, at - body.global_position)):
			event = Event.STRAIGHT
			body = null
		return
	if body == null:
		return
	if pilot_roll != 0.0:
		body = null
		return
	var left := Upright.roll_left(ship_basis, at - body.global_position)
	if is_nan(left):
		# The pilot pointed the nose at the body or away from it: nothing more to roll to.
		body = null
	elif absf(left) < deg_to_rad(tuning.upright_tolerance) and absf(roll_spin) < deg_to_rad(tuning.upright_settled_spin):
		event = Event.LEVEL
		about = body
		body = null


## Stops with no event, as when the ship docks or lands.
func stop() -> void:
	body = null


## The roll (ShipInput.turn.z, -1 to 1) that brings a ship with attitude `ship_basis` at `at`, rolling at `roll_spin`
## (rad/s, pilot frame), upright: as a turn rate with flight assist on (`assist`), as a push on the roll thrusters with
## it off.
func roll_for(ship_basis: Basis, at: Vector3, roll_spin: float, assist: bool) -> float:
	var left := Upright.roll_left(ship_basis, at - body.global_position)
	if is_nan(left):
		return 0.0
	var rate := deg_to_rad(tuning.roll_rate)
	var want := clampf(left / tuning.upright_time, -rate, rate)
	if assist:
		return want / rate
	# Without assist the input pushes the roll thrusters: push toward the wanted rate as assist would.
	var accel := deg_to_rad(tuning.roll_accel)
	return clampf((want - roll_spin) / tuning.assist_turn_response / accel, -1.0, 1.0)


## The planet or moon nearest `at` (to its surface), or null when there is none.
static func nearest(from: Array[CelestialBody], at: Vector3) -> CelestialBody:
	var best: CelestialBody = null
	var best_distance := INF
	for b: CelestialBody in from:
		var d := b.surface_distance(at)
		if d < best_distance:
			best = b
			best_distance = d
	return best


## How far (radians) a ship with attitude `ship_basis` must roll right (negative: left) to be upright against `up` (the
## way out from the body's centre): its top as near `up` as a roll can bring it. NAN when the nose is within
## STRAIGHT_ANGLE of `up` or its opposite.
static func roll_left(ship_basis: Basis, up: Vector3) -> float:
	var local := ship_basis.orthonormalized().transposed() * up.normalized()
	if Vector2(local.x, local.y).length() < sin(deg_to_rad(STRAIGHT_ANGLE)):
		return NAN
	# Rolling right turns the ship's top to the right: toward `up` when `up` is off to the right.
	return atan2(local.x, local.y)
