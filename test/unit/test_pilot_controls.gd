extends GutTest
## The mouse stick (game/flight/pilot_controls.gd): pushed by the mouse, never past a full push, easing back to the
## centre.


func test_push_moves_the_stick() -> void:
	var s := PilotControls.move_stick(Vector2.ZERO, Vector2(0.5, 0), 0.0, 1.0 / 60.0)
	assert_eq(s, Vector2(0.5, 0))


func test_never_past_a_full_push() -> void:
	var s := PilotControls.move_stick(Vector2(0.8, 0), Vector2(3, 3), 0.0, 1.0 / 60.0)
	assert_almost_eq(s.length(), 1.0, 0.0001)


func test_eases_back_to_the_centre() -> void:
	var s := Vector2(1, 0)
	for i in 120:
		s = PilotControls.move_stick(s, Vector2.ZERO, 3.0, 1.0 / 60.0)
	assert_almost_eq(s.x, exp(-6.0), 0.0001)
	assert_eq(PilotControls.move_stick(Vector2(0.4, 0), Vector2.ZERO, 0.0, 1.0), Vector2(0.4, 0), "0 keeps the stick put")
