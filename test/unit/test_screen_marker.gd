extends GutTest
## Where the velocity marker lands on screen (game/hud/screen_marker.gd).

const SCREEN := Vector2(1920, 1080)


func test_straight_ahead_is_the_centre() -> void:
	var at := ScreenMarker.project(Transform3D.IDENTITY, 75.0, SCREEN, Vector3.FORWARD)
	assert_eq(Vector2(at.x, at.y), SCREEN * 0.5)
	assert_eq(at.z, 1.0)


func test_half_the_field_of_view_up_is_the_top_edge() -> void:
	var up := Vector3.FORWARD.rotated(Vector3.RIGHT, deg_to_rad(37.5))
	var at := ScreenMarker.project(Transform3D.IDENTITY, 75.0, SCREEN, up)
	assert_almost_eq(at.y, 0.0, 0.01)
	assert_almost_eq(at.x, 960.0, 0.01)


func test_follows_the_camera_turning() -> void:
	# The camera turned 10 degrees left: something straight down -Z now sits right of centre.
	var view := Transform3D(Basis(Vector3.UP, deg_to_rad(10.0)), Vector3.ZERO)
	var at := ScreenMarker.project(view, 75.0, SCREEN, Vector3.FORWARD)
	assert_gt(at.x, 960.0)


func test_behind_reports_where_the_opposite_way_lands() -> void:
	var back_right := Vector3(1, 0, 1)
	var at := ScreenMarker.project(Transform3D.IDENTITY, 75.0, SCREEN, back_right)
	var opposite := ScreenMarker.project(Transform3D.IDENTITY, 75.0, SCREEN, -back_right)
	assert_eq(at.z, -1.0)
	assert_eq(Vector2(at.x, at.y), Vector2(opposite.x, opposite.y))
	assert_lt(at.x, 960.0)


func test_clamps_inside_the_edge_along_the_same_line() -> void:
	var c := ScreenMarker.clamp_to_screen(Vector2(5000, 540), SCREEN, 64.0)
	assert_eq(c, Vector2(1920 - 64, 540))
	var inside := Vector2(300, 200)
	assert_eq(ScreenMarker.clamp_to_screen(inside, SCREEN, 64.0), inside)
