class_name SmokeRun
extends Node
## The headless smoke test behind `-- --smoke` (tools/smoke_test.sh): an autopilot flies the ship through the same
## ShipInput a player uses and checks the flight model as it goes. It speeds up to the top speed, lets go (assist holds
## the speed), turns and lets go (assist stops the turn and lines the ship's motion up with its nose), turns flight
## assist off (the ship keeps drifting and spinning), brings it to a full stop, pauses and resumes, and flies far
## enough for the floating origin to re-centre the world at least once. Each tick it also checks the ship's true
## position moved exactly as its velocity says, which catches a bad shift. Any failed check is an error, which fails
## the run; otherwise it prints the result line the script looks for, then quits.
##
## It checks the cameras on the way: the dashboard shows the speed, the pilot's head sways back and the engines rumble
## while speeding up, the chase camera lags behind a turn and settles straight behind again, leans toward the drift
## with flight assist off, and pulls in when a wall is put behind the ship (and eases out once it is gone). At top
## speed the ship flies under a bar that crosses the line out to the chase camera, which must never end up inside it.
##
## Then it tours the solar system on the cruise drive: it points the nose at each place in turn (the asteroid belt,
## the station, the moon and the planet's base, an order whose straight lines miss everything), checks the HUD offers
## to cruise there, engages the drive and lets go of the controls: the drive is locked onto the place, turns the nose
## along its course and shows the place on the dashboard, and drops out there by itself, on arrival, at the speed
## flight assist then holds, with no bump on the way. On the way to the station the autopilot moves the stick, which
## releases the lock, and steers there by hand. Last it cruises up into open space and drops out with F, then again with X, which
## also brings the ship to a stop.
##
## Then it parks in orbit, lands, takes off, docks and undocks: it cruises to Calder, presses O and checks the ship
## settles into orbit at the orbit's speed and holds its height and its view of the planet; O leaves orbit and flight
## assist carries on; O again re-enters it, and G lands at Tollgate from orbit: the ship flies itself round the planet
## and down onto the pad with no fade and no bump, is held still there, the HUD says so and the game is autosaved (to
## the smoke test's own file, read back to check). G takes off, the ship climbs clear of the base and cruises to
## Halfway Station, slows down, docks the same way, flying itself into the bay (saved again), and undocks out of it.
## The result line names the belt's fingerprint and when each arrival, the orbit, the landing and the docking came
## (and how long flying in took), so a second run on the same seed must match it exactly.
##
## Ticks are physics ticks at 60 Hz. tools/smoke_test.sh runs with `--fixed-fps 60`, so a run is the same every time
## and finishes as fast as the machine allows.

## tools/smoke_test.sh fails unless this line is printed.
const PASS_LINE := "SMOKE: ok"
## Where the smoke test's autosaves go: never the player's save.
const SAVE_PATH := "user://smoke_savegame.json"
const ACCELERATE := 600
const HOLD := 180
const TURN := 90
const SETTLE := 600
const SPIN := 30
const DRIFT := 120
const STOP_LIMIT := 900
const PAUSED_FRAMES := 30
## When, while speeding up, the head sway and the rumble are checked.
const SWAY_CHECK := 120
## How far (m) behind the ship the test wall goes, and how long the camera gets to react to it and to its going.
const WALL_DISTANCE := 11.0
const WALL_TICKS := 30
const CLEAR_TICKS := 150
## The bar flown under at top speed: how far ahead it goes (m), how high above the ship's centre and how thick.
const BAR_AHEAD := 200.0
const BAR_HEIGHT := 2.8
const BAR_SIZE := Vector3(40.0, 0.4, 0.4)
## How far apart (m) the ship's true movement and its velocity may be in one tick.
const STEP_SLACK := 0.05
## The cruise tour, in order, by name (SolarSystem.landmark).
const TOUR: Array[String] = ["The Shingle", "Halfway Station", "Mote", "Tollgate"]
## How long (ticks) the autopilot may take to point at a place, and to cruise there.
const AIM_LIMIT := 900
const CRUISE_LIMIT := 7200
## Pointed within this (degrees) of a place counts as aimed.
const AIM_TOLERANCE := 1.5
## The place of the tour where the autopilot breaks the lock and steers by hand.
const UNLOCK_AT := "Halfway Station"
## How long (ticks) after engaging the lock is checked, and how far (degrees) the nose may then be off the course.
const LOCK_CHECK := 120
const LOCK_NOSE := 2.0
## The autopilot asks for a turn rate that would close the angle in this long (s).
const STEER_TIME := 0.6
## How long (ticks) to cruise into open space before dropping out by hand.
const OPEN_CRUISE := 480
## How long (ticks) the orbit may take to settle, and how long it is then watched.
const ORBIT_SETTLE_LIMIT := 1800
const ORBIT_WATCH := 900
## How long (ticks) the autopilot flies on after leaving orbit before checking flight assist has it.
const AFTER_ORBIT := 300
## How long (ticks) levelling out to leave orbit may take.
const LEVEL_LIMIT := 300
## How long (ticks) the ship may take to fly itself in, from G to its berth, and to leave.
const APPROACH_LIMIT_IN := 7200
const ARRIVAL_LIMIT := 600
## How long (ticks) the ship is watched sitting at its berth.
const BERTH_WATCH := 60
## How far (m) from the base's middle the ship climbs after taking off, clear of its buildings for the cruise drive.
const CLEAR_OF_BASE := 320.0
## The approach to the station's dock: the speed (m/s) the autopilot slows to, and how long (ticks) it may take.
const APPROACH_SPEED := 80.0
const APPROACH_LIMIT := 2400

