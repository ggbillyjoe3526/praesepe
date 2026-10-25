extends GutTest
## The tiny solar system as authored (design doc, "The tiny solar system"): every place the first playable needs is in
## it, named from the naming list; the places sit where the design doc's table says; nothing overlaps; the player
## starts in open space next to the station with the planet ahead; the station's bay and the base's pad have room for
## the ship and a clear way out. The smoke test then cruises to each one, docks and lands.

const PLACES: Array[String] = ["Calder", "Tollgate", "Mote", "Halfway Station", "The Shingle"]

var _system: SolarSystem


func before_each() -> void:
	_system = load("res://game/system/solar_system.tscn").instantiate()
	add_child_autofree(_system)


func test_has_every_place_once() -> void:
	assert_eq(_system.landmarks.size(), PLACES.size())
	for place: String in PLACES:
		assert_not_null(_system.landmark(place), place)


func test_every_place_has_a_marker_showing_the_distance_to_fly() -> void:
	var at := _system.start_transform().origin
	for l: Landmark in _system.landmarks:
		assert_true(l.marker, "%s has a HUD marker" % l.display_name)
	var calder := _system.landmark("Calder")
	assert_almost_eq(calder.marker_distance(at), at.length() - calder.radius, 0.5, "a planet: to its surface")
	var belt := _system.landmark("The Shingle")
	assert_almost_eq(belt.marker_distance(at), at.distance_to(belt.marker_position()), 0.5, "the belt: to its pocket")


func test_every_name_is_in_the_naming_list() -> void:
	var design := FileAccess.get_file_as_string("res://DESIGN.md")
	var list := design.substr(design.find("## Naming list"))
	assert_gt(list.length(), 0, "DESIGN.md has a naming list")
	assert_string_contains(list, "| Sorrel |", false)
	for l: Landmark in _system.landmarks:
		assert_string_contains(list, "| %s |" % l.display_name, false)


func test_places_sit_where_the_design_doc_says() -> void:
	# Compressed scale in metres; DESIGN.md, "The tiny solar system".
	var calder := _system.landmark("Calder")
	assert_eq(calder.global_position, Vector3.ZERO, "the system's origin is the planet's centre")
	assert_eq(calder.radius, 6000.0)
	assert_almost_eq(_system.landmark("Halfway Station").global_position.length(), 16045.0, 5.0)
	assert_almost_eq(_system.landmark("Mote").global_position.length(), 31000.0, 5.0)
	var base := _system.landmark("Tollgate")
	assert_almost_eq(base.global_position.length(), 5998.0, 1.0, "on Calder's surface")
	assert_almost_eq(base.global_basis.y.dot(base.global_position.normalized()), 1.0, 0.0001, "standing upright")


func test_no_two_places_overlap() -> void:
	# Each place's arrival zone stays clear of every other place, except the base on its planet.
	for a: Landmark in _system.landmarks:
		for b: Landmark in _system.landmarks:
			if a == b or (a.display_name == "Tollgate" and b.display_name == "Calder"):
				continue
			if b.display_name == "Tollgate" and a.display_name == "Calder":
				continue
			var gap := b.surface_distance(a.marker_position())
			assert_gt(gap, a.drop_distance, "%s's zone is clear of %s (%.0f m)" % [a.display_name, b.display_name, gap])


func test_starts_next_to_the_station_facing_open_space_and_the_planet() -> void:
	var start := _system.start_transform()
	var station := _system.landmark("Halfway Station")
	var calder := _system.landmark("Calder")
	var forward := -start.basis.z
	assert_lt(station.surface_distance(start.origin), station.drop_distance, "close to the station")
	assert_gt(station.surface_distance(start.origin), 1000.0, "but clear of it")
	assert_lt(rad_to_deg(forward.angle_to(calder.global_position - start.origin)), 25.0, "Calder ahead")
	# Nothing to hit for the smoke test's first 8 km.
	for l: Landmark in _system.landmarks:
		for step in 9:
			var at := start.origin + forward * 1000.0 * step
			assert_gt(l.surface_distance(at), 600.0, "%s is clear of the start's runway" % l.display_name)


func test_the_sun_lights_the_planet_from_the_start_side() -> void:
	var towards_sun := _system.sun.global_basis.z
	var start := _system.start_transform().origin
	assert_gt(towards_sun.dot(start.normalized()), 0.3, "the face of Calder the player first sees is mostly lit")


