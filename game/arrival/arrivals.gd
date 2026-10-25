class_name Arrivals
extends Node
## Docking and landing (design doc, "Docking and landing"). Each physics tick it looks for the nearest port (Port) the
## ship is close to and says whether docking or landing there is offered, or what the pilot must do first (come
## closer, slow down, leave the cruise drive). G, when offered, hands the ship to the way in (Approach): it flies
## itself to its berth in real time from where it is, with no fade or loading screen, and arrives. G or X on the way
## takes it back, and a bump on the way stops it. G again undocks or takes off, lifting the ship off a bay's floor and
## easing it out along the port's way out before handing it back. Flying by hand, it also watches for anything ahead
## the ship is coming at faster than it could comfortably stop (warning), for the HUD's "SLOW DOWN".
##
## arrive() is the one arrival function (project instructions, "One arrival function for every landing and docking"):
## every docking and every landing goes through it, and it is all the rest of the game sees (Events.arrived), so how
## the ship gets there can change without touching contracts, bases or saves. The tow home (tow()) goes through it
## too, and so will loading a game docked.

enum Stage {
	FLYING, ## Free flight: ports may be offered.
	APPROACHING, ## Flying itself in to the berth.
	DOCKED, ## At the berth: G leaves.
	LEAVING, ## Easing out along the port's way out.
}
## Lifting off a bay's floor, never slower than this (m/s), so it reaches the top.
const LIFT_LEAST := 0.2

## Why the nearest port isn't offered yet.
enum Refusal {
	NONE, ## Offered: G docks or lands.
	TOO_FAR, ## Within its hint range, not yet its offer range.
	TOO_FAST, ## Close enough, faster than its max_speed.
	CRUISING, ## Close enough, but the cruise drive is charging or running.
}

## G was pressed while flying but nothing is offered: `port` is the nearest one (or null) and `why` says why not.
signal refused(port: Port, why: Refusal)
## The way in to `port` stopped short: the pilot took the ship back (G or X), or it was `blocked` by a bump.
signal stopped(port: Port, blocked: bool)

@export var ship: Ship
@export var tuning: ArrivalTuning

## Every port in the solar system (SolarSystem.ports).
var ports: Array[Port] = []
var stage: Stage = Stage.FLYING
## Where the ship is arriving, docked or leaving from.
var port: Port = null
## The way in, while approaching.
var approach: Approach = null
## While flying: the nearest port within its hint range, or null; whether it is offered, and how far away it is
## (Port.distance).
var nearest: Port = null
var refusal: Refusal = Refusal.TOO_FAR
var nearest_distance: float = INF
## Flying by hand: true when the ship is coming at something faster than it could comfortably stop, `warning_place`
## being what (the place it belongs to, or null) and `warning_time` how long (s) until it gets there at this speed.
var warning: bool = false
var warning_place: Landmark = null
var warning_time: float = INF
## The last port the ship arrived at, where the tow takes it (and saved with the game), or null if it never has.
var home: Port = null

## Leaving: how far (m) it has lifted off a bay's floor, and then how far it has eased out.
var _lifted: float = 0.0
var _left: float = 0.0
## The ball swept ahead of the ship to find what is in its way (_in_the_way), and the one swept along its velocity
## for the speed warning (_watch_speed).
var _feeler: PhysicsShapeQueryParameters3D = null
var _watcher: PhysicsShapeQueryParameters3D = null
## The port whose guide light is lit (Port.guiding), or null.
var _guided: Port = null


func _ready() -> void:
	process_physics_priority = FlightOrder.ARRIVALS


func _physics_process(delta: float) -> void:
	if ship == null:
		return
	var asked := ship.input.dock
	ship.input.dock = false
	_watch_speed()
	match stage:
		Stage.FLYING:
			_look_around()
			if asked and nearest != null and refusal == Refusal.NONE:
				_begin(nearest)
			elif asked:
				refused.emit(nearest, refusal)
		Stage.APPROACHING:
			_fly_in(asked, delta)
		Stage.DOCKED:
			if asked:
				depart()
		Stage.LEAVING:
			_ease_out(delta)
	_light_the_way()


## The one arrival function: the ship docks or lands at `to`. It is placed at the berth and held still there (the
## cruise drive and any orbit stopped), and everyone listening hears of it (Events.arrived): the autosave writes the
## game and the HUD says so. Done in one tick; coming in from the way in, the ship is already there, and touches
## down with a bump as hard as its speed then (never softer than touch_speed).
func arrive(to: Port) -> void:
	var touch := maxf(tuning.touch_speed, ship.linear_velocity.length()) if stage == Stage.APPROACHING else 0.0
	port = to
	home = to
	nearest = null
	approach = null
	ship.hold_at(to, touch)
	stage = Stage.DOCKED
	Events.arrived.emit(to)


