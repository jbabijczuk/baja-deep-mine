extends SceneTree

const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const MainScript = preload("res://scripts/main.gd")
const MainScene = preload("res://scenes/Main.tscn")
const PrototypeScene = preload("res://scenes/MinePrototype.tscn")
const RoundSim = preload("res://tests/round_sim.gd")
const TEST_DIR = "user://dm_proto_tests/"
const EXPECTED_ASSERTIONS = 137
const TESTS = [
	"_test_map_from_seed",
	"_test_generator_veins_many_seeds",
	"_test_dig_balance",
	"_test_dig_dirt_and_stone",
	"_test_dirt_hits_and_pick_upgrade",
	"_test_move_tempo_and_weight",
	"_test_round_time_estimate",
	"_test_move_into_dug_cell",
	"_test_move_up_without_gravity",
	"_test_slots_and_mass",
	"_test_full_backpack_leaves_loot_on_map",
	"_test_boulder_falls_stuns_and_push",
	"_test_stun_drops_loot_and_guard",
	"_test_elevator_return",
	"_test_multiple_deposits_one_round",
	"_test_upgrades_persist_between_rounds",
	"_test_progress_save_and_restart",
	"_test_collapse_loses_loot",
	"_test_debug_skip",
	"_test_scene_smoke",
	"_test_scene_loads_progress",
	"_test_scene_dig_and_walk_rhythm",
	"_test_base_navigation_button",
]

var failures: int = 0
var passes: int = 0
var assertions: int = 0

func _initialize() -> void:
	await process_frame
	var real_before := _fingerprint(MainScript.SAVE_PATH)
	var proto_before := _fingerprint(MineModel.SAVE_PATH)
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
	_check(_fingerprint(MineModel.SAVE_PATH) == proto_before, "real prototype progress untouched")
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

func _break(m, dir: Vector2i) -> Dictionary:
	var r: Dictionary = {}
	for _n in range(40):
		r = m.try_step(dir)
		if r["action"] != "hit":
			break
	return r

func _units(m) -> int:
	return m.backpack_count() + m.loot_count()

func _test_map_from_seed() -> bool:
	var a = _model(77)
	var b = _model(77)
	var c = _model(78)
	_check(a.width >= 40 and a.height >= 40, "map at least 40x40")
	_check(a.cells == b.cells and a.variants == b.variants and a.hints == b.hints, "same seed gives same map and hints")
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

func _components(m) -> Array:
	var sizes: Array = []
	var seen := {}
	for y in range(m.height):
		for x in range(m.width):
			var start := Vector2i(x, y)
			if seen.has(start) or not MineModel.is_ore(m.cell_at(start)):
				continue
			var queue: Array = [start]
			seen[start] = true
			var size := 0
			while not queue.is_empty():
				var p: Vector2i = queue.pop_back()
				size += 1
				for d in MineModel.DIRS:
					var n: Vector2i = p + d
					if not seen.has(n) and m.cell_at(n) == m.cell_at(start):
						seen[n] = true
						queue.append(n)
			sizes.append(size)
	return sizes

