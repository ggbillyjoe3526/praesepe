class_name PilotControls
extends Node
## The player's hands on the ship: keys for thrust and roll, the mouse as a stick for pitch and yaw. Fills the ship's
## ShipInput every physics tick, before the ship acts on it (FlightOrder). The mouse moves a stick that springs back
## to the centre (FlightControls), so moving the mouse turns the ship and stopping lets the turn settle.
## Captures the mouse while flying; a click captures it again if it was let go.

@export var ship: Ship
@export var controls: FlightControls

## The mouse stick, each axis -1 to 1: x right, y down (screen directions). The HUD draws it.
var stick: Vector2 = Vector2.ZERO
var _mouse: Vector2 = Vector2.ZERO
var _toggle_assist: bool = false
var _toggle_cruise: bool = false
var _full_stop: bool = false


func _ready() -> void:
	process_physics_priority = FlightOrder.CONTROLS
	capture_mouse()


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_mouse += motion.screen_relative
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		capture_mouse()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_assist"):
		_toggle_assist = true
	elif event.is_action_pressed(&"full_stop"):
		_full_stop = true
	elif event.is_action_pressed(&"toggle_cruise"):
		_toggle_cruise = true


func _physics_process(delta: float) -> void:
	if ship == null:
		return
	stick = PilotControls.move_stick(stick, _mouse * controls.mouse_gain, controls.stick_return, delta)
	_mouse = Vector2.ZERO
	var input := ship.input
	input.thrust = Vector3(
		Input.get_axis(&"strafe_left", &"strafe_right"),
		Input.get_axis(&"thrust_down", &"thrust_up"),
		Input.get_axis(&"thrust_back", &"thrust_forward"))
	var pitch := stick.y if controls.invert_pitch else -stick.y
	input.turn = Vector3(pitch, stick.x, Input.get_axis(&"roll_left", &"roll_right"))
	input.toggle_assist = input.toggle_assist or _toggle_assist
	input.full_stop = input.full_stop or _full_stop
	input.toggle_cruise = input.toggle_cruise or _toggle_cruise
	_toggle_assist = false
	_toggle_cruise = false
	_full_stop = false


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
