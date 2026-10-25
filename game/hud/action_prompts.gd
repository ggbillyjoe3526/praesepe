class_name ActionPrompts
extends Control
## The HUD's prompts for docking, landing and orbit (design doc, "Docking and landing", "Orbit"), so the player always
## knows what they can do here and what to do first: "G  Dock", "Slow below 100 m/s to land", "O  Enter orbit",
## "Docking  ·  G to cancel", "G  Undock", and "F  Cruise" while the nose is aimed at a place the cruise drive would
## lock onto (not while docking or landing is offered). Each is kept short: the place is named by its marker and on the
## dashboard. With "SLOW DOWN  ·  Halfway Station in 4 s" above them while the ship is coming at something faster than
## it could comfortably stop (Arrivals.warning). Up to four lines on a dark plate a little under the middle of the
## view, hidden when there is nothing to say. Each line is rebuilt only when what it says changes (a distance, as
## shown, counts). Placeholder look until the art style is chosen.

const FONT_SIZE := 26
const GAP := 6
const KEY_COLOUR := Color(0.92, 0.95, 1.0)
const HINT_COLOUR := Color(1.0, 0.86, 0.5)
const ORBIT_COLOUR := Color(0.78, 0.72, 1.0)
const CRUISE_COLOUR := FlightHud.CRUISE_COLOUR
const WARNING_COLOUR := Color(1.0, 0.45, 0.38)
## Where the plate sits: its bottom this far (px at 1080p) above the screen's bottom, above the cockpit's dashboard
## and the chase view's plate, a little under the middle of the view. The bottom stays at the same height on the screen
## at any interface size (Settings.ui_scale), so a bigger plate never slides down over the cockpit's dashboard; it
## grows upward, which UI_SCALES' 125% cap keeps clear of the nose mark for two lines.
const BOTTOM := 400.0
## The state keys below fold their parts together like a hash: each part times MIX, and the distance's own key
## (LandmarkMarkers.distance_key, always far under DISTANCE_KEYS) added last, so different states give different keys.
const MIX := 31
const DISTANCE_KEYS := 1000003

@export var ship: Ship
@export var arrivals: Arrivals

var _plate: PanelContainer
var _warning_line: Label
var _port_line: Label
var _orbit_line: Label
var _cruise_line: Label
var _port_key: int = -1
var _orbit_key: int = -1
var _cruise_key: int = -1
var _warning_key: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _process(_delta: float) -> void:
	if ship == null or arrivals == null:
		return
	var key := _warning_state()
	if key != _warning_key:
		_warning_key = key
		_warning_line.text = ActionPrompts.warning_text(arrivals.warning_place, arrivals.warning_time) \
				if arrivals.warning else ""
		_warning_line.visible = arrivals.warning
	key = _port_state()
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
	# Close enough to dock or land, G is what matters: no cruise offer beside it.
	var docking := arrivals.nearest != null and arrivals.refusal == Arrivals.Refusal.NONE
	var aimed := ship.cruise.aimed if arrivals.stage == Arrivals.Stage.FLYING and not docking else null
	key = aimed.get_instance_id() if aimed != null else 0
	if key != _cruise_key:
		_cruise_key = key
		_cruise_line.text = ActionPrompts.cruise_text(aimed)
		_cruise_line.visible = not _cruise_line.text.is_empty()
	_plate.visible = _warning_line.visible or _port_line.visible or _orbit_line.visible or _cruise_line.visible


## The speed warning: coming at `place` (or something that is no place's) faster than it could comfortably stop,
## getting there in `seconds` at this speed.
static func warning_text(place: Landmark, seconds: float) -> String:
	var what := place.display_name if place != null else "Obstacle"
	return "SLOW DOWN   ·   %s in %d s" % [what, ceili(seconds)]


