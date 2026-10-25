class_name FlightHud
extends Control
## The flight HUD (design doc, "Flight and camera"): the nose's aim point, the velocity marker showing where the ship
## is really going and the mouse stick, drawn through whichever camera is active (ShipCameras), plus short messages,
## such as the cruise drive's (CruiseDrive), the orbit's (Orbit) and where the ship docked or landed and whether the
## game saved (Events). The keys are in Settings › Controls; a message at the start says so. In the chase view a
## plate at the bottom also shows speed and flight assist, and the place the cruise drive is locked onto with its
## distance and time to arrival; in the cockpit the dashboard screen shows them
## (CockpitDisplay), in the same words. Text is rebuilt only when the whole number shown changes (so while speeding
## up, not in steady flight; in cruise, speeds over 1 km/s show in tenths of a km/s). A placeholder look until the art
## style is chosen.

## Below this speed (m/s) the ship counts as stopped and no velocity marker shows.
const STOPPED := 0.5
## How long (s) a message (flight assist, camera) stays up; the one saying where the ship docked or landed stays longer.
const TOAST_TIME := 2.5
const ARRIVAL_TOAST_TIME := 4.0
## The message at the start saying where the keys are (they live in Settings › Controls, not on the screen).
const START_HINT := "Esc  ·  pause, settings and controls"
const START_HINT_TIME := 8.0
## How close (px at 1080p) markers come to the screen's edge.
const EDGE := 64.0
const NOSE_COLOUR := Color(0.92, 0.95, 1.0, 0.85)
const PROGRADE_COLOUR := Color(0.45, 1.0, 0.7)
const RETROGRADE_COLOUR := Color(1.0, 0.7, 0.3)
const STICK_COLOUR := Color(0.92, 0.95, 1.0, 0.5)
const OFF_COLOUR := Color(1.0, 0.72, 0.3)
const ON_COLOUR := Color(0.55, 0.95, 0.75)
const CRUISE_COLOUR := Color(0.55, 0.8, 1.0)
const ORBIT_COLOUR := Color(0.78, 0.72, 1.0)
const BERTH_COLOUR := Color(0.92, 0.95, 1.0)
const SAVED_COLOUR := Color(0.55, 0.95, 0.75)
## What the second readout line shows: flight assist off or on, the cruise drive charging or cruising, entering or in
## orbit, flying itself in to dock or land, docked or landed, or leaving.
enum Mode {
	ASSIST_OFF, ASSIST_ON, CHARGING, CRUISING, ENTERING_ORBIT, ORBITING, LEAVING_ORBIT, DOCKED, LANDED, UNDOCKING,
	TAKING_OFF, DOCKING, LANDING, CRUISE_LOCKED,
}
## The target line's state key folds the place in like a hash, then the distance's own key (LandmarkMarkers.distance_key,
## always far under DISTANCE_KEYS), then the time to arrival's (eta_key(), always under ETA_KEYS).
const DISTANCE_KEYS := 1000003
const ETA_KEYS := 100003
const NOSE_ARMS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
## Sizes in px at 1080p: the nose mark's arms, the mouse stick's ring (a full push) and dot, and the velocity markers.
const NOSE_GAP := 6.0
const NOSE_ARM := 16.0
const STICK_RING := 90.0
const STICK_DOT := 4.0
const MARKER_RADIUS := 11.0
const MARKER_WING := 11.0
const MARKER_CROSS := 8.0
const LINE_WIDTH := 2.5

@export var ship: Ship
@export var cameras: ShipCameras
@export var controls: PilotControls
@export var arrivals: Arrivals

var _speed_shown: int = -1
var _set_shown: int = -1
var _mode_shown: int = -1
var _toast_left: float = 0.0
## Whether the last autosave worked, once the ship has docked or landed, for the message saying so (-1: none yet).
var _saved: int = -1
var _target_shown: int = -1

