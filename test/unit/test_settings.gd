extends GutTest
## The player's settings (game/save/settings.gd): the comfort settings keep to their ranges, ignore damaged values,
## take effect through `changed`, and survive a save and a load. A damaged file keeps the defaults and is never wiped.
## Each test works on its own file and puts the autoload back as it found it.

const ROOT := "user://test-settings"

var _saved_path: String = ""
var _n := 0


func before_each() -> void:
	_saved_path = Settings.path
	_n += 1
	DirAccess.make_dir_recursive_absolute(ROOT)
	Settings.path = "%s/settings-%d.json" % [ROOT, _n]
	Settings.reset()


func after_each() -> void:
	# Back to what the player has saved, with nothing left to write.
	Settings.path = _saved_path
	Settings.load_saved()


func after_all() -> void:
	for f in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))
	DirAccess.remove_absolute(ROOT)


func test_defaults() -> void:
	assert_eq(Settings.fov, Settings.DEFAULT_FOV)
	assert_eq(Settings.shake, 1.0)
	assert_true(Settings.head_bob)
	assert_false(Settings.reduce_motion)


func test_values_keep_to_their_ranges() -> void:
	Settings.set_fov(500.0)
	assert_eq(Settings.fov, Settings.FOV_MAX)
	Settings.set_fov(10.0)
	assert_eq(Settings.fov, Settings.FOV_MIN)
	Settings.set_fov(80.4)
	assert_eq(Settings.fov, 80.0, "whole degrees")
	Settings.set_shake(-1.0)
	assert_eq(Settings.shake, 0.0)
	Settings.set_shake(3.0)
	assert_eq(Settings.shake, 1.0)


func test_a_change_is_announced_once() -> void:
	watch_signals(Settings)
	Settings.set_fov(90.0)
	Settings.set_fov(90.0)
	assert_signal_emit_count(Settings, "changed", 1, "the same value again is not a change")


func test_reduce_motion_calms_the_cameras() -> void:
	Settings.set_shake(0.8)
	assert_almost_eq(Settings.shake_amount(), 0.8, 0.0001)
	assert_true(Settings.head_moves())
	Settings.set_reduce_motion(true)
	assert_eq(Settings.shake_amount(), 0.0)
	assert_false(Settings.head_moves())
	assert_almost_eq(Settings.shake, 0.8, 0.0001, "the player's own shake choice is kept for later")


func test_damaged_values_are_ignored() -> void:
	Settings.set_fov(90.0)
	Settings.from_dict({"fov": "wide", "shake": null, "head_bob": 1, "reduce_motion": "yes"})
	assert_eq(Settings.fov, 90.0)
	assert_eq(Settings.shake, 1.0)
	assert_true(Settings.head_bob)
	assert_false(Settings.reduce_motion)


func test_saves_and_loads() -> void:
	Settings.set_fov(88.0)
	Settings.set_shake(0.3)
	Settings.set_head_bob(false)
	Settings.set_reduce_motion(true)
	assert_true(Settings.commit())
	Settings.reset()
	assert_true(Settings.load_saved())
	assert_eq(Settings.fov, 88.0)
	assert_almost_eq(Settings.shake, 0.3, 0.0001)
	assert_false(Settings.head_bob)
	assert_true(Settings.reduce_motion)


func test_the_default_view_is_not_too_wide() -> void:
	# Wide views stretch planets near the screen's edges; 60° tall is about 90° across on 16:9.
	assert_eq(Settings.DEFAULT_FOV, 60.0)
	assert_lte(Settings.FOV_MAX, 90.0)
	var across := rad_to_deg(2.0 * atan(tan(deg_to_rad(Settings.DEFAULT_FOV) * 0.5) * 16.0 / 9.0))
	assert_almost_eq(across, 91.5, 0.5)


func test_an_old_file_on_the_old_default_view_drops_it() -> void:
	Settings.set_fov(80.0)
	Settings.from_dict({"v": 1, "fov": 75.0, "shake": 0.5, "head_bob": false, "reduce_motion": false})
	assert_eq(Settings.fov, 80.0, "an untouched old default leaves the current value (the new default after a load)")
	assert_almost_eq(Settings.shake, 0.5, 0.0001, "the other settings carry over")
	assert_false(Settings.head_bob)


