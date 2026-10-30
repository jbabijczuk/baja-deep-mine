extends Node2D

const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const CELL = 64
const MARGIN = 2
const SIDES = {"top": Vector2i.UP, "bottom": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

var model
var art
var drawn_range := Rect2i()

func setup(model_ref, art_ref) -> void:
	model = model_ref
	art = art_ref
	refresh()

func refresh() -> void:
	drawn_range = Rect2i()
	queue_redraw()

func _process(_delta: float) -> void:
	if model == null:
		return
	var range := _visible_range()
	if not drawn_range.encloses(range):
		drawn_range = range.grow(MARGIN)
		queue_redraw()

func _visible_range() -> Rect2i:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var rect: Rect2 = inv * get_viewport_rect()
	var a := Vector2i(floori(rect.position.x / CELL), floori(rect.position.y / CELL))
	var b := Vector2i(ceili(rect.end.x / CELL), ceili(rect.end.y / CELL))
	return Rect2i(a, b - a)

func tint(pos: Vector2i) -> Color:
	var depth := clampf(float(pos.y - model.station_y) / 50.0, 0.0, 1.0)
	var dist := clampf(Vector2(pos - model.elevator_cell()).length() / 34.0, 0.0, 1.0)
	var k := 1.0 - 0.45 * maxf(depth, dist)
	return Color(k, k * (1.0 - 0.06 * depth), k * (1.0 + 0.04 * depth), 1.0)

func _draw() -> void:
	if model == null or art == null:
		return
	var r := drawn_range if drawn_range.size != Vector2i.ZERO else _visible_range().grow(MARGIN)
	var x0 := maxi(r.position.x, 0)
	var y0 := maxi(r.position.y, 0)
	var x1 := mini(r.end.x, model.width)
	var y1 := mini(r.end.y, model.height)
	for y in range(y0, y1):
		for x in range(x0, x1):
			_draw_cell(Vector2i(x, y))

func _draw_cell(pos: Vector2i) -> void:
	var i: int = pos.y * model.width + pos.x
	var t: int = model.cells[i]
	var rect := Rect2(pos * CELL, Vector2(CELL, CELL))
	var v: int = model.variants[i]
	var col := tint(pos)
	if t == MineModel.SHAFT or t == MineModel.ELEVATOR:
		draw_texture_rect(art.textures["shaft"], rect, false, col)
		return
	if MineModel.is_material(t) or t == MineModel.BEDROCK:
		var name: String = "bedrock" if t == MineModel.BEDROCK else MineModel.MATERIAL_NAMES[t]
		draw_texture_rect(art.textures[name][v], rect, false, col)
		var hint: int = model.hints[i]
		if hint > 0:
			draw_texture_rect(art.textures["hint_" + MineModel.MATERIAL_NAMES[hint]], rect, false, col)
		for side in SIDES:
			if _is_open(pos + SIDES[side]):
				draw_texture_rect(art.textures["rim_" + side], rect, false)
		if MineModel.is_material(t):
			var mx: int = model.max_hp(t)
			var left: int = model.hp[i]
			if left < mx:
				var stage := clampi(int(float(mx - left) / float(mx) * 4.0), 0, 3)
				draw_texture_rect(art.textures["crack"][stage], rect, false)
		return
	draw_texture_rect(art.textures["wall"][v], rect, false, col)
	if model.scars[i] > 0:
		draw_texture_rect(art.textures["scar"][model.scars[i] - 1], rect, false, col)
	for side in SIDES:
		if not _is_open(pos + SIDES[side]):
			draw_texture_rect(art.textures["shade_" + side], rect, false)
	var pile: Array = model.loot_at(pos)
	for n in range(pile.size()):
		var offset := Vector2(14 + (n % 3) * 12, CELL - 30 - (n / 3) * 10)
		draw_texture_rect(art.textures["icon_" + pile[n]], Rect2(rect.position + offset, Vector2(24, 24)), false)

func _is_open(pos: Vector2i) -> bool:
	if pos.y < 0:
		return false
	var t: int = model.cell_at(pos)
	return t == MineModel.EMPTY or t == MineModel.BOULDER
