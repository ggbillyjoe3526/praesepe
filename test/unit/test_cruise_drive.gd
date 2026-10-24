extends GutTest
## The cruise drive (design doc, "Cruise drive"), run directly at the game's 60 Hz tick with the ship moved by the
## drive's velocity: charging, its speed in open space and near things, arriving, refusing to engage, safety drops and
## dropping out by hand. Places are plain spheres (Landmark) far from each other.

const DT := 1.0 / 60.0

var _tuning: CruiseTuning
var _drive: CruiseDrive
var _at: Vector3
var _velocity: Vector3
var _nose: Vector3
var _events: Array[CruiseDrive.Event] = []


func before_each() -> void:
	_tuning = load("res://game/ship/greybox_cruise_tuning.tres")
	_drive = CruiseDrive.new(_tuning)
	_at = Vector3.ZERO
	_velocity = Vector3.ZERO
	_nose = Vector3.FORWARD
	_events.clear()


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


## One tick: the drive steps, then the ship moves at the drive's velocity while it cruises (or keeps its own).
func _tick(toggle: bool = false, stop: bool = false, jolt: float = 0.0) -> void:
	var was := _drive.active()
	_drive.step(_at, _velocity, _nose, toggle, stop, jolt, DT)
	if _drive.event != CruiseDrive.Event.NONE:
		_events.append(_drive.event)
	if _drive.active() or was:
		_velocity = _drive.velocity
	_at += _velocity * DT


func _ticks(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_tick()


## Presses F and waits out the charge.
func _engage() -> void:
	_tick(true)
	_ticks(_tuning.charge_time + DT)


func test_charges_before_it_takes_over() -> void:
	_place("Far rock", Vector3(0, 0, 900000), 100.0, 1000.0)
	_tick(true)
	assert_eq(_drive.phase, CruiseDrive.Phase.CHARGING)
	_ticks(_tuning.charge_time - 0.1)
	assert_eq(_drive.phase, CruiseDrive.Phase.CHARGING, "still charging just before the charge time")
	_ticks(0.2)
	assert_true(_drive.active(), "cruising once charged")
	assert_eq(_events.size(), 2)
	assert_eq(_events.front(), CruiseDrive.Event.CHARGING)
	assert_eq(_events.back(), CruiseDrive.Event.ENGAGED)


func test_f_while_charging_cancels() -> void:
	_tick(true)
	_ticks(0.5)
	_tick(true)
	assert_eq(_drive.phase, CruiseDrive.Phase.OFF)
	assert_eq(_events.back(), CruiseDrive.Event.CANCELLED)


func test_is_fast_in_open_space_and_never_past_its_top_speed() -> void:
	_place("Far rock", Vector3(0, 0, 900000), 100.0, 1000.0)
	_engage()
	_ticks(30.0)
	assert_almost_eq(_drive.speed, _tuning.max_speed, 0.01)
	assert_almost_eq(_velocity, _nose * _tuning.max_speed, Vector3.ONE * 0.01, "goes where the nose points")


func test_slows_down_on_the_way_in_and_arrives() -> void:
	var moon := _place("Moon", Vector3(0, 0, -60000), 1500.0, 1500.0)
	_engage()
	var slowest_near := INF
	for i in 60 * 120:
		_tick()
		var s := moon.surface_distance(_at)
		if _drive.active() and s < 5000.0:
			# Close in, it goes about as fast as the distance over the approach time, and never under its slowest.
			assert_lte(_drive.speed, maxf(s / _tuning.approach_time, _tuning.min_speed) * 1.3, "slow near the moon")
			slowest_near = minf(slowest_near, _drive.speed)
		if not _drive.active():
			break
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED)
	assert_eq(_drive.place, moon)
	assert_almost_eq(moon.surface_distance(_at), 1500.0, 100.0, "at the edge of its zone")
	assert_almost_eq(_drive.exit_speed, _tuning.exit_speed, 0.01, "leaves the ship at the exit speed")
	assert_almost_eq(_velocity.length(), _tuning.exit_speed, 0.01)
	assert_gte(slowest_near, _tuning.min_speed - 0.01)


func test_takes_well_under_a_minute_to_cross_the_system() -> void:
	_place("Moon", Vector3(0, 0, -40000), 1500.0, 1500.0)
	_engage()
	var seconds := 0.0
	while _drive.active() and seconds < 120.0:
		_tick()
		seconds += DT
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED)
	assert_lt(seconds, 40.0, "40 km in %.1f s" % seconds)
	assert_gt(seconds, 15.0, "still a trip, not a jump (%.1f s)" % seconds)


func test_leaving_a_place_never_counts_as_arriving_there() -> void:
	var station := _place("Station", Vector3(0, 0, 1000), 200.0, 2500.0)
	_engage()
	_ticks(10.0)
	assert_true(_drive.active(), "still cruising after leaving the station's zone")
	assert_gt(station.surface_distance(_at), station.drop_distance)
	# Turned round (at about the ship's yaw rate) and steered back, the station counts again.
	for i in 300:
		_nose = Vector3.FORWARD.rotated(Vector3.UP, PI * (i + 1) / 300.0)
		_tick()
	for i in 60 * 120:
		# Steering for it, as a pilot would.
		_nose = _at.direction_to(station.global_position)
		_tick()
		if not _drive.active():
			break
	assert_eq(_events.back(), CruiseDrive.Event.ARRIVED)
	assert_eq(_drive.place, station)


