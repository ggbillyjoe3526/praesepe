class_name DisplayPage
extends SettingsPage
## Settings › Display: how the game fills the screen (fullscreen, exclusive fullscreen or a window), which display it
## opens on, V-Sync and a frame-rate limit. Each takes effect at once (DisplayApply).

## The window modes' names, in DisplayApply.WindowMode's order.
const MODE_NAMES: PackedStringArray = ["Fullscreen", "Exclusive fullscreen", "Windowed"]

var mode_choice: OptionButton
var monitor_choice: OptionButton
var vsync_check: CheckButton
var limit_choice: OptionButton

## The displays the monitor list was made for (it is made again when one is plugged in or out).
var _screens_listed: int = -1


func _init() -> void:
	title = "Display"
	keys = PackedStringArray(["window_mode", "monitor", "vsync", "frame_limit"])


func build() -> void:
	add_heading("Screen")
	mode_choice = add_choice("Window mode", MODE_NAMES, _pick_mode)
	monitor_choice = add_choice("Display", PackedStringArray(), _pick_monitor)
	add_hint("Fullscreen covers the whole display and switches quickly to other windows. Exclusive fullscreen can "
			+ "be a little smoother on some PCs. F11 or Alt+Enter switches between fullscreen and a window at any time.")
	add_heading("Frame rate")
	vsync_check = add_toggle("V-Sync: no tearing, at most your display's refresh rate", Settings.set_vsync)
	limit_choice = add_choice("Frame-rate limit", DisplayPage.limit_names(), _pick_limit)
	add_hint("A limit keeps your PC cooler and quieter. While the game is in the background it draws at most %d "
			% DisplayApply.BACKGROUND_FPS + "frames a second.")


func sync() -> void:
	mode_choice.select(Settings.window_mode)
	var count := DisplayApply.screens().count()
	if count != _screens_listed:
		_screens_listed = count
		SettingsPage.set_options(monitor_choice, DisplayPage.monitor_names(count))
	monitor_choice.select(Settings.monitor + 1 if Settings.monitor < count else 0)
	monitor_choice.disabled = count < 2
	vsync_check.set_pressed_no_signal(Settings.vsync)
	limit_choice.select(DisplayPage.limit_index(Settings.frame_limit))


## The display list: the main display first, then each one by number and size.
static func monitor_names(count: int) -> PackedStringArray:
	var out := PackedStringArray(["Main display"])
	for i in count:
		var size := DisplayApply.screens().size(i)
		out.append("Display %d  ·  %d × %d" % [i + 1, size.x, size.y])
	return out


## The frame-rate limits' names: no limit, then each limit.
static func limit_names() -> PackedStringArray:
	var out := PackedStringArray(["No limit"])
	for fps in DisplayApply.FRAME_LIMITS:
		out.append("%d fps" % fps)
	return out


## Where a limit sits in limit_names.
static func limit_index(fps: int) -> int:
	return DisplayApply.FRAME_LIMITS.find(fps) + 1


func _pick_mode(index: int) -> void:
	Settings.set_window_mode(index as DisplayApply.WindowMode)


func _pick_monitor(index: int) -> void:
	Settings.set_monitor(index - 1)


func _pick_limit(index: int) -> void:
	Settings.set_frame_limit(DisplayApply.UNLIMITED if index == 0 else DisplayApply.FRAME_LIMITS[index - 1])