func _test_generator_veins_many_seeds() -> bool:
	var seeds := 30
	var ratio_ok := true
	var ratio_sum := 0.0
	var clustered := 0
	var ore_total := 0
	var counts := {MineModel.COAL: 0, MineModel.COPPER: 0, MineModel.GOLD: 0}
	var rock_shallow := 0
	var cells_shallow := 0
	var hinted := 0
	var near_start := 0
	var station_clear := true
	for s in range(seeds):
		var m = _model(9000 + s * 37)
		var shallow := 0
		var ore := 0
		for y in range(m.station_y + 1, int(m.config["map"]["shallow_until"])):
			for x in range(1, m.width - 1):
				var p := Vector2i(x, y)
				var t: int = m.cell_at(p)
				shallow += 1
				if MineModel.is_ore(t):
					ore += 1
					counts[t] += 1
				if MineModel.is_rock(t):
					rock_shallow += 1
					if m.hint_at(p) > 0:
						hinted += 1
		var ratio := float(ore) / float(shallow)
		ratio_sum += ratio
		ratio_ok = ratio_ok and ratio >= 0.025 and ratio <= 0.1
		cells_shallow += shallow
		for size in _components(m):
			ore_total += size
			if size >= 2 and size <= 8:
				clustered += size
		var sc: Vector2i = m.start_cell()
		var found := false
		for y in range(m.height):
			for x in range(m.width):
				var p := Vector2i(x, y)
				if absi(p.x - sc.x) + absi(p.y - sc.y) <= 8 and (MineModel.is_ore(m.cell_at(p)) or m.hint_at(p) > 0):
					found = true
		if found:
			near_start += 1
		for x in range(m.shaft_x - 2, m.shaft_x + int(m.config["map"]["start_tunnel"]) + 1):
			station_clear = station_clear and m.is_passable(Vector2i(x, m.station_y))
	var avg := ratio_sum / seeds
	_check(ratio_ok, "shallow ore share within 2.5-10%% on every one of %d seeds" % seeds)
	_check(avg >= 0.04 and avg <= 0.08, "average shallow ore share 4-8%% (%.1f%%)" % (avg * 100.0))
	_check(float(clustered) / float(ore_total) >= 0.85, "ore grows in 2-8 cell veins (%d/%d cells)" % [clustered, ore_total])
	_check(float(rock_shallow) / float(cells_shallow) >= 0.85, "dirt and stone dominate shallow layer")
	_check(counts[MineModel.COAL] > counts[MineModel.COPPER] and counts[MineModel.COPPER] > counts[MineModel.GOLD] and counts[MineModel.GOLD] > 0, "valuable ore rarer: coal %d > copper %d > gold %d" % [counts[MineModel.COAL], counts[MineModel.COPPER], counts[MineModel.GOLD]])
	_check(hinted > 0 and float(hinted) / float(rock_shallow) <= 0.25, "hints exist but mark at most 25% of rock")
	_check(near_start >= int(seeds * 0.8), "ore or hint within 8 cells of start on %d/%d seeds" % [near_start, seeds])
	_check(station_clear, "station corridor never blocked by generator")
	var m = _model(4242)
	var hint_ok := true
	var r := int(m.config["hints"]["radius"])
	for y in range(m.height):
		for x in range(m.width):
			var h: int = m.hint_at(Vector2i(x, y))
			if h == 0:
				continue
			var near := false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					near = near or m.cell_at(Vector2i(x + dx, y + dy)) >= h and MineModel.is_ore(m.cell_at(Vector2i(x + dx, y + dy)))
			hint_ok = hint_ok and near and MineModel.is_rock(m.cell_at(Vector2i(x, y)))
	_check(hint_ok, "every hint sits in rock next to a real vein")
	return true

func _test_dig_balance() -> bool:
	var m = _model()
	var mats: Dictionary = m.config["materials"]
	var p: Dictionary = m.config["player"]
	_check(float(p["dig_interval"]) >= 0.35 and float(p["dig_interval"]) <= 0.4, "dig interval 0.35-0.40 s")
	_check(int(mats["dirt"]["hp"]) == 2 and int(mats["coal"]["hp"]) == 4, "dirt 2 hp, coal 4 hp")
	_check(int(mats["stone"]["hp"]) in [5, 6] and int(mats["copper"]["hp"]) in [7, 8], "stone 5-6 hp, copper 7-8 hp")
	_check(int(mats["gold"]["hp"]) >= 12 and int(mats["gold"]["hp"]) <= 15, "gold 12-15 hp")
	var before := _hits_to_break(m, MineModel.GOLD)
	m.pick_level = 1
	var after := _hits_to_break(m, MineModel.GOLD)
	_check(before == int(mats["gold"]["hp"]) and after < before and after == ceili(float(before) / float(m.pick_power())), "pick upgrade cuts gold hits %d -> %d" % [before, after])
	return true

func _hits_to_break(m, t: int) -> int:
	var target: Vector2i = m.player + Vector2i.DOWN
	m._set_cell(target.x, target.y, t)
	var hits := 0
	var r: Dictionary = {"action": "hit"}
	while r["action"] == "hit" and hits < 50:
		r = m.try_step(Vector2i.DOWN)
		hits += 1
	return hits

