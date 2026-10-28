extends SceneTree

const MainScript = preload("res://scripts/main.gd")
const MainScene = preload("res://scenes/Main.tscn")
const TEST_DIR = "user://dm_tests/"

var failures: int = 0
var passes: int = 0

func _initialize() -> void:
	await process_frame
	var real_before := _fingerprint(MainScript.SAVE_PATH)
	if not _clean_test_dir() or DirAccess.make_dir_recursive_absolute(TEST_DIR) != OK:
		print("FAIL test directory setup")
		quit(1)
		return
	_test_dig_core_return_generator()
	_test_upgrade()
	_test_escape_loses_loot_and_cores()
	_test_fight()
	_test_full_slots_replace_weakest()
	_test_save_load()
	_test_scene_startup()
	_test_warning_threshold()
	_test_encounter_event_count()
	_test_forced_fight_win()
	_test_forced_fight_loss()
	_test_cursed_loot()
	_test_repeated_returns()
	_test_resume_reconciles_income()
	_test_offline_cap_and_future_timestamp()
	_test_save_recovery()
	_check(_clean_test_dir(), "test directory removed")
	_check(_fingerprint(MainScript.SAVE_PATH) == real_before, "real player save untouched")
	print("PASSED: %d  FAILURES: %d" % [passes, failures])
	quit(1 if failures > 0 else 0)

func _fingerprint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "absent"
	return "%s:%d" % [FileAccess.get_md5(path), FileAccess.get_modified_time(path)]

func _clean_test_dir() -> bool:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return true
	for file_name in DirAccess.get_files_at(TEST_DIR):
		if DirAccess.remove_absolute(TEST_DIR + file_name) != OK:
			return false
	return DirAccess.remove_absolute(TEST_DIR) == OK

func _check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)

func _near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance

func _now() -> float:
	return Time.get_unix_time_from_system()

func _isolate(g: Control, tag: String) -> void:
	g.save_path = TEST_DIR + tag + "_save.json"
	g.events_path = TEST_DIR + tag + "_events.jsonl"

func _game(tag: String = "default") -> Control:
	var g: Control = MainScript.new()
	_isolate(g, tag)
	var f := FileAccess.open(MainScript.DATA_PATH, FileAccess.READ)
	g.balance = JSON.parse_string(f.get_as_text())
	g.gold = float(g.balance["base"]["initial_gold"])
	g.last_income_time = _now()
	return g

func _dig_until_dug(g: Control, i: int) -> void:
	for _n in range(20):
		if bool(g.run_data["tiles"][i]["dug"]) or bool(g.run_data["encounter"]):
			return
		g._mine_tile(i)

func _count_events(g: Control, event_name: String) -> int:
	if not FileAccess.file_exists(g.events_path):
		return 0
	var count := 0
	for line in FileAccess.get_file_as_string(g.events_path).split("\n", false):
		var entry = JSON.parse_string(line)
		if typeof(entry) == TYPE_DICTIONARY and entry["event"] == event_name:
			count += 1
	return count

func _has_label(g: Control, prefix: String) -> bool:
	for child in g.content.get_children():
		if child is Label and child.text.begins_with(prefix):
			return true
	return false

func _force_fight_roll(g: Control, win: bool) -> void:
	var chance := minf(0.95, 0.58 + (g.drill - 1) * 0.1 + (g.training - 1) * 0.06)
	for s in range(10000):
		g.rng.seed = s
		if (g.rng.randf() <= chance) == win:
			g.rng.seed = s
			return

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	_check(f != null, "write fixture " + path.get_file())
	if f != null:
		f.store_string(text)
		f.close()

func _test_dig_core_return_generator() -> void:
	var g := _game()
	g._start_run()
	_check(g.current_screen == "mine", "start run opens mine")
	var w := int(g.balance["grid"]["width"])
	_check(not g._can_dig(2 * w + 2), "core not diggable before path")
	for i in [2, w + 2, 2 * w + 2]:
		_dig_until_dug(g, i)
	_check(bool(g.run_data["tiles"][2 * w + 2]["dug"]), "core dug")
	_check(g.run_data["cores"].size() == 1, "core collected")
	var loot := int(g.run_data["loot"])
	_check(loot > 0, "loot collected")
	var gold_before: float = g.gold
	g._retreat(false)
	_check(g.current_screen == "base", "return to base")
	_check(_near(g.gold, gold_before + loot, 0.5), "full loot added")
	_check(g.generators.size() == 1, "generator installed")
	_check(g._income() > 0.0, "income positive")
	var gold_tick: float = g.gold
	g.last_income_time = _now() - 1.0
	g._tick()
	_check(_near(g.gold, gold_tick + g._income(), g._income() * 0.1), "tick adds income")
	g.free()

