extends GutTest
## Locking the cruise drive onto a place (design doc, "How the cruise drive works"): which place the nose is aimed at,
## flying there by itself whatever the nose does, only arriving there, going round a planet in the way (and coming
## down on a base from above), and handing the steering back when the pilot moves the mouse. Run directly at the
## game's 60 Hz tick with the ship moved by the drive's velocity, like test_cruise_drive.gd.

const DT := 1.0 / 60.0

var _tuning: CruiseTuning
var _drive: CruiseDrive
var _at: Vector3
var _velocity: Vector3
var _nose: Vector3
var _events: Array[CruiseDrive.Event] = []
## The closest (m) the ship came to each place's surface, by name.
var _closest: Dictionary = {}


func before_each() -> void:
	_tuning = load("res://game/ship/greybox_cruise_tuning.tres")
	_drive = CruiseDrive.new(_tuning)
	_at = Vector3.ZERO
	_velocity = Vector3.ZERO
	_nose = Vector3.FORWARD
	_events.clear()
	_closest.clear()


func _place(display_name: String, at: Vector3, radius: float, drop: float, obstacle: bool = true) -> Landmark:
	var l := Landmark.new()
	l.display_name = display_name
	l.radius = radius
	l.drop_distance = drop
	l.obstacle = obstacle
	add_child_autofree(l)
	l.global_position = at
	_drive.landmarks.append(l)
	return l


func _tick(toggle: bool = false, steering: bool = false) -> void:
	var was := _drive.active()
	_drive.step(_at, _velocity, _nose, toggle, false, 0.0, DT, steering)
	if _drive.event != CruiseDrive.Event.NONE:
		_events.append(_drive.event)
	if _drive.active() or was:
		_velocity = _drive.velocity
	_at += _velocity * DT
	for l: Landmark in _drive.landmarks:
		_closest[l.display_name] = minf(_closest.get(l.display_name, INF), l.surface_distance(_at))


func _ticks(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_tick()


## Presses F and waits out the charge.
func _engage() -> void:
	_tick(true)
	_ticks(_tuning.charge_time + DT)


## Cruises until the drive drops out, or `limit` seconds.
func _until_out(limit: float = 180.0) -> void:
	for i in roundi(limit / DT):
		_tick()
		if not _drive.active():
			return


func test_aims_at_the_place_nearest_the_nose_within_the_cone() -> void:
	var ahead := _place("Ahead", Vector3(0, 0, -50000), 100.0, 1000.0)
	var aside := _place("Aside", Vector3(50000, 0, -50000), 100.0, 1000.0)
	assert_eq(CruiseDrive.aim(_drive.landmarks, _at, Vector3.FORWARD, 4.0), ahead)
	var slightly := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-3.0))
	assert_eq(CruiseDrive.aim(_drive.landmarks, _at, slightly, 4.0), ahead, "3 degrees off is still aimed")
	var off := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-6.0))
	assert_null(CruiseDrive.aim(_drive.landmarks, _at, off, 4.0), "6 degrees off is not")
	var toward_aside := _at.direction_to(aside.global_position)
	assert_eq(CruiseDrive.aim(_drive.landmarks, _at, toward_aside, 4.0), aside)


func test_a_planet_counts_anywhere_on_its_disc_but_a_base_on_it_wins_near_its_marker() -> void:
	var planet := _place("Planet", Vector3(0, 0, -30000), 6000.0, 2000.0)
	var base := _place("Base", Vector3(0, 6000, -30000), 150.0, 4000.0)
	# About 9 degrees off the planet's middle: outside the cone, but on its 11 degree disc.
	var edge := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-9.0))
	assert_eq(CruiseDrive.aim(_drive.landmarks, _at, edge, 4.0), planet)
	assert_eq(CruiseDrive.aim(_drive.landmarks, _at, _at.direction_to(base.global_position), 4.0), base)
	# A base on the near face, nearer the middle: 1.5 degrees off its marker still picks it, not the planet round it.
	base.global_position = Vector3(0, 0, -30000) + Vector3(0, sin(deg_to_rad(20.0)), cos(deg_to_rad(20.0))) * 6000.0
	var near_base := _at.direction_to(base.global_position).rotated(Vector3.RIGHT, deg_to_rad(-1.5))
	assert_eq(CruiseDrive.aim(_drive.landmarks, _at, near_base, 4.0), base)
	assert_eq(CruiseDrive.aim(_drive.landmarks, _at, Vector3.FORWARD, 4.0), planet, "the planet's middle is its own")