func _test_dig_dirt_and_stone() -> bool:
	var m = _model()
	var target: Vector2i = m.start_cell() + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.DIRT)
	var r: Dictionary = m.try_step(Vector2i.DOWN)
	_check(r["action"] == "hit" and r["hp"] == 1 and m.cell_at(target) == MineModel.DIRT, "first hit only cracks dirt")
	r = m.try_step(Vector2i.DOWN)
	_check(r["action"] == "break" and m.cell_at(target) == MineModel.EMPTY, "dirt breaks on second hit")
	_check(m.player == m.start_cell(), "digging does not move player into block")
	var stone: Vector2i = target + Vector2i.DOWN
	m._set_cell(stone.x, stone.y, MineModel.STONE)
	m.try_step(Vector2i.DOWN)
	var hits: Array = []
	for _n in range(m.max_hp(MineModel.STONE)):
		hits.append(m.try_step(Vector2i.DOWN)["action"])
	_check(hits.count("hit") == m.max_hp(MineModel.STONE) - 1 and hits.back() == "break", "stone needs %d hits" % m.max_hp(MineModel.STONE))
	_check(m.scars[stone.y * m.width + stone.x] > 0, "dug cell keeps dig marks")
	return true

func _test_dirt_hits_and_pick_upgrade() -> bool:
	var m = _model()
	_check(_hits_to_break(m, MineModel.DIRT) == 2, "base pick needs 2 hits for dirt")
	m.pick_level = 1
	_check(m.pick_power() == 2 and _hits_to_break(m, MineModel.DIRT) == 1, "hardened pick breaks dirt in 1 hit")
	_check(_hits_to_break(m, MineModel.STONE) == 3 and _hits_to_break(m, MineModel.COPPER) == 4 and _hits_to_break(m, MineModel.GOLD) == 7, "hardened pick still needs 3/4/7 hits for stone, copper, gold")
	return true

func _test_move_tempo_and_weight() -> bool:
	var m = _model()
	var p: Dictionary = m.config["player"]
	_check(float(p["move_time"]) >= 0.28 and float(p["move_time"]) <= 0.32 and is_equal_approx(m.move_time(), float(p["move_time"])), "base move about 0.30 s per cell")
	m.backpack = {"gold": 2}
	_check(m.is_heavy() and is_equal_approx(m.move_time(), float(p["move_time"]) * float(p["slow_move_multiplier"])) and m.move_time() > float(p["move_time"]), "heavy miner moves slower")
	var target: Vector2i = m.player + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.DIRT)
	_check(is_equal_approx(RoundSim.enter_cost(m, target), 2.0 * float(p["dig_interval"]) + m.move_time()), "dirt cell costs two full dig intervals plus a step")
	return true

func _test_round_time_estimate() -> bool:
	var round_seconds := float(_model().config["round"]["active_seconds"])
	var all_found := true
	var worst_trip := 0.0
	var worst_copper := 0.0
	for seed_value in RoundSim.SEEDS:
		var r: Dictionary = RoundSim.simulate(_model(seed_value), 3)
		all_found = all_found and r["trips"].size() == 3
		worst_trip = maxf(worst_trip, float(r["trips"].back()))
		worst_copper = maxf(worst_copper, float(RoundSim.simulate(_model(seed_value), 1, 1.0, MineModel.COPPER)["trips"][0]))
	_check(is_equal_approx(round_seconds, 280.0), "round stays 4:40")
	_check(all_found, "every seed has 3 reachable ore blocks")
	_check(worst_trip * 4.0 <= round_seconds, "3 nuggets and return fit in a quarter of the round (worst %.1f s)" % worst_trip)
	_check(worst_copper * 2.0 <= round_seconds, "copper trip fits in half of the round (worst %.1f s)" % worst_copper)
	return true

