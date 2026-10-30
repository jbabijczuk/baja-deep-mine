extends Node2D

const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const MineArt = preload("res://scripts/mine_prototype/mine_art.gd")
const MineWorld = preload("res://scripts/mine_prototype/mine_world.gd")
const SurfaceBackdrop = preload("res://scripts/mine_prototype/surface_backdrop.gd")
const CELL = 64
const MAIN_SCENE = "res://scenes/Main.tscn"
const KEYS = {KEY_W: Vector2i.UP, KEY_UP: Vector2i.UP, KEY_S: Vector2i.DOWN, KEY_DOWN: Vector2i.DOWN, KEY_A: Vector2i.LEFT, KEY_LEFT: Vector2i.LEFT, KEY_D: Vector2i.RIGHT, KEY_RIGHT: Vector2i.RIGHT}
const MATERIAL_COLORS = {"dirt": Color("#94704f"), "stone": Color("#7f8996"), "coal": Color("#4a4b52"), "copper": Color("#d4733a"), "gold": Color("#e8b52e")}
const DARKNESS = Color(0.11, 0.12, 0.2)

var model
var art
var world: Node2D
var backdrop: Node2D
var camera: Camera2D
var player_root: Node2D
var player_sprite: AnimatedSprite2D
var miner_light: PointLight2D
var stars: Array = []
var cage: Sprite2D
var boulder_sprites: Dictionary = {}
var lamp_lights: Array = []
var overlay: CanvasLayer
var hp_bar: Node2D
var hp_fill: ColorRect
var hud: Control
var timer_label: Label
var timer_caption: Label
var pack_label: Label
var slot_row: HBoxContainer
var slot_icons: Array = []
var stun_label: Label
var banked_label: Label
var toast: Label
var toast_panel: PanelContainer
var surface_panel: PanelContainer
var surface_title: Label
var surface_info: Label
var descend_button: Button
var upgrade_buttons: Dictionary = {}
var save_path: String = MineModel.SAVE_PATH
var fade: ColorRect
var touch_dir := Vector2i.ZERO
var busy: float = 0.0
var animating: bool = false
var fall_timer: float = 0.0
var shake: float = 0.0
var toast_time: float = 0.0
var clock: float = 0.0
var last_trip_value: int = 0
var input_enabled: bool = true
var mine_controls: Array = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	model = MineModel.new()
	model.generate(int(model.config["seed"]))
	model.load_progress(save_path)
	art = MineArt.new()
	art.build()
	_build_backdrop()
	_build_world()
	_build_lights()
	_build_player()
	_build_overlay()
	_build_hud()
	_rebuild_boulders()
	_place_at_station()
	camera.global_position = _camera_target()
	camera.reset_smoothing()
	_update_hud()

func _cell_center(pos: Vector2i) -> Vector2:
	return Vector2(pos * CELL) + Vector2(CELL, CELL) * 0.5

func _surface_point() -> Vector2:
	return Vector2(model.shaft_x * CELL + CELL * 0.5, -CELL * 1.6)

func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.follow_viewport_enabled = true
	add_child(layer)
	backdrop = SurfaceBackdrop.new()
	layer.add_child(backdrop)
	backdrop.setup(model.width, model.shaft_x)

func _build_world() -> void:
	var modulate_node := CanvasModulate.new()
	modulate_node.color = DARKNESS
	add_child(modulate_node)
	world = MineWorld.new()
	add_child(world)
	world.setup(model, art)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_right = model.width * CELL
	camera.limit_top = -900
	camera.limit_bottom = model.height * CELL + 260
	add_child(camera)
	cage = Sprite2D.new()
	cage.texture = art.textures["cage"]
	cage.scale = Vector2(2, 2)
	cage.z_index = 3
	add_child(cage)

func _light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

