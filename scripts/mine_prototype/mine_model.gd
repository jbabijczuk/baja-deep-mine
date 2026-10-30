extends RefCounted

const DATA_PATH = "res://data/mine_prototype.json"
const SAVE_PATH = "user://mine_prototype_progress.json"
const SAVE_VERSION = 1
const EMPTY = 0
const DIRT = 1
const STONE = 2
const COAL = 3
const COPPER = 4
const GOLD = 5
const BEDROCK = 6
const BOULDER = 7
const SHAFT = 8
const ELEVATOR = 9
const MATERIAL_NAMES = ["", "dirt", "stone", "coal", "copper", "gold"]
const DIRS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var config: Dictionary = {}
var width: int = 0
var height: int = 0
var seed_value: int = 0
var cells := PackedByteArray()
var hp := PackedByteArray()
var variants := PackedByteArray()
var scars := PackedByteArray()
var hints := PackedByteArray()
var loot: Dictionary = {}
var boulders: Dictionary = {}
var lamps: Array = []
var shaft_x: int = 0
var station_y: int = 0
var player := Vector2i.ZERO
var facing := Vector2i.RIGHT
var stun_left: float = 0.0
var stun_guard_left: float = 0.0
var backpack: Dictionary = {}
var banked: Dictionary = {}
var banked_value: int = 0
var lost_value: int = 0
var pick_level: int = 0
var backpack_level: int = 0
var save_path: String = ""
var state: String = "mine"
var round_time: float = 0.0
var round_index: int = 0
var next_boulder_id: int = 0
var rng := RandomNumberGenerator.new()

func _init(cfg: Dictionary = {}) -> void:
	config = cfg if not cfg.is_empty() else load_config()

static func load_config() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func generate(seed_in: int) -> void:
	seed_value = seed_in
	rng.seed = seed_in
	var m: Dictionary = config["map"]
	width = int(m["width"])
	height = int(m["height"])
	shaft_x = int(m["shaft_x"])
	station_y = int(m["station_y"])
	var count := width * height
	cells.resize(count)
	hp.resize(count)
	variants.resize(count)
	scars.resize(count)
	hints.resize(count)
	boulders.clear()
	backpack.clear()
	loot.clear()
	for y in range(height):
		for x in range(width):
			var i := y * width + x
			var t := _roll_rock(y)
			if x == 0 or x == width - 1 or y == height - 1:
				t = BEDROCK
			_set_cell(x, y, t)
			variants[i] = rng.randi_range(0, 3)
			scars[i] = 0
			hints[i] = 0
	_carve_caves(int(m["caves"]))
	_place_veins()
	for y in range(station_y):
		_set_cell(shaft_x, y, SHAFT)
	_set_cell(shaft_x, station_y, ELEVATOR)
	for x in range(shaft_x - 2, shaft_x + 4):
		if x != shaft_x:
			_set_cell(x, station_y - 1, EMPTY)
			_set_cell(x, station_y, EMPTY)
	for x in range(shaft_x + 1, shaft_x + int(m["start_tunnel"]) + 1):
		_set_cell(x, station_y, EMPTY)
	_place_boulders()
	_place_hints()
	lamps.clear()
	for offset in m["lamp_offsets"]:
		lamps.append(Vector2i(shaft_x + int(offset[0]), station_y + int(offset[1])))
	player = start_cell()
	facing = Vector2i.RIGHT
	stun_left = 0.0
	stun_guard_left = 0.0
	state = "mine"

func start_cell() -> Vector2i:
	return Vector2i(shaft_x + 1, station_y)

func elevator_cell() -> Vector2i:
	return Vector2i(shaft_x, station_y)

func _roll_rock(y: int) -> int:
	var stone := 0.0
	for layer in config["layers"]:
		stone = float(layer["stone"])
		if y < int(layer["until"]):
			break
	return STONE if rng.randf() < stone else DIRT

static func is_rock(t: int) -> bool:
	return t == DIRT or t == STONE

static func is_ore(t: int) -> bool:
	return t == COAL or t == COPPER or t == GOLD

func _place_veins() -> void:
	for vein in config["veins"]:
		var ore := MATERIAL_NAMES.find(String(vein["ore"]))
		var size_range: Array = vein["size"]
		for _n in range(int(vein["count"])):
			var start := Vector2i(rng.randi_range(2, width - 3), rng.randi_range(int(vein["min_y"]), mini(int(vein["max_y"]), height - 3)))
			_grow_vein(start, ore, rng.randi_range(int(size_range[0]), int(size_range[1])))

