class_name SolarSystem
extends Node3D
## The tiny solar system of the first playable (design doc, "The tiny solar system"), one self-contained scene
## (game/system/solar_system.tscn), so more systems can be added later without touching the rest of the game. It
## holds the sun's light, every place in the system as a Landmark (the planet, its base, the moon, the station and the
## asteroid belt) and the point the player starts from. Everything in it is authored and placed by hand; only the
## belt's rocks come from the world seed. Its origin is the planet's centre. The bodies hold still: orbits come later.

## Where the player's ship starts, and a point it starts looking at.
@export var start: Marker3D
@export var start_look: Marker3D
## The sun: its light shines along its -z axis.
@export var sun: DirectionalLight3D

## Every place in the system, in scene order.
var landmarks: Array[Landmark] = []


func _ready() -> void:
	_collect(self)
	for l: Landmark in landmarks:
		var body := l as CelestialBody
		if body != null:
			body.light_from(sun.global_basis.z)


## The ship's starting place and heading (world space).
func start_transform() -> Transform3D:
	var at := start.global_position
	return Transform3D(Basis.looking_at(start_look.global_position - at, Vector3.UP), at)


## Tells the system which ship to keep the surroundings solid for (the belt's rocks).
func track(ship: Node3D) -> void:
	for l: Landmark in landmarks:
		var belt := l as AsteroidBelt
		if belt != null:
			belt.focus = ship


## The landmark called `display_name`, or null.
func landmark(display_name: String) -> Landmark:
	for l: Landmark in landmarks:
		if l.display_name == display_name:
			return l
	return null


func _collect(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Landmark:
			landmarks.append(child)
		_collect(child)
