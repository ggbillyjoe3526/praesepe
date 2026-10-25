class_name TitleScreen
extends Node3D
## The title screen, the first thing the game shows (design doc, "Starting a game"): the start menu (StartMenu) over a
## slowly turning starfield. It looks in the save folder once, so Continue appears only for a saved game that can be
## read. New game starts a fresh world in the chosen ship and Continue the saved game (GameStart), then the main scene
## opens and puts the ship there. The smoke test skips it and flies straight away.

const SCENE := "res://game/ui/title_screen.tscn"
const MAIN_SCENE := "res://game/main/main.tscn"
## How fast (degrees a second) the view of the stars turns behind the menu.
const DRIFT_RATE := 1.2

## Where the game is saved (tests point it elsewhere).
@export var save_path: String = SaveGame.PATH
@export var menu: StartMenu
@export var view: Camera3D

## The saved game found at start (SaveFile.read's result).
var save: Dictionary = {}


func _ready() -> void:
	if Game.launch_args.smoke:
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	save = SaveFile.read(save_path, SaveGame.KIND)
	menu.set_save_state(TitleScreen.save_state_of(save))
	menu.continue_chosen.connect(_continue)
	menu.new_game_chosen.connect(_new_game)
	menu.quit_chosen.connect(_quit)


func _process(delta: float) -> void:
	if view != null:
		view.rotate_y(deg_to_rad(DRIFT_RATE) * delta)


## What the start menu should offer for a save read with SaveFile.read.
static func save_state_of(read: Dictionary) -> StartMenu.SaveState:
	if read.get("ok", false):
		return StartMenu.SaveState.GOOD
	if read.get("locked", false):
		return StartMenu.SaveState.LOCKED
	return StartMenu.SaveState.DAMAGED if read.get("found", false) else StartMenu.SaveState.NONE


func _continue() -> void:
	if not save.get("ok", false):
		return
	GameStart.continue_game(save.data)
	_play()


## A new game: the `--seed` world when one was given, otherwise a fresh one.
func _new_game(ship: StringName) -> void:
	var chosen := Game.launch_args.seed_value
	GameStart.new_game(ship, chosen if chosen != LaunchArgs.NO_SEED else Seeds.fresh())
	_play()


func _play() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _quit() -> void:
	Settings.commit()
	get_tree().quit()
