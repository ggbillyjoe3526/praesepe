class_name ShipCameras
extends Node
## Which camera the player sees the ship through: the cockpit (first person, the main view) or the chase camera behind
## the ship (design doc, "Camera"). V switches between them while flying; the game starts in the cockpit. Owns the
## shared camera shake, applies the player's field of view to both cameras, and places the active one every frame
## before the HUD draws over it (FlightOrder.CAMERAS_DRAW). Each physics tick, after the world has moved, it tells the
## shake what the ship felt (FlightOrder.CAMERAS).

signal view_changed(view: View)

enum View { COCKPIT, CHASE }

@export var ship: Ship
@export var tuning: CameraTuning

var view: View = View.COCKPIT
var shake: CameraShake

@onready var cockpit: CockpitCamera = $CockpitCamera
@onready var chase: ChaseCamera = $ChaseCamera


func _ready() -> void:
	process_priority = FlightOrder.CAMERAS_DRAW
	process_physics_priority = FlightOrder.CAMERAS
	shake = CameraShake.new(Game.rng(Game.FX_STREAM).randi())
	cockpit.ship = ship
	cockpit.tuning = tuning
	cockpit.shake = shake
	chase.setup(ship, tuning, shake)
	Settings.changed.connect(_apply_settings)
	Events.arrived.connect(_on_arrived)
	_apply_settings()
	set_view(View.COCKPIT)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)
	if Events.arrived.is_connected(_on_arrived):
		Events.arrived.disconnect(_on_arrived)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_camera"):
		get_viewport().set_input_as_handled()
		set_view(View.CHASE if view == View.COCKPIT else View.COCKPIT)


func _physics_process(_delta: float) -> void:
	shake.feel(ship.jolt, ship.thrust_level(), tuning)


func _process(delta: float) -> void:
	shake.advance(delta, tuning)
	if view == View.CHASE:
		chase.place(delta)
	else:
		cockpit.place(delta)


func set_view(to: View) -> void:
	view = to
	if to == View.CHASE:
		chase.snap()
		chase.place(0.0)
		chase.make_current()
	else:
		cockpit.settle()
		cockpit.place(0.0)
		cockpit.make_current()
	view_changed.emit(to)


## Puts the camera in place at once, with no lag or sway carried over: the ship was just moved somewhere else.
func snap() -> void:
	if view == View.CHASE:
		chase.snap()
		chase.place(0.0)
	else:
		cockpit.settle()
		cockpit.place(0.0)


## The camera the player is looking through.
func current() -> Camera3D:
	return chase if view == View.CHASE else cockpit


func _on_arrived(_port: Port) -> void:
	snap()


func _apply_settings() -> void:
	cockpit.fov = Settings.fov
	chase.fov = Settings.fov
