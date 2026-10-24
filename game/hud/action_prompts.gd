class_name ActionPrompts
extends Control
## The HUD's prompts for docking, landing and orbit (design doc, "Docking and landing", "Orbit"), so the player always
## knows what they can do here and what to do first: "G  Dock at Halfway Station", "Slow below 100 m/s to land at
## Tollgate", "O  Enter orbit round Calder", "G  Undock". Up to two lines on a dark plate a little under the middle of
## the view, hidden when there is nothing to say. Each line is rebuilt only when what it says changes (a distance, as
## shown, counts). Placeholder look until the art style is chosen.

const FONT_SIZE := 26
const GAP := 6
const KEY_COLOUR := Color(0.92, 0.95, 1.0)
const HINT_COLOUR := Color(1.0, 0.86, 0.5)
const ORBIT_COLOUR := Color(0.78, 0.72, 1.0)
## Where the plate sits: its bottom this far (px at 1080p) above the screen's bottom, above the cockpit's dashboard
## and the chase view's plate, a little under the middle of the view.
const BOTTOM := 400.0

@export var ship: Ship
@export var arrivals: Arrivals

var _plate: PanelContainer
var _port_line: Label
var _orbit_line: Label
var _port_key: int = -1
var _orbit_key: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _process(_delta: float) -> void:
	if ship == null or arrivals == null:
		return
	var key := _port_state()
	if key != _port_key:
		_port_key = key
		_port_line.text = ActionPrompts.port_text(arrivals.stage, arrivals.nearest if arrivals.stage ==
				Arrivals.Stage.FLYING else arrivals.port, arrivals.refusal, arrivals.nearest_distance)
		_port_line.visible = not _port_line.text.is_empty()
		_port_line.add_theme_color_override("font_color", KEY_COLOUR if arrivals.refusal == Arrivals.Refusal.NONE
				or arrivals.stage != Arrivals.Stage.FLYING else HINT_COLOUR)
	key = _orbit_state()
	if key != _orbit_key:
		_orbit_key = key
		var o := ship.orbit
		var flying := arrivals.stage == Arrivals.Stage.FLYING
		_orbit_line.text = ActionPrompts.orbit_text(o.phase, o.body if o.active() else o.offered, o.refusal,
				o.tuning.max_entry_speed) if flying else ""
		_orbit_line.visible = not _orbit_line.text.is_empty()
	_plate.visible = _port_line.visible or _orbit_line.visible


## The docking or landing line: at `stage`, about port `p` (the nearest one while flying, the berth once there),
## offered or not (`why`), `distance` away (Port.distance). Empty when there is nothing to say.
static func port_text(stage: Arrivals.Stage, p: Port, why: Arrivals.Refusal, distance: float) -> String:
	if p == null:
		return ""
	var dock := p.kind == Port.Kind.DOCK
	match stage:
		Arrivals.Stage.DOCKED:
			return "G   Undock" if dock else "G   Take off"
		Arrivals.Stage.FLYING:
			var verb := "dock at" if dock else "land at"
			match why:
				Arrivals.Refusal.NONE:
					return ("G   Dock at %s" if dock else "G   Land at %s") % p.place_name()
				Arrivals.Refusal.TOO_FAST:
					return "Slow below %d m/s to %s %s" % [roundi(p.max_speed), verb, p.place_name()]
				Arrivals.Refusal.TOO_FAR:
					if dock:
						return "Fly within %s of %s to dock (%s)" % [LandmarkMarkers.distance_text(p.offer_range),
								p.place_name(), LandmarkMarkers.distance_text(distance)]
					return "Descend below %s to land at %s (%s up)" % [LandmarkMarkers.distance_text(p.offer_range),
							p.place_name(), LandmarkMarkers.distance_text(distance)]
	return ""


## The orbit line: in `phase`, about `body` (orbited, or offered), offered or not (`why`, with the top entry speed
## `max_speed`). Empty when there is nothing to say.
static func orbit_text(phase: Orbit.Phase, body: CelestialBody, why: Orbit.Refusal, max_speed: float) -> String:
	if body == null:
		return ""
	match phase:
		Orbit.Phase.ENTERING:
			return "Entering orbit round %s   ·   O to cancel" % body.display_name
		Orbit.Phase.ORBITING:
			return "O   Leave orbit round %s" % body.display_name
	match why:
		Orbit.Refusal.NONE:
			return "O   Enter orbit round %s" % body.display_name
		Orbit.Refusal.TOO_FAST:
			return "Slow below %d m/s to enter orbit round %s" % [roundi(max_speed), body.display_name]
		Orbit.Refusal.TOO_STEEP:
			return "Level out to enter orbit round %s" % body.display_name
	return ""


## A number that changes exactly when the docking line's words do (worked out without allocating, every frame).
func _port_state() -> int:
	var p := arrivals.nearest if arrivals.stage == Arrivals.Stage.FLYING else arrivals.port
	var id := p.get_instance_id() if p != null else 0
	var shown := 0
	if arrivals.refusal == Arrivals.Refusal.TOO_FAR and arrivals.nearest_distance < INF:
		shown = LandmarkMarkers.distance_key(arrivals.nearest_distance)
	return ((id * 31 + arrivals.stage) * 31 + arrivals.refusal) * 1000003 + shown


## A number that changes exactly when the orbit line's words do.
func _orbit_state() -> int:
	var o := ship.orbit
	var b := o.body if o.active() else o.offered
	var id := b.get_instance_id() if b != null else 0
	return ((id * 31 + arrivals.stage) * 31 + o.phase) * 31 + o.refusal


func _build() -> void:
	_plate = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.04, 0.08, 0.88)
	box.set_corner_radius_all(8)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	_plate.add_theme_stylebox_override("panel", box)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_plate.offset_top = -BOTTOM
	_plate.offset_bottom = -BOTTOM
	add_child(_plate)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(list)
	_port_line = _line(list, KEY_COLOUR)
	_orbit_line = _line(list, ORBIT_COLOUR)
	_plate.visible = false


func _line(parent: Control, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	parent.add_child(label)
	return label
