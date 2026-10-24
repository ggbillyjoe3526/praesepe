class_name Orbit
extends RefCounted
## Parking in orbit (design doc, "Orbit"): near a planet or moon the pilot presses O and the ship settles into a steady
## circle round it, staying there as long as they like. It is not a simulation (the game has no gravity): like the
## cruise drive it is a mode that sets the ship's velocity every physics tick, along the circle at the body's orbit
## speed plus a gentle climb or sink to the orbit's height. The ship's attitude turns with the orbit (`spin`), so a
## view of the planet below stays put while the ground slides past; the mouse still turns the ship within that.
##
## The orbit runs the way the ship was heading, at the height where it levels out (kept within the body's orbit
## heights).
## Entering, the ship's velocity swings onto the circle no faster than OrbitTuning.entry_accel, and the ship turns to
## face along it with the planet below, unless the pilot moves the mouse. O again, a thrust key, X, Z or the cruise
## drive taking over leaves orbit: the ship keeps the velocity it had and flight assist holds it, so nothing lurches.
## A hard bump knocks it out. Nothing here touches nodes but reading where the bodies are, so the unit tests run it
## directly. Vectors are in world space.

enum Phase { OFF, ENTERING, ORBITING }
## What happened this tick. `body` is the planet or moon, where there is one.
enum Event {
	NONE,
	ENTERING, ## O pressed: swinging onto the orbit.
	SETTLED, ## In orbit at its height.
	LEFT, ## Left orbit because the pilot did something else.
	BUMPED, ## Knocked out of orbit.
	REFUSED, ## O pressed, but no orbit is offered here (`refusal` says why; no `body` when none is near).
}
## Why entering orbit isn't offered now.
enum Refusal {
	NONE,
	TOO_FAST, ## Faster than OrbitTuning.max_entry_speed.
	TOO_STEEP, ## Heading down too fast to level out above the surface.
	FAR, ## No planet or moon near enough.
}

## A stick pushed further than this (of a full push) while the ship turns to face along the orbit hands the view
## back to the pilot.
const STICK_TAKES_OVER := 0.15

var tuning: OrbitTuning
## Every planet and moon in the solar system (SolarSystem.bodies).
var bodies: Array[CelestialBody] = []
var phase: Phase = Phase.OFF
## The planet or moon orbited, while in orbit.
var body: CelestialBody = null
## The orbit's axis (unit): the ship goes round it the way a right-handed screw turns.
var axis: Vector3 = Vector3.UP
## The orbit's distance (m) from the body's centre.
var radius: float = 0.0
## The ship's velocity this tick while in orbit.
var velocity: Vector3 = Vector3.ZERO
## How fast (rad/s, world space) the orbit's frame turns, which the ship's attitude turns with.
var spin: Vector3 = Vector3.ZERO
## Still turning the ship to face along the orbit.
var turning: bool = false
var event: Event = Event.NONE
## Out of orbit: the nearest planet or moon close enough to orbit, or null, and whether it can be entered now.
var offered: CelestialBody = null
var refusal: Refusal = Refusal.FAR


func _init(orbit_tuning: OrbitTuning) -> void:
	tuning = orbit_tuning


func active() -> bool:
	return phase != Phase.OFF


func settled() -> bool:
	return phase == Phase.ORBITING


## One physics tick: the ship is `at`, moving at `ship_velocity`, its nose pointing `nose` (unit). `toggle` is O this
## tick; `leave` is anything else the pilot did that leaves orbit (thrust, X, Z, the cruise drive engaging); `jolt` is
## how hard it was bumped (m/s, Ship.jolt). `can_enter` is false while cruising.
func step(at: Vector3, ship_velocity: Vector3, nose: Vector3, toggle: bool, leave: bool, jolt: float,
		can_enter: bool, delta: float) -> void:
	event = Event.NONE
	if phase == Phase.OFF:
		_offer(at, ship_velocity, can_enter)
		if toggle:
			if refusal == Refusal.NONE:
				_enter(at, ship_velocity, nose, delta)
			else:
				event = Event.REFUSED
		return
	if toggle or leave:
		_leave(Event.LEFT)
	elif jolt > tuning.bump_limit:
		_leave(Event.BUMPED)
	else:
		_hold(at, ship_velocity, delta)


## Out of orbit with no event, as when the ship docks or lands.
func stop() -> void:
	phase = Phase.OFF
	body = null
	turning = false
	spin = Vector3.ZERO
	offered = null
	refusal = Refusal.FAR


## The velocity the orbit wants for a ship at `at`: along the circle at the body's orbit speed, climbing or sinking
## toward the orbit's height and back into its plane.
func orbit_velocity(at: Vector3) -> Vector3:
	var r := at - body.global_position
	var d := r.length()
	var out := r / d
	var climb := clampf((radius - d) / tuning.settle_time, -tuning.max_climb, tuning.max_climb)
	var off_plane := clampf(r.dot(axis) / tuning.settle_time, -tuning.max_climb, tuning.max_climb)
	return axis.cross(out).normalized() * body.orbit_speed + out * climb - axis * off_plane


## The attitude the ship turns to on entering, for a ship at `at`: facing along the orbit, the planet below, the nose
## dipped so the horizon sits OrbitTuning.horizon_above over the middle of the view.
func facing(at: Vector3) -> Basis:
	var r := at - body.global_position
	var d := r.length()
	var out := r / d
	var along := axis.cross(out).normalized()
	# The horizon is this far below level, seen from height d - radius.
	var dip := acos(clampf(body.radius / d, -1.0, 1.0))
	var down := clampf(dip + deg_to_rad(tuning.horizon_above), 0.0, PI * 0.5)
	var forward := along * cos(down) - out * sin(down)
	var up := out * cos(down) + along * sin(down)
	return Basis(forward.cross(up), up, -forward)


