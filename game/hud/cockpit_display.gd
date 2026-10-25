class_name CockpitDisplay
extends Node3D
## The cockpit's dashboard screen (design doc, "Cockpit UI is in the world where possible"): the ship's speed and
## flight assist (or the cruise drive), in the same words and colours as the flight HUD, lit on a dark screen so they
## read in any light, and under them the place the cruise drive is locked onto with its distance and the time to get
## there. Text is rebuilt only when what it shows changes. Sits on the root of a cockpit scene, such as
## game/ship/greybox_cockpit.tscn; its parent is the ship.

var _speed_shown: int = -1
var _set_shown: int = -1
var _mode_shown: int = -1
var _target_shown: int = -1
var _ship: Ship

@onready var _speed: Label3D = %Speed
@onready var _assist: Label3D = %Assist
@onready var _target: Label3D = %Target


func _ready() -> void:
	_ship = get_parent() as Ship


func _process(_delta: float) -> void:
	if _ship == null:
		return
	var speed := FlightHud.shown_speed(_ship.speed())
	if speed != _speed_shown:
		_speed_shown = speed
		_speed.text = FlightHud.speed_text(speed)
	var mode := FlightHud.mode_of(_ship)
	var held := roundi(_ship.held_speed())
	if mode != _mode_shown or (mode == FlightHud.Mode.ASSIST_ON and held != _set_shown):
		_mode_shown = mode
		_set_shown = held
		_assist.text = FlightHud.mode_text(mode, held)
		_assist.modulate = FlightHud.mode_colour(mode)
	var key := FlightHud.target_key(_ship)
	if key != _target_shown:
		_target_shown = key
		var t := FlightHud.target_of(_ship)
		_target.text = FlightHud.target_text(t.display_name, t.marker_distance(_ship.global_position),
				_ship.cruise.eta) if t != null else ""


## The speed and flight assist lines as the screen shows them now, and the flight assist line's colour: the nav
## computer's screen (NavPanel) repeats them while it covers this one.
func speed_line() -> String:
	return _speed.text


func assist_line() -> String:
	return _assist.text


func assist_colour() -> Color:
	return _assist.modulate


## What the screen shows now, for the smoke test: the speed line, the flight assist line and the target line.
func shown() -> PackedStringArray:
	return PackedStringArray([_speed.text, _assist.text, _target.text])