func _light(pos: Vector2, radius_cells: float, color: Color, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.texture_scale = radius_cells * CELL / 128.0
	light.color = color
	light.energy = energy
	light.position = pos
	return light

func _build_lights() -> void:
	add_child(_light(_cell_center(model.elevator_cell()) + Vector2(CELL * 1.5, 0), 9.0, Color("#ffb36b"), 0.55))
	add_child(_light(Vector2(model.shaft_x * CELL + CELL * 0.5, -CELL * 1.5), 6.0, Color("#9fb7ff"), 0.85))
	for lamp_pos in model.lamps:
		var center := Vector2(lamp_pos * CELL) + Vector2(CELL * 0.5, 14)
		var sprite := Sprite2D.new()
		sprite.texture = art.textures["lamp"]
		sprite.scale = Vector2(2, 2)
		sprite.position = center
		sprite.z_index = 4
		add_child(sprite)
		var glow := Sprite2D.new()
		glow.texture = art.textures["glow"]
		glow.scale = Vector2(3.2, 3.2)
		glow.modulate = Color(1.0, 0.7, 0.35, 0.55)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		glow.material = mat
		glow.position = center + Vector2(0, 4)
		glow.z_index = 5
		add_child(glow)
		var light := _light(center + Vector2(0, 6), 3.6, Color("#ff9a45"), 1.25)
		add_child(light)
		lamp_lights.append({"light": light, "glow": glow, "base": 1.25})

func _build_player() -> void:
	player_root = Node2D.new()
	player_root.z_index = 2
	add_child(player_root)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var speeds := {"idle": 2.5, "walk": 10.0, "dig": 16.0, "stun": 1.0}
	for anim in art.miner_frames:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, speeds[anim])
		frames.set_animation_loop(anim, anim != "dig")
		for tex in art.miner_frames[anim]:
			frames.add_frame(anim, tex)
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = frames
	player_sprite.scale = Vector2(2, 2)
	player_sprite.play("idle")
	player_root.add_child(player_sprite)
	miner_light = _light(Vector2(10, -14), 4.6, Color("#ffd9a0"), 1.35)
	player_root.add_child(miner_light)
	for i in range(3):
		var star := Sprite2D.new()
		star.texture = art.textures["star"]
		star.scale = Vector2(2, 2)
		star.visible = false
		star.z_index = 6
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		star.material = mat
		player_root.add_child(star)
		stars.append(star)

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 1
	overlay.follow_viewport_enabled = true
	add_child(overlay)
	hp_bar = Node2D.new()
	hp_bar.visible = false
	overlay.add_child(hp_bar)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.size = Vector2(52, 10)
	bg.position = Vector2(-26, 0)
	hp_bar.add_child(bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("#ffcf5a")
	hp_fill.size = Vector2(48, 6)
	hp_fill.position = Vector2(-24, 2)
	hp_bar.add_child(hp_fill)
	stun_label = _make_label("", 22, Color("#ffe066"))
	stun_label.visible = false
	overlay.add_child(stun_label)

func _rebuild_boulders() -> void:
	for id in boulder_sprites:
		boulder_sprites[id].queue_free()
	boulder_sprites.clear()
	for id in model.boulders:
		var b: Dictionary = model.boulders[id]
		var sprite := Sprite2D.new()
		sprite.texture = art.textures["boulder_%d" % clampi(int(b["weight"]), 1, 3)]
		sprite.scale = Vector2(2, 2)
		sprite.position = _cell_center(b["pos"])
		sprite.z_index = 1
		add_child(sprite)
		boulder_sprites[id] = sprite

func _place_at_station() -> void:
	player_root.position = _cell_center(model.player)
	cage.position = _cell_center(model.elevator_cell())

func _panel_style(alpha: float = 0.82) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.07, alpha)
	style.border_color = Color("#8a5a2b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_label(text_value: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	return lbl

func _make_button(text_value: String, callback: Callable, size: int = 22) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", size)
	var normal := _panel_style(0.85)
	normal.bg_color = Color("#3a2514")
	normal.border_color = Color("#e0a050")
	var hover := normal.duplicate()
	hover.bg_color = Color("#55361c")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#22160c")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", pressed)
	btn.add_theme_color_override("font_color", Color("#ffe6b8"))
	btn.pressed.connect(callback)
	return btn

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel_style())
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 14
	hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	var time_box := VBoxContainer.new()
	time_box.custom_minimum_size = Vector2(170, 0)
	row.add_child(time_box)
	timer_caption = _make_label("ZAWALENIE ZA", 16, Color("#c9b49a"))
	time_box.add_child(timer_caption)
	timer_label = _make_label("4:40", 54, Color("#ffe6b8"))
	time_box.add_child(timer_label)
	var pack_box := VBoxContainer.new()
	pack_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pack_box)
	pack_label = _make_label("PLECAK 0/3", 18, Color("#c9b49a"))
	pack_box.add_child(pack_label)
	slot_row = HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	pack_box.add_child(slot_row)
	var bank_box := VBoxContainer.new()
	bank_box.custom_minimum_size = Vector2(130, 0)
	row.add_child(bank_box)
	bank_box.add_child(_make_label("SKARBIEC", 16, Color("#c9b49a")))
	banked_label = _make_label("0 zł", 32, Color("#ffd75a"))
	bank_box.add_child(banked_label)
	var tools := HBoxContainer.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tools.offset_left = 14
	tools.offset_right = -14
	tools.offset_top = 156
	tools.offset_bottom = 206
	tools.add_theme_constant_override("separation", 10)
	hud.add_child(tools)
	var base_btn := _make_button("BAZA", Callable(self, "_go_base"), 18)
	tools.add_child(base_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_child(spacer)
	var drop_btn := _make_button("WYRZUĆ TAŃSZY (Q)", Callable(self, "drop_cheapest"), 18)
	tools.add_child(drop_btn)
	mine_controls.append(drop_btn)
	tools.add_child(_make_button("DEBUG: KONIEC RUNDY", Callable(self, "_debug_skip"), 18))
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _panel_style(0.75))
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_panel.offset_top = 222
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.modulate.a = 0.0
	hud.add_child(toast_panel)
	toast = _make_label("", 24, Color("#ffe6b8"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast)
	_build_dpad()
	var hint := _make_label("Szukaj przebarwień w skale — to ślad żyły.\nPełny plecak? Wróć windą i zjedź ponownie.", 18, Color("#c9b49a"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 22
	hint.offset_top = -110
	hint.offset_bottom = -40
	hud.add_child(hint)
	mine_controls.append(hint)
	_build_surface_panel()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

func _build_dpad() -> void:
	var size := 118.0
	var center := Vector2(-200, -200)
	var dirs := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}
	for dir_name in dirs:
		var d: Vector2i = dirs[dir_name]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon = art.textures["arrow_" + dir_name]
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = false
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.07, 0.05, 0.55)
		style.border_color = Color(1, 0.8, 0.5, 0.55)
		style.set_border_width_all(3)
		style.set_corner_radius_all(int(size / 2))
		var down_style := style.duplicate()
		down_style.bg_color = Color(0.9, 0.6, 0.25, 0.6)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", down_style)
		btn.anchor_left = 1.0
		btn.anchor_right = 1.0
		btn.anchor_top = 1.0
		btn.anchor_bottom = 1.0
		var pos := center + Vector2(d) * (size + 6.0) - Vector2(size, size) * 0.5
		btn.offset_left = pos.x
		btn.offset_top = pos.y
		btn.offset_right = pos.x + size
		btn.offset_bottom = pos.y + size
		btn.button_down.connect(func(): touch_dir = d)
		btn.button_up.connect(func():
			if touch_dir == d:
				touch_dir = Vector2i.ZERO)
		hud.add_child(btn)
		mine_controls.append(btn)

func _build_surface_panel() -> void:
	surface_panel = PanelContainer.new()
	surface_panel.add_theme_stylebox_override("panel", _panel_style(0.9))
	surface_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	surface_panel.offset_left = -290
	surface_panel.offset_right = 290
	surface_panel.offset_top = 60
	surface_panel.offset_bottom = 540
	surface_panel.visible = false
	hud.add_child(surface_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	surface_panel.add_child(box)
	surface_title = _make_label("POWIERZCHNIA", 36, Color("#ffd75a"))
	surface_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(surface_title)
	surface_info = _make_label("", 22, Color("#ffe6b8"))
	surface_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surface_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(surface_info)
	descend_button = _make_button("ZJEDŹ WINDĄ W DÓŁ", Callable(self, "_descend"), 24)
	descend_button.custom_minimum_size = Vector2(0, 70)
	box.add_child(descend_button)
	for kind in ["pick", "backpack"]:
		var btn := _make_button("", Callable(self, "buy_upgrade").bind(kind), 20)
		btn.custom_minimum_size = Vector2(0, 56)
		box.add_child(btn)
		upgrade_buttons[kind] = btn
	var base_btn := _make_button("WRÓĆ DO BAZY", Callable(self, "_go_base"), 20)
	base_btn.custom_minimum_size = Vector2(0, 56)
	box.add_child(base_btn)

func _process(delta: float) -> void:
	clock += delta
	for e in model.tick(delta):
		_handle_event(e)
	fall_timer += delta
	var interval := float(model.config["boulders"]["fall_interval"])
	if fall_timer >= interval:
		fall_timer = 0.0
		for e in model.step_boulders():
			_handle_event(e)
	busy = maxf(0.0, busy - delta)
	if not animating and model.state == "mine" and busy <= 0.0:
		var dir := _input_dir()
		if dir != Vector2i.ZERO:
			apply_step(dir)
		elif model.stun_left <= 0.0 and player_sprite.animation != "idle":
			player_sprite.play("idle")
	_update_effects(delta)
	_update_hud()

func _input_dir() -> Vector2i:
	if not input_enabled:
		return Vector2i.ZERO
	if touch_dir != Vector2i.ZERO:
		return touch_dir
	for key in KEYS:
		if Input.is_physical_key_pressed(key):
			return KEYS[key]
	return Vector2i.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		drop_cheapest()

func drop_cheapest() -> Dictionary:
	var result: Dictionary = model.drop_cheapest()
	if result["action"] == "drop":
		world.refresh()
		_float_text(player_root.position, "−1 %s" % model.config["resources"][result["resource"]]["label"], Color("#c9b49a"))
	return result

func buy_upgrade(kind: String) -> Dictionary:
	var result: Dictionary = model.buy(kind)
	if result["ok"]:
		show_toast("Kupiono: %s (−%d zł)" % [model.config["upgrades"][kind][(model.pick_level if kind == "pick" else model.backpack_level) - 1]["label"], result["cost"]])
	elif result["reason"] == "funds":
		show_toast("Za mało złota: potrzeba %d zł" % result["cost"])
	return result

func apply_step(dir: Vector2i) -> Dictionary:
	var result: Dictionary = model.try_step(dir)
	if dir.x != 0:
		player_sprite.flip_h = dir.x < 0
		miner_light.position.x = -10 if dir.x < 0 else 10
	var action: String = result["action"]
	if action == "move":
		_move_player(result["to"], model.move_time())
		busy = model.move_time()
		var picked: Array = result["picked"]
		if not picked.is_empty():
			world.refresh()
			_float_text(_cell_center(result["to"]), "+%d podniesiono" % picked.size(), Color("#ffe6b8"))
		if int(result["left"]) > 0:
			show_toast("Plecak pełny %d/%d — bryłki leżą dalej na ziemi" % [model.backpack_count(), model.slots()])
	elif action == "hit" or action == "break":
		_dig_effect(result, dir)
	elif action == "push":
		var sprite: Sprite2D = boulder_sprites[result["id"]]
		create_tween().tween_property(sprite, "position", _cell_center(result["boulder_to"]), model.move_time() * 1.5)
		sprite.rotation = 0.0
		create_tween().tween_property(sprite, "rotation", sprite.rotation + PI * 0.5 * dir.x, model.move_time() * 1.5)
		_move_player(result["to"], model.move_time() * 1.5)
		busy = model.move_time() * 1.5
		world.refresh()
		_dust(_cell_center(result["boulder_to"]) + Vector2(0, 26), Color("#857a6b"), 8, Vector2(-dir))
	elif action == "too_heavy":
		show_toast("Głaz za ciężki: waga %d, twoja siła %d" % [result["weight"], result["strength"]])
		shake = maxf(shake, 3.0)
		busy = 0.35
	elif action == "blocked":
		busy = 0.12
	elif action == "elevator":
		last_trip_value = int(result["value"])
		_ride_up()
	return result

func _move_player(to: Vector2i, duration: float) -> void:
	_play_for("walk", duration)
	create_tween().tween_property(player_root, "position", _cell_center(to), duration)

func _play_for(anim: String, duration: float, backwards: bool = false) -> void:
	var frames: SpriteFrames = player_sprite.sprite_frames
	var speed := frames.get_frame_count(anim) / (frames.get_animation_speed(anim) * duration)
	player_sprite.play(anim, -speed if backwards else speed, backwards)

func _dig_effect(result: Dictionary, dir: Vector2i) -> void:
	busy = float(model.config["player"]["dig_interval"])
	player_sprite.stop()
	_play_for("dig", busy, true)
	var target: Vector2i = result["cell"]
	var name: String = result["material"]
	var face := _cell_center(target) - Vector2(dir) * CELL * 0.45
	var color: Color = MATERIAL_COLORS[name]
	world.refresh()
	shake = maxf(shake, 2.5)
	_flash(target)
	if result["action"] == "hit":
		_dust(face, color, 10, Vector2(-dir))
		_particles(face, color.lightened(0.2), 5, Vector2(-dir), 260.0, 700.0, 4.0, 0.5)
		hp_bar.visible = true
		hp_bar.modulate.a = 1.0
		hp_bar.position = Vector2(target * CELL) + Vector2(CELL * 0.5, 4)
		hp_fill.size.x = 48.0 * float(result["hp"]) / float(result["max"])
		var t := create_tween()
		t.tween_interval(0.7)
		t.tween_property(hp_bar, "modulate:a", 0.0, 0.3)
		return
	hp_bar.visible = false
	_dust(_cell_center(target), color, 22, Vector2(-dir))
	_debris(_cell_center(target), color)
	var drops: Dictionary = result["drops"]
	for res in drops:
		if int(drops[res]) > 0:
			_float_text(_cell_center(target), "+%d %s" % [drops[res], model.config["resources"][res]["label"]], MATERIAL_COLORS[name].lightened(0.35))
	if int(result["on_ground"]) > 0:
		show_toast("Plecak pełny %d/%d! %s leży na ziemi.\nWyrzuć tańszy (Q) albo wróć windą." % [model.backpack_count(), model.slots(), model.config["resources"][result["resource"]]["label"]])
	elif not drops.is_empty() and model.free_slots() == 0:
		show_toast("Plecak pełny %d/%d — wracaj do windy" % [model.backpack_count(), model.slots()])

func _flash(cell: Vector2i) -> void:
	var rect := ColorRect.new()
	rect.color = Color(1, 0.95, 0.8, 0.35)
	rect.size = Vector2(CELL, CELL)
	rect.position = Vector2(cell * CELL)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rect)
	var t := create_tween()
	t.tween_property(rect, "color:a", 0.0, 0.14)
	t.tween_callback(rect.queue_free)

func _particles(pos: Vector2, color: Color, amount: int, dir: Vector2, speed: float, gravity: float, size: float, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = 75.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.z_index = 6
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

func _dust(pos: Vector2, color: Color, amount: int, dir: Vector2) -> void:
	_particles(pos, color.lerp(Color("#e8dcc8"), 0.55), amount, dir, 140.0, 40.0, 10.0, 0.9)

func _debris(pos: Vector2, color: Color) -> void:
	_particles(pos, color, 9, Vector2.UP, 220.0, 900.0, 6.0, 0.8)

func _float_text(pos: Vector2, text_value: String, color: Color) -> void:
	var lbl := _make_label(text_value, 22, color)
	lbl.position = pos + Vector2(-50, -40)
	overlay.add_child(lbl)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 60, 1.1)
	t.tween_property(lbl, "modulate:a", 0.0, 1.1).set_delay(0.4)
	t.chain().tween_callback(lbl.queue_free)

func show_toast(text_value: String) -> void:
	toast.text = text_value
	toast_time = 2.6

func _handle_event(e: Dictionary) -> void:
	var type: String = e["type"]
	if type == "fall":
		if boulder_sprites.has(e["id"]):
			create_tween().tween_property(boulder_sprites[e["id"]], "position", _cell_center(e["to"]), float(model.config["boulders"]["fall_interval"]))
		world.refresh()
	elif type == "land":
		_dust(_cell_center(e["at"]) + Vector2(0, 28), Color("#857a6b"), 14, Vector2.UP)
		shake = maxf(shake, 5.0)
		world.refresh()
	elif type == "hit_player":
		shake = maxf(shake, 11.0)
		_dust(player_root.position + Vector2(0, -30), Color("#b0a090"), 24, Vector2.UP)
		player_sprite.play("stun")
		player_sprite.modulate = Color(1.8, 0.5, 0.5)
		create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.6)
		var squash := create_tween()
		squash.tween_property(player_sprite, "scale", Vector2(2.4, 1.6), 0.08)
		squash.tween_property(player_sprite, "scale", Vector2(2, 2), 0.35).set_trans(Tween.TRANS_ELASTIC)
		var dropped: Array = e["dropped"]
		if dropped.is_empty():
			show_toast("AUĆ! Ogłuszenie %.1f s" % model.stun_left)
		else:
			world.refresh()
			show_toast("AUĆ! Ogłuszenie %.1f s — wypadło %d z plecaka.\nPodnieś bryłki, gdy dojdziesz do siebie." % [model.stun_left, dropped.size()])
	elif type == "glance":
		_dust(player_root.position + Vector2(0, -30), Color("#b0a090"), 10, Vector2.UP)
		shake = maxf(shake, 4.0)
		show_toast("Głaz odbił się od kasku")
	elif type == "collapse":
		shake = 16.0
		show_toast("ZAWALENIE! Utracono niewyniesiony łup: %d zł" % int(e["lost"]))
		_collapse_to_surface()
	elif type == "new_round":
		_rebuild_boulders()
		world.refresh()
		cage.position = _surface_point()
		player_root.position = _surface_point()
		show_toast("Kopalnia odbudowana. Nowa runda!")