func test_the_drive_never_engages_among_tollgates_buildings() -> void:
	var drive := CruiseDrive.new(load("res://game/ship/greybox_cruise_tuning.tres"))
	drive.landmarks = _system.landmarks
	var base := _system.landmark("Tollgate")
	var hangar := base.global_basis * Vector3(-1, 0, 0)
	# Hovering over the pad, nose level at the hangar.
	assert_eq(_try_engage(drive, base.to_global(Vector3(0, 20, 0)), hangar), CruiseDrive.Event.BLOCKED_INSIDE)
	assert_eq(drive.place, base)
	# Just outside, nose at the buildings (the ground curves up into the way too, so either may be named).
	assert_eq(_try_engage(drive, base.to_global(Vector3(400, 20, 0)), hangar), CruiseDrive.Event.BLOCKED)
	assert_true(drive.place == base or drive.place == _system.landmark("Calder"))
	# Higher up, aimed down at the pad from 600 m: the base itself is in the way.
	var above := base.to_global(Vector3(0, 600, 0))
	assert_eq(_try_engage(drive, above, (base.global_position - above).normalized()), CruiseDrive.Event.BLOCKED)
	assert_eq(drive.place, base)
	# Clear of them, heading up and away, it goes.
	assert_eq(_try_engage(drive, base.to_global(Vector3(0, 300, 0)), base.global_basis.y), CruiseDrive.Event.ENGAGED)


## Presses F with the ship holding still at `at`, nose along `nose`, and gives the drive's answer once charged.
func _try_engage(drive: CruiseDrive, at: Vector3, nose: Vector3) -> CruiseDrive.Event:
	drive.phase = CruiseDrive.Phase.OFF
	drive.step(at, Vector3.ZERO, nose, true, false, 0.0, 1.0 / 60.0)
	var ticks := roundi(drive.tuning.charge_time * 60.0) + 1
	for i in ticks:
		drive.step(at, Vector3.ZERO, nose, false, false, 0.0, 1.0 / 60.0)
		if drive.event != CruiseDrive.Event.NONE:
			return drive.event
	return CruiseDrive.Event.NONE


func test_the_station_docks_and_the_base_lands() -> void:
	assert_eq(_system.ports.size(), 2)
	var dock := _system.port(&"halfway_station")
	var pad := _system.port(&"tollgate")
	assert_eq(dock.kind, Port.Kind.DOCK)
	assert_eq(dock.place, _system.landmark("Halfway Station"))
	assert_null(dock.body)
	assert_eq(pad.kind, Port.Kind.PAD)
	assert_eq(pad.place, _system.landmark("Tollgate"))
	assert_eq(pad.body, _system.landmark("Calder"), "the way down to the pad goes round Calder")
	assert_almost_eq(pad.global_basis.y.dot(pad.global_position.normalized()), 1.0, 0.0001, "the pad faces up")
	# The cruise drive drops out of each place's zone inside the hint range, so the prompt is there on arrival.
	var station := _system.landmark("Halfway Station")
	assert_lt(station.radius + station.drop_distance + dock.position.length(), dock.hint_range)
	var tollgate := _system.landmark("Tollgate")
	assert_lt(tollgate.radius + tollgate.drop_distance + pad.position.length(), pad.hint_range,
			"cruising to Tollgate ends where the prompt to land shows")


func test_the_ship_fits_its_berths_and_leaves_without_touching_anything() -> void:
	await wait_physics_frames(2)
	var ship: Ship = load("res://game/ship/greybox_ship.tscn").instantiate()
	var shapes: Array[CollisionShape3D] = []
	for child: Node in ship.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	assert_gt(shapes.size(), 0)
	var space := _system.get_world_3d().direct_space_state
	for p: Port in _system.ports:
		# At the berth, lifting off a bay's floor in steps of 1 m, then along the way out and a little beyond it, in
		# steps of 2 m.
		var places: Array[Vector3] = []
		for step in ceili(p.settle) + 1:
			places.append(p.global_position + p.global_basis.y * minf(step, p.settle))
		for step in roundi(p.exit_distance / 2.0) + 6:
			places.append(p.lane_origin() + p.exit_direction() * step * 2.0)
		for origin in places:
			var at := Transform3D(p.global_basis, origin)
			for c: CollisionShape3D in shapes:
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = c.shape
				query.transform = at * c.transform
				query.margin = 0.02
				var hits := space.intersect_shape(query, 1)
				assert_eq(hits.size(), 0, "%s: the %s is clear at %s" % [p.id, c.name, origin - p.global_position])
	ship.free()
