extends RefCounted

static func load_game(path: String) -> Dictionary:
	var payload := _read(path)
	if payload.is_empty():
		payload = _read(path + ".bak")
	return payload

static func save_game(path: String, payload: Dictionary) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return write_error

	if not _read(path).is_empty():
		var previous := path + ".bak"
		var backup_error := DirAccess.copy_absolute(path, previous)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			return backup_error

	var commit_error := DirAccess.rename_absolute(temporary, path)
	if commit_error != OK:
		DirAccess.remove_absolute(temporary)
	return commit_error

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var payload: Variant = parser.data
	if payload is Dictionary and payload.get("version") == 1 and payload.get("cars") is Array:
		return payload
	return {}
