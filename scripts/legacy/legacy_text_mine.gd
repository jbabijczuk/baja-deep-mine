extends Control

const DATA_PATH = "res://data/balance.json"
const SAVE_PATH = "user://save_v12.json"
const EVENTS_PATH = "user://events_v12.jsonl"
const PROTOTYPE_SCENE = "res://scenes/MinePrototype.tscn"

var save_path: String = SAVE_PATH
var events_path: String = EVENTS_PATH
var last_income_time: float = 0.0
var balance: Dictionary = {}
var gold: float = 0.0
var drill: int = 1
var training: int = 1
var generators: Array = []
var run_number: int = 0
var best_depth: int = 0
var lifetime_runs: int = 0
var run_data: Dictionary = {}
var rng := RandomNumberGenerator.new()
var content: VBoxContainer
var notice: String = "Zacznij wyprawę. Szukaj rdzeni zasilających bazę."
var last_save_time: int = 0
var current_screen: String = "base"
var income_timer: Timer

func _ready() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Brak pliku balansu")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Niepoprawny balans")
		return
	balance = parsed
	_load_game()
	_create_ui()
	income_timer = Timer.new()
	income_timer.wait_time = 1.0
	income_timer.timeout.connect(_tick)
	add_child(income_timer)
	income_timer.start()
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_settle_income()
		_save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_settle_income()
		_render()

func _create_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#111b2c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

func _label(text_value: String, font_size: int = 27, font_color: String = "#ebeff7") -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(font_color))
	content.add_child(lbl)
	return lbl

func _button(text_value: String, callback: Callable, parent: Control = null) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size = Vector2(0, 76)
	btn.add_theme_font_size_override("font_size", 22)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent == null:
		content.add_child(btn)
	else:
		parent.add_child(btn)
	btn.pressed.connect(callback)
	return btn

func _panel_text(value: String) -> void:
	var box := PanelContainer.new()
	content.add_child(box)
	var inner := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inner.add_theme_constant_override(key, 13)
	box.add_child(inner)
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 23)
	inner.add_child(label)

func _render() -> void:
	if content == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_label("DEEP MINE", 46, "#62ebd2")
	_label("CURSED DEPTHS  /  BUILD 0.2", 20, "#9fb0c7")
	_label("Zloto: %s   |   Dochod: %s / s" % [_money(gold), _money(_income())], 25, "#ffdf8a")
	if current_screen == "base":
		_render_base()
	else:
		_render_mine()
	_panel_text(notice)

func _render_base() -> void:
	_label("BAZA", 33)
	_panel_text("Kilof: %d   |   Trening: %d   |   Generatory: %d/%d\nNajgłębsza warstwa: %d   |   Wyprawy: %d" % [drill, training, generators.size(), int(balance["base"]["generator_slots"]), best_depth, lifetime_runs])
	_button("ROZPOCZNIJ WYPRAWĘ", Callable(self, "_start_run"))
	_button("NOWA KOPALNIA — PROTOTYP", Callable(self, "_open_prototype"))
	var drill_cost := _upgrade_cost("drill")
	var drill_button := _button("Ulepsz kilof (+1 mocy): %d zl" % drill_cost, Callable(self, "_upgrade").bind("drill"))
	drill_button.disabled = gold < drill_cost
	var train_cost := _upgrade_cost("training")
	var train_button := _button("Trening (+1 szansa ucieczki): %d zl" % train_cost, Callable(self, "_upgrade").bind("training"))
	train_button.disabled = gold < train_cost
	_label("TWOJE GENERATORY", 28)
	if generators.is_empty():
		_panel_text("Wykop rdzen w kopalni i wroc zywy. Zasili baze i bedzie produkowal zloto rowniez poza gra.")
	else:
		for i in range(generators.size()):
			_panel_text("Generator %d  •  %d zl/s" % [i + 1, int(generators[i])])
	_label("Cel: znajdz mocniejszy rdzen, rozbuduj kilof i zejdz glebiej.", 23, "#acd9d0")

