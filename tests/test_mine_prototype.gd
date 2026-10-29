extends SceneTree

const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const MainScript = preload("res://scripts/main.gd")
const MainScene = preload("res://scenes/Main.tscn")
const PrototypeScene = preload("res://scenes/MinePrototype.tscn")
const TEST_DIR = "user://dm_proto_tests/"
const EXPECTED_ASSERTIONS = 62
const TESTS = [
	"_test_map_from_seed",
	"_test_dig_dirt_and_stone",
	"_test_move_into_dug_cell",
	"_test_move_up_without_gravity",
	"_test_drops_and_backpack",
	"_test_boulder_falls_stuns_and_push",
	"_test_elevator_return",
	"_test_collapse_loses_loot",
	"_test_debug_skip",
	"_test_scene_smoke",
	"_test_base_navigation_button",
]

var failures: int = 0
var passes: int = 0
var assertions: int = 0

func _initialize() -> void:
	await process_frame
	var real_before := _fingerprint(MainScript.SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var completed := 0
	for test_name in TESTS:
		if await call(test_name) == true:
			completed += 1
		else:
			failures += 1
			print("FAIL test not completed: ", test_name)
	_clean_test_dir()
	_check(_fingerprint(MainScript.SAVE_PATH) == real_before, "real player save untouched")
	if assertions != EXPECTED_ASSERTIONS:
		failures += 1
		print("FAIL prototype assertion count %d, expected %d" % [assertions, EXPECTED_ASSERTIONS])
	print("PROTOTYPE PASSED: %d  FAILURES: %d" % [passes, failures])
	if failures == 0 and completed == TESTS.size():
		print("PROTOTYPE_TESTS_COMPLETED tests=%d assertions=%d" % [completed, assertions])
	quit(1 if failures > 0 else 0)

func _fingerprint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "absent"
	return "%s:%d" % [FileAccess.get_md5(path), FileAccess.get_modified_time(path)]

func _clean_test_dir() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		for file_name in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(TEST_DIR + file_name)
		DirAccess.remove_absolute(TEST_DIR)

func _check(cond: bool, label: String) -> void:
	assertions += 1
	if cond:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)

func _model(seed_value: int = 1234):
	var m = MineModel.new()
	m.generate(seed_value)
	return m

func _test_map_from_seed() -> bool:
	var a = _model(77)
	var b = _model(77)
	var c = _model(78)
	_check(a.width >= 40 and a.height >= 40, "map at least 40x40")
	_check(a.cells == b.cells and a.variants == b.variants, "same seed gives same map")
	_check(a.cells != c.cells, "different seed gives different map")
	var all_reachable := true
	var all_supported := true
	var lamps_ok := true
	for s in range(1, 21):
		var m = _model(s * 101)
		all_reachable = all_reachable and m.reachable(m.start_cell(), m.elevator_cell())
		lamps_ok = lamps_ok and m.lamps.size() >= 2 and m.lamps.size() <= 4
		for id in m.boulders:
			var pos: Vector2i = m.boulders[id]["pos"]
			all_supported = all_supported and m.cell_at(pos) == MineModel.BOULDER and MineModel.is_material(m.cell_at(pos + Vector2i.DOWN))
	_check(all_reachable, "path from start to elevator open on 20 seeds")
	_check(all_supported, "every boulder starts supported by a block")
	_check(lamps_ok, "2-4 lamps near shaft")
	_check(a.boulders.size() >= 10, "map has boulders")
	var kinds := {}
	for t in a.cells:
		kinds[t] = true
	_check(kinds.has(MineModel.DIRT) and kinds.has(MineModel.STONE) and kinds.has(MineModel.COAL) and kinds.has(MineModel.COPPER) and kinds.has(MineModel.GOLD), "all five materials generated")
	return true

func _test_dig_dirt_and_stone() -> bool:
	var m = _model()
	var target: Vector2i = m.start_cell() + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.DIRT)
	var r: Dictionary = m.try_step(Vector2i.DOWN)
	_check(r["action"] == "break" and m.cell_at(target) == MineModel.EMPTY, "dirt breaks in one hit")
	_check(m.player == m.start_cell(), "digging does not move player into block")
	var stone: Vector2i = target + Vector2i.DOWN
	m._set_cell(stone.x, stone.y, MineModel.STONE)
	m.try_step(Vector2i.DOWN)
	var hits: Array = []
	for _n in range(3):
		hits.append(m.try_step(Vector2i.DOWN)["action"])
	_check(hits == ["hit", "hit", "break"], "stone needs three hits")
	_check(m.scars[stone.y * m.width + stone.x] > 0, "dug cell keeps dig marks")
	return true

