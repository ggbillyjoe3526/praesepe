class_name CelestialBody
extends Landmark
## A planet or moon (design doc, "Planets and moons"): a solid sphere of `radius` metres with its surface look, and an
## optional glow of atmosphere around it. It builds its own sphere meshes and collision from the radius when it enters
## the scene, so its look, its collision and the cruise drive's idea of its size always agree. Close up it is drawn
## with a finely divided sphere; past `lod_distance` with a coarse one, which looks the same from that far (its edge
## is out by under a pixel). Its collision is one sphere shape. Placeholder look until the art style is chosen.
## The ship can park in orbit round it (Orbit) between its two orbit heights, going round at its orbit speed.

## Segments around and rings from pole to pole, close up and far away.
const NEAR_SEGMENTS := 128
const NEAR_RINGS := 64
const FAR_SEGMENTS := 48
const FAR_RINGS := 24
const GLOW_SEGMENTS := 64
const GLOW_RINGS := 32
## How far (share of lod_distance) the camera must go past the switch before it switches back, so it never flickers.
const LOD_HYSTERESIS := 0.03

## What saves call it (`&"calder"`): never shown and never renamed, unlike its display name.
@export var id: StringName = &""
## Its surface (game/system/body_surface.gdshader).
@export var surface: Material
## The glow around it (game/system/atmosphere.gdshader), or none for an airless moon.
@export var atmosphere: ShaderMaterial
## How far (m) the glow reaches above the surface.
@export var atmosphere_height: float = 0.0
## Beyond this distance (m) from the camera the coarse sphere is drawn.
@export var lod_distance: float = 40000.0

@export_group("Orbit")
## The lowest and highest orbits (m above the surface). Below the highest, the HUD offers to enter orbit; entering
## lower than the lowest climbs to it.
@export var orbit_min_altitude: float = 500.0
@export var orbit_max_altitude: float = 4000.0
## How fast (m/s) a ship goes round in orbit.
@export var orbit_speed: float = 90.0


func _ready() -> void:
	var ball := SphereShape3D.new()
	ball.radius = radius
	var shape := CollisionShape3D.new()
	shape.shape = ball
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_child(shape)
	add_child(body)
	_add_sphere("Near", radius, NEAR_SEGMENTS, NEAR_RINGS, surface).visibility_range_end = lod_distance
	_add_sphere("Far", radius, FAR_SEGMENTS, FAR_RINGS, surface).visibility_range_begin = lod_distance
	if atmosphere != null:
		_add_sphere("Atmosphere", radius + atmosphere_height, GLOW_SEGMENTS, GLOW_RINGS, atmosphere)


## Points the atmosphere's glow at the sun (`towards_sun`, world space, unit), so its night side stays dark.
func light_from(towards_sun: Vector3) -> void:
	if atmosphere != null:
		atmosphere.set_shader_parameter(&"sun_direction", towards_sun)


func _add_sphere(node_name: String, sphere_radius: float, segments: int, rings: int,
		material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = sphere_radius
	mesh.height = sphere_radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_begin_margin = lod_distance * LOD_HYSTERESIS
	instance.visibility_range_end_margin = lod_distance * LOD_HYSTERESIS
	add_child(instance)
	return instance
