class_name TransitionScreen
extends CanvasLayer
## The transition screen for docking and landing (design doc, "Landing: a prompt, then a transition screen"): the view
## fades to black, names where the ship is going ("Docking at Halfway Station"), then where it is and whether the game
## saved, and fades back in at the berth. Arrivals sets how far it covers the view (`cover`) every physics tick, so it
## stands still while paused. It sits under the pause screen. Placeholder look until the art style is chosen.

const LAYER := 40
const TITLE_SIZE := 52
const LINE_SIZE := 26
const GAP := 18
const LINE_COLOUR := Color(0.7, 0.75, 0.85)
const SAVED_COLOUR := Color(0.55, 0.95, 0.75)
const NOT_SAVED_COLOUR := Color(1.0, 0.72, 0.3)

## How far the screen covers the view: 0 (not at all, hidden) to 1 (black).
var cover: float = 0.0:
	set(value):
		cover = value
		_apply()

var _shade: ColorRect
var _words: Control
var _title: Label
var _line: Label


func _ready() -> void:
	layer = LAYER
	_build()
	Events.arrived.connect(_on_arrived)
	Events.game_saved.connect(_on_saved)
	_apply()


func _exit_tree() -> void:
	if Events.arrived.is_connected(_on_arrived):
		Events.arrived.disconnect(_on_arrived)
	if Events.game_saved.is_connected(_on_saved):
		Events.game_saved.disconnect(_on_saved)


## Starts a transition to `port`: its words, before the fade begins.
func begin(port: Port) -> void:
	_title.text = TransitionScreen.going_text(port.kind, port.place_name())
	_line.text = ""


## What the screen says on the way in.
static func going_text(kind: Port.Kind, place: String) -> String:
	return ("Docking at %s" if kind == Port.Kind.DOCK else "Landing at %s") % place


## What it says once the ship is there.
static func arrived_text(kind: Port.Kind, place: String) -> String:
	return ("Docked at %s" if kind == Port.Kind.DOCK else "Landed at %s") % place


## The words under it once the autosave has run.
static func saved_text(ok: bool) -> String:
	return "Game saved" if ok else "The game couldn't be saved this time. Your last save is safe"


## The words now shown, for the smoke test: the title and the line under it.
func shown() -> PackedStringArray:
	return PackedStringArray([_title.text, _line.text])


func _on_arrived(port: Port) -> void:
	_title.text = TransitionScreen.arrived_text(port.kind, port.place_name())


func _on_saved(ok: bool) -> void:
	_line.text = TransitionScreen.saved_text(ok)
	_line.add_theme_color_override("font_color", SAVED_COLOUR if ok else NOT_SAVED_COLOUR)


func _apply() -> void:
	if _shade == null:
		return
	visible = cover > 0.0
	_shade.color = Color(0.0, 0.0, 0.0, cover)
	# The words come in over the last part of the fade, so they never sit on a half-faded view.
	_words.modulate.a = clampf(cover * 2.0 - 1.0, 0.0, 1.0)


func _build() -> void:
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(list)
	_words = list
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(_title)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", LINE_SIZE)
	_line.add_theme_color_override("font_color", LINE_COLOUR)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(_line)
