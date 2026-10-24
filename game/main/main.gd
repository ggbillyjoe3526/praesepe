extends Node3D
## The first scene: the tiny solar system (game/system/solar_system.tscn) with the player's greybox ship, seen from the
## cockpit or the chase camera (ShipCameras), with HUD markers on every place. The ship starts at the system's start
## point next to the station, and the floating origin is centred on it from the first tick, so true positions are the
## system's own (the planet's centre is 0, 0, 0). Launched with `-- --smoke`, the autopilot flies it instead of the
## player (game/debug/smoke_run.gd).

@onready var _ship: Ship = $World/Ship
@onready var _origin: FloatingOrigin = $FloatingOrigin
@onready var _pilot: PilotControls = $PilotControls
@onready var _hud: FlightHud = $Hud/FlightHud
@onready var _pause: PauseScreen = $PauseScreen
@onready var _cameras: ShipCameras = $ShipCameras
@onready var _system: SolarSystem = $World/SolarSystem
@onready var _markers: LandmarkMarkers = $Hud/LandmarkMarkers


func _ready() -> void:
	_ship.global_transform = _system.start_transform()
	_origin.shift(_ship.global_position)
	_ship.cruise.landmarks = _system.landmarks
	_system.track(_ship)
	_markers.show_places(_system.landmarks)
	if not Game.launch_args.smoke:
		return
	# Nobody at the controls: the autopilot fills the ship's input, and losing the mouse never pauses.
	_pause.controls = null
	_hud.controls = null
	_pilot.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var smoke := SmokeRun.new()
	smoke.ship = _ship
	smoke.origin = _origin
	smoke.pause = _pause
	smoke.cameras = _cameras
	smoke.system = _system
	add_child(smoke)