func _test_move_into_dug_cell() -> bool:
	var m = _model()
	var target: Vector2i = m.start_cell() + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.COAL)
	m.try_step(Vector2i.DOWN)
	_check(m.cell_at(target) == MineModel.COAL and m.hp_at(target) == 3, "coal survives first hit")
	_break(m, Vector2i.DOWN)
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
	_break(m, Vector2i.UP)
	m.try_step(Vector2i.UP)
	_check(m.player == above, "dig and climb up through tunnel")
	m.tick(1.0)
	m.step_boulders()
	_check(m.player == above, "no gravity for miner")
	m.try_step(Vector2i.DOWN)
	m.try_step(Vector2i.DOWN)
	_check(m.player == start, "walk back down")
	return true

func _test_slots_and_mass() -> bool:
	var m = _model()
	_check(m.slots() == 3 and m.free_slots() == 3, "backpack starts with 3 slots")
	var target: Vector2i = m.start_cell() + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.COPPER)
	var r: Dictionary = _break(m, Vector2i.DOWN)
	_check(r["action"] == "break" and r["drops"] == {"copper": 1} and m.backpack_count() == 1, "one block gives exactly one unit")
	_check(m.backpack_mass() == 3 and m.backpack_value() == 9, "mass and value tracked per unit")
	_check(not m.is_heavy() and is_equal_approx(m.move_time(), float(m.config["player"]["move_time"])), "light load keeps base speed")
	m.backpack = {"coal": 3}
	_check(m.free_slots() == 0 and not m.is_heavy(), "3 coal fill slots but stay light")
	m.backpack = {"gold": 2}
	_check(m.free_slots() == 1 and m.is_heavy() and m.move_time() > float(m.config["player"]["move_time"]), "2 gold leave a slot but slow the miner")
	return true

func _test_full_backpack_leaves_loot_on_map() -> bool:
	var m = _model()
	m.backpack = {"coal": 2, "copper": 1}
	var target: Vector2i = m.start_cell() + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.GOLD)
	var r: Dictionary = _break(m, Vector2i.DOWN)
	_check(r["action"] == "break" and int(r["on_ground"]) == 1 and r["drops"].is_empty(), "full backpack: ore stays on the map")
	_check(m.loot_at(target) == ["gold"] and m.backpack_count() == 3, "gold nugget lies in broken cell, backpack unchanged")
	var walk: Dictionary = m.try_step(Vector2i.DOWN)
	_check(walk["action"] == "move" and walk["picked"].is_empty() and int(walk["left"]) == 1, "walking over loot with full pack keeps it on the ground")
	m.try_step(Vector2i.UP)
	var d: Dictionary = m.drop_cheapest()
	_check(d["action"] == "drop" and d["resource"] == "coal" and m.loot_at(m.player) == ["coal"] and m.backpack_count() == 2, "drop cheapest unit onto current cell")
	walk = m.try_step(Vector2i.DOWN)
	_check(walk["picked"] == ["gold"] and int(m.backpack.get("gold", 0)) == 1 and m.loot_at(target).is_empty(), "gold picked up after freeing a slot")
	_check(_units(m) == 4 and m.backpack_count() == 3, "no unit lost or duplicated")
	m.backpack.clear()
	walk = m.try_step(Vector2i.UP)
	_check(walk["picked"] == ["coal"] and m.loot_count() == 0, "dropped coal can be picked up again")
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
	var r: Dictionary = _break(m, Vector2i.UP)
	_check(r["action"] == "break", "support block dug")
	var e1: Array = m.step_boulders()
	_check(e1.size() == 1 and e1[0]["type"] == "fall" and m.boulders[id]["pos"] == Vector2i(bx, m.station_y - 1), "boulder falls after support removed")
	var e2: Array = m.step_boulders()
	_check(e2.size() == 1 and e2[0]["type"] == "hit_player" and m.stun_left > 0.0 and e2[0]["dropped"].is_empty(), "falling boulder stuns miner, empty pack drops nothing")
	_check(m.try_step(Vector2i.LEFT)["action"] == "stunned", "stunned miner cannot move")
	_check(m.step_boulders().is_empty() and m.boulders[id]["pos"] == Vector2i(bx, m.station_y - 1), "boulder rests on miner head")
	m.tick(float(m.config["player"]["stun_seconds"]) + 0.05)
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