var ship: Ship
var origin: FloatingOrigin
var pause: PauseScreen
var cameras: ShipCameras
var system: SolarSystem
var arrivals: Arrivals
var autosave: Autosave
var hud: FlightHud

var _frames: int = 0
var _phase: int = 0
var _phase_ticks: int = 0
var _failures: int = 0
var _top_speed: float = 0.0
var _start_forward: Vector3 = Vector3.ZERO
var _drift_velocity: Vector3 = Vector3.ZERO
var _last_true: PackedFloat64Array = PackedFloat64Array()
var _paused_at: Vector3 = Vector3.ZERO
var _paused_clock: float = 0.0
var _paused_frames: int = 0
var _wall: StaticBody3D
var _check_eye_on_frame: bool = false
var _bar: StaticBody3D
var _bar_reach: float = 1.0
var _stage: int = 0
var _tour: int = 0
var _cruise_top: float = 0.0
var _arrivals: PackedStringArray = PackedStringArray()
var _event: CruiseDrive.Event = CruiseDrive.Event.NONE
var _event_place: Landmark = null
var _event_tick: int = 0
var _orbit_event: Orbit.Event = Orbit.Event.NONE
## Leaving orbit: the height (m) over the planet when O was pressed, and the tick the ship was out of orbit.
var _left_height: float = 0.0
var _left_tick: int = -1
var _orbit_height: float = 0.0
var _orbit_view: float = 0.0
var _orbit_start: Vector3 = Vector3.ZERO
var _arrived_at: Port = null
## Checked the ship at its berth, and now watching it sit there.
var _at_berth: bool = false


func _ready() -> void:
	# Runs during the pause too, to check that nothing moves and to resume.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = FlightOrder.CONTROLS
	ship.cruise_changed.connect(_on_cruise_changed)
	ship.orbit_changed.connect(_on_orbit_changed)
	Events.arrived.connect(_on_arrived)
	SaveFile.remove(SAVE_PATH)


func _exit_tree() -> void:
	if ship.cruise_changed.is_connected(_on_cruise_changed):
		ship.cruise_changed.disconnect(_on_cruise_changed)
	if ship.orbit_changed.is_connected(_on_orbit_changed):
		ship.orbit_changed.disconnect(_on_orbit_changed)
	if Events.arrived.is_connected(_on_arrived):
		Events.arrived.disconnect(_on_arrived)


func _on_orbit_changed(event: Orbit.Event, _body: CelestialBody) -> void:
	_orbit_event = event


## Docking or landing moved the ship to its berth: start the movement check afresh from there.
func _on_arrived(port: Port) -> void:
	_arrived_at = port
	_last_true = PackedFloat64Array()


func _on_cruise_changed(event: CruiseDrive.Event, place: Landmark) -> void:
	_event = event
	_event_place = place
	_event_tick = _frames