@onready var _speed: Label = %Speed
@onready var _assist: Label = %Assist
@onready var _toast: Label = %Toast
@onready var _toast_plate: Control = %ToastPlate
@onready var _readout: Control = %Readout
@onready var _target: Label = %Target


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_plate.visible = false
	_target.visible = false
	if ship != null:
		ship.assist_changed.connect(_on_assist_changed)
		ship.cruise_changed.connect(_on_cruise_changed)
		ship.orbit_changed.connect(_on_orbit_changed)
		ship.upright_changed.connect(_on_upright_changed)
	if arrivals != null:
		arrivals.refused.connect(_on_dock_refused)
		arrivals.stopped.connect(_on_dock_stopped)
	Events.arrived.connect(_on_arrived)
	Events.game_saved.connect(_on_saved)
	if cameras != null:
		cameras.view_changed.connect(_on_view_changed)
		_readout.visible = cameras.view == ShipCameras.View.CHASE
	# A new field of view in the settings menu moves the markers while the game is paused.
	Settings.changed.connect(queue_redraw)
	if ship != null and not Game.launch_args.smoke:
		_show_toast(START_HINT, BERTH_COLOUR, START_HINT_TIME)


func _exit_tree() -> void:
	if ship != null and ship.assist_changed.is_connected(_on_assist_changed):
		ship.assist_changed.disconnect(_on_assist_changed)
	if ship != null and ship.cruise_changed.is_connected(_on_cruise_changed):
		ship.cruise_changed.disconnect(_on_cruise_changed)
	if ship != null and ship.orbit_changed.is_connected(_on_orbit_changed):
		ship.orbit_changed.disconnect(_on_orbit_changed)
	if ship != null and ship.upright_changed.is_connected(_on_upright_changed):
		ship.upright_changed.disconnect(_on_upright_changed)
	if arrivals != null and arrivals.refused.is_connected(_on_dock_refused):
		arrivals.refused.disconnect(_on_dock_refused)
	if arrivals != null and arrivals.stopped.is_connected(_on_dock_stopped):
		arrivals.stopped.disconnect(_on_dock_stopped)
	if Events.arrived.is_connected(_on_arrived):
		Events.arrived.disconnect(_on_arrived)
	if Events.game_saved.is_connected(_on_saved):
		Events.game_saved.disconnect(_on_saved)
	if cameras != null and cameras.view_changed.is_connected(_on_view_changed):
		cameras.view_changed.disconnect(_on_view_changed)
	if Settings.changed.is_connected(queue_redraw):
		Settings.changed.disconnect(queue_redraw)


## A speed (m/s) rounded as it is shown: to the metre per second up to 1 km/s, to 100 m/s beyond.
static func shown_speed(speed: float) -> int:
	return roundi(speed) if speed < 999.5 else roundi(speed / 100.0) * 100


## The speed as the HUD and the dashboard show it, from shown_speed().
static func speed_text(speed: int) -> String:
	return "%d m/s" % speed if speed < 1000 else "%.1f km/s" % (speed / 1000.0)


## Flight assist as the HUD and the dashboard show it, with the speed it is holding.
static func assist_text(on: bool, held: int) -> String:
	return "FLIGHT ASSIST ON  ·  holding %d m/s" % held if on else "FLIGHT ASSIST OFF  ·  drifting"


## What `ship` is flying in, for the second readout line.
static func mode_of(ship: Ship) -> Mode:
	if ship.bound_for != null:
		return Mode.DOCKING if ship.bound_for.kind == Port.Kind.DOCK else Mode.LANDING
	if ship.berth != null:
		var dock := ship.berth.kind == Port.Kind.DOCK
		if ship.guided:
			return Mode.UNDOCKING if dock else Mode.TAKING_OFF
		return Mode.DOCKED if dock else Mode.LANDED
	# The drive can charge while still in orbit (engaging is what leaves it), so it is asked first.
	match ship.cruise.phase:
		CruiseDrive.Phase.CHARGING:
			return Mode.CHARGING
		CruiseDrive.Phase.CRUISING:
			return Mode.CRUISE_LOCKED if ship.cruise.target != null else Mode.CRUISING
	match ship.orbit.phase:
		Orbit.Phase.ENTERING:
			return Mode.ENTERING_ORBIT
		Orbit.Phase.ORBITING:
			return Mode.ORBITING
		Orbit.Phase.LEAVING:
			return Mode.LEAVING_ORBIT
	return Mode.ASSIST_ON if ship.assist_on() else Mode.ASSIST_OFF


