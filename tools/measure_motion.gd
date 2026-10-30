extends SceneTree

const PrototypeScene = preload("res://scenes/MinePrototype.tscn")
const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const SAVE = "user://dm123_measure_progress.json"
const SCENARIOS = ["walk", "turns", "heavy", "dig", "boulder", "elevator"]
const REPEATS = 3

var scene: Node2D
var rec: Dictionary = {}

func _initialize() -> void:
	print("MEASURE renderer=%s vsync=%d refresh=%.0f window=%s" % [RenderingServer.get_current_rendering_method(), DisplayServer.window_get_vsync_mode(), DisplayServer.screen_get_refresh_rate(), DisplayServer.window_get_size()])
	for run in range(REPEATS):
		for name in SCENARIOS:
			await _open()
			await call("_run_" + name)
			_report(name, run + 1)
			scene.queue_free()
			await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)

func _open() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	scene = PrototypeScene.instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	await _frames(30)
	scene.input_enabled = true

func _corridor(rows: int, length: int, boulders: Array = []) -> void:
	var m = scene.model
	m.boulders = {}
	var start := Vector2i(m.shaft_x + 3, m.station_y + 3)
	for y in range(start.y - 1, start.y + rows + 1):
		for x in range(start.x - 1, start.x + length + 1):
			var inside := y >= start.y and y < start.y + rows and x >= start.x and x < start.x + length
			m._set_cell(x, y, MineModel.EMPTY if inside else MineModel.DIRT)
	for b in boulders:
		m._add_boulder(start + Vector2i(b[0], 0), b[1])
	m.player = start
	scene.world.refresh()
	scene._rebuild_boulders()
	scene._place_at_station()
	scene.camera_pos = scene._camera_target()
	await _frames(30)

func _begin() -> void:
	rec = {"frames": 0, "time": 0.0, "max": 0.0, "fps_min": 1000, "fps_sum": 0, "still": 0, "back": 0, "sub": 0, "jumps": 0, "cam_kinks": 0, "last_cam": scene.camera.global_position, "last_cam_step": Vector2.ZERO, "max_jump": 0.0, "was_moving": false, "max_step": 0.0, "shake": 0.0, "last_pos": scene.player_root.position, "last_gap": scene.player_root.position - scene.camera.global_position, "last_us": Time.get_ticks_usec(), "end_cell": Vector2i.ZERO, "end_center": true}

func _sample(dir: Vector2i) -> void:
	await process_frame
	var now := Time.get_ticks_usec()
	var dt := (now - int(rec["last_us"])) / 1000000.0
	rec["last_us"] = now
	rec["frames"] += 1
	rec["time"] += dt
	rec["max"] = maxf(rec["max"], dt)
	var fps := int(Engine.get_frames_per_second())
	rec["fps_sum"] += fps
	rec["fps_min"] = mini(rec["fps_min"], fps)
	var pos: Vector2 = scene.player_root.position
	var cam: Vector2 = scene.camera.global_position
	var step: Vector2 = pos - rec["last_pos"]
	if dir != Vector2i.ZERO and scene.moving and rec["was_moving"] and step == Vector2.ZERO:
		rec["still"] += 1
	if scene.moving and step.dot(scene.move_to - scene.move_from) < 0.0:
		rec["back"] += 1
	rec["was_moving"] = scene.moving
	var cage: Vector2 = scene.cage.position
	if pos != pos.round() or cam != cam.round() or cage != cage.round():
		rec["sub"] += 1
	var gap: Vector2 = pos - cam
	var jump: float = gap.distance_to(rec["last_gap"])
	if jump > 2.0:
		rec["jumps"] += 1
	var cam_step: Vector2 = cam - rec["last_cam"]
	if cam_step.distance_to(rec["last_cam_step"]) > 2.0:
		rec["cam_kinks"] += 1
	rec["last_cam"] = cam
	rec["last_cam_step"] = cam_step
	rec["max_jump"] = maxf(rec["max_jump"], jump)
	rec["max_step"] = maxf(rec["max_step"], step.length())
	rec["shake"] = maxf(rec["shake"], scene.camera.offset.length())
	rec["last_pos"] = pos
	rec["last_gap"] = gap