func _test_move_into_dug_cell() -> bool:
	var m = _model()
	var target: Vector2i = m.start_cell() + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.COAL)
	m.try_step(Vector2i.DOWN)
	_check(m.cell_at(target) == MineModel.COAL, "coal survives first hit")
	m.try_step(Vector2i.DOWN)
	_check(m.is_passable(target), "broken coal becomes tunnel")
	var r: Dictionary = m.try_step(Vector2i.DOWN)
	_check(r["action"] == "move" and m.player == target, "player walks into dug cell")
	m._set_cell(target.x + 1, target.y, MineModel.BEDROCK)
	_check(m.try_step(Vector2i.RIGHT)["action"] == "blocked" and m.player == target, "bedrock blocks")
	return true

func _test_move_up_without_gravity() -> bool:
	var m = _model()
	var start: Vector2i = m.start_cell()
	var r: Dictionary = m.try_step(Vector2i.UP)
	_check(r["action"] == "move" and m.player == start + Vector2i.UP, "move up into chamber")
	var above: Vector2i = m.player + Vector2i.UP
	m._set_cell(above.x, above.y, MineModel.DIRT)
	m.try_step(Vector2i.UP)
	m.try_step(Vector2i.UP)
	_check(m.player == above, "dig and climb up through tunnel")
	m.tick(1.0)
	m.step_boulders()
	_check(m.player == above, "no gravity for miner")
	m.try_step(Vector2i.DOWN)
	m.try_step(Vector2i.DOWN)
	_check(m.player == start, "walk back down")
	return true

func _test_drops_and_backpack() -> bool:
	var m = _model()
	var target: Vector2i = m.start_cell() + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.COPPER)
	var r: Dictionary = {}
	for _n in range(3):
		r = m.try_step(Vector2i.DOWN)
	var got := int(r["drops"].get("copper", 0))
	_check(r["action"] == "break" and got >= 1 and got <= 3, "copper drops 1-3 units")
	_check(m.backpack_mass() == got * 3 and m.backpack_value() == got * 9, "backpack mass and value")
	m.backpack = {"gold": 10}
	_check(m.move_time() > float(m.config["player"]["move_time"]), "heavy backpack slows miner")
	m._set_cell(target.x, target.y, MineModel.GOLD)
	for _n in range(5):
		r = m.try_step(Vector2i.DOWN)
	_check(r["action"] == "break" and int(r["lost"]) >= 1 and m.backpack_mass() <= 40, "full backpack drops overflow")
	var types := {}
	for name in ["coal", "copper", "gold"]:
		types[name] = m.config["materials"][name].has("drop")
	_check(types.values().count(true) == 3, "three resource types drop")
	return true

func _test_boulder_falls_stuns_and_push() -> bool:
	var m = _model()
	var bx: int = m.shaft_x + 6
	var id: int = m.boulder_at(Vector2i(bx, m.station_y - 2))
	_check(id >= 0, "demo boulder above corridor")
	_check(m.step_boulders().is_empty(), "supported boulder stays")
	for _n in range(5):
		m.try_step(Vector2i.RIGHT)
	_check(m.player == Vector2i(bx, m.station_y), "miner under demo boulder")
	var r: Dictionary = m.try_step(Vector2i.UP)
	_check(r["action"] == "break", "support block dug")
	var e1: Array = m.step_boulders()
	_check(e1.size() == 1 and e1[0]["type"] == "fall" and m.boulders[id]["pos"] == Vector2i(bx, m.station_y - 1), "boulder falls after support removed")
	var e2: Array = m.step_boulders()
	_check(e2.size() == 1 and e2[0]["type"] == "hit_player" and m.stun_left > 0.0, "falling boulder stuns miner")
	_check(m.try_step(Vector2i.LEFT)["action"] == "stunned", "stunned miner cannot move")
	_check(m.step_boulders().is_empty() and m.boulders[id]["pos"] == Vector2i(bx, m.station_y - 1), "boulder rests on miner head")
	m.tick(2.0)
	m.try_step(Vector2i.LEFT)
	_check(m.player == Vector2i(bx - 1, m.station_y), "miner steps away after stun")
	m.step_boulders()
	var land: Array = m.step_boulders()
	_check(m.boulders[id]["pos"] == Vector2i(bx, m.station_y) and land.size() == 1 and land[0]["type"] == "land", "boulder drops into vacated cell")
	r = m.try_step(Vector2i.RIGHT)
	_check(r["action"] == "push" and m.boulders[id]["pos"] == Vector2i(bx + 1, m.station_y) and m.player == Vector2i(bx, m.station_y), "light boulder pushed with enough strength")
	_check(m.try_step(Vector2i.RIGHT)["action"] == "blocked", "push blocked by solid block")
	m.boulders[id]["weight"] = 3
	m._set_cell(bx + 2, m.station_y, MineModel.EMPTY)
	r = m.try_step(Vector2i.RIGHT)
	_check(r["action"] == "too_heavy" and m.boulders[id]["pos"] == Vector2i(bx + 1, m.station_y), "heavy boulder needs more strength")
	_check(m.boulders.size() == _model().boulders.size(), "boulders never duplicated")
	return true

