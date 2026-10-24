class_name FloatingOrigin
extends Node
## Keeps the ship near the world's origin so nothing jitters far out (design doc, "Large-world precision"). Engine
## positions are 32-bit, fine to a fraction of a millimetre near the origin but visibly shaky thousands of kilometres
## out. When the ship strays more than `threshold` metres from the origin, every child of `world` moves back by the
## ship's position, all in the same physics tick, so nothing visibly moves. The distance moved so far is kept in
## 64-bit numbers (`offset_x`, `offset_y`, `offset_z`): the true position of anything is its position plus that offset.
##
## Everything that lives in the world goes under `world`; screen-space things and the camera's own effects don't.

## After a shift: `by` is how far everything moved (the ship's old position; everything moved by minus this).
signal shifted(by: Vector3)

## How far (m) the ship may stray from the origin before the world is re-centred.
@export var threshold: float = 2048.0
## The node whose children are moved.
@export var world: Node3D
## What is kept near the origin (the player's ship).
@export var focus: Node3D

var offset_x: float = 0.0
var offset_y: float = 0.0
var offset_z: float = 0.0
## How many times the world has been re-centred.
var shift_count: int = 0


func _ready() -> void:
	process_physics_priority = FlightOrder.ORIGIN


func _physics_process(_delta: float) -> void:
	if focus != null and focus.global_position.length() > threshold:
		shift(focus.global_position)


## Moves every child of `world` by -`by` and adds `by` to the offset.
func shift(by: Vector3) -> void:
	if world == null:
		return
	for child: Node in world.get_children():
		var node := child as Node3D
		if node == null:
			continue
		node.global_position -= by
		node.reset_physics_interpolation()
	offset_x += by.x
	offset_y += by.y
	offset_z += by.z
	shift_count += 1
	shifted.emit(by)


## The true position of a world position, axis by axis in 64-bit (x, y, z), for readouts and checks. Allocates: never
## call it every frame in flight.
func true_position(local: Vector3) -> PackedFloat64Array:
	return PackedFloat64Array([offset_x + local.x, offset_y + local.y, offset_z + local.z])


## How far the origin has moved, wrapped into [0, size) on each axis, worked out in 64-bit so it stays exact however
## far the ship has gone. Repeating effects (space dust) use it to keep their pattern still across a shift.
func wrapped_offset(size: float) -> Vector3:
	return Vector3(fposmod(offset_x, size), fposmod(offset_y, size), fposmod(offset_z, size))
