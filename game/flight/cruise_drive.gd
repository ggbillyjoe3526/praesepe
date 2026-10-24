class_name CruiseDrive
extends RefCounted
## The cruise drive (design doc, "Cruise drive"): fast travel between the places in the solar system, worked out each
## physics tick like the flight model, with no nodes of its own so the unit tests run it directly.
##
## F starts it charging; after CruiseTuning.charge_time it takes over the ship's speed, going wherever the nose points.
## Its speed is the distance to the nearest surface over approach_time, from min_speed up to max_speed, so it is fast
## in open space and slows down smoothly on the way in. It drops out by itself on arriving at a place (inside the
## place's Landmark.drop_distance), and also before it could hit anything or after a bump. F (or X) drops out at once.
## Places the ship is already at when the drive engages don't count as arrivals until the ship has left them, so
## leaving a station never drops straight back out. It refuses to engage inside something (the asteroid belt) or when
## the nose points at something close.
##
## Vectors are in world space. Each step() fills `velocity` (the ship's velocity this tick while cruising, and the
## velocity to leave it with on the tick it drops out) and `event` (what happened, for messages).

enum Phase { OFF, CHARGING, CRUISING }
## What happened this tick. `place` is the Landmark it happened at, where there is one.
enum Event {
	NONE,
	CHARGING, ## F pressed: charging.
	CANCELLED, ## F or X pressed while charging.
	ENGAGED, ## Took over the ship's speed.
	BLOCKED, ## Didn't engage: the nose points at `place`, too close.
	BLOCKED_INSIDE, ## Didn't engage: the ship is inside `place` (the asteroid belt).
	ARRIVED, ## Dropped out on arriving at `place`.
	DROPPED, ## Dropped out because the pilot asked.
	SAFETY, ## Dropped out before running into `place`.
	BUMPED, ## Dropped out after a bump.
}

## How far ahead (s) the drive looks to see whether it is closing on something.
const PROBE_TIME := 0.25
## How far (m) beyond its drop distance the ship must go before a place it left counts for arrival again.
const REARM_MARGIN := 250.0

var tuning: CruiseTuning
## Every place in the solar system (SolarSystem.landmarks).
var landmarks: Array[Landmark] = []
var phase: Phase = Phase.OFF
## The drive's speed (m/s) while cruising.
var speed: float = 0.0
## Which way it is travelling (unit vector) while cruising.
var direction: Vector3 = Vector3.FORWARD
## See the class description.
var velocity: Vector3 = Vector3.ZERO
## The forward speed (m/s) flight assist should hold after this tick's drop-out.
var exit_speed: float = 0.0
var event: Event = Event.NONE
var place: Landmark = null
## The closest thing to fly into while cruising, and how far (m) its surface is.
var nearest: Landmark = null
var nearest_distance: float = INF

var _charge_left: float = 0.0
## Per landmark: 1 when arriving there drops the drive out, 0 until the ship has left it.
var _armed: PackedByteArray = PackedByteArray()


func _init(drive_tuning: CruiseTuning) -> void:
	tuning = drive_tuning


func active() -> bool:
	return phase == Phase.CRUISING


## How long (s) until the drive finishes charging; zero unless charging.
func charge_left() -> float:
	return _charge_left if phase == Phase.CHARGING else 0.0


## One physics tick: the ship is `at`, moving at `ship_velocity`, its nose pointing `nose` (unit), and it was bumped by
## `jolt` (m/s, Ship.jolt). `toggle` is F this tick, `stop` is X.
func step(at: Vector3, ship_velocity: Vector3, nose: Vector3, toggle: bool, stop: bool, jolt: float,
		delta: float) -> void:
	event = Event.NONE
	place = null
	match phase:
		Phase.OFF:
			if toggle:
				phase = Phase.CHARGING
				_charge_left = tuning.charge_time
				event = Event.CHARGING
		Phase.CHARGING:
			if toggle or stop:
				phase = Phase.OFF
				event = Event.CANCELLED
				return
			_charge_left -= delta
			if _charge_left <= 0.0:
				_engage(at, ship_velocity, nose)
		Phase.CRUISING:
			if toggle or stop:
				_drop(Event.DROPPED, null, tuning.exit_speed)
			elif jolt > tuning.bump_limit:
				_drop(Event.BUMPED, null, tuning.safety_exit_speed)
				# The bump already set the ship's course: only slow it down, then let flight assist bring it to rest
				# rather than push it back into whatever it hit.
				velocity = ship_velocity.limit_length(exit_speed)
				exit_speed = 0.0
			else:
				_cruise(at, nose, delta)


func _engage(at: Vector3, ship_velocity: Vector3, nose: Vector3) -> void:
	phase = Phase.OFF
	var forward := maxf(ship_velocity.dot(nose), 0.0)
	var probe := nose * maxf(forward, tuning.min_speed)
	for l: Landmark in landmarks:
		if not l.obstacle:
			continue
		if l.surface_distance(at) <= 0.0:
			event = Event.BLOCKED_INSIDE
			place = l
			return
		if time_to_reach(l, at, probe) < tuning.safety_time * 2.0:
			event = Event.BLOCKED
			place = l
			return
	if _armed.size() != landmarks.size():
		_armed.resize(landmarks.size())
	for i in landmarks.size():
		_armed[i] = 1 if landmarks[i].surface_distance(at) > landmarks[i].drop_distance else 0
	phase = Phase.CRUISING
	event = Event.ENGAGED
	speed = forward
	direction = nose
	velocity = direction * speed


func _cruise(at: Vector3, nose: Vector3, delta: float) -> void:
	direction = direction.slerp(nose, Smoothing.factor(delta, tuning.align_time)).normalized()
	velocity = direction * speed
	nearest = null
	nearest_distance = INF
	for i in landmarks.size():
		var l := landmarks[i]
		var s := l.surface_distance(at)
		if _armed[i] == 0 and s > l.drop_distance + REARM_MARGIN:
			_armed[i] = 1
		if _armed[i] == 1 and s < l.drop_distance:
			_drop(Event.ARRIVED, l, tuning.exit_speed)
			return
		if not l.obstacle:
			continue
		if s < nearest_distance:
			nearest = l
			nearest_distance = s
		if time_to_reach(l, at, velocity) < tuning.safety_time:
			_drop(Event.SAFETY, l, tuning.safety_exit_speed)
			return
	var target := clampf(nearest_distance / tuning.approach_time, tuning.min_speed, tuning.max_speed)
	speed = move_toward(speed, target, maxf(speed, tuning.min_speed) * delta / tuning.ramp_time)
	velocity = direction * speed


func _drop(why: Event, at_place: Landmark, keep: float) -> void:
	phase = Phase.OFF
	event = why
	place = at_place
	exit_speed = minf(speed, keep)
	velocity = direction * exit_speed
	speed = 0.0
	nearest = null
	nearest_distance = INF


## How long (s) until a ship at `at` moving at `moving` reaches `l`'s surface, judged from how fast it is closing on it
## now; INF when it isn't closing.
static func time_to_reach(l: Landmark, at: Vector3, moving: Vector3) -> float:
	var now := l.surface_distance(at)
	var closing := (now - l.surface_distance(at + moving * PROBE_TIME)) / PROBE_TIME
	return now / closing if closing > 0.0 else INF
