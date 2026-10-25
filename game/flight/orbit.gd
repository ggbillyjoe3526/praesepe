class_name Orbit
extends RefCounted
## Parking in orbit (design doc, "Orbit"): near a planet or moon the pilot presses O and the ship settles into a steady
## circle round it, staying there as long as they like. It is not a simulation (the game has no gravity): like the
## cruise drive it is a mode that sets the ship's velocity every physics tick, along the circle at the body's orbit
## speed plus a gentle climb or sink to the orbit's height. The ship's attitude turns with the orbit (`spin`), so a
## view of the planet below stays put while the ground slides past; the mouse still turns the ship within that.
##
## Each planet and moon has one orbit line, up in space at its orbit height (CelestialBody.orbit_altitude). Within
## OrbitTuning.guide_reach of it the orbit shows the way there: the line round the body in the plane the ship would go
## round in (`guide_axis`, the way the ship is heading), and an insertion point on it ahead (`insertion`), as far along
## as a gentle climb or descent would take to reach it. Entering is offered only close to the line (within
## CelestialBody.orbit_window above or below), never near the surface; the orbit then runs the way the ship was
## heading, and the ship settles onto the line.
## Entering, the ship's velocity swings onto the circle no faster than OrbitTuning.entry_accel, and the ship turns to
## face along it with the planet below, unless the pilot moves the mouse. O again or a thrust key leaves orbit gently:
## the ship carries straight on at the velocity it had while its nose comes up level along it
## (OrbitTuning.level_time), then flight assist holds that velocity, so nothing lurches and the ship climbs slowly away
## from the planet rather than following its dipped nose down. X, Z or the cruise drive taking over leave at once, as
## does moving the mouse while it levels out. A hard bump knocks it out. Nothing here touches nodes but reading where
## the bodies are, so the unit tests run it directly. Vectors are in world space.

enum Phase { OFF, ENTERING, ORBITING, LEAVING }
## What happened this tick. `body` is the planet or moon, where there is one.
enum Event {
	NONE,
	ENTERING, ## O pressed: swinging onto the orbit.
	SETTLED, ## In orbit at its height.
	LEAVING, ## O or thrust: levelling out before leaving.
	LEFT, ## Left orbit because the pilot did something else.
	BUMPED, ## Knocked out of orbit.
	REFUSED, ## O pressed, but no orbit is offered here (`refusal` says why; no `body` when none is near).
}
## Why entering orbit isn't offered now.
enum Refusal {
	NONE,
	TOO_FAST, ## Faster than OrbitTuning.max_entry_speed.
	TOO_STEEP, ## Climbing or diving too fast to level out before leaving the orbit's window.
	FAR, ## No planet or moon near enough.
	TOO_LOW, ## Below the orbit line's window: climb `to_climb` metres to the line.
	TOO_HIGH, ## Above it: descend.
}

## A stick pushed further than this (of a full push) while the ship turns to face along the orbit hands the view
## back to the pilot.
const STICK_TAKES_OVER := 0.15
## Slower than this (m/s), the ship's motion says nothing about which way it is heading.
const BARELY_MOVING := 1.0
## A direction with less than this (of its length) left after levelling was straight up or down.
const NEARLY_STRAIGHT := 0.01
## Heading this close to straight up or down (share of its length left after levelling, about 6 degrees), the orbit
## goes round the way the nose points instead, so a ship climbing straight up still has a steady orbit to aim for.
const NEARLY_UPRIGHT := 0.1

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
## Out of orbit: the nearest planet or moon close enough to show its orbit line, or null, and whether its orbit can
## be entered now.
var offered: CelestialBody = null
var refusal: Refusal = Refusal.FAR
## With an orbit offered: the axis (unit) the ship would go round, the insertion point on the orbit line (m from the
## body's centre, so a floating origin shift never leaves it behind), and how far (m) the line is above the ship
## (below it when negative).
var guide_axis: Vector3 = Vector3.UP
var insertion: Vector3 = Vector3.ZERO
var to_climb: float = 0.0
## Leaving: the attitude the ship levels out to, how long (s) it had been at it when this tick began, and how long it
## takes (OrbitTuning.level_time, or longer for a turn too big to make that fast within the ship's turn rates).
var _level_to: Basis = Basis.IDENTITY
var _levelled_for: float = 0.0
var _level_time: float = 0.0
var _level_sized: bool = false
## Leaving: the pilot moved the stick, so the ship is theirs from the next tick.
var _handed_over: bool = false


func _init(orbit_tuning: OrbitTuning) -> void:
	tuning = orbit_tuning


func active() -> bool:
	return phase != Phase.OFF


func settled() -> bool:
	return phase == Phase.ORBITING


