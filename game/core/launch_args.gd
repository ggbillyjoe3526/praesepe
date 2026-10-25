class_name LaunchArgs
extends RefCounted
## The options given after `--` on the command line, as in `godot --path . -- --smoke --seed 1234` (README.md, "Debug
## flags"). A bad value is ignored with a warning. The `--seed` parsing follows the owner's Airsoft-Next project
## (game/debug/launch_seed.gd).

## No usable `--seed` was given.
const NO_SEED := -1
const SEED := "--seed"
const SMOKE := "--smoke"
const PERF := "--perf"
const NAV := "--nav"

## The world seed asked for, or NO_SEED.
var seed_value: int = NO_SEED
## Run the headless smoke test (game/debug/smoke_run.gd) and quit.
var smoke: bool = false
## Log performance counters every 2 s and a summary at exit (game/debug/debug_perf.gd).
var perf: bool = false
## With --smoke: the nav computer flies the smoke run instead (game/debug/nav_smoke_run.gd).
var nav: bool = false


static func parse(args: PackedStringArray) -> LaunchArgs:
	var out := LaunchArgs.new()
	out.smoke = args.has(SMOKE)
	out.perf = args.has(PERF)
	out.nav = args.has(NAV)
	out.seed_value = _parse_seed(args)
	return out


## The first `--seed <n>` or `--seed=<n>`, or NO_SEED if there is none or it is not a number from 0 to Seeds.MAX_SEED.
static func _parse_seed(args: PackedStringArray) -> int:
	for i in args.size():
		var value := ""
		if args[i] == SEED:
			if i + 1 >= args.size():
				push_warning("LaunchArgs: %s needs a number; ignored" % SEED)
				return NO_SEED
			value = args[i + 1]
		elif args[i].begins_with(SEED + "="):
			value = args[i].substr(SEED.length() + 1)
		else:
			continue
		if not value.is_valid_int():
			push_warning("LaunchArgs: %s '%s' isn't a whole number; ignored" % [SEED, value])
			return NO_SEED
		var n := value.to_int()
		if n < 0 or n > Seeds.MAX_SEED:
			push_warning("LaunchArgs: %s %s is outside 0 to %d; ignored" % [SEED, value, Seeds.MAX_SEED])
			return NO_SEED
		return n
	return NO_SEED