func _physics_process(_delta: float) -> void:
	_frames += 1
	if get_tree().paused:
		_while_paused()
		return
	_check_step()
	_phase_ticks += 1
	var input := ship.input
	input.reset()
	match _phase:
		0: # Speed up to the top speed with flight assist on, in the cockpit.
			input.thrust.z = 1.0
			_top_speed = maxf(_top_speed, ship.speed())
			if _phase_ticks == SWAY_CHECK:
				_check_cockpit_under_thrust()
			if _phase_ticks >= ACCELERATE:
				_expect(absf(ship.speed() - ship.tuning.max_speed) < 0.5, "reaches the top speed (%.2f m/s)" % ship.speed())
				_check_dashboard()
				_next()
		1: # Let go: assist holds the speed. Watched from the chase camera, under a bar across the way.
			if _phase_ticks == 1:
				cameras.set_view(ShipCameras.View.CHASE)
				_expect(cameras.current() == cameras.chase and cameras.chase.current, "switches to the chase camera")
				_expect(_chase_lag() < 0.1, "starts the chase camera straight behind (%.2f degrees off)" % _chase_lag())
				_bar = _put_box(BAR_SIZE, ship.global_position - ship.global_basis.z * BAR_AHEAD
						+ ship.global_basis.y * BAR_HEIGHT)
			if _phase_ticks >= HOLD:
				_expect(_bar_reach < 0.9, "pulls the chase camera in under the bar (reach %.2f)" % _bar_reach)
				_bar.queue_free()
				_bar = null
				_expect(absf(ship.speed() - ship.held_speed()) < 0.5, "holds its speed (%.2f, set %.2f)" % [ship.speed(),
						ship.held_speed()])
				_expect(ship.held_speed() > ship.tuning.max_speed - 1.0, "keeps the set speed (%.2f)" % ship.held_speed())
				_start_forward = _forward()
				_next()
		2: # Turn right, watched from the chase camera.
			input.turn.y = 1.0
			if _phase_ticks >= TURN:
				var lag := _chase_lag()
				_expect(lag > 1.0 and lag < 20.0, "chase camera lags a little behind the turn (%.2f degrees)" % lag)
				_expect(cameras.chase.is_position_in_frustum(ship.global_position), "stays in the chase camera's view")
				_next()
		3: # Let go: assist stops the turn and lines the motion up with the nose.
			if _phase_ticks >= SETTLE:
				var spin := ship.angular_velocity.length()
				var slip := rad_to_deg(ship.linear_velocity.angle_to(_forward()))
				_expect(spin < 0.002, "stops turning (%.4f rad/s)" % spin)
				_expect(_forward().angle_to(_start_forward) > deg_to_rad(30.0), "has turned")
				_expect(slip < 1.0, "moves along its nose again (%.2f degrees off)" % slip)
				_expect(_chase_lag() < 0.5, "chase camera settles straight behind (%.2f degrees off)" % _chase_lag())
				_expect(cameras.chase.lean < 0.01, "chase camera doesn't lean with assist on (%.3f)" % cameras.chase.lean)
				input.toggle_assist = true
				_drift_velocity = ship.linear_velocity
				_next()
		4: # Assist off: a short turn left, then let go.
			if _phase_ticks == 1:
				_expect(not ship.assist_on(), "turns flight assist off")
			if _phase_ticks <= SPIN:
				input.turn.y = -1.0
			if _phase_ticks >= SPIN + DRIFT:
				var drift := ship.linear_velocity.distance_to(_drift_velocity)
				_expect(drift < 0.01, "keeps drifting the same way (velocity moved %.4f m/s)" % drift)
				_expect(ship.angular_velocity.length() > 0.1, "keeps spinning (%.3f rad/s)" % ship.angular_velocity.length())
				_expect(cameras.chase.lean > 0.9, "chase camera leans toward the drift (%.3f)" % cameras.chase.lean)
				input.full_stop = true
				_next()
		5: # Full stop: assist comes back on and brings the ship to rest.
			if _phase_ticks == 1:
				_expect(ship.assist_on(), "full stop turns flight assist on")
			if ship.speed() < 0.05 and ship.angular_velocity.length() < 0.001:
				_put_wall()
				_next()
			elif _phase_ticks >= STOP_LIMIT:
				_expect(false, "comes to a full stop (%.2f m/s, %.4f rad/s)" % [ship.speed(),
						ship.angular_velocity.length()])
				_next()
		6: # A wall behind the ship: the chase camera comes in front of it, then eases out once it is gone.
			if _phase_ticks == WALL_TICKS:
				var back := cameras.chase.global_position - ship.global_position
				var behind := back.dot(ship.global_basis.z)
				_expect(cameras.chase.reach < 0.6, "pulls the chase camera in for the wall (reach %.2f)" % cameras.chase.reach)
				_expect(behind < WALL_DISTANCE - 0.5, "keeps the chase camera in front of the wall (%.2f m behind)" % behind)
				_wall.queue_free()
			if _phase_ticks >= WALL_TICKS + CLEAR_TICKS:
				_expect(cameras.chase.reach > 0.95, "eases the chase camera back out (reach %.2f)" % cameras.chase.reach)
				cameras.set_view(ShipCameras.View.COCKPIT)
				_expect(cameras.current() == cameras.cockpit and cameras.cockpit.current, "switches back to the cockpit")
				_next()
		7: # Pause: the ship and the clock stand still until resumed.
			_paused_at = ship.global_position
			_paused_clock = Game.clock
			_paused_frames = 0
			pause.open()
			_next()
		8:
			_tour_step(input)
		9: # Into open space (straight up, out of the ring's plane), then drop out with F.
			_open_cruise(input, false)
		10: # And again, dropping out with X: the ship then comes to a stop.
			_open_cruise(input, true)
		11:
			if ship.speed() < 0.05 or _phase_ticks >= STOP_LIMIT:
				_expect(ship.speed() < 0.05, "stops after X drops it out of cruise (%.2f m/s)" % ship.speed())
				_next()
		12: # Cruise to Calder.
			if _visit(input, system.landmark("Calder")):
				_next()
		13:
			_orbit_step(input)
		14: # Leave orbit with O: the nose levels out, then flight assist flies on at the orbit's speed, never sinking.
			var calder := system.landmark("Calder") as CelestialBody
			if _phase_ticks == 1:
				input.toggle_orbit = true
				_left_height = calder.surface_distance(ship.global_position)
				_left_tick = -1
			elif _phase_ticks == 2:
				_expect(_orbit_event == Orbit.Event.LEAVING and ship.orbit.phase == Orbit.Phase.LEAVING,
						"levels out to leave orbit with O")
			elif _left_tick < 0:
				if not ship.orbit.active():
					_expect(_orbit_event == Orbit.Event.LEFT, "leaves orbit once level")
					_left_tick = _phase_ticks
				elif _phase_ticks > LEVEL_LIMIT:
					_expect(false, "leaves orbit once level (still levelling out after %d ticks)" % _phase_ticks)
					_next()
			elif _phase_ticks - _left_tick >= AFTER_ORBIT:
				var slip := rad_to_deg(ship.linear_velocity.angle_to(_forward()))
				var height := calder.surface_distance(ship.global_position)
				_expect(ship.assist_on() and absf(ship.speed() - ship.held_speed()) < 0.5 and slip < 1.0
						and ship.held_speed() > calder.orbit_speed - 1.0,
						"flies on with flight assist after leaving orbit (%.2f m/s, set %.2f, %.2f degrees off the nose)"
						% [ship.speed(), ship.held_speed(), slip])
				_expect(height > _left_height - 1.0,
						"no lower %.0f s after leaving orbit (%.0f m, from %.0f m)" % [AFTER_ORBIT / 60.0, height, _left_height])
				_next()
		15: # Back into orbit, and land at Tollgate from it.
			_land_from_orbit(input)
		16: # Take off, then climb clear of the base's buildings.
			_take_off(input)
		17: # Cruise to the station.
			if _visit(input, system.landmark("Halfway Station")):
				_next()
		18:
			_dock_at_station(input)
		19:
			_undock(input)


