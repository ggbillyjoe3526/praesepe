class_name LandmarkMarkers
extends Control
## The HUD markers for the places in the solar system (Landmark.marker), so the player always knows where everything
## is: a diamond on each place with its name and distance on a dark plate, drawn through whichever camera is active
## (ShipCameras). A place off the screen or behind the camera sits at the screen's edge on the side to turn to, as a
## hollow diamond. Labels that would cover each other stack instead. The place the ship is docked or landed at (and
## the planet under it) has no marker until it leaves. The place the nose is aimed at, which F would lock the cruise
## drive onto (CruiseDrive.aimed), is framed in corner brackets; the place the drive is locked onto is framed and drawn
## in the cruise colour. A label is rebuilt only when its distance, as shown, changes. A placeholder look until the art
## style is chosen.

const COLOUR := Color(1.0, 0.86, 0.5)
const PLATE_COLOUR := Color(0.03, 0.04, 0.08, 0.85)
## Sizes in px at 1080p: the diamond, the gap to its label, the label's text and the plate's padding, and how close
## to the screen's edge markers come.
const DIAMOND := 9.0
const LABEL_GAP := 14.0
const FONT_SIZE := 20
const PAD := Vector2(8.0, 3.0)
const EDGE := 90.0
const LINE_WIDTH := 2.0
## The corner brackets round an aimed or locked marker: how far (px at 1080p) from its middle, and how long each arm is.
const BRACKET := 17.0
const BRACKET_ARM := 7.0
const CORNERS: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]

@export var ship: Ship
@export var cameras: ShipCameras

var _places: Array[Landmark] = []
var _labels: PackedStringArray = PackedStringArray()
var _label_sizes: PackedVector2Array = PackedVector2Array()
var _shown: PackedInt32Array = PackedInt32Array()
## The label plates drawn so far this frame, so the next one can keep clear of them.
var _plates: Array[Rect2] = []
var _plate_count: int = 0
var _font: Font
## The diamond's corners, refilled for each marker so drawing allocates nothing: four for the filled one, five (back
## to the start) for the outline.
var _diamond: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _outline: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
		Vector2.ZERO])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


## Shows a marker for each of `places` that wants one (SolarSystem.landmarks).
func show_places(places: Array[Landmark]) -> void:
	_places.clear()
	for l: Landmark in places:
		if l.marker:
			_places.append(l)
	_labels.resize(_places.size())
	_label_sizes.resize(_places.size())
	_shown.resize(_places.size())
	_shown.fill(-1)
	_plates.resize(_places.size())


## The distance as a marker shows it: tens of metres up close, tenths of a kilometre to 10 km, whole kilometres beyond.
static func distance_text(metres: float) -> String:
	if metres < 995.0:
		return "%d m" % (roundi(metres / 10.0) * 10)
	if metres < 9950.0:
		return "%.1f km" % (metres / 1000.0)
	return "%d km" % roundi(metres / 1000.0)


## A number that changes exactly when distance_text() does.
static func distance_key(metres: float) -> int:
	if metres < 995.0:
		return roundi(metres / 10.0)
	if metres < 9950.0:
		return 1000 + roundi(metres / 100.0)
	return 100000 + roundi(metres / 1000.0)


## `plate` moved up (or down) a plate's height at a time until it covers none of the first `count` of `taken`.
static func stack(plate: Rect2, taken: Array[Rect2], count: int, up: bool) -> Rect2:
	var step := (plate.size.y + 2.0) * (-1.0 if up else 1.0)
	var moved := true
	while moved:
		moved = false
		for j in count:
			if plate.intersects(taken[j]):
				plate.position.y += step
				moved = true
				break
	return plate


func _process(_delta: float) -> void:
	if ship == null or cameras == null:
		return
	for i in _places.size():
		var metres := _places[i].marker_distance(ship.global_position)
		var key := LandmarkMarkers.distance_key(metres)
		if key != _shown[i]:
			_shown[i] = key
			_labels[i] = "%s  ·  %s" % [_places[i].display_name, LandmarkMarkers.distance_text(metres)]
			_label_sizes[i] = _font.get_string_size(_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	queue_redraw()


func _draw() -> void:
	if ship == null or cameras == null:
		return
	var camera := cameras.current()
	var view := camera.global_transform
	var screen := size
	var centre := screen * 0.5
	_plate_count = 0
	# The place the ship is docked or landed at, and the planet under it, are all around it: no markers for them until
	# the ship has left.
	var here: Landmark = ship.berth.place if ship.berth != null else null
	var under: Landmark = ship.berth.body if ship.berth != null else null
	var aimed := ship.cruise.aimed
	var locked := FlightHud.target_of(ship)
	for i in _places.size():
		if _places[i] == here or _places[i] == under:
			continue
		var at := ScreenMarker.project(view, camera.fov, screen, _places[i].marker_position() - view.origin)
		var point := Vector2(at.x, at.y)
		if at.z <= 0.0:
			# Behind the camera: out at the edge on the side the place is, so turning that way finds it.
			var off := centre - point
			point = centre + (off.normalized() if off.length_squared() > 1.0 else Vector2.DOWN) * screen.length()
		var clamped := ScreenMarker.clamp_to_screen(point, screen, EDGE)
		var colour := FlightHud.CRUISE_COLOUR if _places[i] == locked else COLOUR
		_draw_marker(clamped, clamped == point, _labels[i], _label_sizes[i], screen, colour,
				_places[i] == locked or _places[i] == aimed)


func _draw_marker(p: Vector2, ahead: bool, label: String, label_size: Vector2, screen: Vector2, colour: Color,
		framed: bool) -> void:
	var d := DIAMOND
	_diamond[0] = p + Vector2(0, -d)
	_diamond[1] = p + Vector2(d, 0)
	_diamond[2] = p + Vector2(0, d)
	_diamond[3] = p + Vector2(-d, 0)
	if ahead:
		draw_colored_polygon(_diamond, colour)
	else:
		for k in 4:
			_outline[k] = _diamond[k]
		_outline[4] = _diamond[0]
		draw_polyline(_outline, colour, LINE_WIDTH, true)
	if framed:
		_draw_brackets(p, colour)
	# The label goes under the diamond, or over it near the bottom, and always wholly on the screen.
	var top_left := p + Vector2(-label_size.x * 0.5, d + LABEL_GAP * 0.5)
	if top_left.y + label_size.y + PAD.y > screen.y:
		top_left.y = p.y - d - LABEL_GAP * 0.5 - label_size.y
	top_left.x = clampf(top_left.x, PAD.x, maxf(screen.x - label_size.x - PAD.x, PAD.x))
	var plate := Rect2(top_left - PAD, label_size + PAD * 2.0)
	# Stacked away from the screen's nearer top or bottom edge, clear of the labels already drawn.
	plate = LandmarkMarkers.stack(plate, _plates, _plate_count, p.y > screen.y * 0.5)
	_plates[_plate_count] = plate
	_plate_count += 1
	draw_rect(plate, PLATE_COLOUR)
	draw_string(_font, plate.position + PAD + Vector2(0, _font.get_ascent(FONT_SIZE)), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


## Four corner brackets round the marker at `p`, like a sight's frame.
func _draw_brackets(p: Vector2, colour: Color) -> void:
	for c: Vector2 in CORNERS:
		var corner := p + c * BRACKET
		draw_line(corner, corner - Vector2(c.x * BRACKET_ARM, 0.0), colour, LINE_WIDTH, true)
		draw_line(corner, corner - Vector2(0.0, c.y * BRACKET_ARM), colour, LINE_WIDTH, true)
