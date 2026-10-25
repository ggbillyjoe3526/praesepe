class_name NavStrip
extends PanelContainer
## One line on the HUD while the nav computer flies a plan with its screen shut (design doc, "Nav computer"): which
## step of how many, what it is doing, and the key that matters ("NAV  2/3  ·  Cruise to Calder  ·  P  Pause"); amber,
## saying why, when the plan is paused. Hidden otherwise. It sits at the top of the view, centred, and is rebuilt only
## when the nav computer says something changed. Placeholder look until the art style is chosen.

const FONT_SIZE := 22
## Its top this far (px at 1080p) below the top of the screen.
const TOP := 24.0

var computer: NavComputer = null

var _line: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.04, 0.08, 0.88)
	box.set_corner_radius_all(6)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	add_theme_stylebox_override("panel", box)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(_line)
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = TOP
	visible = false


## Follows `nav`.
func attach(nav: NavComputer) -> void:
	computer = nav
	computer.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if computer != null and computer.changed.is_connected(_refresh):
		computer.changed.disconnect(_refresh)


func _refresh() -> void:
	_line.text = NavStrip.line_for(computer)
	_line.add_theme_color_override("font_color", NavPanel.PAUSED_COLOUR
			if computer.state == NavComputer.State.PAUSED else FlightHud.CRUISE_COLOUR)
	visible = not computer.is_open and computer.state != NavComputer.State.IDLE and not _line.text.is_empty()
	# Shrink back round the new words, still centred.
	reset_size()
	offset_left = -size.x * 0.5
	offset_right = size.x * 0.5


## The strip's words for `nav`'s plan as it stands.
static func line_for(nav: NavComputer) -> String:
	var step := nav.plan.now()
	if step == null:
		return ""
	var count := "%d/%d" % [nav.plan.done_count + 1, nav.plan.total()]
	if nav.state == NavComputer.State.PAUSED:
		return "NAV PAUSED  ·  %s  ·  %s  ·  P  Resume" % [count, nav.activity]
	var doing := nav.activity if not nav.activity.is_empty() else step.text()
	return "NAV  %s  ·  %s  ·  P  Pause" % [count, doing]
