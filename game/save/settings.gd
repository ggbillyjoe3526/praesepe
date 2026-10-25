extends Node
## The Settings autoload: the player's own choices, kept apart from any saved game, changed in the settings menu
## (game/ui/settings/): the display (window mode, monitor, V-Sync, frame-rate limit), the interface size, comfort
## (project instructions, "Comfort": field of view, camera shake, head bob and reduce motion), the mouse (sensitivity,
## invert) and when the places' HUD markers show (LandmarkMarkers). Audio volumes and key rebinding come here later.
## The shape (to_dict and from_dict with a version and one-step migrations, damaged values ignored) follows the owner's
## katanashotgun project (scripts/settings.gd); the file is written by SaveFile, crash-safe with one backup.
##
## A change takes effect at once (`changed`; the display ones through DisplayApply), and is written when the settings
## menu or the pause screen closes or the game quits, so dragging a slider writes once. F11 and Alt+Enter switch
## between fullscreen and a window (WindowWatch, a child of this node) and write at once. The smoke test never reads or
## writes the file: it flies on the defaults.

signal changed

const VERSION := 2
const KIND := "settings"
## The vertical field of view (degrees) of both ship cameras. 60° tall is about 90° across on a 16:9 screen. Wider
## views stretch round things near the screen's edges (a planet looks oval there), so the range stops at 90°.
const FOV_MIN := 50.0
const FOV_MAX := 90.0
const DEFAULT_FOV := 60.0
## The default field of view before version 2, which stretched planets near the screen's edges.
const OLD_DEFAULT_FOV := 75.0
## Camera shake is set in steps of this (of full shake).
const SHAKE_STEP := 0.1
## Mouse sensitivity: a multiple of the flight tuning's mouse_gain (FlightControls), in steps of SENSITIVITY_STEP.
const SENSITIVITY_MIN := 0.25
const SENSITIVITY_MAX := 3.0
const SENSITIVITY_STEP := 0.05

## Where the settings are saved. Tests point it somewhere else.
var path: String = "user://settings.json"
var fov: float = DEFAULT_FOV
## Camera shake, 0 (none) to 1 (full).
var shake: float = 1.0
## The head sways with the ship's pushes in the cockpit (and will bob while walking).
var head_bob: bool = true
## Calmer cameras: no shake, no head bob, and a chase camera that swings less.
var reduce_motion: bool = false
## Fullscreen on the player's display from the first start (William, 2026-10-25).
var window_mode: DisplayApply.WindowMode = DisplayApply.WindowMode.FULLSCREEN
## The fullscreen kind F11 goes back to from a window.
var last_fullscreen: DisplayApply.WindowMode = DisplayApply.WindowMode.FULLSCREEN
## The display the game opens on (an index), or DisplayApply.MONITOR_MAIN.
var monitor: int = DisplayApply.MONITOR_MAIN
var vsync: bool = true
## Frames a second at most, or DisplayApply.UNLIMITED.
var frame_limit: int = DisplayApply.UNLIMITED
## How far the mouse steers, times the flight tuning's.
var sensitivity: float = 1.0
## Mouse up points the nose down instead of up.
var invert_mouse: bool = false
## The size of the HUD, its text and the menus, times the size made for the screen (one of DisplayApply.UI_SCALES).
var ui_scale: float = 1.0
## When the places' HUD markers show their diamonds and their names (LandmarkMarkers.Show): always, only when the
## place is near or looked at, or never. Names default to near or looked at, so the screen stays clear.
var marker_icons: int = LandmarkMarkers.Show.ALWAYS
var marker_names: int = LandmarkMarkers.Show.NEARBY

var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(WindowWatch.new())
	if not Game.launch_args.smoke:
		load_saved()
	apply_display(true)


func _notification(what: int) -> void:
	# Closing the window (or Alt+F4) writes any change; the pause screen's Quit button commits first itself.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		commit()


## How much camera shake to show, after reduce motion.
func shake_amount() -> float:
	return 0.0 if reduce_motion else shake


## Whether the head moves at all, after reduce motion.
func head_moves() -> bool:
	return head_bob and not reduce_motion


func set_fov(value: float) -> void:
	_change(&"fov", clampf(roundf(value), FOV_MIN, FOV_MAX))


func set_shake(value: float) -> void:
	_change(&"shake", clampf(snappedf(value, SHAKE_STEP), 0.0, 1.0))


