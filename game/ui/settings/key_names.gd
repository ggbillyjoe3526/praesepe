class_name KeyNames
## Names for the keys of the input map in the player's own keyboard layout: a key is bound by its position (physical
## keycode, so WASD stays WASD on any layout) and named by what it prints there (the W key is "Z" on AZERTY), through
## DisplayServer.keyboard_get_keycode_from_physical. From the owner's Airsoft-Next project (game/input/key_names.gd),
## reading the input map instead of its own key list.

const MOUSE_NAMES: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "Left click",
	MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
}
const NO_KEY := "-"
## Short names for the keys whose own names are long.
const SHORT: Dictionary[String, String] = {"Escape": "Esc", "Kp Enter": "Keypad Enter"}


## The readable name of an input event's key or button, with the modifiers it needs ("Shift+Enter"); a dash for
## anything else.
static func name_of(event: InputEvent) -> String:
	var button := event as InputEventMouseButton
	if button != null:
		return MOUSE_NAMES.get(int(button.button_index), "Mouse %d" % int(button.button_index))
	var key := event as InputEventKey
	if key == null:
		return NO_KEY
	var physical := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	# The headless display server has no keyboard to ask (it reports an error), so keys keep their US names there.
	var printed := KEY_NONE as Key
	if DisplayServer.get_name() != "headless":
		printed = DisplayServer.keyboard_get_keycode_from_physical(physical)
	var named := OS.get_keycode_string(printed if printed != KEY_NONE else physical)
	if named.is_empty():
		return NO_KEY
	var held := ""
	if key.ctrl_pressed:
		held += "Ctrl+"
	if key.alt_pressed:
		held += "Alt+"
	if key.shift_pressed:
		held += "Shift+"
	return held + SHORT.get(named, named)


## Every key of `action` as the input map has it now: "Ctrl or C".
static func of_action(action: StringName) -> String:
	if not InputMap.has_action(action):
		return NO_KEY
	var parts := PackedStringArray()
	for event in InputMap.action_get_events(action):
		parts.append(name_of(event))
	return " or ".join(parts) if not parts.is_empty() else NO_KEY
