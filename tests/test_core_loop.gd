extends SceneTree

const MainScript = preload("res://scripts/main.gd")
const SAVE_BACKUP = "user://save_v12.json.testbak"

var failures: int = 0

func _init() -> void:
	var had_save := FileAccess.file_exists(MainScript.SAVE_PATH)
	if had_save:
		DirAccess.rename_absolute(MainScript.SAVE_PATH, SAVE_BACKUP)
	_test_dig_core_return_generator()
	_test_upgrade()
	_test_escape_loses_loot_and_cores()
	_test_fight()
	_test_full_slots_replace_weakest()
	_test_save_load()
	DirAccess.remove_absolute(MainScript.SAVE_PATH)
	if had_save:
		DirAccess.rename_absolute(SAVE_BACKUP, MainScript.SAVE_PATH)
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)

func _game() -> Control:
	var g: Control = MainScript.new()
	var f := FileAccess.open(MainScript.DATA_PATH, FileAccess.READ)
	g.balance = JSON.parse_string(f.get_as_text())
	g.gold = float(g.balance["base"]["initial_gold"])
	return g

func _dig_until_dug(g: Control, i: int) -> void:
	for _n in range(20):
		if bool(g.run_data["tiles"][i]["dug"]) or bool(g.run_data["encounter"]):
			return
		g._mine_tile(i)

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
	_check(is_equal_approx(g.gold, gold_before + loot), "full loot added")
	_check(g.generators.size() == 1, "generator installed")
	_check(g._income() > 0.0, "income positive")
	var gold_tick: float = g.gold
	g._tick()
	_check(is_equal_approx(g.gold, gold_tick + g._income()), "tick adds income")
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
	_check(is_equal_approx(g.gold, gold_before + 70), "escape keeps 70% loot")
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
	var g := _game()
	g.gold = 1234.0
	g.drill = 3
	g.training = 2
	g.generators = [1, 8]
	g.run_number = 5
	g.best_depth = 4
	g.lifetime_runs = 5
	g._save_game()
	var h := _game()
	h._load_game()
	_check(h.gold >= 1234.0 and h.gold < 1234.0 + 9.0 * 5.0, "gold restored")
	_check(h.drill == 3 and h.training == 2, "upgrades restored")
	_check(h.generators.size() == 2 and h._income() == 9.0, "generators restored")
	_check(h.run_number == 5 and h.best_depth == 4 and h.lifetime_runs == 5, "progress restored")
	g.free()
	h.free()
