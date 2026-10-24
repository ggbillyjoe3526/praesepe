class_name SaveFile
## Crash-safe JSON files, from the owner's katanashotgun project (scripts/save/save_file.gd). A file is one header line,
## "PSAVE <kind> <version> <sha256 of the payload>", then the JSON payload.
## Writes go to <path>.tmp first and are read back and checked before the old
## file is rotated to <path>.bak, so a crash or a full disk at any point leaves
## at least one good copy. Loading tries .tmp (a finished write that never got
## renamed), then the file, then the backup; a copy whose checksum fails is
## skipped, never trusted. A copy that exists but can't be opened (another
## program holds it, or no permission) may be fine, so it is never treated as
## damaged: read() reports it as locked and write() won't replace it.

const MAGIC := "PSAVE"
const TMP := ".tmp"
const BAK := ".bak"
const BAK_OLD := ".bak.old" # the previous backup, only while it is rotated


static func encode(kind: String, version: int, data: Dictionary) -> String:
	var payload := JSON.stringify(data, "  ")
	return "%s %s %d %s\n%s" % [MAGIC, kind, version, payload.sha256_text(), payload]


## Parses one file's text. Returns {ok, version, data} or {ok: false, error}.
static func decode(text: String, kind: String) -> Dictionary:
	var nl := text.find("\n")
	if nl < 0:
		return {"ok": false, "error": "no header"}
	var head := text.substr(0, nl).split(" ")
	var payload := text.substr(nl + 1)
	if head.size() != 4 or head[0] != MAGIC:
		return {"ok": false, "error": "not a save file"}
	if head[1] != kind:
		return {"ok": false, "error": "wrong kind %s" % head[1]}
	if not head[2].is_valid_int():
		return {"ok": false, "error": "bad version"}
	if payload.sha256_text() != head[3]:
		return {"ok": false, "error": "checksum mismatch"}
	var data: Variant = JSON.parse_string(payload)
	if not data is Dictionary:
		return {"ok": false, "error": "payload is not an object"}
	return {"ok": true, "version": int(head[2]), "data": data}


## The file's text, or "" when it is missing or can't be opened.
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## True when the file exists but can't be opened, so its contents are unknown.
static func is_locked(path: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.open(path, FileAccess.READ) == null


## Writes atomically and keeps one backup. Returns false (and leaves the old
## file and backup untouched) if the new copy could not be written and
## verified, the old file can't be opened, or the backup can't be rotated.
static func write(path: String, kind: String, version: int, data: Dictionary) -> bool:
	if is_locked(path):
		push_warning("save: can't open %s, so it is not replaced" % path)
		return false
	var text := encode(kind, version, data)
	var tmp := path + TMP
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: can't open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	# read it back: a full disk can leave a short file without reporting it
	if err != OK or read_text(tmp) != text:
		push_warning("save: %s did not write cleanly" % tmp)
		DirAccess.remove_absolute(tmp)
		return false
	# from here on, a failed step keeps the verified .tmp, which read() finds
	if FileAccess.file_exists(path):
		if decode(read_text(path), kind).ok:
			# the current file is good: it becomes the backup
			if not _rotate(path):
				push_warning("save: can't rotate %s to its backup" % path)
				return false
		elif DirAccess.rename_absolute(path, "%s.corrupt-%s" % [path, _stamp()]) != OK:
			# a damaged file never replaces a good backup, and is moved aside,
			# never deleted
			push_warning("save: can't move damaged %s aside" % path)
			return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		# the verified .tmp stays on disk and read() still finds it
		push_warning("save: can't rename %s" % tmp)
		return false
	return true


## Turns the file into the backup. The old backup is set aside first and only
## dropped once that worked; if it didn't, the old backup is put back.
static func _rotate(path: String) -> bool:
	var had_bak := FileAccess.file_exists(path + BAK)
	if had_bak and DirAccess.rename_absolute(path + BAK, path + BAK_OLD) != OK:
		return false
	if DirAccess.rename_absolute(path, path + BAK) != OK:
		if had_bak:
			DirAccess.rename_absolute(path + BAK_OLD, path + BAK)
		return false
	if had_bak:
		DirAccess.remove_absolute(path + BAK_OLD)
	return true


## Loads the newest good copy. Returns {ok, version, data, source, file}
## where source is "tmp", "main" or "backup" and file is that copy's path, or
## {ok: false, found, locked} when no copy is good (found says whether any
## file existed at all). locked means a copy newer than any good one exists
## but can't be opened: it may be fine, so the caller must not write over it.
static func read(path: String, kind: String) -> Dictionary:
	var found := false
	# the old backup set aside mid-rotation, if a crash came before it was dropped
	for c: Array in [[path + TMP, "tmp"], [path, "main"], [path + BAK, "backup"], [path + BAK_OLD, "backup"]]:
		var text := read_text(c[0])
		if text == "":
			if is_locked(c[0]):
				push_warning("save: can't open %s" % c[0])
				return {"ok": false, "found": true, "locked": true}
			found = found or FileAccess.file_exists(c[0])
			continue
		found = true
		var r := decode(text, kind)
		if r.ok:
			r["source"] = c[1]
			r["file"] = c[0]
			return r
		push_warning("save: skipping %s (%s)" % [c[0], r.error])
	return {"ok": false, "found": found, "locked": false}


## Moves every copy aside as <path>.corrupt-<n> so a fresh file can be written
## without destroying anything a player might want recovered.
static func quarantine(path: String) -> void:
	var stamp := _stamp()
	for suffix: String in ["", TMP, BAK, BAK_OLD]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.rename_absolute(path + suffix, "%s%s.corrupt-%s" % [path, suffix, stamp])


static func remove(path: String) -> void:
	for suffix: String in ["", TMP, BAK, BAK_OLD]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


## A file-name stamp for moved-aside copies.
static func _stamp() -> String:
	return str(Time.get_unix_time_from_system()).replace(".", "")