func test_an_old_file_keeps_a_view_the_player_chose() -> void:
	Settings.from_dict({"v": 1, "fov": 70.0})
	assert_eq(Settings.fov, 70.0)
	Settings.from_dict({"v": 1, "fov": 100.0})
	assert_eq(Settings.fov, Settings.FOV_MAX, "a view wider than the new range comes in to its edge")


func test_an_old_view_that_rounds_to_75_counts_as_the_old_default() -> void:
	Settings.set_fov(80.0)
	Settings.from_dict({"v": 1, "fov": 75.4})
	assert_eq(Settings.fov, 80.0)


func test_an_old_file_without_a_version_in_it_goes_by_its_header() -> void:
	var f := FileAccess.open(Settings.path, FileAccess.WRITE)
	f.store_string(SaveFile.encode(Settings.KIND, 1, {"fov": 75.0}))
	f.close()
	assert_true(Settings.load_saved())
	assert_eq(Settings.fov, Settings.DEFAULT_FOV)


func test_the_cameras_in_the_main_scene_start_at_the_default_view() -> void:
	var main: PackedScene = load("res://game/main/main.tscn")
	var state := main.get_state()
	var found := 0
	for i in state.get_node_count():
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"fov":
				assert_eq(state.get_node_property_value(i, p), Settings.DEFAULT_FOV, str(state.get_node_name(i)))
				found += 1
	assert_eq(found, 2, "both ship cameras")


func test_a_new_file_keeps_75() -> void:
	Settings.from_dict({"v": 2, "fov": 75.0})
	assert_eq(Settings.fov, 75.0, "only version 1 files are moved off 75")


func test_loading_an_old_file_on_the_old_default_gives_the_new_default() -> void:
	var f := FileAccess.open(Settings.path, FileAccess.WRITE)
	f.store_string(SaveFile.encode(Settings.KIND, 1, {"v": 1, "fov": 75.0, "shake": 0.2, "head_bob": true,
			"reduce_motion": true}))
	f.close()
	assert_true(Settings.load_saved())
	assert_eq(Settings.fov, Settings.DEFAULT_FOV)
	assert_almost_eq(Settings.shake, 0.2, 0.0001)
	assert_true(Settings.reduce_motion)


func test_only_writes_when_something_changed() -> void:
	assert_true(Settings.commit())
	assert_true(FileAccess.file_exists(Settings.path), "reset() counts as a change")
	DirAccess.remove_absolute(Settings.path)
	assert_true(Settings.commit())
	assert_false(FileAccess.file_exists(Settings.path), "nothing changed, nothing written")


func test_a_damaged_file_keeps_the_defaults_and_is_not_wiped() -> void:
	var f := FileAccess.open(Settings.path, FileAccess.WRITE)
	f.store_string("PSAVE settings 1 0000\n{broken")
	f.close()
	assert_false(Settings.load_saved())
	assert_eq(Settings.fov, Settings.DEFAULT_FOV)
	assert_true(FileAccess.file_exists(Settings.path), "the damaged file is left for SaveFile to move aside")


func test_saving_after_a_damaged_load_sets_the_damaged_copy_aside() -> void:
	var f := FileAccess.open(Settings.path, FileAccess.WRITE)
	f.store_string("PSAVE settings 1 0000\n{broken")
	f.close()
	Settings.load_saved()
	Settings.set_fov(70.0)
	assert_true(Settings.commit())
	var kept := 0
	for name in DirAccess.get_files_at(ROOT):
		if name.begins_with(Settings.path.get_file() + ".corrupt-"):
			kept += 1
	assert_eq(kept, 1, "the damaged copy is moved aside, never deleted")
	Settings.reset()
	assert_true(Settings.load_saved())
	assert_eq(Settings.fov, 70.0)


