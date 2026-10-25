extends Node3D
## The game scene, opened from the title screen (game/ui/title_screen.gd): the tiny solar system
## (game/system/solar_system.tscn) with the player's greybox ship, seen from the cockpit or the chase camera
## (ShipCameras), with HUD markers on every place. The ship starts where GameStart says: docked at Halfway Station for
## a new game, or where it was saved when continuing. The floating origin is centred on it from the first tick; true
## positions are the system's own (the planet's centre is 0, 0, 0). Docking and landing (Arrivals), the autosave
## (Autosave) and the nav computer (NavComputer, shown on the dashboard and as a card in the chase view) are nodes of
## their own beside it. When the ship is towed home it jumps there in one tick, so the floating origin is centred on it
## at once and the camera is put in place with no swing across the system. Opened on its own (F6 in the editor), the
## ship starts at the system's start point in flight next to the station. Launched with `-- --smoke` it starts there
## too, and the autopilot flies it instead of the player (game/debug/smoke_run.gd); with `-- --smoke --nav`, the nav
## computer does, given orders by game/debug/nav_smoke_run.gd.

@onready var _ship: Ship = $World/Ship
@onready var _origin: FloatingOrigin = $FloatingOrigin
@onready var _pilot: PilotControls = $PilotControls
@onready var _hud: FlightHud = $Hud/FlightHud
@onready var _pause: PauseScreen = $PauseScreen
@onready var _cameras: ShipCameras = $ShipCameras
@onready var _system: SolarSystem = $World/SolarSystem
@onready var _markers: LandmarkMarkers = $Hud/LandmarkMarkers
@onready var _arrivals: Arrivals = $Arrivals
@onready var _autosave: Autosave = $Autosave
@onready var _nav: NavComputer = $NavComputer
@onready var _nav_card: NavPanel = $Hud/NavCard
@onready var _nav_strip: NavStrip = $Hud/NavStrip


func _ready() -> void:
	_ship.cruise.landmarks = _system.landmarks
	_ship.orbit.bodies = _system.bodies
	_ship.upright.bodies = _system.bodies
	_arrivals.ports = _system.ports
	_system.track(_ship)
	_markers.show_places(_system.landmarks)
	_nav.setup(_system.landmarks, _system.ports)
	var dashboard := _ship.get_node(^"Cockpit/NavScreen") as NavScreen
	dashboard.attach(_nav)
	_markers.cover = dashboard
	_nav_card.attach(_nav)
	_nav_strip.attach(_nav)
	_nav.attach(dashboard, _nav_card)
	Events.towed.connect(_on_towed)
	if not Game.launch_args.smoke and GameStart.pending:
		_ship.model_id = GameStart.ship_id
		var began := GameStart.begin(_ship, _origin, _arrivals)
		_cameras.snap()
		if began == GameStart.Began.DOCKED or began == GameStart.Began.IN_SPACE:
			_hud.welcome_back(_ship.berth)
		return
	_ship.global_transform = _system.start_transform()
	_origin.shift(_ship.global_position)
	if not Game.launch_args.smoke:
		return
	# Nobody at the controls: the autopilot fills the ship's input, and losing the mouse never pauses. Its saves go to
	# a file of its own, never the player's.
	_autosave.path = SmokeRun.SAVE_PATH
	_pause.controls = null
	_hud.controls = null
	_nav.controls = null
	_pilot.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.launch_args.nav:
		var orders := NavSmokeRun.new()
		orders.ship = _ship
		orders.nav = _nav
		orders.system = _system
		orders.arrivals = _arrivals
		orders.cameras = _cameras
		orders.screen = dashboard
		orders.card = _nav_card
		add_child(orders)
		return
	var smoke := SmokeRun.new()
	smoke.ship = _ship
	smoke.origin = _origin
	smoke.pause = _pause
	smoke.cameras = _cameras
	smoke.system = _system
	smoke.arrivals = _arrivals
	smoke.autosave = _autosave
	smoke.hud = _hud
	add_child(smoke)


func _exit_tree() -> void:
	if Events.towed.is_connected(_on_towed):
		Events.towed.disconnect(_on_towed)


func _on_towed(_port: Port) -> void:
	_origin.shift(_ship.global_position)
	_cameras.snap()
