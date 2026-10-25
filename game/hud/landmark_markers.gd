class_name LandmarkMarkers
extends Control
## The HUD markers for the places in the solar system (Landmark.marker), so the player always knows where everything
## is: a diamond on each place with its name and distance on a dark plate, drawn through whichever camera is active
## (ShipCameras). A place off the screen or behind the camera sits at the screen's edge on the side to turn to, as a
## hollow diamond. Labels that would cover each other stack instead. The place the ship is docked or landed at (and
## the planet under it) has no marker until it leaves. The place the nose is aimed at, which F would lock the cruise
## drive onto (CruiseDrive.aimed), is framed in corner brackets; the place the drive is locked onto is framed and drawn
## in the cruise colour. While the nav computer's dashboard screen (NavScreen) is lit, markers that fall on it are left
## off so they don't cover it. A label is rebuilt only when its distance, as shown, changes. A placeholder look until the
## art style is chosen.
##
## The diamonds and the names each show always, only for places the player has noticed, or never (the player's
## settings, Settings.marker_icons and marker_names; names default to noticed, so the screen stays clear). A place is
## noticed when it is within NEAR of the ship, near the middle of the view (LOOK_CONE), aimed at for a lock, or what
## the cruise drive is locked onto. Diamonds and names fade in and out over FADE_TIME rather than popping.

## When a marker's diamond or name shows (Settings.marker_icons and marker_names).
enum Show { ALWAYS, NEARBY, OFF }

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
## A place within this (m, as its marker's distance) is noticed.
const NEAR := 5000.0
## A place whose marker is within this (degrees) of the middle of the view is noticed; once noticed, it stays so until
## its marker is past LOOK_CONE_OUT, so a name at the cone's edge doesn't flicker.
const LOOK_CONE := 10.0
const LOOK_CONE_OUT := 14.0
## How long (s) a diamond or name takes to fade fully in or out.
const FADE_TIME := 0.25

@export var ship: Ship
@export var cameras: ShipCameras
## When the diamonds and the names show; follow the player's settings unless `follow_settings` is off (tests).
@export var icons: Show = Show.ALWAYS
@export var names: Show = Show.NEARBY
@export var follow_settings: bool = true
## The nav computer's dashboard screen, which markers keep off while it is lit.
var cover: NavScreen = null

var _places: Array[Landmark] = []
var _labels: PackedStringArray = PackedStringArray()
var _label_sizes: PackedVector2Array = PackedVector2Array()
var _shown: PackedInt32Array = PackedInt32Array()
## Per place: whether the player has noticed it, and how far its diamond and its name have faded in (0 to 1).
var _noticed: PackedByteArray = PackedByteArray()
var _icon_alpha: PackedFloat32Array = PackedFloat32Array()
var _name_alpha: PackedFloat32Array = PackedFloat32Array()
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
	if follow_settings:
		Settings.changed.connect(_apply_settings)
		_apply_settings()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)


## Takes the player's settings, shown at once with no fade: they change in the settings menu, while the game behind
## it is paused and nothing would fade.
func _apply_settings() -> void:
	icons = Settings.marker_icons as Show
	names = Settings.marker_names as Show
	for i in _places.size():
		_icon_alpha[i] = 1.0 if LandmarkMarkers.shows(icons, _noticed[i] != 0) else 0.0
		_name_alpha[i] = 1.0 if LandmarkMarkers.shows(names, _noticed[i] != 0) else 0.0
	queue_redraw()


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
	_noticed.resize(_places.size())
	_noticed.fill(0)
	# Places set to Always start faded in; places shown when noticed fade in once the first frame finds them noticed.
	_icon_alpha.resize(_places.size())
	_icon_alpha.fill(1.0 if icons == Show.ALWAYS else 0.0)
	_name_alpha.resize(_places.size())
	_name_alpha.fill(1.0 if names == Show.ALWAYS else 0.0)


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


## Whether the player has noticed a place: it is `focus` (aimed at or locked onto), within NEAR (`metres` away), or
## its marker is within the look cone of the middle of the view (`look_degrees` off it; the wider cone if it `was`
## noticed already).
static func is_noticed(metres: float, look_degrees: float, focus: bool, was: bool) -> bool:
	return focus or metres < NEAR or look_degrees < (LOOK_CONE_OUT if was else LOOK_CONE)


## Whether a diamond or name set to `mode` shows for a place the player has `noticed` or not.
static func shows(mode: Show, noticed: bool) -> bool:
	return mode == Show.ALWAYS or (mode == Show.NEARBY and noticed)


## `alpha` faded `delta` seconds further toward shown (1) or hidden (0).
static func fade(alpha: float, shown: bool, delta: float) -> float:
	return move_toward(alpha, 1.0 if shown else 0.0, delta / FADE_TIME)


