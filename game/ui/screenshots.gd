class_name Screenshots
extends CanvasLayer
## The screenshot key (F12): saves the picture on the screen, exactly as the player sees it (HUD, messages and pause
## screen included), as a PNG in the `screenshots` folder in the user folder, then says where for a few seconds. Works
## while paused too. The picture is read back once the frame is drawn and written to disk on a worker thread, so
## taking one never holds up flight; its own note is hidden first, so it is never in the picture. If no frame is drawn
## within DRAW_WAIT_FRAMES (a headless run, a window that isn't drawing) it gives up and says so. The file's name is
## the date and time it was taken (for naming only: nothing in the game runs on the real clock).

const LAYER := 60
const FOLDER := "user://screenshots"
## How long (s) the note saying where the picture went stays up.
const NOTE_TIME := 4.0
## Frames to wait for the picture to be drawn before giving up (a window that isn't drawing, as when minimised).
const DRAW_WAIT_FRAMES := 30
const PLATE_COLOUR := Color(0.03, 0.04, 0.08, 0.92)
const SAVED_COLOUR := Color(0.55, 0.95, 0.75)
const FAILED_COLOUR := Color(1.0, 0.72, 0.3)
## Sizes in px at 1080p.
const TEXT_SIZE := 20
const MARGIN := 24.0
const PAD := Vector2(18.0, 8.0)
const CORNER := 6

## Where pictures go.
var folder: String = FOLDER
## The file the last picture went to, once written (empty until then, or if it failed).
var last_path: String = ""

var _plate: PanelContainer
var _note: Label
var _note_left: float = 0.0
## Between the key and the note: waiting for the frame, or for the worker to write it.
var _taking: bool = false
var _path: String = ""
var _task: int = -1
var _written: Error = OK
## Frames left to wait for the frame to be drawn, while waiting.
var _draw_wait: int = 0


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_grab):
		RenderingServer.frame_post_draw.disconnect(_grab)
	# Never leave a picture half written.
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"screenshot"):
		get_viewport().set_input_as_handled()
		take()


## Takes a picture of the next frame drawn. Does nothing while the last one is still being taken.
func take() -> void:
	if _taking:
		return
	_taking = true
	_plate.visible = false
	_note_left = 0.0
	_draw_wait = DRAW_WAIT_FRAMES
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)


## Whether a picture is being taken or written.
func busy() -> bool:
	return _taking


## The note on screen now, or empty when none is up (for the tests).
func note_text() -> String:
	return _note.text if _plate.visible else ""


## The file name for a picture taken at `when` (Time.get_datetime_dict_from_system()), with `count` added after the
## time when it is above 1 (a second picture in the same second).
static func file_name(when: Dictionary, count: int = 1) -> String:
	var words := "praesepe_%04d-%02d-%02d_%02d-%02d-%02d" % [when.year, when.month, when.day, when.hour, when.minute,
			when.second]
	return (words + "_%d.png" % count) if count > 1 else words + ".png"


## The first file in `in_folder` for a picture taken at `when` that doesn't exist yet.
static func free_path(in_folder: String, when: Dictionary) -> String:
	var count := 1
	var path := in_folder.path_join(Screenshots.file_name(when))
	while FileAccess.file_exists(path):
		count += 1
		path = in_folder.path_join(Screenshots.file_name(when, count))
	return path


## The note once a picture is written to `path` (`ok`), or couldn't be.
static func note_for(path: String, ok: bool) -> String:
	if ok:
		return "Screenshot saved  ·  %s" % ProjectSettings.globalize_path(path)
	return "Couldn't save the screenshot. Check the user folder can be written to and has room"


func _grab() -> void:
	_draw_wait = 0
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_finish(false)
		return
	_path = Screenshots.free_path(folder, Time.get_datetime_dict_from_system())
	_task = WorkerThreadPool.add_task(_write.bind(image, _path, folder), false, "Screenshot")


## On the worker thread: makes the folder if need be and writes the picture.
func _write(image: Image, path: String, in_folder: String) -> void:
	var made := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(in_folder))
	_written = image.save_png(path) if made == OK else made


func _process(delta: float) -> void:
	if _draw_wait > 0:
		_draw_wait -= 1
		if _draw_wait == 0 and RenderingServer.frame_post_draw.is_connected(_grab):
			# Nothing was drawn: give up rather than leave the key dead.
			RenderingServer.frame_post_draw.disconnect(_grab)
			_finish(false)
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish(_written == OK)
	if _note_left > 0.0:
		_note_left -= delta
		_plate.visible = _note_left > 0.0


func _finish(ok: bool) -> void:
	_taking = false
	last_path = _path if ok else ""
	_note.text = Screenshots.note_for(_path, ok)
	_note.add_theme_color_override("font_color", SAVED_COLOUR if ok else FAILED_COLOUR)
	_note_left = NOTE_TIME
	_plate.visible = true


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE_COLOUR
	style.set_corner_radius_all(CORNER)
	style.content_margin_left = PAD.x
	style.content_margin_right = PAD.x
	style.content_margin_top = PAD.y
	style.content_margin_bottom = PAD.y
	_plate = PanelContainer.new()
	_plate.name = "NotePlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override(&"panel", style)
	_plate.anchor_top = 1.0
	_plate.anchor_bottom = 1.0
	_plate.offset_left = MARGIN
	_plate.offset_top = -MARGIN
	_plate.offset_bottom = -MARGIN
	_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_plate.visible = false
	_note = Label.new()
	_note.add_theme_font_size_override(&"font_size", TEXT_SIZE)
	_plate.add_child(_note)
	add_child(_plate)
