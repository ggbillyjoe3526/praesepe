extends GutTest
## The settings menu (game/ui/settings/): every page builds, its controls change the Settings autoload and show what is
## set, Defaults puts back only that page, Esc and Back close it, and the pause screen opens it. The controls page lists
## the keys from the input map. Nothing is opened over a paused tree, so the tree is never paused.

var _saved_path: String = ""


func before_each() -> void:
	_saved_path = Settings.path
	Settings.path = "user://test-settings-menu.json"
	Settings.reset()


func after_each() -> void:
	# Back to what the player has saved, with nothing left to write.
	Settings.path = _saved_path
	Settings.load_saved()
	DirAccess.remove_absolute("user://test-settings-menu.json")
	DirAccess.remove_absolute("user://test-settings-menu.json.bak")


func _menu() -> SettingsMenu:
	var menu := SettingsMenu.new()
	add_child_autofree(menu)
	return menu


func _page(menu: SettingsMenu, script: Script) -> SettingsPage:
	for p in menu.pages:
		if p.get_script() == script:
			return p
	return null


func test_every_page_builds_with_a_title() -> void:
	var menu := _menu()
	assert_eq(menu.pages.size(), SettingsMenu.PAGES.size())
	var titles := PackedStringArray()
	for p in menu.pages:
		titles.append(p.title)
	assert_eq(titles, PackedStringArray(["Display", "Interface", "Comfort", "Controls"]))
	for i in menu.pages.size():
		assert_eq(menu.page_buttons[i].text, menu.pages[i].title)


func test_one_page_shows_at_a_time() -> void:
	var menu := _menu()
	assert_true(menu.pages[0].visible)
	menu.page_buttons[2].pressed.emit()
	assert_eq(menu.current, 2)
	assert_false(menu.pages[0].visible)
	assert_true(menu.pages[2].visible)
	assert_true(menu.page_buttons[2].button_pressed)


func test_comfort_controls_start_at_the_settings() -> void:
	Settings.set_fov(80.0)
	var comfort := _page(_menu(), ComfortPage) as ComfortPage
	assert_eq(comfort.fov_slider.value, 80.0)
	assert_eq(SettingsPage.value_label(comfort.fov_slider).text, "80°")
	assert_eq(comfort.shake_slider.value, 1.0)
	assert_true(comfort.head_bob_check.button_pressed)
	assert_false(comfort.reduce_motion_check.button_pressed)


func test_comfort_controls_change_the_settings() -> void:
	var comfort := _page(_menu(), ComfortPage) as ComfortPage
	comfort.fov_slider.value = 85.0
	comfort.shake_slider.value = 0.4
	comfort.head_bob_check.button_pressed = false
	assert_eq(Settings.fov, 85.0)
	assert_almost_eq(Settings.shake, 0.4, 0.0001)
	assert_false(Settings.head_bob)


func test_reduce_motion_greys_out_shake_and_head_bob() -> void:
	var comfort := _page(_menu(), ComfortPage) as ComfortPage
	comfort.reduce_motion_check.button_pressed = true
	assert_true(Settings.reduce_motion)
	assert_false(comfort.shake_slider.editable)
	assert_true(comfort.head_bob_check.disabled)
	comfort.reduce_motion_check.button_pressed = false
	assert_true(comfort.shake_slider.editable)
	assert_false(comfort.head_bob_check.disabled)


func test_display_controls_change_the_settings() -> void:
	var display := _page(_menu(), DisplayPage) as DisplayPage
	assert_eq(display.mode_choice.selected, DisplayApply.WindowMode.FULLSCREEN)
	display.mode_choice.select(DisplayApply.WindowMode.WINDOWED)
	display.mode_choice.item_selected.emit(DisplayApply.WindowMode.WINDOWED)
	assert_eq(Settings.window_mode, DisplayApply.WindowMode.WINDOWED)
	display.vsync_check.button_pressed = false
	assert_false(Settings.vsync)
	display.limit_choice.item_selected.emit(DisplayPage.limit_index(60))
	assert_eq(Settings.frame_limit, 60)
	assert_eq(display.limit_choice.selected, DisplayPage.limit_index(60), "the list follows")
	assert_eq(display.limit_choice.get_item_text(0), "No limit")


func test_the_main_display_heads_the_list() -> void:
	var display := _page(_menu(), DisplayPage) as DisplayPage
	assert_eq(display.monitor_choice.get_item_text(0), "Main display")
	assert_eq(display.monitor_choice.selected, 0)


