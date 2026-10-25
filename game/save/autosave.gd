class_name Autosave
extends Node
## Autosave (project instructions, "Saves"; design doc, "Saving"): the game is written whenever the ship arrives at a
## port (Events.arrived), and every few minutes of in-game time while it flies, so quitting or a crash never loses more
## than that. Everyone hears whether it worked (Events.game_saved). A failed write keeps the last good save and the game
## carries on. The smoke test saves to its own file, never the player's.
##
## A save in flight waits until the ship is somewhere loading can put it back as it was: flying freely or settled in
## orbit, not while the cruise drive charges or runs, nor while the ship is flown in to its berth or out of it. Its file
## is written on a worker thread, so the disk never holds up a frame; only the snapshot of the game is taken on the
## main thread. Saving on arrival, and save_now() (quitting), write at once and wait for any save still being written,
## so two never touch the file together.

## Where the game is saved.
@export var path: String = SaveGame.PATH
## How long (in-game seconds) the ship may fly since the last save before it is saved again.
@export var interval: float = 180.0
## The player's ship, what is docking or landing it, and the floating origin (for its true position). Without a ship
## (as in some tests) only arrivals are saved.
@export var ship: Ship
@export var arrivals: Arrivals
@export var origin: FloatingOrigin

## What the last save wrote (the berth, or "" in flight) and whether it worked (for the smoke test and the HUD).
var last_berth: StringName = &""
var last_ok: bool = false
## How many saves in flight have been written (for the smoke test).
var flight_saves: int = 0
## The in-game time (Game.clock) the next save in flight is due.
var due: float = 0.0

## The save being written on a worker thread (WorkerThreadPool), or -1; and whether it worked, set by the worker.
var _task: int = -1
var _worker_ok: bool = false


func _ready() -> void:
	Events.arrived.connect(_on_arrived)
	due = Game.clock + interval


func _exit_tree() -> void:
	if Events.arrived.is_connected(_on_arrived):
		Events.arrived.disconnect(_on_arrived)
	# Never leave a write cut short.
	_finish_writing()


func _physics_process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_writing()
	if _task < 0 and Game.clock >= due and can_save_in_flight():
		var data := _snapshot()
		var to := path
		_worker_ok = false
		# Counted from when the game was taken, not from when the disk finished, so it never drifts.
		due = Game.clock + interval
		_task = WorkerThreadPool.add_task(_write_on_worker.bind(to, data), false, "Autosave")


## Whether a save now would put the ship back as it is: flying freely or settled in orbit. Not while the cruise drive
## charges or runs, the orbit swings in or levels out, or the ship is being flown in to a berth, is at one or is
## leaving it (arriving saved it already).
func can_save_in_flight() -> bool:
	if ship == null or ship.berth != null or ship.guided:
		return false
	if arrivals != null and arrivals.stage != Arrivals.Stage.FLYING:
		return false
	if ship.cruise.phase != CruiseDrive.Phase.OFF:
		return false
	return ship.orbit.phase == Orbit.Phase.OFF or ship.orbit.phase == Orbit.Phase.ORBITING


## Writes the game now, wherever the ship is, and waits until it is on disk (for quitting). Returns false, leaving the
## last save as it was, when the write failed or the ship is somewhere a save can't put it back (cruising, or being
## flown in to a berth or out of it).
func save_now() -> bool:
	_finish_writing()
	var docked := ship != null and ship.berth != null and not ship.guided \
			and (arrivals == null or arrivals.stage == Arrivals.Stage.DOCKED)
	if not docked and not can_save_in_flight():
		return false
	last_berth = ship.berth.id if docked else &""
	return _saved(SaveGame.write(path, _snapshot()))


func _on_arrived(port: Port) -> void:
	_finish_writing()
	last_berth = port.id
	var data := SaveGame.snapshot(port, port, ship, origin)
	_saved(SaveGame.write(path, data))


## The game as it is now. The berth is the ship's while it is docked or landed (save_now and arrivals only).
func _snapshot() -> Dictionary:
	var home := arrivals.home if arrivals != null else null
	return SaveGame.snapshot(ship.berth, home, ship, origin)


## On the worker thread: touches nothing but the file.
func _write_on_worker(to: String, data: Dictionary) -> void:
	_worker_ok = SaveGame.write(to, data)


## Waits for the save being written on the worker thread, if there is one, and says how it went.
func _finish_writing() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	last_berth = &""
	if _worker_ok:
		flight_saves += 1
	last_ok = _worker_ok
	Events.game_saved.emit(_worker_ok)


## A save finished (`ok`): the next one in flight is due a full interval from now.
func _saved(ok: bool) -> bool:
	last_ok = ok
	due = Game.clock + interval
	Events.game_saved.emit(ok)
	return ok
