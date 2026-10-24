class_name Autosave
extends Node
## Autosave on docking and landing (project instructions, "Saves"): whenever the ship arrives at a port
## (Events.arrived) the game is written (SaveGame) and everyone hears whether it worked (Events.game_saved). A failed
## write keeps the last good save and the game carries on. The smoke test saves to its own file, never the player's.

## Where the game is saved.
@export var path: String = SaveGame.PATH
## What the last save wrote, and whether it worked (for the smoke test and the HUD).
var last_berth: StringName = &""
var last_ok: bool = false


func _ready() -> void:
	Events.arrived.connect(_on_arrived)


func _exit_tree() -> void:
	if Events.arrived.is_connected(_on_arrived):
		Events.arrived.disconnect(_on_arrived)


func _on_arrived(port: Port) -> void:
	last_berth = port.id
	last_ok = SaveGame.write(path, port)
	Events.game_saved.emit(last_ok)
