extends Node3D
## The first scene: a placeholder until the first playable has a ship to fly. Shows the version and the world seed,
## and starts the smoke test when launched with `-- --smoke`.

@onready var _status: Label = %Status


func _ready() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_status.text = "Project Praesepe %s\nProject skeleton: nothing to fly yet.\nWorld seed %d" % [version, Game.world_seed]
	if Game.launch_args.smoke:
		add_child(SmokeRun.new())