## The second readout line, on the HUD and the dashboard.
static func mode_text(mode: Mode, held: int) -> String:
	match mode:
		Mode.CHARGING:
			return "CRUISE CHARGING  ·  F to cancel"
		Mode.CRUISING:
			return "CRUISE  ·  F to drop out"
		Mode.CRUISE_LOCKED:
			return "CRUISE LOCKED  ·  F to drop out"
		Mode.ENTERING_ORBIT:
			return "ENTERING ORBIT  ·  O to cancel"
		Mode.ORBITING:
			return "IN ORBIT  ·  O or thrust to leave"
		Mode.LEAVING_ORBIT:
			return "LEAVING ORBIT  ·  levelling out"
		Mode.DOCKED:
			return "DOCKED  ·  G to undock"
		Mode.LANDED:
			return "LANDED  ·  G to take off"
		Mode.UNDOCKING:
			return "UNDOCKING"
		Mode.TAKING_OFF:
			return "TAKING OFF"
		Mode.DOCKING:
			return "DOCKING  ·  G to cancel"
		Mode.LANDING:
			return "LANDING  ·  G to cancel"
	return FlightHud.assist_text(mode == Mode.ASSIST_ON, held)


static func mode_colour(mode: Mode) -> Color:
	match mode:
		Mode.ASSIST_OFF:
			return OFF_COLOUR
		Mode.ASSIST_ON:
			return ON_COLOUR
		Mode.ENTERING_ORBIT, Mode.ORBITING, Mode.LEAVING_ORBIT:
			return ORBIT_COLOUR
		Mode.DOCKED, Mode.LANDED, Mode.UNDOCKING, Mode.TAKING_OFF, Mode.DOCKING, Mode.LANDING:
			return BERTH_COLOUR
	return CRUISE_COLOUR


## The place the cruise drive is locked onto while it charges or cruises, or null.
static func target_of(ship: Ship) -> Landmark:
	return ship.cruise.target if ship.cruise.phase != CruiseDrive.Phase.OFF else null


## The target line, on the HUD and the dashboard: where the cruise drive is locked onto, how far it is (`metres`,
## Landmark.marker_distance) and about how long until it gets there (`seconds`, CruiseDrive.eta; left off when INF).
static func target_text(place: String, metres: float, seconds: float = INF) -> String:
	var words := "TARGET  %s  ·  %s" % [place, LandmarkMarkers.distance_text(metres)]
	return words if is_inf(seconds) else words + "  ·  " + FlightHud.eta_text(seconds)


## The time to arrival as the target line shows it: whole seconds (rounded up) under a minute, then minutes and
## seconds, then whole minutes from ten minutes (CruiseDrive gives no time for trips that long).
static func eta_text(seconds: float) -> String:
	var s := ceili(maxf(seconds, 0.0))
	if s < 60:
		return "%d s" % s
	if s < 600:
		return "%d min %d s" % [s / 60, s % 60]
	return "%d min" % roundi(s / 60.0)


## A number that changes exactly when eta_text() does, under ETA_KEYS; -1 for INF (no time shown).
static func eta_key(seconds: float) -> int:
	if is_inf(seconds):
		return -1
	var s := mini(ceili(maxf(seconds, 0.0)), ETA_KEYS - 2)
	return s if s < 600 else 600 + roundi(s / 60.0)


## A number that changes exactly when the target line's words do (worked out without allocating, every frame); 0 when
## there is no target.
static func target_key(ship: Ship) -> int:
	var t := FlightHud.target_of(ship)
	if t == null:
		return 0
	var place := posmod(t.get_instance_id(), DISTANCE_KEYS) + 1
	var distance := LandmarkMarkers.distance_key(t.marker_distance(ship.global_position))
	return (place * DISTANCE_KEYS + distance) * ETA_KEYS + FlightHud.eta_key(ship.cruise.eta) + 1


