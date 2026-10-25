class_name InterfacePage
extends SettingsPage
## Settings › Interface: what the HUD shows and how big. For now the interface size: the HUD, its text and the menus
## together, for big or high-resolution screens (William, 2026-10-25). Takes effect at once (DisplayApply).

var size_choice: OptionButton


func _init() -> void:
	title = "Interface"
	keys = PackedStringArray(["ui_scale"])


func build() -> void:
	add_heading("Size")
	size_choice = add_choice("Interface size", InterfacePage.size_names(), _pick_size)
	add_hint("Makes the HUD, its text and the menus bigger or smaller. 100% already grows with the screen; go up for a "
			+ "big screen you sit far from.")


func sync() -> void:
	size_choice.select(DisplayApply.UI_SCALES.find(Settings.ui_scale))


static func size_names() -> PackedStringArray:
	var out := PackedStringArray()
	for s in DisplayApply.UI_SCALES:
		out.append("%d%%" % roundi(s * 100.0))
	return out


func _pick_size(index: int) -> void:
	Settings.set_ui_scale(DisplayApply.UI_SCALES[index])
