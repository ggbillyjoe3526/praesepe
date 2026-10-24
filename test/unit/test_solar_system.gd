extends GutTest
## The tiny solar system as authored (design doc, "The tiny solar system"): every place the first playable needs is in
## it, named from the naming list; the places sit where the design doc's table says; nothing overlaps; the player
## starts in open space next to the station with the planet ahead. The smoke test then cruises to each one.

const PLACES: Array[String] = ["Calder", "Tollgate", "Mote", "Halfway Station", "The Shingle"]

var _system: SolarSystem


func before_each() -> void:
	_system = load("res://game/system/solar_system.tscn").instantiate()
	add_child_autofree(_system)


func test_has_every_place_once() -> void:
	assert_eq(_system.landmarks.size(), PLACES.size())
	for place: String in PLACES:
		assert_not_null(_system.landmark(place), place)


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
