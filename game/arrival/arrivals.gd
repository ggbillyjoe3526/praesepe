class_name Arrivals
extends Node
## Docking and landing (design doc, "Docking and landing"). Each physics tick it looks for the nearest port (Port) the
## ship is close to and says whether docking or landing there is offered, or what the pilot must do first (come
## closer, slow down, leave the cruise drive). G, when offered, fades to the transition screen and the ship arrives;
## G again undocks or takes off, easing the ship out along the port's way out before handing it back.
##
## arrive() is the one arrival function (project instructions, "One arrival function for every landing and docking"):
## every docking and every landing goes through it, and it is all the rest of the game sees (Events.arrived), so
## seamless landing can later replace what happens on screen without touching contracts, bases or saves. Loading a
## game docked and the tow back to a base will use it too.

enum Stage {
	FLYING, ## Free flight: ports may be offered.
	ARRIVING, ## Fading out on the way in.
	SETTLING, ## Black, then fading in at the berth.
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

@export var ship: Ship
@export var transition: TransitionScreen
@export var tuning: ArrivalTuning

## Every port in the solar system (SolarSystem.ports).
var ports: Array[Port] = []
var stage: Stage = Stage.FLYING
## Where the ship is arriving, docked or leaving from.
var port: Port = null
## While flying: the nearest port within its hint range, or null; whether it is offered, and how far away it is
## (Port.distance).
var nearest: Port = null
var refusal: Refusal = Refusal.TOO_FAR
var nearest_distance: float = INF

var _timer: float = 0.0
var _left: float = 0.0


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
		Stage.ARRIVING:
			# The pilot has let go; the ship coasts on as flight assist holds it while the view fades.
			ship.input.reset()
			_timer += delta
			_show(_timer / tuning.fade_out)
			if _timer >= tuning.fade_out:
				arrive(port)
				stage = Stage.SETTLING
				_timer = 0.0
		Stage.SETTLING:
			_timer += delta
			_show(1.0 - (_timer - tuning.hold) / tuning.fade_in)
			if _timer >= tuning.hold + tuning.fade_in:
				stage = Stage.DOCKED
				_show(0.0)
		Stage.DOCKED:
			if asked:
				depart()
		Stage.LEAVING:
			_ease_out(delta)


## The one arrival function: the ship docks or lands at `to`. It is placed at the berth and held still there (the
## cruise drive and any orbit stopped), and everyone listening hears of it (Events.arrived): the autosave writes the
## game. Done in one tick, so whatever covers it (today the transition screen) decides how it looks.
func arrive(to: Port) -> void:
	port = to
	nearest = null
	ship.hold_at(to)
	if stage == Stage.FLYING or stage == Stage.LEAVING:
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
	stage = Stage.ARRIVING
	_timer = 0.0
	if transition != null:
		transition.begin(to)


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


func _show(cover: float) -> void:
	if transition != null:
		transition.cover = clampf(cover, 0.0, 1.0)