func _stunned_under_demo(m, pack: Dictionary) -> Array:
	for _n in range(5):
		m.try_step(Vector2i.RIGHT)
	m.backpack = pack
	_break(m, Vector2i.UP)
	m.step_boulders()
	return m.step_boulders()

func _test_stun_drops_loot_and_guard() -> bool:
	var m = _model()
	var p: Dictionary = m.config["player"]
	var stun := float(p["stun_seconds"])
	_check(stun >= 3.5 and stun <= 4.0, "stun lasts 3.5-4 s")
	var id: int = m.boulder_at(Vector2i(m.shaft_x + 6, m.station_y - 2))
	var hit: Array = _stunned_under_demo(m, {"coal": 1, "copper": 1, "gold": 1})
	var dropped: Array = hit[0]["dropped"]
	_check(hit[0]["type"] == "hit_player" and dropped.size() == 2 and m.backpack_count() == 1, "stun knocks 2 of 3 units out of the pack")
	var cells_ok := true
	for item in dropped:
		cells_ok = cells_ok and m.is_passable(item["cell"]) and item["cell"] != m.player
	_check(cells_ok and _units(m) == 3, "dropped units lie on free floor next to miner")
	m.tick(stun - 0.5)
	m.boulders[id]["falling"] = true
	var e: Array = m.step_boulders()
	_check(e.size() == 1 and e[0]["type"] == "glance" and m.stun_left < 1.0 and m.backpack_count() == 1, "hit during stun does not extend it or drop more")
	_check(m.try_step(Vector2i.LEFT)["action"] == "stunned", "loot cannot be grabbed while stunned")
	m.tick(0.6)
	var left: Dictionary = m.try_step(Vector2i.LEFT)
	m.step_boulders()
	m.step_boulders()
	var push: Dictionary = m.try_step(Vector2i.RIGHT)
	_check(left["picked"].size() == 1 and push["action"] == "push" and push["picked"].size() == 1, "dropped units recovered, also from under a pushed boulder")
	_check(m.backpack_count() == 3 and m.loot_count() == 0 and m.backpack_value() == 40, "full value back after recovery")
	var g = _model()
	_stunned_under_demo(g, {})
	var gid: int = g.boulder_at(Vector2i(g.shaft_x + 6, g.station_y - 1))
	g.tick(stun + 0.05)
	_check(g.stun_left == 0.0 and g.stun_guard_left > 0.0, "guard window after stun ends")
	g.boulders[gid]["falling"] = true
	e = g.step_boulders()
	_check(e[0]["type"] == "glance" and g.stun_left == 0.0 and g.try_step(Vector2i.DOWN)["action"] != "stunned", "no re-stun inside guard window")
	g.tick(float(p["stun_guard_seconds"]))
	g.boulders[gid]["falling"] = true
	e = g.step_boulders()
	_check(e[0]["type"] == "hit_player" and g.stun_left > 0.0, "new hit after guard stuns again")
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

func _test_multiple_deposits_one_round() -> bool:
	var m = _model()
	m.tick(30.0)
	m.backpack = {"coal": 3}
	m.try_step(Vector2i.LEFT)
	var t1: float = m.round_time
	_check(m.state == "surface" and m.banked_value == 9 and is_equal_approx(t1, 30.0), "first deposit keeps round clock running")
	m.tick(5.0)
	_check(m.descend() and m.state == "mine" and is_equal_approx(m.time_left(), 245.0), "descend again in the same round")
	var target: Vector2i = m.player + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.COPPER)
	_break(m, Vector2i.DOWN)
	m.backpack["coal"] = 2
	m.try_step(Vector2i.LEFT)
	_check(m.banked_value == 9 + 9 + 6 and m.round_index == 0, "second deposit adds to bank in same round")
	m.tick(m.time_left())
	_check(m.state == "break" and not m.descend(), "no descent after active phase ends")
	m.tick(float(m.config["round"]["break_seconds"]))
	_check(m.state == "surface" and m.banked_value == 24 and m.round_index == 1, "bank survives the break into next round")
	return true

