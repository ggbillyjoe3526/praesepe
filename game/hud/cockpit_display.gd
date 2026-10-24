class_name CockpitDisplay
extends Node3D
## The cockpit's dashboard screen (design doc, "Cockpit UI is in the world where possible"): the ship's speed and
## flight assist, in the same words and colours as the flight HUD, lit on a dark screen so they read in any light. Text
## is rebuilt only when the whole number shown changes. Sits on the root of a cockpit scene, such as
## game/ship/greybox_cockpit.tscn; its parent is the ship.

var _speed_shown: int = -1
var _set_shown: int = -1
var _assist_shown: int = -1
var _ship: Ship

@onready var _speed: Label3D = %Speed
@onready var _assist: Label3D = %Assist


func _ready() -> void:
	_ship = get_parent() as Ship


func _process(_delta: float) -> void:
	if _ship == null:
		return
	var speed := roundi(_ship.speed())
	if speed != _speed_shown:
		_speed_shown = speed
		_speed.text = FlightHud.speed_text(speed)
	var on := 1 if _ship.assist_on() else 0
	var held := roundi(_ship.held_speed())
	if on != _assist_shown or (on == 1 and held != _set_shown):
		_assist_shown = on
		_set_shown = held
		_assist.text = FlightHud.assist_text(on == 1, held)
		_assist.modulate = FlightHud.ON_COLOUR if on == 1 else FlightHud.OFF_COLOUR


## What the screen shows now, for the smoke test: the speed line and the flight assist line.
func shown() -> PackedStringArray:
	return PackedStringArray([_speed.text, _assist.text])
