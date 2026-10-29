extends SceneTree

const PrototypeScene = preload("res://scenes/MinePrototype.tscn")
const OUT_DIR = "res://docs/screenshots/prototype/"

var vp: SubViewport
var scene: Node2D

func _initialize() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = PrototypeScene.instantiate()
	vp.add_child(scene)
	await _frames(5)
	scene.input_enabled = false
	await _go(Vector2i.RIGHT, 2)
	await _go(Vector2i.DOWN, 3)
	await _go(Vector2i.RIGHT, 3)
	await _go(Vector2i.DOWN, 2)
	await _go(Vector2i.LEFT, 5)
	await _go(Vector2i.UP, 2)
	await _go(Vector2i.RIGHT, 1)
	await _go(Vector2i.UP, 3)
	await _go(Vector2i.LEFT, 1)
	await _strike()
	_save("prototype_full_720x1280.png")
	scene.camera.zoom = Vector2(2, 2)
	scene.hud.visible = false
	await _frames(30)
	await _strike()
	_save("prototype_closeup.png")
	scene.camera.zoom = Vector2(1, 1)
	scene.hud.visible = true
	while scene.model.player.y > scene.model.station_y:
		await _go(Vector2i.UP, 1)
	while scene.model.player.x > scene.model.shaft_x:
		await _go(Vector2i.LEFT, 1)
	await _frames(150)
	_save("prototype_surface_return.png")
	_save_atlas()
	quit(0)

func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _idle() -> void:
	for _i in range(240):
		if scene.busy <= 0.0 and not scene.animating:
			return
		await process_frame

func _go(dir: Vector2i, cells: int) -> void:
	for _c in range(cells):
		for _attempt in range(12):
			await _idle()
			var r: Dictionary = scene.apply_step(dir)
			if r["action"] != "hit" and r["action"] != "break":
				break
	await _idle()
	await _frames(20)

func _strike() -> void:
	await _idle()
	var dir := Vector2i.ZERO
	for min_hp in [2, 1]:
		for d in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP]:
			var pos: Vector2i = scene.model.player + d
			if dir == Vector2i.ZERO and scene.model.is_material(scene.model.cell_at(pos)) and scene.model.hp_at(pos) >= min_hp:
				dir = d
	if dir != Vector2i.ZERO:
		print("STRIKE ", scene.apply_step(dir))
	await _frames(5)

func _save(file_name: String) -> void:
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + file_name)
	print("SAVED ", path, " ", img.get_size(), " ", img.save_png(path))

func _save_atlas() -> void:
	var art = scene.art
	var tiles: Array = []
	for name in ["dirt", "stone", "coal", "copper", "gold", "bedrock", "wall"]:
		for tex in art.textures[name]:
			tiles.append(tex)
	for key in ["shaft", "cage", "boulder_1", "boulder_2", "boulder_3"]:
		tiles.append(art.textures[key])
	for anim in ["idle", "walk", "dig", "stun"]:
		for tex in art.miner_frames[anim]:
			tiles.append(tex)
	var cols := 8
	var rows := int(ceil(tiles.size() / float(cols)))
	var sheet := Image.create(cols * 72, rows * 72, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#15110f"))
	for i in range(tiles.size()):
		var img: Image = tiles[i].get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * 72 + 4, (i / cols) * 72 + 4))
	var path := ProjectSettings.globalize_path(OUT_DIR + "prototype_art_sheet.png")
	print("SAVED ", path, " ", sheet.save_png(path))
