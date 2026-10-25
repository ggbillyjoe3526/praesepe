class_name NavComputer
extends Node
## The ship's nav computer (design doc, "Nav computer"; William chose concept A, 2026-10-25). Tab opens it: on the
## cockpit's dashboard (NavScreen) or as a card in the chase view (NavPanel), the same in both. The pilot picks a place
## and how to arrive there, and "Go now" replaces the plan with the steps that takes, or "Add to plan" queues them
## after it (NavPlan). The computer then flies the plan one step at a time.
##
## It flies like a pilot would, through the ship's one input (ShipInput) and the same systems: it climbs clear of a
## station or base, lines the nose up with the cruise drive's course and presses F (locking the drive onto the place,
## CruiseDrive.wanted), lines up level for an orbit and presses O, closes in on a dock or pad slowly enough and presses
## G, or presses G to undock or take off. So docking still goes through Arrivals.arrive() and saves as ever.
##
## The pilot is always in charge: touching the controls (thrust, the mouse stick, F, O, G, X or Z) while it flies
## pauses the plan and leaves the ship to them, as does anything that stops a step (a bump, the drive refusing). R
## resumes or pauses it, and the screen says why it paused. Closing the screen doesn't stop the plan; a strip on the
## HUD (NavStrip) says what it is doing.

## The plan, the selection, the menu or what the computer is doing changed: the screens redraw.
signal changed

enum State {
	IDLE, ## No plan, or it is done.
	RUNNING, ## Flying the plan.
	PAUSED, ## Holding the plan until R; the pilot flies.
}

@export var ship: Ship
@export var arrivals: Arrivals
@export var cameras: ShipCameras
## Who to take the mouse from while the screen is open, and give it back to (null in the smoke test).
@export var controls: PilotControls
@export var tuning: NavTuning

var plan: NavPlan = NavPlan.new()
var state: State = State.IDLE
## The screen is open.
var is_open: bool = false
## The places listed (NavPlan.places), the one highlighted, its ways to arrive and the one picked.
var places: Array[Landmark] = []
var selected: int = 0
var options: Array[NavPlan.Option] = []
var choice: int = 0
## What it is doing now ("Climbing clear of Halfway Station"), why it paused, or what just happened.
var activity: String = ""
## The dashboard screen and the chase view's card, shown while open in their view.
var screen: Node3D = null
var card: Control = null

var _ports: Array[Port] = []
## The step `_stuck_for` counts for, and how long (s) the computer has been working at it without a system taking
## over (lining up, closing in, climbing clear).
var _step: NavStep = null
var _stuck_for: float = 0.0
## The computer pressed F to drop out of a cruise it didn't start: the drop-out isn't the pilot's.
var _dropping: bool = false
## What `activity` was made from by _set_activity (its words with a %s, and the place), so the words are only built
## again when they change, not every tick.
var _form: String = ""
var _subject: String = ""


func _ready() -> void:
	process_physics_priority = FlightOrder.NAV
	if ship != null:
		ship.cruise_changed.connect(_on_cruise_changed)
		ship.orbit_changed.connect(_on_orbit_changed)
	if arrivals != null:
		arrivals.stopped.connect(_on_dock_stopped)
	if cameras != null:
		cameras.view_changed.connect(_on_view_changed)


func _exit_tree() -> void:
	if ship != null and ship.cruise_changed.is_connected(_on_cruise_changed):
		ship.cruise_changed.disconnect(_on_cruise_changed)
	if ship != null and ship.orbit_changed.is_connected(_on_orbit_changed):
		ship.orbit_changed.disconnect(_on_orbit_changed)
	if arrivals != null and arrivals.stopped.is_connected(_on_dock_stopped):
		arrivals.stopped.disconnect(_on_dock_stopped)
	if cameras != null and cameras.view_changed.is_connected(_on_view_changed):
		cameras.view_changed.disconnect(_on_view_changed)


