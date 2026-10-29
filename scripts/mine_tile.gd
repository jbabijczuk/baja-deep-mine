extends Button

const ACCENTS = {
	"dirt": Color("#3a2b21"),
	"rock": Color("#9fb3c8"),
	"copper": Color("#ff9d5c"),
	"gold": Color("#ffe27a"),
	"gem": Color("#d2b4ff"),
	"core": Color("#62ffdc"),
	"heart": Color("#ff5ca0"),
}

var tile_type: String = "dirt"
var base_color: Color = Color("#675447")
var hp: int = 1
var max_hp: int = 1
var dug: bool = false
var diggable: bool = false
var pattern_seed: int = 0
var flash: float = 0.0:
	set(value):
		flash = value
		queue_redraw()
var burst: float = 0.0:
	set(value):
		burst = value
		queue_redraw()

func setup(type_name: String, color: Color, hp_value: int, max_hp_value: int, is_dug: bool, can_dig: bool, index: int) -> void:
	tile_type = type_name
	base_color = color
	hp = hp_value
	max_hp = maxi(1, max_hp_value)
	dug = is_dug
	diggable = can_dig
	pattern_seed = 7349 + index * 104729
	disabled = not diggable
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if diggable else Control.CURSOR_ARROW
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, empty)

func play_hit() -> void:
	var tween := create_tween()
	if dug:
		burst = 0.01
		tween.tween_property(self, "burst", 1.0, 0.35)
	else:
		flash = 1.0
		tween.tween_property(self, "flash", 0.0, 0.22)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-2.0)
	if get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED:
		r = r.grow(-3.0)
	r.position.x += sin(flash * 40.0) * 4.0 * flash
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	if dug:
		_draw_tunnel(r, rng)
	else:
		_draw_block(r, rng)
		_draw_damage(r)
		if diggable:
			draw_rect(r, Color(1.0, 0.92, 0.68, 0.95 if is_hovered() else 0.6), false, 3.0)
		else:
			draw_rect(r, Color(0.01, 0.02, 0.05, 0.62))
	if flash > 0.0:
		draw_rect(r, Color(1.0, 1.0, 0.9, flash * 0.65))
	if burst > 0.0 and burst < 1.0:
		_draw_burst(r)

func _draw_tunnel(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("#06080d"))
	draw_rect(r.grow(-r.size.x * 0.08), Color("#0c111a"))
	draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.2, r.size.x, r.size.y * 0.2), Color("#151b26"))
	for n in range(3):
		var p := Vector2(r.position.x + r.size.x * rng.randf_range(0.15, 0.85), r.end.y - r.size.y * rng.randf_range(0.06, 0.16))
		draw_circle(p, rng.randf_range(1.5, 3.5), Color("#232c3a"))

