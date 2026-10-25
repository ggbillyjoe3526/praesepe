class_name NavScreen
extends MeshInstance3D
## The nav computer on the cockpit's dashboard (design doc, "Nav computer"): a screen in the world, in front of the
## speed screen, as tall and wider, that lights up while the nav computer is open in the cockpit. It shows a NavPanel drawn
## in a viewport of its own, and passes the mouse on to it where the mouse points at the screen, so it is clicked like
## any screen. Its quad (a QuadMesh) is set in the cockpit's scene; the panel's canvas matches its shape.

## The panel's canvas (px) for the quad's size, its main text size, and the plan rows it has room for.
@export var canvas: Vector2i = Vector2i(1600, 340)
@export var font_size: int = 30
@export var max_rows: int = 3

var _viewport: SubViewport
var _panel: NavPanel


func _ready() -> void:
	visible = false
	_viewport = SubViewport.new()
	_viewport.size = canvas
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.gui_disable_input = false
	add_child(_viewport)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_texture = _viewport.get_texture()
	material_override = look
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_changed.connect(_on_visibility_changed)


## Shows `nav` on the screen.
func attach(nav: NavComputer) -> void:
	_panel = NavPanel.new()
	_panel.font_size = font_size
	_panel.max_rows = max_rows
	_panel.compact = false
	_viewport.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.attach(nav)


func _on_visibility_changed() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null or not visible or _panel == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := screen_point(camera.project_ray_origin(mouse.position), camera.project_ray_normal(mouse.position))
	if at.x < 0.0:
		return
	var moved := mouse.duplicate() as InputEventMouse
	moved.position = at
	moved.global_position = at
	_viewport.push_input(moved, true)
	get_viewport().set_input_as_handled()


## The screen's four corners, in world space.
func corners() -> PackedVector3Array:
	var half := (mesh as QuadMesh).size * 0.5 if mesh is QuadMesh else Vector2.ZERO
	var out := PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(global_transform * Vector3(c.x * half.x, c.y * half.y, 0.0))
	return out


## Where a ray from `from` along `along` (world space) meets the screen, in the panel's canvas (px), or (-1, -1) when
## it misses.
func screen_point(from: Vector3, along: Vector3) -> Vector2:
	var quad := mesh as QuadMesh
	if quad == null:
		return Vector2(-1.0, -1.0)
	var to_local := global_transform.affine_inverse()
	var o := to_local * from
	var d := to_local.basis * along
	if absf(d.z) < 1.0e-6:
		return Vector2(-1.0, -1.0)
	var t := -o.z / d.z
	if t <= 0.0:
		return Vector2(-1.0, -1.0)
	var hit := o + d * t
	var u := hit.x / quad.size.x + 0.5
	var v := 0.5 - hit.y / quad.size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(u * canvas.x, v * canvas.y)