## Where the tow would take the ship: home, or the nearest port if it has never arrived anywhere. Null when there are no
## ports.
func tow_to() -> Port:
	if home != null:
		return home
	var best: Port = null
	var best_distance := INF
	for p: Port in ports:
		var d := p.distance(ship.global_position)
		if d < best_distance:
			best = p
			best_distance = d
	return best


## Whether the tow is offered: not while docked or landed (the ship is at a base already), and only with somewhere to go.
func can_tow() -> bool:
	return stage != Stage.DOCKED and tow_to() != null


## Tows the ship home ("Tow me to base" on the pause screen): wherever it is and whatever it is doing (flying, cruising,
## in orbit, on its way in to a berth or out of one), it is put straight at home's berth through arrive(), like any
## arrival, so the game saves there. Then everyone hears it was towed (Events.towed): the floating origin re-centres on
## it and, once money exists, the fee is charged. Returns where it went, or null when the tow isn't offered.
func tow() -> Port:
	if not can_tow():
		return null
	var to := tow_to()
	# Whatever trip was under way is dropped; the ship arrives at rest, with no bump.
	stage = Stage.FLYING
	approach = null
	arrive(to)
	Events.towed.emit(to)
	return to


## Leaves the berth: the ship is eased out along the port's way out, then handed back to the pilot.
func depart() -> void:
	if port == null or stage != Stage.DOCKED:
		return
	stage = Stage.LEAVING
	_lifted = 0.0
	_left = 0.0
	ship.guide(Vector3.ZERO)
	Events.departed.emit(port)


## Whether docking or landing at `p` is offered to a ship `distance` away (Port.distance) moving at `speed`, with its
## cruise drive charging or running (`cruising`).
static func judge(p: Port, distance: float, speed: float, cruising: bool) -> Refusal:
	if distance > p.offer_range:
		return Refusal.TOO_FAR
	if cruising:
		return Refusal.CRUISING
	if speed > p.max_speed:
		return Refusal.TOO_FAST
	return Refusal.NONE


func _look_around() -> void:
	nearest = null
	nearest_distance = INF
	refusal = Refusal.TOO_FAR
	var at := ship.global_position
	for p: Port in ports:
		var d := p.distance(at)
		if d <= p.hint_range and d < nearest_distance:
			nearest = p
			nearest_distance = d
	if nearest != null:
		refusal = Arrivals.judge(nearest, nearest_distance, ship.speed(),
				ship.cruise.phase != CruiseDrive.Phase.OFF)


func _begin(to: Port) -> void:
	port = to
	stage = Stage.APPROACHING
	approach = Approach.new(to, tuning)
	approach.start_from(ship.global_position, ship.linear_velocity)
	approach.obstacle = _in_the_way
	ship.approach(to)


## One tick of the way in: G or X takes the ship back (X then stops it), a bump stops it, and otherwise the ship goes
## as the way in says until it is at its berth.
func _fly_in(asked: bool, delta: float) -> void:
	var stop := ship.input.full_stop
	var blocked := ship.jolt > tuning.bump_limit
	if asked or stop or blocked:
		var from := port
		stage = Stage.FLYING
		var close := approach.final
		port = null
		approach = null
		ship.release(ship.linear_velocity)
		# A bump leaves the ship to come to rest, as X does; so does G on the final leg, rather than carrying on into
		# the bay or down onto the pad.
		ship.input.full_stop = stop or blocked or close
		stopped.emit(from, blocked)
		return
	approach.step(ship.global_position, ship.global_basis, ship.linear_velocity, ship.angular_velocity,
			ship.tuning.max_rates(), ship.tuning.turn_accels(), delta)
	if approach.done:
		arrive(port)
	else:
		ship.guide(approach.velocity, approach.spin)