func set_head_bob(on: bool) -> void:
	_change(&"head_bob", on)


func set_reduce_motion(on: bool) -> void:
	_change(&"reduce_motion", on)


## Fullscreen, exclusive fullscreen or a window; a fullscreen kind is remembered as the one F11 goes back to.
func set_window_mode(mode: DisplayApply.WindowMode) -> void:
	if mode != DisplayApply.WindowMode.WINDOWED:
		last_fullscreen = mode
	_change(&"window_mode", mode)
	DisplayApply.apply_window(window_mode)


## F11 or Alt+Enter: a window from fullscreen, or the last fullscreen kind from a window.
func toggle_fullscreen() -> void:
	if window_mode == DisplayApply.WindowMode.WINDOWED:
		set_window_mode(last_fullscreen)
	else:
		set_window_mode(DisplayApply.WindowMode.WINDOWED)


## The window moves to display `screen` (or the main one, DisplayApply.MONITOR_MAIN) and opens there from now on.
func set_monitor(screen: int) -> void:
	_change(&"monitor", clampi(screen, DisplayApply.MONITOR_MAIN, DisplayApply.MONITOR_MOST))
	apply_display(true)


func set_vsync(on: bool) -> void:
	_change(&"vsync", on)
	apply_display()


func set_frame_limit(fps: int) -> void:
	_change(&"frame_limit", DisplayApply.nearest_limit(fps))
	DisplayApply.apply_frame_rate(frame_limit)


func set_ui_scale(value: float) -> void:
	_change(&"ui_scale", DisplayApply.nearest_ui_scale(value))
	DisplayApply.apply_ui_scale(ui_scale)


func set_sensitivity(value: float) -> void:
	_change(&"sensitivity", clampf(snappedf(value, SENSITIVITY_STEP), SENSITIVITY_MIN, SENSITIVITY_MAX))


func set_invert_mouse(on: bool) -> void:
	_change(&"invert_mouse", on)


func set_marker_icons(mode: int) -> void:
	_change(&"marker_icons", clampi(mode, 0, LandmarkMarkers.Show.size() - 1))


func set_marker_names(mode: int) -> void:
	_change(&"marker_names", clampi(mode, 0, LandmarkMarkers.Show.size() - 1))


## The display settings into the window (with `place`, onto the chosen display first), and the interface size.
func apply_display(place: bool = false) -> void:
	DisplayApply.apply(window_mode, monitor, vsync, frame_limit, place)
	DisplayApply.apply_ui_scale(ui_scale)


## Back to the defaults (the file is written on the next commit()). With `keys`, only those settings (a page of the
## settings menu); the window follows at once.
func reset(keys: PackedStringArray = PackedStringArray()) -> void:
	var d := _defaults()
	if not keys.is_empty():
		var only := {}
		for k in keys:
			if d.has(k):
				only[k] = d[k]
			else:
				push_warning("settings: no setting %s to reset" % k)
		d = only
	from_dict(d)
	if d.has("window_mode") and window_mode != DisplayApply.WindowMode.WINDOWED:
		last_fullscreen = window_mode
	_dirty = true
	changed.emit()
	apply_display(d.has("monitor"))


