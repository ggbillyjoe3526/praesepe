extends GutTest
## When the places' HUD markers show their diamonds and names (game/hud/landmark_markers.gd): a place counts as
## noticed when it is near, looked at, aimed at or locked onto, with a wider cone to stop looking at it so a name at
## the edge doesn't flicker; each of the two settings shows always, only for noticed places, or never; and showing
## or hiding fades rather than pops, at the same pace at any frame rate; a change in the settings menu shows at once.

const FAR := LandmarkMarkers.NEAR * 4.0
const OFF_TO_SIDE := 90.0


func test_a_far_place_off_to_the_side_is_not_noticed() -> void:
	assert_false(LandmarkMarkers.is_noticed(FAR, OFF_TO_SIDE, false, false))


func test_a_near_place_is_noticed_wherever_it_is() -> void:
	assert_true(LandmarkMarkers.is_noticed(LandmarkMarkers.NEAR - 1.0, 180.0, false, false))


func test_a_place_in_the_middle_of_the_view_is_noticed() -> void:
	assert_true(LandmarkMarkers.is_noticed(FAR, LandmarkMarkers.LOOK_CONE - 1.0, false, false))


func test_aimed_at_or_locked_onto_is_always_noticed() -> void:
	assert_true(LandmarkMarkers.is_noticed(FAR, 180.0, true, false))


func test_looking_away_needs_the_wider_cone() -> void:
	var between := (LandmarkMarkers.LOOK_CONE + LandmarkMarkers.LOOK_CONE_OUT) * 0.5
	assert_false(LandmarkMarkers.is_noticed(FAR, between, false, false), "not noticed yet: needs the narrow cone")
	assert_true(LandmarkMarkers.is_noticed(FAR, between, false, true), "noticed already: stays until the wide cone")
	assert_false(LandmarkMarkers.is_noticed(FAR, LandmarkMarkers.LOOK_CONE_OUT + 1.0, false, true))


func test_each_setting_shows_always_noticed_or_never() -> void:
	for noticed: bool in [true, false]:
		assert_true(LandmarkMarkers.shows(LandmarkMarkers.Show.ALWAYS, noticed))
		assert_false(LandmarkMarkers.shows(LandmarkMarkers.Show.OFF, noticed))
		assert_eq(LandmarkMarkers.shows(LandmarkMarkers.Show.NEARBY, noticed), noticed)


func test_showing_fades_in_over_the_fade_time_at_any_frame_rate() -> void:
	for fps: int in [30, 60, 144]:
		var alpha := 0.0
		var frames := 0
		while alpha < 1.0:
			alpha = LandmarkMarkers.fade(alpha, true, 1.0 / fps)
			frames += 1
		assert_almost_eq(frames / float(fps), LandmarkMarkers.FADE_TIME, 1.5 / fps, "%d fps" % fps)
	assert_eq(LandmarkMarkers.fade(0.4, false, 10.0), 0.0, "never below hidden")
	assert_eq(LandmarkMarkers.fade(0.4, true, 10.0), 1.0, "never past shown")


func test_a_settings_change_shows_at_once_without_a_fade() -> void:
	# On a scratch file, so the player's own settings are never touched; put back as they were at the end.
	var saved_path := Settings.path
	Settings.path = "user://test-marker-settings.json"
	var markers := LandmarkMarkers.new()
	add_child_autofree(markers)
	var place := Landmark.new()
	add_child_autofree(place)
	var places: Array[Landmark] = [place]
	markers.show_places(places)
	Settings.set_marker_names(LandmarkMarkers.Show.ALWAYS)
	assert_eq(markers._name_alpha[0], 1.0, "shown at once while the game is paused")
	Settings.set_marker_names(LandmarkMarkers.Show.OFF)
	assert_eq(markers._name_alpha[0], 0.0)
	Settings.path = saved_path
	Settings.load_saved()