## One physics tick: the ship is `at`, moving at `ship_velocity`, its nose pointing `nose` (unit). `toggle` is O this
## tick; `leave` is a thrust key, which leaves orbit by levelling out first, like O; `drop` is anything that leaves it
## at once (X, Z, the cruise drive engaging); `jolt` is how hard it was bumped (m/s, Ship.jolt). `can_enter` is false
## while cruising.
func step(at: Vector3, ship_velocity: Vector3, nose: Vector3, toggle: bool, leave: bool, drop: bool, jolt: float,
		can_enter: bool, delta: float) -> void:
	event = Event.NONE
	if phase == Phase.OFF:
		_offer(at, ship_velocity, nose, can_enter)
		if toggle:
			if refusal == Refusal.NONE:
				_enter(at, ship_velocity, nose, delta)
			else:
				event = Event.REFUSED
		return
	if drop:
		_leave(Event.LEFT)
	elif jolt > tuning.bump_limit:
		_leave(Event.BUMPED)
	elif phase == Phase.LEAVING:
		_levelled_for += delta
		# Level since the last tick's turn (level_spin), or the pilot's to fly.
		if _handed_over or _levelled_for > _level_time - delta * 0.5:
			_leave(Event.LEFT)
	elif toggle or leave:
		_level_out(at, ship_velocity)
	else:
		_hold(at, ship_velocity, delta)


## Out of orbit with no event, as when the ship docks or lands.
func stop() -> void:
	phase = Phase.OFF
	body = null
	turning = false
	_handed_over = false
	spin = Vector3.ZERO
	offered = null
	refusal = Refusal.FAR


## The velocity the orbit wants for a ship at `at`: along the circle at the body's orbit speed, climbing or sinking
## toward the orbit line and back into its plane.
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
## the pilot leaves the stick alone, it steers, all the way while the ship climbs or sinks onto the line (the
## horizon's dip changes with height); once lined up in orbit, or once the pilot pushes the stick, the pilot's turn is
## used as it is.
func turn_for(ship_basis: Basis, at: Vector3, pilot_turn: Vector3, rates: Vector3) -> Vector3:
	if phase == Phase.LEAVING and pilot_turn.length() > STICK_TAKES_OVER:
		_handed_over = true
	if not turning:
		return pilot_turn
	if pilot_turn.length() > STICK_TAKES_OVER:
		turning = false
		return pilot_turn
	var target := facing(at)
	if phase != Phase.ENTERING and Orbit.lined_up(ship_basis, target, deg_to_rad(tuning.turn_tolerance)):
		turning = false
		return pilot_turn
	return Orbit.steer(ship_basis, target, rates, tuning.turn_time)


## While leaving, the spin (rad/s, world space) that turns a ship whose attitude is `ship_basis` to level out along its
## velocity this tick: easing in and out, so it is level just as the level-out's time runs out. The first tick sizes
## that time so the turn is never faster than the slowest of the full-stick `rates` (rad/s).
func level_spin(ship_basis: Basis, rates: Vector3, delta: float) -> Vector3:
	if phase != Phase.LEAVING:
		return Vector3.ZERO
	var turn := Orbit.rotation_of(Quaternion(_level_to * ship_basis.orthonormalized().inverse()))
	var angle := turn.length()
	if not _level_sized:
		_level_sized = true
		# Easing in and out, the turn is fastest halfway, at 1.5 times its average rate.
		_level_time = maxf(tuning.level_time, 1.5 * angle / minf(rates.x, minf(rates.y, rates.z)))
	if angle < 1.0e-6:
		return Vector3.ZERO
	var before := smoothstep(0.0, 1.0, _levelled_for / _level_time)
	var after := smoothstep(0.0, 1.0, (_levelled_for + delta) / _level_time)
	# The share of the turn still to go that this tick covers.
	var share := 1.0 if before >= 1.0 else (after - before) / (1.0 - before)
	return turn * share / delta


## The turn that brings `from` round to `to`: a rate on each axis that would close its angle in `time` seconds, as a
## share of the full-stick `rates`. Worked out from the one rotation between them, so a big turn (nose down at the
## planet, wings level with the old heading) goes the short way round without the axes fighting each other.
static func steer(from: Basis, to: Basis, rates: Vector3, time: float) -> Vector3:
	var turn := Orbit.rotation_of(Quaternion(from.transposed() * to))
	# In the ship's own axes: pitch up is about +x, yaw right about -y, roll right about -z.
	var want := Vector3(turn.x, -turn.y, -turn.z) / time
	return Vector3(clampf(want.x / rates.x, -1.0, 1.0), clampf(want.y / rates.y, -1.0, 1.0),
			clampf(want.z / rates.z, -1.0, 1.0))


## The axis (unit) an orbit round a body would go round, for a ship `out` (unit) from its centre, moving at
## `ship_velocity` with its nose pointing `nose` (unit): the way it is moving, or the way its nose points when it is
## barely moving or heading nearly straight up or down; a ship pointing straight at the body too goes round its
## equator.
static func plane_axis(out: Vector3, ship_velocity: Vector3, nose: Vector3) -> Vector3:
	var along := Vector3.ZERO
	if ship_velocity.length() > BARELY_MOVING:
		along = Orbit._level(ship_velocity.normalized(), out)
	if along.length() < NEARLY_UPRIGHT:
		along = Orbit._level(nose, out)
	if along.length() < NEARLY_STRAIGHT:
		along = Orbit._level(Vector3.FORWARD if absf(out.y) > 0.9 else Vector3.UP.cross(out), out)
	return out.cross(along.normalized()).normalized()


