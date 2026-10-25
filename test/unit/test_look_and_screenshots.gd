extends GutTest
## Looking round the cockpit while the look button is held (PilotControls.move_look, ShipCameras.head_turn) and the
## screenshot key's files and notes (Screenshots).

const DT := 1.0 / 60.0

var _controls: FlightControls


func before_each() -> void:
	_controls = load("res://game/flight/flight_controls.tres")


func test_held_the_mouse_turns_the_head_within_its_limits() -> void:
	var look := PilotControls.move_look(Vector2.ZERO, Vector2(0.5, 0.2), true, _controls, DT)
	assert_eq(look, Vector2(0.5, 0.2))
	look = PilotControls.move_look(look, Vector2(10.0, 10.0), true, _controls, DT)
	assert_almost_eq(look.x, deg_to_rad(_controls.look_side_max), 0.0001, "no further round than the limit")
	assert_almost_eq(look.y, deg_to_rad(_controls.look_up_max), 0.0001, "nor up")
	look = PilotControls.move_look(look, Vector2(0.0, -10.0), true, _controls, DT)
	assert_almost_eq(look.y, -deg_to_rad(_controls.look_down_max), 0.0001, "nor down")


func test_let_go_the_head_turns_back_to_the_front() -> void:
	var look := Vector2(1.5, 0.5)
	for i in 30:
		look = PilotControls.move_look(look, Vector2(3.0, 0.0), false, _controls, DT)
	assert_lt(look.length(), 0.15, "most of the way back in half a second, the mouse ignored")
	for i in 60:
		look = PilotControls.move_look(look, Vector2.ZERO, false, _controls, DT)
	assert_eq(look, Vector2.ZERO, "and exactly straight ahead in the end")


func test_the_head_turns_the_way_the_mouse_went() -> void:
	var right := ShipCameras.head_turn(Vector2(deg_to_rad(90.0), 0.0)) * Vector3.FORWARD
	assert_almost_eq(right, Vector3.RIGHT, Vector3.ONE * 0.0001, "right is right")
	var up := ShipCameras.head_turn(Vector2(0.0, deg_to_rad(30.0))) * Vector3.FORWARD
	assert_gt(up.y, 0.49, "up is up")
	assert_eq(ShipCameras.head_turn(Vector2.ZERO), Basis.IDENTITY)


func test_screenshots_are_named_by_when_they_were_taken() -> void:
	var when := {year = 2026, month = 10, day = 5, hour = 9, minute = 3, second = 7}
	assert_eq(Screenshots.file_name(when), "praesepe_2026-10-05_09-03-07.png")
	assert_eq(Screenshots.file_name(when, 2), "praesepe_2026-10-05_09-03-07_2.png")


func test_a_second_screenshot_in_the_same_second_never_overwrites_the_first() -> void:
	var folder := "user://test_screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var when := {year = 2026, month = 10, day = 25, hour = 12, minute = 0, second = 0}
	var first := Screenshots.free_path(folder, when)
	var file := FileAccess.open(first, FileAccess.WRITE)
	file.store_string("taken")
	file.close()
	var second := Screenshots.free_path(folder, when)
	assert_ne(second, first)
	assert_string_ends_with(second, "_2.png")
	DirAccess.remove_absolute(first)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))


func test_the_note_says_where_the_picture_went() -> void:
	var words := Screenshots.note_for("user://screenshots/praesepe_2026-10-25_12-00-00.png", true)
	assert_string_starts_with(words, "Screenshot saved")
	assert_string_contains(words, "praesepe_2026-10-25_12-00-00.png")
	assert_false(words.contains("user://"), "a real place on the disk, not the game's own name for it")
	assert_string_contains(Screenshots.note_for("", false), "Couldn't save")
