extends SceneTree
## Writes build/release/THIRD_PARTY_NOTICES.txt: the licence text for everything made by someone else that ships
## inside the game, starting with the Godot Engine itself. From the owner's katanashotgun project. The release workflow
## runs it before packaging and puts the file next to the game in the installer and the zip (RELEASING.md), so it
## always matches the Godot version the game was exported with. Run it by hand with:
##   godot --headless --path . -s res://tools/make_notices.gd
## Third-party assets are listed in ASSETS.md; each one that ships in the game with a licence file needs an entry in
## SHIPPED below.

const OUT := "res://build/release/THIRD_PARTY_NOTICES.txt"
const RULE := "================================================================================"

## [name, licence file] for each third-party asset inside the game. Nothing yet: Gut and its fonts are tests only.
const SHIPPED: Array[Array] = []


func _initialize() -> void:
	var out := PackedStringArray()
	out.append("Project Praesepe: third-party licences")
	out.append("")
	out.append("This game includes work by other people, used under the licences below.")
	out.append("Everything else in the game was made for Project Praesepe.")
	out.append("")
	for entry: Array in SHIPPED:
		_section(out, entry[0])
		var text := FileAccess.get_file_as_string(entry[1])
		if text.is_empty():
			push_error("make_notices: can't read %s" % entry[1])
			quit(1)
			return
		out.append(text.strip_edges())
		out.append("")
	_godot(out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("make_notices: can't write %s" % OUT)
		quit(1)
		return
	f.store_string("\n".join(out).strip_edges() + "\n")
	f.close()
	print("make_notices: wrote %s" % OUT)
	quit(0)


func _section(out: PackedStringArray, title: String) -> void:
	out.append(RULE)
	out.append(title)
	out.append(RULE)
	out.append("")


## Godot's own licence, then every component built into the engine and its licence, as the engine reports them
## (godotengine.org/license).
func _godot(out: PackedStringArray) -> void:
	_section(out, "Godot Engine %s" % Engine.get_version_info()["string"])
	out.append("This game uses the Godot Engine, available under the following licence:")
	out.append("")
	out.append(Engine.get_license_text().strip_edges())
	out.append("")
	_section(out, "Components of the Godot Engine")
	for component: Dictionary in Engine.get_copyright_info():
		out.append("- %s" % component["name"])
		for part: Dictionary in component["parts"]:
			for line: String in part["copyright"]:
				out.append("  Copyright %s" % line)
			out.append("  Licence: %s" % part["license"])
		out.append("")
	var licences: Dictionary = Engine.get_license_info()
	var names := licences.keys()
	names.sort()
	for licence_name: String in names:
		_section(out, "Licence: %s" % licence_name)
		out.append(String(licences[licence_name]).strip_edges())
		out.append("")