func _ride_up() -> void:
	animating = true
	hp_bar.visible = false
	player_sprite.play("idle")
	var t := create_tween()
	t.tween_property(player_root, "position", _cell_center(model.elevator_cell()), model.move_time())
	t.tween_interval(0.25)
	t.set_parallel(true)
	t.tween_property(cage, "position", _surface_point(), 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(player_root, "position", _surface_point(), 1.6).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(func():
		animating = false
		show_toast("Wyniesiono łup: +%d zł" % last_trip_value))

func _descend() -> void:
	if animating or not model.descend():
		return
	animating = true
	surface_panel.visible = false
	player_root.position = _surface_point()
	cage.position = _surface_point()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(cage, "position", _cell_center(model.elevator_cell()), 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(player_root, "position", _cell_center(model.elevator_cell()), 1.6).set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(player_root, "position", _cell_center(model.player), model.move_time())
	t.chain().tween_callback(func(): animating = false)

func _collapse_to_surface() -> void:
	animating = true
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.6)
	t.tween_callback(func():
		cage.position = _surface_point()
		player_root.position = _surface_point()
		camera.global_position = _camera_target()
		camera.reset_smoothing())
	t.tween_property(fade, "color:a", 0.0, 0.6)
	t.tween_callback(func(): animating = false)

func _go_base() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _debug_skip() -> void:
	model.debug_skip()
	show_toast("DEBUG: zegar przesunięty na koniec rundy")

func _camera_target() -> Vector2:
	return player_root.position + Vector2(0, 40)

func _update_effects(delta: float) -> void:
	camera.global_position = _camera_target()
	shake = maxf(0.0, shake - delta * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	for i in range(lamp_lights.size()):
		var entry: Dictionary = lamp_lights[i]
		var f := sin(clock * 11.0 + i * 1.7) * 0.06 + sin(clock * 23.0 + i) * 0.04
		entry["light"].energy = float(entry["base"]) + f
		entry["glow"].modulate.a = 0.55 + f
	miner_light.energy = 1.35 + sin(clock * 7.0) * 0.03
	var stunned: bool = model.stun_left > 0.0
	for i in range(stars.size()):
		stars[i].visible = stunned
		var a := clock * 5.0 + i * TAU / 3.0
		stars[i].position = Vector2(cos(a) * 18.0, -38 + sin(a) * 6.0)
	stun_label.visible = stunned
	if stunned:
		stun_label.text = "OGŁUSZONY %.1f s" % model.stun_left
		stun_label.position = player_root.position + Vector2(-90, -96)
		player_sprite.rotation = sin(clock * 6.0) * 0.12
	else:
		player_sprite.rotation = 0.0
	toast_time = maxf(0.0, toast_time - delta)
	toast_panel.modulate.a = clampf(toast_time * 2.0, 0.0, 1.0)

func _update_hud() -> void:
	if model.state == "break":
		timer_caption.text = "ODBUDOWA KOPALNI"
		timer_label.text = _clock(model.break_left())
		timer_label.add_theme_color_override("font_color", Color("#9fb7ff"))
	else:
		timer_caption.text = "ZAWALENIE ZA"
		var left: float = model.time_left()
		timer_label.text = _clock(left)
		var warn := left <= 20.0 and int(clock * 4.0) % 2 == 0
		timer_label.add_theme_color_override("font_color", Color("#ff6a4a") if warn else Color("#ffe6b8"))
	var full: bool = model.free_slots() == 0
	pack_label.text = "PLECAK %d/%d%s  •  %d kg  •  %d zł%s" % [model.backpack_count(), model.slots(), " PEŁNY" if full else "", model.backpack_mass(), model.backpack_value(), "  •  CIĘŻKO!" if model.is_heavy() else ""]
	pack_label.add_theme_color_override("font_color", Color("#ff9a6a") if full else Color("#c9b49a"))
	_update_slots()
	banked_label.text = "%d zł" % model.banked_value
	surface_panel.visible = model.state != "mine" and not animating
	for control in mine_controls:
		control.visible = model.state == "mine"
	if model.state != "mine":
		touch_dir = Vector2i.ZERO
	if model.state == "break":
		surface_title.text = "KOPALNIA SIĘ ODBUDOWUJE"
		surface_info.text = "Przerwa między rundami: %s.\nWyniesiony łup łącznie: %d zł." % [_clock(model.break_left()), model.banked_value]
		descend_button.disabled = true
	else:
		surface_title.text = "POWIERZCHNIA"
		surface_info.text = "Ostatni kurs windy: +%d zł\nSkarbiec: %d zł\nDo zawalenia: %s — możesz zjechać ponownie" % [last_trip_value, model.banked_value, _clock(model.time_left())]
		descend_button.disabled = false
	for kind in upgrade_buttons:
		var btn: Button = upgrade_buttons[kind]
		var upgrade: Dictionary = model.next_upgrade(kind)
		if upgrade.is_empty():
			btn.text = "KILOF: siła %d (max)" % model.pick_power() if kind == "pick" else "PLECAK: %d sloty (max)" % model.slots()
			btn.disabled = true
		else:
			btn.text = "KUP: %s — %d zł" % [String(upgrade["label"]).to_upper(), int(upgrade["cost"])]
			btn.disabled = model.banked_value < int(upgrade["cost"])

func _update_slots() -> void:
	if slot_icons.size() != model.slots():
		for child in slot_row.get_children():
			child.queue_free()
		slot_icons.clear()
		for _n in range(model.slots()):
			var frame := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0.55)
			style.border_color = Color("#8a5a2b")
			style.set_border_width_all(2)
			style.set_corner_radius_all(6)
			frame.add_theme_stylebox_override("panel", style)
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(36, 36)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			frame.add_child(icon)
			slot_row.add_child(frame)
			slot_icons.append(icon)
	var units: Array = []
	for res in ["gold", "copper", "coal"]:
		for _n in range(int(model.backpack.get(res, 0))):
			units.append(res)
	for n in range(slot_icons.size()):
		slot_icons[n].texture = art.textures["icon_" + units[n]] if n < units.size() else null

func _clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]
