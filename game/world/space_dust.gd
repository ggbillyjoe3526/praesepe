class_name SpaceDust
extends MultiMeshInstance3D
## Specks of dust drifting in space around the camera (space_dust.gdshader), so speed and drift read clearly where
## there is nothing else to see. One draw call, built once from the presentation stream (Game.FX_STREAM); each frame
## only two shader values change. It sits outside the floating origin's world and follows the origin's offset instead,
## so its pattern never jumps on a shift. Placeholder look until the art style is chosen.

const LATTICE_SHIFT := &"lattice_shift"
const STREAK := &"streak"
const BOX_SIZE := &"box_size"

@export var count: int = 1200
## The repeating box's size (m); the dust fades out before its edge.
@export var box_size: float = 400.0
## How long a streak is, in seconds of motion: at 200 m/s, 0.05 s gives 10 m streaks.
@export var streak_time: float = 0.05
@export var origin: FloatingOrigin
## Whose motion stretches the dust (the player's ship).
@export var ship: Ship

var _material: ShaderMaterial


func _ready() -> void:
	_material = material_override as ShaderMaterial
	_material.set_shader_parameter(BOX_SIZE, box_size)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count
	var rng := Game.rng(Game.FX_STREAM)
	for i in count:
		var at := Vector3(rng.randf(), rng.randf(), rng.randf()) * box_size
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	multimesh = mm
	# The specks are placed in the shader around the camera, wherever that is, so the usual bounds don't apply.
	var reach := box_size + (origin.threshold if origin != null else 0.0) * 2.0
	custom_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)


func _process(_delta: float) -> void:
	if origin != null:
		_material.set_shader_parameter(LATTICE_SHIFT, origin.wrapped_offset(box_size))
	if ship != null:
		_material.set_shader_parameter(STREAK, ship.linear_velocity * streak_time)
