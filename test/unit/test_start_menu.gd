extends GutTest
## The start menu and the title screen (design doc, "Starting a game"): Continue only for a saved game that can be
## read (and a note for one that can't), New game opening the ship choice with each ship's "Great for:" hint,
## choosing a ship starting at once with no saved game and asking first when it would replace one, Esc going back a
## page, and the starter ships as data.

const SHIPS: StarterShips = preload("res://game/ship/starter_ships.tres")

var _menu: StartMenu
var _continued: int = 0
var _new_games: Array[StringName] = []
var _quits: int = 0


func before_each() -> void:
	_continued = 0
	_new_games.clear()
	_quits = 0
	_menu = StartMenu.new()
	_menu.ships = SHIPS
	_menu.continue_chosen.connect(func() -> void: _continued += 1)
	_menu.new_game_chosen.connect(func(ship: StringName) -> void: _new_games.append(ship))
	_menu.quit_chosen.connect(func() -> void: _quits += 1)
	add_child_autofree(_menu)


func _esc() -> void:
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	_menu._unhandled_input(press)


func test_the_starter_ships_are_data() -> void:
	var ships := SHIPS
	assert_eq(ships.ships.size(), 1, "the first playable has one ship")
	var hauler := ships.find(GameStart.DEFAULT_SHIP)
	assert_not_null(hauler, "the default ship is on the list")
	assert_eq(hauler.display_name, "Hauler")
	assert_eq(hauler.great_for, "Porters and miners")
	assert_null(ships.find(&"no_such_ship"))


func test_continue_shows_only_for_a_good_save() -> void:
	assert_false(_menu.continue_button.visible, "no saved game: no Continue")
	assert_true(_menu.new_game_button.has_focus(), "New game is ready for Enter")
	_menu.set_save_state(StartMenu.SaveState.GOOD)
	assert_true(_menu.continue_button.visible)
	assert_true(_menu.continue_button.has_focus())
	_menu.continue_button.pressed.emit()
	assert_eq(_continued, 1)
	for state: StartMenu.SaveState in [StartMenu.SaveState.DAMAGED, StartMenu.SaveState.LOCKED]:
		_menu.set_save_state(state)
		assert_false(_menu.continue_button.visible)
		assert_ne(StartMenu.save_note(state), "", "says why there is no Continue")


func test_settings_opens_the_settings_menu_and_esc_comes_back() -> void:
	_menu.settings_button.pressed.emit()
	assert_eq(_menu.page, StartMenu.Page.SETTINGS)
	assert_true(_menu.settings_menu.visible)
	assert_false(_menu.settings_button.is_visible_in_tree(), "the start menu's own page is hidden behind it")
	_menu.settings_menu.close()
	assert_eq(_menu.page, StartMenu.Page.MAIN)
	assert_false(_menu.settings_menu.visible)
	assert_true(_menu.settings_button.has_focus(), "back on Settings")


func test_quit_says_so() -> void:
	_menu.quit_button.pressed.emit()
	assert_eq(_quits, 1)


func test_new_game_with_no_save_starts_in_the_chosen_ship() -> void:
	_menu.new_game_button.pressed.emit()
	assert_eq(_menu.page, StartMenu.Page.SHIPS)
	assert_eq(_menu.ship_buttons.size(), 1)
	assert_eq(_menu.ship_buttons[0].text, "Fly the Hauler")
	assert_true(_menu.ship_buttons[0].has_focus())
	_menu.ship_buttons[0].pressed.emit()
	assert_eq(_new_games, [&"hauler"] as Array[StringName])


func test_new_game_over_a_save_asks_first() -> void:
	_menu.set_save_state(StartMenu.SaveState.GOOD)
	_menu.new_game_button.pressed.emit()
	_menu.ship_buttons[0].pressed.emit()
	assert_eq(_new_games, [] as Array[StringName], "nothing started yet")
	assert_eq(_menu.page, StartMenu.Page.REPLACE)
	assert_true(_menu.replace_back_button.has_focus(), "Enter by mistake keeps the save")
	_menu.replace_back_button.pressed.emit()
	assert_eq(_menu.page, StartMenu.Page.SHIPS)
	_menu.ship_buttons[0].pressed.emit()
	_menu.replace_button.pressed.emit()
	assert_eq(_new_games, [&"hauler"] as Array[StringName])
	assert_string_contains(StartMenu.replace_question("Hauler", StartMenu.SaveState.GOOD), "replaces your saved game")
	assert_string_contains(StartMenu.replace_question("Hauler", StartMenu.SaveState.DAMAGED), "never deleted")


func test_esc_goes_back_a_page() -> void:
	_menu.set_save_state(StartMenu.SaveState.GOOD)
	_menu.new_game_button.pressed.emit()
	_menu.ship_buttons[0].pressed.emit()
	_esc()
	assert_eq(_menu.page, StartMenu.Page.SHIPS)
	_esc()
	assert_eq(_menu.page, StartMenu.Page.MAIN)
	_esc()
	assert_eq(_menu.page, StartMenu.Page.MAIN, "Esc on the first page does nothing")


func test_the_title_screen_reads_what_the_save_folder_holds() -> void:
	assert_eq(TitleScreen.save_state_of({"ok": true, "data": {}}), StartMenu.SaveState.GOOD)
	assert_eq(TitleScreen.save_state_of({"ok": false, "found": false, "locked": false}), StartMenu.SaveState.NONE)
	assert_eq(TitleScreen.save_state_of({"ok": false, "found": true, "locked": false}), StartMenu.SaveState.DAMAGED)
	assert_eq(TitleScreen.save_state_of({"ok": false, "found": true, "locked": true}), StartMenu.SaveState.LOCKED)
