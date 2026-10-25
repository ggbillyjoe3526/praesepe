class_name ComfortPage
extends SettingsPage
## Settings › Comfort (project instructions, "Comfort"): field of view, camera shake, head bob and reduce motion. Each
## takes effect at once, so the paused picture behind the menu shows the new field of view. Reduce motion greys out the
## shake and head bob it turns off.

var fov_slider: HSlider
var shake_slider: HSlider
var head_bob_check: CheckButton
var reduce_motion_check: CheckButton


func _init() -> void:
	title = "Comfort"
	keys = PackedStringArray(["fov", "shake", "head_bob", "reduce_motion"])


func build() -> void:
	add_heading("View")
	fov_slider = add_slider("Field of view", Settings.FOV_MIN, Settings.FOV_MAX, 1.0, Settings.set_fov)
	add_hint("Wider shows more round you, but stretches round things near the edges of the screen.")
	add_heading("Motion")
	shake_slider = add_slider("Camera shake", 0.0, 1.0, Settings.SHAKE_STEP, Settings.set_shake)
	head_bob_check = add_toggle("Head bob: your head sways as the ship pushes", Settings.set_head_bob)
	reduce_motion_check = add_toggle("Reduce motion", Settings.set_reduce_motion)
	add_hint("Reduce motion turns off shake and head bob, and steadies the chase camera.")


func sync() -> void:
	var calm := Settings.reduce_motion
	fov_slider.set_value_no_signal(Settings.fov)
	SettingsPage.value_label(fov_slider).text = "%d°" % roundi(Settings.fov)
	shake_slider.set_value_no_signal(Settings.shake)
	shake_slider.editable = not calm
	var shake_value := SettingsPage.value_label(shake_slider)
	shake_value.text = "off (reduce motion)" if calm else "%d%%" % roundi(Settings.shake * 100.0)
	SettingsPage.grey(shake_value, calm)
	head_bob_check.set_pressed_no_signal(Settings.head_bob)
	head_bob_check.disabled = calm
	reduce_motion_check.set_pressed_no_signal(calm)
