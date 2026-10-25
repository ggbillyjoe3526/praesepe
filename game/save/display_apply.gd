class_name DisplayApply
## Puts the display settings into the game: the window (its monitor and mode), V-Sync, the frame-rate limit and the
## interface size. From the
## owner's Airsoft-Next project (game/save/settings_apply.gd, its display half), adapted: the game starts fullscreen on
## the player's display, and a window opens at a comfortable size in the middle of its screen. Nothing is cached, so a
## change shows at once. The window goes through `screens()`, which a test swaps for a stand-in: the headless display
## server has no screens and never changes mode, so there (and in the smoke test) nothing here touches the engine.

## Fullscreen is the borderless kind (the window covers the whole display, so switching to other windows is quick);
## exclusive fullscreen takes the display over (on some PCs a little smoother); windowed is an ordinary window.
enum WindowMode { FULLSCREEN, EXCLUSIVE, WINDOWED }

## The frame-rate limits offered besides no limit (UNLIMITED); a saved number that isn't one reads as the nearest.
const FRAME_LIMITS: Array[int] = [30, 60, 120, 144, 165, 240]
const UNLIMITED := 0
## Frames a second at most while the game is in the background (unfocused or minimised); it is paused then anyway.
const BACKGROUND_FPS := 30
## The display the game opens on: MONITOR_MAIN is the system's main display; a saved index above MONITOR_MOST is junk.
const MONITOR_MAIN := -1
const MONITOR_MOST := 63
## A window covers this share of its display's usable area (inside the taskbar), centred, and is never smaller than
## WINDOW_MIN.
const WINDOW_SHARE := 0.8
const WINDOW_MIN := Vector2i(1280, 720)
## The interface sizes offered: the HUD, its text and the menus, times the size made for the screen (the 2D canvas is
## laid out for 1920 × 1080 and stretched to fit the window, so 100% already grows with the screen).
## Bigger than 125% and the HUD's prompts would crowd the middle of the view.
const UI_SCALES: Array[float] = [0.8, 0.9, 1.0, 1.1, 1.25]

static var _screens: Screens = null


## Everything: with `place` (at start, and on picking a monitor) the window goes onto the chosen display first (the
## main one when that display is gone, so it is never off-screen).
static func apply(mode: WindowMode, monitor: int, vsync: bool, frame_limit: int, place: bool = false) -> void:
	var ds := screens()
	if not ds.available():
		return
	if place:
		var target := monitor_now(monitor, ds)
		if ds.current() != target:
			ds.set_current(target)
			if ds.mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				ds.fit_window(target)
	apply_window(mode)
	var want := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	if ds.vsync() != want:
		ds.set_vsync(want)
	apply_frame_rate(frame_limit)


## The window's mode. Leaving fullscreen opens a window at a comfortable size in the middle of the display it was on.
static func apply_window(mode: WindowMode) -> void:
	var ds := screens()
	if not ds.available():
		return
	var now := ds.mode()
	match mode:
		WindowMode.FULLSCREEN:
			if now != DisplayServer.WINDOW_MODE_FULLSCREEN:
				ds.set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.EXCLUSIVE:
			if now != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				ds.set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			if now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				var at := ds.current()
				ds.set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				ds.fit_window(at)


## Engine.max_fps: the limit, or BACKGROUND_FPS (the lower of the two) while the game is in the background. The
## game's 60 ticks a second don't depend on it: a slower frame runs more ticks.
static func apply_frame_rate(frame_limit: int) -> void:
	var ds := screens()
	if not ds.available():
		return
	var limit := frame_limit
	if not ds.focused:
		limit = BACKGROUND_FPS if limit == UNLIMITED else mini(limit, BACKGROUND_FPS)
	if Engine.max_fps != limit:
		Engine.max_fps = limit


## The interface size: the root window's content scale, which grows every Control and 2D drawing but not the 3D view.
static func apply_ui_scale(scale: float) -> void:
	var ds := screens()
	if not ds.available():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and not is_equal_approx(tree.root.content_scale_factor, scale):
		tree.root.content_scale_factor = scale


## An interface size as one of UI_SCALES: the nearest.
static func nearest_ui_scale(scale: float) -> float:
	var best := UI_SCALES[0]
	for s in UI_SCALES:
		if absf(s - scale) < absf(best - scale):
			best = s
	return best


## The display `monitor` names now: itself, or the main one when it is gone or none was chosen.
static func monitor_now(monitor: int, ds: Screens = null) -> int:
	if ds == null:
		ds = screens()
	if monitor == MONITOR_MAIN or monitor < 0 or monitor >= ds.count():
		return ds.primary()
	return monitor


## A frame-rate limit as one of those offered: UNLIMITED, or the nearest of FRAME_LIMITS (the higher on a tie).
static func nearest_limit(fps: int) -> int:
	if fps <= 0:
		return UNLIMITED
	var best := FRAME_LIMITS[0]
	for f in FRAME_LIMITS:
		if absi(f - fps) <= absi(best - fps):
			best = f
	return best


## A window's size and place on a display's usable area `area`: WINDOW_SHARE of it (never under WINDOW_MIN, never
## over the area), in the middle.
static func window_rect(area: Rect2i) -> Rect2i:
	var size := Vector2i((Vector2(area.size) * WINDOW_SHARE).round())
	size = size.max(WINDOW_MIN).min(area.size)
	return Rect2i(area.position + (area.size - size) / 2, size)


## The game's window calls, or the stand-in a test gave.
static func screens() -> Screens:
	if _screens == null:
		_screens = Screens.new()
	return _screens


## A test's stand-in for the window calls; null goes back to the real ones.
static func use_screens(stand_in: Screens) -> void:
	_screens = stand_in


## The window's DisplayServer calls, one each, so a test can stand in for them; and whether the game is in front.
class Screens:
	extends RefCounted
	## False while the window is unfocused or minimised (WindowWatch).
	var focused: bool = true

	## Whether there is a real window to change: not headless (unit tests, CI) and not the smoke test.
	func available() -> bool:
		return DisplayServer.get_name() != "headless" and not Game.launch_args.smoke

	func mode() -> DisplayServer.WindowMode:
		return DisplayServer.window_get_mode()

	func set_mode(m: DisplayServer.WindowMode) -> void:
		DisplayServer.window_set_mode(m)

	func vsync() -> DisplayServer.VSyncMode:
		return DisplayServer.window_get_vsync_mode()

	func set_vsync(m: DisplayServer.VSyncMode) -> void:
		DisplayServer.window_set_vsync_mode(m)

	## The number of displays.
	func count() -> int:
		return DisplayServer.get_screen_count()

	func primary() -> int:
		return DisplayServer.get_primary_screen()

	## The display the window is on.
	func current() -> int:
		return DisplayServer.window_get_current_screen()

	func set_current(screen: int) -> void:
		DisplayServer.window_set_current_screen(screen)

	## A display's size in pixels.
	func size(screen: int) -> Vector2i:
		return DisplayServer.screen_get_size(screen)

	## Sizes the window and puts it in the middle of display `screen` (DisplayApply.window_rect).
	func fit_window(screen: int) -> void:
		var r := DisplayApply.window_rect(DisplayServer.screen_get_usable_rect(screen))
		DisplayServer.window_set_size(r.size)
		DisplayServer.window_set_position(r.position)
