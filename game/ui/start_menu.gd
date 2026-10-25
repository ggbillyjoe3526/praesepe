class_name StartMenu
extends Control
## The start menu on the title screen (design doc, "Starting a game"): Continue, New game, Settings and Quit. New game
## opens the ship choice, one card per starter ship (StarterShips) with its "Great for:" hint; choosing one starts the
## game in it, after asking first when that would replace a saved game. Continue is there only when a saved game can
## be read; when one exists but can't be, it says why and keeps the file. Settings opens the settings menu
## (SettingsMenu) over it, as the pause screen does. For the rest the menu only says what was chosen (its signals); the
## title screen does it. Esc goes back a page. Its look is a placeholder, like the pause screen's.

signal continue_chosen
signal new_game_chosen(ship: StringName)
signal quit_chosen

enum Page {
	MAIN, ## Continue, New game, Settings, Quit.
	SETTINGS, ## The settings menu.
	SHIPS, ## Choose your ship.
	REPLACE, ## A new game would replace the saved game: start it, or go back.
}
## What the title screen found in the save folder.
enum SaveState {
	NONE, ## No saved game.
	GOOD, ## A saved game that can be continued.
	DAMAGED, ## A saved game that can't be read (it is kept, never deleted).
	LOCKED, ## A saved game another program holds, so it can't be opened.
	NEWER, ## A saved game from a newer version of the game (it is kept, never deleted).
}

const PLATE_COLOUR := Color(0.03, 0.04, 0.08, 0.92)
const CARD_COLOUR := Color(0.06, 0.08, 0.14, 0.96)
const TITLE_COLOUR := Color(0.92, 0.95, 1.0)
const ACCENT_COLOUR := Color(0.55, 0.8, 1.0)
const NOTE_COLOUR := Color(1.0, 0.72, 0.3)
const QUIET_COLOUR := Color(0.7, 0.75, 0.85)
## Sizes in px at 1080p.
const TITLE_SIZE := 84
const HEADING_SIZE := 44
const PLATE_MARGIN := 36.0
const PLATE_WIDTH := 460.0
const CARD_WIDTH := 560.0
const GAP := 16
const BUTTON_HEIGHT := 64.0
const BUTTON_TEXT_SIZE := 28
const SHIP_NAME_SIZE := 40
const GREAT_FOR_SIZE := 26
const TEXT_SIZE := 22
const NOTE_SIZE := 20
const VERSION_SIZE := 18
const EDGE := 24.0
const TITLE_TOP := 120.0

## The ships to choose from. Set before the menu enters the tree.
@export var ships: StarterShips
## What is in the save folder. Set with set_save_state().
var save_state: SaveState = SaveState.NONE
var page: Page = Page.MAIN

## The buttons (public for the tests).
var continue_button: Button
var new_game_button: Button
var settings_button: Button
var quit_button: Button
## One per ship, in the order of `ships`.
var ship_buttons: Array[Button] = []
var ships_back_button: Button
var replace_button: Button
var replace_back_button: Button
## The settings menu, a child so it hears Esc before the menu does (public for the tests).
var settings_menu: SettingsMenu

var _pages: Dictionary[Page, Control] = {}
var _title: Label
var _save_note: Label
var _replace_words: Label
## The ship chosen while asking whether to replace the saved game.
var _chosen: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	set_save_state(save_state)
	show_page(Page.MAIN)


## Shows what was found in the save folder: Continue only for a good save, and a note for one that can't be read.
func set_save_state(state: SaveState) -> void:
	save_state = state
	if continue_button == null:
		return
	continue_button.visible = state == SaveState.GOOD
	_save_note.visible = state != SaveState.NONE and state != SaveState.GOOD
	_save_note.text = StartMenu.save_note(state)
	if page == Page.MAIN:
		_focus_first()


## The note shown under the menu for a save that can't be continued, or "".
static func save_note(state: SaveState) -> String:
	match state:
		SaveState.DAMAGED:
			return "Your saved game couldn't be read. It stays in the save folder; a new game won't delete it."
		SaveState.LOCKED:
			return "Your saved game is open in another program. Close that program, then restart the game to continue."
		SaveState.NEWER:
			return "Your saved game is from a newer version of the game. Play it there; a new game here won't delete it."
	return ""


func show_page(to: Page) -> void:
	page = to
	for p: Page in _pages:
		_pages[p].visible = p == to
	# The game's name heads the first page only; the others have their own heading or question.
	_title.visible = to == Page.MAIN
	if to == Page.SETTINGS:
		settings_menu.open()
	else:
		settings_menu.visible = false
		_focus_first()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"pause"):
		return
	match page:
		Page.SHIPS:
			show_page(Page.MAIN)
		Page.REPLACE:
			show_page(Page.SHIPS)
		_:
			return
	get_viewport().set_input_as_handled()


func _focus_first() -> void:
	var first: Button = null
	match page:
		Page.MAIN:
			first = continue_button if continue_button.visible else new_game_button
		Page.SHIPS:
			first = ship_buttons[0] if not ship_buttons.is_empty() else ships_back_button
		Page.REPLACE:
			first = replace_back_button
	if first != null and is_inside_tree():
		first.grab_focus()