func _while_paused() -> void:
	_paused_frames += 1
	_visit_settings()
	if _paused_frames < PAUSED_FRAMES:
		return
	_expect(ship.global_position == _paused_at, "stands still while paused")
	_expect(Game.clock == _paused_clock, "the clock stops while paused")
	pause.close()
	_expect(not get_tree().paused, "resumes")
	# The ship stood still; start the movement check afresh.
	_last_true = PackedFloat64Array()


## While paused: opens the settings menu, shows each page for a frame, and closes it again (the menu never writes the
## settings in the smoke test).
func _visit_settings() -> void:
	var menu := pause.settings_menu
	var pages := menu.pages.size()
	if _paused_frames == 2:
		pause.open_settings()
		_expect(menu.visible, "opens the settings menu")
	elif _paused_frames > 2 and _paused_frames <= 2 + pages:
		menu.show_page(_paused_frames - 3)
		_expect(menu.pages[menu.current].is_visible_in_tree(), "shows the %s settings" % menu.pages[menu.current].title)
	elif _paused_frames == 3 + pages:
		menu.close()
		_expect(not menu.visible and pause.visible, "goes back from the settings menu to the pause screen")


## The ship's true position should move by its velocity each tick (to within the physics step), whatever the floating
## origin did. A shift that moved the ship differently from the world would show here as a jump. The velocity it moved
## by is the one it has now, at the start of this tick: what the ship set last tick, which the physics step used.
func _check_step() -> void:
	var now := origin.true_position(ship.global_position)
	if not _last_true.is_empty():
		var moved := Vector3(now[0] - _last_true[0], now[1] - _last_true[1], now[2] - _last_true[2])
		var expected := ship.linear_velocity / Engine.physics_ticks_per_second
		if moved.distance_to(expected) > STEP_SLACK + expected.length() * 0.01:
			_expect(false, "moves by its velocity (moved %s, expected %s, tick %d)" % [moved, expected, _frames])
	_expect(ship.global_position.length() <= origin.threshold + ship.tuning.max_speed, "stays near the origin")
	_last_true = now


func _forward() -> Vector3:
	return -ship.global_basis.z


## Speeding up in the cockpit: the camera is at the eye, the head is pushed back a little, and the engines rumble.
func _check_cockpit_under_thrust() -> void:
	var cockpit := cameras.cockpit
	_expect(cameras.current() == cockpit and cockpit.current, "starts in the cockpit")
	_expect(cockpit.sway.z > 0.02 and cockpit.sway.length() <= cockpit.tuning.head_sway_max + 0.001,
			"pushes the pilot's head back a little (%.3f m)" % cockpit.sway.z)
	_expect(cameras.shake.rumble > 0.5, "rumbles under thrust (%.2f)" % cameras.shake.rumble)
	_check_eye_on_frame = true


## The cameras are placed each frame from the ship's drawn position, so where they are is checked in a frame (after
## ShipCameras has placed them), not in a physics tick.
func _process(_delta: float) -> void:
	if _bar != null:
		_check_clear_of(_bar, BAR_SIZE)
	if not _check_eye_on_frame:
		return
	_check_eye_on_frame = false
	var eye := ship.get_global_transform_interpolated() * ship.eye.position
	var off := cameras.cockpit.global_position.distance_to(eye)
	_expect(off < cameras.cockpit.tuning.head_sway_max + 0.001, "keeps the camera at the pilot's eye (%.3f m off)" % off)


func _check_dashboard() -> void:
	var shown := (ship.get_node(^"Cockpit") as CockpitDisplay).shown()
	var speed := FlightHud.speed_text(FlightHud.shown_speed(ship.speed()))
	var assist := FlightHud.assist_text(true, roundi(ship.held_speed()))
	_expect(shown[0] == speed and shown[1] == assist, "shows its speed on the dashboard (%s / %s)" % [shown[0],
			shown[1]])


## How far (degrees) the chase camera's heading is from the ship's nose.
func _chase_lag() -> float:
	return rad_to_deg(cameras.chase.heading_forward().angle_to(_forward()))


## A wall across the way behind the ship, where the chase camera wants to be.
func _put_wall() -> void:
	_wall = _put_box(Vector3(60.0, 60.0, 1.0), ship.global_position + ship.global_basis.z * WALL_DISTANCE)


## A solid box lined up with the ship, centred `at`. It goes in the floating origin's world, like everything solid.
func _put_box(box_size: Vector3, at: Vector3) -> StaticBody3D:
	var box := BoxShape3D.new()
	box.size = box_size
	var shape := CollisionShape3D.new()
	shape.shape = box
	var body := StaticBody3D.new()
	body.add_child(shape)
	origin.world.add_child(body)
	body.global_transform = Transform3D(ship.global_basis, at)
	return body


