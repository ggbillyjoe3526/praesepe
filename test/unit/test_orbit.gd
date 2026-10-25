extends GutTest
## Parking in orbit (design doc, "Orbit"), run directly at the game's 60 Hz tick with the ship moved by the orbit's
## velocity: what is offered where (only near the orbit line, up in space), the guide to the line and its insertion
## point, entering the way the ship heads, settling onto the line, holding its height and speed round and round, the
## attitude turning with the orbit, and every way of leaving. The planet is a plain sphere, its orbit line 1.5 km up,
## with the greybox ship's orbit tuning.

const DT := 1.0 / 60.0

var _tuning: OrbitTuning
var _orbit: Orbit
var _planet: CelestialBody
var _at: Vector3
var _velocity: Vector3
var _events: Array[Orbit.Event] = []


func before_each() -> void:
	_tuning = load("res://game/ship/greybox_orbit_tuning.tres")
	_orbit = Orbit.new(_tuning)
	_planet = _body("Test planet", Vector3.ZERO, 6000.0, 1500.0, 600.0, 90.0)
	_at = Vector3(0, 0, 6000.0 + 1500.0)
	_velocity = Vector3.ZERO
	_events.clear()


func _body(display_name: String, at: Vector3, radius: float, altitude: float, window: float,
		speed: float) -> CelestialBody:
	var b := CelestialBody.new()
	b.display_name = display_name
	b.radius = radius
	b.orbit_altitude = altitude
	b.orbit_window = window
	b.orbit_speed = speed
	add_child_autofree(b)
	b.global_position = at
	_orbit.bodies.append(b)
	return b


## One tick: the orbit steps, then the ship moves at the orbit's velocity while in it (or keeps its own). `leave` is a
## thrust key, `drop` X or Z.
func _tick(toggle: bool = false, leave: bool = false, jolt: float = 0.0, can_enter: bool = true,
		drop: bool = false) -> void:
	var was := _orbit.active()
	_orbit.step(_at, _velocity, Vector3.FORWARD, toggle, leave, drop, jolt, can_enter, DT)
	if _orbit.event != Orbit.Event.NONE:
		_events.append(_orbit.event)
	if _orbit.active() or was:
		_velocity = _orbit.velocity
	_at += _velocity * DT