## Lists the solar system's places (SolarSystem.landmarks) and knows its ports, as main.gd wires it.
func setup(landmarks: Array[Landmark], ports: Array[Port]) -> void:
	_ports = ports
	places = NavPlan.places(landmarks)
	plan.max_steps = tuning.max_steps
	select(0)
	# Towed home from the pause screen: the plan was for where the ship was, so it is dropped.
	if not Events.towed.is_connected(_on_towed):
		Events.towed.connect(_on_towed)


func _on_towed(_port: Port) -> void:
	if not plan.is_empty():
		clear()


## Shows the screen in the view the pilot is in (`dashboard` in the cockpit, `chase_card` in the chase view).
func attach(dashboard: Node3D, chase_card: Control) -> void:
	screen = dashboard
	card = chase_card
	_sync_views()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var handled := true
	if event.is_action_pressed(&"nav_computer"):
		toggle_menu()
	elif event.is_action_pressed(&"nav_pause") and not plan.is_empty():
		toggle_pause()
	elif not is_open:
		handled = false
	elif event.is_action_pressed(&"nav_up"):
		select(selected - 1)
	elif event.is_action_pressed(&"nav_down"):
		select(selected + 1)
	elif event.is_action_pressed(&"nav_left"):
		pick(choice - 1)
	elif event.is_action_pressed(&"nav_right"):
		pick(choice + 1)
	# Exact, so Shift+Enter isn't also Go now and Alt+Enter (fullscreen) is neither.
	elif event.is_action_pressed(&"nav_add", false, true):
		add()
	elif event.is_action_pressed(&"nav_go", false, true):
		go()
	elif event.is_action_pressed(&"nav_clear"):
		clear()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Pausing the game closes the screen; the pause screen has the mouse.
	if what == NOTIFICATION_PAUSED and is_open:
		is_open = false
		_sync_views()
		changed.emit()


func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()


## Opens the screen and frees the mouse to click it. The ship flies on as it was.
func open_menu() -> void:
	if is_open:
		return
	is_open = true
	if controls != null:
		controls.release_mouse()
	_sync_views()
	changed.emit()


func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	if controls != null and not get_tree().paused:
		controls.capture_mouse()
	_sync_views()
	changed.emit()


## Highlights place `index` (wrapping round the list) and its first way to arrive.
func select(index: int) -> void:
	if places.is_empty():
		return
	selected = posmod(index, places.size())
	options = NavPlan.options(places[selected], _ports)
	choice = 0
	changed.emit()


## Picks way to arrive `index` (wrapping round) at the highlighted place.
func pick(index: int) -> void:
	if options.is_empty():
		return
	choice = posmod(index, options.size())
	changed.emit()


## Replaces the plan with the way to the highlighted place picked, and flies it.
func go() -> void:
	if options.is_empty():
		return
	if not plan.replace(options[choice].steps, _berth()):
		_say("That's more than %d steps" % plan.max_steps)
		return
	_run()


## Queues the way to the highlighted place picked after the plan, flying it now if nothing was planned.
func add() -> void:
	if options.is_empty():
		return
	var was_empty := plan.is_empty()
	if not plan.append(options[choice].steps, _berth()):
		_say("The plan is full (%d steps)" % plan.max_steps)
		return
	if was_empty or state == State.IDLE:
		_run()
	else:
		changed.emit()


## R: pauses the plan, or carries on with it.
func toggle_pause() -> void:
	if state == State.RUNNING:
		_pause("Paused")
	elif not plan.is_empty():
		_run()


## Forgets the plan; the pilot flies, from wherever the ship is and however it is going (a cruise carries on).
func clear() -> void:
	plan.clear()
	state = State.IDLE
	_step = null
	_let_go()
	activity = ""
	_form = ""
	changed.emit()


func _run() -> void:
	state = State.RUNNING
	_step = null
	activity = ""
	_form = ""
	changed.emit()


func _pause(why: String) -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	_step = null
	_let_go()
	activity = why
	_form = ""
	changed.emit()


## Takes back what it asked of the ship and may not have had answered yet: a lock it gave the drive with an F that
## went unheard, and a drop-out it is waiting for, so neither is mistaken for the pilot's later.
func _let_go() -> void:
	_dropping = false
	if ship != null:
		ship.cruise.wanted = null


