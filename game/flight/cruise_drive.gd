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
## leaving a station never drops straight back out. It refuses to engage inside something (the asteroid belt, a base's
## buildings) or when the nose points at something close.
##
## Pressing F with the nose aimed at a place (`aimed`, from aim()) locks the drive onto it (`target`): once charged it
## flies there by itself, turning the ship's nose to follow (turn_for()), going round any planet, moon or station in the
## way (course()), and drops out only on arriving there. Moving the mouse, while it charges or cruises, hands the
## steering back (it cruises where the nose points, as without a lock); F or X cancel or drop out as usual. With nothing aimed at, F cruises where the nose points.
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
	BLOCKED_INSIDE, ## Didn't engage: the ship is inside `place` (the asteroid belt, a base).
	ARRIVED, ## Dropped out on arriving at `place`.
	DROPPED, ## Dropped out because the pilot asked.
	SAFETY, ## Dropped out before running into `place`.
	BUMPED, ## Dropped out after a bump.
	UNLOCKED, ## The pilot moved the mouse: no longer locked onto `place`, steered by hand.
}

## How far ahead (s) the drive looks to see whether it is closing on something.
const PROBE_TIME := 0.25
## How far (m) beyond its drop distance the ship must go before a place it left counts for arrival again.
const REARM_MARGIN := 250.0
## Locked on (or charging to), a stick pushed further than this (of a full push, pitch and yaw) hands the steering back
## to the pilot, the same as taking over from the orbit's turn.
const STICK_TAKES_OVER := Orbit.STICK_TAKES_OVER

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
## The place the drive is locked onto while it charges or cruises, or null when it goes where the nose points.
var target: Landmark = null
## While off: the place the nose is aimed at, which F would lock onto, or null.
var aimed: Landmark = null
## A place for the next F to lock onto instead of the aimed one, wherever the nose points: the nav computer
## (NavComputer) sets it with the F it presses for the pilot. Used once.
var wanted: Landmark = null

var _charge_left: float = 0.0
## Per landmark: 1 when arriving there drops the drive out, 0 until the ship has left it.
var _armed: PackedByteArray = PackedByteArray()


func _init(drive_tuning: CruiseTuning) -> void:
	tuning = drive_tuning


func active() -> bool:
	return phase == Phase.CRUISING


## Cruising locked onto `target`, so the drive steers the ship.
func locked() -> bool:
	return phase == Phase.CRUISING and target != null


## How long (s) until the drive finishes charging; zero unless charging.
func charge_left() -> float:
	return _charge_left if phase == Phase.CHARGING else 0.0


## One physics tick: the ship is `at`, moving at `ship_velocity`, its nose pointing `nose` (unit), and it was bumped by
## `jolt` (m/s, Ship.jolt). `toggle` is F this tick, `stop` is X. `steering` is the pilot pushing the stick further
## than STICK_TAKES_OVER, which ends a lock.
func step(at: Vector3, ship_velocity: Vector3, nose: Vector3, toggle: bool, stop: bool, jolt: float,
		delta: float, steering: bool = false) -> void:
	event = Event.NONE
	place = null
	match phase:
		Phase.OFF:
			aimed = CruiseDrive.aim(landmarks, at, nose, tuning.lock_cone)
			if toggle:
				phase = Phase.CHARGING
				_charge_left = tuning.charge_time
				target = wanted if wanted != null else aimed
				wanted = null
				aimed = null
				event = Event.CHARGING
				place = target
		Phase.CHARGING:
			if toggle or stop:
				phase = Phase.OFF
				target = null
				event = Event.CANCELLED
				return
			if target != null and steering:
				# Turning away while it charges: the pilot is choosing somewhere else.
				event = Event.UNLOCKED
				place = target
				target = null
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
				if target != null and steering:
					_unlock(at)
				_cruise(at, nose, delta)


## Off at once with no event, as when the ship docks or lands.
func stop() -> void:
	phase = Phase.OFF
	target = null
	aimed = null
	wanted = null
	speed = 0.0
	velocity = Vector3.ZERO
	nearest = null
	nearest_distance = INF


