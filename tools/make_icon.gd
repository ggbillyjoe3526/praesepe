extends SceneTree
## Writes build/release/icon.ico from icon.svg: the icon of the game's exe, the setup wizard and the Start menu and
## desktop shortcuts. The release workflow runs it before exporting (RELEASING.md), so the icon always follows
## icon.svg and no binary is committed. Run it by hand with:
##   godot --headless --path . -s res://tools/make_icon.gd
## Each size is drawn from the SVG itself, so small sizes stay sharp. Sizes below 256 are stored as plain bitmaps and
## 256 as PNG, the form every Windows version and Inno Setup read.

const SRC := "res://icon.svg"
const OUT := "res://build/release/icon.ico"
const SIZES: Array[int] = [16, 24, 32, 48, 64, 128, 256]
## Sizes from this one up are stored as PNG.
const PNG_FROM := 256


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string(SRC)
	if svg.is_empty():
		_fail("can't read %s" % SRC)
		return
	var probe := Image.new()
	if probe.load_svg_from_string(svg) != OK:
		_fail("can't draw %s" % SRC)
		return
	var images: Array[PackedByteArray] = []
	for size: int in SIZES:
		var image := Image.new()
		image.load_svg_from_string(svg, float(size) / float(probe.get_width()))
		if image.get_width() != size or image.get_height() != size:
			image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		images.append(image.save_png_to_buffer() if size >= PNG_FROM else _bitmap(image))
	var ico := _ico(images)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		_fail("can't write %s" % OUT)
		return
	f.store_buffer(ico)
	f.close()
	print("make_icon: wrote %s (%d sizes, %d bytes)" % [OUT, SIZES.size(), ico.size()])
	quit(0)


## The icon file: a header, one 16-byte entry per size, then each image.
func _ico(images: Array[PackedByteArray]) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(6 + 16 * images.size())
	out.encode_u16(0, 0)
	out.encode_u16(2, 1)
	out.encode_u16(4, images.size())
	var offset := out.size()
	for i in images.size():
		var at := 6 + 16 * i
		var size := SIZES[i]
		out.encode_u8(at, size % 256)
		out.encode_u8(at + 1, size % 256)
		out.encode_u8(at + 2, 0)
		out.encode_u8(at + 3, 0)
		out.encode_u16(at + 4, 1)
		out.encode_u16(at + 6, 32)
		out.encode_u32(at + 8, images[i].size())
		out.encode_u32(at + 12, offset)
		offset += images[i].size()
	for data: PackedByteArray in images:
		out.append_array(data)
	return out


## One size as an icon bitmap: a 40-byte header (height doubled, as icons want), the colour rows bottom-up in BGRA,
## then an all-clear 1-bit mask (the alpha channel already says what is see-through).
func _bitmap(image: Image) -> PackedByteArray:
	var w := image.get_width()
	var h := image.get_height()
	var mask_row := ((w + 31) / 32) * 4
	var out := PackedByteArray()
	out.resize(40 + w * h * 4 + mask_row * h)
	out.encode_u32(0, 40)
	out.encode_s32(4, w)
	out.encode_s32(8, h * 2)
	out.encode_u16(12, 1)
	out.encode_u16(14, 32)
	out.encode_u32(16, 0)
	out.encode_u32(20, w * h * 4 + mask_row * h)
	var at := 40
	for y in range(h - 1, -1, -1):
		for x in w:
			var c := image.get_pixel(x, y)
			out.encode_u8(at, c.b8)
			out.encode_u8(at + 1, c.g8)
			out.encode_u8(at + 2, c.r8)
			out.encode_u8(at + 3, c.a8)
			at += 4
	return out


func _fail(message: String) -> void:
	push_error("make_icon: %s" % message)
	quit(1)