## Says `words` on the screen without changing anything else.
func _say(words: String) -> void:
	activity = words
	_form = ""
	changed.emit()


## Says what it is doing: `form` (words with a %s) about `subject`, built only when either changes.
func _set_activity(form: String, subject: String) -> void:
	if form == _form and subject == _subject:
		return
	_form = form
	_subject = subject
	activity = form % subject
	changed.emit()


func _physics_process(delta: float) -> void:
	if state != State.RUNNING or ship == null:
		return
	var step := plan.now()
	if step == null:
		_finish()
		return
	if step != _step:
		_step = step
		_stuck_for = 0.0
	if _pilot_flying():
		_pause("You took the controls")
		return
	match step.kind:
		NavStep.Kind.DEPART:
			_depart(step, delta)
		NavStep.Kind.CRUISE:
			_cruise(step, delta)
		NavStep.Kind.ORBIT:
			_orbit(step, delta)
		NavStep.Kind.ARRIVE:
			_arrive(step, delta)
	if state == State.RUNNING and _stuck_for > tuning.give_up_time:
		_pause("%s is taking too long  ·  fly closer" % step.text())


## Whether the pilot is flying the ship by hand this tick: thrust, the mouse stick past the point where it takes over
## from the cruise drive's lock, or F, O, G, X or Z. Rolling is left alone (the lock leaves roll to the pilot too).
## While the ship is held or guided in or out of a berth, Arrivals deals with what the pilot presses.
func _pilot_flying() -> bool:
	if ship.berth != null or ship.guided:
		return false
	var i := ship.input
	return (i.thrust != Vector3.ZERO or Vector2(i.turn.x, i.turn.y).length() > CruiseDrive.STICK_TAKES_OVER
			or i.toggle_cruise or i.toggle_orbit or i.dock or i.full_stop or i.toggle_assist)


func _done() -> void:
	plan.advance()
	_step = null
	if plan.is_empty():
		_finish()
	else:
		changed.emit()


func _finish() -> void:
	state = State.IDLE
	_step = null
	activity = "Plan done"
	_form = ""
	plan.clear()
	changed.emit()


## Undock or take off: G while held at the berth, then wait until Arrivals hands the ship back.
func _depart(step: NavStep, delta: float) -> void:
	match arrivals.stage:
		Arrivals.Stage.DOCKED:
			_stuck_for += delta
			ship.input.dock = true
			_set_activity(_leaving_form(step), step.port.place_name())
		Arrivals.Stage.LEAVING:
			_set_activity(_leaving_form(step), step.port.place_name())
		Arrivals.Stage.APPROACHING:
			# Ordered while the docking computer was taking the ship in: it finishes that, then leaves.
			_set_activity(_arriving_form(arrivals.port), arrivals.port.place_name())
		Arrivals.Stage.FLYING:
			_done()


## The berth the plan starts from: where the ship is docked or landed, or where it is being taken in to now.
func _berth() -> Port:
	if ship.berth != null:
		return ship.berth
	return arrivals.port if arrivals.stage == Arrivals.Stage.APPROACHING else null


## For a cruise or orbit step while the ship is at, or on its way in or out of, a berth (a plan that didn't start with
## leaving it): finish coming in, then G to leave, and wait until Arrivals hands the ship back. False once it is free.
func _leave_berth() -> bool:
	match arrivals.stage:
		Arrivals.Stage.DOCKED:
			ship.input.dock = true
			_set_activity("Undocking from %s" if arrivals.port.kind == Port.Kind.DOCK else "Taking off from %s",
					arrivals.port.place_name())
			return true
		Arrivals.Stage.APPROACHING:
			_set_activity(_arriving_form(arrivals.port), arrivals.port.place_name())
			return true
		Arrivals.Stage.LEAVING:
			return true
	return false


static func _arriving_form(port: Port) -> String:
	return "Docking at %s" if port.kind == Port.Kind.DOCK else "Landing at %s"


static func _leaving_form(step: NavStep) -> String:
	return "Undocking from %s" if step.port.kind == Port.Kind.DOCK else "Taking off from %s"