func test_never_aims_at_a_place_the_ship_is_already_at_or_without_a_marker() -> void:
	var station := _place("Station", Vector3(0, 0, -2000), 250.0, 2500.0)
	assert_null(CruiseDrive.aim(_drive.landmarks, _at, Vector3.FORWARD, 4.0), "inside its arrival zone")
	station.global_position = Vector3(0, 0, -20000)
	station.marker = false
	assert_null(CruiseDrive.aim(_drive.landmarks, _at, Vector3.FORWARD, 4.0), "no marker")


func test_f_locks_onto_the_aimed_place_and_flies_there_whatever_the_nose_does() -> void:
	var moon := _place("Moon", Vector3(0, 0, -40000), 1500.0, 1500.0)
	_tick()
	assert_eq(_drive.aimed, moon, "aimed while off")
	_engage()
	assert_true(_drive.locked(), "locked on once engaged")
	assert_eq(_drive.target, moon)
	assert_null(_drive.aimed, "nothing aimed at while cruising")
	# The pilot's nose wanders off; the drive keeps its course.
	_nose = Vector3.RIGHT
	_until_out()
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED)
	assert_eq(_drive.place, moon)
	assert_almost_eq(moon.surface_distance(_at), 1500.0, 100.0, "at the edge of its zone")
	assert_null(_drive.target, "the lock ends on arriving")


func test_locked_on_it_flies_on_through_other_places_zones() -> void:
	# Not something to fly into, so the course goes straight through its zone.
	var near := _place("Buoy", Vector3(1500, 0, -20000), 50.0, 2500.0, false)
	var far := _place("Moon", Vector3(0, 0, -60000), 1500.0, 1500.0)
	_engage()
	assert_eq(_drive.target, far)
	_until_out()
	assert_lt(_closest["Buoy"], near.drop_distance, "went through the buoy's zone")
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED)
	assert_eq(_drive.place, far, "and only arrived at the moon")


func test_without_a_lock_it_still_goes_where_the_nose_points() -> void:
	_place("Moon", Vector3(0, 0, 60000), 1500.0, 1500.0)
	_engage()
	assert_true(_drive.active())
	assert_false(_drive.locked(), "nothing was aimed at")
	_nose = Vector3.RIGHT
	_ticks(3.0)
	assert_lt(_drive.direction.angle_to(Vector3.RIGHT), deg_to_rad(0.5))


func test_moving_the_stick_releases_the_lock() -> void:
	var moon := _place("Moon", Vector3(0, 0, -90000), 1500.0, 1500.0)
	_engage()
	_ticks(2.0)
	_tick(false, true)
	assert_eq(_events.back(), CruiseDrive.Event.UNLOCKED)
	assert_eq(_drive.place, moon, "names the place it let go of")
	assert_true(_drive.active(), "still cruising")
	assert_false(_drive.locked())
	_nose = Vector3.UP
	_ticks(3.0)
	assert_lt(_drive.direction.angle_to(Vector3.UP), deg_to_rad(0.5), "then goes where the nose points")


func test_cancelling_or_being_blocked_ends_the_lock() -> void:
	_place("Moon", Vector3(0, 0, -40000), 1500.0, 1500.0)
	_tick(true)
	assert_not_null(_drive.target, "locked on while charging")
	_tick(true)
	assert_eq(_events.back(), CruiseDrive.Event.CANCELLED)
	assert_null(_drive.target)
	var rock := _place("Rock", Vector3(0, 0, -900), 100.0, 300.0)
	_engage()
	assert_eq(_events.back(), CruiseDrive.Event.BLOCKED)
	assert_eq(_drive.place, rock)
	assert_null(_drive.target)


