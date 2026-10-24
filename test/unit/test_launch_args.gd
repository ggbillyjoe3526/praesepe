extends GutTest
## The command-line options after `--` (README.md, "Debug flags").


func test_seed_both_spellings() -> void:
	assert_eq(LaunchArgs.parse(PackedStringArray(["--seed", "1234"])).seed_value, 1234)
	assert_eq(LaunchArgs.parse(PackedStringArray(["--seed=99"])).seed_value, 99)


func test_bad_seeds_are_ignored() -> void:
	for args: Array in [["--seed"], ["--seed", "abc"], ["--seed=-4"], ["--seed=4294967296"], []]:
		assert_eq(LaunchArgs.parse(PackedStringArray(args)).seed_value, LaunchArgs.NO_SEED, str(args))


func test_smoke_flag() -> void:
	assert_true(LaunchArgs.parse(PackedStringArray(["--seed", "3", "--smoke"])).smoke)
	assert_false(LaunchArgs.parse(PackedStringArray(["--seed", "3"])).smoke)
