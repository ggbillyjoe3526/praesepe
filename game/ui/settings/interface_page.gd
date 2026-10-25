class_name InterfacePage
extends SettingsPage
## Settings › Interface: what the HUD shows and how big. The interface size: the HUD, its text and the menus
## together, for big or high-resolution screens (William, 2026-10-25). Takes effect at once (DisplayApply). And when
## the places' markers show their diamonds and their names (LandmarkMarkers.Show; William, 2026-10-25).

## The choices for the place markers and names, in LandmarkMarkers.Show's order.
const SHOW_NAMES: PackedStringArray = ["Always", "Near or looked at", "Off"]

var size_choice: OptionButton
var marker_icons_choice: OptionButton
var marker_names_choice: OptionButton


func _init() -> void:
	title = "Interface"
	keys = PackedStringArray(["ui_scale", "marker_icons", "marker_names"])


func build() -> void:
	add_heading("Size")
	size_choice = add_choice("Interface size", InterfacePage.size_names(), _pick_size)
	add_hint("Makes the HUD, its text and the menus bigger or smaller. 100% already grows with the screen; go up for a "
			+ "big screen you sit far from.")
	add_heading("Places")
	marker_icons_choice = add_choice("Place markers", SHOW_NAMES, Settings.set_marker_icons)
	marker_names_choice = add_choice("Place names", SHOW_NAMES, Settings.set_marker_names)
	add_hint("Near or looked at shows a place when you're close to it, looking toward it, aiming at it or cruising to "
			+ "it.")


func sync() -> void:
	size_choice.select(DisplayApply.UI_SCALES.find(Settings.ui_scale))
	marker_icons_choice.select(Settings.marker_icons)
	marker_names_choice.select(Settings.marker_names)


static func size_names() -> PackedStringArray:
	var out := PackedStringArray()
	for s in DisplayApply.UI_SCALES:
		out.append("%d%%" % roundi(s * 100.0))
	return out


func _pick_size(index: int) -> void:
	Settings.set_ui_scale(DisplayApply.UI_SCALES[index])