## The docking or landing line: at `stage`, about port `p` (the nearest one while flying, the berth once there),
## offered or not (`why`), `distance` away (Port.distance). Empty when there is nothing to say.
static func port_text(stage: Arrivals.Stage, p: Port, why: Arrivals.Refusal, distance: float) -> String:
	if p == null:
		return ""
	var dock := p.kind == Port.Kind.DOCK
	match stage:
		Arrivals.Stage.APPROACHING:
			return "Docking   ·   G to cancel" if dock else "Landing   ·   G to cancel"
		Arrivals.Stage.DOCKED:
			return "G   Undock" if dock else "G   Take off"
		Arrivals.Stage.FLYING:
			var verb := "dock" if dock else "land"
			match why:
				Arrivals.Refusal.NONE:
					return "G   Dock" if dock else "G   Land"
				Arrivals.Refusal.TOO_FAST:
					return "Slow below %d m/s to %s" % [roundi(p.max_speed), verb]
				Arrivals.Refusal.TOO_FAR:
					return "Fly within %s to %s (%s)" % [LandmarkMarkers.distance_text(p.offer_range), verb,
							LandmarkMarkers.distance_text(distance)]
	return ""


## The orbit line: in `phase`, about `body` (orbited, or offered), offered or not (`why`, with the top entry speed
## `max_speed`). Empty when there is nothing to say, as when the ship is still below or above the orbit line (the
## insertion marker, OrbitMarker, shows the way there).
static func orbit_text(phase: Orbit.Phase, body: CelestialBody, why: Orbit.Refusal, max_speed: float) -> String:
	if body == null:
		return ""
	match phase:
		Orbit.Phase.ENTERING:
			return "Entering orbit   ·   O to cancel"
		Orbit.Phase.ORBITING:
			return "O   Leave orbit"
		Orbit.Phase.LEAVING:
			return "Levelling out to leave orbit"
	match why:
		Orbit.Refusal.NONE:
			return "O   Enter orbit"
		Orbit.Refusal.TOO_FAST:
			return "Slow below %d m/s to enter orbit" % roundi(max_speed)
		Orbit.Refusal.TOO_STEEP:
			return "Level out to enter orbit"
	return ""


## The cruise line: F locks the cruise drive onto `aimed` (CruiseDrive.aimed). Empty when nothing is aimed at.
static func cruise_text(aimed: Landmark) -> String:
	return "F   Cruise" if aimed != null else ""


## A number that changes exactly when the docking line's words do (worked out without allocating, every frame).
func _port_state() -> int:
	var p := arrivals.nearest if arrivals.stage == Arrivals.Stage.FLYING else arrivals.port
	var id := p.get_instance_id() if p != null else 0
	var shown := 0
	if arrivals.refusal == Arrivals.Refusal.TOO_FAR and arrivals.nearest_distance < INF:
		shown = LandmarkMarkers.distance_key(arrivals.nearest_distance)
	return ((id * MIX + arrivals.stage) * MIX + arrivals.refusal) * DISTANCE_KEYS + shown


## A number that changes exactly when the speed warning's words do.
func _warning_state() -> int:
	if not arrivals.warning:
		return 0
	var id := arrivals.warning_place.get_instance_id() if arrivals.warning_place != null else 0
	return (id * MIX + ceili(arrivals.warning_time)) * MIX + 1


## A number that changes exactly when the orbit line's words do.
func _orbit_state() -> int:
	var o := ship.orbit
	var b := o.body if o.active() else o.offered
	var id := b.get_instance_id() if b != null else 0
	return ((id * MIX + arrivals.stage) * MIX + o.phase) * MIX + o.refusal


func _exit_tree() -> void:
	if Settings.changed.is_connected(_place):
		Settings.changed.disconnect(_place)


## The plate's bottom BOTTOM px (at 1080p, on the screen) above the screen's bottom, whatever the interface size.
func _place() -> void:
	_plate.offset_top = -BOTTOM / Settings.ui_scale
	_plate.offset_bottom = _plate.offset_top


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
	add_child(_plate)
	_place()
	Settings.changed.connect(_place)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(list)
	_warning_line = _line(list, WARNING_COLOUR)
	_port_line = _line(list, KEY_COLOUR)
	_orbit_line = _line(list, ORBIT_COLOUR)
	_cruise_line = _line(list, CRUISE_COLOUR)
	_plate.visible = false


func _line(parent: Control, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	parent.add_child(label)
	return label
