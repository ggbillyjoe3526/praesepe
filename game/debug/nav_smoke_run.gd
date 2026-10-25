class_name NavSmokeRun
extends Node
## The nav computer's headless smoke run (`godot --headless --path . -- --smoke --nav`, tools/smoke_test.sh): nobody
## touches the controls, and the nav computer (NavComputer) flies every order it is given, the way a player would give
## them on its screen. It checks the screen opens in the cockpit and as a card in the chase view; heads to dock at
## Halfway Station from the start and, once the docking computer is taking the ship in, is told to land at Tollgate
## instead, so it finishes docking, undocks, cruises to Tollgate and lands there, carrying on after the pilot takes the
## stick for a moment on the way (which pauses it) and P; takes off and settles into orbit round Mote; and queues a
## longer plan, which puts the undocking between a docking and the cruise after it. Prints "SMOKE NAV: ok ..." and quits
## with 0, or pushes an error per failed check and quits with 1.

const PASS_LINE := "SMOKE NAV: ok"
## The longest (ticks) any one plan may take.
const PLAN_LIMIT := 60 * 240
## How long (ticks) into the cruise to Tollgate the pilot moves the stick.
const TOUCH_AFTER := 90

var ship: Ship
var nav: NavComputer
var system: SolarSystem
var arrivals: Arrivals
var cameras: ShipCameras
var screen: Node3D
var card: Control

var _frames: int = 0
var _phase: int = 0
var _phase_ticks: int = 0
var _failures: int = 0
var _touched: bool = false
var _cruise_ticks: int = 0
var _docked_first: bool = false
var _done: PackedStringArray = PackedStringArray()


func _ready() -> void:
	process_physics_priority = FlightOrder.CONTROLS
	SaveFile.remove(SmokeRun.SAVE_PATH)


func _physics_process(_delta: float) -> void:
	_frames += 1
	_phase_ticks += 1
	ship.input.reset()
	match _phase:
		0:
			_check_screens()
			_next()
		1: # Dock at Halfway Station, from the start, until the docking computer has the ship.
			if _phase_ticks == 1:
				_order("Halfway Station", "Dock", false, ["Cruise to Halfway Station", "Dock at Halfway Station"])
			elif arrivals.stage == Arrivals.Stage.APPROACHING:
				_done.append("docking@%d" % _frames)
				_next()
			elif _await_plan("docks at Halfway Station"):
				_expect(false, "hands the ship to the docking computer before the plan ends")
				_next()
		2: # Told to land at Tollgate while docking: it docks, undocks, cruises to Tollgate and lands, taking the stick
			# for a moment on the way.
			if _phase_ticks == 1:
				_order("Calder", "Land", false, ["Undock from Halfway Station", "Cruise to Tollgate",
						"Land at Tollgate"])
			else:
				if arrivals.stage == Arrivals.Stage.DOCKED and arrivals.port == system.port(&"halfway_station"):
					_docked_first = true
				_touch_on_the_way()
				if _await_plan("lands at Tollgate"):
					_expect(_docked_first, "finished docking at Halfway Station before leaving")
					_expect(_touched, "was paused by the pilot on the way and carried on")
					_expect(arrivals.stage == Arrivals.Stage.DOCKED and arrivals.port == system.port(&"tollgate"),
							"is landed at Tollgate after the plan")
					_next()
		3: # Take off and orbit Mote, given with "Add to plan".
			if _phase_ticks == 1:
				_order("Mote", "Orbit", true, ["Take off from Tollgate", "Cruise to Mote", "Enter orbit round Mote"])
			elif _await_plan("orbits Mote"):
				var mote := system.landmark("Mote")
				_expect(ship.orbit.settled() and ship.orbit.body == mote, "is in orbit round Mote after the plan")
				_next()
		4:
			_check_queue()
			_finish()


## Opening the nav computer shows it on the dashboard in the cockpit and as a card in the chase view.
func _check_screens() -> void:
	var names: PackedStringArray = []
	for l: Landmark in nav.places:
		names.append(l.display_name)
	_expect(",".join(names) == "Calder,Mote,Halfway Station,The Shingle", "lists the places (%s)" % ",".join(names))
	nav.select(0)
	var labels: PackedStringArray = []
	for o: NavPlan.Option in nav.options:
		labels.append(o.label)
	_expect(",".join(labels) == "Land,Orbit,Stop nearby", "offers Calder's ways to arrive (%s)"
			% ",".join(labels))
	nav.open_menu()
	_expect(screen.visible and not card.visible, "opens on the dashboard in the cockpit")
	cameras.set_view(ShipCameras.View.CHASE)
	_expect(card.visible and not screen.visible, "shows as a card in the chase view")
	cameras.set_view(ShipCameras.View.COCKPIT)
	nav.close_menu()
	_expect(not screen.visible and not card.visible, "closes")


