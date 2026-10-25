class_name NavStep
extends RefCounted
## One order in the nav computer's plan (NavPlan): leave the berth, cruise to a place, enter orbit round a planet or
## moon, or dock or land at a port. The nav computer (NavComputer) flies each one by pressing the same keys the pilot
## would (F, O, G), so every order goes through the cruise drive, the orbit and Arrivals like a hand-flown one.

enum Kind {
	DEPART, ## Undock or take off from `port`.
	CRUISE, ## Cruise to `place`, dropping out on arriving there.
	ORBIT, ## Enter orbit round `place` (a CelestialBody) and settle there.
	ARRIVE, ## Dock or land at `port` (its place is `place`).
}

var kind: Kind = Kind.CRUISE
var place: Landmark = null
var port: Port = null


static func depart(from: Port) -> NavStep:
	var s := NavStep.new()
	s.kind = Kind.DEPART
	s.port = from
	s.place = from.place
	return s


static func cruise(to: Landmark) -> NavStep:
	var s := NavStep.new()
	s.kind = Kind.CRUISE
	s.place = to
	return s


static func orbit(round_body: CelestialBody) -> NavStep:
	var s := NavStep.new()
	s.kind = Kind.ORBIT
	s.place = round_body
	return s


static func arrive(at: Port) -> NavStep:
	var s := NavStep.new()
	s.kind = Kind.ARRIVE
	s.port = at
	s.place = at.place
	return s


## The order in words, as the nav computer's screen lists it: "Cruise to Mote", "Land at Tollgate".
func text() -> String:
	match kind:
		Kind.DEPART:
			var where := port.place_name()
			return "Undock from %s" % where if port.kind == Port.Kind.DOCK else "Take off from %s" % where
		Kind.CRUISE:
			return "Cruise to %s" % place.display_name
		Kind.ORBIT:
			return "Enter orbit round %s" % place.display_name
	var at := port.place_name()
	return "Dock at %s" % at if port.kind == Port.Kind.DOCK else "Land at %s" % at


## The colour the screen lists it in: cruise blue, orbit violet, berth white (as the HUD shows each).
func colour() -> Color:
	match kind:
		Kind.CRUISE:
			return FlightHud.CRUISE_COLOUR
		Kind.ORBIT:
			return FlightHud.ORBIT_COLOUR
	return FlightHud.BERTH_COLOUR