func _engage(at: Vector3, ship_velocity: Vector3, nose: Vector3) -> void:
	phase = Phase.OFF
	if target != null and target.surface_distance(at) <= target.drop_distance:
		# The ship got there while charging: it has arrived, with nothing left to cruise to.
		event = Event.ARRIVED
		place = target
		target = null
		return
	var heading := nose if target == null else course(at, nose)
	var forward := maxf(ship_velocity.dot(heading), 0.0)
	var probe := heading * maxf(forward, tuning.min_speed)
	# Of everything too close ahead, the one it would reach first is the one the message names.
	var soonest := tuning.engage_look_ahead
	for l: Landmark in landmarks:
		if not l.obstacle:
			continue
		if l.surface_distance(at) <= 0.0:
			event = Event.BLOCKED_INSIDE
			place = l
			target = null
			return
		var reach := time_to_reach(l, at, probe)
		if reach < soonest:
			soonest = reach
			event = Event.BLOCKED
			place = l
	if event == Event.BLOCKED:
		target = null
		return
	if _armed.size() != landmarks.size():
		_armed.resize(landmarks.size())
	for i in landmarks.size():
		_armed[i] = 1 if landmarks[i].surface_distance(at) > landmarks[i].drop_distance else 0
	phase = Phase.CRUISING
	event = Event.ENGAGED
	place = target
	speed = forward
	direction = heading
	velocity = direction * speed


func _cruise(at: Vector3, nose: Vector3, delta: float) -> void:
	var want := nose if target == null else course(at, direction)
	direction = direction.slerp(want, Smoothing.factor(delta, tuning.align_time)).normalized()
	velocity = direction * speed
	nearest = null
	nearest_distance = INF
	for i in landmarks.size():
		var l := landmarks[i]
		var s := l.surface_distance(at)
		if _armed[i] == 0 and s > l.drop_distance + REARM_MARGIN:
			_armed[i] = 1
		# Locked on, only the place it is going to counts: it flies on through the others' arrival zones.
		if _armed[i] == 1 and s < l.drop_distance and (target == null or l == target):
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
	var want_speed := clampf(nearest_distance / tuning.approach_time, tuning.min_speed, tuning.max_speed)
	speed = move_toward(speed, want_speed, maxf(speed, tuning.min_speed) * delta / tuning.ramp_time)
	velocity = direction * speed


## The pilot took the steering back. Places whose zones the ship is flying through on its way count as left behind,
## so taking over there never drops it straight out; they count again once it has left them.
func _unlock(at: Vector3) -> void:
	event = Event.UNLOCKED
	place = target
	target = null
	for i in landmarks.size():
		if landmarks[i].surface_distance(at) < landmarks[i].drop_distance:
			_armed[i] = 0


func _drop(why: Event, at_place: Landmark, keep: float) -> void:
	phase = Phase.OFF
	target = null
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


## Locked on, the turn (ShipInput.turn) that brings the nose of a ship whose attitude is `ship_basis` round to the way
## it is going, closing the angle in CruiseTuning.lock_turn_time as a share of the full-stick `rates`; `roll` is the
## pilot's own roll, which the lock leaves alone.
func turn_for(ship_basis: Basis, roll: float, rates: Vector3) -> Vector3:
	return CruiseDrive.turn_towards(ship_basis, direction, roll, rates, tuning.lock_turn_time)


## The turn (ShipInput.turn) that brings the nose of a ship whose attitude is `ship_basis` round to `way` (world space),
## closing the angle in `time` seconds as a share of the full-stick `rates`, with `roll` as given.
static func turn_towards(ship_basis: Basis, way: Vector3, roll: float, rates: Vector3, time: float) -> Vector3:
	var local := ship_basis.inverse() * way
	var yaw := atan2(local.x, -local.z)
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	return Vector3(clampf(pitch / (rates.x * time), -1.0, 1.0), clampf(yaw / (rates.y * time), -1.0, 1.0), roll)


