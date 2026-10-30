extends SceneTree

const PrototypeScene = preload("res://scenes/MinePrototype.tscn")
const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const OUT_DIR = "res://docs/screenshots/dm-121/"
const SAVE = "user://dm121_capture_progress.json"

var vp: SubViewport
var scene: Node2D

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	vp = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	await _open()
	_save("dm121_01_start_hud_0of3.png")
	var ore := _nearest_ore()
	print("NEAREST ORE ", ore, " ", MineModel.MATERIAL_NAMES[scene.model.cell_at(ore)])
	await _walk_towards(ore, 2)
	_save("dm121_02_search_hints.png")
	await _walk_towards(ore, 1)
	var dir: Vector2i = ore - scene.model.player
	for _n in range(3):
		await _idle()
		scene.apply_step(dir)
	await _frames(6)
	_save("dm121_03_dig_progress.png")
	await _go(dir, 1)
	await _frames(30)
	_save("dm121_04_first_ore.png")
	scene.model.backpack = {"coal": 2, "copper": 1}
	var below: Vector2i = scene.model.player + Vector2i.DOWN
	if scene.model.cell_at(below) == MineModel.BEDROCK:
		below = scene.model.player + Vector2i.UP
	scene.model._set_cell(below.x, below.y, MineModel.GOLD)
	scene.world.refresh()
	await _dig_out(below - scene.model.player)
	await _frames(20)
	_save("dm121_05_full_pack_loot_on_ground.png")
	await _close()
	await _open()
	await _go(Vector2i.RIGHT, 5)
	scene.model.backpack = {"coal": 1, "copper": 1, "gold": 1}
	await _idle()
	scene.apply_step(Vector2i.UP)
	await _frames(50)
	_save("dm121_06_stun_countdown_dropped_loot.png")
	await _close()
	await _open()
	scene.hud.visible = false
	scene.camera.zoom = Vector2(0.38, 0.38)
	scene.camera.limit_top = -200
	for child in scene.get_children():
		if child is CanvasModulate:
			child.color = Color(0.8, 0.8, 0.85)
	scene.player_root.position = scene._cell_center(Vector2i(24, 22))
	await _frames(40)
	_save("dm121_07_sparse_veins_overview_lit.png")
	await _close()
	await _open()
	scene.model.backpack = {"copper": 2, "gold": 1}
	await _go(Vector2i.LEFT, 1)
	await _frames(150)
	_save("dm121_08_surface_upgrades.png")
	scene.buy_upgrade("pick")
	await _frames(10)
	_save("dm121_09_surface_after_pick_upgrade.png")
	await _close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)

func _open() -> void:
	scene = PrototypeScene.instantiate()
	scene.save_path = SAVE
	vp.add_child(scene)
	await _frames(8)
	scene.input_enabled = false

func _close() -> void:
	scene.queue_free()
	await _frames(2)

func _nearest_ore() -> Vector2i:
	var m = scene.model
	var best := Vector2i(-1, -1)
	var best_d := 9999
	for y in range(m.station_y, m.height):
		for x in range(m.shaft_x + 2, m.width - 1):
			var p := Vector2i(x, y)
			var d := absi(p.x - m.player.x) + absi(p.y - m.player.y)
			if MineModel.is_ore(m.cell_at(p)) and d < best_d and m.boulder_at(p + Vector2i.UP) < 0:
				best = p
				best_d = d
	return best

func _walk_towards(target: Vector2i, stop_at: int) -> void:
	for _guard in range(60):
		var m = scene.model
		var delta: Vector2i = target - m.player
		if absi(delta.x) + absi(delta.y) <= stop_at:
			return
		var dir := Vector2i(signi(delta.x), 0) if delta.x != 0 else Vector2i(0, signi(delta.y))
		await _go(dir, 1)

func _dig_out(dir: Vector2i) -> void:
	for _attempt in range(30):
		await _idle()
		if scene.apply_step(dir)["action"] != "hit":
			return

func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _idle() -> void:
	for _i in range(400):
		if scene.busy <= 0.0 and not scene.animating and scene.model.stun_left <= 0.0:
			return
		await process_frame

func _go(dir: Vector2i, cells: int) -> void:
	for _c in range(cells):
		for _attempt in range(30):
			await _idle()
			var r: Dictionary = scene.apply_step(dir)
			if r["action"] != "hit" and r["action"] != "break":
				break
	await _idle()
	await _frames(20)

func _save(file_name: String) -> void:
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + file_name)
	print("SAVED ", path, " ", img.get_size(), " ", img.save_png(path))