## Cruise to the step's place: climb clear of a station or base first, line the nose up with the drive's course, then
## F with the drive told where to lock on. Done once the ship is inside the place's arrival zone (where the drive
## drops out).
func _cruise(step: NavStep, delta: float) -> void:
	if _leave_berth():
		return
	var place := step.place
	var drive := ship.cruise
	if drive.phase != CruiseDrive.Phase.OFF:
		if drive.target == place:
			_set_activity("Cruising to %s" if drive.active() else "Cruise drive charging for %s", place.display_name)
		else:
			_drop_cruise()
		return
	var at := ship.global_position
	if place.surface_distance(at) <= place.drop_distance:
		_done()
		return
	_stuck_for += delta
	var near := _too_close(at)
	if near != null:
		_set_activity("Climbing clear of %s", near.display_name)
		_climb_clear(near)
		return
	_set_activity("Lining up for %s", place.display_name)
	var nose := -ship.global_basis.z
	var way := drive.course_to(place, at, nose)
	ship.input.turn = _turn_to(way)
	# Close is enough: once engaged, the drive's lock turns the nose the rest of the way.
	if nose.angle_to(way) < deg_to_rad(tuning.aim_tolerance):
		drive.wanted = place
		ship.input.toggle_cruise = true
		# Hands off while it charges: a turn now would count as the pilot steering away. Roll stays the pilot's.
		ship.input.turn = Vector3(0.0, 0.0, ship.input.turn.z)


## Enter orbit round the step's body: O once it is offered; until then fly toward the body and then at the insertion
## point on its orbit line, slowly enough. Done once the ship has settled into the orbit.
func _orbit(step: NavStep, delta: float) -> void:
	if _leave_berth():
		return
	var body := step.place as CelestialBody
	var o := ship.orbit
	if o.active():
		if o.body != body:
			_pause("In orbit round %s  ·  leave it first" % o.body.display_name)
		elif o.settled():
			_done()
		else:
			_set_activity("Entering orbit round %s", body.display_name)
		return
	if ship.cruise.phase != CruiseDrive.Phase.OFF:
		_drop_cruise()
		return
	_stuck_for += delta
	if o.offered == body and o.refusal == Orbit.Refusal.NONE:
		ship.input.toggle_orbit = true
		_set_activity("Entering orbit round %s", body.display_name)
		return
	_set_activity("Lining up for orbit round %s", body.display_name)
	# Toward the body until its orbit line is near; then at the insertion point on the line (the ring the HUD shows),
	# which a gentle climb or descent reaches, and O as soon as the orbit is offered on the way.
	var way := body.global_position - ship.global_position
	if o.offered == body:
		way += o.insertion
	_fly(way.normalized(), o.tuning.max_entry_speed * tuning.orbit_speed_share)


## Dock or land at the step's port: G once it is offered; until then close in on its gate, slowing to below the port's
## top speed by the time it is in reach. Done once the ship is held at that berth.
func _arrive(step: NavStep, delta: float) -> void:
	var port := step.port
	match arrivals.stage:
		Arrivals.Stage.DOCKED:
			if arrivals.port == port:
				_done()
			else:
				_pause("At %s, not %s" % [arrivals.port.place_name(), port.place_name()])
			return
		Arrivals.Stage.APPROACHING:
			_set_activity(_arriving_form(port), port.place_name())
			return
		Arrivals.Stage.LEAVING:
			return
	if ship.cruise.phase != CruiseDrive.Phase.OFF:
		_drop_cruise()
		return
	if arrivals.nearest == port and arrivals.refusal == Arrivals.Refusal.NONE:
		ship.input.dock = true
		return
	_stuck_for += delta
	var at := ship.global_position
	var slow := port.max_speed * tuning.arrive_speed_share
	var speed := clampf((port.distance(at) - port.offer_range) / tuning.close_in_time, slow, ship.tuning.max_speed)
	var too_fast := arrivals.nearest == port and arrivals.refusal == Arrivals.Refusal.TOO_FAST
	_set_activity("Slowing down for %s" if too_fast else "Closing in on %s", port.place_name())
	_fly((port.gate() - at).normalized(), speed)


