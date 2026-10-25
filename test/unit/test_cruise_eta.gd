extends GutTest
## The time to arrival the cruise drive shows while locked on (design doc, "How the cruise drive works"): close to how
## long the trip really takes from every point on the way, straight there or round a planet in the way, counting down
## steadily between fresh estimates, and gone without a lock. Run at the game's 60 Hz tick like test_cruise_lock.gd.

const DT := 1.0 / 60.0

var _tuning: CruiseTuning
var _drive: CruiseDrive
var _at: Vector3
var _velocity: Vector3


func before_each() -> void:
	_tuning = load("res://game/ship/greybox_cruise_tuning.tres")
	_drive = CruiseDrive.new(_tuning)
	_at = Vector3.ZERO
	_velocity = Vector3.ZERO


func _place(display_name: String, at: Vector3, radius: float, drop: float) -> Landmark:
	var l := Landmark.new()
	l.display_name = display_name
	l.radius = radius
	l.drop_distance = drop
	add_child_autofree(l)
	l.global_position = at
	_drive.landmarks.append(l)
	return l


func _tick(toggle: bool = false) -> void:
	var was := _drive.active()
	_drive.step(_at, _velocity, Vector3.FORWARD, toggle, false, 0.0, DT)
	if _drive.active() or was:
		_velocity = _drive.velocity
	_at += _velocity * DT


## Locks on with F and flies until the drive drops out, noting the estimate every half second. Returns the estimates
## and how long after each the drive really arrived: [estimates, actual].
func _fly() -> Array[PackedFloat32Array]:
	var estimates := PackedFloat32Array()
	var stamps := PackedFloat32Array()
	var t := 0.0
	_tick(true)
	t += DT
	assert_not_null(_drive.target, "locked on")
	while _drive.phase != CruiseDrive.Phase.OFF and t < 300.0:
		if fmod(t, 0.5) < DT:
			estimates.append(_drive.eta)
			stamps.append(t)
		_tick()
		t += DT
	assert_eq(_drive.event, CruiseDrive.Event.ARRIVED, "arrived")
	var actual := PackedFloat32Array()
	for s: float in stamps:
		actual.append(t - s)
	return [estimates, actual]


func _check_close(results: Array[PackedFloat32Array], what: String) -> void:
	var estimates := results[0]
	var actual := results[1]
	assert_gt(estimates.size(), 10, "%s: a trip of a few seconds at least" % what)
	var worst := -INF
	var furthest := 0.0
	for i in estimates.size():
		assert_false(is_inf(estimates[i]), "%s: an estimate at %d" % [what, i])
		# Within a second and a half, or a tenth of the trip, whichever is more.
		var off := absf(estimates[i] - actual[i])
		worst = maxf(worst, off - maxf(1.5, actual[i] * 0.1))
		furthest = maxf(furthest, off)
	gut.p("%s: %.1f s trip, estimates at most %.2f s out" % [what, actual[0], furthest])
	assert_lt(worst, 0.0, "%s: every estimate close to the real time left" % what)


func test_straight_there_the_estimate_matches_the_trip() -> void:
	_place("Moon", Vector3(0, 0, -60000), 1500.0, 1500.0)
	_check_close(_fly(), "straight")


func test_round_a_planet_in_the_way_the_estimate_counts_the_way_round() -> void:
	_place("Planet", Vector3(0, 0, -30000), 6000.0, 2000.0)
	_place("Moon", Vector3(0, 0, -70000), 1500.0, 1500.0)
	_drive.landmarks[1].marker = true
	_check_close(_fly(), "round a planet")


func test_it_counts_down_between_estimates_and_goes_without_a_lock() -> void:
	_place("Moon", Vector3(0, 0, -60000), 1500.0, 1500.0)
	assert_true(is_inf(_drive.eta), "no lock, no time")
	_tick(true)
	var first := _drive.eta
	assert_gt(first, _tuning.charge_time, "the charge counts too")
	for i in 30:
		_tick()
	assert_almost_eq(_drive.eta, first - 30 * DT, 0.001, "counted down")
	_tick(true)
	assert_true(is_inf(_drive.eta), "cancelled: no time")


func test_the_time_shows_in_whole_seconds_then_minutes() -> void:
	assert_eq(FlightHud.eta_text(17.2), "18 s", "rounded up, so it never says it is there early")
	assert_eq(FlightHud.eta_text(0.0), "0 s")
	assert_eq(FlightHud.eta_text(80.0), "1 min 20 s")
	assert_eq(FlightHud.eta_text(725.0), "12 min")
	assert_eq(FlightHud.eta_key(17.2), FlightHud.eta_key(17.9), "same text, same key")
	assert_ne(FlightHud.eta_key(17.2), FlightHud.eta_key(16.9))
	assert_eq(FlightHud.eta_key(INF), -1)
	assert_eq(FlightHud.target_text("Mote", 31400.0, 17.2), "TARGET  Mote  ·  31 km  ·  18 s")
	assert_eq(FlightHud.target_text("Mote", 31400.0), "TARGET  Mote  ·  31 km", "no time without an estimate")