## Fails if the chase camera, as drawn this frame, is inside the box `body` of size `box_size` (or within its
## clearance of it), and notes how far the camera was pulled in.
func _check_clear_of(body: StaticBody3D, box_size: Vector3) -> void:
	if cameras.view != ShipCameras.View.CHASE:
		return
	_bar_reach = minf(_bar_reach, cameras.chase.reach)
	var local := body.global_transform.affine_inverse() * cameras.chase.global_position
	var gap := (local.abs() - box_size * 0.5).max(Vector3.ZERO).length()
	_expect(gap > cameras.chase.tuning.clip_radius * 0.9,
			"keeps the chase camera out of the bar at speed (%.2f m from it, frame %d)" % [gap, _frames])


## One place of the cruise tour: point at it, engage, cruise there, and check the drive dropped out on arrival.
func _tour_step(input: ShipInput) -> void:
	var place := system.landmark(TOUR[_tour])
	if place == null:
		_expect(false, "finds %s in the solar system" % TOUR[_tour])
		_next_place()
		return
	if _visit(input, place, TOUR[_tour] == UNLOCK_AT):
		_next_place()


## Points at `place`, engages the cruise drive locked onto it, cruises there and checks it dropped out on arrival and
## that flight assist then holds the exit speed. With `unlock`, it moves the stick a while after engaging, which
## releases the lock, and steers there itself. True once done (or given up on).
func _visit(input: ShipInput, place: Landmark, unlock: bool = false) -> bool:
	if place == null:
		_expect(false, "finds a place to cruise to")
		return true
	input.turn = _steer_toward(place.marker_position())
	match _stage:
		0: # Point at it, then press F.
			if _aimed_at(place.marker_position()):
				_expect(ship.cruise.aimed == place and ActionPrompts.cruise_text(ship.cruise.aimed)
						== "F   Cruise to %s" % place.display_name, "is offered to cruise to %s (aimed at %s)"
						% [place.display_name, ship.cruise.aimed.display_name if ship.cruise.aimed != null else "nothing"])
				input.toggle_cruise = true
				_event = CruiseDrive.Event.NONE
				_cruise_top = 0.0
				_stage = 1
				_phase_ticks = 0
			elif _phase_ticks >= AIM_LIMIT:
				_expect(false, "points at %s" % place.display_name)
				_stage = 0
				return true
		1: # Charging, then cruising, until the drive drops out.
			if ship.cruise.target != null:
				# Hands off while it charges too: moving the stick would release the lock.
				input.turn = Vector3.ZERO
			_cruise_top = maxf(_cruise_top, ship.speed())
			var charge_ticks := roundi(ship.cruise_tuning.charge_time * Engine.physics_ticks_per_second)
			if _phase_ticks == charge_ticks + 2:
				_expect(ship.cruise.active(), "engages the cruise drive after charging, for %s" % place.display_name)
				_expect(ship.cruise.locked() and ship.cruise.target == place, "locks onto %s" % place.display_name)
			if ship.cruise.locked():
				# Hands off: the lock flies it.
				input.turn = Vector3.ZERO
				if _phase_ticks == charge_ticks + LOCK_CHECK:
					_check_lock(place)
					if unlock:
						input.turn.y = 0.5
			if unlock and _phase_ticks == charge_ticks + LOCK_CHECK + 1 and ship.cruise.active():
				_expect(_event == CruiseDrive.Event.UNLOCKED and not ship.cruise.locked(),
						"releases the lock when the stick moves (event %s)" % CruiseDrive.Event.keys()[_event])
			if ship.cruise.active():
				_expect(ship.jolt < 0.5, "cruises without a bump (%.2f m/s)" % ship.jolt)
			if _event in [CruiseDrive.Event.ARRIVED, CruiseDrive.Event.DROPPED, CruiseDrive.Event.SAFETY,
					CruiseDrive.Event.BUMPED, CruiseDrive.Event.BLOCKED, CruiseDrive.Event.BLOCKED_INSIDE]:
				_check_arrival(place)
				_stage = 2
				_phase_ticks = 0
			elif _phase_ticks >= CRUISE_LIMIT:
				_expect(false, "arrives at %s in time (%.0f m to go)" % [place.display_name,
						place.surface_distance(ship.global_position)])
				_stage = 0
				return true
		2: # A moment later, assist holds the exit speed.
			if _phase_ticks >= 30:
				_expect(absf(ship.speed() - ship.cruise_tuning.exit_speed) < 1.0, "holds %.0f m/s after arriving (%.2f)"
						% [ship.cruise_tuning.exit_speed, ship.speed()])
				_stage = 0
				return true
	return false


## Locked onto `place`: the nose has turned along the course and the dashboard says where the ship is going.
func _check_lock(place: Landmark) -> void:
	var off := rad_to_deg(_forward().angle_to(ship.linear_velocity))
	_expect(off < LOCK_NOSE, "turns its nose along the course to %s (%.2f degrees off)" % [place.display_name, off])
	var shown := (ship.get_node(^"Cockpit") as CockpitDisplay).shown()
	# The distance is checked by the unit tests; the screen redraws in frames, so here only the name.
	var line := FlightHud.target_text(place.display_name, 0.0).get_slice("  ·  ", 0)
	_expect(shown[1] == FlightHud.mode_text(FlightHud.Mode.CRUISE_LOCKED, 0) and shown[2].begins_with(line),
			"shows the lock on the dashboard (%s / %s)" % [shown[1], shown[2]])