## The turn (pilot frame, each axis -1 to 1) for a ship whose attitude is `ship_basis`, with full-stick turn rates
## `rates` (rad/s), given the pilot's own `pilot_turn`. While the orbit is still turning the ship to face along it and
## the pilot leaves the stick alone, it steers; once lined up, or once the pilot pushes the stick, the pilot's turn is
## used as it is.
func turn_for(ship_basis: Basis, at: Vector3, pilot_turn: Vector3, rates: Vector3) -> Vector3:
	if not turning:
		return pilot_turn
	if pilot_turn.length() > STICK_TAKES_OVER:
		turning = false
		return pilot_turn
	var target := facing(at)
	if Orbit.lined_up(ship_basis, target, deg_to_rad(tuning.turn_tolerance)):
		turning = false
		return pilot_turn
	return Orbit.steer(ship_basis, target, rates, tuning.turn_time)


## The turn that brings `from` round to `to`: a rate on each axis that would close its angle in `time` seconds, as a
## share of the full-stick `rates`. Worked out from the one rotation between them, so a big turn (nose down at the
## planet, wings level with the old heading) goes the short way round without the axes fighting each other.
static func steer(from: Basis, to: Basis, rates: Vector3, time: float) -> Vector3:
	var q := Quaternion(from.transposed() * to).normalized()
	if q.w < 0.0:
		q = -q
	var angle := q.get_angle()
	var turn := q.get_axis() * angle if angle > 1.0e-6 else Vector3.ZERO
	# In the ship's own axes: pitch up is about +x, yaw right about -y, roll right about -z.
	var want := Vector3(turn.x, -turn.y, -turn.z) / time
	return Vector3(clampf(want.x / rates.x, -1.0, 1.0), clampf(want.y / rates.y, -1.0, 1.0),
			clampf(want.z / rates.z, -1.0, 1.0))


## Whether `a` and `b` face the same way, tops and noses within `tolerance` radians.
static func lined_up(a: Basis, b: Basis, tolerance: float) -> bool:
	return a.z.angle_to(b.z) < tolerance and a.y.angle_to(b.y) < tolerance


func _offer(at: Vector3, ship_velocity: Vector3, can_enter: bool) -> void:
	offered = null
	refusal = Refusal.FAR
	if not can_enter:
		return
	var nearest := INF
	for b: CelestialBody in bodies:
		var h := b.surface_distance(at)
		if h <= b.orbit_max_altitude and h < nearest:
			nearest = h
			offered = b
	if offered == null:
		return
	refusal = Refusal.NONE
	if ship_velocity.length() > tuning.max_entry_speed:
		refusal = Refusal.TOO_FAST
		return
	# Heading down: the swing onto the orbit must stop the fall before the surface.
	var sinking := -ship_velocity.dot((at - offered.global_position).normalized())
	if sinking > 0.0 and nearest - sinking * sinking / (2.0 * tuning.entry_accel) < tuning.entry_clearance:
		refusal = Refusal.TOO_STEEP


func _enter(at: Vector3, ship_velocity: Vector3, nose: Vector3, delta: float) -> void:
	body = offered
	var r := at - body.global_position
	var out := r.normalized()
	# Round the way the ship is heading: its motion, or its nose when it is barely moving or heading straight up or
	# down; a ship pointing straight at the body too goes round its equator.
	var along := Orbit._level(ship_velocity if ship_velocity.length() > 1.0 else nose, out)
	if along.length() < 0.01:
		along = Orbit._level(nose, out)
	if along.length() < 0.01:
		along = Orbit._level(Vector3.FORWARD if absf(out.y) > 0.9 else Vector3.UP.cross(out), out)
	axis = out.cross(along.normalized()).normalized()
	radius = clampf(r.length(), body.radius + body.orbit_min_altitude, body.radius + body.orbit_max_altitude)
	phase = Phase.ENTERING
	turning = true
	event = Event.ENTERING
	offered = null
	_hold(at, ship_velocity, delta)


func _hold(at: Vector3, ship_velocity: Vector3, delta: float) -> void:
	var r := at - body.global_position
	var d := r.length()
	if phase == Phase.ENTERING:
		# Until the swing is over, the orbit's height is wherever the ship has levelled out (within the body's orbit
		# heights), so a ship coming in steeply settles a little lower rather than diving and climbing back.
		radius = clampf(d, body.radius + body.orbit_min_altitude, body.radius + body.orbit_max_altitude)
	var target := orbit_velocity(at)
	if phase == Phase.ENTERING:
		velocity = ship_velocity.move_toward(target, tuning.entry_accel * delta)
		if velocity.distance_to(target) < 0.01 and absf(d - radius) < tuning.settle_tolerance:
			phase = Phase.ORBITING
			event = Event.SETTLED
	else:
		velocity = target
	spin = axis * (velocity.dot(axis.cross(r / d).normalized()) / d)


func _leave(why: Event) -> void:
	phase = Phase.OFF
	event = why
	turning = false
	spin = Vector3.ZERO


## `v` with its part along `out` (unit) taken away.
static func _level(v: Vector3, out: Vector3) -> Vector3:
	return v - out * v.dot(out)