## The message for something the cruise drive did (CruiseDrive.Event) at the place called `place` (where it is
## locked onto, for charging and engaging; empty without a lock).
static func cruise_message(event: CruiseDrive.Event, place: String) -> String:
	match event:
		CruiseDrive.Event.CHARGING:
			if not place.is_empty():
				return "Cruise drive charging  ·  locked onto %s  ·  F to cancel" % place
			return "Cruise drive charging  ·  F to cancel"
		CruiseDrive.Event.CANCELLED:
			return "Cruise cancelled"
		CruiseDrive.Event.ENGAGED:
			if not place.is_empty():
				return "Cruising to %s  ·  move the mouse to steer yourself" % place
			return "Cruising  ·  steer with the mouse, F to drop out"
		CruiseDrive.Event.BLOCKED:
			return "Can't cruise: %s is too close ahead. Turn away first" % place
		CruiseDrive.Event.BLOCKED_INSIDE:
			return "Can't cruise inside %s. Fly clear of it first" % place
		CruiseDrive.Event.ARRIVED:
			return "Arrived at %s" % place
		CruiseDrive.Event.DROPPED:
			return "Dropped out of cruise"
		CruiseDrive.Event.SAFETY:
			return "Dropped out of cruise: %s is close" % place
		CruiseDrive.Event.BUMPED:
			return "Bump! Dropped out of cruise"
		CruiseDrive.Event.UNLOCKED:
			return "Lock released  ·  steering yourself"
	return ""


## The message for something that happened with an orbit (Orbit.Event) round the body called `body`; `why` says why
## entering was refused, and `to_climb` how far (m) the orbit line is above the ship (Orbit.to_climb).
static func orbit_message(event: Orbit.Event, body: String, why: Orbit.Refusal, to_climb: float = 0.0) -> String:
	match event:
		Orbit.Event.ENTERING:
			return "Entering orbit round %s" % body
		Orbit.Event.SETTLED:
			return "In orbit round %s  ·  O or any thrust key to leave" % body
		Orbit.Event.LEAVING:
			return "Levelling out to leave orbit"
		Orbit.Event.LEFT:
			return "Left orbit"
		Orbit.Event.BUMPED:
			return "Bump! Knocked out of orbit"
		Orbit.Event.REFUSED:
			match why:
				Orbit.Refusal.TOO_FAST:
					return "Too fast to enter orbit round %s. Slow down first" % body
				Orbit.Refusal.TOO_STEEP:
					return "Too steep to enter orbit round %s. Level out first" % body
				Orbit.Refusal.TOO_LOW:
					return "Climb %s to %s's orbit line first" % [LandmarkMarkers.distance_text(to_climb), body]
				Orbit.Refusal.TOO_HIGH:
					return "Descend %s to %s's orbit line first" % [LandmarkMarkers.distance_text(-to_climb), body]
			return "Nothing to orbit here. Fly closer to a planet or moon"
	return ""


## The message for rolling upright (Upright.Event) against the planet or moon called `body`.
static func upright_message(event: Upright.Event, body: String) -> String:
	match event:
		Upright.Event.ROLLING:
			return "Rolling level with %s  ·  Q or E to stop" % body
		Upright.Event.LEVEL:
			return "Level with %s" % body
		Upright.Event.STRAIGHT:
			return "Can't roll level: pitch toward %s's horizon first" % body
		Upright.Event.NOTHING:
			return "Nothing to roll level with here"
	return ""


## The message when G is pressed with nothing offered: `port` is the nearest one, or null, and `why` says why not.
static func dock_refused_message(port: Port, why: Arrivals.Refusal) -> String:
	if port == null:
		return "Nothing to dock at or land on here"
	var verb := "dock at" if port.kind == Port.Kind.DOCK else "land at"
	match why:
		Arrivals.Refusal.TOO_FAST:
			return "Too fast to %s %s. Slow below %d m/s" % [verb, port.place_name(), roundi(port.max_speed)]
		Arrivals.Refusal.CRUISING:
			return "Drop out of cruise (F) to %s %s" % [verb, port.place_name()]
	return "Come closer to %s %s" % [verb, port.place_name()]


## The message when the way in to `port` stops short: the pilot took the ship back, or a bump (`blocked`) stopped it.
static func dock_stopped_message(port: Port, blocked: bool) -> String:
	var dock := port != null and port.kind == Port.Kind.DOCK
	if blocked:
		return "Bump! %s stopped. G to try again" % ("Docking" if dock else "Landing")
	return "%s cancelled" % ("Docking" if dock else "Landing")


