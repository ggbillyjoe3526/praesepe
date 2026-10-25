class_name OrbitMarker
extends Control
## The orbit's insertion point on the HUD (design doc, "Orbit"): where the ship would join its orbit line (OrbitLine)
## ahead, as a small ring in the orbit's colour with ticks pointing in, labelled with how far to climb or descend to
## the line ("Orbit  ·  climb 1.2 km"), what to do first when on it ("Orbit  ·  slow down", "Orbit  ·  level out"),
## or just "Orbit" once O enters it (the prompt then says O). Flying at it is a gentle climb (or
## descent) into orbit. Off the screen or behind the camera it sits at the screen's edge on the side to turn to,
## without its ticks. Shown whenever Orbit is guiding; drawn through whichever camera is active (ShipCameras).
## The label is rebuilt only when what it says changes. Placeholder look until the art style is chosen.

## Sizes in px at 1080p: the ring, its ticks, and how close to the screen's edge it comes.
const RING := 10.0
const TICK := 5.0
const EDGE := 90.0
const TICKS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
## The label's state key: the refusal, times this, plus the distance's own key (always far under it).
const DISTANCE_KEYS := 1000003

@export var ship: Ship
@export var cameras: ShipCameras

var _label: String = ""
var _label_size: Vector2 = Vector2.ZERO
var _shown: int = -1
var _font: Font
## Whether the marker was drawn last frame, so it is cleared once when it goes.
var _drawn: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


## The marker's label, for an orbit offered or not (`why`) with the line `to_climb` metres above the ship (below when
## negative, Orbit.to_climb).
static func label_text(why: Orbit.Refusal, to_climb: float) -> String:
	match why:
		Orbit.Refusal.TOO_LOW:
			return "Orbit  ·  climb %s" % LandmarkMarkers.distance_text(to_climb)
		Orbit.Refusal.TOO_HIGH:
			return "Orbit  ·  descend %s" % LandmarkMarkers.distance_text(-to_climb)
		Orbit.Refusal.TOO_FAST:
			return "Orbit  ·  slow down"
		Orbit.Refusal.TOO_STEEP:
			return "Orbit  ·  level out"
	return "Orbit"


## A number that changes exactly when label_text() does.
static func label_key(why: Orbit.Refusal, to_climb: float) -> int:
	var far := why == Orbit.Refusal.TOO_LOW or why == Orbit.Refusal.TOO_HIGH
	return why * DISTANCE_KEYS + (LandmarkMarkers.distance_key(absf(to_climb)) if far else 0)


func _process(_delta: float) -> void:
	if ship == null or cameras == null:
		return
	var o := ship.orbit
	var showing := o.offered != null and o.guiding
	if showing:
		var key := OrbitMarker.label_key(o.refusal, o.to_climb)
		if key != _shown:
			_shown = key
			_label = OrbitMarker.label_text(o.refusal, o.to_climb)
			_label_size = _font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LandmarkMarkers.FONT_SIZE)
	if showing or _drawn:
		queue_redraw()
	_drawn = showing


func _draw() -> void:
	if ship == null or cameras == null or ship.orbit.offered == null or not ship.orbit.guiding:
		return
	var camera := cameras.current()
	var view := camera.global_transform
	var screen := size
	var centre := screen * 0.5
	var point_at := ship.orbit.offered.global_position + ship.orbit.insertion
	var at := ScreenMarker.project(view, camera.fov, screen, point_at - view.origin)
	var point := Vector2(at.x, at.y)
	if at.z <= 0.0:
		# Behind the camera: out at the edge on the side it is, so turning that way finds it.
		var off := centre - point
		point = centre + (off.normalized() if off.length_squared() > 1.0 else Vector2.DOWN) * screen.length()
	var p := ScreenMarker.clamp_to_screen(point, screen, EDGE)
	var colour := FlightHud.ORBIT_COLOUR
	draw_arc(p, RING, 0.0, TAU, 32, colour, LandmarkMarkers.LINE_WIDTH, true)
	if p == point:
		for t: Vector2 in TICKS:
			draw_line(p + t * (RING + TICK), p + t * RING, colour, LandmarkMarkers.LINE_WIDTH, true)
	# The label under the ring (over it near the bottom), always wholly on the screen.
	var pad := LandmarkMarkers.PAD
	var top_left := p + Vector2(-_label_size.x * 0.5, RING + TICK + LandmarkMarkers.LABEL_GAP * 0.5)
	if top_left.y + _label_size.y + pad.y > screen.y:
		top_left.y = p.y - RING - TICK - LandmarkMarkers.LABEL_GAP * 0.5 - _label_size.y
	top_left.x = clampf(top_left.x, pad.x, maxf(screen.x - _label_size.x - pad.x, pad.x))
	var plate := Rect2(top_left - pad, _label_size + pad * 2.0)
	draw_rect(plate, LandmarkMarkers.PLATE_COLOUR)
	draw_string(_font, plate.position + pad + Vector2(0, _font.get_ascent(LandmarkMarkers.FONT_SIZE)), _label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LandmarkMarkers.FONT_SIZE, colour)