func _check_arrival(place: Landmark) -> void:
	var name_seen := _event_place.display_name if _event_place != null else "nowhere"
	_expect(_event == CruiseDrive.Event.ARRIVED and _event_place == place, "drops out of cruise on arriving at %s (event %s at %s)"
			% [place.display_name, CruiseDrive.Event.keys()[_event], name_seen])
	var left := place.surface_distance(ship.global_position)
	_expect(left < place.drop_distance and left > place.drop_distance - 200.0,
			"drops out at the edge of %s's arrival zone (%.0f m, zone %.0f m)" % [place.display_name, left, place.drop_distance])
	_expect(_cruise_top > ship.cruise_tuning.min_speed, "cruises faster than its slowest (%.0f m/s)" % _cruise_top)
	_arrivals.append("%s@%d" % [place.display_name.replace(" ", ""), _event_tick])


## Into orbit round Calder with O: it settles at the orbit's speed, then holds its height, its speed and its view of
## the planet (the nose keeps the same angle to the ground below) while going round, with no bump.
func _orbit_step(input: ShipInput) -> void:
	var o := ship.orbit
	var calder := system.landmark("Calder") as CelestialBody
	match _stage:
		0:
			_expect(o.offered == calder and o.refusal == Orbit.Refusal.NONE, "is offered an orbit round Calder")
			_expect(ActionPrompts.orbit_text(o.phase, o.offered, o.refusal, o.tuning.max_entry_speed)
					== "O   Enter orbit round Calder", "shows the prompt to enter orbit")
			input.toggle_orbit = true
			_orbit_event = Orbit.Event.NONE
			_stage = 1
			_phase_ticks = 0
		1:
			if _phase_ticks == 1:
				_expect(_orbit_event == Orbit.Event.ENTERING and o.active() and o.body == calder,
						"starts entering orbit round Calder")
			_expect(ship.jolt < 0.5, "enters orbit without a bump (%.2f m/s)" % ship.jolt)
			if o.settled() and not o.turning:
				_expect(absf(ship.speed() - calder.orbit_speed) < 0.05, "goes round at the orbit's speed (%.2f m/s)"
						% ship.speed())
				var h := calder.surface_distance(ship.global_position)
				_expect(h >= calder.orbit_min_altitude - 5.0 and h <= calder.orbit_max_altitude + 5.0,
						"orbits between Calder's orbit heights (%.0f m up)" % h)
				_expect(Orbit.lined_up(ship.global_basis, o.facing(ship.global_position), deg_to_rad(1.0)),
						"turns to face along the orbit with the planet below")
				_orbit_height = h
				_orbit_view = _view_angle(calder)
				_orbit_start = ship.global_position - calder.global_position
				_arrivals.append("orbit@%d" % _frames)
				_stage = 2
				_phase_ticks = 0
			elif _phase_ticks >= ORBIT_SETTLE_LIMIT:
				_expect(false, "settles into orbit in time (phase %d, turning %s)" % [o.phase, o.turning])
				_stage = 0
				_next()
		2:
			_expect(o.settled(), "stays in orbit")
			var h := calder.surface_distance(ship.global_position)
			_expect(absf(h - _orbit_height) < 1.0, "holds its orbit's height (%.2f m off)" % (h - _orbit_height))
			_expect(absf(ship.speed() - calder.orbit_speed) < 0.05, "holds the orbit's speed (%.2f m/s)" % ship.speed())
			var view := _view_angle(calder)
			_expect(absf(view - _orbit_view) < 0.5, "keeps its view of the planet (%.2f degrees moved)"
					% (view - _orbit_view))
			if _phase_ticks >= ORBIT_WATCH:
				var swept := rad_to_deg(_orbit_start.angle_to(ship.global_position - calder.global_position))
				_expect(swept > 5.0, "goes round the planet (%.1f degrees)" % swept)
				_stage = 0
				_next()


## The angle (degrees) between the ship's nose and straight down to `body`: steady while the view turns with the
## orbit.
func _view_angle(body: CelestialBody) -> float:
	return rad_to_deg(_forward().angle_to(body.global_position - ship.global_position))


## O again, then G once landing at Tollgate is offered: the ship flies itself down and ends up held still on the pad,
## the game saved there.
func _land_from_orbit(input: ShipInput) -> void:
	var tollgate := system.port(&"tollgate")
	match _stage:
		0:
			input.toggle_orbit = true
			_stage = 1
			_phase_ticks = 0
		1:
			if _phase_ticks >= 30:
				_expect(ship.orbit.active(), "re-enters orbit")
				_expect(arrivals.nearest == tollgate and arrivals.refusal == Arrivals.Refusal.NONE,
						"is offered landing at Tollgate from orbit (refusal %d)" % arrivals.refusal)
				_expect(ActionPrompts.port_text(arrivals.stage, arrivals.nearest, arrivals.refusal,
						arrivals.nearest_distance) == "G   Land at Tollgate", "shows the prompt to land")
				input.dock = true
				_arrived_at = null
				_stage = 2
				_phase_ticks = 0
		2:
			if _await_berth(tollgate, FlightHud.arrival_message(tollgate, 1), FlightHud.Mode.LANDED, "G   Take off"):
				_stage = 0
				_next()


