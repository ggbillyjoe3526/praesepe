class_name SettingsPage
extends VBoxContainer
## One page of the settings menu (SettingsMenu): a column of settings, each changing the Settings autoload at once.
## A page is its own script extending this one: it names itself (`title`), lists the settings its Defaults button puts
## back (`keys`), builds its rows in `build()` with the helpers here, and shows the settings as they are now in
## `sync()`, which runs whenever any setting changes. To add a page, write one and add it to SettingsMenu.PAGES.
##
## The rows share one look: a name on the left, its control or value on the right, and a hint in a softer colour
## under the settings that need one. Sizes are in px at 1080p.

const HEADING_SIZE := 30
const SETTING_SIZE := 24
const HINT_SIZE := 19
const HINT_COLOUR := Color(0.7, 0.75, 0.85)
const OFF_TEXT_COLOUR := Color(0.55, 0.58, 0.65)
const GAP := 14
const SLIDER_HEIGHT := 36.0
const CHOICE_WIDTH := 380.0
const CHOICE_HEIGHT := 48.0
## Where a slider keeps the label that shows its value (value_label).
const VALUE_META := &"value_label"

## The page's name on its button in the menu.
var title: String = ""
## The settings (keys of Settings.to_dict) the Defaults button puts back.
var keys: PackedStringArray = PackedStringArray()


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build()
	Settings.changed.connect(sync)
	sync()


func _exit_tree() -> void:
	if Settings.changed.is_connected(sync):
		Settings.changed.disconnect(sync)


## Adds the page's rows (once, when the page is made).
func build() -> void:
	pass


## Shows the settings as they are now, without sending them back (set_value_no_signal and the like).
func sync() -> void:
	pass


## Puts this page's settings back to their defaults.
func defaults() -> void:
	Settings.reset(keys)


func add_heading(words: String) -> Label:
	var heading := Label.new()
	heading.text = words
	heading.add_theme_font_size_override("font_size", HEADING_SIZE)
	add_child(heading)
	return heading


## A line of softer text that wraps.
func add_hint(words: String) -> Label:
	var hint := Label.new()
	hint.text = words
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", HINT_SIZE)
	hint.add_theme_color_override("font_color", HINT_COLOUR)
	add_child(hint)
	return hint


## A setting's name on the left and a value on the right; returns the value's label.
func add_value_row(words: String) -> Label:
	var row := _row(words)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", SETTING_SIZE)
	row.add_child(value)
	return value


## A named slider from `low` to `high` in steps of `step`, its value shown on the right (value_label); `moved` gets
## each new value.
func add_slider(words: String, low: float, high: float, step: float, moved: Callable) -> HSlider:
	var value := add_value_row(words)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT)
	slider.set_meta(VALUE_META, value)
	slider.value_changed.connect(moved)
	add_child(slider)
	return slider


## The label showing a slider's value.
static func value_label(slider: HSlider) -> Label:
	return slider.get_meta(VALUE_META) as Label


## An on/off switch; `toggled` gets the new state.
func add_toggle(words: String, toggled: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = words
	check.add_theme_font_size_override("font_size", SETTING_SIZE)
	check.toggled.connect(toggled)
	add_child(check)
	return check


## A named list to pick one from; `picked` gets the index of the one picked.
func add_choice(words: String, options: PackedStringArray, picked: Callable) -> OptionButton:
	var row := _row(words)
	var choice := OptionButton.new()
	choice.custom_minimum_size = Vector2(CHOICE_WIDTH, CHOICE_HEIGHT)
	choice.add_theme_font_size_override("font_size", SETTING_SIZE)
	choice.get_popup().add_theme_font_size_override("font_size", SETTING_SIZE)
	set_options(choice, options)
	choice.item_selected.connect(picked)
	row.add_child(choice)
	return choice


## Replaces a choice's options (the selection is sync()'s to set).
static func set_options(choice: OptionButton, options: PackedStringArray) -> void:
	choice.clear()
	for words in options:
		choice.add_item(words)


## Greys a value out (or not), for settings another one turns off.
static func grey(label: Label, off: bool) -> void:
	label.add_theme_color_override("font_color", OFF_TEXT_COLOUR if off else Color.WHITE)


func _row(words: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	add_child(row)
	var name_label := Label.new()
	name_label.text = words
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", SETTING_SIZE)
	row.add_child(name_label)
	return row
