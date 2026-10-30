extends SceneTree

const EntryScene = preload("res://scenes/GameEntry.tscn")
const LegacyScene = preload("res://scenes/legacy/LegacyTextMine.tscn")
const OUT_DIR = "res://docs/screenshots/release-002/"
const TMP_DIR = "user://release002_capture/"

var vp: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	vp = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var legacy = LegacyScene.instantiate()
	legacy.save_path = TMP_DIR + "legacy_save.json"
	legacy.events_path = TMP_DIR + "legacy_events.jsonl"
	await _shot(legacy, "release-002-before.png")
	var entry = EntryScene.instantiate()
	entry.save_path = TMP_DIR + "absent_progress.json"
	await _shot(entry, "release-002-after.png")
	var file := FileAccess.open(TMP_DIR + "progress.json", FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	entry = EntryScene.instantiate()
	entry.save_path = TMP_DIR + "progress.json"
	await _shot(entry, "release-002-after-continue.png")
	for name in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR + name)
	DirAccess.remove_absolute(TMP_DIR)
	quit(0)

func _shot(node: Node, file_name: String) -> void:
	vp.add_child(node)
	for _n in range(8):
		await process_frame
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + file_name)
	print("SAVED ", path, " ", img.get_size(), " ", img.save_png(path))
	node.queue_free()
	await process_frame