## Waits for the ship to fly itself in to `port`, then checks it is held still there, the HUD says `words`, the
## dashboard shows `mode`, the prompt offers `leave_prompt`, and the game was saved there. True when done (or given up
## on).
func _await_berth(port: Port, words: String, mode: FlightHud.Mode, leave_prompt: String) -> bool:
	if _at_berth:
		return _berth_watch(port, words)
	if _phase_ticks == 1:
		_expect(arrivals.stage == Arrivals.Stage.APPROACHING and ship.bound_for == port,
				"starts flying itself in to %s (stage %d)" % [port.place_name(), arrivals.stage])
	if arrivals.stage == Arrivals.Stage.APPROACHING:
		_expect(ship.jolt < 0.5, "flies in to %s without a bump (%.2f m/s)" % [port.place_name(), ship.jolt])
	if arrivals.stage != Arrivals.Stage.DOCKED:
		if arrivals.stage == Arrivals.Stage.FLYING:
			_expect(false, "keeps flying in to %s (stopped after %d ticks)" % [port.place_name(), _phase_ticks])
			return true
		if _phase_ticks >= APPROACH_LIMIT_IN:
			_expect(false, "arrives at %s in time (stage %d)" % [port.place_name(), arrivals.stage])
			return true
		return false
	_expect(_arrived_at == port and ship.berth == port, "arrives at %s" % port.place_name())
	var off := ship.global_position.distance_to(port.global_position)
	var turned := rad_to_deg(ship.global_basis.z.angle_to(port.global_basis.z))
	_expect(off < 0.01 and turned < 0.1, "is placed at the berth (%.3f m, %.2f degrees off)" % [off, turned])
	_expect(not ship.orbit.active() and not ship.cruise.active(), "stops the orbit and the cruise drive")
	var shown := (ship.get_node(^"Cockpit") as CockpitDisplay).shown()
	_expect(shown[1] == FlightHud.mode_text(mode, 0), "shows it on the dashboard (%s)" % shown[1])
	_expect(ActionPrompts.port_text(arrivals.stage, arrivals.port, arrivals.refusal, 0.0) == leave_prompt,
			"offers to leave (%s)" % leave_prompt)
	_check_save(port)
	# Where, when, and how many ticks it took to fly in.
	_arrivals.append("%s:%s@%d/%d" % ["dock" if port.kind == Port.Kind.DOCK else "land", String(port.id), _frames,
			_phase_ticks])
	_at_berth = true
	_phase_ticks = 0
	return false


## Watches the ship sit still at its berth for a moment; once the HUD has caught up, it says `words`. True when done.
func _berth_watch(port: Port, words: String) -> bool:
	_expect(ship.speed() == 0.0 and ship.global_position.distance_to(port.global_position) < 0.01,
			"sits still at %s" % port.place_name())
	if _phase_ticks == 2:
		_expect(hud.toast_text() == words, "says where it arrived and that the game saved (%s)" % hud.toast_text())
	if _phase_ticks < BERTH_WATCH:
		return false
	_at_berth = false
	return true


## The autosave wrote the game with the ship at `port`, and it reads back.
func _check_save(port: Port) -> void:
	_expect(autosave.last_ok and autosave.last_berth == port.id, "autosaves at %s" % port.place_name())
	var r := SaveFile.read(SAVE_PATH, SaveGame.KIND)
	_expect(r.ok and r.version == SaveGame.VERSION, "reads the autosave back")
	if r.ok:
		var world: Dictionary = r.data.get("world", {})
		_expect(r.data.get("berth") == String(port.id) and int(world.get("world_seed", -1)) == Game.world_seed,
				"saved the berth and the world (%s, seed %s)" % [r.data.get("berth"), world.get("world_seed")])


## G takes off from the pad: the ship rises along the way out, then flight assist has it; then it climbs clear of
## the base.
func _take_off(input: ShipInput) -> void:
	var tollgate := system.port(&"tollgate")
	match _stage:
		0:
			input.dock = true
			_stage = 1
			_phase_ticks = 0
		1:
			if _phase_ticks == 2:
				_expect(arrivals.stage == Arrivals.Stage.LEAVING and ship.guided, "starts taking off")
			if arrivals.stage == Arrivals.Stage.FLYING:
				var rise := (ship.global_position - tollgate.global_position).dot(tollgate.exit_direction())
				_expect(absf(rise - tollgate.exit_distance) < 1.0, "rises %.0f m off the pad (%.2f)"
						% [tollgate.exit_distance, rise])
				_expect(ship.berth == null and not ship.guided and ship.assist_on(), "hands the ship back")
				_stage = 2
				_phase_ticks = 0
			elif _phase_ticks >= ARRIVAL_LIMIT:
				_expect(false, "takes off in time")
				_stage = 2
		2:
			input.thrust.y = 1.0
			var base := system.landmark("Tollgate")
			if ship.global_position.distance_to(base.global_position) > CLEAR_OF_BASE:
				input.thrust.y = 0.0
				input.full_stop = true
				_stage = 0
				_next()
			elif _phase_ticks >= ARRIVAL_LIMIT:
				_expect(false, "climbs clear of Tollgate")
				_stage = 0
				_next()


