class_name WindowWatch
extends Node
## The window's keys and focus, everywhere (flying, paused, in the settings menu): F11 or Alt+Enter switches between
## fullscreen and a window and saves it at once (Settings.toggle_fullscreen), and while the game is in the background
## (unfocused or minimised) it draws at most DisplayApply.BACKGROUND_FPS. From the owner's Airsoft-Next project
## (game/ui/window_watch.gd). A child of the Settings autoload, so it is there before any scene.
##
## The keys are read in `_input`, before a focused button takes Enter.


func _ready() -> void:
	name = "WindowWatch"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not WindowWatch.is_toggle(event):
		return
	get_viewport().set_input_as_handled()
	Settings.toggle_fullscreen()
	Settings.commit()


func _notification(what: int) -> void:
	# The window's own focus and the application's, whichever the system sends (minimising loses focus).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_set_focused(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_set_focused(true)


## Whether `event` is the fullscreen key: F11, or Enter with Alt held.
static func is_toggle(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.physical_keycode == KEY_F11:
		return true
	return key.alt_pressed and (key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER)


func _set_focused(focused: bool) -> void:
	DisplayApply.screens().focused = focused
	DisplayApply.apply_frame_rate(Settings.frame_limit)
