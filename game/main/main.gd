extends Node3D
## The first scene: flight in an empty sky. A greybox ship with a cockpit among a few buoys, with space dust and stars
## to judge motion by, seen from the cockpit or the chase camera (ShipCameras). Launched with `-- --smoke`, the autopilot flies it instead of the player (game/debug/smoke_run.gd).

@onready var _ship: Ship = $World/Ship
@onready var _origin: FloatingOrigin = $FloatingOrigin
@onready var _pilot: PilotControls = $PilotControls
@onready var _hud: FlightHud = $Hud/FlightHud
@onready var _pause: PauseScreen = $PauseScreen
@onready var _cameras: ShipCameras = $ShipCameras


func _ready() -> void:
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
	add_child(smoke)
