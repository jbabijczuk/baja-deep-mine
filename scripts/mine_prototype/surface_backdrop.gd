extends Node2D

const CELL = 64

var map_width: int = 48
var shaft_x: int = 14

func setup(width_cells: int, shaft_column: int) -> void:
	map_width = width_cells
	shaft_x = shaft_column
	queue_redraw()

func _draw() -> void:
	var w := float(map_width * CELL)
	var top := -1400.0
	var sky_top := Color("#0b1026")
	var sky_mid := Color("#2a2550")
	var sky_low := Color("#c0644a")
	_gradient(Rect2(-400, top, w + 800, 900), sky_top, sky_mid)
	_gradient(Rect2(-400, top + 900, w + 800, -top - 900), sky_mid, sky_low)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for _s in range(90):
		var p := Vector2(rng.randf_range(-400, w + 400), rng.randf_range(top, top + 900))
		draw_rect(Rect2(p, Vector2(2, 2) * rng.randi_range(1, 2)), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	draw_circle(Vector2(w * 0.72, -560), 46, Color("#f6e7c1"))
	draw_circle(Vector2(w * 0.72 + 14, -570), 40, Color("#2a2550").lerp(Color("#f6e7c1"), 0.15))
	_hills(w, -220.0, 160.0, Color("#3a2a44"), 3)
	_hills(w, -120.0, 90.0, Color("#271c2e"), 7)
	draw_rect(Rect2(-400, -40, w + 800, 40), Color("#2c1f18"))
	draw_rect(Rect2(-400, -48, w + 800, 10), Color("#3f5a2c"))
	for x in range(-400, int(w) + 400, 8):
		draw_rect(Rect2(x, -52 - (x * 7 % 5), 4, 6), Color("#567a37"))
	_headframe(float(shaft_x * CELL + CELL / 2))
	_shack(float((shaft_x + 3) * CELL))

func _gradient(rect: Rect2, a: Color, b: Color) -> void:
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(pts, PackedColorArray([a, a, b, b]))

func _hills(w: float, base: float, amp: float, color: Color, freq: int) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(-400, 0))
	for i in range(0, 61):
		var x := -400.0 + (w + 800.0) * i / 60.0
		pts.append(Vector2(x, base - amp * (0.5 + 0.5 * sin(i * 0.37 * freq / 3.0) * cos(i * 0.11 * freq))))
	pts.append(Vector2(w + 400, 0))
	draw_colored_polygon(pts, color)

func _headframe(cx: float) -> void:
	var steel := Color("#1b1d24")
	var light := Color("#3b4150")
	draw_line(Vector2(cx - 70, -40), Vector2(cx - 18, -330), steel, 10)
	draw_line(Vector2(cx + 70, -40), Vector2(cx + 18, -330), steel, 10)
	draw_line(Vector2(cx + 70, -40), Vector2(cx + 170, -200), steel, 8)
	for i in range(1, 6):
		var y := -40.0 - i * 52.0
		var half := 70.0 - i * 9.5
		draw_line(Vector2(cx - half, y), Vector2(cx + half, y), light, 4)
		draw_line(Vector2(cx - half, y), Vector2(cx + half - 9, y - 52), light, 3)
	draw_circle(Vector2(cx, -340), 34, steel)
	draw_arc(Vector2(cx, -340), 28, 0, TAU, 24, Color("#8d949c"), 4)
	for k in range(6):
		var a := k * TAU / 6.0
		draw_line(Vector2(cx, -340), Vector2(cx, -340) + Vector2(cos(a), sin(a)) * 26, Color("#5d6673"), 3)
	draw_line(Vector2(cx - 10, -340), Vector2(cx - 10, 0), Color("#8d949c"), 2)
	draw_line(Vector2(cx + 10, -340), Vector2(cx + 10, 0), Color("#8d949c"), 2)
	draw_circle(Vector2(cx, -380), 6, Color("#ff5a4a"))

func _shack(x: float) -> void:
	draw_rect(Rect2(x, -150, 170, 110), Color("#3b2618"))
	for i in range(0, 170, 17):
		draw_line(Vector2(x + i, -150), Vector2(x + i, -40), Color("#2a1a10"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 16, -150), Vector2(x + 85, -205), Vector2(x + 186, -150)]), Color("#22161d"))
	draw_rect(Rect2(x + 30, -120, 36, 30), Color("#ffcf6e"))
	draw_rect(Rect2(x + 105, -120, 36, 30), Color("#ffcf6e"))
	draw_line(Vector2(x + 48, -120), Vector2(x + 48, -90), Color("#3b2618"), 3)
	draw_line(Vector2(x + 123, -120), Vector2(x + 123, -90), Color("#3b2618"), 3)