func _render_mine() -> void:
	_label("WYPRAWA %d" % run_number, 33)
	var data: Dictionary = run_data
	_label("Lup: %d zl  |  Halas: %d/100  |  Najglebiej: %d" % [int(data["loot"]), int(data["noise"]), int(data["depth"])], 22, "#f9d692")
	if bool(data["curse_active"]):
		_label("AKTYWNA KLATWA: x2 lup, +3 halasu za cios", 20, "#fd9ec1")
	if bool(data["encounter"]):
		_panel_text("POTWOR PRZECIAL DROGE! Walcz lub uciekaj i utrac 30% lupu. Walka zalezy od kilofa i treningu.")
		_button("WALCZ Z POTWOREM", Callable(self, "_fight"))
		_button("UCIEKAJ (-30% lupu)", Callable(self, "_retreat").bind(true))
		return
	if bool(data["heart_found"]) and not bool(data["heart_resolved"]):
		_panel_text("SERCE KOPALNI: x2 wartosci przyszlego lupu, ale +3 halasu za kazdy cios. Co wybierasz?")
		_button("PRZYJMIJ KLATWE", Callable(self, "_resolve_heart").bind(true))
		_button("ODRZUC", Callable(self, "_resolve_heart").bind(false))
	var grid := GridContainer.new()
	grid.columns = int(balance["grid"]["width"])
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	var tiles: Array = run_data["tiles"]
	for i in range(tiles.size()):
		var tile: Dictionary = tiles[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(97, 79)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 17)
		if bool(tile["dug"]):
			btn.text = "·"
			btn.modulate = Color("#526377")
		else:
			var name: String = str(tile["type"])
			var types: Dictionary = balance["tiles"]
			btn.text = "%s\n%dHP" % [str(types[name]["label"]), int(tile["hp"])]
			btn.modulate = Color(str(types[name]["color"]))
			if not _can_dig(i):
				btn.disabled = true
		btn.pressed.connect(Callable(self, "_mine_tile").bind(i))
		grid.add_child(btn)
	if int(data["noise"]) >= int(balance["danger"]["warning"]):
		_label("UWAGA: wzrost halasu przyciaga potwory.", 22, "#ff9c98")
	_button("WROC DO BAZY (ZACHOWAJ LUP)", Callable(self, "_retreat").bind(false))

func _start_run() -> void:
	run_number += 1
	lifetime_runs += 1
	rng.seed = 87319 + run_number * 7919
	var w: int = int(balance["grid"]["width"])
	var h: int = int(balance["grid"]["height"])
	var tiles: Array = []
	for y in range(h):
		for x in range(w):
			var roll := rng.randf()
			var name := "dirt"
			if roll > 0.89:
				name = "gem"
			elif roll > 0.73:
				name = "gold"
			elif roll > 0.54:
				name = "copper"
			elif roll > 0.23:
				name = "rock"
			if y == 2 and x == 2:
				name = "core"
			if y == 4 and x == 3:
				name = "heart"
			if y >= 6 and roll > 0.93:
				name = "core"
			var types: Dictionary = balance["tiles"]
			var hp := int(types[name]["hp"]) + (1 if y > 5 else 0)
			tiles.append({"type": name, "hp": hp, "dug": false})
	run_data = {"tiles": tiles, "loot": 0, "noise": 0, "cores": [], "depth": 0, "curse_active": false, "heart_found": false, "heart_resolved": false, "encounter": false, "encounter_seen": false, "hits": 0}
	current_screen = "mine"
	notice = "Kop od gory, szukaj drog do bogatych zyl i rdzeni."
	_event("run_start", {"run": run_number})
	_render()

func _open_prototype() -> void:
	_settle_income()
	_save_game()
	get_tree().change_scene_to_file(PROTOTYPE_SCENE)

func _can_dig(i: int) -> bool:
	var tiles: Array = run_data["tiles"]
	if bool(tiles[i]["dug"]):
		return false
	var w: int = int(balance["grid"]["width"])
	if i < w:
		return true
	if bool(tiles[i-w]["dug"]):
		return true
	if i % w != 0 and bool(tiles[i-1]["dug"]):
		return true
	if i % w != w - 1 and bool(tiles[i+1]["dug"]):
		return true
	return false