func _test_upgrade() -> void:
	var g := _game()
	var cost: int = g._upgrade_cost("drill")
	g.gold = cost - 1
	g._upgrade("drill")
	_check(g.drill == 1, "upgrade blocked without gold")
	g.gold = cost
	g._upgrade("drill")
	_check(g.drill == 2 and is_zero_approx(g.gold), "drill upgrade bought")
	_check(g._upgrade_cost("drill") > cost, "drill cost grows")
	g.gold = g._upgrade_cost("training")
	g._upgrade("training")
	_check(g.training == 2, "training upgrade bought")
	g.free()

func _test_escape_loses_loot_and_cores() -> void:
	var g := _game()
	g._start_run()
	g.run_data["loot"] = 100
	g.run_data["cores"] = [3]
	var gold_before: float = g.gold
	g._retreat(true)
	_check(_near(g.gold, gold_before + 70, 0.01), "escape keeps 70% loot")
	_check(g.generators.is_empty(), "escape installs no cores")
	g.free()

func _test_fight() -> void:
	var g := _game()
	g._start_run()
	g.run_data["encounter"] = true
	var before := int(g.run_data["tiles"][0]["hp"])
	g._mine_tile(0)
	_check(int(g.run_data["tiles"][0]["hp"]) == before, "no digging during encounter")
	g._fight()
	var won: bool = g.current_screen == "mine" and not bool(g.run_data["encounter"])
	var lost: bool = g.current_screen == "base"
	_check(won or lost, "fight resolves encounter")
	g.free()

func _test_full_slots_replace_weakest() -> void:
	var g := _game()
	var slots := int(g.balance["base"]["generator_slots"])
	for _n in range(slots):
		g.generators.append(1)
	g._start_run()
	g.run_data["cores"] = [22, 1]
	g._retreat(false)
	_check(g.generators.size() == slots, "slot limit kept")
	_check(g._income() == float(slots - 1 + 22), "weakest replaced only by stronger")
	g.free()

func _test_save_load() -> void:
	var g := _game("saveload")
	g.gold = 1234.0
	g.drill = 3
	g.training = 2
	g.generators = [1, 8]
	g.run_number = 5
	g.best_depth = 4
	g.lifetime_runs = 5
	g._save_game()
	var h := _game("saveload")
	h._load_game()
	_check(h.gold >= 1234.0 and h.gold < 1234.0 + 9.0 * 5.0, "gold restored")
	_check(h.drill == 3 and h.training == 2, "upgrades restored")
	_check(h.generators.size() == 2 and h._income() == 9.0, "generators restored")
	_check(h.run_number == 5 and h.best_depth == 4 and h.lifetime_runs == 5, "progress restored")
	g.free()
	h.free()

func _test_scene_startup() -> void:
	var g: Control = MainScene.instantiate()
	_isolate(g, "scene")
	root.add_child(g)
	_check(not g.balance.is_empty(), "scene loads balance")
	_check(g.content != null and g.content.get_child_count() > 0, "scene builds ui")
	_check(g.income_timer != null and not g.income_timer.is_stopped(), "scene starts income timer")
	_check(g.current_screen == "base" and _has_label(g, "BAZA"), "scene shows base")
	g._start_run()
	_check(_has_label(g, "WYPRAWA"), "scene renders mine")
	root.remove_child(g)
	g.free()

func _test_warning_threshold() -> void:
	var g: Control = MainScene.instantiate()
	_isolate(g, "warning")
	root.add_child(g)
	g._start_run()
	var warning := int(g.balance["danger"]["warning"])
	g.run_data["noise"] = warning - 1
	g._render()
	_check(not _has_label(g, "UWAGA"), "no warning below threshold")
	g.run_data["noise"] = warning
	g._render()
	_check(_has_label(g, "UWAGA"), "warning at threshold")
	root.remove_child(g)
	g.free()