func _test_upgrades_persist_between_rounds() -> bool:
	var m = _model()
	var res: Dictionary = m.config["resources"]
	var trip_cheap: int = m.slots() * int(res["coal"]["value"])
	var trip_rich: int = m.slots() * int(res["copper"]["value"])
	var pick_cost := int(m.config["upgrades"]["pick"][0]["cost"])
	var pack_cost := int(m.config["upgrades"]["backpack"][0]["cost"])
	_check(pick_cost <= 2 * trip_rich and pick_cost >= trip_cheap, "pick costs 1-2 early deliveries (%d zł)" % pick_cost)
	_check(pack_cost >= 2 * trip_cheap and pack_cost <= 4 * trip_rich and pack_cost > pick_cost, "backpack 3->4 costs 2-4 deliveries (%d zł)" % pack_cost)
	m.banked_value = 1000
	_check(not m.buy("pick")["ok"] and m.pick_level == 0 and m.banked_value == 1000, "no shopping inside the mine")
	m.try_step(Vector2i.LEFT)
	m.banked_value = pick_cost - 1
	var r: Dictionary = m.buy("pick")
	_check(not r["ok"] and r["reason"] == "funds" and m.pick_level == 0 and m.banked_value == pick_cost - 1, "purchase verified against funds before granting")
	m.banked_value = pick_cost + pack_cost
	_check(m.buy("pick")["ok"] and m.buy("backpack")["ok"] and m.banked_value == 0, "both upgrades bought for exact price")
	_check(m.pick_power() == 2 and m.slots() == 4, "upgrades change pick power and slots")
	m.banked_value = 500
	_check(m.buy("pick")["reason"] == "max" and m.buy("backpack")["reason"] == "max" and m.banked_value == 500, "maxed upgrade cannot be bought twice")
	m.descend()
	m.tick(m.time_left() + float(m.config["round"]["break_seconds"]))
	_check(m.round_index == 1 and m.pick_level == 1 and m.backpack_level == 1 and m.slots() == 4, "upgrades kept into next round")
	return true

func _test_progress_save_and_restart() -> bool:
	var path := TEST_DIR + "progress.json"
	var m = _model()
	m.load_progress(path)
	_check(m.banked_value == 0 and m.pick_level == 0, "missing save starts fresh")
	m.backpack = {"gold": 2}
	m.try_step(Vector2i.LEFT)
	m.buy("pick")
	var restarted = _model()
	restarted.load_progress(path)
	_check(restarted.banked_value == 56 - 25 and restarted.pick_level == 1 and restarted.backpack_level == 0, "bank and pick level survive restart")
	_check(restarted.backpack.is_empty() and restarted.ride_up() == 0 and restarted.banked_value == 31, "restart does not duplicate loot")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var broken = _model()
	broken.load_progress(path)
	_check(broken.banked_value == 0 and broken.pick_level == 0, "corrupt save falls back to defaults")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "banked_value": -50, "pick_level": 99, "backpack_level": 7}))
	file.close()
	var clamped = _model()
	clamped.load_progress(path)
	_check(clamped.banked_value == 0 and clamped.pick_level == 1 and clamped.backpack_level == 1, "tampered save values clamped")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"banked_value": 80}))
	file.close()
	var legacy = _model()
	legacy.load_progress(path)
	_check(legacy.banked_value == 0, "save without version ignored")
	return true

