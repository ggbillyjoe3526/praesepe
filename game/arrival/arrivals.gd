class_name Arrivals
extends Node
## Docking and landing (design doc, "Docking and landing"). Each physics tick it looks for the nearest port (Port) the
## ship is close to and says whether docking or landing there is offered, or what the pilot must do first (come
## closer, slow down, leave the cruise drive). G, when offered, hands the ship to the way in (Approach): it flies
## itself to its berth in real time, with no fade or loading screen, and arrives. G or X on the way takes it back, and
## a bump on the way stops it. G again undocks or takes off, easing the ship out along the port's way out before
## handing it back.
##
## arrive() is the one arrival function (project instructions, "One arrival function for every landing and docking"):
## every docking and every landing goes through it, and it is all the rest of the game sees (Events.arrived), so how
## the ship gets there can change without touching contracts, bases or saves. Loading a game docked and the tow back
## to a base will use it too.

enum Stage {
	FLYING, ## Free flight: ports may be offered.
	APPROACHING, ## Flying itself in to the berth.
	DOCKED, ## At the berth: G leaves.
	LEAVING, ## Easing out along the port's way out.
}
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

var _left: float = 0.0
## The ball swept ahead of the ship to find what is in its way (_in_the_way).
var _feeler: PhysicsShapeQueryParameters3D = null


func _ready() -> void:
	process_physics_priority = FlightOrder.ARRIVALS


func _physics_process(delta: float) -> void:
	if ship == null:
		return
	var asked := ship.input.dock
	ship.input.dock = false
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


## The one arrival function: the ship docks or lands at `to`. It is placed at the berth and held still there (the
## cruise drive and any orbit stopped), and everyone listening hears of it (Events.arrived): the autosave writes the
## game and the HUD says so. Done in one tick; coming in from the way in, the ship is already there, and touches
## down with a bump as hard as its speed then (never softer than touch_speed).
func arrive(to: Port) -> void:
	var touch := maxf(tuning.touch_speed, ship.linear_velocity.length()) if stage == Stage.APPROACHING else 0.0
	port = to
	nearest = null
	approach = null
	ship.hold_at(to, touch)
	stage = Stage.DOCKED
	Events.arrived.emit(to)


## Leaves the berth: the ship is eased out along the port's way out, then handed back to the pilot.
func depart() -> void:
	if port == null or stage != Stage.DOCKED:
		return
	stage = Stage.LEAVING
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
## swept along it, and the normal of the first thing it meets.
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
	_feeler.motion = motion
	var fractions := space.cast_motion(_feeler)
	if fractions.is_empty() or fractions[1] >= 1.0:
		return Vector3.ZERO
	_feeler.transform = Transform3D(Basis.IDENTITY, from + motion * fractions[1])
	_feeler.motion = Vector3.ZERO
	var rest := space.get_rest_info(_feeler)
	return rest.get("normal", Vector3.ZERO)


## Speeding up evenly from rest to the port's exit speed over its exit distance, then the pilot has the ship.
func _ease_out(delta: float) -> void:
	var accel := port.exit_speed * port.exit_speed / (2.0 * port.exit_distance)
	var speed := minf(sqrt(2.0 * accel * _left) + accel * delta, port.exit_speed)
	_left += speed * delta
	if _left >= port.exit_distance:
		ship.release(port.exit_direction() * port.exit_speed)
		stage = Stage.FLYING
		port = null
		return
	ship.guide(port.exit_direction() * speed)
