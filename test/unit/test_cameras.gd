extends GutTest
## The ship cameras' maths (game/camera/): easing that is the same at any frame rate, camera shake that stays still
## when it should and dies away, the pilot's head swaying against the push, and the chase camera's lean toward the
## drift.

const TICK := 1.0 / 60.0

var tuning: CameraTuning = preload("res://game/camera/camera_tuning.tres")


func test_easing_is_the_same_at_any_frame_rate() -> void:
	var at_30 := 0.0
	for i in 30:
		at_30 = lerpf(at_30, 1.0, Smoothing.factor(1.0 / 30.0, 0.2))
	var at_144 := 0.0
	for i in 144:
		at_144 = lerpf(at_144, 1.0, Smoothing.factor(1.0 / 144.0, 0.2))
	assert_almost_eq(at_30, at_144, 0.0001)
	assert_eq(Smoothing.factor(TICK, 0.0), 1.0, "no easing time jumps straight there")


func test_no_shake_in_open_space_at_rest() -> void:
	var shake := CameraShake.new(7)
	shake.feel(0.0, 0.0, tuning)
	shake.advance(TICK, tuning)
	assert_eq(shake.angles(tuning, 1.0), Vector3.ZERO)


func test_a_small_knock_is_ignored() -> void:
	var shake := CameraShake.new(7)
	shake.feel(tuning.bump_floor * 0.5, 0.0, tuning)
	assert_eq(shake.trauma, 0.0)


func test_a_bump_shakes_then_dies_away() -> void:
	var shake := CameraShake.new(7)
	shake.feel(tuning.bump_full * 2.0, 0.0, tuning)
	assert_eq(shake.trauma, 1.0, "never past a full bump")
	shake.advance(TICK * 3.0, tuning)
	var turn := shake.angles(tuning, 1.0)
	assert_gt(turn.length(), 0.0)
	assert_lt(turn.length(), deg_to_rad(tuning.bump_angle) * 2.0, "a fraction of a few degrees")
	for i in ceili(60.0 / tuning.bump_decay) + 1:
		shake.feel(0.0, 0.0, tuning)
		shake.advance(TICK, tuning)
	assert_eq(shake.trauma, 0.0)
	assert_eq(shake.angles(tuning, 1.0), Vector3.ZERO)


func test_the_shake_setting_scales_it() -> void:
	var shake := CameraShake.new(7)
	shake.feel(tuning.bump_full, 1.0, tuning)
	shake.advance(TICK * 5.0, tuning)
	var full := shake.angles(tuning, 1.0)
	assert_almost_eq(shake.angles(tuning, 0.5).length(), full.length() * 0.5, 0.000001)
	assert_eq(shake.angles(tuning, 0.0), Vector3.ZERO, "0 is no shake at all")


func test_the_same_seed_shakes_the_same() -> void:
	var a := CameraShake.new(42)
	var b := CameraShake.new(42)
	for s: CameraShake in [a, b]:
		s.feel(tuning.bump_full, 0.5, tuning)
		s.advance(0.25, tuning)
	assert_eq(a.angles(tuning, 1.0), b.angles(tuning, 1.0))


func test_the_rumble_eases_in() -> void:
	var shake := CameraShake.new(7)
	shake.feel(0.0, 1.0, tuning)
	shake.advance(TICK, tuning)
	assert_between(shake.rumble, 0.01, 0.2, "no jolt when the engines start")
	for i in 120:
		shake.advance(TICK, tuning)
	assert_almost_eq(shake.rumble, 1.0, 0.01)


func test_the_head_sways_against_the_push() -> void:
	var forward := CockpitCamera.sway_target(Vector3(0, 0, 40), 0.001, 1.0)
	assert_almost_eq(forward, Vector3(0, 0, 0.04), Vector3.ONE * 0.0001, "speeding up pushes the head back")
	var right := CockpitCamera.sway_target(Vector3(30, 0, 0), 0.001, 1.0)
	assert_almost_eq(right, Vector3(-0.03, 0, 0), Vector3.ONE * 0.0001, "sliding right pushes it left")
	var hard := CockpitCamera.sway_target(Vector3(100, 100, 100), 0.01, 0.06)
	assert_almost_eq(hard.length(), 0.06, 0.0001, "never further than the most")


func test_no_lean_without_motion_or_allowance() -> void:
	assert_eq(ChaseCamera.lean_toward(Vector3.FORWARD, Vector3.ZERO, 0.5, 1.0), Quaternion.IDENTITY)
	assert_eq(ChaseCamera.lean_toward(Vector3.FORWARD, Vector3.RIGHT, 0.5, 0.0), Quaternion.IDENTITY)
	assert_eq(ChaseCamera.lean_toward(Vector3.FORWARD, Vector3.FORWARD * 9.0, 0.5, 1.0), Quaternion.IDENTITY)
	assert_eq(ChaseCamera.lean_toward(Vector3.FORWARD, Vector3.BACK, 0.5, 1.0), Quaternion.IDENTITY)


func test_leans_toward_the_drift() -> void:
	# Nose forward, drifting 40 degrees to the right: half of that is 20 degrees, under the 25 degree cap.
	var drift := Vector3.FORWARD.rotated(Vector3.DOWN, deg_to_rad(40.0))
	var lean := ChaseCamera.lean_toward(Vector3.FORWARD, drift * 50.0, 0.5, deg_to_rad(25.0))
	var leaned := lean * Vector3.FORWARD
	assert_almost_eq(rad_to_deg(leaned.angle_to(Vector3.FORWARD)), 20.0, 0.01)
	assert_almost_eq(rad_to_deg(leaned.angle_to(drift)), 20.0, 0.01, "toward the drift, not away")
	var sideways := ChaseCamera.lean_toward(Vector3.FORWARD, Vector3.RIGHT, 0.5, deg_to_rad(25.0))
	assert_almost_eq(rad_to_deg((sideways * Vector3.FORWARD).angle_to(Vector3.FORWARD)), 25.0, 0.01, "capped")


func test_the_lean_never_jumps_as_the_nose_swings_past_backwards() -> void:
	# Spinning with assist off: the nose sweeps all the way round while the ship keeps moving forward. One degree of
	# nose movement may move the lean target only a few degrees, including across exactly backwards.
	var velocity := Vector3.FORWARD * 60.0
	var cap := deg_to_rad(25.0)
	var last := Vector3.ZERO
	var worst := 0.0
	for step in 721:
		var nose := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(step * 0.5))
		var target := ChaseCamera.lean_toward(nose, velocity, 0.5, cap) * nose
		if step > 0:
			worst = maxf(worst, rad_to_deg(target.angle_to(last)))
		last = target
	assert_lt(worst, 2.0, "biggest jump per half degree of nose: %.2f degrees" % worst)
	var backwards := ChaseCamera.lean_toward(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(179.0)), velocity, 0.5, cap)
	assert_lt(rad_to_deg(backwards.get_angle()), 1.0, "almost no lean when moving almost straight backwards")