func _grow_vein(start: Vector2i, ore: int, size: int) -> void:
	if not is_rock(cell_at(start)):
		return
	var vein: Array = [start]
	_set_cell(start.x, start.y, ore)
	for _attempt in range(size * 10):
		if vein.size() >= size:
			break
		var next: Vector2i = vein[rng.randi_range(0, vein.size() - 1)] + DIRS[rng.randi_range(0, 3)]
		if next.x < 1 or next.x > width - 2 or next.y < 1 or next.y > height - 2 or not is_rock(cell_at(next)):
			continue
		_set_cell(next.x, next.y, ore)
		vein.append(next)

func _place_hints() -> void:
	var h: Dictionary = config["hints"]
	var radius := int(h["radius"])
	var chance := float(h["chance"])
	for y in range(height):
		for x in range(width):
			var t: int = cells[y * width + x]
			if not is_ore(t):
				continue
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var p := Vector2i(x + dx, y + dy)
					if in_bounds(p) and is_rock(cell_at(p)) and hints[p.y * width + p.x] < t and rng.randf() < chance:
						hints[p.y * width + p.x] = t

func _carve_caves(amount: int) -> void:
	for _n in range(amount):
		var pos := Vector2i(rng.randi_range(2, width - 3), rng.randi_range(station_y + 6, height - 4))
		for _s in range(rng.randi_range(5, 13)):
			if pos.x > 1 and pos.x < width - 2 and pos.y > station_y + 4 and pos.y < height - 2:
				_set_cell(pos.x, pos.y, EMPTY)
			pos += [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN][rng.randi_range(0, 4)]

func _place_boulders() -> void:
	var b: Dictionary = config["boulders"]
	var demo: Dictionary = b["demo"]
	var demo_pos := Vector2i(shaft_x + int(demo["dx"]), station_y + int(demo["dy"]))
	_set_cell(demo_pos.x, demo_pos.y + 1, DIRT)
	_add_boulder(demo_pos, int(demo["weight"]))
	var weights: Array = b["weights"]
	var exclusion := int(config["map"]["boulder_exclusion"])
	var placed := 0
	for _attempt in range(int(b["count"]) * 30):
		if placed >= int(b["count"]):
			break
		var pos := Vector2i(rng.randi_range(1, width - 2), rng.randi_range(station_y + 3, height - 3))
		if absi(pos.x - shaft_x) <= exclusion and pos.y < station_y + exclusion:
			continue
		if not is_material(cell_at(pos)) or not is_material(cell_at(pos + Vector2i.DOWN)) or cell_at(pos + Vector2i.UP) == BOULDER:
			continue
		_add_boulder(pos, int(weights[rng.randi_range(0, weights.size() - 1)]))
		placed += 1

func _add_boulder(pos: Vector2i, weight: int) -> void:
	_set_cell(pos.x, pos.y, BOULDER)
	boulders[next_boulder_id] = {"pos": pos, "weight": weight, "falling": false}
	next_boulder_id += 1

func _set_cell(x: int, y: int, t: int) -> void:
	var i := y * width + x
	cells[i] = t
	hp[i] = int(config["materials"][MATERIAL_NAMES[t]]["hp"]) if is_material(t) else 0

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height

func cell_at(pos: Vector2i) -> int:
	return cells[pos.y * width + pos.x] if in_bounds(pos) else BEDROCK

func hp_at(pos: Vector2i) -> int:
	return hp[pos.y * width + pos.x] if in_bounds(pos) else 0

func hint_at(pos: Vector2i) -> int:
	return hints[pos.y * width + pos.x] if in_bounds(pos) else 0

func max_hp(t: int) -> int:
	return int(config["materials"][MATERIAL_NAMES[t]]["hp"]) if is_material(t) else 0

static func is_material(t: int) -> bool:
	return t >= DIRT and t <= GOLD

func is_passable(pos: Vector2i) -> bool:
	var t := cell_at(pos)
	return t == EMPTY or t == ELEVATOR

func boulder_at(pos: Vector2i) -> int:
	for id in boulders:
		if boulders[id]["pos"] == pos:
			return id
	return -1

func pick_power() -> int:
	if pick_level > 0:
		return int(config["upgrades"]["pick"][pick_level - 1]["power"])
	return int(config["player"]["pick_power"])

func slots() -> int:
	if backpack_level > 0:
		return int(config["upgrades"]["backpack"][backpack_level - 1]["slots"])
	return int(config["player"]["slots"])

func backpack_count() -> int:
	var total := 0
	for res in backpack:
		total += int(backpack[res])
	return total

func free_slots() -> int:
	return maxi(0, slots() - backpack_count())

func next_upgrade(kind: String) -> Dictionary:
	var levels: Array = config["upgrades"][kind]
	var level := pick_level if kind == "pick" else backpack_level
	return levels[level] if level < levels.size() else {}

