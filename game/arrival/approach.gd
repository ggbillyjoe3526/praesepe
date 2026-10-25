class_name Approach
extends RefCounted
## The way in to a port (design doc, "How docking and landing work"): with no fade or loading screen, the ship flies
## itself to its berth in real time, and the pilot watches from the cockpit or the chase camera. Arrivals runs it once
## G is pressed and hands its velocity and spin to the ship each tick (Ship.guide).
##
## The way in has two legs. First the ship flies to the port's gate (Port.gate): out in front of the bay's mouth, or
## high above the pad. On the way it goes round the station or planet (Port.centre) rather than through it, never
## nearer than the gate is, so it misses the station's ring and panels and the base's tower. Near the gate it cuts the
## corner onto the final leg: straight in along the port's way out, backing into the bay or settling onto the pad,
## slowing all the way to a soft touch. It faces where it is going until it is close, then turns to the berth's
## attitude, and it holds short of the berth until it has lined up.
##
## Its speed follows how far it still has to go: a firm push (travel_accel, the main engine's) everywhere but the
## corner and the final leg, where it eases down gently (final_accel). The whole thing is worked out afresh from where the ship is
## each tick, so the floating origin, a slow turn or a nudge never throws it off.

var port: Port
var tuning: ArrivalTuning
## On the final leg (once on, it stays on).
var final: bool = false
## Facing the berth's attitude (from line_up_lead before the gate on), and lined up: on the final leg's line and
## turned to the berth's attitude (once on the final leg, it stays lined up unless knocked well off).
var lining_up: bool = false
var lined_up: bool = false
## How far (m) the ship still has to go: to the gate and then along the final leg.
var left: float = INF
## What it asks of the ship this tick (world space): velocity (m/s) and spin (rad/s).
var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
## True once the ship is at its berth: Arrivals then calls the arrival function.
var done: bool = false


func _init(to: Port, approach_tuning: ArrivalTuning) -> void:
	port = to
	tuning = approach_tuning


## One tick for a ship at `at` with attitude `ship_basis`, moving at `moving` and spinning at `spinning` (world space),
## with the full-stick turn `rates` and turn `accels` (pitch, yaw, roll; ShipTuning).
func step(at: Vector3, ship_basis: Basis, moving: Vector3, spinning: Vector3, rates: Vector3, accels: Vector3,
		delta: float) -> void:
	var berth := port.global_position
	var out := port.exit_direction()
	var along := (at - berth).dot(out)
	var side := (at - berth) - out * along
	# Inside the gate and near the leg's line, it is on the final leg.
	if not final and along > 0.0 and along <= port.approach_distance and side.length() <= tuning.corner:
		final = true
	var target: Vector3
	var heading: Vector3
	var gate := port.gate()
	var to_gate := at.distance_to(gate)
	# By the gate, it chases a point on the final leg instead, a corner's length further in: that cuts the corner
	# onto the leg.
	var near := to_gate <= tuning.corner
	if final:
		left = maxf(along, 0.0)
		heading = -out
	elif near:
		left = to_gate + port.approach_distance
		heading = (gate - out * tuning.corner - at).normalized()
	else:
		left = Approach.round_length(at - port.centre(), gate - port.centre()) + port.approach_distance
		heading = Approach.round_heading(at - port.centre(), gate - port.centre(), tuning.climb)
	lining_up = final or left - port.approach_distance < tuning.line_up_lead
	var facing := port.global_basis.orthonormalized() if lining_up else Approach.facing_along(heading,
			at - port.centre(), port.global_basis.orthonormalized())
	# Within the tolerances it is lined up; once lined up on the final leg, three times as much still counts, so it
	# never stops and starts on the edge of them.
	var slack := 3.0 if final and lined_up else 1.0
	lined_up = lining_up and side.length() <= tuning.on_line * slack \
			and Orbit.lined_up(ship_basis.orthonormalized(), facing, deg_to_rad(tuning.lined_up_angle * slack))
	if final:
		# Hold short of the berth until lined up, then all the way in, never past it this tick.
		var to_go := along if lined_up else maxf(along - tuning.hold_short, 0.0)
		var speed := minf(Approach.speed_for(to_go, port.approach_distance, tuning), to_go / delta)
		target = -out * speed - (side / tuning.side_time).limit_length(tuning.cornering_speed())
		done = along <= tuning.arrive_distance and side.length() <= tuning.on_line
	else:
		# Slowing as gently for the corner onto the final leg, and the stretch before it, as for the final leg itself.
		var speed := Approach.speed_for(left, port.approach_distance + 2.0 * tuning.corner, tuning)
		# Slow enough at the corner to make it at a share of its push, slowing for it as on the way.
		var cornering := tuning.cornering_speed()
		var slowing := tuning.travel_accel * (1.0 - tuning.curve_share)
		var to_corner := 0.0 if near else maxf(to_gate - tuning.corner, 0.0)
		speed = minf(speed, sqrt(cornering * cornering + 2.0 * slowing * to_corner))
		# Going round, no faster than it can keep curving round at a share of its push.
		var up := (at - port.centre()).normalized()
		var round := (heading - up * heading.dot(up)).length()
		if round > 0.1:
			speed = minf(speed, sqrt(tuning.curve_share * tuning.travel_accel * (at - port.centre()).length()) / round)
		target = heading * speed
	velocity = moving.move_toward(target, tuning.travel_accel * delta)
	spin = Approach.turn(ship_basis.orthonormalized(), facing, spinning, rates, accels, tuning.turn_time, delta)