func _mine_tile(i: int) -> void:
	if current_screen != "mine" or bool(run_data["encounter"]) or not _can_dig(i):
		return
	var tile: Dictionary = run_data["tiles"][i]
	var name: String = str(tile["type"])
	var types: Dictionary = balance["tiles"]
	tile["hp"] = max(0, int(tile["hp"]) - drill)
	run_data["hits"] = int(run_data["hits"]) + 1
	var extra := int(balance["curse"]["extra_noise_per_hit"]) if bool(run_data["curse_active"]) else 0
	run_data["noise"] = min(100, int(run_data["noise"]) + int(types[name]["noise"]) + extra)
	if int(tile["hp"]) == 0:
		tile["dug"] = true
		var reward := int(types[name]["value"])
		if bool(run_data["curse_active"]):
			reward = int(round(reward * float(balance["curse"]["loot_multiplier"])))
		run_data["loot"] = int(run_data["loot"]) + reward
		run_data["depth"] = max(int(run_data["depth"]), int(i / int(balance["grid"]["width"])) + 1)
		notice = "Wydobyto %s: +%d zl. Mozesz wrocic z lupem." % [str(types[name]["label"]), reward]
		if name == "core":
			var rate := _generated_core_rate()
			run_data["cores"].append(rate)
			notice = "ZNALEZIONO RDZEN! +%d zl/s po bezpiecznym powrocie." % rate
		if name == "heart" and not bool(run_data["heart_resolved"]):
			run_data["heart_found"] = true
	else:
		notice = "Kamien pekl! Jeszcze %d HP. Halas: %d." % [int(tile["hp"]), int(run_data["noise"])]
	if int(run_data["noise"]) >= int(balance["danger"]["encounter"]) and not bool(run_data["encounter_seen"]):
		run_data["encounter"] = true
		run_data["encounter_seen"] = true
		_event("monster_encounter", {"noise": run_data["noise"]})
	_event("dig", {"type": name, "depth": run_data["depth"], "noise": run_data["noise"]})
	_render()

func _generated_core_rate() -> int:
	var rates: Array = balance["generator_rates"]
	var depth := int(run_data["depth"])
	var tier: int = 0
	if depth >= 7:
		tier = 3
	elif depth >= 5:
		tier = 2
	elif depth >= 3:
		tier = 1
	return int(rates[tier])

func _resolve_heart(accept: bool) -> void:
	if current_screen != "mine":
		return
	run_data["heart_resolved"] = true
	run_data["curse_active"] = accept
	notice = "Klątwa przyjeta: teraz kazdy skarb wiecej wart." if accept else "Odrzucono klatwe. Wyprawa jest bezpieczniejsza."
	_event("curse_choice", {"accept": accept})
	_render()

func _fight() -> void:
	if current_screen != "mine" or not bool(run_data.get("encounter", false)):
		return
	var chance := minf(0.95, 0.58 + (drill - 1) * 0.1 + (training - 1) * 0.06)
	if rng.randf() <= chance:
		run_data["encounter"] = false
		run_data["noise"] = 28
		notice = "Pokonales potwora. Droga wolna. Mozesz wracac albo kopac dalej."
		_event("fight", {"won": true})
		_render()
	else:
		_event("fight", {"won": false})
		_retreat(true)

func _retreat(with_loss: bool) -> void:
	if current_screen != "mine" or run_data.is_empty():
		return
	var settled: Dictionary = run_data
	run_data = {}
	current_screen = "base"
	var loot := int(settled["loot"])
	if with_loss:
		loot = int(round(loot * (1.0 - float(balance["danger"]["escape_loss_fraction"]))))
	gold += loot
	var added: int = 0
	if not with_loss:
		var slots := int(balance["base"]["generator_slots"])
		for rate_value in settled["cores"]:
			var rate := int(rate_value)
			if generators.size() < slots:
				generators.append(rate)
				added += 1
			else:
				var weakest := 0
				for j in range(1, generators.size()):
					if int(generators[j]) < int(generators[weakest]):
						weakest = j
				if rate > int(generators[weakest]):
					generators[weakest] = rate
					added += 1
	best_depth = max(best_depth, int(settled["depth"]))
	_event("run_end", {"loot": loot, "new_generators": added, "depth": settled["depth"], "escaped": with_loss})
	notice = "Wrociles! +%d zl, zainstalowane rdzenie: %d. Produkcja bazy: %s zl/s." % [loot, added, _money(_income())]
	_save_game()
	_render()

