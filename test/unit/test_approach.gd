extends GutTest
## The way in to a port (Approach; design doc, "How docking and landing work"), flown without the physics engine so
## a whole approach takes a moment: the ship goes round the station or planet, never nearer its centre than the gate,
## takes the final leg straight in, lined up before it is inside the bay or near the pad, settles onto the bay's floor,
## and touches its berth softly. It carries on at about the speed the ship was going, never climbing higher than it
## must.
## Run against the real station and base, so their ports' gates are checked to clear everything there.

const DT := 1.0 / 60.0
## Longest any approach here may take (s): from rest at the edge of the landing offer is the longest way in.
const LIMIT := 150.0

var _tuning: ArrivalTuning
var _rates: Vector3
var _accels: Vector3


func before_each() -> void:
	_tuning = load("res://game/arrival/arrival_tuning.tres")
	var ship_tuning: ShipTuning = load("res://game/ship/greybox_ship_tuning.tres")
	_rates = ship_tuning.max_rates()
	_accels = ship_tuning.turn_accels()


## The real station, its centre at the origin.
func _station() -> Port:
	var station: Node3D = load("res://game/system/greybox_station.tscn").instantiate()
	add_child_autofree(station)
	return station.get_node(^"DockPort") as Port


## A planet of Calder's size at the origin with the real base standing on top of it.
func _planet_pad() -> Port:
	var planet := CelestialBody.new()
	planet.display_name = "Test Planet"
	planet.radius = 6000.0
	add_child_autofree(planet)
	var base: Node3D = load("res://game/system/greybox_base.tscn").instantiate()
	base.position = Vector3(0, 6000, 0)
	planet.add_child(base)
	return base.get_node(^"PadPort") as Port


## What a flight in noted: how long it took (s), the nearest it came to the centre before the final leg (m), its top
## speed (m/s) and its speed at the berth, and the ship's attitude and place at each tick of the final leg.
class Flight:
	var time: float = 0.0
	var nearest: float = INF
	var top: float = 0.0
	var touch: float = 0.0
	var done: bool = false
	var final_at: Array[Vector3] = []
	var final_basis: Array[Basis] = []
	## Every place it went until it settled (path), and from then on (settle_path), with the attitude it settled in.
	var path: Array[Vector3] = []
	var settle_path: Array[Vector3] = []
	var settle_basis: Array[Basis] = []
	## The highest it went above the centre it goes round (m).
	var highest: float = 0.0
	var turn_rates: Vector3 = Vector3.ZERO


## Flies the way in to `port` from `at`, moving at `moving`, the ship turning and moving as it is asked each tick.
func _fly(port: Port, at: Vector3, moving: Vector3 = Vector3.ZERO, ship_basis: Basis = Basis.IDENTITY) -> Flight:
	var a := Approach.new(port, _tuning)
	a.start_from(at, moving)
	var structure := port.get_parent().get_node_or_null(^"Structure") as Node3D
	if structure != null:
		a.obstacle = _in_the_way.bind(structure)
	var f := Flight.new()
	var spinning := Vector3.ZERO
	var centre := port.centre()
	while f.time < LIMIT:
		a.step(at, ship_basis, moving, spinning, _rates, _accels, DT)
		if a.done:
			f.done = true
			f.touch = moving.length()
			break
		moving = a.velocity
		spinning = a.spin
		f.top = maxf(f.top, moving.length())
		f.highest = maxf(f.highest, at.distance_to(centre))
		var local := (ship_basis.inverse() * spinning).abs()
		f.turn_rates = f.turn_rates.max(local)
		if a.settling:
			f.settle_path.append(at)
			f.settle_basis.append(ship_basis)
		elif a.final:
			f.path.append(at)
			f.final_at.append(at)
			f.final_basis.append(ship_basis)
		else:
			f.path.append(at)
			f.nearest = minf(f.nearest, at.distance_to(centre))
		at += moving * DT
		if spinning.length() > 0.0:
			ship_basis = (Basis(spinning.normalized(), spinning.length() * DT) * ship_basis).orthonormalized()
		f.time += DT
	return f


