extends Node
## The Settings autoload: the player's own choices, kept apart from any saved game. For now the view and comfort
## settings (project instructions, "Comfort"): field of view, camera shake, head bob and reduce motion, changed on the
## pause screen. The settings menu adds audio, video and keys here later. The shape (to_dict and from_dict with a
## version and one-step migrations, damaged values ignored) follows the owner's katanashotgun project
## (scripts/settings.gd); the file is written by SaveFile, crash-safe with one backup.
##
## A change takes effect at once (`changed`), and is written when the pause screen closes or the game quits, so
## dragging a slider writes once. The smoke test never reads or writes the file: it flies on the defaults.

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

## Where the settings are saved. Tests point it somewhere else.
var path: String = "user://settings.json"
var fov: float = DEFAULT_FOV
## Camera shake, 0 (none) to 1 (full).
var shake: float = 1.0
## The head sways with the ship's pushes in the cockpit (and will bob while walking).
var head_bob: bool = true
## Calmer cameras: no shake, no head bob, and a chase camera that swings less.
var reduce_motion: bool = false

var _dirty: bool = false


func _ready() -> void:
	if not Game.launch_args.smoke:
		load_saved()


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


## Back to the defaults (the file is written on the next commit()).
func reset() -> void:
	from_dict(_defaults())
	_dirty = true
	changed.emit()


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
		from_dict(r.data)
	_dirty = false
	changed.emit()
	return r.ok


func to_dict() -> Dictionary:
	return {"v": VERSION, "fov": fov, "shake": shake, "head_bob": head_bob, "reduce_motion": reduce_motion}


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


## Version 1 saved the field of view whenever any setting changed, so the old default (75°) almost always means the
## player never moved the slider: it moves to the new default. Any other choice is kept, within the new range.
static func _migrate_v1(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	if _is_num(out.get("fov")) and is_equal_approx(float(out.fov), OLD_DEFAULT_FOV):
		out.erase("fov")
	out["v"] = 2
	return out


func _defaults() -> Dictionary:
	return {"fov": DEFAULT_FOV, "shake": 1.0, "head_bob": true, "reduce_motion": false}


static func _is_num(v: Variant) -> bool:
	return v is float or v is int