func _upgrade_cost(name: String) -> int:
	var u: Dictionary = balance["upgrade"]
	var current := drill if name == "drill" else training
	return int(round(float(u["%s_base" % name]) * pow(float(u["%s_multiplier" % name]), current - 1)))

func _upgrade(name: String) -> void:
	var cost := _upgrade_cost(name)
	if gold < cost:
		return
	gold -= cost
	if name == "drill":
		drill += 1
	else:
		training += 1
	notice = "Ulepszenie kupione za %d zl. Nastepna wyprawa bedzie latwiejsza." % cost
	_event("upgrade", {"name": name, "cost": cost})
	_save_game()
	_render()

func _income() -> float:
	var sum := 0.0
	for rate in generators:
		sum += float(rate)
	return sum

func _settle_income() -> void:
	if balance.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	var max_seconds := float(balance["base"]["offline_cap_hours"]) * 3600.0
	var seconds := clampf(now - last_income_time, 0.0, max_seconds)
	last_income_time = now
	gold += seconds * _income()
	if seconds > 10.0 and _income() > 0:
		notice = "Twoje generatory pracowaly podczas nieobecnosci: +%s zl." % _money(seconds * _income())

func _tick() -> void:
	_settle_income()
	var now: int = int(Time.get_unix_time_from_system())
	if now - last_save_time >= 15:
		_save_game()
	if current_screen == "base":
		_render()

func _load_game() -> void:
	var base: Dictionary = balance["base"]
	gold = float(base["initial_gold"])
	last_income_time = Time.get_unix_time_from_system()
	var data: Dictionary = {}
	for path in [save_path, save_path + ".tmp", save_path + ".bak"]:
		data = _read_save(path)
		if not data.is_empty():
			break
	if data.is_empty():
		return
	gold = float(data["gold"])
	drill = int(data["drill"])
	training = int(data["training"])
	generators = data["generators"]
	run_number = int(data["run_number"])
	best_depth = int(data["best_depth"])
	lifetime_runs = int(data["lifetime_runs"])
	last_income_time = float(data.get("saved_at", last_income_time))
	_settle_income()
	_secure_tmp_save()

func _secure_tmp_save() -> bool:
	var tmp_path := save_path + ".tmp"
	if not _read_save(save_path).is_empty() or _read_save(tmp_path).is_empty():
		return true
	return DirAccess.rename_absolute(tmp_path, save_path) == OK

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = json.data
	for key in ["gold", "drill", "training", "run_number", "best_depth", "lifetime_runs", "saved_at"]:
		if data.has(key) and typeof(data[key]) != TYPE_FLOAT and typeof(data[key]) != TYPE_INT:
			return {}
		if not data.has(key) and key != "saved_at":
			return {}
	if typeof(data.get("generators")) != TYPE_ARRAY:
		return {}
	for rate in data["generators"]:
		if typeof(rate) != TYPE_FLOAT and typeof(rate) != TYPE_INT:
			return {}
	return data

func _save_game() -> void:
	if balance.is_empty() or not _secure_tmp_save():
		return
	last_save_time = int(Time.get_unix_time_from_system())
	var data := {"version": 12, "gold": gold, "drill": drill, "training": training, "generators": generators, "run_number": run_number, "best_depth": best_depth, "lifetime_runs": lifetime_runs, "saved_at": last_income_time}
	var text := JSON.stringify(data)
	var tmp_path := save_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.get_file_as_string(tmp_path) != text or _read_save(tmp_path).is_empty():
		return
	if not _read_save(save_path).is_empty():
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp_path, save_path)

func _event(name: String, payload: Dictionary) -> void:
	var f := FileAccess.open(events_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(events_path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify({"event": name, "at": int(Time.get_unix_time_from_system()), "data": payload}))

func _money(value: float) -> String:
	if value >= 1000000.0:
		return "%.2fM" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1fk" % (value / 1000.0)
	return str(int(round(value)))