func _process(delta: float) -> void:
	if ship == null or cameras == null:
		return
	var view := cameras.current().global_transform
	var forward := -view.basis.z
	var aimed := ship.cruise.aimed
	var locked := FlightHud.target_of(ship)
	for i in _places.size():
		var metres := _places[i].marker_distance(ship.global_position)
		var to_marker := _places[i].marker_position() - view.origin
		var look := rad_to_deg(forward.angle_to(to_marker)) if to_marker.length_squared() > 1.0 else 0.0
		var noticed := LandmarkMarkers.is_noticed(metres, look, _places[i] == aimed or _places[i] == locked,
				_noticed[i] != 0)
		_noticed[i] = 1 if noticed else 0
		_icon_alpha[i] = LandmarkMarkers.fade(_icon_alpha[i], LandmarkMarkers.shows(icons, noticed), delta)
		_name_alpha[i] = LandmarkMarkers.fade(_name_alpha[i], LandmarkMarkers.shows(names, noticed), delta)
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
	var covered := _covered(view, camera.fov, screen)
	for i in _places.size():
		var framed := _places[i] == locked or _places[i] == aimed
		var hidden := _icon_alpha[i] <= 0.0 and _name_alpha[i] <= 0.0 and not framed
		if _places[i] == here or _places[i] == under or hidden:
			continue
		var at := ScreenMarker.project(view, camera.fov, screen, _places[i].marker_position() - view.origin)
		var point := Vector2(at.x, at.y)
		if at.z <= 0.0:
			# Behind the camera: out at the edge on the side the place is, so turning that way finds it.
			var off := centre - point
			point = centre + (off.normalized() if off.length_squared() > 1.0 else Vector2.DOWN) * screen.length()
		var clamped := ScreenMarker.clamp_to_screen(point, screen, EDGE)
		if covered.has_area() and _covers(covered, clamped, _label_sizes[i]):
			continue
		var colour := FlightHud.CRUISE_COLOUR if _places[i] == locked else COLOUR
		_draw_marker(clamped, clamped == point, i, screen, colour, framed)


## Where on the screen the nav computer's dashboard screen is, while it is lit (an empty rect otherwise).
func _covered(view: Transform3D, fov: float, screen: Vector2) -> Rect2:
	if cover == null or not cover.is_visible_in_tree():
		return Rect2()
	var out := Rect2()
	var first := true
	for corner: Vector3 in cover.corners():
		var at := ScreenMarker.project(view, fov, screen, corner - view.origin)
		if at.z <= 0.0:
			return Rect2()
		var point := Vector2(at.x, at.y)
		out = Rect2(point, Vector2.ZERO) if first else out.expand(point)
		first = false
	return out


## Whether a marker at `p`, or the label under it, would fall on `covered`.
func _covers(covered: Rect2, p: Vector2, label_size: Vector2) -> bool:
	var side := label_size.x * 0.5 + PAD.x
	return covered.grow_individual(side, DIAMOND + LABEL_GAP + label_size.y + PAD.y * 2.0, side, DIAMOND).has_point(p)


## The marker for place `i` at `p`: its diamond (filled when `ahead` on the screen, hollow at the edge) and its name
## below, each as far faded in as it is. Framed when aimed at or locked onto, even with the diamonds turned off: the
## brackets say what F locks onto, and the cruise colour what the drive is locked onto.
func _draw_marker(p: Vector2, ahead: bool, i: int, screen: Vector2, colour: Color, framed: bool) -> void:
	var d := DIAMOND
	if _icon_alpha[i] > 0.0:
		var icon_colour := Color(colour, colour.a * _icon_alpha[i])
		_diamond[0] = p + Vector2(0, -d)
		_diamond[1] = p + Vector2(d, 0)
		_diamond[2] = p + Vector2(0, d)
		_diamond[3] = p + Vector2(-d, 0)
		if ahead:
			draw_colored_polygon(_diamond, icon_colour)
		else:
			for k in 4:
				_outline[k] = _diamond[k]
			_outline[4] = _diamond[0]
			draw_polyline(_outline, icon_colour, LINE_WIDTH, true)
	if framed:
		_draw_brackets(p, colour)
	if _name_alpha[i] <= 0.0:
		return
	var label_size := _label_sizes[i]
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
	draw_rect(plate, Color(PLATE_COLOUR, PLATE_COLOUR.a * _name_alpha[i]))
	draw_string(_font, plate.position + PAD + Vector2(0, _font.get_ascent(FONT_SIZE)), _labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(colour, colour.a * _name_alpha[i]))


## Four corner brackets round the marker at `p`, like a sight's frame.
func _draw_brackets(p: Vector2, colour: Color) -> void:
	for c: Vector2 in CORNERS:
		var corner := p + c * BRACKET
		draw_line(corner, corner - Vector2(c.x * BRACKET_ARM, 0.0), colour, LINE_WIDTH, true)
		draw_line(corner, corner - Vector2(0.0, c.y * BRACKET_ARM), colour, LINE_WIDTH, true)
