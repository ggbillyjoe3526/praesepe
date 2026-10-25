class_name SaveGame
## The player's saved game (project instructions, "Saves"): one file in the user folder, written by SaveFile (atomic,
## read back, one backup, damaged copies set aside and never deleted). It holds the world (Game.snapshot: the seed, the
## clock and where each random stream has got to), the port the ship is docked or landed at ("berth", "" while it
## flies), the last port it arrived at ("home", where the tow takes it) and the ship itself ("ship": which ship, where
## it is in the solar system's own coordinates, which way it faces, how it moves, flight assist, and the planet or moon
## it is in orbit round). Money, cargo, contracts and the loan join it as they are built. The game is written on every
## docking and landing and every few minutes in flight (Autosave).
##
## Older versions are brought up to date one step at a time when read (migrate()), so every old save still loads.
## Version 1 (2026-10-24) held the world and the berth only.

const KIND := "game"
const VERSION := 2
const PATH := "user://savegame.json"


## What is saved: the ship docked or landed at `berth` (null while it flies), last arrived at `home` (null if never),
## and, when there is one, `ship` itself, its true position worked out from the floating `origin`.
static func snapshot(berth: Port, home: Port, ship: Ship = null, origin: FloatingOrigin = null) -> Dictionary:
	var data := {
		"v": VERSION,
		"world": Game.snapshot(),
		"berth": String(berth.id) if berth != null else "",
		"home": String(home.id) if home != null else "",
	}
	if ship != null:
		data["ship"] = SaveGame.ship_state(ship, origin)
	return data


## Where `ship` is and how it moves. "at" is its true position in the solar system's own coordinates (the planet's
## centre is 0, 0, 0), in 64-bit, so it is the same whatever the floating origin has done; "turn" is its attitude as a
## quaternion (x, y, z, w); "velocity" (m/s) and "spin" (rad/s) are in world axes; "held" is the forward speed flight
## assist holds; "orbit" is empty out of orbit, or, settled in orbit, the planet or moon's id ("body"), the orbit's
## distance from its centre ("radius", m) and its axis ("axis"), so the ship goes back to the very same orbit.
static func ship_state(ship: Ship, origin: FloatingOrigin = null) -> Dictionary:
	var at := ship.global_position
	var true_at := origin.true_position(at) if origin != null else PackedFloat64Array([at.x, at.y, at.z])
	var turn := ship.global_basis.get_rotation_quaternion()
	var velocity := ship.linear_velocity
	var spin := ship.angular_velocity
	return {
		"model": String(ship.model_id),
		"at": [true_at[0], true_at[1], true_at[2]],
		"turn": [turn.x, turn.y, turn.z, turn.w],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"spin": [spin.x, spin.y, spin.z],
		"assist": ship.assist_on(),
		"held": ship.held_speed(),
		"orbit": SaveGame.orbit_state(ship.orbit),
	}


## The orbit `orbit` the ship is settled in, or {} when it isn't in one.
static func orbit_state(orbit: Orbit) -> Dictionary:
	if orbit.phase != Orbit.Phase.ORBITING or orbit.body == null:
		return {}
	var axis := orbit.axis
	return {"body": String(orbit.body.id), "radius": orbit.radius, "axis": [axis.x, axis.y, axis.z]}


## Writes `data` (a snapshot()) to `path`. Returns false (keeping the last good save) when the write failed. Safe to
## call from a worker thread: it touches nothing but the files.
static func write(path: String, data: Dictionary) -> bool:
	return SaveFile.write(path, KIND, VERSION, data)


## Reads the newest good copy of the game at `path`, brought up to the current version. Returns {ok: true, data,
## source} (source as SaveFile.read says), or {ok: false, found, locked, newer}: newer means it was written by a later
## version of the game, which this one can't read and must not write over.
static func read(path: String) -> Dictionary:
	var r := SaveFile.read(path, KIND)
	if not r.ok:
		return {"ok": false, "found": r.found, "locked": r.locked, "newer": false}
	if int(r.version) > VERSION:
		push_warning("save: %s is from a newer version of the game (%d)" % [path, r.version])
		return {"ok": false, "found": true, "locked": false, "newer": true}
	return {"ok": true, "data": SaveGame.migrate(r.data, int(r.version)), "source": r.source}


## Brings `data`, saved as `version`, up to VERSION, one step at a time.
static func migrate(data: Dictionary, version: int) -> Dictionary:
	if version < 2:
		# 1 -> 2: no home or ship yet. The ship was always docked or landed, and that port was the last it arrived at;
		# with no ship block, loading puts it at its berth.
		data["home"] = str(data.get("berth", ""))
	data["v"] = VERSION
	return data
