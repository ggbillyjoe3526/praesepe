class_name ShipClass
extends Resource
## One starter ship as the new-game screen shows it (design doc, "Ships"): its name, the "Great for:" hint, a line
## about it and its strengths and trade-offs. One file per ship (`game/ship/hauler.tres`), listed in
## `game/ship/starter_ships.tres`. How the ship flies lives in its own tuning files, not here.

## Its name in save files. Never change it once players have saves.
@export var id: StringName = &""
@export var display_name: String = ""
## Who it suits, shown as "Great for: ...".
@export var great_for: String = ""
## One or two short sentences about it.
@export_multiline var summary: String = ""
@export var strengths: String = ""
@export var trade_offs: String = ""