func test_goes_round_a_planet_in_the_way() -> void:
	var planet := _place("Planet", Vector3(0, 0, -30000), 6000.0, 2000.0)
	var station := _place("Station", Vector3(0, 0, -60000), 250.0, 2500.0)
	# Aimed at the station straight through the planet: the planet's disc is bigger, so aim with the lock directly.
	_tick(true)
	_drive.target = station
	_ticks(_tuning.charge_time + DT)
	assert_true(_drive.locked())
	_until_out(240.0)
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED, "no safety drop on the way")
	assert_eq(_drive.place, station)
	assert_gt(_closest["Planet"], planet.radius * _tuning.clearance * 0.9, "kept clear of the planet")


func test_comes_down_on_a_base_from_above_even_from_the_far_side_of_its_planet() -> void:
	var planet := _place("Planet", Vector3(0, 0, -20000), 6000.0, 2000.0)
	# On the far side, a little above the planet's middle as the ship sees it.
	var base := _place("Base", Vector3(0, 0, -20000) + Vector3(0, 0.5, -0.866) * 6000.0, 150.0, 4000.0)
	_nose = _at.direction_to(base.global_position)
	_engage()
	assert_eq(_drive.target, base, "aimed at the base, behind the planet")
	_until_out(240.0)
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED, "no safety drop on the way")
	assert_eq(_drive.place, base)
	assert_gt(_closest["Planet"], 1000.0, "never skimmed the planet")
	var up := (_at - planet.global_position).normalized()
	var seen := rad_to_deg(asin((_at - base.global_position).normalized().dot(up)))
	assert_gt(seen, _tuning.approach_angle - 2.0, "came down at it from above (%.0f degrees)" % seen)


func test_round_sphere_touches_it_from_outside_and_follows_it_from_inside() -> void:
	var centre := Vector3.ZERO
	var at := Vector3(0, 0, 20000)
	var way := CruiseDrive.round_sphere(at, centre, 10000.0, Vector3(0, 1000, -20000))
	# The line just touching the sphere: 30 degrees off the line to its middle, on the side of the aim.
	assert_almost_eq(rad_to_deg(way.angle_to(-at.normalized())), 30.0, 0.01)
	assert_gt(way.y, 0.0, "round the side the aim is on")
	var inside := CruiseDrive.round_sphere(Vector3(0, 0, 8000), centre, 10000.0, Vector3(0, 0, -20000))
	assert_gt(inside.z, 0.0, "climbing back out")
	assert_almost_eq(inside.length(), 1.0, 0.0001)


func test_the_lock_turns_the_nose_along_the_course_and_leaves_roll_alone() -> void:
	_drive.direction = Vector3.RIGHT
	var rates := Vector3(1.0, 1.0, 1.0)
	var turn := _drive.turn_for(Basis.IDENTITY, 0.3, rates)
	assert_eq(turn.y, 1.0, "yaws right, as hard as it can for a big turn")
	assert_almost_eq(turn.x, 0.0, 0.0001)
	assert_almost_eq(turn.z, 0.3, 0.0001, "the pilot's roll")
	_drive.direction = Vector3.FORWARD.rotated(Vector3.RIGHT, deg_to_rad(6.0))
	turn = _drive.turn_for(Basis.IDENTITY, 0.0, rates)
	assert_almost_eq(turn.x, deg_to_rad(6.0) / _tuning.lock_turn_time, 0.0001, "pitches up, gently for a small turn")


func test_the_greybox_lock_tuning_is_the_design_docs() -> void:
	# DESIGN.md, "Cruise drive tuning": change a value there and in greybox_cruise_tuning.tres together.
	var expected := {"lock_cone": 4.0, "lock_turn_time": 0.6, "clearance": 1.0, "approach_angle": 15.0}
	for key: String in expected:
		assert_eq(_tuning.get(key), expected[key], key)
	var design := FileAccess.get_file_as_string("res://DESIGN.md")
	var table := design.substr(design.find("**Cruise drive tuning**"), 2500)
	for row: String in ["| Lock cone | 4° |", "| Lock turning | 0.6 s |", "| Clearance |", "| Approach angle | 15° |"]:
		assert_string_contains(table, row, false)


