class_name FlightHud
extends Control
## The flight HUD (design doc, "Flight and camera"): the nose's aim point, the velocity marker showing where the ship
## is really going, the mouse stick, and a readout of speed and flight assist on a solid plate. Text is rebuilt only
## when the whole number shown changes (so while speeding up, not in steady flight). A placeholder look until the
## cockpit and art style arrive.

## Below this speed (m/s) the ship counts as stopped and no velocity marker shows.
const STOPPED := 0.5
## How long (s) the flight assist message stays up.
const TOAST_TIME := 2.5
## How close (px at 1080p) markers come to the screen's edge.
const EDGE := 64.0
const NOSE_COLOUR := Color(0.92, 0.95, 1.0, 0.85)
const PROGRADE_COLOUR := Color(0.45, 1.0, 0.7)
const RETROGRADE_COLOUR := Color(1.0, 0.7, 0.3)
const STICK_COLOUR := Color(0.92, 0.95, 1.0, 0.5)
const OFF_COLOUR := Color(1.0, 0.72, 0.3)
const ON_COLOUR := Color(0.55, 0.95, 0.75)
const NOSE_ARMS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
## Sizes in px at 1080p: the nose mark's arms, the mouse stick's ring (a full push) and dot, and the velocity markers.
const NOSE_GAP := 6.0
const NOSE_ARM := 16.0
const STICK_RING := 90.0
const STICK_DOT := 4.0
const MARKER_RADIUS := 11.0
const MARKER_WING := 11.0
const MARKER_CROSS := 8.0
const LINE_WIDTH := 2.5

@export var ship: Ship
@export var camera: Camera3D
@export var controls: PilotControls

var _speed_shown: int = -1
var _set_shown: int = -1
var _assist_shown: int = -1
var _toast_left: float = 0.0

@onready var _speed: Label = %Speed
@onready var _assist: Label = %Assist
@onready var _toast: Label = %Toast
@onready var _toast_plate: Control = %ToastPlate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_plate.visible = false
	if ship != null:
		ship.assist_changed.connect(_on_assist_changed)


func _exit_tree() -> void:
	if ship != null and ship.assist_changed.is_connected(_on_assist_changed):
		ship.assist_changed.disconnect(_on_assist_changed)


func _process(delta: float) -> void:
	if ship == null:
		return
	_update_text()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast_plate.visible = _toast_left > 0.0
	queue_redraw()


func _update_text() -> void:
	var speed := roundi(ship.speed())
	if speed != _speed_shown:
		_speed_shown = speed
		_speed.text = "%d m/s" % speed
	var on := 1 if ship.assist_on() else 0
	var held := roundi(ship.held_speed())
	if on != _assist_shown:
		_assist.add_theme_color_override("font_color", ON_COLOUR if on == 1 else OFF_COLOUR)
	if on != _assist_shown or (on == 1 and held != _set_shown):
		_assist_shown = on
		_set_shown = held
		if on == 1:
			_assist.text = "FLIGHT ASSIST ON  ·  holding %d m/s" % held
		else:
			_assist.text = "FLIGHT ASSIST OFF  ·  drifting"


func _on_assist_changed(on: bool) -> void:
	_toast.text = "Flight assist ON" if on else "Flight assist OFF: the ship keeps drifting and spinning"
	_toast.add_theme_color_override("font_color", ON_COLOUR if on else OFF_COLOUR)
	_toast_left = TOAST_TIME
	_toast_plate.visible = true


func _draw() -> void:
	if ship == null or camera == null:
		return
	var screen := size
	var centre := screen * 0.5
	_draw_nose(centre)
	if controls != null:
		_draw_stick(centre, controls.stick)
	if ship.speed() < STOPPED:
		return
	var view := camera.get_global_transform_interpolated()
	var at := ScreenMarker.project(view, camera.fov, screen, ship.linear_velocity)
	var point := Vector2(at.x, at.y)
	var clamped := ScreenMarker.clamp_to_screen(point, screen, EDGE)
	var faded := clamped != point
	if at.z >= 0.0:
		_draw_prograde(clamped, faded)
	else:
		_draw_retrograde(clamped, faded)


func _draw_nose(c: Vector2) -> void:
	for dir: Vector2 in NOSE_ARMS:
		draw_line(c + dir * NOSE_GAP, c + dir * NOSE_ARM, NOSE_COLOUR, 2.0, true)


## The mouse stick: a faint ring the size of a full deflection, and a dot where the stick is.
func _draw_stick(c: Vector2, stick: Vector2) -> void:
	if stick.length() < 0.02:
		return
	draw_arc(c, STICK_RING, 0.0, TAU, 48, Color(STICK_COLOUR, 0.18), 1.5, true)
	draw_circle(c + stick * STICK_RING, STICK_DOT, STICK_COLOUR)


## Where the ship is going: a ring with three short wings.
func _draw_prograde(p: Vector2, faded: bool) -> void:
	var col := Color(PROGRADE_COLOUR, 0.55 if faded else 1.0)
	var r := MARKER_RADIUS
	draw_arc(p, r, 0.0, TAU, 32, col, LINE_WIDTH, true)
	draw_line(p + Vector2(-r, 0), p + Vector2(-r - MARKER_WING, 0), col, LINE_WIDTH, true)
	draw_line(p + Vector2(r, 0), p + Vector2(r + MARKER_WING, 0), col, LINE_WIDTH, true)
	draw_line(p + Vector2(0, -r), p + Vector2(0, -r - MARKER_WING * 0.8), col, LINE_WIDTH, true)


## Going backwards: a ring with a cross, where the ship is moving away from.
func _draw_retrograde(p: Vector2, faded: bool) -> void:
	var col := Color(RETROGRADE_COLOUR, 0.55 if faded else 1.0)
	var x := MARKER_CROSS
	draw_arc(p, MARKER_RADIUS, 0.0, TAU, 32, col, LINE_WIDTH, true)
	draw_line(p + Vector2(-x, -x), p + Vector2(x, x), col, LINE_WIDTH, true)
	draw_line(p + Vector2(-x, x), p + Vector2(x, -x), col, LINE_WIDTH, true)