func _choose_ship(id: StringName) -> void:
	if save_state == SaveState.NONE:
		new_game_chosen.emit(id)
		return
	# Starting would write over the saved game (or set a damaged one aside): ask first.
	_chosen = id
	var ship := ships.find(id)
	_replace_words.text = StartMenu.replace_question(ship.display_name if ship != null else String(id), save_state)
	# A saved game another program holds can't be written over, so a new game couldn't be saved either.
	replace_button.visible = save_state != SaveState.LOCKED
	show_page(Page.REPLACE)


## What the menu asks before a new game in `ship_name` takes the place of the saved game.
static func replace_question(ship_name: String, state: SaveState) -> String:
	if state == SaveState.GOOD:
		return "Start a new game in the %s?\nThis replaces your saved game." % ship_name
	if state == SaveState.LOCKED:
		return "Your saved game is open in another program, so a new game couldn't be saved.\nClose that program, " \
				+ "then restart the game."
	return "Start a new game in the %s?\nYour old saved game is set aside in the save folder, never deleted." \
			% ship_name


func _build() -> void:
	_title = _label(self, ProjectSettings.get_setting("application/config/name", "Project Praesepe"), TITLE_SIZE,
			TITLE_COLOUR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = TITLE_TOP
	var version := _label(self, String(ProjectSettings.get_setting("application/config/version", "")), VERSION_SIZE,
			QUIET_COLOUR)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -EDGE
	version.offset_bottom = -EDGE
	_pages[Page.MAIN] = _build_main()
	_pages[Page.SHIPS] = _build_ships()
	_pages[Page.REPLACE] = _build_replace()
	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	settings_menu.closed.connect(_settings_closed)
	add_child(settings_menu)


## Back from the settings menu (it saved any change as it closed): the first page, on its Settings button.
func _settings_closed() -> void:
	show_page(Page.MAIN)
	settings_button.grab_focus()


func _build_main() -> Control:
	var plate := _plate(PLATE_WIDTH)
	var list: VBoxContainer = plate.get_child(0)
	continue_button = _button(list, "Continue")
	continue_button.pressed.connect(continue_chosen.emit)
	new_game_button = _button(list, "New game")
	new_game_button.pressed.connect(show_page.bind(Page.SHIPS))
	settings_button = _button(list, "Settings")
	settings_button.pressed.connect(show_page.bind(Page.SETTINGS))
	quit_button = _button(list, "Quit")
	quit_button.pressed.connect(quit_chosen.emit)
	_save_note = _label(list, "", NOTE_SIZE, NOTE_COLOUR)
	_save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return _centre_of(plate)


func _build_ships() -> Control:
	var page_box := VBoxContainer.new()
	page_box.add_theme_constant_override("separation", GAP * 2)
	page_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var heading := _label(page_box, "Choose your ship", HEADING_SIZE, TITLE_COLOUR)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP * 2)
	page_box.add_child(row)
	if ships != null:
		for ship: ShipClass in ships.ships:
			_ship_card(row, ship)
	var back_row := CenterContainer.new()
	page_box.add_child(back_row)
	ships_back_button = _button(back_row, "Back (Esc)")
	ships_back_button.custom_minimum_size.x = PLATE_WIDTH * 0.6
	ships_back_button.pressed.connect(show_page.bind(Page.MAIN))
	return _centre_of(page_box)


func _ship_card(parent: Control, ship: ShipClass) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(CARD_COLOUR))
	parent.add_child(card)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_child(list)
	_label(list, ship.display_name, SHIP_NAME_SIZE, TITLE_COLOUR)
	_label(list, "Great for: %s" % ship.great_for, GREAT_FOR_SIZE, ACCENT_COLOUR)
	var summary := _label(list, ship.summary, TEXT_SIZE, TITLE_COLOUR)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var strengths := _label(list, "Strengths: %s" % ship.strengths, TEXT_SIZE, QUIET_COLOUR)
	strengths.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var trade_offs := _label(list, "Trade-offs: %s" % ship.trade_offs, TEXT_SIZE, QUIET_COLOUR)
	trade_offs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fly := _button(list, "Fly the %s" % ship.display_name)
	fly.pressed.connect(_choose_ship.bind(ship.id))
	ship_buttons.append(fly)


func _build_replace() -> Control:
	var plate := _plate(PLATE_WIDTH * 1.4)
	var list: VBoxContainer = plate.get_child(0)
	_replace_words = _label(list, "", TEXT_SIZE + 4, TITLE_COLOUR)
	_replace_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_replace_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replace_button = _button(list, "Start new game")
	replace_button.pressed.connect(func() -> void: new_game_chosen.emit(_chosen))
	replace_back_button = _button(list, "Back (Esc)")
	replace_back_button.pressed.connect(show_page.bind(Page.SHIPS))
	return _centre_of(plate)


## A full-screen centring box holding `content`, added to the menu.
func _centre_of(content: Control) -> Control:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.add_child(content)
	return centre


## A backed plate holding a list `width` px wide (its first child).
func _plate(width: float) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _box(PLATE_COLOUR))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.custom_minimum_size = Vector2(width, 0)
	plate.add_child(list)
	return plate


func _box(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(10)
	box.set_content_margin_all(PLATE_MARGIN)
	return box


func _label(parent: Control, words: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label


func _button(parent: Control, words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", BUTTON_TEXT_SIZE)
	parent.add_child(b)
	return b