## Every corner of the solid parts under `structure` (its collision shapes), in `port`'s parent's space.
func _corners(structure: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in structure.get_children():
		var shape := child as CollisionShape3D
		if shape == null:
			continue
		var box := shape.shape.get_debug_mesh().get_aabb()
		for i in 8:
			out.append(structure.transform * shape.transform * box.get_endpoint(i))
	return out


## How far (m) `point` (world space) is inside `shape` widened by the ship's reach (its wingtips), and the way back out
## through the nearest side (world space); [0.0, Vector3.ZERO] when it is clear of it. Boxes and upright cylinders.
func _inside(shape: CollisionShape3D, point: Vector3) -> Array:
	var local := shape.global_transform.affine_inverse() * point
	var reach := _tuning.reach
	var cylinder := shape.shape as CylinderShape3D
	var depth := 0.0
	var normal := Vector3.ZERO
	if cylinder != null:
		var round := Vector2(local.x, local.z)
		var from_side := cylinder.radius + reach - round.length()
		var from_end := cylinder.height * 0.5 + reach - absf(local.y)
		if from_side <= 0.0 or from_end <= 0.0:
			return [0.0, Vector3.ZERO]
		depth = minf(from_side, from_end)
		normal = Vector3(0.0, signf(local.y), 0.0) if from_end < from_side \
				else Vector3(round.x, 0.0, round.y).normalized()
	else:
		var box := shape.shape.get_debug_mesh().get_aabb().grow(reach)
		if not box.has_point(local):
			return [0.0, Vector3.ZERO]
		depth = INF
		for axis in 3:
			var face := Vector3.ZERO
			face[axis] = 1.0
			if local[axis] - box.position[axis] < depth:
				depth = local[axis] - box.position[axis]
				normal = -face
			if box.end[axis] - local[axis] < depth:
				depth = box.end[axis] - local[axis]
				normal = face
	return [depth, (shape.global_basis * normal).normalized()]


## What is in the way of the ship going from `from` along `motion` among the solid parts under `structure`, as the
## way back out of the first one it meets (Approach.obstacle, as Arrivals asks the physics), checked a metre at a time.
func _in_the_way(from: Vector3, motion: Vector3, structure: Node3D) -> Vector3:
	var steps := int(ceil(motion.length())) + 1
	for i in steps + 1:
		var point := from + motion * (float(i) / steps)
		for child in structure.get_children():
			var shape := child as CollisionShape3D
			if shape != null:
				var inside := _inside(shape, point)
				if inside[0] > 0.0:
					return inside[1]
	return Vector3.ZERO


## How deep (m) the worst point of `path` went into any solid part under `structure` (_inside); 0 when it never
## touched one.
func _deepest_in(structure: Node3D, path: Array[Vector3]) -> float:
	var worst := 0.0
	for child in structure.get_children():
		var shape := child as CollisionShape3D
		if shape == null:
			continue
		for point in path:
			worst = maxf(worst, _inside(shape, point)[0])
	return worst


func test_speed_eases_down_to_a_soft_touch() -> void:
	assert_almost_eq(Approach.speed_for(0.0, 200.0, _tuning), _tuning.touch_speed, 0.001, "touches at touch speed")
	assert_almost_eq(Approach.speed_for(200.0, 200.0, _tuning), sqrt(2.0 * _tuning.final_accel * 200.0), 0.001)
	assert_eq(Approach.speed_for(100000.0, 200.0, _tuning), _tuning.top_speed, "never faster than its top speed")
	var last := 0.0
	for d in range(0, 20000, 50):
		var speed := Approach.speed_for(float(d), 200.0, _tuning)
		assert_true(speed >= last, "slower the closer it is (%.0f m)" % d)
		last = speed


func test_carries_on_at_about_the_speed_it_was_going() -> void:
	assert_eq(Approach.speed_limit(0.0, 4000.0, _tuning), _tuning.least_speed, "from rest far out, its least speed")
	assert_almost_eq(Approach.speed_limit(0.0, 300.0, _tuning), 300.0 / _tuning.least_time, 0.001,
			"from rest close in, slower")
	assert_eq(Approach.speed_limit(0.0, 20.0, _tuning), _tuning.slowest_speed, "but never crawling")
	assert_almost_eq(Approach.speed_limit(8.0, 200.0, _tuning), 10.0, 0.001, "slow and close in, it stays slow")
	assert_almost_eq(Approach.speed_limit(80.0, 1000.0, _tuning), 80.0 * _tuning.speed_up, 0.001,
			"a little faster at most")
	assert_eq(Approach.speed_limit(1000.0, 1000.0, _tuning), _tuning.top_speed, "never past its top speed")
	assert_eq(Approach.speed_for(100000.0, 200.0, _tuning, 50.0), 50.0, "no faster than it is told")
	var dock := _station()
	for speed: float in [10.0, 80.0]:
		var start := dock.gate() + Vector3(1200, 100, 300)
		var f := _fly(dock, start, Vector3(-speed, 0, 0), Basis(Vector3.UP, PI / 2.0))
		assert_true(f.done, "arrives from %.0f m/s" % speed)
		gut.p("docked from %.0f m/s in %.1f s, top %.0f m/s" % [speed, f.time, f.top])
		assert_lte(f.top, Approach.speed_limit(speed, INF, _tuning) + 0.01,
				"never much faster than it was going")


func test_going_round_never_comes_nearer_the_centre() -> void:
	var from := Vector3(0, -7500, 0)
	var to := Vector3(0, 6155, 0)
	var way := Approach.round_heading(from, to, _tuning.climb)
	assert_almost_eq(way.dot(from.normalized()), 0.0, 0.2, "from straight below, it goes across first")
	way = Approach.round_heading(Vector3(6100, 0, 0), to, _tuning.climb)
	assert_gt(way.dot(Vector3.RIGHT), 0.0, "below the gate's height it climbs on the way across")
	assert_almost_eq(Approach.round_length(Vector3(0, 0, 100), Vector3(0, 0, 300)), 200.0, 0.001, "straight out")


func test_the_turn_keeps_within_the_ships_turn_rates() -> void:
	var from := Basis.IDENTITY
	var to := Basis(Vector3.UP, PI * 0.9)
	var spin := Vector3.ZERO
	for i in 600:
		spin = Approach.turn(from, to, spin, _rates, _accels, _tuning.turn_time, DT)
		assert_true(absf(spin.y) <= _rates.y + 0.001, "within the yaw rate (%.3f)" % spin.y)
		from = (Basis(spin.normalized(), spin.length() * DT) * from).orthonormalized() if spin.length() > 0.0 else from
	assert_true(Orbit.lined_up(from, to, deg_to_rad(0.5)), "turns all the way round and stops on it")


func test_the_stations_gate_clears_everything_on_it() -> void:
	var dock := _station()
	var radius := dock.gate().distance_to(dock.centre())
	for corner in _corners(dock.get_parent().get_node(^"Structure")):
		assert_lt(corner.length(), radius - 5.0, "the station's parts are all inside the gate's distance (%s)" % corner)


func test_the_berths_sit_on_the_floor() -> void:
	var ship: Node3D = load("res://game/ship/greybox_ship.tscn").instantiate()
	add_child_autofree(ship)
	var lowest := INF
	for child in ship.get_children():
		var shape := child as CollisionShape3D
		if shape != null:
			lowest = minf(lowest, (shape.transform * shape.shape.get_debug_mesh().get_aabb()).position.y)
	var dock := _station()
	var floor_top := dock.get_parent().get_node(^"Structure/BayFloorShape") as CollisionShape3D
	var top := floor_top.position.y + (floor_top.shape as BoxShape3D).size.y * 0.5
	assert_almost_eq(dock.position.y + lowest, top + 0.05, 0.01, "the docked ship's underside is on the bay's floor")
	assert_almost_eq(dock.lane_origin().y, 155.0, 0.01, "and the way in runs down the middle of its mouth")
	var pad := _planet_pad()
	var pad_shape := pad.get_parent().get_node(^"Structure/PadShape") as CollisionShape3D
	top = pad_shape.position.y + (pad_shape.shape as CylinderShape3D).height * 0.5
	assert_almost_eq(pad.position.y + lowest, top + 0.05, 0.01, "the landed ship's underside is on the pad")


func test_the_bases_gate_is_above_everything_on_it() -> void:
	var pad := _planet_pad()
	var base := pad.get_parent() as Node3D
	for corner in _corners(base.get_node(^"Structure")):
		assert_lt(corner.y, pad.position.y + pad.approach_distance - 30.0, "the base's buildings are under the gate")


func test_docks_from_in_front_backing_in_lined_up() -> void:
	var dock := _station()
	var f := _fly(dock, dock.global_position + Vector3(1400, 100, 300), Vector3(-80, 0, 0),
			Basis(Vector3.UP, PI / 2.0))
	assert_true(f.done, "arrives within %.0f s" % LIMIT)
	gut.p("docked from in front in %.1f s, top %.0f m/s, touched at %.2f m/s" % [f.time, f.top, f.touch])
	assert_lt(f.time, 40.0, "takes well under a minute from the edge of the offer")
	_check_final(dock, f)


func test_docks_from_behind_going_round_the_station() -> void:
	var dock := _station()
	var start := dock.global_position + Vector3(-1200, -300, 200)
	var f := _fly(dock, start, Vector3(0, 0, 60))
	assert_true(f.done, "arrives within %.0f s" % LIMIT)
	gut.p("docked from behind in %.1f s, nearest %.0f m to the station's centre" % [f.time, f.nearest])
	assert_gt(f.nearest, dock.gate().distance_to(dock.centre()) - 2.0, "never cuts through the station")
	_check_final(dock, f)


func test_docks_from_awkward_places_close_to_the_bay_without_touching_the_station() -> void:
	var dock := _station()
	var structure := dock.get_parent().get_node(^"Structure") as Node3D
	var station := dock.get_parent() as Node3D
	# Over the bay's roof, beside its side wall, under its floor by the spine, and just off its mouth to one side.
	var starts: Array[Vector3] = [Vector3(10, 230, 0), Vector3(0, 155, 60), Vector3(30, 115, 20), Vector3(55, 155, 40)]
	for start in starts:
		var f := _fly(dock, station.global_position + start)
		assert_true(f.done, "arrives from %s" % start)
		var into := _deepest_in(structure, f.path)
		assert_eq(into, 0.0, "never touches the station from %s (%.1f m into it)" % [start, into])
		_check_final(dock, f)


func test_climbs_out_of_the_middle_of_the_station_without_touching_it() -> void:
	var dock := _station()
	var structure := dock.get_parent().get_node(^"Structure") as Node3D
	var station := dock.get_parent() as Node3D
	# Inside the ring's wheel: between its spokes just above and below them, beside the spine, and under the wheel.
	var starts: Array[Vector3] = [Vector3(60, 20, 0), Vector3(40, 20, 40), Vector3(47, 3, -69), Vector3(87, 3, -29),
			Vector3(-73, 3, 51), Vector3(47, -37, 11), Vector3(87, -77, 11), Vector3(47, -157, 11), Vector3(0, 30, 38),
			Vector3(90, 0, 30), Vector3(83.15, 0, 34.44)]
	for start in starts:
		var f := _fly(dock, station.global_position + start)
		assert_true(f.done, "arrives from %s" % start)
		var into := _deepest_in(structure, f.path)
		assert_eq(into, 0.0, "never touches the station from %s (%.1f m into it)" % [start, into])
		assert_lt(f.time, 60.0, "takes under a minute from %s" % start)
		_check_final(dock, f)


func test_docks_from_anywhere_inside_the_bay() -> void:
	var dock := _station()
	var structure := dock.get_parent().get_node(^"Structure") as Node3D
	var station := dock.get_parent() as Node3D
	# Off to each side, high and low, behind the berth, and just inside the mouth (the way in runs 155 m up).
	var starts: Array[Vector3] = [Vector3(20, 155, 15), Vector3(-20, 160, 10), Vector3(30, 148, -14),
			Vector3(-15, 150, -12), Vector3(35, 162, 0)]
	for start in starts:
		assert_true(dock.in_lane(station.global_position + start), "%s is in the lane" % start)
		var f := _fly(dock, station.global_position + start)
		assert_true(f.done, "arrives from %s" % start)
		var into := _deepest_in(structure, f.path)
		assert_eq(into, 0.0, "never touches the bay from %s (%.1f m into it)" % [start, into])
		assert_lt(f.time, 60.0, "takes under a minute from %s" % start)
	assert_false(dock.in_lane(station.global_position + Vector3(20, 185, 0)), "over the roof is not")
	# Just over the floor, flown in by hand: it stays low rather than climbing to the middle of the mouth first.
	for start: Vector3 in [Vector3(5, 139.4, 3), Vector3(30, 140, -8), Vector3(-10, 139.4, 0)]:
		var f := _fly(dock, station.global_position + start)
		assert_true(f.done, "arrives from the floor at %s" % start)
		var highest := -INF
		for at in f.path + f.settle_path:
			highest = maxf(highest, (at - dock.global_position).dot(dock.global_basis.y))
		assert_lt(highest, _tuning.low_line + 0.5, "never climbs up the bay from %s (%.1f m up)" % [start, highest])
		assert_lt(f.time, 40.0, "takes under 40 s from %s" % start)
	assert_false(dock.in_lane(station.global_position + Vector3(20, 155, 40)), "beside the wall is not")


func test_brakes_before_cutting_in_when_pressed_fast_and_close() -> void:
	var dock := _station()
	var structure := dock.get_parent().get_node(^"Structure") as Node3D
	var station := dock.get_parent() as Node3D
	# 350 m below the station's middle, heading straight up at it at 99 m/s.
	var f := _fly(dock, station.global_position + Vector3(0, -350, 60), Vector3(0, 99, 0))
	assert_true(f.done, "arrives")
	var into := _deepest_in(structure, f.path)
	assert_eq(into, 0.0, "never touches the station (%.1f m into it)" % into)


func test_rises_onto_the_pad_from_just_under_its_marker() -> void:
	var pad := _planet_pad()
	var f := _fly(pad, pad.global_position - pad.exit_direction() * 3.0, Vector3.ZERO, pad.global_basis)
	assert_true(f.done, "arrives")
	assert_lt(f.time, 5.0, "straight onto it, not round by the gate (%.1f s)" % f.time)


func test_lands_from_low_and_far_without_climbing_higher_than_it_must() -> void:
	var pad := _planet_pad()
	var planet := pad.body
	var base_height := pad.global_position.distance_to(planet.global_position)
	# 60 m up, at the edge of the offer, heading for the base at 50 m/s.
	var start := (pad.global_position + Vector3(580, 0, 0)).normalized() * (base_height + 60.0)
	assert_lt(pad.distance(start), pad.offer_range, "landing is offered here")
	var f := _fly(pad, start, (pad.global_position - start).normalized() * 50.0)
	assert_true(f.done, "arrives within %.0f s" % LIMIT)
	gut.p("landed from low and far in %.1f s, top %.0f m/s, highest %.0f m above the pad"
			% [f.time, f.top, f.highest - base_height])
	assert_lt(f.highest - base_height, pad.low_gate + 5.0, "climbs only as high as it must to clear the base")
	assert_gt(f.nearest, planet.radius + 40.0, "never near the ground")
	assert_lte(f.top, Approach.speed_limit(50.0, INF, _tuning) + 0.01,
			"never much faster than it was going")
	_check_final(pad, f)


func test_lands_from_the_edge_of_the_offer_at_rest() -> void:
	var pad := _planet_pad()
	var start := pad.global_position + Vector3(420, 420, 0)
	assert_lt(pad.distance(start), pad.offer_range, "landing is offered here")
	var f := _fly(pad, start)
	assert_true(f.done, "arrives within %.0f s" % LIMIT)
	gut.p("landed from rest %.1f km out in %.1f s" % [pad.distance(start) / 1000.0, f.time])
	_check_final(pad, f)


func test_lands_from_low_beside_the_base_climbing_clear_first() -> void:
	var pad := _planet_pad()
	var planet := pad.body
	# 20 m up, 400 m from the pad, beyond the tower.
	var start := pad.global_position + Vector3(300, 15, -260)
	var f := _fly(pad, start)
	assert_true(f.done, "arrives within %.0f s" % LIMIT)
	assert_true(f.nearest > planet.radius + 10.0, "never touches the ground")
	_check_final(pad, f)


## The final leg: lined up before it is within the hold-short distance (nose first into a bay), close to the line in,
## turning round in a bay by yawing in place (never flipping over), then in a bay settling straight down onto the
## floor, and touching softly at the berth, facing its way.
func _check_final(port: Port, f: Flight) -> void:
	assert_false(f.final_at.is_empty(), "takes a final leg")
	assert_lt(f.touch, _tuning.touch_speed + 0.5, "touches softly (%.2f m/s)" % f.touch)
	assert_true(f.turn_rates.x <= _rates.x + 0.01 and f.turn_rates.y <= _rates.y + 0.01
			and f.turn_rates.z <= _rates.z + 0.01, "turns within the ship's own rates (%s)" % f.turn_rates)
	var out := port.exit_direction()
	var berth := port.global_basis.orthonormalized()
	var nose_in := Basis(berth.y, PI) * berth if port.turn_round_at > 0.0 else berth
	var worst_side := 0.0
	var worst_angle := 0.0
	var worst_tilt := 0.0
	var deepest := INF
	for i in f.final_at.size():
		var rel := f.final_at[i] - port.lane_origin()
		var along := rel.dot(out)
		if along < _tuning.hold_short - 1.0:
			worst_side = maxf(worst_side, (rel - out * along).length())
			worst_tilt = maxf(worst_tilt, rad_to_deg(f.final_basis[i].y.angle_to(berth.y)))
			if along > port.turn_round_at + 1.0:
				worst_angle = maxf(worst_angle, rad_to_deg(f.final_basis[i].z.angle_to(nose_in.z)))
		deepest = minf(deepest, along)
	assert_lt(worst_side, 3.0, "keeps to the line in near the berth (%.2f m off)" % worst_side)
	assert_lt(worst_angle, _tuning.lined_up_angle * 3.0 + 0.5, "lined up on the way in (%.2f degrees off)" % worst_angle)
	assert_lt(worst_tilt, 5.0, "stays level with the berth, never flipping over (%.2f degrees)" % worst_tilt)
	assert_gt(deepest, -0.5, "never goes past the berth (%.2f m)" % deepest)
	var last := f.final_basis[f.final_basis.size() - 1]
	if port.settle > 0.0:
		assert_false(f.settle_path.is_empty(), "settles onto the floor")
		var up := port.global_basis.y
		var worst_drift := 0.0
		var lowest := INF
		for i in f.settle_path.size():
			var rel := f.settle_path[i] - port.global_position
			worst_drift = maxf(worst_drift, (rel - up * rel.dot(up)).length())
			lowest = minf(lowest, rel.dot(up))
			worst_angle = maxf(worst_angle, rad_to_deg(f.settle_basis[i].z.angle_to(berth.z)))
		assert_lt(worst_drift, 1.5, "straight down over the berth (%.2f m off)" % worst_drift)
		assert_gt(lowest, -0.05, "never through the floor (%.2f m)" % lowest)
		assert_lt(worst_angle, _tuning.lined_up_angle * 3.0 + 0.5, "facing out of the mouth all the way down")
		last = f.settle_basis[f.settle_basis.size() - 1]
	else:
		assert_true(f.settle_path.is_empty(), "a pad's way in already comes straight down")
	assert_lt(rad_to_deg(last.z.angle_to(berth.z)), _tuning.lined_up_angle * 3.0 + 0.5, "ends facing the berth's way")