func _draw_block(r: Rect2, rng: RandomNumberGenerator) -> void:
	var inner := r.grow(-3.0)
	draw_rect(r, base_color.darkened(0.45))
	draw_rect(inner, base_color.darkened(0.1))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), base_color)
	draw_line(inner.position, Vector2(inner.end.x, inner.position.y), base_color.lightened(0.35), 2.0)
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	var accent: Color = ACCENTS.get(tile_type, Color.WHITE)
	match tile_type:
		"dirt":
			for n in range(10):
				draw_circle(_rand_point(inner, rng), rng.randf_range(1.5, 3.5), accent if n % 2 == 0 else base_color.lightened(0.25))
		"rock":
			var facet := PackedVector2Array([c + Vector2(-0.4, -0.1) * s, c + Vector2(-0.05, -0.38) * s, c + Vector2(0.35, -0.18) * s, c + Vector2(0.1, 0.05) * s])
			draw_colored_polygon(facet, base_color.lightened(0.18))
			for n in range(3):
				draw_polyline(_jagged(_rand_point(inner, rng), _rand_point(inner, rng), rng, 4, s * 0.08), base_color.darkened(0.55), 2.0)
			draw_line(c + Vector2(-0.05, -0.38) * s, c + Vector2(0.1, 0.05) * s, accent, 1.5)
		"copper":
			for n in range(2):
				var y := inner.position.y + inner.size.y * (0.35 + 0.3 * n)
				draw_polyline(_jagged(Vector2(inner.position.x, y), Vector2(inner.end.x, y - s * 0.15), rng, 6, s * 0.1), accent, 3.5)
			for n in range(4):
				draw_circle(_rand_point(inner, rng), rng.randf_range(2.0, 3.5), accent.lightened(0.3))
		"gold":
			draw_polyline(_jagged(Vector2(inner.position.x, inner.end.y - s * 0.2), Vector2(inner.end.x, inner.position.y + s * 0.2), rng, 6, s * 0.08), accent.darkened(0.2), 3.0)
			for n in range(3):
				var p := _rand_point(inner.grow(-s * 0.12), rng)
				var k := rng.randf_range(0.09, 0.14) * s
				var nugget := PackedVector2Array([p + Vector2(-k, 0), p + Vector2(-k * 0.3, -k * 0.8), p + Vector2(k * 0.8, -k * 0.5), p + Vector2(k, k * 0.4), p + Vector2(0, k * 0.8)])
				draw_colored_polygon(nugget, accent)
				draw_circle(p + Vector2(-k * 0.2, -k * 0.3), k * 0.25, Color(1, 1, 0.9, 0.9))
		"gem":
			draw_circle(c, s * 0.42, Color(accent, 0.18))
			draw_circle(c, s * 0.3, Color(accent, 0.22))
			var crystal := PackedVector2Array([c + Vector2(0, -0.38) * s, c + Vector2(0.22, -0.1) * s, c + Vector2(0.14, 0.3) * s, c + Vector2(-0.14, 0.3) * s, c + Vector2(-0.22, -0.1) * s])
			draw_colored_polygon(crystal, accent)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.38) * s, c + Vector2(0.22, -0.1) * s, c + Vector2(0, 0.0) * s, c + Vector2(-0.22, -0.1) * s]), accent.lightened(0.45))
			draw_line(c, c + Vector2(0, 0.3) * s, accent.darkened(0.3), 1.5)
			draw_circle(c + Vector2(0.3, -0.3) * s, 2.5, Color.WHITE)
		"core":
			draw_circle(c, s * 0.44, Color(accent, 0.15))
			draw_circle(c, s * 0.32, Color(accent, 0.25))
			for n in range(8):
				var dir := Vector2.from_angle(TAU * n / 8.0)
				draw_line(c + dir * s * 0.24, c + dir * s * 0.4, Color(accent, 0.8), 2.0)
			draw_arc(c, s * 0.22, 0.0, TAU, 24, accent, 3.0)
			draw_circle(c, s * 0.13, accent.lightened(0.4))
			draw_circle(c, s * 0.06, Color.WHITE)
		"heart":
			draw_circle(c, s * 0.42, Color(0.05, 0.0, 0.03, 0.45))
			draw_circle(c, s * 0.34, Color(accent, 0.2))
			var heart := PackedVector2Array()
			for n in range(32):
				var t := TAU * n / 32.0
				heart.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * s * 0.017)
			draw_colored_polygon(heart, accent)
			draw_polyline(_jagged(c + Vector2(0, -0.12) * s, c + Vector2(0, 0.2) * s, rng, 4, s * 0.05), Color("#2a0614"), 2.0)

func _draw_damage(r: Rect2) -> void:
	var damage := 1.0 - float(hp) / float(max_hp)
	if damage > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = pattern_seed + 1
		var c := r.get_center()
		var s := minf(r.size.x, r.size.y)
		for n in range(int(ceil(damage * 5.0))):
			var dir := Vector2.from_angle(rng.randf() * TAU)
			draw_polyline(_jagged(c, c + dir * s * rng.randf_range(0.35, 0.55), rng, 4, s * 0.06), Color(0.0, 0.0, 0.0, 0.8), 2.5)
	if max_hp > 1:
		var gap := 3.0
		var width := (r.size.x * 0.6 - gap * (max_hp - 1)) / max_hp
		var start := Vector2(r.position.x + r.size.x * 0.2, r.end.y - 10.0)
		for k in range(max_hp):
			var pip := Rect2(start + Vector2((width + gap) * k, 0), Vector2(width, 5.0))
			draw_rect(pip.grow(1.0), Color(0, 0, 0, 0.7))
			draw_rect(pip, Color("#f2efd9") if k < hp else Color("#3b2a2a"))

func _draw_burst(r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	for n in range(10):
		var dir := Vector2.from_angle(TAU * n / 10.0 + 0.3)
		var p := c + dir * s * 0.5 * burst
		var k := 6.0 * (1.0 - burst) + 1.0
		draw_rect(Rect2(p - Vector2(k, k) * 0.5, Vector2(k, k)), Color(base_color.lightened(0.2), 1.0 - burst))
	draw_circle(c, s * 0.45 * burst, Color(1.0, 0.95, 0.8, 0.35 * (1.0 - burst)))

func _rand_point(r: Rect2, rng: RandomNumberGenerator) -> Vector2:
	return r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)

func _jagged(from: Vector2, to: Vector2, rng: RandomNumberGenerator, segments: int, amplitude: float) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var normal := (to - from).orthogonal().normalized()
	for n in range(1, segments):
		points.append(from.lerp(to, float(n) / segments) + normal * rng.randf_range(-amplitude, amplitude))
	points.append(to)
	return points