## Picks `option` at `place` on the screen and presses Go now (or Add to plan, `queue`), then checks the plan reads
## `steps`.
func _order(place: String, option: String, queue: bool, steps: Array[String]) -> void:
	var found := false
	for i in nav.places.size():
		if nav.places[i].display_name == place:
			nav.select(i)
			found = true
	_expect(found, "lists %s" % place)
	for j in nav.options.size():
		if nav.options[j].label == option:
			nav.pick(j)
	_expect(nav.options[nav.choice].label == option, "offers \"%s\" at %s" % [option, place])
	if queue:
		nav.add()
	else:
		nav.go()
	var shown: PackedStringArray = []
	for s: NavStep in nav.plan.steps:
		shown.append(s.text())
	_expect(" / ".join(shown) == " / ".join(steps), "plans %s (%s)" % [" / ".join(steps), " / ".join(shown)])
	_expect(nav.state == NavComputer.State.RUNNING, "starts flying the plan")


## True once the plan is done (or given up on), checking it finished.
func _await_plan(what: String) -> bool:
	if nav.state == NavComputer.State.IDLE:
		_expect(nav.plan.is_empty(), "%s: finishes the plan" % what)
		_done.append("%s@%d" % [what.get_slice(" ", 0), _frames])
		return true
	var touching := _cruise_ticks > 0 and not _touched
	if nav.state == NavComputer.State.PAUSED and not touching:
		_expect(false, "%s: paused (%s)" % [what, nav.activity])
		return true
	if _phase_ticks >= PLAN_LIMIT:
		var step := nav.plan.now()
		_expect(false, "%s in time (at \"%s\", %s)" % [what, step.text() if step != null else "", nav.activity])
		return true
	return false


## A while into the cruise to Tollgate, the pilot moves the stick: the plan pauses and the ship is theirs. P carries
## on, and the computer takes the drive back.
func _touch_on_the_way() -> void:
	if _touched or (_cruise_ticks == 0 and not ship.cruise.locked()):
		return
	_cruise_ticks += 1
	if _cruise_ticks == TOUCH_AFTER:
		ship.input.turn.y = 0.5
	elif _cruise_ticks == TOUCH_AFTER + 2:
		_expect(nav.state == NavComputer.State.PAUSED, "pauses when the pilot takes the stick")
		_expect(not ship.cruise.locked(), "leaves the ship to the pilot")
		nav.toggle_pause()
		_expect(nav.state == NavComputer.State.RUNNING, "carries on with P")
		_touched = true


## A plan given with Add to plan twice (within one tick, so nothing is flown): the undocking comes between the docking
## and the next cruise. Then cleared.
func _check_queue() -> void:
	nav.clear()
	_order_only("Halfway Station", "Dock")
	_order_only("Calder", "Orbit")
	var shown: PackedStringArray = []
	for s: NavStep in nav.plan.steps:
		shown.append(s.text())
	# In orbit round Mote the ship isn't at a berth, so nothing comes before the first cruise.
	var want := "Cruise to Halfway Station / Dock at Halfway Station / Undock from Halfway Station / Cruise to Calder"
	want += " / Enter orbit round Calder"
	_expect(" / ".join(shown) == want, "queues with Add to plan (%s)" % " / ".join(shown))
	nav.clear()
	_expect(nav.plan.is_empty() and nav.state == NavComputer.State.IDLE, "clears the plan")


func _order_only(place: String, option: String) -> void:
	for i in nav.places.size():
		if nav.places[i].display_name == place:
			nav.select(i)
	for j in nav.options.size():
		if nav.options[j].label == option:
			nav.pick(j)
	nav.add()


func _next() -> void:
	_phase += 1
	_phase_ticks = 0


func _expect(ok: bool, what: String) -> void:
	if ok:
		return
	_failures += 1
	push_error("SMOKE NAV: the nav computer %s: failed" % what)


func _finish() -> void:
	set_physics_process(false)
	if _failures > 0:
		push_error("SMOKE NAV: %d checks failed" % _failures)
		get_tree().quit(1)
		return
	print("%s frames=%d seed=%d clock=%.2f plans=%s" % [PASS_LINE, _frames, Game.world_seed, Game.clock,
			",".join(_done)])
	get_tree().quit(0)