func test_taking_the_steering_inside_another_place_zone_flies_on() -> void:
	# Off to the side of the nose, so the moon is the one aimed at.
	var buoy := _place("Buoy", Vector3(1500, 0, -20000), 50.0, 2500.0, false)
	var moon := _place("Moon", Vector3(0, 0, -90000), 1500.0, 1500.0)
	_engage()
	assert_eq(_drive.target, moon)
	for i in 60 * 60:
		_tick()
		if buoy.surface_distance(_at) < 2000.0:
			break
	assert_lt(buoy.surface_distance(_at), buoy.drop_distance, "inside the buoy's zone")
	_tick(false, true)
	assert_eq(_events.back(), CruiseDrive.Event.UNLOCKED)
	assert_true(_drive.active(), "still cruising, not arrived at the buoy")
	_ticks(1.0)
	assert_true(_drive.active())


func test_getting_there_while_charging_counts_as_arriving() -> void:
	var moon := _place("Moon", Vector3(0, 0, -5000), 1500.0, 1500.0)
	_tick(true)
	assert_eq(_drive.target, moon)
	_at = Vector3(0, 0, -3000)
	_ticks(_tuning.charge_time + DT)
	assert_false(_drive.active(), "nothing to cruise to")
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED)
	assert_eq(_drive.place, moon)
	assert_null(_drive.target)


func test_turning_away_while_charging_releases_the_lock() -> void:
	var moon := _place("Moon", Vector3(0, 0, -40000), 1500.0, 1500.0)
	_tick(true)
	assert_eq(_drive.target, moon)
	_tick(false, true)
	assert_eq(_events.back(), CruiseDrive.Event.UNLOCKED)
	assert_null(_drive.target)
	assert_eq(_drive.phase, CruiseDrive.Phase.CHARGING, "still charging")
	_nose = Vector3.UP
	_ticks(_tuning.charge_time)
	assert_true(_drive.active() and not _drive.locked(), "cruises where the nose points")
	_ticks(2.0)
	assert_lt(_drive.direction.angle_to(Vector3.UP), deg_to_rad(0.5))


func test_the_nav_computer_can_lock_it_onto_a_place_the_nose_isnt_aimed_at() -> void:
	var ahead := _place("Ahead", Vector3(0, 0, -50000), 100.0, 1000.0)
	var behind := _place("Behind", Vector3(0, 0, 60000), 100.0, 1000.0)
	_tick()
	assert_eq(_drive.aimed, ahead, "the nose is aimed elsewhere")
	assert_eq(_drive.course_to(behind, _at, _nose), Vector3.BACK, "the course to it is straight there")
	_drive.wanted = behind
	_engage()
	assert_true(_drive.locked(), "locked on")
	assert_eq(_drive.target, behind, "onto the wanted place")
	assert_null(_drive.wanted, "used once")
	_until_out()
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED)
	assert_lt(behind.surface_distance(_at), behind.drop_distance, "arrived there")


func test_the_turn_towards_a_way_is_the_one_the_lock_uses() -> void:
	var b := Basis.IDENTITY
	var rates := Vector3(deg_to_rad(50.0), deg_to_rad(35.0), deg_to_rad(100.0))
	var right := CruiseDrive.turn_towards(b, Vector3.RIGHT, 0.3, rates, 0.6)
	assert_eq(right.x, 0.0, "no pitch for a way level with the nose")
	assert_eq(right.y, 1.0, "full yaw for a way well off to the right")
	assert_almost_eq(right.z, 0.3, 1.0e-6, "the roll given")
	_drive.direction = Vector3.RIGHT
	assert_eq(_drive.turn_for(b, 0.3, rates), right)
