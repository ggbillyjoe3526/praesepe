class_name Seeds
## World seeds and the random streams derived from them (design doc, "Seeded generation"). A seed is an unsigned 32-bit
## integer. Each named stream gets its own seed from the world seed and the stream's name, with exact 32-bit
## arithmetic, so the same world seed always replays the same draws and adding a stream never moves another's. The
## derivation follows the owner's Airsoft-Next project (game/sim/seeds.gd).

const MAX_SEED := 0xFFFFFFFF
const MASK_32 := 0xFFFFFFFF
## seed × multiplier + offset, mod 2^32: arbitrary large primes that keep the streams apart. Changing them changes
## every seeded world.
const STREAM_MULTIPLIER := 2654435761
const STREAM_OFFSET := 374761393
const FNV_OFFSET := 2166136261
const FNV_PRIME := 16777619


## `seed × multiplier + add`, wrapped to 32 bits. A large seed times a large multiplier overflows GDScript's 64-bit
## integers, which wrap around; the low 32 bits of a wrapped product are still exact, so the masked result is right.
static func derive(seed_value: int, multiplier: int, add: int) -> int:
	return ((seed_value & MASK_32) * multiplier + add) & MASK_32


## FNV-1a over the name's UTF-8 bytes: a stable 32-bit number for a stream name. String.hash() is not used because
## nothing promises it stays the same between Godot versions.
static func name_hash(stream_name: StringName) -> int:
	var h := FNV_OFFSET
	for b: int in String(stream_name).to_utf8_buffer():
		h = ((h ^ b) * FNV_PRIME) & MASK_32
	return h


## The seed of stream `stream_name` in a world seeded with `world_seed`.
static func stream_seed(world_seed: int, stream_name: StringName) -> int:
	return derive((world_seed & MASK_32) ^ name_hash(stream_name), STREAM_MULTIPLIER, STREAM_OFFSET)


## A generator seeded with `seed_value`.
static func stream(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value & MASK_32
	return rng


## A fresh world seed from the engine's own randomness. Only for picking a new world's seed, never for gameplay.
static func fresh() -> int:
	return randi() & MASK_32
