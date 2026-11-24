@tool
extends EditorPlugin

const IMAGE_IMPORT_SUFFIXES: Array[String] = [
	".png.import",
	".jpg.import",
	".jpeg.import",
	".webp.import",
	".bmp.import",
	".tga.import",
	".svg.import",
]
const SKIP_DIRECTORIES: Array[String] = [
	".git",
	".godot",
	"build",
	".venv",
	"node_modules",
]

var _policy_running: bool = false


func _enter_tree() -> void:
	call_deferred("_apply_quality_policy")


func _apply_quality_policy() -> void:
	if _policy_running:
		return
	_policy_running = true

	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while filesystem.is_scanning() or filesystem.is_importing():
		await get_tree().process_frame

	var changed_sources: PackedStringArray = PackedStringArray()
	var scanned_count: int = _scan_directory("res://", changed_sources)
	if not changed_sources.is_empty():
		print(
			"QUALITY_FIRST_IMPORTS: reimporting %d of %d images as Lossless."
			% [changed_sources.size(), scanned_count]
		)
		filesystem.reimport_files(changed_sources)
		print("QUALITY_FIRST_IMPORTS: Lossless import pass completed.")
	else:
		print(
			"QUALITY_FIRST_IMPORTS: all %d image imports already use Lossless settings."
			% scanned_count
		)

	_policy_running = false


func _scan_directory(folder_path: String, changed_sources: PackedStringArray) -> int:
	var directory: DirAccess = DirAccess.open(folder_path)
	if directory == null:
		return 0

	var scanned_count: int = 0
	for file_name: String in directory.get_files():
		var lower_name: String = file_name.to_lower()
		var is_image_import: bool = false
		for suffix: String in IMAGE_IMPORT_SUFFIXES:
			if lower_name.ends_with(suffix):
				is_image_import = true
				break
		if not is_image_import:
			continue

		var import_path: String = folder_path.path_join(file_name)
		var source_path: String = import_path.trim_suffix(".import")
		if not FileAccess.file_exists(source_path):
			continue
		var content: String = FileAccess.get_file_as_string(import_path)
		var has_texture_importer: bool = content.contains('importer="texture"')
		var has_compressed_texture_type: bool = content.contains('type="CompressedTexture2D"')
		if not has_texture_importer or not has_compressed_texture_type:
			continue

		scanned_count += 1
		var lines: PackedStringArray = content.split("\n")
		var changed: bool = false
		changed = _set_setting(lines, "compress/mode", "0") or changed
		changed = _set_setting(lines, "detect_3d/compress_to", "0") or changed
		changed = _set_setting(lines, "process/size_limit", "0") or changed
		if not changed:
			continue

		var output: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
		if output == null:
			push_error("Could not update image import settings: %s" % import_path)
			continue
		output.store_string("\n".join(lines))
		output.flush()
		output.close()
		changed_sources.append(source_path)

	for subdirectory: String in directory.get_directories():
		if SKIP_DIRECTORIES.has(subdirectory):
			continue
		scanned_count += _scan_directory(
			folder_path.path_join(subdirectory),
			changed_sources
		)
	return scanned_count


func _set_setting(lines: PackedStringArray, key: String, value: String) -> bool:
	var prefix: String = key + "="
	var expected: String = prefix + value
	for index: int in range(lines.size()):
		if lines[index].begins_with(prefix):
			if lines[index] == expected:
				return false
			lines[index] = expected
			return true

	var params_index: int = lines.find("[params]")
	if params_index < 0:
		push_error("Image import sidecar has no [params] section for %s." % key)
		return false
	lines.insert(params_index + 1, expected)
	return true