## How fast (m/s) to go with `left` metres to go, of which the last `final_leg` are the final leg: easing down at
## final_accel on it and before it at the share of travel_accel that isn't kept for curving (curve_share), no faster
## than top_speed and no slower than touch_speed.
static func speed_for(left: float, final_leg: float, approach_tuning: ArrivalTuning) -> float:
	var on_final := minf(left, final_leg)
	var before := maxf(left - final_leg, 0.0)
	var slowing := approach_tuning.travel_accel * (1.0 - approach_tuning.curve_share)
	var speed := sqrt(2.0 * approach_tuning.final_accel * on_final + 2.0 * slowing * before)
	return clampf(speed, approach_tuning.touch_speed, approach_tuning.top_speed)


## How far (m) it is from `from` to `to` (both from the centre it goes round) going round the centre: the arc, with
## the change in height spread along it.
static func round_length(from: Vector3, to: Vector3) -> float:
	var arc := from.angle_to(to) * (from.length() + to.length()) * 0.5
	return Vector2(arc, to.length() - from.length()).length()


## Which way (unit) to go from `from` toward `to` (both from the centre it goes round), going round the centre: along
## the arc between them, with the height changing evenly along it, so it never comes nearer the centre than the nearer
## of the two. Below `to`'s height it climbs `climb` times as steeply, getting clear before going across.
static func round_heading(from: Vector3, to: Vector3, climb: float) -> Vector3:
	var up := from.normalized()
	var across := to.normalized() - up * up.dot(to.normalized())
	if across.length() < 1.0e-4:
		# Straight above or below: any way across will do, if there is one to go.
		across = up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT)
	var arc := from.angle_to(to) * (from.length() + to.length()) * 0.5
	var rise := to.length() - from.length()
	if rise > 0.0:
		rise *= climb
	var way := across.normalized() * arc + up * rise
	return way.normalized() if way.length() > 1.0e-6 else (to - from).normalized()


## The attitude for going along `heading`, top away from the centre (`from_centre`), or `otherwise` when the heading
## is too close to straight up or down for that to mean anything.
static func facing_along(heading: Vector3, from_centre: Vector3, otherwise: Basis) -> Basis:
	var up := from_centre.normalized()
	if heading.cross(up).length() < 0.2:
		return otherwise
	return Basis.looking_at(heading, up)


## The spin (rad/s, world space) that turns a ship whose attitude is `from` toward `to`, from its spin now
## (`spinning`): closing the angle over `time`, but never faster than the full-stick `rates` or speeding up or slowing
## down faster than the turn `accels` (pitch, yaw, roll), and slowing in time to stop on it.
static func turn(from: Basis, to: Basis, spinning: Vector3, rates: Vector3, accels: Vector3, time: float,
		delta: float) -> Vector3:
	var q := Quaternion(to * from.inverse()).normalized()
	if q.w < 0.0:
		q = -q
	var angle := q.get_angle()
	# Speeding up and slowing down no faster than the ship's slowest turn acceleration, whichever way it turns.
	var accel := minf(accels.x, minf(accels.y, accels.z))
	var want := Vector3.ZERO
	if angle > 1.0e-5:
		var axis := q.get_axis().normalized()
		# The ship's top rate about this axis: pitch about its x, yaw about y, roll about z.
		var local := (from.inverse() * axis).abs()
		var rate := 1.0 / Vector3(local.x / rates.x, local.y / rates.y, local.z / rates.z).length()
		want = axis * minf(minf(angle / time, rate), sqrt(2.0 * accel * angle))
	return spinning.move_toward(want, accel * delta)
