class_name SmokeRun
extends Node
## The headless smoke test behind `-- --smoke` (tools/smoke_test.sh): lets the game run for FRAMES physics frames, then
## prints the result line the script looks for and quits. For now it only proves the game boots and ticks; it grows
## to fly, dock and quit as those features land (project instructions, "Testing and Honesty").

const FRAMES := 300
## tools/smoke_test.sh fails unless this line is printed.
const PASS_LINE := "SMOKE: ok"

var _frames: int = 0


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < FRAMES:
		return
	print("%s frames=%d seed=%d clock=%.2f" % [PASS_LINE, _frames, Game.world_seed, Game.clock])
	set_physics_process(false)
	get_tree().quit(0)