func _change(key: StringName, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	_dirty = true
	changed.emit()


## Writes the settings if anything changed since the last write. Returns false only when a write failed.
func commit() -> bool:
	if not _dirty or Game.launch_args.smoke:
		return true
	if not SaveFile.write(path, KIND, VERSION, to_dict()):
		return false
	_dirty = false
	return true


## Reads the saved settings over the defaults. A missing or unreadable file keeps the defaults and is never wiped:
## SaveFile moves a damaged copy aside on the next write. Returns false when nothing could be read.
func load_saved() -> bool:
	from_dict(_defaults())
	var r := SaveFile.read(path, KIND)
	if r.ok:
		var d: Dictionary = r.data
		# The file's header holds its version too; it counts when the payload lacks a usable one.
		if not _is_num(d.get("v")):
			d["v"] = r.version
		from_dict(d)
	_dirty = false
	changed.emit()
	return r.ok


func to_dict() -> Dictionary:
	return {
		"v": VERSION, "fov": fov, "shake": shake, "head_bob": head_bob, "reduce_motion": reduce_motion,
		"window_mode": int(window_mode), "last_fullscreen": int(last_fullscreen), "monitor": monitor, "vsync": vsync,
		"frame_limit": frame_limit, "sensitivity": sensitivity, "invert_mouse": invert_mouse, "ui_scale": ui_scale,
		"marker_icons": marker_icons, "marker_names": marker_names,
	}


## Reads `d` over the current values. Anything missing, of the wrong type or out of range keeps its current value, so
## an old or damaged file never breaks the game. JSON gives numbers back as floats.
func from_dict(d: Dictionary) -> void:
	# Migrations, one step at a time, as VERSION grows (after katanashotgun's _migrate_v1 and so on).
	if _is_num(d.get("v")) and int(d.v) < 2:
		d = _migrate_v1(d)
	if _is_num(d.get("fov")):
		fov = clampf(roundf(float(d.fov)), FOV_MIN, FOV_MAX)
	if _is_num(d.get("shake")):
		shake = clampf(float(d.shake), 0.0, 1.0)
	if d.get("head_bob") is bool:
		head_bob = d.head_bob
	if d.get("reduce_motion") is bool:
		reduce_motion = d.reduce_motion
	if _is_whole(d.get("window_mode"), 0, DisplayApply.WindowMode.size() - 1):
		window_mode = int(d.window_mode) as DisplayApply.WindowMode
	if _is_whole(d.get("last_fullscreen"), 0, DisplayApply.WindowMode.size() - 1) \
			and int(d.last_fullscreen) != DisplayApply.WindowMode.WINDOWED:
		last_fullscreen = int(d.last_fullscreen) as DisplayApply.WindowMode
	elif not d.has("last_fullscreen") and d.has("window_mode") and window_mode != DisplayApply.WindowMode.WINDOWED:
		# A file without it: F11 goes back to the fullscreen kind the game is in.
		last_fullscreen = window_mode
	if _is_whole(d.get("monitor"), DisplayApply.MONITOR_MAIN, DisplayApply.MONITOR_MOST):
		monitor = int(d.monitor)
	if d.get("vsync") is bool:
		vsync = d.vsync
	if _is_num(d.get("frame_limit")) and float(d.frame_limit) >= 0.0:
		frame_limit = DisplayApply.nearest_limit(roundi(float(d.frame_limit)))
	if _is_num(d.get("sensitivity")):
		sensitivity = clampf(snappedf(float(d.sensitivity), SENSITIVITY_STEP), SENSITIVITY_MIN, SENSITIVITY_MAX)
	if d.get("invert_mouse") is bool:
		invert_mouse = d.invert_mouse
	if _is_num(d.get("ui_scale")):
		ui_scale = DisplayApply.nearest_ui_scale(float(d.ui_scale))
	if _is_whole(d.get("marker_icons"), 0, LandmarkMarkers.Show.size() - 1):
		marker_icons = int(d.marker_icons)
	if _is_whole(d.get("marker_names"), 0, LandmarkMarkers.Show.size() - 1):
		marker_names = int(d.marker_names)


## Version 1 saved the field of view whenever any setting changed, so the old default (75°) almost always means the
## player never moved the slider: it moves to the new default. Any other choice is kept, within the new range. The
## file itself stays version 1 until the next change is written, so this runs again on each load until then (harmless).
static func _migrate_v1(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	if _is_num(out.get("fov")) and is_equal_approx(roundf(float(out.fov)), OLD_DEFAULT_FOV):
		out.erase("fov")
	out["v"] = 2
	return out


func _defaults() -> Dictionary:
	return {
		"fov": DEFAULT_FOV, "shake": 1.0, "head_bob": true, "reduce_motion": false,
		"window_mode": DisplayApply.WindowMode.FULLSCREEN, "last_fullscreen": DisplayApply.WindowMode.FULLSCREEN,
		"monitor": DisplayApply.MONITOR_MAIN, "vsync": true, "frame_limit": DisplayApply.UNLIMITED,
		"sensitivity": 1.0, "invert_mouse": false, "ui_scale": 1.0, "marker_icons": LandmarkMarkers.Show.ALWAYS,
		"marker_names": LandmarkMarkers.Show.NEARBY,
	}


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


## A whole number from `low` to `high` (JSON gives it back as a float).
static func _is_whole(v: Variant, low: int, high: int) -> bool:
	return _is_num(v) and is_equal_approx(float(v), roundf(float(v))) and float(v) >= low and float(v) <= high