func _test_encounter_event_count() -> void:
	var g := _game("encounter")
	g.drill = 10
	g._start_run()
	var threshold := int(g.balance["danger"]["encounter"])
	var silent_before := true
	for i in range(g.run_data["tiles"].size()):
		if bool(g.run_data["encounter"]):
			g.run_data["encounter"] = false
		g._mine_tile(i)
		if int(g.run_data["noise"]) < threshold and _count_events(g, "monster_encounter") != 0:
			silent_before = false
	_check(silent_before, "no encounter event below threshold")
	_check(int(g.run_data["noise"]) >= threshold, "noise reached encounter threshold")
	_check(_count_events(g, "monster_encounter") == 1, "exactly one encounter event")
	_check(_count_events(g, "dig") == g.run_data["tiles"].size(), "one dig event per hit")
	g.free()

func _test_forced_fight_win() -> void:
	var g := _game()
	g._start_run()
	g.run_data["loot"] = 50
	g.run_data["encounter"] = true
	var gold_before: float = g.gold
	_force_fight_roll(g, true)
	g._fight()
	_check(g.current_screen == "mine" and not bool(g.run_data["encounter"]), "forced win keeps run")
	_check(int(g.run_data["noise"]) == 28 and int(g.run_data["loot"]) == 50, "forced win resets noise, keeps loot")
	_check(g.gold == gold_before, "forced win pays nothing yet")
	g._fight()
	_check(g.current_screen == "mine", "fight without encounter ignored")
	g.free()

func _test_forced_fight_loss() -> void:
	var g := _game()
	g._start_run()
	g.run_data["loot"] = 50
	g.run_data["cores"] = [8]
	g.run_data["encounter"] = true
	var gold_before: float = g.gold
	_force_fight_roll(g, false)
	g._fight()
	_check(g.current_screen == "base", "forced loss returns to base")
	_check(_near(g.gold, gold_before + 35, 0.01), "forced loss keeps 70% loot")
	_check(g.generators.is_empty(), "forced loss installs no cores")
	g.free()

func _test_cursed_loot() -> void:
	var g := _game()
	g.drill = 10
	g._start_run()
	g._resolve_heart(true)
	var types: Dictionary = g.balance["tiles"]
	var tile_type: String = g.run_data["tiles"][0]["type"]
	g._mine_tile(0)
	var expected := int(round(int(types[tile_type]["value"]) * float(g.balance["curse"]["loot_multiplier"])))
	_check(int(g.run_data["loot"]) == expected, "cursed loot multiplied")
	_check(int(g.run_data["noise"]) == int(types[tile_type]["noise"]) + int(g.balance["curse"]["extra_noise_per_hit"]), "curse adds noise per hit")
	g._start_run()
	g._resolve_heart(false)
	tile_type = g.run_data["tiles"][0]["type"]
	g._mine_tile(0)
	_check(int(g.run_data["loot"]) == int(types[tile_type]["value"]), "rejected curse keeps normal loot")
	g.free()

func _test_repeated_returns() -> void:
	var g := _game()
	g._retreat(false)
	g._retreat(true)
	_check(g.gold == float(g.balance["base"]["initial_gold"]) and g.generators.is_empty(), "retreat outside run ignored")
	g._start_run()
	g.run_data["loot"] = 100
	g.run_data["cores"] = [3]
	var start: float = g.gold
	g._retreat(false)
	g._retreat(false)
	_check(_near(g.gold, start + 100, 0.01) and g.generators.size() == 1, "repeated normal return pays once")
	g._start_run()
	g.run_data["loot"] = 100
	g.run_data["cores"] = [3]
	start = g.gold
	g._retreat(true)
	g._retreat(true)
	_check(_near(g.gold, start + 70, 0.01) and g.generators.size() == 1, "repeated escape pays once")
	g._start_run()
	g.run_data["loot"] = 100
	g.run_data["cores"] = [3]
	start = g.gold
	g._retreat(true)
	g._retreat(false)
	_check(_near(g.gold, start + 70, 0.01) and g.generators.size() == 1, "escape then return pays once, no cores")
	g.free()