func test_wont_engage_pointing_at_something_close() -> void:
	var rock := _place("Rock", Vector3(0, 0, -900), 100.0, 300.0)
	_engage()
	assert_false(_drive.active())
	assert_eq(_events.back(), CruiseDrive.Event.BLOCKED)
	assert_eq(_drive.place, rock)
	# Pointing away is fine.
	_nose = Vector3.BACK
	_engage()
	assert_true(_drive.active())


func test_wont_engage_inside_something() -> void:
	var cloud := _place("Cloud", Vector3(0, 0, 0), 500.0, 1000.0)
	_engage()
	assert_false(_drive.active())
	assert_eq(_events.back(), CruiseDrive.Event.BLOCKED_INSIDE)
	assert_eq(_drive.place, cloud)


func test_drops_out_before_hitting_something_it_started_next_to() -> void:
	# Inside the moon's zone (so no arrival) and pointing past it, then turned towards it.
	var moon := _place("Moon", Vector3(0, 0, -3000), 1500.0, 2000.0)
	_nose = Vector3.RIGHT
	_engage()
	assert_true(_drive.active())
	_nose = Vector3.FORWARD
	for i in 60 * 30:
		_tick()
		if not _drive.active():
			break
	assert_eq(_events.back(), CruiseDrive.Event.SAFETY)
	assert_eq(_drive.place, moon)
	assert_gt(moon.surface_distance(_at), 0.0, "never reached it")
	assert_almost_eq(_velocity.length(), minf(_tuning.safety_exit_speed, _drive.exit_speed), 0.01)
	assert_lte(_drive.exit_speed, _tuning.safety_exit_speed)


func test_f_or_x_drops_out_at_the_exit_speed() -> void:
	_place("Far rock", Vector3(0, 0, 900000), 100.0, 1000.0)
	for stop: bool in [false, true]:
		_engage()
		_ticks(10.0)
		_tick(not stop, stop)
		assert_eq(_events.back(), CruiseDrive.Event.DROPPED)
		assert_false(_drive.active())
		assert_almost_eq(_velocity.length(), _tuning.exit_speed, 0.01)


func test_a_bump_drops_out_and_leaves_the_ship_coming_to_rest() -> void:
	_place("Far rock", Vector3(0, 0, 900000), 100.0, 1000.0)
	_engage()
	_ticks(5.0)
	_velocity = Vector3(0, 0, 400)
	_tick(false, false, _tuning.bump_limit + 1.0)
	assert_eq(_events.back(), CruiseDrive.Event.BUMPED)
	assert_almost_eq(_drive.velocity, Vector3(0, 0, _tuning.safety_exit_speed), Vector3.ONE * 0.01,
			"keeps the bounce's direction, slowed")
	assert_eq(_drive.exit_speed, 0.0, "flight assist then brings it to rest")


func test_turns_to_follow_the_nose() -> void:
	_place("Far rock", Vector3(0, 0, 900000), 100.0, 1000.0)
	_engage()
	_ticks(5.0)
	_nose = Vector3.RIGHT
	_ticks(0.1)
	assert_gt(_drive.direction.angle_to(Vector3.RIGHT), deg_to_rad(10.0), "not at once")
	_ticks(3.0)
	assert_lt(_drive.direction.angle_to(Vector3.RIGHT), deg_to_rad(0.5), "but soon")


func test_the_greybox_tuning_is_the_design_docs() -> void:
	# DESIGN.md, "Cruise drive tuning": change a value there and in greybox_cruise_tuning.tres together.
	var expected := {
		"charge_time": 2.0, "engage_look_ahead": 5.0, "min_speed": 300.0, "max_speed": 5000.0,
		"approach_time": 6.0, "ramp_time": 1.5, "align_time": 0.4, "exit_speed": 200.0, "safety_time": 2.5,
		"safety_exit_speed": 50.0, "bump_limit": 3.0, "rumble": 0.3,
	}
	for key: String in expected:
		assert_eq(_tuning.get(key), expected[key], key)
	var design := FileAccess.get_file_as_string("res://DESIGN.md")
	var table := design.substr(design.find("**Cruise drive tuning**"), 1500)
	for row: String in ["| Charge time | 2 s |", "| Engage look-ahead | 5 s |", "| 300 m/s to 5 km/s |",
			"| Approach time | 6 s |", "| Ramp time | 1.5 s |", "| Turning | 0.4 s |", "| Exit speed | 200 m/s |",
			"| 2.5 s to a surface, then 50 m/s |", "| Bump limit | 3 m/s |", "| Rumble | 0.3 of full thrust |"]:
		assert_string_contains(table, row, false)
