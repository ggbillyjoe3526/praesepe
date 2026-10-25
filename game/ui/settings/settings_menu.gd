class_name SettingsMenu
extends Control
## The settings menu, opened from the pause screen: a button for each page down the left (PAGES), the page picked on
## the right, and Defaults (this page's settings back to their defaults) and Back along the bottom. Every change takes
## effect at once; the file is written when the menu closes (Settings.commit()). Esc or Back closes it (`closed`), back
## to whatever opened it (the pause screen). It works while the game is paused. Sizes are in px at 1080p; the plate
## shrinks to fit a smaller screen or a bigger interface size, and the page scrolls.
##
## Adding a page: write a script extending SettingsPage (game/ui/settings/settings_page.gd) and add it to PAGES.

signal closed

## The pages, in the order their buttons show.
const PAGES: Array[Script] = [
	preload("res://game/ui/settings/display_page.gd"),
	preload("res://game/ui/settings/interface_page.gd"),
	preload("res://game/ui/settings/comfort_page.gd"),
	preload("res://game/ui/settings/controls_page.gd"),
]
const PLATE_COLOUR := Color(0.03, 0.04, 0.08, 0.97)
const PLATE_MARGIN := 36.0
const PLATE_CORNER := 10
const PLATE_SIZE := Vector2(1240.0, 820.0)
const SIDEBAR_WIDTH := 240.0
const GAP := 24
const TITLE_SIZE := 44
const BUTTON_HEIGHT := 60.0
const BUTTON_TEXT_SIZE := 26

## The pages, in PAGES's order (public for the tests and the smoke test).
var pages: Array[SettingsPage] = []
var page_buttons: Array[Button] = []
## The page showing.
var current: int = 0

var _back: Button
var _plate: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	show_page(0)
	resized.connect(_fit)
	_fit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


## Opens on the page last shown, with the keyboard on its button.
func open() -> void:
	# Brought up to date (a display plugged in since the menu was last open shows in the list).
	for page in pages:
		page.sync()
	visible = true
	page_buttons[current].grab_focus()


## Writes any change and tells the pause screen.
func close() -> void:
	if not visible:
		return
	visible = false
	Settings.commit()
	closed.emit()


func show_page(index: int) -> void:
	current = clampi(index, 0, pages.size() - 1)
	for i in pages.size():
		pages[i].visible = i == current
		page_buttons[i].set_pressed_no_signal(i == current)
	if is_visible_in_tree():
		page_buttons[current].grab_focus()


func _build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var plate := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PLATE_COLOUR
	box.set_corner_radius_all(PLATE_CORNER)
	box.set_content_margin_all(PLATE_MARGIN)
	plate.add_theme_stylebox_override("panel", box)
	centre.add_child(plate)
	_plate = plate
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	plate.add_child(column)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	column.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", GAP * 2)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0)
	body.add_child(sidebar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var stack := MarginContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("margin_right", GAP)
	scroll.add_child(stack)
	var group := ButtonGroup.new()
	for i in PAGES.size():
		var page: SettingsPage = PAGES[i].new()
		stack.add_child(page)
		pages.append(page)
		var b := _button(sidebar, page.title)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(show_page.bind(i))
		page_buttons.append(b)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", GAP)
	column.add_child(bottom)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var reset := _button(bottom, "Defaults for this page")
	reset.pressed.connect(func() -> void: pages[current].defaults())
	_back = _button(bottom, "Back (Esc)")
	_back.custom_minimum_size.x = SIDEBAR_WIDTH
	_back.pressed.connect(close)


## The plate at its full size, or as much as fits on the screen.
func _fit() -> void:
	if _plate != null:
		_plate.custom_minimum_size = PLATE_SIZE.min(size - Vector2(GAP, GAP) * 2.0)


func _button(parent: Control, words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", BUTTON_TEXT_SIZE)
	parent.add_child(b)
	return b
