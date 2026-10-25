class_name Ship
extends RigidBody3D
## A flyable ship. Every physics tick it reads `input` (filled by PilotControls or an autopilot), asks its FlightModel
## for the accelerations and adds them to its velocity; the physics engine moves it and handles bumps. Gravity and
## damping are off: in space nothing slows the ship but its own thrusters.
## The ship also says where its cameras sit (the pilot's eye in the cockpit, the chase camera behind it) and how hard it
## was last bumped, for camera shake.
## While its cruise drive (CruiseDrive) runs, the drive sets the ship's speed and direction and flight assist only
## turns it; the thrust keys and Z do nothing until it drops out. In orbit (Orbit) the orbit sets its velocity the same
## way and the ship's attitude turns with the orbit; O or a thrust key leaves orbit once the nose has come up level, X
## or Z at once, and then they work as usual.
## Docking or landing (Arrivals), it flies itself in: Arrivals guides it at a set velocity and spin each tick while it
## ignores its input. Docked or landed it is held still at its berth; leaving, Arrivals guides it out again before
## handing it back to the pilot.

signal assist_changed(on: bool)
## The cruise drive charged, engaged, refused or dropped out (CruiseDrive.Event), at `place` where there is one.
signal cruise_changed(event: CruiseDrive.Event, place: Landmark)
## The ship entered, settled into, left or was refused an orbit (Orbit.Event), round `body` where there is one.
signal orbit_changed(event: Orbit.Event, body: CelestialBody)

@export var tuning: ShipTuning
@export var cruise_tuning: CruiseTuning
@export var orbit_tuning: OrbitTuning
## The pilot's eye in the cockpit (game/camera/cockpit_camera.gd).
@export var eye: Node3D
## Where the chase camera sits when the ship flies straight (game/camera/chase_camera.gd).
@export var chase_anchor: Node3D

var input: ShipInput = ShipInput.new()
var model: FlightModel
var cruise: CruiseDrive
var orbit: Orbit
## How suddenly the ship's velocity changed in the last physics step for a reason other than its own thrusters, such
## as a bump (m/s). Zero in open space.
var jolt: float = 0.0
## Where the ship is docked or landed, or is leaving from, or null while it flies.
var berth: Port = null
## Where Arrivals is flying the ship in to, or null.
var bound_for: Port = null
## True while Arrivals guides the ship (in to its berth or out of it) at `guided_velocity` and `guided_spin`.
var guided: bool = false
var guided_velocity: Vector3 = Vector3.ZERO
var guided_spin: Vector3 = Vector3.ZERO
var _expected_velocity: Vector3 = Vector3.ZERO
## The speed (m/s) it touched its berth at, felt as a bump on the next tick.
var _touch: float = 0.0


func _ready() -> void:
	process_physics_priority = FlightOrder.SHIP
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	model = FlightModel.new(tuning)
	cruise = CruiseDrive.new(cruise_tuning)
	orbit = Orbit.new(orbit_tuning)


func _physics_process(delta: float) -> void:
	if berth != null or guided:
		_held(delta)
		return
	# Nothing but a collision changes the velocity between the last tick's thrust and now.
	jolt = linear_velocity.distance_to(_expected_velocity)
	var was_on := model.assist
	var was_cruising := cruise.active()
	cruise.step(global_position, linear_velocity, -global_basis.z, input.toggle_cruise, input.full_stop, jolt, delta)
	input.toggle_cruise = false
	var stopping := input.full_stop
	if was_cruising or cruise.active():
		# The drive has the speed; flight assist only turns the ship. X still stops it once it has dropped out.
		input.thrust = Vector3.ZERO
		input.toggle_assist = false
	var pilot_turn := input.turn
	_step_orbit(delta)
	if cruise.event == CruiseDrive.Event.ENGAGED or orbit.event == Orbit.Event.ENTERING:
		model.set_assist(true, 0.0)
	model.step(pilot_velocity(), pilot_spin(), input, delta)
	# The orbit may have steered this tick; the input keeps what the pilot asked for.
	input.turn = pilot_turn
	if model.assist != was_on:
		assist_changed.emit(model.assist)
	var b := global_basis
	var w := model.angular_accel
	angular_velocity += b * Vector3(w.x, -w.y, -w.z) * delta
	if orbit.phase == Orbit.Phase.LEAVING:
		angular_velocity = orbit.level_spin(b, tuning.max_rates(), delta)
	if cruise.active():
		model.linear_accel = Vector3.ZERO
		linear_velocity = cruise.velocity
	elif was_cruising:
		model.linear_accel = Vector3.ZERO
		linear_velocity = cruise.velocity
		if not stopping:
			model.set_speed = cruise.exit_speed
	elif orbit.active():
		model.linear_accel = Vector3.ZERO
		linear_velocity = orbit.velocity
	else:
		var a := model.linear_accel
		linear_velocity += b * Vector3(a.x, a.y, -a.z) * delta
	_expected_velocity = linear_velocity
	if cruise.event != CruiseDrive.Event.NONE:
		cruise_changed.emit(cruise.event, cruise.place)
	if orbit.event != Orbit.Event.NONE:
		orbit_changed.emit(orbit.event, orbit.body if orbit.event != Orbit.Event.REFUSED else orbit.offered)


