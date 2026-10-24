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