## What is in the ship's way going from `from` along `motion` (Approach.obstacle): a ball as wide as the ship's reach,
## swept along it, and the normal of the first thing it meets (or of what it is already touching).
func _in_the_way(from: Vector3, motion: Vector3) -> Vector3:
	if _feeler == null:
		_feeler = PhysicsShapeQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = tuning.reach
		_feeler.shape = ball
		_feeler.exclude = [ship.get_rid()]
		_feeler.collision_mask = ship.collision_mask
	var space := ship.get_world_3d().direct_space_state
	_feeler.transform = Transform3D(Basis.IDENTITY, from)
	_feeler.motion = Vector3.ZERO
	# Already within reach of something: the sweep can't see what it starts in, so that is what is in the way.
	var touching := space.get_rest_info(_feeler)
	if not touching.is_empty():
		return touching.get("normal", Vector3.ZERO)
	_feeler.motion = motion
	var fractions := space.cast_motion(_feeler)
	if fractions.is_empty() or fractions[1] >= 1.0:
		return Vector3.ZERO
	_feeler.transform = Transform3D(Basis.IDENTITY, from + motion * fractions[1])
	_feeler.motion = Vector3.ZERO
	var rest := space.get_rest_info(_feeler)
	return rest.get("normal", Vector3.ZERO)


## Lifting off a bay's floor (Port.settle) as gently as the ship settled onto it, then speeding up evenly from rest to
## the port's exit speed over its exit distance, then the pilot has the ship.
func _ease_out(delta: float) -> void:
	if _lifted < port.settle:
		var a := tuning.settle_accel
		var rise := minf(sqrt(2.0 * a * _lifted) + a * delta, sqrt(2.0 * a * (port.settle - _lifted)))
		rise = minf(clampf(rise, LIFT_LEAST, tuning.settle_speed), (port.settle - _lifted) / delta)
		_lifted += rise * delta
		ship.guide(port.global_basis.y.normalized() * rise)
		return
	var accel := port.exit_speed * port.exit_speed / (2.0 * port.exit_distance)
	var speed := minf(sqrt(2.0 * accel * _left) + accel * delta, port.exit_speed)
	_left += speed * delta
	if _left >= port.exit_distance:
		ship.release(port.exit_direction() * port.exit_speed)
		stage = Stage.FLYING
		port = null
		return
	ship.guide(port.exit_direction() * speed)


## Flying by hand (not cruising or in orbit) at warn_speed or more: a ball swept along the ship's velocity as far as it
## would take to stop using warn_share of its weakest push, plus warn_lead seconds at its speed. Anything it meets
## sets the warning, with the place that thing belongs to and how long until the ship gets there.
func _watch_speed() -> void:
	warning = false
	warning_place = null
	warning_time = INF
	var speed := ship.speed()
	if stage != Stage.FLYING or ship.cruise.phase != CruiseDrive.Phase.OFF or ship.orbit.active() \
			or speed < tuning.warn_speed:
		return
	if _watcher == null:
		_watcher = PhysicsShapeQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = tuning.warn_reach
		_watcher.shape = ball
		_watcher.exclude = [ship.get_rid()]
		_watcher.collision_mask = ship.collision_mask
	var brake := minf(ship.tuning.reverse_accel, minf(ship.tuning.lateral_accel, ship.tuning.vertical_accel))
	var reach := speed * speed / (2.0 * tuning.warn_share * brake) + speed * tuning.warn_lead
	var space := ship.get_world_3d().direct_space_state
	_watcher.transform = Transform3D(Basis.IDENTITY, ship.global_position)
	_watcher.motion = ship.linear_velocity * (reach / speed)
	var fractions := space.cast_motion(_watcher)
	# Clear all the way, or already up against something (a bump is the ship's to feel, not a warning).
	if fractions.is_empty() or fractions[1] >= 1.0 or fractions[1] <= 0.0:
		return
	warning = true
	warning_time = reach * fractions[1] / speed
	_watcher.transform = Transform3D(Basis.IDENTITY, ship.global_position + _watcher.motion * fractions[1])
	_watcher.motion = Vector3.ZERO
	var id: int = space.get_rest_info(_watcher).get("collider_id", 0)
	var node := instance_from_id(id) as Node if id != 0 else null
	while node != null and not node is Landmark:
		node = node.get_parent()
	warning_place = node as Landmark


## Lights the guide light of the port the ship is lined up in (in its lane, flying) or flying itself in to, and puts
## out the one it lit before.
func _light_the_way() -> void:
	var lit: Port = null
	if stage == Stage.APPROACHING:
		lit = port
	elif stage == Stage.FLYING and nearest != null and nearest.in_lane(ship.global_position):
		lit = nearest
	if lit == _guided:
		return
	if _guided != null:
		_guided.guiding = false
	_guided = lit
	if lit != null:
		lit.guiding = true