func test_interface_size() -> void:
	var page := _page(_menu(), InterfacePage) as InterfacePage
	assert_eq(page.size_choice.get_item_text(page.size_choice.selected), "100%")
	page.size_choice.item_selected.emit(DisplayApply.UI_SCALES.find(1.25))
	assert_almost_eq(Settings.ui_scale, 1.25, 0.0001)
	assert_eq(page.size_choice.get_item_text(page.size_choice.selected), "125%")


func test_place_markers_and_names() -> void:
	var page := _page(_menu(), InterfacePage) as InterfacePage
	assert_eq(page.marker_icons_choice.get_item_text(page.marker_icons_choice.selected), "Always")
	assert_eq(page.marker_names_choice.get_item_text(page.marker_names_choice.selected), "Near or looked at")
	page.marker_names_choice.item_selected.emit(LandmarkMarkers.Show.OFF)
	assert_eq(Settings.marker_names, LandmarkMarkers.Show.OFF)
	page.marker_icons_choice.item_selected.emit(LandmarkMarkers.Show.NEARBY)
	assert_eq(Settings.marker_icons, LandmarkMarkers.Show.NEARBY)
	page.defaults()
	assert_eq(page.marker_names_choice.selected, LandmarkMarkers.Show.NEARBY, "Defaults puts them back")
	assert_eq(Settings.marker_icons, LandmarkMarkers.Show.ALWAYS)


func test_the_controls_page_lists_the_keys() -> void:
	var controls := _page(_menu(), ControlsPage) as ControlsPage
	assert_eq(controls.key_labels.size(), ControlsPage.KEYS.size())
	var shown := {}
	for i in ControlsPage.KEYS.size():
		shown[ControlsPage.KEYS[i][0]] = controls.key_labels[i].text
	assert_eq(shown["Speed up / slow down"], "W / S")
	assert_eq(shown["Slide up / down"], "Space / Ctrl or C")
	assert_eq(shown["Dock, land, undock or take off"], "G")
	assert_eq(shown["Pause, settings and controls"], "Esc")
	assert_eq(shown["Steer (pitch and yaw)"], "Mouse")
	for words: String in shown:
		assert_ne(shown[words], KeyNames.NO_KEY, "%s has a key" % words)


func test_every_key_the_game_uses_is_listed() -> void:
	var listed := {}
	for entry in ControlsPage.KEYS:
		for action: StringName in entry[1]:
			listed[action] = true
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			assert_true(listed.has(action), "%s is in the controls list" % action)


func test_mouse_controls_change_the_settings() -> void:
	var controls := _page(_menu(), ControlsPage) as ControlsPage
	controls.sensitivity_slider.value = 2.0
	assert_almost_eq(Settings.sensitivity, 2.0, 0.0001)
	assert_eq(SettingsPage.value_label(controls.sensitivity_slider).text, "2.00×")
	controls.invert_check.button_pressed = true
	assert_true(Settings.invert_mouse)


func test_defaults_puts_back_only_its_page() -> void:
	var menu := _menu()
	Settings.set_fov(85.0)
	Settings.set_vsync(false)
	menu.show_page(menu.pages.find(_page(menu, ComfortPage)))
	menu.pages[menu.current].defaults()
	assert_eq(Settings.fov, Settings.DEFAULT_FOV)
	assert_false(Settings.vsync, "the display page's settings are kept")


func test_every_page_key_has_a_default() -> void:
	var known := Settings.to_dict()
	for script in SettingsMenu.PAGES:
		var page: SettingsPage = script.new()
		for k in page.keys:
			assert_true(known.has(k), "%s.%s is a setting" % [page.title, k])
		page.free()


func test_esc_and_back_close_it() -> void:
	var menu := _menu()
	menu.open()
	watch_signals(menu)
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	menu._unhandled_input(esc)
	assert_false(menu.visible)
	assert_signal_emitted(menu, "closed")
	menu.open()
	menu.close()
	assert_signal_emit_count(menu, "closed", 2)


func test_closing_writes_the_settings() -> void:
	var menu := _menu()
	menu.open()
	Settings.set_fov(70.0)
	menu.close()
	assert_true(FileAccess.file_exists(Settings.path))


func test_the_pause_screen_has_the_menu() -> void:
	var screen := PauseScreen.new()
	add_child_autofree(screen)
	assert_not_null(screen.settings_menu)
	assert_false(screen.settings_menu.visible)
	screen.open_settings()
	assert_true(screen.settings_menu.visible)
	screen.settings_menu.close()
	assert_false(screen.settings_menu.visible)