func _test_elevator_return() -> bool:
	var m = _model()
	m.backpack = {"copper": 2, "gold": 1}
	var r: Dictionary = m.try_step(Vector2i.LEFT)
	_check(r["action"] == "elevator" and int(r["value"]) == 46, "elevator carries loot up")
	_check(m.state == "surface" and m.banked_value == 46 and m.backpack.is_empty(), "loot banked once on surface")
	_check(m.try_step(Vector2i.RIGHT)["action"] == "none", "no mining on surface")
	_check(m.ride_up() == 0 and m.banked_value == 46, "second ride does not duplicate loot")
	_check(m.descend() and m.state == "mine" and m.player == m.start_cell(), "descend back to station")
	return true

func _test_collapse_loses_loot() -> bool:
	var m = _model()
	m.banked_value = 10
	m.backpack = {"gold": 2}
	var events: Array = m.tick(279.0)
	_check(events.is_empty() and m.state == "mine", "mine open before 4:40")
	events = m.tick(1.0)
	_check(events.size() == 1 and events[0]["type"] == "collapse" and int(events[0]["lost"]) == 56, "collapse at 4:40 reports lost loot")
	_check(m.backpack.is_empty() and m.banked_value == 10 and m.state == "break", "collapse empties backpack, keeps banked")
	_check(m.try_step(Vector2i.RIGHT)["action"] == "none" and not m.descend(), "no actions during break")
	var old_cells: PackedByteArray = m.cells.duplicate()
	events = m.tick(20.0)
	_check(events.size() == 1 and events[0]["type"] == "new_round" and m.state == "surface" and m.round_time == 0.0, "new round after 0:20 break")
	_check(m.cells != old_cells and m.reachable(m.start_cell(), m.elevator_cell()), "world regenerated with open elevator path")
	return true

func _test_debug_skip() -> bool:
	var m = _model()
	m.debug_skip()
	_check(is_equal_approx(m.time_left(), 10.0), "debug skip leaves 0:10")
	m.backpack = {"coal": 1}
	m.tick(10.0)
	_check(m.state == "break" and m.lost_value == 3, "debug skip leads to collapse")
	return true

func _test_scene_smoke() -> bool:
	var scene: Node2D = PrototypeScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(scene.model != null and scene.model.state == "mine", "prototype scene starts in mine")
	_check(scene.boulder_sprites.size() == scene.model.boulders.size(), "boulder sprites match model")
	_check(scene.lamp_lights.size() == scene.model.lamps.size(), "lamp lights created")
	_check(scene.art.miner_frames.has("idle") and scene.art.miner_frames.has("walk") and scene.art.miner_frames.has("dig"), "miner animations built")
	_check(scene.art.textures["dirt"].size() == 4 and scene.art.textures["gold"].size() == 4, "material texture variants")
	scene.input_enabled = false
	var r: Dictionary = scene.apply_step(Vector2i.RIGHT)
	_check(r["action"] == "move", "scene step moves miner")
	await create_timer(0.5).timeout
	_check(scene.player_root.position.distance_to(scene._cell_center(scene.model.player)) < 1.0, "sprite reaches cell")
	scene.queue_free()
	await process_frame
	return true

func _test_base_navigation_button() -> bool:
	var g: Control = MainScene.instantiate()
	g.save_path = TEST_DIR + "nav_save.json"
	g.events_path = TEST_DIR + "nav_events.jsonl"
	root.add_child(g)
	await process_frame
	var found := false
	for child in g.content.get_children():
		if child is Button and child.text == "NOWA KOPALNIA — PROTOTYP":
			found = true
	_check(found, "base shows prototype button")
	_check(g.PROTOTYPE_SCENE == PrototypeScene.resource_path, "button targets prototype scene")
	g.queue_free()
	await process_frame
	return true
