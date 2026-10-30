extends SceneTree

const PrototypeScene = preload("res://scenes/MinePrototype.tscn")
const OUT_DIR = "res://docs/screenshots/dm-124/"
const SAVE = "user://dm124_capture_progress.json"

var vp: SubViewport
var scene: Node2D

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	vp = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = PrototypeScene.instantiate()
	scene.save_path = SAVE
	vp.add_child(scene)
	await _frames(8)
	scene.input_enabled = false
	var m = scene.model
	m.backpack = {"copper": 2, "gold": 1}
	await _frames(20)
	_save("dm124_01_loaded_miner_slower.png")
	scene.apply_step(Vector2i.LEFT)
	scene._process(0.8)
	scene._process(10.0)
	await _frames(20)
	_save("dm124_02_ascending_progress.png")
	scene._process(19.4)
	await _frames(10)
	_save("dm124_03_unloading.png")
	scene._process(2.0)
	await _frames(10)
	_save("dm124_04_surface_panel.png")
	scene._descend()
	scene._process(8.5)
	await _frames(30)
	m.round_time = 262.0
	await _frames(20)
	_save("dm124_05_warning_under_30s.png")
	scene.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)

func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _save(file_name: String) -> void:
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + file_name)
	print("SAVED ", path, " ", img.get_size(), " ", img.save_png(path))