## The message once the ship has docked or landed at `port`: where, and whether the game saved (`saved`: 1 yes, 0 no,
## -1 not known).
static func arrival_message(port: Port, saved: int) -> String:
	var words := ("Docked at %s" if port.kind == Port.Kind.DOCK else "Landed at %s") % port.place_name()
	match saved:
		1:
			return words + "  ·  Game saved"
		0:
			return words + "  ·  The game couldn't be saved this time. Your last save is safe"
	return words


## The message on continuing a saved game: where the ship is, docked or landed at `berth`, or null out in space.
static func welcome_message(berth: Port) -> String:
	if berth == null:
		return "Welcome back  ·  Game loaded"
	return "Welcome back  ·  " + ("Docked at %s" if berth.kind == Port.Kind.DOCK else "Landed at %s") \
			% berth.place_name()


## Says the saved game was loaded (GameStart), where the ship is: docked or landed at `berth`, or null out in space.
func welcome_back(berth: Port) -> void:
	_show_toast(FlightHud.welcome_message(berth), SAVED_COLOUR, ARRIVAL_TOAST_TIME)


## The message on screen now, or empty when none is up (for the smoke test).
func toast_text() -> String:
	return _toast.text if _toast_plate.visible else ""


func _process(delta: float) -> void:
	if ship == null:
		return
	_update_text()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast_plate.visible = _toast_left > 0.0
	queue_redraw()


func _update_text() -> void:
	var speed := FlightHud.shown_speed(ship.speed())
	if speed != _speed_shown:
		_speed_shown = speed
		_speed.text = FlightHud.speed_text(speed)
	var mode := FlightHud.mode_of(ship)
	var held := roundi(ship.held_speed())
	if mode != _mode_shown:
		_assist.add_theme_color_override("font_color", FlightHud.mode_colour(mode))
	if mode != _mode_shown or (mode == Mode.ASSIST_ON and held != _set_shown):
		_mode_shown = mode
		_set_shown = held
		_assist.text = FlightHud.mode_text(mode, held)
	var key := FlightHud.target_key(ship)
	if key != _target_shown:
		_target_shown = key
		var t := FlightHud.target_of(ship)
		_target.visible = t != null
		if t != null:
			_target.text = FlightHud.target_text(t.display_name, t.marker_distance(ship.global_position), ship.cruise.eta)


func _on_assist_changed(on: bool) -> void:
	_show_toast("Flight assist ON" if on else "Flight assist OFF: the ship keeps drifting and spinning",
			ON_COLOUR if on else OFF_COLOUR)


func _on_cruise_changed(event: CruiseDrive.Event, place: Landmark) -> void:
	var words := FlightHud.cruise_message(event, place.display_name if place != null else "")
	var warn := event in [CruiseDrive.Event.BLOCKED, CruiseDrive.Event.BLOCKED_INSIDE, CruiseDrive.Event.SAFETY,
			CruiseDrive.Event.BUMPED]
	_show_toast(words, OFF_COLOUR if warn else CRUISE_COLOUR)


func _on_orbit_changed(event: Orbit.Event, body: CelestialBody) -> void:
	var words := FlightHud.orbit_message(event, body.display_name if body != null else "", ship.orbit.refusal,
			ship.orbit.to_climb)
	var warn := event == Orbit.Event.BUMPED or event == Orbit.Event.REFUSED
	_show_toast(words, OFF_COLOUR if warn else ORBIT_COLOUR)


func _on_upright_changed(event: Upright.Event, body: CelestialBody) -> void:
	var words := FlightHud.upright_message(event, body.display_name if body != null else "")
	var warn := event == Upright.Event.STRAIGHT or event == Upright.Event.NOTHING
	_show_toast(words, OFF_COLOUR if warn else NOSE_COLOUR)


func _on_dock_refused(port: Port, why: Arrivals.Refusal) -> void:
	_show_toast(FlightHud.dock_refused_message(port, why), OFF_COLOUR)


func _on_dock_stopped(port: Port, blocked: bool) -> void:
	_show_toast(FlightHud.dock_stopped_message(port, blocked), OFF_COLOUR if blocked else BERTH_COLOUR)


## The autosave answers while the ship arrives (Events.game_saved, during Events.arrived), before or after this hears
## of the arrival, so the message goes up at the end of the tick, once both are known.
func _on_arrived(_port: Port) -> void:
	_show_arrival.call_deferred()


func _on_saved(ok: bool) -> void:
	_saved = 1 if ok else 0


