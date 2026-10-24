class_name CockpitDisplay
extends Node3D
## The cockpit's dashboard screen (design doc, "Cockpit UI is in the world where possible"): the ship's speed and
## flight assist (or the cruise drive), in the same words and colours as the flight HUD, lit on a dark screen so they read in any light. Text
## is rebuilt only when the whole number shown changes. Sits on the root of a cockpit scene, such as
## game/ship/greybox_cockpit.tscn; its parent is the ship.

var _speed_shown: int = -1
var _set_shown: int = -1
var _mode_shown: int = -1
var _ship: Ship

@onready var _speed: Label3D = %Speed
@onready var _assist: Label3D = %Assist


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


## What the screen shows now, for the smoke test: the speed line and the flight assist line.
func shown() -> PackedStringArray:
	return PackedStringArray([_speed.text, _assist.text])