## F to drop out of a cruise the computer didn't start (or is going elsewhere), so the step can go on.
func _drop_cruise() -> void:
	_dropping = true
	ship.input.toggle_cruise = true


## Turns the nose toward `way` (world space, unit) and holds `speed` (m/s) forward with flight assist on, not speeding
## up while the nose is still well off.
func _fly(way: Vector3, speed: float) -> void:
	var nose := -ship.global_basis.z
	ship.input.turn = _turn_to(way)
	var forward := ship.pilot_velocity().z
	var want := speed
	if nose.angle_to(way) > deg_to_rad(tuning.turning_cone):
		want = minf(speed, maxf(forward, 0.0))
	ship.input.thrust = Vector3(0.0, 0.0, clampf((want - forward) / tuning.speed_band, -1.0, 1.0))
	if not ship.assist_on():
		ship.input.toggle_assist = true


func _turn_to(way: Vector3) -> Vector3:
	# The pilot's roll (Q/E, already in the input this tick) is passed on: rolling never pauses the plan.
	return CruiseDrive.turn_towards(ship.global_basis, way, ship.input.turn.z, ship.tuning.max_rates(), tuning.turn_time)


## The station or base (not a planet or moon) whose surface the ship at `at` is within NavTuning.clearance of, or null:
## too close for the cruise drive to engage.
func _too_close(at: Vector3) -> Landmark:
	for l: Landmark in ship.cruise.landmarks:
		if l.obstacle and l.radius > 0.0 and not l is CelestialBody and l.surface_distance(at) < tuning.clearance:
			return l
	return null


## Thrusts straight away from `near`'s middle, the nose left as it is.
func _climb_clear(near: Landmark) -> void:
	var away := (ship.global_position - near.global_position).normalized()
	var local := ship.global_basis.inverse() * away
	var push := Vector3(local.x, local.y, -local.z)
	var most := maxf(absf(push.x), maxf(absf(push.y), absf(push.z)))
	ship.input.thrust = push / most if most > 0.0 else Vector3.ZERO
	ship.input.turn = Vector3(0.0, 0.0, ship.input.turn.z)
	if not ship.assist_on():
		ship.input.toggle_assist = true


func _on_cruise_changed(event: CruiseDrive.Event, place: Landmark) -> void:
	if state != State.RUNNING:
		_dropping = false
		return
	var where := place.display_name if place != null else ""
	match event:
		CruiseDrive.Event.DROPPED, CruiseDrive.Event.CANCELLED:
			if _dropping:
				_dropping = false
			else:
				_pause("You took the controls")
		CruiseDrive.Event.UNLOCKED:
			_pause("You took the controls")
		CruiseDrive.Event.BLOCKED, CruiseDrive.Event.BLOCKED_INSIDE, CruiseDrive.Event.SAFETY, \
				CruiseDrive.Event.BUMPED:
			_pause(FlightHud.cruise_message(event, where))


func _on_orbit_changed(event: Orbit.Event, body: CelestialBody) -> void:
	var step := plan.now()
	if state != State.RUNNING or step == null or step.kind != NavStep.Kind.ORBIT:
		return
	if event == Orbit.Event.BUMPED or event == Orbit.Event.LEFT or event == Orbit.Event.LEAVING:
		var words := body.display_name if body != null else ""
		_pause(FlightHud.orbit_message(event, words, ship.orbit.refusal))


func _on_dock_stopped(port: Port, blocked: bool) -> void:
	var step := plan.now()
	if state == State.RUNNING and step != null and step.kind == NavStep.Kind.ARRIVE:
		_pause(FlightHud.dock_stopped_message(port, blocked))


func _on_view_changed(_view: ShipCameras.View) -> void:
	_sync_views()


func _sync_views() -> void:
	var cockpit := cameras == null or cameras.view == ShipCameras.View.COCKPIT
	if screen != null:
		screen.visible = is_open and cockpit
	if card != null:
		card.visible = is_open and not cockpit
