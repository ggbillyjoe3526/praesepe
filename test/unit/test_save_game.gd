extends GutTest
## The autosave (project instructions, "Saves"): arriving at a port writes the game (SaveGame, through SaveFile) and
## says whether it worked; what it writes reads back with the world and the berth; a failed write is reported and
## the game carries on.

const PATH := "user://test_savegame.json"

var _port: Port
var _saved: Array[bool] = []


func before_each() -> void:
	SaveFile.remove(PATH)
	_saved.clear()
	_port = Port.new()
	_port.id = &"test_port"
	add_child_autofree(_port)
	Events.game_saved.connect(_on_saved)


func after_each() -> void:
	Events.game_saved.disconnect(_on_saved)
	SaveFile.remove(PATH)


func _on_saved(ok: bool) -> void:
	_saved.append(ok)


func test_writes_the_world_and_the_berth() -> void:
	assert_true(SaveGame.write(PATH, _port))
	var r := SaveFile.read(PATH, SaveGame.KIND)
	assert_true(r.ok)
	assert_eq(r.version, SaveGame.VERSION)
	assert_eq(r.data.berth, "test_port")
	assert_eq(int(r.data.world.world_seed), Game.world_seed)


func test_arriving_autosaves() -> void:
	var autosave := Autosave.new()
	autosave.path = PATH
	add_child_autofree(autosave)
	Events.arrived.emit(_port)
	assert_eq(_saved, [true] as Array[bool])
	assert_eq(autosave.last_berth, &"test_port")
	assert_true(SaveFile.read(PATH, SaveGame.KIND).ok)
	# A second arrival keeps the first as the backup.
	Events.arrived.emit(_port)
	assert_true(FileAccess.file_exists(PATH + SaveFile.BAK))


func test_a_failed_write_is_reported() -> void:
	var autosave := Autosave.new()
	autosave.path = "user://no_such_folder/savegame.json"
	add_child_autofree(autosave)
	Events.arrived.emit(_port)
	assert_eq(_saved, [false] as Array[bool])
	assert_false(autosave.last_ok)
