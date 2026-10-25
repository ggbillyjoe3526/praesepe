extends GutTest
## The comfort settings on the pause screen (game/ui/pause_screen.gd): each control changes its setting, shows the
## value, and greys out what reduce motion turns off. The screen is never opened, so the tree is never paused.

var _saved_path: String = ""


func before_each() -> void:
	_saved_path = Settings.path
	Settings.path = "user://test-pause-comfort.json"
	Settings.reset()


func after_each() -> void:
	# Back to what the player has saved, with nothing left to write.
	Settings.path = _saved_path
	Settings.load_saved()
	DirAccess.remove_absolute("user://test-pause-comfort.json")
	DirAccess.remove_absolute("user://test-pause-comfort.json.bak")


func _screen() -> PauseScreen:
	var screen := PauseScreen.new()
	add_child_autofree(screen)
	return screen


func test_controls_start_at_the_settings() -> void:
	Settings.set_fov(80.0)
	var screen := _screen()
	assert_eq(screen.fov_slider.value, 80.0)
	assert_eq(screen.shake_slider.value, 1.0)
	assert_true(screen.head_bob_check.button_pressed)
	assert_false(screen.reduce_motion_check.button_pressed)


func test_the_controls_change_the_settings() -> void:
	var screen := _screen()
	screen.fov_slider.value = 85.0
	screen.shake_slider.value = 0.4
	screen.head_bob_check.button_pressed = false
	assert_eq(Settings.fov, 85.0)
	assert_almost_eq(Settings.shake, 0.4, 0.0001)
	assert_false(Settings.head_bob)


func test_reduce_motion_greys_out_shake_and_head_bob() -> void:
	var screen := _screen()
	screen.reduce_motion_check.button_pressed = true
	assert_true(Settings.reduce_motion)
	assert_false(screen.shake_slider.editable)
	assert_true(screen.head_bob_check.disabled)
	screen.reduce_motion_check.button_pressed = false
	assert_true(screen.shake_slider.editable)
	assert_false(screen.head_bob_check.disabled)