func _ticks(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_tick()


## Enters orbit and waits until it has settled.
func _settle(limit: float = 60.0) -> void:
	_tick(true)
	for i in roundi(limit / DT):
		_tick()
		if _orbit.settled():
			return


func _height() -> float:
	return _planet.surface_distance(_at)


func test_offers_entering_only_near_the_orbit_line() -> void:
	var moon := _body("Test moon", Vector3(30000, 0, 0), 1500.0, 1200.0, 300.0, 20.0)
	_tick()
	assert_eq(_orbit.offered, _planet, "1.5 km up: the planet")
	assert_eq(_orbit.refusal, Orbit.Refusal.NONE, "on its line")
	_at = Vector3(0, 0, 6000.0 + 2050.0)
	_tick()
	assert_eq(_orbit.refusal, Orbit.Refusal.NONE, "550 m above the line: still close enough")
	_at = Vector3(30000, 0, 1500.0 + 2000.0)
	_tick()
	assert_eq(_orbit.offered, moon, "2 km above the moon")
	assert_eq(_orbit.refusal, Orbit.Refusal.TOO_HIGH, "800 m above its line")
	assert_almost_eq(_orbit.to_climb, -800.0, 0.01)
	_at = Vector3(0, 0, 6000.0 + 3100.0)
	_tick()
	assert_null(_orbit.offered, "over twice the line's height above the planet: nothing")
	assert_eq(_orbit.refusal, Orbit.Refusal.FAR)


func test_near_the_surface_it_shows_the_way_up_but_wont_enter() -> void:
	_at = Vector3(0, 0, 6000.0 + 200.0)
	_velocity = Vector3(50, 0, 0)
	_tick(true)
	assert_eq(_orbit.offered, _planet, "the planet's orbit line shows")
	assert_eq(_orbit.refusal, Orbit.Refusal.TOO_LOW)
	assert_almost_eq(_orbit.to_climb, 1300.0, 0.01, "1.3 km below the line")
	assert_false(_orbit.guiding, "no guide this close to the ground")
	_at = Vector3(0, 0, 6000.0 + 400.0)
	_tick()
	assert_true(_orbit.guiding, "a little higher it shows the way")
	assert_false(_orbit.active(), "O doesn't enter it from down here")
	assert_eq(_events, [Orbit.Event.REFUSED] as Array[Orbit.Event])


func test_the_insertion_point_is_on_the_line_ahead_a_gentle_climb_away() -> void:
	_at = Vector3(0, 0, 6000.0 + 200.0)
	_velocity = Vector3(50, 0, 0)
	var at := _at
	_tick()
	var line := _planet.orbit_radius()
	assert_almost_eq(_orbit.insertion.length(), line, 0.01, "on the orbit line")
	assert_almost_eq(_orbit.insertion.dot(_orbit.guide_axis), 0.0, 0.01, "in the orbit's plane")
	assert_almost_eq(_orbit.guide_axis, Vector3(0, 1, 0), Vector3.ONE * 0.001, "round the way the ship is heading")
	assert_gt(_orbit.insertion.x, 0.0, "ahead of the ship")
	# As far round as climbing the 1.3 km at insertion_climb would cover along the ground.
	var ahead := _orbit.insertion.angle_to(at) * line
	assert_almost_eq(ahead, 1300.0 / tan(deg_to_rad(_tuning.insertion_climb)), 1.0)
	var up_there := rad_to_deg((_orbit.insertion - at).angle_to(Vector3(1, 0, 0)))
	assert_between(up_there, 20.0, 45.0, "a gentle climb up from level (%.1f degrees)" % up_there)
	_at = Vector3(0, 0, 6000.0 + 1500.0)
	at = _at
	_tick()
	assert_almost_eq(_orbit.insertion.angle_to(at) * line, _tuning.insertion_lead, 1.0, "on the line: just ahead")


func test_small_turns_leave_the_orbit_line_still_and_real_ones_swing_it_smoothly() -> void:
	_velocity = Vector3(80, 0, 0)
	_tick()
	assert_almost_eq(_orbit.guide_axis, Vector3(0, 1, 0), Vector3.ONE * 0.001)
	# A 2 degree wobble for a tenth of a second hardly moves it.
	_velocity = Vector3(80, 0, 0).rotated(_at.normalized(), deg_to_rad(2.0))
	for i in 6:
		_tick()
	assert_lt(rad_to_deg(_orbit.guide_axis.angle_to(Vector3(0, 1, 0))), 2.0)
	# A 90 degree turn swings it round at guide_swing, all the way in the end.
	_at = Vector3(0, 0, 6000.0 + 1500.0)
	_velocity = Vector3(0, 80, 0)
	var last := _orbit.guide_axis
	for i in roundi(8.0 / DT):
		_orbit.step(_at, _velocity, Vector3.FORWARD, false, false, false, 0.0, true, DT)
		assert_lt(rad_to_deg(last.angle_to(_orbit.guide_axis)), _tuning.guide_swing * DT + 0.001, "tick %d" % i)
		last = _orbit.guide_axis
	assert_almost_eq(_orbit.guide_axis, Vector3(-1, 0, 0), Vector3.ONE * 0.001, "round the new heading")
	# O enters the orbit shown.
	_tick(true)
	assert_almost_eq(_orbit.axis, _orbit.guide_axis, Vector3.ONE * 0.001)


func test_climbing_straight_up_the_orbit_goes_the_way_the_nose_points() -> void:
	_at = Vector3(0, 0, 6000.0 + 200.0)
	_velocity = Vector3(0.5, 0, 60.0)
	_orbit.step(_at, _velocity, Vector3(-1, 0, 0), false, false, false, 0.0, true, DT)
	assert_almost_eq(_orbit.guide_axis, Vector3(0, -1, 0), Vector3.ONE * 0.001, "round the nose's way, not the drift's")


func test_nothing_is_offered_while_cruising() -> void:
	_tick(false, false, 0.0, false)
	assert_null(_orbit.offered)
	_tick(true, false, 0.0, false)
	assert_false(_orbit.active(), "O does nothing while cruising")


func test_refuses_too_fast_or_too_steep() -> void:
	_velocity = Vector3(_tuning.max_entry_speed + 10.0, 0, 0)
	_tick(true)
	assert_false(_orbit.active())
	assert_eq(_events, [Orbit.Event.REFUSED] as Array[Orbit.Event])
	assert_eq(_orbit.refusal, Orbit.Refusal.TOO_FAST)
	# On the line, falling at 200 m/s: stopping takes 800 m, out of the window.
	_velocity = Vector3(0, 0, -200.0)
	_tick(true)
	assert_eq(_orbit.refusal, Orbit.Refusal.TOO_STEEP)
	assert_false(_orbit.active())
	_velocity = Vector3(0, 0, 200.0)
	_tick(true)
	assert_eq(_orbit.refusal, Orbit.Refusal.TOO_STEEP, "climbing too")
	_at = Vector3(0, 0, 6000.0 + 1500.0)
	# Slower, it can.
	_velocity = Vector3(0, 0, -40.0)
	_tick(true)
	assert_true(_orbit.active())


func test_o_far_from_everything_is_refused_with_no_body() -> void:
	_at = Vector3(0, 0, 50000.0)
	_tick(true)
	assert_eq(_events, [Orbit.Event.REFUSED] as Array[Orbit.Event])
	assert_null(_orbit.offered)


func test_goes_round_the_way_the_ship_was_heading() -> void:
	_velocity = Vector3(80, 0, 0)
	_settle()
	assert_true(_orbit.settled(), "settled")
	assert_eq(_events, [Orbit.Event.ENTERING, Orbit.Event.SETTLED] as Array[Orbit.Event])
	assert_gt(_velocity.x, 89.0, "still heading +x")
	assert_almost_eq(_velocity.length(), _planet.orbit_speed, 0.01, "at the orbit's speed")
	assert_almost_eq(_orbit.axis, Vector3(0, 1, 0), Vector3.ONE * 0.001, "round the planet's y axis")


func test_holds_its_height_and_speed_all_the_way_round() -> void:
	_velocity = Vector3(0, 60, 0)
	_settle()
	var h := _height()
	assert_almost_eq(h, 1500.0, _tuning.settle_tolerance + 1.0, "levelled out where it was, moving sideways")
	var start := _at
	var lap := TAU * _at.length() / _planet.orbit_speed
	for i in roundi(lap / DT):
		_tick()
		if i % 60 == 0:
			assert_almost_eq(_height(), h, 1.0, "height after %d s" % (i / 60))
			assert_almost_eq(_velocity.length(), _planet.orbit_speed, 0.01, "speed after %d s" % (i / 60))
	assert_lt(_at.distance_to(start), 60.0, "back where it started after one lap (%.1f m)" % _at.distance_to(start))
	assert_eq(_events, [Orbit.Event.ENTERING, Orbit.Event.SETTLED] as Array[Orbit.Event], "never dropped out")


func test_coming_in_steeply_settles_onto_the_line_without_leaving_the_window() -> void:
	_at = Vector3(0, 0, 6000.0 + 2000.0)
	_velocity = Vector3(0, 0, -100.0)
	_tick(true)
	var lowest := _height()
	for i in roundi(60.0 / DT):
		_tick()
		lowest = minf(lowest, _height())
		if _orbit.settled():
			break
	assert_true(_orbit.settled())
	assert_almost_eq(_height(), _planet.orbit_altitude, _tuning.settle_tolerance, "on the line")
	assert_gt(lowest, _planet.orbit_altitude - _planet.orbit_window, "never dived out of the window (%.0f m)" % lowest)


func test_entering_below_the_line_climbs_onto_it() -> void:
	_at = Vector3(0, 0, 6000.0 + 1000.0)
	_velocity = Vector3(50, 0, 0)
	_settle()
	assert_true(_orbit.settled())
	assert_almost_eq(_height(), _planet.orbit_altitude, _tuning.settle_tolerance)


func test_the_swing_onto_the_orbit_is_never_sharper_than_the_thrusters() -> void:
	_velocity = Vector3(0, 0, 100.0)
	_tick(true)
	var last := _velocity
	for i in 600:
		_tick()
		var change := last.distance_to(_velocity) / DT
		assert_lt(change, _tuning.entry_accel + 0.5, "tick %d: %.2f m/s²" % [i, change])
		last = _velocity


func test_the_frame_turns_once_per_lap() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	assert_almost_eq(_orbit.spin.length(), _planet.orbit_speed / _at.length(), 0.00001)
	assert_almost_eq(_orbit.spin.normalized(), _orbit.axis, Vector3.ONE * 0.0001)


func test_o_again_or_thrust_levels_out_then_leaves_keeping_the_velocity() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	var before := _velocity
	var height := _planet.surface_distance(_at)
	_tick(true)
	assert_eq(_events.back(), Orbit.Event.LEAVING)
	assert_eq(_orbit.phase, Orbit.Phase.LEAVING)
	assert_eq(_orbit.spin, Vector3.ZERO, "no longer turning with the orbit")
	for i in roundi(_tuning.level_time / DT) - 2:
		_tick()
	assert_eq(_orbit.phase, Orbit.Phase.LEAVING, "levelling out for OrbitTuning.level_time")
	_tick()
	_tick()
	assert_false(_orbit.active())
	assert_eq(_events.back(), Orbit.Event.LEFT)
	assert_eq(_velocity, before, "the ship carried straight on at the velocity it had")
	assert_gt(_planet.surface_distance(_at), height, "a little higher, never lower")
	_settle()
	_tick(false, true)
	assert_eq(_events.back(), Orbit.Event.LEAVING, "a thrust key levels out too")


func test_x_or_z_leave_at_once() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	var before := _velocity
	_tick(false, false, 0.0, true, true)
	assert_false(_orbit.active())
	assert_eq(_events.back(), Orbit.Event.LEFT)
	assert_eq(_velocity, before)
	_settle()
	_tick(true)
	_tick(false, false, 0.0, true, true)
	assert_eq(_events.back(), Orbit.Event.LEFT, "also while levelling out")


func test_moving_the_mouse_while_levelling_out_hands_the_ship_back() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	_tick(true)
	_orbit.turn_for(Basis.IDENTITY, _at, Vector3(0.5, 0, 0), Vector3.ONE)
	_tick()
	assert_false(_orbit.active())
	assert_eq(_events.back(), Orbit.Event.LEFT)


func test_levelling_out_turns_the_nose_level_along_the_velocity_in_time() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	var ship := _orbit.facing(_at)
	assert_gt(rad_to_deg((-ship.z).angle_to(_velocity)), 20.0, "the nose starts dipped well below the velocity")
	var below := _at.normalized()
	_tick(true)
	var steps := 0
	while _orbit.phase == Orbit.Phase.LEAVING:
		var w := _orbit.level_spin(ship, Vector3.ONE * 10.0, DT)
		if w.length() > 1.0e-9:
			ship = Basis(w.normalized(), w.length() * DT) * ship
		_tick()
		steps += 1
	assert_almost_eq(steps, roundi(_tuning.level_time / DT), 1, "in OrbitTuning.level_time, with quick turn rates")
	assert_lt(rad_to_deg((-ship.z).angle_to(_velocity)), 0.05, "the nose is along the velocity")
	assert_lt(rad_to_deg(ship.y.angle_to(below)), 0.05, "the planet straight below where it left")


func test_a_big_level_out_takes_longer_rather_than_turning_faster_than_the_ship_can() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	# The pilot has looked round behind, the nose 150 degrees off the velocity.
	var ship := Basis(_at.normalized(), deg_to_rad(150.0)) * _orbit.facing(_at)
	var rates := Vector3(deg_to_rad(50.0), deg_to_rad(40.0), deg_to_rad(90.0))
	_tick(true)
	var fastest := 0.0
	var steps := 0
	while _orbit.phase == Orbit.Phase.LEAVING:
		var w := _orbit.level_spin(ship, rates, DT)
		fastest = maxf(fastest, w.length())
		if w.length() > 1.0e-9:
			ship = Basis(w.normalized(), w.length() * DT) * ship
		_tick()
		steps += 1
	assert_lt(fastest, rates.y * 1.01, "never faster than the slowest turn rate")
	assert_gt(steps * DT, _tuning.level_time * 2.0, "so it takes longer")
	assert_lt(rad_to_deg((-ship.z).angle_to(_velocity)), 0.5, "and still ends level along the velocity")


func test_a_hard_bump_knocks_it_out() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	_tick(false, false, _tuning.bump_limit + 0.5)
	assert_eq(_events.back(), Orbit.Event.BUMPED, "a hard bump knocks it out")
	_settle()
	_tick(false, false, _tuning.bump_limit - 0.5)
	assert_true(_orbit.active(), "a nudge doesn't")


func test_facing_puts_the_horizon_just_above_the_middle_of_the_view() -> void:
	_velocity = Vector3(90, 0, 0)
	_settle()
	var f := _orbit.facing(_at)
	var forward := -f.z
	assert_almost_eq(forward.dot(f.y), 0.0, 0.0001, "an upright attitude")
	assert_gt(forward.dot(_velocity.normalized()), 0.5, "facing along the orbit")
	assert_gt(f.y.dot(_at.normalized()), 0.5, "the planet below")
	# The horizon, seen from here, is this far below level; the view's middle sits horizon_above under it.
	var dip := rad_to_deg(acos(_planet.radius / _at.length()))
	var below_level := rad_to_deg(asin(-forward.dot(_at.normalized())))
	assert_almost_eq(below_level - dip, _tuning.horizon_above, 0.01)


func test_steer_turns_the_right_way_on_each_axis() -> void:
	var rates := Vector3(1, 1, 1)
	assert_almost_eq(Orbit.steer(Basis.IDENTITY, Basis.IDENTITY, rates, 1.0), Vector3.ZERO, Vector3.ONE * 0.0001)
	var yawed_right := Basis(Vector3.UP, -0.2)
	assert_gt(Orbit.steer(Basis.IDENTITY, yawed_right, rates, 1.0).y, 0.0, "yaw right")
	var pitched_up := Basis(Vector3.RIGHT, 0.2)
	assert_gt(Orbit.steer(Basis.IDENTITY, pitched_up, rates, 1.0).x, 0.0, "pitch up")
	var rolled_right := Basis(Vector3.FORWARD, 0.2)
	assert_gt(Orbit.steer(Basis.IDENTITY, rolled_right, rates, 1.0).z, 0.0, "roll right")
	assert_almost_eq(Orbit.steer(Basis.IDENTITY, Basis(Vector3.UP, -3.0), rates, 0.1).y, 1.0, 0.0001, "never past full")
	# Nose straight down to level and rolled a quarter turn: one rotation, every axis toward it.
	var big := Basis(Vector3.FORWARD, 0.6) * Basis(Vector3.RIGHT, 1.2)
	var turn := Orbit.steer(Basis.IDENTITY, big, rates, 10.0)
	assert_gt(turn.x, 0.0, "pitches up")
	assert_gt(turn.z, 0.0, "rolls right")


func test_the_pilots_stick_takes_the_view_back() -> void:
	_velocity = Vector3(90, 0, 0)
	_tick(true)
	assert_true(_orbit.turning)
	var auto := _orbit.turn_for(Basis.IDENTITY, _at, Vector3.ZERO, Vector3.ONE)
	assert_ne(auto, Vector3.ZERO, "the orbit steers while the stick is still")
	var mine := Vector3(0.5, 0, 0)
	assert_eq(_orbit.turn_for(Basis.IDENTITY, _at, mine, Vector3.ONE), mine, "a push hands it back")
	assert_false(_orbit.turning)
	assert_eq(_orbit.turn_for(Basis.IDENTITY, _at, Vector3.ZERO, Vector3.ONE), Vector3.ZERO, "and it stays the pilot's")


func test_small_turns_are_steered_all_the_way() -> void:
	# Under about half a degree Quaternion.get_axis() stops normalising; rotation_of() stays exact.
	for degrees: float in [0.05, 0.2, 0.45, 10.0, 170.0]:
		var turn := Orbit.rotation_of(Quaternion(Vector3(1, 2, 3).normalized(), deg_to_rad(degrees)))
		assert_almost_eq(rad_to_deg(turn.length()), degrees, degrees * 0.001 + 0.0001, "%.2f degrees" % degrees)
		assert_almost_eq(turn.normalized(), Vector3(1, 2, 3).normalized(), Vector3.ONE * 0.001)
	var rates := Vector3.ONE
	var steer := Orbit.steer(Basis.IDENTITY, Basis(Vector3.RIGHT, deg_to_rad(0.2)), rates, 1.0)
	assert_almost_eq(steer.x, deg_to_rad(0.2), 0.00001, "a 0.2 degree pitch asks for its whole rate")
