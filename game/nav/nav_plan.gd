class_name NavPlan
extends RefCounted
## The nav computer's plan (design doc, "Nav computer"): the orders queued for the ship, flown one after another. The
## pilot picks a place and how to arrive there (an Option, such as "Dock" or "Land at Tollgate") and the plan gets the
## steps that takes: cruise there, then dock, land or enter orbit. A plan that starts at a berth, or continues after a
## docking or landing, gets the undocking or take-off first. A finished step leaves the plan, so its first step is
## always the one being flown. Nothing here touches nodes but reading how the solar system is laid out, so the unit
## tests run it directly.


## One way to arrive at a place: its words on the screen, and the steps it takes from wherever the ship is.
class Option:
	var label: String = ""
	var steps: Array[NavStep] = []

	func _init(words: String, route: Array[NavStep]) -> void:
		label = words
		steps = route


## Orders still to fly, the one being flown first.
var steps: Array[NavStep] = []
## How many orders of this plan have been flown, for "2 of 3".
var done_count: int = 0
## No more orders than this, still to fly.
var max_steps: int = 8


func is_empty() -> bool:
	return steps.is_empty()


## The order being flown, or null.
func now() -> NavStep:
	return null if steps.is_empty() else steps[0]


## The order being flown is done.
func advance() -> void:
	if not steps.is_empty():
		steps.remove_at(0)
		done_count += 1


func clear() -> void:
	steps.clear()
	done_count = 0


## How many orders the plan has had: flown and still to fly.
func total() -> int:
	return done_count + steps.size()


## Adds `route` after the orders still to fly (an empty plan starts counting afresh). If the ship ends up at a berth
## before it (`berth`, where it is held now, for an empty plan), leaving it comes first. False, changing nothing, when
## the plan would grow past max_steps.
func append(route: Array[NavStep], berth: Port) -> bool:
	var from := berth
	if not steps.is_empty():
		var last := steps[steps.size() - 1]
		from = last.port if last.kind == NavStep.Kind.ARRIVE else null
	var add: Array[NavStep] = []
	if from != null and (route.is_empty() or route[0].kind != NavStep.Kind.DEPART):
		add.append(NavStep.depart(from))
	add.append_array(route)
	if steps.size() + add.size() > max_steps:
		return false
	if steps.is_empty():
		done_count = 0
	steps.append_array(add)
	return true


## Replaces the plan with `route`, starting from `berth` (where the ship is held now, or null). False, changing
## nothing, when `route` alone is longer than max_steps.
func replace(route: Array[NavStep], berth: Port) -> bool:
	var kept := steps
	steps = []
	if append(route, berth):
		done_count = 0
		return true
	steps = kept
	return false


## The places the nav computer lists, in the solar system's order: every place with a HUD marker, except a base on a
## planet or moon, which is landed at from its planet's entry ("Land at Tollgate" under Calder).
static func places(landmarks: Array[Landmark]) -> Array[Landmark]:
	var out: Array[Landmark] = []
	for l: Landmark in landmarks:
		if l.marker and not NavPlan.on_body(l):
			out.append(l)
	return out


## Whether `place` stands on a planet or moon (a base).
static func on_body(place: Node) -> bool:
	var node := place.get_parent()
	while node != null:
		if node is CelestialBody:
			return true
		node = node.get_parent()
	return false


## The ways to arrive at `place`, most useful first: dock at its docking bay; land at each base on it; enter orbit
## round it (a planet or moon); or stop nearby, which only cruises there.
static func options(place: Landmark, ports: Array[Port]) -> Array[Option]:
	var out: Array[Option] = []
	for p: Port in ports:
		if p.place == place and p.body == null and p.kind == Port.Kind.DOCK:
			out.append(Option.new("Dock", [NavStep.cruise(place), NavStep.arrive(p)]))
	var body := place as CelestialBody
	if body != null:
		for p: Port in ports:
			if p.body == body and p.place != null:
				out.append(Option.new("Land at %s" % p.place_name(), [NavStep.cruise(p.place), NavStep.arrive(p)]))
		out.append(Option.new("Orbit", [NavStep.cruise(body), NavStep.orbit(body)]))
	out.append(Option.new("Stop nearby", [NavStep.cruise(place)]))
	return out