## Flies at the station's dock, slowing to APPROACH_SPEED, until docking is offered; then G docks.
func _dock_at_station(input: ShipInput) -> void:
	var dock := system.port(&"halfway_station")
	match _stage:
		0:
			input.turn = _steer_toward(dock.global_position)
			if ship.speed() > APPROACH_SPEED:
				input.thrust.z = -1.0
			if arrivals.nearest == dock and arrivals.refusal == Arrivals.Refusal.NONE:
				input.dock = true
				_arrived_at = null
				_stage = 1
				_phase_ticks = 0
			elif _phase_ticks >= APPROACH_LIMIT:
				_expect(false, "is offered docking at Halfway Station (refusal %d, %.0f m)" % [arrivals.refusal,
						arrivals.nearest_distance])
				_stage = 0
				_next()
		1:
			if _await_berth(dock, FlightHud.arrival_message(dock, 1), FlightHud.Mode.DOCKED, "G   Undock"):
				_stage = 0
				_next()


## G undocks: the ship slides out of the bay along its nose and flight assist holds the speed it left with.
func _undock(input: ShipInput) -> void:
	var dock := system.port(&"halfway_station")
	match _stage:
		0:
			input.dock = true
			_stage = 1
			_phase_ticks = 0
		1:
			if arrivals.stage == Arrivals.Stage.FLYING:
				var out := (ship.global_position - dock.global_position).dot(dock.exit_direction())
				_expect(absf(out - dock.exit_distance) < 1.0, "slides %.0f m out of the bay (%.2f)" % [dock.exit_distance,
						out])
				_stage = 2
				_phase_ticks = 0
			elif _phase_ticks >= ARRIVAL_LIMIT:
				_expect(false, "undocks in time")
				_finish()
		2:
			_expect(ship.jolt < 0.01, "leaves the bay without touching it (%.3f m/s)" % ship.jolt)
			if _phase_ticks >= 60:
				_expect(absf(ship.held_speed() - dock.exit_speed) < 0.5 and absf(ship.speed() - dock.exit_speed) < 0.5,
						"flies on at %.0f m/s (%.2f, set %.2f)" % [dock.exit_speed, ship.speed(), ship.held_speed()])
				_finish()


func _next_place() -> void:
	_tour += 1
	_stage = 0
	_phase_ticks = 0
	if _tour >= TOUR.size():
		_next()


## Cruise straight up for a while, then drop out: with F (`with_stop` false: the ship keeps the exit speed) or with X
## (true: it then stops).
func _open_cruise(input: ShipInput, with_stop: bool) -> void:
	var up := ship.global_position + Vector3.UP * 100000.0
	input.turn = _steer_toward(up)
	match _stage:
		0:
			if _aimed_at(up):
				input.toggle_cruise = true
				_event = CruiseDrive.Event.NONE
				_stage = 1
				_phase_ticks = 0
			elif _phase_ticks >= AIM_LIMIT:
				_expect(false, "points straight up")
				_stage = 1
		1:
			var cruising_for := _phase_ticks - roundi(ship.cruise_tuning.charge_time * Engine.physics_ticks_per_second)
			if cruising_for == OPEN_CRUISE:
				_expect(ship.cruise.active(), "cruises in open space")
				_expect(ship.speed() > ship.cruise_tuning.min_speed + 1.0, "speeds up in open space (%.0f m/s)" % ship.speed())
				if with_stop:
					input.full_stop = true
				else:
					input.toggle_cruise = true
			elif cruising_for == OPEN_CRUISE + 2:
				_expect(_event == CruiseDrive.Event.DROPPED, "drops out of cruise when asked (event %s)"
						% CruiseDrive.Event.keys()[_event])
				_expect(not ship.cruise.active(), "has dropped out")
				var held := 0.0 if with_stop else ship.cruise_tuning.exit_speed
				_expect(absf(ship.held_speed() - held) < 0.5, "then holds %.0f m/s (%.2f)" % [held, ship.held_speed()])
				_stage = 0
				_next()


## The turn that steers the nose toward `point` (world space): a rate that would close the angle in STEER_TIME.
func _steer_toward(point: Vector3) -> Vector3:
	var local := ship.global_basis.inverse() * (point - ship.global_position)
	var yaw := atan2(local.x, -local.z)
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	var rates := ship.tuning.max_rates()
	return Vector3(clampf(pitch / (rates.x * STEER_TIME), -1.0, 1.0), clampf(yaw / (rates.y * STEER_TIME), -1.0, 1.0), 0.0)


func _aimed_at(point: Vector3) -> bool:
	var angle := rad_to_deg(_forward().angle_to(point - ship.global_position))
	return angle < AIM_TOLERANCE and ship.angular_velocity.length() < 0.05


func _next() -> void:
	_phase += 1
	_phase_ticks = 0


func _expect(ok: bool, what: String) -> void:
	if ok:
		return
	_failures += 1
	push_error("SMOKE: the ship %s: failed" % what)


func _finish() -> void:
	set_physics_process(false)
	_expect(origin.shift_count >= 1, "flew far enough to re-centre the world")
	if _failures > 0:
		push_error("SMOKE: %d checks failed" % _failures)
		get_tree().quit(1)
		return
	var t := origin.true_position(ship.global_position)
	var belt := system.landmark("The Shingle") as AsteroidBelt
	print("%s frames=%d seed=%d clock=%.2f top=%.2f shifts=%d belt=%s arrivals=%s at=(%.3f, %.3f, %.3f)" % [PASS_LINE,
			_frames, Game.world_seed, Game.clock, _top_speed, origin.shift_count, belt.layout.checksum(),
			",".join(_arrivals), t[0], t[1], t[2]])
	get_tree().quit(0)
