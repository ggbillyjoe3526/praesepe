extends GutTest
## The nav computer's plan (design doc, "Nav computer"): which places it lists, the ways to arrive at each, the steps
## each takes, leaving a berth first, queueing one route after another, and the words on its screen and HUD strip.

var _station: Landmark
var _dock: Port
var _planet: CelestialBody
var _base: Landmark
var _pad: Port
var _belt: Landmark
var _landmarks: Array[Landmark] = []
var _ports: Array[Port] = []


func before_each() -> void:
	# Nodes only, never entered into the tree: nothing here needs them built.
	_planet = CelestialBody.new()
	_planet.display_name = "Calder"
	_base = Landmark.new()
	_base.display_name = "Tollgate"
	_planet.add_child(_base)
	_pad = Port.new()
	_pad.kind = Port.Kind.PAD
	_pad.place = _base
	_pad.body = _planet
	_base.add_child(_pad)
	_station = Landmark.new()
	_station.display_name = "Halfway Station"
	_dock = Port.new()
	_dock.kind = Port.Kind.DOCK
	_dock.place = _station
	_station.add_child(_dock)
	_belt = Landmark.new()
	_belt.display_name = "The Shingle"
	var hidden := Landmark.new()
	hidden.display_name = "Hidden"
	hidden.marker = false
	_landmarks = [_planet, _base, _station, _belt, hidden]
	_ports = [_pad, _dock]
	for n: Node in [_planet, _station, _belt, hidden]:
		autofree(n)


func _texts(steps: Array[NavStep]) -> String:
	var out: PackedStringArray = []
	for s: NavStep in steps:
		out.append(s.text())
	return " / ".join(out)


func _labels(options: Array[NavPlan.Option]) -> String:
	var out: PackedStringArray = []
	for o: NavPlan.Option in options:
		out.append(o.label)
	return ",".join(out)


func test_lists_places_with_markers_but_reaches_a_base_through_its_planet() -> void:
	var names: PackedStringArray = []
	for l: Landmark in NavPlan.places(_landmarks):
		names.append(l.display_name)
	assert_eq(",".join(names), "Calder,Halfway Station,The Shingle")


func test_ways_to_arrive_at_each_kind_of_place() -> void:
	assert_eq(_labels(NavPlan.options(_station, _ports)), "Dock,Stop nearby")
	assert_eq(_labels(NavPlan.options(_planet, _ports)), "Land,Orbit,Stop nearby")
	assert_eq(_labels(NavPlan.options(_belt, _ports)), "Stop nearby")


func test_each_way_cruises_there_first() -> void:
	var at_station := NavPlan.options(_station, _ports)
	assert_eq(_texts(at_station[0].steps), "Cruise to Halfway Station / Dock at Halfway Station")
	assert_eq(_texts(at_station[1].steps), "Cruise to Halfway Station")
	var at_planet := NavPlan.options(_planet, _ports)
	assert_eq(_texts(at_planet[0].steps), "Cruise to Tollgate / Land at Tollgate", "lands by cruising to the base")
	assert_eq(_texts(at_planet[1].steps), "Cruise to Calder / Enter orbit round Calder")


func test_a_plan_from_a_berth_leaves_it_first() -> void:
	var plan := NavPlan.new()
	assert_true(plan.replace(NavPlan.options(_planet, _ports)[1].steps, _dock))
	assert_eq(_texts(plan.steps), "Undock from Halfway Station / Cruise to Calder / Enter orbit round Calder")
	assert_true(plan.replace(NavPlan.options(_station, _ports)[0].steps, _pad))
	assert_eq(_texts(plan.steps), "Take off from Tollgate / Cruise to Halfway Station / Dock at Halfway Station")
	assert_true(plan.replace(NavPlan.options(_station, _ports)[0].steps, null))
	assert_eq(_texts(plan.steps), "Cruise to Halfway Station / Dock at Halfway Station", "nothing to leave in flight")


func test_queueing_after_a_docking_undocks_between() -> void:
	var plan := NavPlan.new()
	assert_true(plan.append(NavPlan.options(_station, _ports)[0].steps, null))
	assert_true(plan.append(NavPlan.options(_planet, _ports)[0].steps, null))
	assert_eq(_texts(plan.steps), "Cruise to Halfway Station / Dock at Halfway Station / Undock from Halfway Station"
			+ " / Cruise to Tollgate / Land at Tollgate")
	assert_true(plan.append(NavPlan.options(_belt, _ports)[0].steps, _dock))
	assert_eq(plan.steps[5].text(), "Take off from Tollgate", "leaves where the plan ends, not where the ship is")


func test_steps_leave_the_plan_as_they_are_flown_and_are_counted() -> void:
	var plan := NavPlan.new()
	plan.replace(NavPlan.options(_planet, _ports)[1].steps, null)
	assert_eq(plan.now().kind, NavStep.Kind.CRUISE)
	plan.advance()
	assert_eq(plan.now().kind, NavStep.Kind.ORBIT)
	assert_eq(plan.done_count, 1)
	assert_eq(plan.total(), 2)
	plan.append(NavPlan.options(_belt, _ports)[0].steps, null)
	assert_eq(plan.total(), 3, "queueing more keeps the count")
	plan.advance()
	plan.advance()
	assert_true(plan.is_empty())
	plan.append(NavPlan.options(_belt, _ports)[0].steps, null)
	assert_eq(plan.done_count, 0, "an empty plan starts counting afresh")


func test_a_plan_never_grows_past_its_most_steps() -> void:
	var plan := NavPlan.new()
	plan.max_steps = 4
	assert_true(plan.append(NavPlan.options(_station, _ports)[0].steps, null))
	assert_false(plan.append(NavPlan.options(_planet, _ports)[0].steps, null), "five steps is too many")
	assert_eq(plan.steps.size(), 2, "unchanged")
	assert_true(plan.append(NavPlan.options(_belt, _ports)[0].steps, null), "but it can fill up to four")
	assert_false(plan.replace([NavStep.cruise(_belt), NavStep.cruise(_station), NavStep.cruise(_planet),
			NavStep.cruise(_belt), NavStep.cruise(_station)], null))
	assert_eq(plan.steps.size(), 4, "a refused replacement keeps the plan")


func test_each_step_has_its_colour() -> void:
	assert_eq(NavStep.cruise(_belt).colour(), FlightHud.CRUISE_COLOUR)
	assert_eq(NavStep.orbit(_planet).colour(), FlightHud.ORBIT_COLOUR)
	assert_eq(NavStep.arrive(_dock).colour(), FlightHud.BERTH_COLOUR)
	assert_eq(NavStep.depart(_pad).colour(), FlightHud.BERTH_COLOUR)


func test_the_hud_strip_says_which_step_and_what_it_is_doing() -> void:
	var nav: NavComputer = autofree(NavComputer.new())
	assert_eq(NavStrip.line_for(nav), "", "nothing without a plan")
	nav.plan.replace(NavPlan.options(_planet, _ports)[1].steps, _dock)
	nav.plan.advance()
	nav.state = NavComputer.State.RUNNING
	assert_eq(NavStrip.line_for(nav), "NAV  2/3  ·  Cruise to Calder  ·  P  Pause")
	nav.activity = "Lining up for Calder"
	assert_eq(NavStrip.line_for(nav), "NAV  2/3  ·  Lining up for Calder  ·  P  Pause")
	nav.state = NavComputer.State.PAUSED
	nav.activity = "You took the controls"
	assert_eq(NavStrip.line_for(nav), "NAV PAUSED  ·  2/3  ·  You took the controls  ·  P  Resume")
