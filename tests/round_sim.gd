extends SceneTree

const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const SEEDS = [20261029, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const NEAREST_ORE = Vector2i(-1, -1)

func _initialize() -> void:
	for pick_level in [0, 1]:
		for seed_value in SEEDS:
			var line := "SIM pick_level=%d seed=%d" % [pick_level, seed_value]
			for ore in [0, MineModel.COPPER, MineModel.GOLD]:
				var copy = MineModel.new()
				copy.generate(seed_value)
				copy.pick_level = pick_level
				var r := simulate(copy, 3 if ore == 0 else 1, 1.0, ore)
				line += " %s: first=%.1f trips=%s" % ["any" if ore == 0 else MineModel.MATERIAL_NAMES[ore], r["first_ore"], r["trips"].map(func(t): return snappedf(t, 0.1))]
			print(line)
	quit()

static func simulate(m, nuggets: int, break_factor: float = 1.0, ore: int = 0) -> Dictionary:
	var elapsed := 0.0
	var pos: Vector2i = m.player
	var trips: Array = []
	var ores: Array = []
	var first_ore := -1.0
	for _n in range(nuggets):
		var leg := _route(m, pos, NEAREST_ORE, break_factor, ore)
		if leg.is_empty():
			break
		elapsed += float(leg["cost"])
		pos = leg["path"].back()
		var res: String = m.config["materials"][MineModel.MATERIAL_NAMES[m.cell_at(pos)]]["drop"]
		for cell in leg["path"]:
			if MineModel.is_material(m.cell_at(cell)):
				m._set_cell(cell.x, cell.y, MineModel.EMPTY)
		m.backpack[res] = int(m.backpack.get(res, 0)) + 1
		ores.append(res)
		if first_ore < 0.0:
			first_ore = elapsed
		trips.append(elapsed + float(_route(m, pos, m.elevator_cell(), break_factor)["cost"]))
	return {"first_ore": first_ore, "trips": trips, "ores": ores}

static func enter_cost(m, pos: Vector2i, break_factor: float = 1.0) -> float:
	var t: int = m.cell_at(pos)
	if t == MineModel.EMPTY or t == MineModel.ELEVATOR:
		return m.move_time()
	if not MineModel.is_material(t) or m.cell_at(pos + Vector2i.UP) == MineModel.BOULDER:
		return -1.0
	var hits := ceili(float(m.hp_at(pos)) / float(m.pick_power()))
	return (hits - 1 + break_factor) * float(m.config["player"]["dig_interval"]) + m.move_time()

static func _route(m, from: Vector2i, goal: Vector2i, break_factor: float, ore: int = 0) -> Dictionary:
	var dist := {from: 0.0}
	var prev := {}
	var heap: Array = [[0.0, from]]
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var pos: Vector2i = top[1]
		if top[0] > dist[pos]:
			continue
		if pos == goal or (goal == NEAREST_ORE and MineModel.is_ore(m.cell_at(pos)) and (ore == 0 or m.cell_at(pos) == ore)):
			var path: Array = [pos]
			while prev.has(path[0]):
				path.push_front(prev[path[0]])
			return {"cost": top[0], "path": path}
		for dir in MineModel.DIRS:
			var next: Vector2i = pos + dir
			var step := enter_cost(m, next, break_factor)
			if step < 0.0:
				continue
			var cost: float = top[0] + step
			if cost < float(dist.get(next, INF)):
				dist[next] = cost
				prev[next] = pos
				_push(heap, [cost, next])
	return {}

static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0 and heap[(i - 1) / 2][0] > heap[i][0]:
		var parent := (i - 1) / 2
		var tmp: Array = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent

static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	while true:
		var smallest := i
		for child in [i * 2 + 1, i * 2 + 2]:
			if child < heap.size() and heap[child][0] < heap[smallest][0]:
				smallest = child
		if smallest == i:
			break
		var tmp: Array = heap[smallest]
		heap[smallest] = heap[i]
		heap[i] = tmp
		i = smallest
	return top