func _hold(dir: Vector2i, until: Callable, limit: int = 2000) -> void:
	scene.touch_dir = dir
	for _i in range(limit):
		await _sample(dir)
		if until.call():
			break
	scene.touch_dir = Vector2i.ZERO

func _settle() -> void:
	for _i in range(600):
		await _sample(Vector2i.ZERO)
		if not scene.moving and not scene.animating and scene.busy <= 0.0:
			break
	for _i in range(30):
		await _sample(Vector2i.ZERO)
	rec["end_cell"] = scene.model.player
	rec["end_center"] = scene.player_root.position == scene._cell_center(scene.model.player) or scene.model.state != "mine"

func _cells_from(origin: Vector2i, dir: Vector2i, n: int) -> Callable:
	return func(): return scene.model.player == origin + dir * n

func _run_walk() -> void:
	await _corridor(1, 14)
	_begin()
	var o: Vector2i = scene.model.player
	await _hold(Vector2i.RIGHT, _cells_from(o, Vector2i.RIGHT, 12))
	await _settle()

func _run_turns() -> void:
	await _corridor(3, 8)
	_begin()
	for leg in [[Vector2i.RIGHT, 4], [Vector2i.DOWN, 2], [Vector2i.LEFT, 3], [Vector2i.UP, 2], [Vector2i.RIGHT, 2], [Vector2i.LEFT, 2], [Vector2i.RIGHT, 1]]:
		var o: Vector2i = scene.model.player
		await _hold(leg[0], _cells_from(o, leg[0], leg[1]))
	await _settle()

func _run_heavy() -> void:
	await _corridor(1, 14)
	scene.model.backpack = {"gold": 2}
	print("  heavy mass=%d kg move_time=%.2f" % [scene.model.backpack_mass(), scene.model.move_time()])
	_begin()
	var o: Vector2i = scene.model.player
	await _hold(Vector2i.RIGHT, _cells_from(o, Vector2i.RIGHT, 12))
	await _settle()

func _run_dig() -> void:
	await _corridor(1, 12)
	var m = scene.model
	for x in range(2, 10):
		m._set_cell(m.player.x + x, m.player.y, MineModel.DIRT)
	scene.world.refresh()
	await _frames(10)
	_begin()
	var o: Vector2i = m.player
	await _hold(Vector2i.RIGHT, _cells_from(o, Vector2i.RIGHT, 10))
	await _settle()

func _run_boulder() -> void:
	await _corridor(1, 12, [[3, 1], [9, 3]])
	_begin()
	var o: Vector2i = scene.model.player
	await _hold(Vector2i.RIGHT, _cells_from(o, Vector2i.RIGHT, 7))
	await _hold(Vector2i.RIGHT, func(): return false, 150)
	await _settle()

func _run_elevator() -> void:
	scene.model.backpack = {"coal": 1}
	await _frames(10)
	_begin()
	await _hold(Vector2i.LEFT, func(): return scene.model.state != "mine", 120)
	await _hold(Vector2i.ZERO, func(): return scene.model.state == "surface", 3000)
	scene._descend()
	await _hold(Vector2i.ZERO, func(): return scene.model.state == "mine", 1200)
	await _settle()

func _report(name: String, run: int) -> void:
	var n: int = rec["frames"]
	print("SCENARIO %s run=%d frames=%d fps_avg=%.1f fps_min=%d real_fps=%.1f frame_avg_ms=%.2f frame_max_ms=%.2f still=%d back=%d subpixel=%d cam_jumps_gt2=%d cam_kinks_gt2=%d max_cam_jump=%.1f max_step=%.1f max_shake=%.1f end=%s centered=%s" % [name, run, n, float(rec["fps_sum"]) / n, rec["fps_min"], n / rec["time"], rec["time"] / n * 1000.0, rec["max"] * 1000.0, rec["still"], rec["back"], rec["sub"], rec["jumps"], rec["cam_kinks"], rec["max_jump"], rec["max_step"], rec["shake"], rec["end_cell"], rec["end_center"]])

func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame
