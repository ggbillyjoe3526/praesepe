extends GutTest
## The words the HUD and the dashboard show for speed, the cruise drive and the distance to each place, and that they
## change only when what is shown changes (so text is never rebuilt every frame at a steady speed).


func test_speeds_under_a_kilometre_a_second_show_in_metres() -> void:
	assert_eq(FlightHud.speed_text(FlightHud.shown_speed(199.6)), "200 m/s")
	assert_eq(FlightHud.speed_text(FlightHud.shown_speed(0.2)), "0 m/s")


func test_cruise_speeds_show_in_tenths_of_a_kilometre_a_second() -> void:
	assert_eq(FlightHud.speed_text(FlightHud.shown_speed(2349.0)), "2.3 km/s")
	assert_eq(FlightHud.speed_text(FlightHud.shown_speed(5000.0)), "5.0 km/s")
	assert_eq(FlightHud.shown_speed(2310.0), FlightHud.shown_speed(2340.0), "the same text for nearby speeds")


func test_every_cruise_event_has_words() -> void:
	for event: CruiseDrive.Event in CruiseDrive.Event.values():
		var words := FlightHud.cruise_message(event, "Mote")
		if event == CruiseDrive.Event.NONE:
			assert_eq(words, "")
		else:
			assert_ne(words, "", CruiseDrive.Event.keys()[event])
	assert_eq(FlightHud.cruise_message(CruiseDrive.Event.ARRIVED, "Mote"), "Arrived at Mote")


func test_the_readout_names_the_cruise_drive_while_it_runs() -> void:
	assert_string_contains(FlightHud.mode_text(FlightHud.Mode.CRUISING, 0), "CRUISE")
	assert_string_contains(FlightHud.mode_text(FlightHud.Mode.CHARGING, 0), "CHARGING")
	assert_eq(FlightHud.mode_text(FlightHud.Mode.ASSIST_ON, 120), FlightHud.assist_text(true, 120))


func test_distances_show_in_steps_that_suit_them() -> void:
	assert_eq(LandmarkMarkers.distance_text(436.0), "440 m")
	assert_eq(LandmarkMarkers.distance_text(2460.0), "2.5 km")
	assert_eq(LandmarkMarkers.distance_text(31400.0), "31 km")
	assert_eq(LandmarkMarkers.distance_key(31400.0), LandmarkMarkers.distance_key(31200.0), "same text, same key")
	assert_ne(LandmarkMarkers.distance_key(2460.0), LandmarkMarkers.distance_key(2560.0))
	# The keys never collide across the steps.
	assert_ne(LandmarkMarkers.distance_key(990.0), LandmarkMarkers.distance_key(9900.0))


func test_marker_labels_stack_rather_than_cover_each_other() -> void:
	var taken: Array[Rect2] = [Rect2(100, 500, 200, 30), Rect2(120, 468, 200, 30), Rect2(900, 500, 100, 30)]
	var plate := LandmarkMarkers.stack(Rect2(150, 505, 180, 30), taken, 3, true)
	for j in 3:
		assert_false(plate.intersects(taken[j]), "clear of label %d" % j)
	assert_lt(plate.position.y, 468.0, "stacked upwards")
	assert_eq(plate.position.x, 150.0, "only moved up")
	var alone := Rect2(500, 100, 100, 30)
	assert_eq(LandmarkMarkers.stack(alone, taken, 3, false), alone, "left alone when clear")


func test_every_mode_has_words_that_fit_the_dashboard() -> void:
	for mode: FlightHud.Mode in FlightHud.Mode.values():
		var words := FlightHud.mode_text(mode, 200)
		assert_ne(words, "", FlightHud.Mode.keys()[mode])
		# The dashboard's line fits about 40 characters at its size.
		assert_lt(words.length(), 40, words)
	assert_eq(FlightHud.mode_text(FlightHud.Mode.DOCKED, 0), "DOCKED  ·  G to undock")
	assert_eq(FlightHud.mode_text(FlightHud.Mode.ORBITING, 0), "IN ORBIT  ·  O or thrust to leave")


func test_every_orbit_event_has_words() -> void:
	for event: Orbit.Event in Orbit.Event.values():
		var words := FlightHud.orbit_message(event, "Calder", Orbit.Refusal.NONE)
		if event == Orbit.Event.NONE:
			assert_eq(words, "")
		else:
			assert_ne(words, "", Orbit.Event.keys()[event])
	assert_string_contains(FlightHud.orbit_message(Orbit.Event.REFUSED, "Calder", Orbit.Refusal.TOO_FAST), "Too fast")
	assert_string_contains(FlightHud.orbit_message(Orbit.Event.REFUSED, "", Orbit.Refusal.FAR), "Nothing to orbit")


func test_the_prompts_say_what_to_do_next() -> void:
	var dock := Port.new()
	dock.id = &"test"
	var station := Landmark.new()
	station.display_name = "Halfway Station"
	station.add_child(dock)
	add_child_autofree(station)
	var flying := Arrivals.Stage.FLYING
	assert_eq(ActionPrompts.port_text(flying, dock, Arrivals.Refusal.NONE, 900.0), "G   Dock at Halfway Station")
	assert_eq(ActionPrompts.port_text(flying, dock, Arrivals.Refusal.TOO_FAST, 900.0),
			"Slow below 100 m/s to dock at Halfway Station")
	assert_eq(ActionPrompts.port_text(flying, dock, Arrivals.Refusal.TOO_FAR, 2340.0),
			"Fly within 1.5 km of Halfway Station to dock (2.3 km)")
	assert_eq(ActionPrompts.port_text(flying, dock, Arrivals.Refusal.CRUISING, 900.0), "", "nothing while cruising")
	assert_eq(ActionPrompts.port_text(Arrivals.Stage.DOCKED, dock, Arrivals.Refusal.NONE, 0.0), "G   Undock")
	assert_eq(ActionPrompts.port_text(Arrivals.Stage.ARRIVING, dock, Arrivals.Refusal.NONE, 0.0), "", "nothing in the fade")
	dock.kind = Port.Kind.PAD
	dock.offer_range = 4000.0
	assert_eq(ActionPrompts.port_text(flying, dock, Arrivals.Refusal.TOO_FAR, 5240.0),
			"Descend below 4.0 km to land at Halfway Station (5.2 km up)")
	assert_eq(ActionPrompts.port_text(Arrivals.Stage.DOCKED, dock, Arrivals.Refusal.NONE, 0.0), "G   Take off")
	assert_eq(ActionPrompts.port_text(flying, null, Arrivals.Refusal.TOO_FAR, INF), "", "no port, no words")
	var calder := CelestialBody.new()
	calder.display_name = "Calder"
	autofree(calder)
	var off := Orbit.Phase.OFF
	assert_eq(ActionPrompts.orbit_text(off, calder, Orbit.Refusal.NONE, 250.0), "O   Enter orbit round Calder")
	assert_eq(ActionPrompts.orbit_text(off, calder, Orbit.Refusal.TOO_FAST, 250.0),
			"Slow below 250 m/s to enter orbit round Calder")
	assert_eq(ActionPrompts.orbit_text(Orbit.Phase.ORBITING, calder, Orbit.Refusal.NONE, 250.0),
			"O   Leave orbit round Calder")
	assert_eq(ActionPrompts.orbit_text(off, null, Orbit.Refusal.FAR, 250.0), "")


func test_the_transition_and_the_refusals_name_the_place() -> void:
	assert_eq(TransitionScreen.going_text(Port.Kind.DOCK, "Halfway Station"), "Docking at Halfway Station")
	assert_eq(TransitionScreen.arrived_text(Port.Kind.PAD, "Tollgate"), "Landed at Tollgate")
	assert_eq(TransitionScreen.saved_text(true), "Game saved")
	assert_string_contains(TransitionScreen.saved_text(false), "last save is safe")
	assert_eq(FlightHud.dock_refused_message(null, Arrivals.Refusal.TOO_FAR), "Nothing to dock at or land on here")