func test_the_game_starts_fullscreen_on_the_main_display() -> void:
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.FULLSCREEN)
	assert_eq(Settings.monitor, DisplayApply.MONITOR_MAIN)
	assert_true(Settings.vsync)
	assert_eq(Settings.frame_limit, DisplayApply.UNLIMITED)
	assert_eq(Settings.ui_scale, 1.0)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/mode")), DisplayServer.WINDOW_MODE_FULLSCREEN,
			"the window opens fullscreen, so there is no flash of a window first")


func test_the_display_and_mouse_settings_save_and_load() -> void:
	Settings.set_window_mode(DisplayApply.WindowMode.WINDOWED)
	Settings.set_monitor(1)
	Settings.set_vsync(false)
	Settings.set_frame_limit(144)
	Settings.set_sensitivity(1.5)
	Settings.set_invert_mouse(true)
	Settings.set_ui_scale(1.25)
	assert_true(Settings.commit())
	Settings.reset()
	assert_true(Settings.load_saved())
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.WINDOWED)
	assert_eq(Settings.monitor, 1)
	assert_false(Settings.vsync)
	assert_eq(Settings.frame_limit, 144)
	assert_almost_eq(Settings.sensitivity, 1.5, 0.0001)
	assert_true(Settings.invert_mouse)
	assert_almost_eq(Settings.ui_scale, 1.25, 0.0001)


func test_a_file_from_before_the_settings_menu_starts_fullscreen() -> void:
	var f := FileAccess.open(Settings.path, FileAccess.WRITE)
	f.store_string(SaveFile.encode(Settings.KIND, 2, {"v": 2, "fov": 70.0, "shake": 0.5, "head_bob": true,
			"reduce_motion": false}))
	f.close()
	assert_true(Settings.load_saved())
	assert_eq(Settings.fov, 70.0)
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.FULLSCREEN)
	assert_almost_eq(Settings.sensitivity, 1.0, 0.0001)


func test_new_values_keep_to_what_is_offered() -> void:
	Settings.set_frame_limit(100)
	assert_eq(Settings.frame_limit, 120, "the nearest limit offered")
	Settings.set_frame_limit(-5)
	assert_eq(Settings.frame_limit, DisplayApply.UNLIMITED)
	Settings.set_sensitivity(10.0)
	assert_eq(Settings.sensitivity, Settings.SENSITIVITY_MAX)
	Settings.set_sensitivity(1.234)
	assert_almost_eq(Settings.sensitivity, 1.25, 0.0001, "in steps")
	Settings.set_ui_scale(1.3)
	assert_almost_eq(Settings.ui_scale, 1.25, 0.0001)
	Settings.set_monitor(500)
	assert_eq(Settings.monitor, DisplayApply.MONITOR_MOST)


func test_damaged_display_values_are_ignored() -> void:
	Settings.from_dict({"window_mode": 7, "last_fullscreen": 2.5, "monitor": "two", "vsync": 0, "frame_limit": "fast",
			"sensitivity": [], "invert_mouse": 1, "ui_scale": null})
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.FULLSCREEN)
	assert_eq(Settings.last_fullscreen, DisplayApply.WindowMode.FULLSCREEN)
	assert_eq(Settings.monitor, DisplayApply.MONITOR_MAIN)
	assert_true(Settings.vsync)
	assert_eq(Settings.frame_limit, DisplayApply.UNLIMITED)
	assert_almost_eq(Settings.sensitivity, 1.0, 0.0001)
	assert_false(Settings.invert_mouse)
	assert_almost_eq(Settings.ui_scale, 1.0, 0.0001)


func test_f11_goes_back_to_the_fullscreen_kind_last_used() -> void:
	Settings.set_window_mode(DisplayApply.WindowMode.EXCLUSIVE)
	Settings.toggle_fullscreen()
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.WINDOWED)
	Settings.toggle_fullscreen()
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.EXCLUSIVE)


func test_resetting_some_keys_leaves_the_rest() -> void:
	Settings.set_fov(80.0)
	Settings.set_window_mode(DisplayApply.WindowMode.WINDOWED)
	Settings.set_vsync(false)
	Settings.reset(PackedStringArray(["window_mode", "vsync"]))
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.FULLSCREEN)
	assert_true(Settings.vsync)
	assert_eq(Settings.fov, 80.0, "a setting on another page is kept")