func buy(kind: String) -> Dictionary:
	if state == "mine" or not config["upgrades"].has(kind):
		return {"ok": false, "reason": "unavailable"}
	var upgrade := next_upgrade(kind)
	if upgrade.is_empty():
		return {"ok": false, "reason": "max"}
	var cost := int(upgrade["cost"])
	if banked_value < cost:
		return {"ok": false, "reason": "funds", "cost": cost}
	banked_value -= cost
	if kind == "pick":
		pick_level += 1
	else:
		backpack_level += 1
	save_progress()
	return {"ok": true, "cost": cost}

func loot_at(pos: Vector2i) -> Array:
	return loot.get(pos, [])

func loot_count() -> int:
	var total := 0
	for pos in loot:
		total += loot[pos].size()
	return total

func _add_loot(pos: Vector2i, res: String) -> void:
	if not loot.has(pos):
		loot[pos] = []
	loot[pos].append(res)

func _collect(pos: Vector2i) -> Array:
	var picked: Array = []
	var pile: Array = loot_at(pos)
	while not pile.is_empty() and free_slots() > 0:
		var res: String = pile.pop_back()
		backpack[res] = int(backpack.get(res, 0)) + 1
		picked.append(res)
	if pile.is_empty():
		loot.erase(pos)
	return picked

func _take_unit(res: String) -> void:
	backpack[res] = int(backpack[res]) - 1
	if int(backpack[res]) <= 0:
		backpack.erase(res)

func drop_cheapest() -> Dictionary:
	if state != "mine" or stun_left > 0.0 or backpack.is_empty():
		return {"action": "none"}
	var cheapest := ""
	for res in backpack:
		if cheapest == "" or int(config["resources"][res]["value"]) < int(config["resources"][cheapest]["value"]):
			cheapest = res
	_take_unit(cheapest)
	_add_loot(player, cheapest)
	return {"action": "drop", "resource": cheapest, "cell": player}

func try_step(dir: Vector2i) -> Dictionary:
	if state != "mine":
		return {"action": "none"}
	if stun_left > 0.0:
		return {"action": "stunned"}
	facing = dir
	var target := player + dir
	var t := cell_at(target)
	if t == EMPTY:
		var from := player
		player = target
		var picked := _collect(target)
		return {"action": "move", "from": from, "to": target, "picked": picked, "left": loot_at(target).size()}
	if is_material(t):
		return _hit(target)
	if t == BOULDER:
		return _push(target, dir)
	if t == ELEVATOR:
		var from_cell := player
		player = target
		var value := ride_up()
		return {"action": "elevator", "from": from_cell, "value": value}
	return {"action": "blocked", "reason": "bedrock"}

func _hit(target: Vector2i) -> Dictionary:
	var i := target.y * width + target.x
	var t: int = cells[i]
	var name: String = MATERIAL_NAMES[t]
	hp[i] = max(0, int(hp[i]) - pick_power())
	if hp[i] > 0:
		return {"action": "hit", "cell": target, "material": name, "hp": int(hp[i]), "max": max_hp(t)}
	cells[i] = EMPTY
	hints[i] = 0
	scars[i] = rng.randi_range(1, 3)
	var result := {"action": "break", "cell": target, "material": name, "drops": {}, "on_ground": 0}
	var mat: Dictionary = config["materials"][name]
	if mat.has("drop"):
		var res: String = mat["drop"]
		if free_slots() > 0:
			backpack[res] = int(backpack.get(res, 0)) + 1
			result["drops"] = {res: 1}
		else:
			_add_loot(target, res)
			result["on_ground"] = 1
			result["resource"] = res
	return result

func _push(target: Vector2i, dir: Vector2i) -> Dictionary:
	var id := boulder_at(target)
	var boulder: Dictionary = boulders[id]
	if dir.y != 0:
		return {"action": "blocked", "reason": "boulder"}
	if int(config["player"]["strength"]) < int(boulder["weight"]):
		return {"action": "too_heavy", "weight": int(boulder["weight"]), "strength": int(config["player"]["strength"])}
	var beyond := target + dir
	if cell_at(beyond) != EMPTY or bool(boulder["falling"]):
		return {"action": "blocked", "reason": "boulder"}
	_set_cell(beyond.x, beyond.y, BOULDER)
	_set_cell(target.x, target.y, EMPTY)
	_shift_loot(beyond, target)
	boulder["pos"] = beyond
	var from := player
	player = target
	return {"action": "push", "id": id, "from": from, "to": target, "boulder_to": beyond, "picked": _collect(target)}

func _shift_loot(from: Vector2i, to: Vector2i) -> void:
	if loot.has(from):
		loot[to] = loot_at(to) + loot[from]
		loot.erase(from)