## The orbit's part of a tick, before the flight model runs: O enters or leaves it, anything else the pilot does with
## the ship leaves it (a thrust key levelling out first, like O), and while it lasts the ship may be turning to face
## along it.
func _step_orbit(delta: float) -> void:
	var leave := input.thrust != Vector3.ZERO
	var drop := input.full_stop or input.toggle_assist or cruise.event == CruiseDrive.Event.ENGAGED
	orbit.step(global_position, linear_velocity, -global_basis.z, input.toggle_orbit, leave, drop, jolt,
			cruise.phase != CruiseDrive.Phase.CRUISING, delta)
	input.toggle_orbit = false
	if orbit.event == Orbit.Event.LEFT or orbit.event == Orbit.Event.BUMPED:
		# Flight assist carries on at the speed the orbit left the ship with, along its nose (levelled out along the
		# velocity when leaving with O or thrust, so that is all of it).
		model.set_speed = clampf(pilot_velocity().z, -tuning.max_reverse_speed, tuning.max_speed)
	if orbit.active():
		input.turn = orbit.turn_for(global_basis, global_position, input.turn, tuning.max_rates())


## Docked, landed or being guided in or out: no flight and nothing from the input. The one-shots are dropped so a key
## pressed meanwhile does nothing once the ship flies again. While guided, a bump still shows (as `jolt`), and the
## guiding's push counts as the thrusters', so the pilot's head sways and the engines rumble as in flight.
func _held(delta: float) -> void:
	jolt = linear_velocity.distance_to(_expected_velocity) if guided else _touch
	_touch = 0.0
	input.toggle_assist = false
	input.toggle_cruise = false
	input.toggle_orbit = false
	input.full_stop = false
	var before := _expected_velocity
	linear_velocity = guided_velocity if guided else Vector3.ZERO
	angular_velocity = guided_spin if guided else Vector3.ZERO
	var push := global_basis.transposed() * (linear_velocity - before) / delta
	model.linear_accel = Vector3(push.x, push.y, -push.z)
	model.angular_accel = Vector3.ZERO
	_expected_velocity = linear_velocity


## Holds the ship still at `port`, as Arrivals.arrive() does on docking or landing: placed at its berth, the cruise
## drive and any orbit stopped, flight assist on and holding zero. It touched down at `touch` m/s, felt as a soft bump.
func hold_at(port: Port, touch: float = 0.0) -> void:
	cruise.stop()
	orbit.stop()
	berth = port
	bound_for = null
	guided = false
	_touch = touch
	global_transform = port.global_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_expected_velocity = Vector3.ZERO
	model.set_assist(true, 0.0)
	model.set_speed = 0.0
	input.reset()
	reset_physics_interpolation()


## Starts flying the ship in to `port` (Arrivals): the cruise drive and any orbit stop, and from now on it goes as it
## is guided, carrying on as it was until then.
func approach(port: Port) -> void:
	cruise.stop()
	orbit.stop()
	bound_for = port
	_expected_velocity = linear_velocity
	guide(linear_velocity, angular_velocity)


## Moves the ship at `velocity` (world space), spinning at `spin`, while it is guided in to its berth or out of it.
func guide(velocity: Vector3, spin: Vector3 = Vector3.ZERO) -> void:
	guided = true
	guided_velocity = velocity
	guided_spin = spin


## Hands the ship back to the pilot after guiding it out (or when the way in is cancelled), moving at `velocity`
## (world space) and still turning as it was: flight assist on, holding its forward speed.
func release(velocity: Vector3) -> void:
	berth = null
	bound_for = null
	guided = false
	guided_spin = Vector3.ZERO
	linear_velocity = velocity
	_expected_velocity = velocity
	model.set_assist(true, 0.0)
	model.set_speed = clampf(pilot_velocity().z, -tuning.max_reverse_speed, tuning.max_speed)
	input.reset()


## The ship's velocity in the pilot's frame: x right, y up, z forward.
func pilot_velocity() -> Vector3:
	var v := global_basis.transposed() * linear_velocity
	return Vector3(v.x, v.y, -v.z)


## The ship's spin in the pilot's frame (rad/s): x pitch up, y yaw right, z roll right. In orbit it is the spin
## against the orbit's turning frame, so a still stick keeps the view of the planet still.
func pilot_spin() -> Vector3:
	var w := global_basis.transposed() * (angular_velocity - (orbit.spin if orbit.active() else Vector3.ZERO))
	return Vector3(w.x, -w.y, -w.z)


func speed() -> float:
	return linear_velocity.length()


func assist_on() -> bool:
	return model.assist


## The forward speed (m/s) flight assist is holding.
func held_speed() -> float:
	return model.set_speed


## How hard the thrusters are pushing, 0 to 1 of the main engine's push.
func thrust_level() -> float:
	if cruise.active():
		return cruise_tuning.rumble
	return clampf(model.linear_accel.length() / tuning.forward_accel, 0.0, 1.0)
