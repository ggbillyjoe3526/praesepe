extends Node
## The Game autoload: the world seed, every random stream and the in-game clock (project instructions, "Performance
## and Code"). Gameplay never calls the global randi() or randf(): it draws from `Game.rng(<stream>)`, so the same seed
## gives the same world. Presentation-only randomness (sparkles, shake) uses the FX stream, so effects never move a
## gameplay draw.

## The streams gameplay may draw from. Add a name here before using it; adding one never moves another's draws.
const GAMEPLAY_STREAMS: Array[StringName] = [&"world", &"contracts", &"events"]
## The presentation-only stream.
const FX_STREAM: StringName = &"fx"

var world_seed: int = 0
## In-game seconds since this world started. Advances with scaled physics time while the game isn't paused; waiting
## (sleep, end of shift) is skipped with skip_time(), never real time.
var clock: float = 0.0
var launch_args: LaunchArgs = LaunchArgs.new()
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _ready() -> void:
	launch_args = LaunchArgs.parse(OS.get_cmdline_user_args())
	var chosen := launch_args.seed_value
	start_world(chosen if chosen != LaunchArgs.NO_SEED else Seeds.fresh())


func _physics_process(delta: float) -> void:
	clock += delta


## Starts a world on `seed_value`: every stream restarts from its first draw and the clock from zero. Streams are
## reseeded in place, so a generator someone kept from `rng()` follows the new world too.
func start_world(seed_value: int) -> void:
	world_seed = seed_value & Seeds.MASK_32
	clock = 0.0
	for stream_name: StringName in _streams:
		_streams[stream_name].seed = Seeds.stream_seed(world_seed, stream_name)


## The random stream `stream_name` (one of GAMEPLAY_STREAMS, or FX_STREAM), created on first use.
func rng(stream_name: StringName) -> RandomNumberGenerator:
	var existing: RandomNumberGenerator = _streams.get(stream_name)
	if existing != null:
		return existing
	if stream_name != FX_STREAM and not GAMEPLAY_STREAMS.has(stream_name):
		push_error("Game.rng: unknown stream '%s'; add it to GAMEPLAY_STREAMS" % stream_name)
	var created := Seeds.stream(Seeds.stream_seed(world_seed, stream_name))
	_streams[stream_name] = created
	return created


## Moves the in-game clock forward without waiting, for sleeping or ending a shift.
func skip_time(seconds: float) -> void:
	clock += maxf(seconds, 0.0)


## The world seed, the clock and where each gameplay stream has got to, for a save file. A stream's state is a 64-bit
## number that JSON can't hold exactly, so it is written as a string. The FX stream is presentation only and not saved.
func snapshot() -> Dictionary:
	var states := {}
	for stream_name: StringName in _streams:
		if stream_name != FX_STREAM:
			states[String(stream_name)] = str(_streams[stream_name].state)
	return {"world_seed": world_seed, "clock": clock, "streams": states}


## Puts back a snapshot(): the same seed, clock and stream positions, so the next draws match the saved game's. A
## missing or unreadable value starts that part fresh.
func restore(data: Dictionary) -> void:
	start_world(int(data.get("world_seed", 0)))
	clock = maxf(float(data.get("clock", 0.0)), 0.0)
	var states: Variant = data.get("streams", {})
	if not states is Dictionary:
		return
	for key: Variant in states:
		var value := str(states[key])
		if GAMEPLAY_STREAMS.has(StringName(str(key))) and value.is_valid_int():
			rng(StringName(str(key))).state = value.to_int()