func step_boulders() -> Array:
	var events: Array = []
	var ids := boulders.keys()
	ids.sort_custom(func(a, b): return boulders[a]["pos"].y > boulders[b]["pos"].y)
	for id in ids:
		var boulder: Dictionary = boulders[id]
		var pos: Vector2i = boulder["pos"]
		var below := pos + Vector2i.DOWN
		if below == player:
			if bool(boulder["falling"]) and state == "mine":
				if stun_guard_left > 0.0:
					events.append({"type": "glance", "id": id, "at": pos})
				else:
					var p: Dictionary = config["player"]
					stun_left = float(p["stun_seconds"])
					stun_guard_left = stun_left + float(p["stun_guard_seconds"])
					events.append({"type": "hit_player", "id": id, "at": pos, "dropped": _drop_on_stun()})
			boulder["falling"] = false
		elif cell_at(below) == EMPTY:
			_set_cell(below.x, below.y, BOULDER)
			_set_cell(pos.x, pos.y, EMPTY)
			_shift_loot(below, pos)
			boulder["pos"] = below
			boulder["falling"] = true
			events.append({"type": "fall", "id": id, "from": pos, "to": below})
		elif bool(boulder["falling"]):
			boulder["falling"] = false
			events.append({"type": "land", "id": id, "at": pos})
	return events

func _drop_on_stun() -> Array:
	var units: Array = []
	for res in backpack:
		for _n in range(int(backpack[res])):
			units.append(res)
	var amount := ceili(units.size() * float(config["player"]["stun_drop_fraction"]))
	var spots: Array = []
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if cell_at(player + dir) == EMPTY:
			spots.append(player + dir)
	if spots.is_empty():
		spots.append(player)
	var dropped: Array = []
	for n in range(amount):
		var res: String = units.pop_at(rng.randi_range(0, units.size() - 1))
		var spot: Vector2i = spots[n % spots.size()]
		_take_unit(res)
		_add_loot(spot, res)
		dropped.append({"resource": res, "cell": spot})
	return dropped

func tick(delta: float) -> Array:
	var events: Array = []
	stun_left = maxf(0.0, stun_left - delta)
	stun_guard_left = maxf(0.0, stun_guard_left - delta)
	round_time += delta
	var active := float(config["round"]["active_seconds"])
	if state != "break" and round_time >= active:
		if state == "mine":
			var value := backpack_value()
			lost_value += value
			backpack.clear()
			events.append({"type": "collapse", "lost": value})
		else:
			events.append({"type": "break"})
		state = "break"
	if state == "break" and round_time >= active + float(config["round"]["break_seconds"]):
		round_index += 1
		generate(seed_value + 7919)
		round_time = 0.0
		state = "surface"
		events.append({"type": "new_round", "round": round_index})
	return events

func ride_up() -> int:
	var value := backpack_value()
	for res in backpack:
		banked[res] = int(banked.get(res, 0)) + int(backpack[res])
	banked_value += value
	backpack.clear()
	state = "surface"
	if value > 0:
		save_progress()
	return value

func descend() -> bool:
	if state != "surface":
		return false
	player = start_cell()
	facing = Vector2i.RIGHT
	state = "mine"
	return true

func debug_skip() -> void:
	round_time = maxf(round_time, float(config["round"]["debug_skip_to"]))

func time_left() -> float:
	return maxf(0.0, float(config["round"]["active_seconds"]) - round_time)

func break_left() -> float:
	return clampf(float(config["round"]["active_seconds"]) + float(config["round"]["break_seconds"]) - round_time, 0.0, float(config["round"]["break_seconds"]))

func backpack_mass() -> int:
	var total := 0
	for res in backpack:
		total += int(backpack[res]) * int(config["resources"][res]["mass"])
	return total

func backpack_value() -> int:
	var total := 0
	for res in backpack:
		total += int(backpack[res]) * int(config["resources"][res]["value"])
	return total

func is_heavy() -> bool:
	return backpack_mass() >= int(config["player"]["heavy_mass"])

func move_time() -> float:
	var p: Dictionary = config["player"]
	var base := float(p["move_time"])
	return base * float(p["slow_move_multiplier"]) if is_heavy() else base

func load_progress(path: String) -> void:
	save_path = path
	if path == "" or not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != SAVE_VERSION:
		return
	banked_value = maxi(0, int(parsed.get("banked_value", 0)))
	pick_level = clampi(int(parsed.get("pick_level", 0)), 0, config["upgrades"]["pick"].size())
	backpack_level = clampi(int(parsed.get("backpack_level", 0)), 0, config["upgrades"]["backpack"].size())

func save_progress() -> bool:
	if save_path == "":
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "banked_value": banked_value, "pick_level": pick_level, "backpack_level": backpack_level}))
	return true

func reachable(from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var queue: Array = [from]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if pos == to:
			return true
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = pos + dir
			if not seen.has(next) and is_passable(next):
				seen[next] = true
				queue.append(next)
	return false
