class_name PilotControls
extends Node
## The player's hands on the ship: keys for thrust and roll, the mouse as a stick for pitch and yaw. Fills the ship's
## ShipInput every physics tick, before the ship acts on it (FlightOrder). The mouse moves a stick that springs back
## to the centre (FlightControls), so moving the mouse turns the ship and stopping lets the turn settle. The player's
## mouse sensitivity and invert (Settings › Controls) scale and flip it.
## Captures the mouse while flying; a click captures it again if it was let go, unless it was let go on purpose
## (release_mouse(), for clicking the nav computer's screen).

@export var ship: Ship
@export var controls: FlightControls

## The mouse stick, each axis -1 to 1: x right, y down (screen directions). The HUD draws it.
var stick: Vector2 = Vector2.ZERO
## The mouse is free on purpose (release_mouse()): it doesn't steer, a click doesn't take it back, and losing it
## doesn't pause.
var mouse_free: bool = false
var _mouse: Vector2 = Vector2.ZERO
var _toggle_assist: bool = false
var _toggle_cruise: bool = false
var _full_stop: bool = false
var _toggle_orbit: bool = false
var _dock: bool = false


func _ready() -> void:
	process_physics_priority = FlightOrder.CONTROLS
	capture_mouse()


func capture_mouse() -> void:
	mouse_free = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Lets the mouse go to click something on screen (the nav computer); capture_mouse() takes it back.
func release_mouse() -> void:
	mouse_free = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_mouse += motion.screen_relative
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and not mouse_free and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		capture_mouse()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_assist"):
		_toggle_assist = true
	elif event.is_action_pressed(&"full_stop"):
		_full_stop = true
	elif event.is_action_pressed(&"toggle_cruise"):
		_toggle_cruise = true
	elif event.is_action_pressed(&"toggle_orbit"):
		_toggle_orbit = true
	elif event.is_action_pressed(&"dock"):
		_dock = true


func _physics_process(delta: float) -> void:
	if ship == null:
		return
	var gain := controls.mouse_gain * Settings.sensitivity
	stick = PilotControls.move_stick(stick, _mouse * gain, controls.stick_return, delta)
	_mouse = Vector2.ZERO
	var input := ship.input
	input.thrust = Vector3(
		Input.get_axis(&"strafe_left", &"strafe_right"),
		Input.get_axis(&"thrust_down", &"thrust_up"),
		Input.get_axis(&"thrust_back", &"thrust_forward"))
	var pitch := stick.y if Settings.invert_mouse else -stick.y
	input.turn = Vector3(pitch, stick.x, Input.get_axis(&"roll_left", &"roll_right"))
	input.toggle_assist = input.toggle_assist or _toggle_assist
	input.full_stop = input.full_stop or _full_stop
	input.toggle_cruise = input.toggle_cruise or _toggle_cruise
	input.toggle_orbit = input.toggle_orbit or _toggle_orbit
	input.dock = input.dock or _dock
	_toggle_assist = false
	_toggle_cruise = false
	_full_stop = false
	_toggle_orbit = false
	_dock = false


func _notification(what: int) -> void:
	# Coming back from pause, the stick starts centred and mouse movement made while paused is forgotten.
	if what == NOTIFICATION_UNPAUSED:
		stick = Vector2.ZERO
		_mouse = Vector2.ZERO
		if ship != null:
			ship.input.reset()


## The stick after a tick: pushed by `push`, kept inside the unit circle, then eased back towards the centre at
## `return_rate` per second.
static func move_stick(current: Vector2, push: Vector2, return_rate: float, delta: float) -> Vector2:
	var moved := (current + push).limit_length(1.0)
	return moved * exp(-return_rate * delta)
