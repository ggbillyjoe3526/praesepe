class_name SaveGame
## The player's saved game (project instructions, "Saves"): one file in the user folder, written by SaveFile (atomic,
## read back, one backup, damaged copies set aside and never deleted). Version 1 holds the world (Game.snapshot: the
## seed, the clock and where each random stream has got to) and the port the ship is docked or landed at. Money,
## cargo, contracts and the loan join it as they are built. It is written on every docking and landing (Autosave);
## Continue on the title screen reads it and GameStart puts the game back as it was.

const KIND := "game"
const VERSION := 1
const PATH := "user://savegame.json"


## What is saved for a ship docked or landed at `port`.
static func snapshot(port: Port) -> Dictionary:
	return {"v": VERSION, "world": Game.snapshot(), "berth": String(port.id)}


## Writes the game, the ship at `port`, to `path`. Returns false (keeping the last good save) when the write failed.
static func write(path: String, port: Port) -> bool:
	return SaveFile.write(path, KIND, VERSION, SaveGame.snapshot(port))