func _test_collapse_loses_loot() -> bool:
	var m = _model()
	m.banked_value = 10
	m.backpack = {"gold": 2}
	m._add_loot(m.start_cell(), "copper")
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
	_check(m.loot_count() == 0 and m.banked_value == 10, "ground loot buried, bank kept")
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
	scene.save_path = TEST_DIR + "scene_smoke.json"
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(scene.model != null and scene.model.state == "mine", "prototype scene starts in mine")
	_check(scene.boulder_sprites.size() == scene.model.boulders.size(), "boulder sprites match model")
	_check(scene.lamp_lights.size() == scene.model.lamps.size(), "lamp lights created")
	_check(scene.art.miner_frames.has("idle") and scene.art.miner_frames.has("walk") and scene.art.miner_frames.has("dig"), "miner animations built")
	_check(scene.art.textures["dirt"].size() == 4 and scene.art.textures.has("hint_gold"), "material variants and hint textures")
	_check(scene.pack_label.text.begins_with("PLECAK 0/3") and scene.slot_icons.size() == 3, "HUD shows 0/3 with three slots")
	scene.input_enabled = false
	var r: Dictionary = scene.apply_step(Vector2i.RIGHT)
	_check(r["action"] == "move", "scene step moves miner")
	await create_timer(0.5).timeout
	_check(scene.player_root.position.distance_to(scene._cell_center(scene.model.player)) < 1.0, "sprite reaches cell")
	scene.model.backpack = {"coal": 1, "gold": 1}
	await process_frame
	await process_frame
	_check(scene.pack_label.text.begins_with("PLECAK 2/3") and scene.slot_icons[0].texture == scene.art.textures["icon_gold"], "slots show carried ore icons")
	scene.drop_cheapest()
	_check(scene.model.backpack == {"gold": 1} and scene.model.loot_at(scene.model.player) == ["coal"], "drop button leaves coal on floor")
	scene.model.state = "surface"
	scene.model.banked_value = 30
	await process_frame
	_check(not scene.upgrade_buttons["pick"].disabled and scene.upgrade_buttons["backpack"].disabled, "upgrade buttons reflect funds")
	_check(scene.buy_upgrade("pick")["ok"] and FileAccess.file_exists(scene.save_path), "buying in scene saves progress")
	scene.queue_free()
	await process_frame
	return true

func _test_scene_loads_progress() -> bool:
	var scene: Node2D = PrototypeScene.instantiate()
	scene.save_path = TEST_DIR + "scene_smoke.json"
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(scene.model.pick_level == 1 and scene.model.banked_value == 5 and scene.model.backpack.is_empty(), "restarted scene keeps pick and bank, no carried loot")
	scene.queue_free()
	await process_frame
	return true

func _test_scene_dig_and_walk_rhythm() -> bool:
	var scene: Node2D = PrototypeScene.instantiate()
	scene.save_path = TEST_DIR + "scene_rhythm.json"
	root.add_child(scene)
	await process_frame
	scene.input_enabled = false
	var m = scene.model
	var p: Dictionary = m.config["player"]
	var interval := float(p["dig_interval"])
	var target: Vector2i = m.player + Vector2i.DOWN
	m._set_cell(target.x, target.y, MineModel.DIRT)
	var r: Dictionary = scene.apply_step(Vector2i.DOWN)
	_check(r["action"] == "hit" and m.hp_at(target) < m.max_hp(MineModel.DIRT) and scene.hp_bar.visible and is_equal_approx(scene.busy, interval), "first dirt hit cracks block and waits one dig interval")
	_check(scene.player_sprite.animation == "dig" and is_equal_approx(_anim_seconds(scene), interval), "dig animation lasts the dig interval")
	r = scene.apply_step(Vector2i.DOWN)
	_check(r["action"] == "break" and is_equal_approx(scene.busy, interval), "final hit keeps full dig interval")
	r = scene.apply_step(Vector2i.DOWN)
	_check(r["action"] == "move" and is_equal_approx(scene.busy, m.move_time()) and scene.player_sprite.animation == "walk" and is_equal_approx(_anim_seconds(scene), m.move_time()), "walk cycle spans one cell move")
	m.backpack = {"gold": 2}
	r = scene.apply_step(Vector2i.UP)
	_check(r["action"] == "move" and is_equal_approx(scene.busy, float(p["move_time"]) * float(p["slow_move_multiplier"])) and is_equal_approx(_anim_seconds(scene), scene.busy), "heavy walk is slower and animation follows")
	scene.queue_free()
	await process_frame
	return true

func _anim_seconds(scene) -> float:
	var frames: SpriteFrames = scene.player_sprite.sprite_frames
	var anim: StringName = scene.player_sprite.animation
	return frames.get_frame_count(anim) / (frames.get_animation_speed(anim) * absf(scene.player_sprite.get_playing_speed()))

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