func _show_arrival() -> void:
	if ship == null or ship.berth == null:
		_saved = -1
		return
	_show_toast(FlightHud.arrival_message(ship.berth, _saved), OFF_COLOUR if _saved == 0 else SAVED_COLOUR,
			ARRIVAL_TOAST_TIME)
	_saved = -1


func _on_view_changed(view: ShipCameras.View) -> void:
	var chase := view == ShipCameras.View.CHASE
	_readout.visible = chase
	_show_toast("Chase camera  ·  V for the cockpit" if chase else "Cockpit  ·  V for the chase camera", NOSE_COLOUR)


func _show_toast(words: String, colour: Color, time: float = TOAST_TIME) -> void:
	_toast.text = words
	_toast.add_theme_color_override("font_color", colour)
	_toast_left = time
	_toast_plate.visible = true


func _draw() -> void:
	if ship == null or cameras == null:
		return
	var screen := size
	var camera := cameras.current()
	var view := camera.global_transform
	# The nose's aim point: the screen's centre in the cockpit, ahead of the ship in the chase view.
	var nose_at := ScreenMarker.project(view, camera.fov, screen, -ship.get_global_transform_interpolated().basis.z)
	var nose_point := Vector2(nose_at.x, nose_at.y)
	if nose_at.z < 0.0:
		# Looking round, the nose can be behind the view: its mark waits at the edge on the side to turn back to.
		var off := screen * 0.5 - nose_point
		nose_point = screen * 0.5 + (off.normalized() if off.length_squared() > 1.0 else Vector2.DOWN) * screen.length()
	var nose := ScreenMarker.clamp_to_screen(nose_point, screen, EDGE)
	_draw_nose(nose)
	if controls != null:
		_draw_stick(nose, controls.stick)
	if ship.speed() < STOPPED:
		return
	var at := ScreenMarker.project(view, camera.fov, screen, ship.linear_velocity)
	var point := Vector2(at.x, at.y)
	var clamped := ScreenMarker.clamp_to_screen(point, screen, EDGE)
	var faded := clamped != point
	if at.z >= 0.0:
		_draw_prograde(clamped, faded)
	else:
		_draw_retrograde(clamped, faded)


func _draw_nose(c: Vector2) -> void:
	for dir: Vector2 in NOSE_ARMS:
		draw_line(c + dir * NOSE_GAP, c + dir * NOSE_ARM, NOSE_COLOUR, 2.0, true)


## The mouse stick: a faint ring the size of a full deflection, and a dot where the stick is.
func _draw_stick(c: Vector2, stick: Vector2) -> void:
	if stick.length() < 0.02:
		return
	draw_arc(c, STICK_RING, 0.0, TAU, 48, Color(STICK_COLOUR, 0.18), 1.5, true)
	draw_circle(c + stick * STICK_RING, STICK_DOT, STICK_COLOUR)


## Where the ship is going: a ring with three short wings.
func _draw_prograde(p: Vector2, faded: bool) -> void:
	var col := Color(PROGRADE_COLOUR, 0.55 if faded else 1.0)
	var r := MARKER_RADIUS
	draw_arc(p, r, 0.0, TAU, 32, col, LINE_WIDTH, true)
	draw_line(p + Vector2(-r, 0), p + Vector2(-r - MARKER_WING, 0), col, LINE_WIDTH, true)
	draw_line(p + Vector2(r, 0), p + Vector2(r + MARKER_WING, 0), col, LINE_WIDTH, true)
	draw_line(p + Vector2(0, -r), p + Vector2(0, -r - MARKER_WING * 0.8), col, LINE_WIDTH, true)


## Going backwards: a ring with a cross, where the ship is moving away from.
func _draw_retrograde(p: Vector2, faded: bool) -> void:
	var col := Color(RETROGRADE_COLOUR, 0.55 if faded else 1.0)
	var x := MARKER_CROSS
	draw_arc(p, MARKER_RADIUS, 0.0, TAU, 32, col, LINE_WIDTH, true)
	draw_line(p + Vector2(-x, -x), p + Vector2(x, x), col, LINE_WIDTH, true)
	draw_line(p + Vector2(-x, x), p + Vector2(x, -x), col, LINE_WIDTH, true)