## Which way (unit) a ship at `at` locked onto `target` goes: straight at its marker, unless a planet, moon or station
## is in the way, then round the nearest such along the shortest way, CruiseTuning.clearance above it, until the way
## is clear. A place on a planet's surface (a base) is in the planet's way while the ship sees it lower than
## CruiseTuning.approach_angle over its horizon, so the drive goes round to come down at it from above. `fallback` is
## the way to go when the ship is at the marker already.
func course(at: Vector3, fallback: Vector3) -> Vector3:
	return course_to(target, at, fallback)


## The way (unit) course() would go to `to`, for a ship at `at` (the nav computer lines the nose up with it before
## starting the drive).
func course_to(to: Landmark, at: Vector3, fallback: Vector3) -> Vector3:
	var goal := to.marker_position()
	var to_goal := goal - at
	var length := to_goal.length()
	if length < 1.0:
		return fallback
	var straight := to_goal / length
	var way := straight
	var first := INF
	var low := sin(deg_to_rad(tuning.approach_angle))
	for l: Landmark in landmarks:
		if l == to or not l.obstacle or l.radius <= 0.0:
			continue
		var centre := l.global_position
		var r := l.radius + maxf(l.drop_distance, l.radius * tuning.clearance)
		var along := (centre - at).dot(straight)
		var aim := goal
		var blocked := false
		var up := goal - centre
		if up.length_squared() < r * r:
			# The place is within this one's clearance: on it or close by. Clear once seen high enough over its horizon.
			up = up.normalized() if up.length_squared() > 1.0 else Vector3.UP
			aim = centre + up * r
			blocked = -straight.dot(up) < low
		else:
			blocked = along > 0.0 and along < length and (at + straight * along).distance_squared_to(centre) < r * r
		if blocked and along < first:
			first = along
			way = CruiseDrive.round_sphere(at, centre, r, aim)
	return way


## The way (unit) from `at` round a sphere of radius `r` at `centre` toward `aim`: along the line that just touches the
## sphere on the side `aim` is, or, inside the sphere, along it while climbing back out.
static func round_sphere(at: Vector3, centre: Vector3, r: float, aim: Vector3) -> Vector3:
	var out := at - centre
	var d := out.length()
	var radial := out / d if d > 1.0e-3 else Vector3.UP
	var want := aim - at
	var side := want - radial * want.dot(radial)
	if side.length_squared() < 1.0e-6:
		# Straight through the middle: either way round is as short.
		side = radial.cross(Vector3.UP if absf(radial.y) < 0.9 else Vector3.RIGHT)
	side = side.normalized()
	if d <= r:
		return (side + radial * (1.0 - d / r)).normalized()
	var s := r / d
	return (side * s - radial * sqrt(1.0 - s * s)).normalized()


## The place a ship at `at` with its nose along `nose` (unit) is aimed at, which F would lock onto, of the places with
## a marker that it isn't already at (inside the arrival zone): the one whose marker is nearest the nose, within
## `cone_degrees` of it; failing that, the planet or moon whose disc the nose is on (the nearest middle, as a share of
## its disc). So a base wins over its planet near the base's marker. Null when nothing is aimed at.
static func aim(places: Array[Landmark], at: Vector3, nose: Vector3, cone_degrees: float) -> Landmark:
	var best: Landmark = null
	# Markers in the cone score 0 to 1, discs 1 to 2: lowest wins.
	var best_score := 2.0
	var cone := deg_to_rad(cone_degrees)
	for l: Landmark in places:
		if not l.marker or l.surface_distance(at) <= l.drop_distance:
			continue
		var to := l.marker_position() - at
		var d := to.length()
		if d < 1.0:
			continue
		var angle := nose.angle_to(to)
		var score := angle / cone
		if score > 1.0:
			var disc := atan2(l.radius, d)
			score = 1.0 + angle / disc if disc > 0.0 and angle < disc else INF
		if score < best_score or (score == best_score and best != null and l.radius < best.radius):
			best = l
			best_score = score
	return best
