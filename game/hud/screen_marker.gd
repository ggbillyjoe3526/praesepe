class_name ScreenMarker
## Where a direction lands on screen, for HUD markers that point the way the ship is moving. Worked out from the
## camera's drawn (interpolated) transform, so markers sit exactly on the picture rather than a physics tick behind.

## Where `direction` (world space) appears for a perspective camera at `view` with vertical field of view `fov`
## (degrees) on a `screen` of that size. z is 1 when the direction is in front of the camera and -1 when behind it (the
## point is then where the opposite direction lands, mirrored), 0 when it is exactly sideways.
static func project(view: Transform3D, fov: float, screen: Vector2, direction: Vector3) -> Vector3:
	var d := view.basis.transposed() * direction
	var centre := screen * 0.5
	if is_zero_approx(d.z):
		return Vector3(centre.x + d.x * 1.0e6, centre.y - d.y * 1.0e6, 0.0)
	var focal := centre.y / tan(deg_to_rad(fov) * 0.5)
	var ahead := -d.z
	return Vector3(centre.x + d.x / ahead * focal, centre.y - d.y / ahead * focal, signf(ahead))


## `point` pulled in along the line from the screen's centre until it is at least `margin` inside the edge. Returns the
## point unchanged when it already is.
static func clamp_to_screen(point: Vector2, screen: Vector2, margin: float) -> Vector2:
	var centre := screen * 0.5
	var reach := centre - Vector2(margin, margin)
	var off := point - centre
	if reach.x <= 0.0 or reach.y <= 0.0:
		return centre
	var scale := maxf(absf(off.x) / reach.x, absf(off.y) / reach.y)
	if scale <= 1.0:
		return point
	return centre + off / scale
