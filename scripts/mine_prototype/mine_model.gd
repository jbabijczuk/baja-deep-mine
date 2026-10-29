extends RefCounted

const DATA_PATH = "res://data/mine_prototype.json"
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

var config: Dictionary = {}
var width: int = 0
var height: int = 0
var seed_value: int = 0
var cells := PackedByteArray()
var hp := PackedByteArray()
var variants := PackedByteArray()
var scars := PackedByteArray()
var boulders: Dictionary = {}
var lamps: Array = []
var shaft_x: int = 0
var station_y: int = 0
var player := Vector2i.ZERO
var facing := Vector2i.RIGHT
var stun_left: float = 0.0
var backpack: Dictionary = {}
var banked: Dictionary = {}
var banked_value: int = 0
var lost_value: int = 0
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
	boulders.clear()
	backpack.clear()
	for y in range(height):
		for x in range(width):
			var i := y * width + x
			var t := _roll_material(y)
			if x == 0 or x == width - 1 or y == height - 1:
				t = BEDROCK
			_set_cell(x, y, t)
			variants[i] = rng.randi_range(0, 3)
			scars[i] = 0
	_carve_caves(int(m["caves"]))
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
	lamps.clear()
	for offset in m["lamp_offsets"]:
		lamps.append(Vector2i(shaft_x + int(offset[0]), station_y + int(offset[1])))
	player = start_cell()
	facing = Vector2i.RIGHT
	stun_left = 0.0
	state = "mine"

func start_cell() -> Vector2i:
	return Vector2i(shaft_x + 1, station_y)

func elevator_cell() -> Vector2i:
	return Vector2i(shaft_x, station_y)

func _roll_material(y: int) -> int:
	var weights: Dictionary = {}
	for layer in config["layers"]:
		weights = layer["weights"]
		if y < int(layer["until"]):
			break
	var total := 0
	for key in weights:
		total += int(weights[key])
	var roll := rng.randi_range(1, max(total, 1))
	for key in weights:
		roll -= int(weights[key])
		if roll <= 0:
			return MATERIAL_NAMES.find(key)
	return DIRT

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
		if not is_material(cell_at(pos)) or not is_material(cell_at(pos + Vector2i.DOWN)):
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
		return {"action": "move", "from": from, "to": target}
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
	hp[i] = max(0, int(hp[i]) - int(config["player"]["pick_power"]))
	if hp[i] > 0:
		return {"action": "hit", "cell": target, "material": name, "hp": int(hp[i]), "max": max_hp(t)}
	cells[i] = EMPTY
	scars[i] = rng.randi_range(1, 3)
	var result := {"action": "break", "cell": target, "material": name, "drops": {}, "lost": 0}
	var mat: Dictionary = config["materials"][name]
	if mat.has("drop"):
		var res: String = mat["drop"]
		var amount := rng.randi_range(int(mat["drop_min"]), int(mat["drop_max"]))
		var unit_mass := int(config["resources"][res]["mass"])
		var taken := 0
		for _n in range(amount):
			if backpack_mass() + unit_mass > int(config["player"]["capacity"]):
				break
			backpack[res] = int(backpack.get(res, 0)) + 1
			taken += 1
		result["drops"] = {res: taken}
		result["lost"] = amount - taken
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
	boulder["pos"] = beyond
	var from := player
	player = target
	return {"action": "push", "id": id, "from": from, "to": target, "boulder_to": beyond}

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
				stun_left = float(config["player"]["stun_seconds"])
				events.append({"type": "hit_player", "id": id, "at": pos})
			boulder["falling"] = false
		elif cell_at(below) == EMPTY:
			_set_cell(below.x, below.y, BOULDER)
			_set_cell(pos.x, pos.y, EMPTY)
			boulder["pos"] = below
			boulder["falling"] = true
			events.append({"type": "fall", "id": id, "from": pos, "to": below})
		elif bool(boulder["falling"]):
			boulder["falling"] = false
			events.append({"type": "land", "id": id, "at": pos})
	return events

func tick(delta: float) -> Array:
	var events: Array = []
	stun_left = maxf(0.0, stun_left - delta)
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

func move_time() -> float:
	var p: Dictionary = config["player"]
	var base := float(p["move_time"])
	if backpack_mass() >= float(p["capacity"]) * float(p["slow_load_fraction"]):
		return base * float(p["slow_move_multiplier"])
	return base

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