## The rotation `q` as its axis times its angle (rad), the short way round. Exact for small turns too, where
## Quaternion.get_axis() stops normalising (under about half a degree) and would all but stop a steer short.
static func rotation_of(q: Quaternion) -> Vector3:
	q = q.normalized()
	if q.w < 0.0:
		q = -q
	var v := Vector3(q.x, q.y, q.z)
	var s := v.length()
	if s < 1.0e-9:
		return Vector3.ZERO
	return v / s * 2.0 * atan2(s, q.w)


## Whether `a` and `b` face the same way, tops and noses within `tolerance` radians.
static func lined_up(a: Basis, b: Basis, tolerance: float) -> bool:
	return a.z.angle_to(b.z) < tolerance and a.y.angle_to(b.y) < tolerance


func _offer(at: Vector3, ship_velocity: Vector3, nose: Vector3, can_enter: bool) -> void:
	offered = null
	refusal = Refusal.FAR
	if not can_enter:
		return
	var nearest := INF
	for b: CelestialBody in bodies:
		var h := b.surface_distance(at)
		if h <= b.orbit_altitude * tuning.guide_reach and h < nearest:
			nearest = h
			offered = b
	if offered == null:
		return
	var out := (at - offered.global_position).normalized()
	var line := offered.orbit_radius()
	to_climb = offered.orbit_altitude - nearest
	guide_axis = Orbit.plane_axis(out, ship_velocity, nose)
	# Ahead along the orbit, as far as a climb (or descent) at insertion_climb would take to reach the line.
	var lead := maxf(absf(to_climb) / tan(deg_to_rad(tuning.insertion_climb)), tuning.insertion_lead)
	var ahead := minf(lead / line, PI * 0.5)
	insertion = (out * cos(ahead) + guide_axis.cross(out) * sin(ahead)) * line
	if to_climb > offered.orbit_window:
		refusal = Refusal.TOO_LOW
		return
	if to_climb < -offered.orbit_window:
		refusal = Refusal.TOO_HIGH
		return
	refusal = Refusal.NONE
	if ship_velocity.length() > tuning.max_entry_speed:
		refusal = Refusal.TOO_FAST
		return
	# The swing onto the orbit must stop a climb or a dive before it carries the ship out of the window.
	var rising := ship_velocity.dot(out)
	var overshoot := rising * absf(rising) / (2.0 * tuning.entry_accel)
	if absf(overshoot - to_climb) > offered.orbit_window:
		refusal = Refusal.TOO_STEEP


func _enter(at: Vector3, ship_velocity: Vector3, nose: Vector3, delta: float) -> void:
	body = offered
	axis = Orbit.plane_axis((at - body.global_position).normalized(), ship_velocity, nose)
	radius = body.orbit_radius()
	phase = Phase.ENTERING
	turning = true
	event = Event.ENTERING
	offered = null
	_hold(at, ship_velocity, delta)


func _hold(at: Vector3, ship_velocity: Vector3, delta: float) -> void:
	var r := at - body.global_position
	var d := r.length()
	var target := orbit_velocity(at)
	if phase == Phase.ENTERING:
		velocity = ship_velocity.move_toward(target, tuning.entry_accel * delta)
		if velocity.distance_to(target) < 0.01 and absf(d - radius) < tuning.settle_tolerance:
			phase = Phase.ORBITING
			event = Event.SETTLED
	else:
		velocity = target
	spin = axis * (velocity.dot(axis.cross(r / d).normalized()) / d)


## Starts leaving: the ship carries straight on at `ship_velocity`, no longer turning with the orbit, and levels out
## along it with the planet below. A ship barely moving, or moving straight up or down, leaves at once.
func _level_out(at: Vector3, ship_velocity: Vector3) -> void:
	var out := (at - body.global_position).normalized()
	var forward := ship_velocity.normalized()
	var up := Orbit._level(out, forward)
	if ship_velocity.length() < BARELY_MOVING or up.length() < NEARLY_STRAIGHT:
		_leave(Event.LEFT)
		return
	up = up.normalized()
	_level_to = Basis(forward.cross(up), up, -forward)
	_levelled_for = 0.0
	_level_time = tuning.level_time
	_level_sized = false
	_handed_over = false
	phase = Phase.LEAVING
	event = Event.LEAVING
	turning = false
	velocity = ship_velocity
	spin = Vector3.ZERO


func _leave(why: Event) -> void:
	phase = Phase.OFF
	event = why
	turning = false
	_handed_over = false
	spin = Vector3.ZERO


## `v` with its part along `out` (unit) taken away.
static func _level(v: Vector3, out: Vector3) -> Vector3:
	return v - out * v.dot(out)