func _test_resume_reconciles_income() -> void:
	var g := _game("resume")
	g.generators = [5]
	g.last_income_time = _now() - 100.0
	var start: float = g.gold
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(_near(g.gold, start + 500.0, 5.0), "resume credits suspended time")
	start = g.gold
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	g._tick()
	_check(_near(g.gold, start, 5.0), "repeated resume and tick do not double count")
	g.last_income_time = _now() - 30.0
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var saved: Dictionary = g._read_save(g.save_path)
	_check(not saved.is_empty() and _near(float(saved["saved_at"]), _now(), 2.0), "pause settles and saves")
	start = g.gold
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(_near(g.gold, start, 5.0), "repeated pause/resume does not double count")
	var cap := float(g.balance["base"]["offline_cap_hours"]) * 3600.0
	g.last_income_time = _now() - cap * 3.0
	start = g.gold
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(_near(g.gold, start + cap * 5.0, 10.0), "resume respects offline cap")
	g.last_income_time = _now() + 5000.0
	start = g.gold
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(g.gold == start and g.last_income_time <= _now(), "future timestamp on resume pays nothing and resets")
	g.free()

func _test_offline_cap_and_future_timestamp() -> void:
	var g := _game("offline")
	var cap_hours := float(g.balance["base"]["offline_cap_hours"])
	g.generators = [10]
	g.gold = 100.0
	g.last_income_time = _now() - 20.0 * 3600.0
	g._save_game()
	var h := _game("offline")
	h._load_game()
	_check(_near(h.gold, 100.0 + 10.0 * cap_hours * 3600.0, 30.0), "offline income capped")
	_check(h.notice.begins_with("Twoje generatory"), "offline notice shown")
	g.last_income_time = _now() - 60.0
	g._save_game()
	var k := _game("offline")
	k._load_game()
	_check(_near(k.gold, 100.0 + 600.0, 30.0), "offline income below cap")
	g.last_income_time = _now() + 5000.0
	g._save_game()
	var m := _game("offline")
	m._load_game()
	_check(m.gold == 100.0 and m.last_income_time <= _now(), "future save timestamp pays nothing")
	for x in [g, h, k, m]:
		x.free()

func _test_save_recovery() -> void:
	var g := _game("recovery")
	var initial := float(g.balance["base"]["initial_gold"])
	g.gold = 100.0
	g._save_game()
	g.gold = 200.0
	g._save_game()
	_check(FileAccess.file_exists(g.save_path + ".bak"), "backup created on second save")
	_check(not FileAccess.file_exists(g.save_path + ".tmp"), "temp file replaced after save")
	_check(float(g._read_save(g.save_path)["gold"]) == 200.0, "save replaced on windows-style rename")
	var valid := FileAccess.get_file_as_string(g.save_path)
	var cases := {
		"corrupt": "{garbage",
		"truncated": valid.substr(0, valid.length() / 2),
		"empty": "",
		"wrong type": valid.replace("\"generators\":[]", "\"generators\":\"x\""),
	}
	for label in cases:
		_write(g.save_path, cases[label])
		var h := _game("recovery")
		h._load_game()
		_check(h.gold == 100.0, "recover from %s save via backup" % label)
		h.free()
	_write(g.save_path, valid)
	_write(g.save_path + ".tmp", "{interrupted")
	var k := _game("recovery")
	k._load_game()
	_check(k.gold == 200.0, "interrupted temp ignored when save valid")
	k.free()
	_check(DirAccess.remove_absolute(g.save_path) == OK, "simulate crash between delete and rename")
	_write(g.save_path + ".tmp", valid)
	var t := _game("recovery")
	t._load_game()
	_check(t.gold == 200.0, "recover validated temp when save missing")
	t.free()
	_write(g.save_path, "{garbage")
	g.gold = 300.0
	g._save_game()
	_check(float(g._read_save(g.save_path)["gold"]) == 300.0, "save after corruption succeeds")
	_check(float(g._read_save(g.save_path + ".bak")["gold"]) == 100.0, "corrupt save never overwrites backup")
	for path in [g.save_path, g.save_path + ".tmp", g.save_path + ".bak"]:
		_write(path, "{bad")
	var d := _game("recovery")
	d._load_game()
	_check(d.gold == initial and d.drill == 1 and d.generators.is_empty(), "all saves invalid falls back to defaults")
	d.free()
	g.free()
