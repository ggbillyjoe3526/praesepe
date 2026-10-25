extends GutTest
## The display settings into the window (game/save/display_apply.gd) through a stand-in for the window calls, since the
## headless display server has no screens: fullscreen, exclusive and windowed, the window's size on leaving fullscreen,
## the chosen display (the main one when it is gone), V-Sync, the frame-rate limit and the background limit, and the
## interface size. Also the F11 and Alt+Enter keys (WindowWatch).


## Records what the game asked of the window.
class FakeScreens:
	extends DisplayApply.Screens
	var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN
	var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
	var screen_count: int = 2
	var on: int = 0
	var fitted: Array[int] = []

	func available() -> bool:
		return true

	func mode() -> DisplayServer.WindowMode:
		return window_mode

	func set_mode(m: DisplayServer.WindowMode) -> void:
		window_mode = m

	func vsync() -> DisplayServer.VSyncMode:
		return vsync_mode

	func set_vsync(m: DisplayServer.VSyncMode) -> void:
		vsync_mode = m

	func count() -> int:
		return screen_count

	func primary() -> int:
		return 0

	func current() -> int:
		return on

	func set_current(screen: int) -> void:
		on = screen

	func size(_screen: int) -> Vector2i:
		return Vector2i(2560, 1440)

	func fit_window(screen: int) -> void:
		fitted.append(screen)


var _fake: FakeScreens
var _max_fps: int = 0


func before_each() -> void:
	_fake = FakeScreens.new()
	DisplayApply.use_screens(_fake)
	_max_fps = Engine.max_fps


func after_each() -> void:
	DisplayApply.use_screens(null)
	Engine.max_fps = _max_fps
	get_tree().root.content_scale_factor = 1.0


func test_each_window_mode() -> void:
	DisplayApply.apply_window(DisplayApply.WindowMode.EXCLUSIVE)
	assert_eq(_fake.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayApply.apply_window(DisplayApply.WindowMode.FULLSCREEN)
	assert_eq(_fake.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayApply.apply_window(DisplayApply.WindowMode.WINDOWED)
	assert_eq(_fake.window_mode, DisplayServer.WINDOW_MODE_WINDOWED)


func test_leaving_fullscreen_opens_a_window_in_the_middle_of_that_display() -> void:
	_fake.on = 1
	DisplayApply.apply_window(DisplayApply.WindowMode.WINDOWED)
	assert_eq(_fake.fitted, [1] as Array[int])
	DisplayApply.apply_window(DisplayApply.WindowMode.WINDOWED)
	assert_eq(_fake.fitted.size(), 1, "a window already open is left as the player sized it")


func test_a_window_is_most_of_the_display_and_centred() -> void:
	var r := DisplayApply.window_rect(Rect2i(0, 0, 1920, 1040))
	assert_eq(r.size, Vector2i(1536, 832))
	assert_eq(r.position, Vector2i(192, 104))
	var small := DisplayApply.window_rect(Rect2i(100, 0, 1366, 728))
	assert_eq(small.size, Vector2i(1280, 720), "never smaller than the smallest window")
	var tiny := DisplayApply.window_rect(Rect2i(0, 0, 1024, 600))
	assert_eq(tiny.size, Vector2i(1024, 600), "never bigger than the display")


func test_the_window_goes_onto_the_chosen_display() -> void:
	DisplayApply.apply(DisplayApply.WindowMode.FULLSCREEN, 1, true, 0, true)
	assert_eq(_fake.on, 1)
	DisplayApply.apply(DisplayApply.WindowMode.FULLSCREEN, 3, true, 0, true)
	assert_eq(_fake.on, 0, "a display that is gone falls back to the main one")
	_fake.on = 1
	DisplayApply.apply(DisplayApply.WindowMode.FULLSCREEN, DisplayApply.MONITOR_MAIN, true, 0, true)
	assert_eq(_fake.on, 0)
	_fake.on = 1
	DisplayApply.apply(DisplayApply.WindowMode.FULLSCREEN, DisplayApply.MONITOR_MAIN, true, 0)
	assert_eq(_fake.on, 1, "without `place` the window stays where it is")


func test_vsync_and_the_frame_rate_limit() -> void:
	DisplayApply.apply(DisplayApply.WindowMode.FULLSCREEN, DisplayApply.MONITOR_MAIN, false, 144)
	assert_eq(_fake.vsync_mode, DisplayServer.VSYNC_DISABLED)
	assert_eq(Engine.max_fps, 144)
	DisplayApply.apply(DisplayApply.WindowMode.FULLSCREEN, DisplayApply.MONITOR_MAIN, true, DisplayApply.UNLIMITED)
	assert_eq(_fake.vsync_mode, DisplayServer.VSYNC_ENABLED)
	assert_eq(Engine.max_fps, 0)


func test_the_background_draws_slower() -> void:
	_fake.focused = false
	DisplayApply.apply_frame_rate(DisplayApply.UNLIMITED)
	assert_eq(Engine.max_fps, DisplayApply.BACKGROUND_FPS)
	DisplayApply.apply_frame_rate(30)
	assert_eq(Engine.max_fps, 30)
	DisplayApply.apply_frame_rate(144)
	assert_eq(Engine.max_fps, DisplayApply.BACKGROUND_FPS)
	_fake.focused = true
	DisplayApply.apply_frame_rate(144)
	assert_eq(Engine.max_fps, 144)


func test_nearest_limit() -> void:
	assert_eq(DisplayApply.nearest_limit(0), DisplayApply.UNLIMITED)
	assert_eq(DisplayApply.nearest_limit(59), 60)
	assert_eq(DisplayApply.nearest_limit(90), 120, "the higher on a tie")
	assert_eq(DisplayApply.nearest_limit(1000), 240)


func test_the_interface_size_scales_the_2d_canvas() -> void:
	DisplayApply.apply_ui_scale(1.25)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.25, 0.0001)
	assert_almost_eq(DisplayApply.nearest_ui_scale(1.18), 1.25, 0.0001)
	assert_almost_eq(DisplayApply.nearest_ui_scale(0.1), DisplayApply.UI_SCALES[0], 0.0001)


func test_nothing_changes_without_a_real_window() -> void:
	DisplayApply.use_screens(null)
	Engine.max_fps = 77
	DisplayApply.apply(DisplayApply.WindowMode.WINDOWED, 1, false, 30, true)
	DisplayApply.apply_ui_scale(1.5)
	assert_eq(Engine.max_fps, 77, "headless (and the smoke test) never touch the window")
	assert_eq(get_tree().root.content_scale_factor, 1.0)


func test_the_fullscreen_keys() -> void:
	var f11 := InputEventKey.new()
	f11.physical_keycode = KEY_F11
	f11.pressed = true
	assert_true(WindowWatch.is_toggle(f11))
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	assert_false(WindowWatch.is_toggle(enter), "Enter alone presses buttons")
	enter.alt_pressed = true
	assert_true(WindowWatch.is_toggle(enter))
	f11.echo = true
	assert_false(WindowWatch.is_toggle(f11), "holding the key down switches once")
