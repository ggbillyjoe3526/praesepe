class_name PilotControls
extends Node
## The player's hands on the ship: keys for thrust and roll, the mouse as a stick for pitch and yaw. Fills the ship's
## ShipInput every physics tick, before the ship acts on it (FlightOrder). The mouse moves a stick that springs back
## to the centre (FlightControls), so moving the mouse turns the ship and stopping lets the turn settle. The player's
## mouse sensitivity and invert (Settings › Controls) scale and flip it.
## Holding the look button (right mouse) turns the pilot's head instead (ShipCameras.look): the mouse looks round the
## cockpit, or swings the chase camera round the ship, while the stick eases back to the centre so the ship's turn
## settles as if the mouse had stopped. Let go and the view turns back to the front. R asks the ship to roll upright
## (ShipInput.roll_upright).
## Captures the mouse while flying; a click captures it again if it was let go, unless it was let go on purpose
## (release_mouse(), for clicking the nav computer's screen).

@export var ship: Ship
@export var controls: FlightControls
## Where the head turn goes, or null (no looking round).
@export var cameras: ShipCameras

## The mouse stick, each axis -1 to 1: x right, y down (screen directions). The HUD draws it.
var stick: Vector2 = Vector2.ZERO
## The mouse is free on purpose (release_mouse()): it doesn't steer, a click doesn't take it back, and losing it
## doesn't pause.
var mouse_free: bool = false
## Where the pilot's head is turned (radians): x to the right, y up. Zero looks straight ahead.
var look: Vector2 = Vector2.ZERO
var _mouse: Vector2 = Vector2.ZERO
var _look_mouse: Vector2 = Vector2.ZERO
var _roll_upright: bool = false
var _toggle_assist: bool = false
var _toggle_cruise: bool = false
var _full_stop: bool = false
var _toggle_orbit: bool = false
var _dock: bool = false


func _ready() -> void:
	process_physics_priority = FlightOrder.CONTROLS
	process_priority = FlightOrder.CONTROLS_DRAW
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
			if looking():
				_look_mouse += motion.screen_relative
			else:
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
	elif event.is_action_pressed(&"roll_upright"):
		_roll_upright = true


## The look button is held with the mouse captured: the mouse turns the head, not the ship.
func looking() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed(&"look_around")


func _process(delta: float) -> void:
	var push := _look_mouse * deg_to_rad(controls.look_gain) * Settings.sensitivity
	if Settings.invert_mouse:
		push.y = -push.y
	# Screen y is down; the head's y is up.
	look = PilotControls.move_look(look, Vector2(push.x, -push.y), looking(), controls, delta)
	_look_mouse = Vector2.ZERO
	if cameras != null:
		cameras.look = look


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
	input.roll_upright = input.roll_upright or _roll_upright
	_toggle_assist = false
	_toggle_cruise = false
	_full_stop = false
	_toggle_orbit = false
	_dock = false
	_roll_upright = false


func _notification(what: int) -> void:
	# Coming back from pause, the stick starts centred and mouse movement made while paused is forgotten.
	if what == NOTIFICATION_UNPAUSED:
		stick = Vector2.ZERO
		_mouse = Vector2.ZERO
		_look_mouse = Vector2.ZERO
		if ship != null:
			ship.input.reset()


## The stick after a tick: pushed by `push`, kept inside the unit circle, then eased back towards the centre at
## `return_rate` per second.
static func move_stick(current: Vector2, push: Vector2, return_rate: float, delta: float) -> Vector2:
	var moved := (current + push).limit_length(1.0)
	return moved * exp(-return_rate * delta)


## The head's turn after a frame: while `held`, turned by `push` (radians: x right, y up) and kept within the
## controls' limits; once let go, eased back to straight ahead over FlightControls.look_return_time.
static func move_look(current: Vector2, push: Vector2, held: bool, limits: FlightControls, delta: float) -> Vector2:
	if not held:
		var back := current.lerp(Vector2.ZERO, Smoothing.factor(delta, limits.look_return_time))
		# Within a twentieth of a degree it is straight ahead.
		return back if back.length_squared() > 1.0e-6 else Vector2.ZERO
	var side := deg_to_rad(limits.look_side_max)
	return Vector2(clampf(current.x + push.x, -side, side),
			clampf(current.y + push.y, -deg_to_rad(limits.look_down_max), deg_to_rad(limits.look_up_max)))
