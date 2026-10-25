class_name GuideLight
extends MeshInstance3D
## The faint light along a port's way in (design doc, "How docking and landing work"), so the pilot can line up by eye
## before pressing G: a soft beam shining out of a station's bay along its line in, or straight up from a landing pad.
## Its port (Port) adds it to itself and sets how it looks (guide_colour, guide_start, guide_reach, guide_radius). While
## the ship is in the port's lane or flying itself in (Port.guiding) it shines brighter. Built once when it enters the
## scene; it runs each frame only while easing its brightness (wake), and isn't drawn from farther than DRAW_RANGE.
## Placeholder look until the art style is chosen.

## How bright it shines (shader strength): faint, and lined up or on the way in.
const FAINT := 0.3
const BRIGHT := 0.7
## It eases between them over about this long (s).
const EASE_TIME := 0.4
## Not drawn from farther than this (m): from there it would be under a pixel wide.
const DRAW_RANGE := 8000.0

var port: Port

var _material: ShaderMaterial
var _strength: float = FAINT


func _ready() -> void:
	var length := port.guide_reach - port.guide_start
	var beam := CylinderMesh.new()
	beam.top_radius = port.guide_radius
	beam.bottom_radius = port.guide_radius
	beam.height = length
	beam.radial_segments = 12
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	_material = ShaderMaterial.new()
	_material.shader = preload("res://game/arrival/guide_light.gdshader")
	_material.set_shader_parameter(&"colour", port.guide_colour)
	_material.set_shader_parameter(&"beam_length", length)
	_material.set_shader_parameter(&"strength", _strength)
	beam.material = _material
	mesh = beam
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = DRAW_RANGE
	visibility_range_end_margin = DRAW_RANGE * 0.05
	set_process(false)
	# The mesh's y axis along the way out (the port's -z out of a bay, its y up off a pad), from guide_start out.
	var out := Vector3.UP if port.kind == Port.Kind.PAD else Vector3.FORWARD
	var turn := Basis.IDENTITY if port.kind == Port.Kind.PAD else Basis(Vector3.RIGHT, -PI / 2.0)
	transform = Transform3D(turn, Vector3(0.0, port.settle, 0.0) + out * (port.guide_start + length * 0.5))


## Starts easing toward the brightness Port.guiding asks for.
func wake() -> void:
	set_process(true)


func _process(delta: float) -> void:
	var want := BRIGHT if port.guiding else FAINT
	_strength = move_toward(_strength, want, (BRIGHT - FAINT) * delta / EASE_TIME)
	_material.set_shader_parameter(&"strength", _strength)
	if _strength == want:
		set_process(false)
