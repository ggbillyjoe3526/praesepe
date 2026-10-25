class_name NavPanel
extends PanelContainer
## The nav computer's screen (design doc, "Nav computer"): where to go, how to arrive there, and the plan with what the
## computer is doing now. The same panel shows on the cockpit's dashboard (NavScreen: wide, the places and the plan
## side by side) and as a card in the chase view (compact: one above the other), so both read the same. Everything on
## it works with the mouse and with keys, and each button says its key. Text is rebuilt only when the nav computer
## says something changed while the panel shows (or once it shows again), the ways to arrive only when they or the
## pick change, and the distances four times a second while it shows; the button looks are made once. Buttons never take keyboard focus,
## so Space and the arrows keep flying the ship and working the list. Placeholder look until the art style is chosen.

const PLATE_COLOUR := Color(0.012, 0.02, 0.047, 0.94)
const EDGE_COLOUR := Color(0.165, 0.227, 0.345)
const LINE_COLOUR := Color(0.106, 0.153, 0.251)
const TEXT_COLOUR := Color(0.92, 0.95, 1.0)
const DIM_COLOUR := Color(0.66, 0.71, 0.78)
const DARK_COLOUR := Color(0.012, 0.02, 0.047)
const PLACE_COLOUR := Color(1.0, 0.86, 0.5)
const PICKED_COLOUR := FlightHud.CRUISE_COLOUR
const PICKED_FILL := Color(0.07, 0.125, 0.227)
const KEYCAP_COLOUR := Color(0.353, 0.416, 0.525)
const GO_COLOUR := FlightHud.ON_COLOUR
const PAUSED_COLOUR := FlightHud.OFF_COLOUR
## How often (s) the distances to the places are brought up to date while the panel shows.
const DISTANCE_EVERY := 0.25

## One above the other (the chase view's card) rather than side by side (the dashboard).
@export var compact: bool = false
## The size (px of the panel's own canvas) of its main text; everything else is sized from it.
@export var font_size: int = 22
## Plan rows shown; the rest are counted underneath.
@export var max_rows: int = 5

var computer: NavComputer = null
## What shows the panel, when that isn't the panel itself (NavScreen, whose viewport's Controls always count as visible).
var shown_by: Node3D = null
## The cockpit's speed screen, which the panel covers on the dashboard: its speed and flight assist are repeated in the
## panel's top line (none on the chase view's card, where the HUD shows them).
var dashboard: CockpitDisplay = null


## The diamond each place has, as its HUD marker does.
class Diamond:
	extends Control
	var colour: Color = Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.35
		draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
				c + Vector2(0, -r)]), colour, maxf(1.0, r * 0.25), true)


var _place_buttons: Array[Button] = []
var _distance_labels: Array[Label] = []
var _distance_keys: PackedInt32Array = PackedInt32Array()
var _options: HFlowContainer
var _go: Button
var _add: Button
var _state: Label
var _rows: Array[Control] = []
var _row_numbers: Array[Label] = []
var _row_texts: Array[Label] = []
var _row_tags: Array[PanelContainer] = []
var _row_tag_texts: Array[Label] = []
var _more: Label
var _activity: Label
var _pause: Button
var _clear: Button
var _distance_left: float = 0.0
var _speed_line: Label
var _assist_line: Label
## Something changed while the panel was hidden; it is brought up to date when it shows.
var _stale: bool = false
## The place row and the ways to arrive (and the pick among them) as last drawn.
var _shown_selected: int = -1
var _shown_options: Array[NavPlan.Option] = []
var _shown_choice: int = -1
## Each look a place row or a way-to-arrive pill can have (normal, hover, pressed), made once.
var _row_on: Array[StyleBoxFlat] = []
var _row_off: Array[StyleBoxFlat] = []
var _pill_on: Array[StyleBoxFlat] = []
var _pill_off: Array[StyleBoxFlat] = []


## Builds the panel for `nav` and keeps it up to date.
func attach(nav: NavComputer) -> void:
	computer = nav
	_build()
	computer.changed.connect(_on_changed)
	visibility_changed.connect(shown)
	_refresh()


## Whether the player can see the panel now.
func showing() -> bool:
	return shown_by.is_visible_in_tree() if shown_by != null else is_visible_in_tree()


## Brings the panel up to date if it changed while hidden; whatever shows it calls this when it does.
func shown() -> void:
	if _stale and showing():
		_refresh()


func _exit_tree() -> void:
	if computer != null and computer.changed.is_connected(_on_changed):
		computer.changed.disconnect(_on_changed)


func _process(delta: float) -> void:
	if computer == null or not showing():
		return
	if dashboard != null:
		# Copied only when they change, which the dashboard's own text does only when its numbers do.
		if _speed_line.text != dashboard.speed_line():
			_speed_line.text = dashboard.speed_line()
		if _assist_line.text != dashboard.assist_line():
			_assist_line.text = dashboard.assist_line()
			_assist_line.add_theme_color_override("font_color", dashboard.assist_colour())
	_distance_left -= delta
	if _distance_left > 0.0:
		return
	_distance_left = DISTANCE_EVERY
	var at := computer.ship.global_position
	for i in _distance_labels.size():
		var metres := computer.places[i].marker_distance(at)
		var key := LandmarkMarkers.distance_key(metres)
		if key != _distance_keys[i]:
			_distance_keys[i] = key
			_distance_labels[i].text = LandmarkMarkers.distance_text(metres)


func _size(share: float) -> int:
	return roundi(font_size * share)


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row_on = [_box(PICKED_FILL, Color(PICKED_COLOUR, 0.55), 0.15), _box(PICKED_FILL, Color(PICKED_COLOUR, 0.55), 0.15),
			_box(PICKED_FILL, Color(PICKED_COLOUR, 0.55), 0.15)]
	_row_off = [_box(Color(PICKED_FILL, 0.0), Color(0, 0, 0, 0), 0.15),
			_box(Color(PICKED_FILL, 0.6), Color(0, 0, 0, 0), 0.15), _box(PICKED_FILL, Color(0, 0, 0, 0), 0.15)]
	_pill_on = [_box(TEXT_COLOUR, TEXT_COLOUR, 0.6), _box(TEXT_COLOUR, TEXT_COLOUR, 0.6),
			_box(TEXT_COLOUR, TEXT_COLOUR, 0.6)]
	_pill_off = [_box(Color(TEXT_COLOUR, 0.0), KEYCAP_COLOUR, 0.6), _box(PICKED_FILL, KEYCAP_COLOUR, 0.6),
			_box(TEXT_COLOUR, TEXT_COLOUR, 0.6)]
	var plate := StyleBoxFlat.new()
	plate.bg_color = PLATE_COLOUR
	plate.border_color = EDGE_COLOUR
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(_size(0.3))
	plate.set_content_margin_all(_size(0.6))
	add_theme_stylebox_override("panel", plate)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", _size(0.25))
	add_child(page)
	var head := HBoxContainer.new()
	page.add_child(head)
	var title := _label(head, "NAV COMPUTER", 0.7, DIM_COLOUR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dashboard != null:
		head.add_theme_constant_override("separation", _size(0.8))
		_speed_line = _label(head, "", 0.8, TEXT_COLOUR)
		_assist_line = _label(head, "", 0.8, TEXT_COLOUR)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(gap)
	_label(head, "Tab  Close", 0.7, DIM_COLOUR)
	_rule(page)
	var columns := BoxContainer.new()
	columns.vertical = compact
	columns.add_theme_constant_override("separation", _size(0.7))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var places := _build_places(columns)
	_rule(columns)
	if compact:
		_build_orders(places)
	else:
		# On the dashboard's short, wide screen the ways to arrive and the orders get a column of their own.
		var orders := VBoxContainer.new()
		orders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orders.size_flags_stretch_ratio = 0.8
		orders.add_theme_constant_override("separation", _size(0.25))
		columns.add_child(orders)
		_build_orders(orders)
		_rule(columns)
	_build_plan(columns)


func _build_places(parent: Control) -> VBoxContainer:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", _size(0.12))
	parent.add_child(side)
	_label(side, "WHERE TO   Up / Down", 0.7, DIM_COLOUR)
	for i in computer.places.size():
		var row := _flat_button(side)
		row.custom_minimum_size.y = _size(1.25)
		row.pressed.connect(computer.select.bind(i))
		var line := HBoxContainer.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = _size(0.4)
		line.offset_right = -_size(0.4)
		line.add_theme_constant_override("separation", _size(0.4))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		var diamond := Diamond.new()
		diamond.colour = PLACE_COLOUR
		diamond.custom_minimum_size = Vector2(_size(0.7), _size(0.7))
		diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(diamond)
		var place := _label(line, computer.places[i].display_name, 1.0, TEXT_COLOUR)
		place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		place.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var distance := _label(line, "", 0.85, DIM_COLOUR)
		distance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_row(row, false)
		_place_buttons.append(row)
		_distance_labels.append(distance)
		_distance_keys.append(-1)
	return side


## The ways to arrive at the picked place, and Go now and Add to plan: under the places on the card, in a column of
## their own (one above the other) on the dashboard.
func _build_orders(side: VBoxContainer) -> void:
	var arrive: BoxContainer = HBoxContainer.new() if compact else VBoxContainer.new()
	arrive.add_theme_constant_override("separation", _size(0.4) if compact else _size(0.12))
	side.add_child(arrive)
	_label(arrive, "ARRIVE   Left / Right", 0.7, DIM_COLOUR)
	_options = HFlowContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("h_separation", _size(0.3))
	_options.add_theme_constant_override("v_separation", _size(0.3))
	arrive.add_child(_options)
	if not compact:
		var filler := Control.new()
		filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(filler)
	var buttons: BoxContainer = HBoxContainer.new() if compact else VBoxContainer.new()
	buttons.add_theme_constant_override("separation", _size(0.4) if compact else _size(0.25))
	side.add_child(buttons)
	_go = _action_button(buttons, "Enter  Go", true)
	_go.pressed.connect(computer.go)
	_add = _action_button(buttons, "Shift+Enter  Add", false)
	_add.pressed.connect(computer.add)


func _build_plan(parent: Control) -> void:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.0 if compact else 1.2
	side.add_theme_constant_override("separation", _size(0.12))
	parent.add_child(side)
	var head := HBoxContainer.new()
	side.add_child(head)
	_label(head, "PLAN", 0.7, DIM_COLOUR).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_state = _label(head, "", 0.7, DIM_COLOUR)
	for i in max_rows:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = _size(1.2)
		row.add_theme_constant_override("separation", _size(0.4))
		side.add_child(row)
		var number := _label(row, str(i + 1), 0.75, TEXT_COLOUR)
		number.custom_minimum_size.x = _size(1.1)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var words := _label(row, "", 1.0, TEXT_COLOUR)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.clip_text = true
		var tag := PanelContainer.new()
		var tag_box := StyleBoxFlat.new()
		tag_box.set_corner_radius_all(_size(0.15))
		tag_box.content_margin_left = _size(0.3)
		tag_box.content_margin_right = _size(0.3)
		tag.add_theme_stylebox_override("panel", tag_box)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
		var tag_words := _label(tag, "NOW", 0.6, DARK_COLOUR)
		_rows.append(row)
		_row_numbers.append(number)
		_row_texts.append(words)
		_row_tags.append(tag)
		_row_tag_texts.append(tag_words)
	_more = _label(side, "", 0.7, DIM_COLOUR)
	_activity = _label(side, "", 0.8, DIM_COLOUR)
	_activity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity.max_lines_visible = 2
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(filler)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", _size(0.4))
	side.add_child(buttons)
	_pause = _action_button(buttons, "P  Pause", false)
	_pause.pressed.connect(computer.toggle_pause)
	_clear = _action_button(buttons, "Backspace  Clear", false)
	_clear.pressed.connect(computer.clear)


func _on_changed() -> void:
	if showing():
		_refresh()
	else:
		_stale = true


func _refresh() -> void:
	_stale = false
	if computer.selected != _shown_selected:
		for i in _place_buttons.size():
			if i == computer.selected or i == _shown_selected:
				_style_row(_place_buttons[i], i == computer.selected)
		_shown_selected = computer.selected
	if not is_same(computer.options, _shown_options) or computer.choice != _shown_choice:
		_refresh_options()
	_refresh_plan()


func _refresh_options() -> void:
	if not is_same(computer.options, _shown_options):
		for child: Node in _options.get_children():
			_options.remove_child(child)
			child.queue_free()
		for i in computer.options.size():
			var pill := _pill(computer.options[i].label)
			pill.pressed.connect(computer.pick.bind(i))
			_options.add_child(pill)
		_shown_options = computer.options
		_shown_choice = -1
	for i in _options.get_child_count():
		if i == computer.choice or i == _shown_choice:
			_style_pill(_options.get_child(i) as Button, i == computer.choice)
	_shown_choice = computer.choice
	_go.disabled = computer.options.is_empty()
	_add.disabled = computer.options.is_empty()


func _refresh_plan() -> void:
	var plan := computer.plan
	var running := computer.state == NavComputer.State.RUNNING
	var paused := computer.state == NavComputer.State.PAUSED
	match computer.state:
		NavComputer.State.RUNNING:
			_state.text = "FLYING  ·  STEP %d OF %d" % [plan.done_count + 1, plan.total()]
			_state.add_theme_color_override("font_color", GO_COLOUR)
		NavComputer.State.PAUSED:
			_state.text = "PAUSED  ·  STEP %d OF %d" % [plan.done_count + 1, plan.total()]
			_state.add_theme_color_override("font_color", PAUSED_COLOUR)
		_:
			_state.text = "EMPTY  ·  PICK A PLACE" if plan.is_empty() else "READY"
			_state.add_theme_color_override("font_color", DIM_COLOUR)
	for i in _rows.size():
		var step: NavStep = plan.steps[i] if i < plan.steps.size() else null
		_rows[i].visible = step != null
		if step == null:
			continue
		var colour := step.colour()
		_row_numbers[i].text = str(plan.done_count + i + 1)
		_row_numbers[i].add_theme_color_override("font_color", colour)
		_row_texts[i].text = step.text()
		_row_texts[i].add_theme_color_override("font_color", colour)
		_row_tags[i].visible = i == 0 and (running or paused)
		_row_tag_texts[i].text = "NOW" if running else "PAUSED"
		(_row_tags[i].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = GO_COLOUR if running else PAUSED_COLOUR
	var hidden := plan.steps.size() - _rows.size()
	_more.visible = hidden > 0
	_more.text = "+ %d more" % hidden
	_activity.text = computer.activity
	_activity.visible = not computer.activity.is_empty()
	_activity.add_theme_color_override("font_color", PAUSED_COLOUR if paused else DIM_COLOUR)
	_pause.text = "P  Resume" if paused else "P  Pause"
	_pause.disabled = plan.is_empty()
	_clear.disabled = plan.is_empty()


func _label(parent: Control, words: String, share: float, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", _size(share))
	label.add_theme_color_override("font_color", colour)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _rule(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = LINE_COLOUR
	line.custom_minimum_size = Vector2(1, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _box(fill: Color, edge: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1 if edge.a > 0.0 else 0)
	box.set_corner_radius_all(_size(radius))
	box.content_margin_left = _size(0.5)
	box.content_margin_right = _size(0.5)
	return box


func _flat_button(parent: Control) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


func _style_row(row: Button, on: bool) -> void:
	var looks := _row_on if on else _row_off
	row.add_theme_stylebox_override("normal", looks[0])
	row.add_theme_stylebox_override("hover", looks[1])
	row.add_theme_stylebox_override("pressed", looks[2])
	var line := row.get_child(0)
	(line.get_child(1) as Label).add_theme_color_override("font_color", PICKED_COLOUR if on else TEXT_COLOUR)


func _pill(words: String) -> Button:
	var pill := Button.new()
	pill.text = words
	pill.focus_mode = Control.FOCUS_NONE
	pill.add_theme_font_size_override("font_size", _size(0.8))
	pill.add_theme_color_override("font_pressed_color", DARK_COLOUR)
	pill.custom_minimum_size.y = _size(1.2)
	_style_pill(pill, false)
	return pill


func _style_pill(pill: Button, on: bool) -> void:
	var looks := _pill_on if on else _pill_off
	pill.add_theme_stylebox_override("normal", looks[0])
	pill.add_theme_stylebox_override("hover", looks[1])
	pill.add_theme_stylebox_override("pressed", looks[2])
	var words_colour := DARK_COLOUR if on else TEXT_COLOUR
	pill.add_theme_color_override("font_color", words_colour)
	pill.add_theme_color_override("font_hover_color", words_colour)
	pill.add_theme_color_override("font_focus_color", words_colour)


func _action_button(parent: Control, words: String, main: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", _size(0.8))
	button.custom_minimum_size.y = _size(1.3)
	var fill := GO_COLOUR if main else Color(0, 0, 0, 0)
	var edge := GO_COLOUR if main else KEYCAP_COLOUR
	button.add_theme_stylebox_override("normal", _box(fill, edge, 0.15))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.15) if main else PICKED_FILL, edge, 0.15))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15) if main else PICKED_FILL, edge, 0.15))
	button.add_theme_stylebox_override("disabled", _box(Color(fill, fill.a * 0.35), Color(edge, 0.35), 0.15))
	var words_colour := DARK_COLOUR if main else TEXT_COLOUR
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, words_colour)
	button.add_theme_color_override("font_disabled_color", Color(words_colour, 0.5))
	parent.add_child(button)
	return button
