extends RefCounted

const PX = 32
const OUTLINE = Color("#120d0b")
const PALETTES = {
	"dirt": [Color("#3e2a1e"), Color("#5a3d29"), Color("#76523a"), Color("#94704f")],
	"stone": [Color("#2c3038"), Color("#434a55"), Color("#5d6673"), Color("#7f8996")],
	"coal": [Color("#26262b"), Color("#36373d"), Color("#4a4b52"), Color("#5e6068")],
	"copper": [Color("#3b2a26"), Color("#54403a"), Color("#6c5249"), Color("#86695c")],
	"gold": [Color("#2e2620"), Color("#463a2f"), Color("#5c4c3d"), Color("#776250")],
	"bedrock": [Color("#120f17"), Color("#1d1824"), Color("#2a2333"), Color("#3a3046")],
	"wall": [Color("#17120f"), Color("#1f1814"), Color("#271f1a"), Color("#30261f")],
}
const ORES = {
	"coal": [Color("#09090b"), Color("#17171b"), Color("#9fb3c8")],
	"copper": [Color("#8a3f1d"), Color("#d4733a"), Color("#ffc08a"), Color("#4fa38a")],
	"gold": [Color("#8f6412"), Color("#e8b52e"), Color("#fff1a6"), Color("#ffffff")],
}

var textures: Dictionary = {}
var miner_frames: Dictionary = {}

func build() -> void:
	for name in ["dirt", "stone", "coal", "copper", "gold", "bedrock", "wall"]:
		var list: Array = []
		for v in range(4):
			list.append(ImageTexture.create_from_image(_material(name, v)))
		textures[name] = list
	var scar_list: Array = []
	for v in range(3):
		scar_list.append(ImageTexture.create_from_image(_scar(v)))
	textures["scar"] = scar_list
	var crack_list: Array = []
	for stage in range(4):
		crack_list.append(ImageTexture.create_from_image(_cracks(stage)))
	textures["crack"] = crack_list
	for side in ["top", "bottom", "left", "right"]:
		textures["rim_" + side] = ImageTexture.create_from_image(_rim(side))
		textures["shade_" + side] = ImageTexture.create_from_image(_shade(side))
	textures["shaft"] = ImageTexture.create_from_image(_shaft())
	textures["cage"] = ImageTexture.create_from_image(_cage())
	textures["lamp"] = ImageTexture.create_from_image(_lamp())
	textures["boulder_1"] = ImageTexture.create_from_image(_boulder(1))
	textures["boulder_2"] = ImageTexture.create_from_image(_boulder(2))
	textures["boulder_3"] = ImageTexture.create_from_image(_boulder(3))
	textures["glow"] = ImageTexture.create_from_image(_glow(64))
	for res in ["coal", "copper", "gold"]:
		textures["icon_" + res] = ImageTexture.create_from_image(_icon(res))
		textures["hint_" + res] = ImageTexture.create_from_image(_hint(res))
	textures["star"] = ImageTexture.create_from_image(_star())
	for dir_name in ["up", "down", "left", "right"]:
		textures["arrow_" + dir_name] = ImageTexture.create_from_image(_arrow(dir_name))
	_build_miner()

func _star() -> Image:
	var img := _new_image(9, 9)
	for i in range(9):
		var a := 1.0 - absf(i - 4) / 5.0
		_put(img, Vector2i(i, 4), Color(1, 0.9, 0.3, a))
		_put(img, Vector2i(4, i), Color(1, 0.9, 0.3, a))
	_put(img, Vector2i(4, 4), Color.WHITE)
	_put(img, Vector2i(3, 3), Color(1, 0.95, 0.6))
	_put(img, Vector2i(5, 5), Color(1, 0.95, 0.6))
	_put(img, Vector2i(3, 5), Color(1, 0.95, 0.6))
	_put(img, Vector2i(5, 3), Color(1, 0.95, 0.6))
	return img

func _arrow(dir_name: String) -> Image:
	var img := _new_image(48, 48)
	for y in range(48):
		for x in range(48):
			var u := float(x - 24)
			var v := float(y - 24)
			var along := -v
			var across := u
			if dir_name == "down":
				along = v
			elif dir_name == "left":
				along = -u
				across = v
			elif dir_name == "right":
				along = u
				across = v
			if along < 14.0 and along > -12.0 and absf(across) < (14.0 - along) * 0.85:
				img.set_pixel(x, y, Color(1, 0.93, 0.78, 0.95))
	return img

func _new_image(w: int = PX, h: int = PX) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

func _noise(rng: RandomNumberGenerator, scale: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = scale
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n

func _material(name: String, v: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + v * 977
	var pal: Array = PALETTES[name]
	var img := _new_image()
	var n := _noise(rng, 0.11)
	var fine := _noise(rng, 0.45)
	for y in range(PX):
		for x in range(PX):
			var nx := posmod(x, PX)
			var value := n.get_noise_2d(nx, y) * 0.65 + fine.get_noise_2d(nx, y) * 0.35
			if name == "wall":
				value = n.get_noise_2d(nx * 0.4, y * 2.2) * 0.7 + fine.get_noise_2d(nx, y) * 0.3
			var idx := clampi(int((value + 0.6) * 2.6), 0, 3)
			img.set_pixel(x, y, pal[idx])
	if name == "stone" or name == "bedrock" or name == "copper" or name == "gold" or name == "coal":
		_slabs(img, rng, pal)
	if name == "dirt":
		for _p in range(5):
			_pebble(img, rng, Vector2i(rng.randi_range(2, 28), rng.randi_range(2, 28)), rng.randi_range(1, 2), pal[3], pal[0])
		for _r in range(2):
			var p := Vector2i(rng.randi_range(0, 31), rng.randi_range(0, 31))
			for _s in range(6):
				_put(img, p, pal[0])
				p += Vector2i(rng.randi_range(-1, 1), 1)
	if ORES.has(name):
		var ore: Array = ORES[name]
		var count: int = {"coal": 4, "copper": 4, "gold": 3}[name]
		for _o in range(count):
			_nugget(img, rng, Vector2i(rng.randi_range(5, 26), rng.randi_range(5, 26)), rng.randi_range(2, 3), ore, name)
	return img

func _slabs(img: Image, rng: RandomNumberGenerator, pal: Array) -> void:
	for _l in range(3):
		var p := Vector2i(rng.randi_range(0, 31), rng.randi_range(0, 31))
		var dir := Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
		for _s in range(rng.randi_range(8, 16)):
			_put(img, p, pal[0])
			_put(img, p + Vector2i(dir.y, dir.x), pal[3])
			p += dir
			if rng.randf() < 0.35:
				p += Vector2i(dir.y, dir.x) * (1 if rng.randf() < 0.5 else -1)

func _pebble(img: Image, rng: RandomNumberGenerator, c: Vector2i, r: int, light: Color, dark: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r - 1, r + 2):
			if x * x + y * y * 2 <= r * r + 2:
				_put(img, c + Vector2i(x, y), light.darkened(0.15 if y > 0 else 0.0))
	_put(img, c + Vector2i(0, r + 1), dark)
	_put(img, c + Vector2i(-1, -r), light.lightened(0.25))

func _nugget(img: Image, rng: RandomNumberGenerator, c: Vector2i, r: int, ore: Array, name: String) -> void:
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := x * x + y * y + rng.randi_range(-1, 1)
			if d <= r * r + 1:
				_put(img, c + Vector2i(x, y), OUTLINE if d >= r * r else ore[1])
	for y in range(-r + 1, r):
		for x in range(-r + 1, r):
			if x * x + y * y <= (r - 1) * (r - 1) and x + y < 0:
				_put(img, c + Vector2i(x, y), ore[min(2, ore.size() - 1)] if name != "coal" else ore[1])
	_put(img, c + Vector2i(-1, -1), ore[2])
	if name == "gold":
		_put(img, c + Vector2i(-1, -2), ore[3])
		_put(img, c + Vector2i(-2, -1), ore[3])
	if name == "copper" and rng.randf() < 0.7:
		_put(img, c + Vector2i(r, 0), ore[3])
		_put(img, c + Vector2i(r, 1), ore[3])
	_put(img, c + Vector2i(1, r), ore[0])

func _put(img: Image, p: Vector2i, color: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, color)

func _scar(v: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5551 + v
	var img := _new_image()
	for _m in range(4 + v):
		var p := Vector2i(rng.randi_range(3, 26), rng.randi_range(3, 22))
		for s in range(rng.randi_range(3, 6)):
			_put(img, p + Vector2i(s, s / 2), Color(0.55, 0.42, 0.32, 0.55))
			_put(img, p + Vector2i(s, s / 2 + 1), Color(0, 0, 0, 0.5))
	for x in range(PX):
		var h := 2 + int(abs(sin(x * 0.7 + v)) * 3.0) + rng.randi_range(0, 1)
		for y in range(PX - h, PX):
			var c: Color = PALETTES["dirt"][rng.randi_range(0, 2)]
			if y == PX - h:
				c = c.lightened(0.2)
			_put(img, Vector2i(x, y), c)
	for _r in range(5):
		_pebble(img, rng, Vector2i(rng.randi_range(2, 29), rng.randi_range(26, 29)), 1, PALETTES["stone"][2], PALETTES["stone"][0])
	return img

func _cracks(stage: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var img := _new_image()
	var c := Vector2i(16, 16)
	for branch in range(2 + stage * 2):
		var p := c
		var angle := rng.randf() * TAU
		for s in range(5 + stage * 3):
			angle += rng.randf_range(-0.6, 0.6)
			p += Vector2i(roundi(cos(angle) * 1.5), roundi(sin(angle) * 1.5))
			_put(img, p, Color(0.02, 0.01, 0.01, 0.95))
			_put(img, p + Vector2i(1, 0), Color(1, 0.95, 0.85, 0.35))
	return img

func _rim(side: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(side)
	var img := _new_image()
	for i in range(PX):
		var depth := 1 + rng.randi_range(0, 2)
		for d in range(depth + 2):
			var color := OUTLINE if d < depth else Color(0, 0, 0, 0.35)
			if side == "top" and d == depth:
				color = Color(1, 0.86, 0.66, 0.35)
			var p := Vector2i(i, d)
			if side == "bottom":
				p = Vector2i(i, PX - 1 - d)
			elif side == "left":
				p = Vector2i(d, i)
			elif side == "right":
				p = Vector2i(PX - 1 - d, i)
			_put(img, p, color)
	return img

func _shade(side: String) -> Image:
	var img := _new_image()
	for i in range(PX):
		for d in range(12):
			var a := 0.75 * pow(1.0 - d / 12.0, 1.6)
			var p := Vector2i(i, d)
			if side == "bottom":
				p = Vector2i(i, PX - 1 - d)
			elif side == "left":
				p = Vector2i(d, i)
			elif side == "right":
				p = Vector2i(PX - 1 - d, i)
			_put(img, p, Color(0, 0, 0, a))
	return img

func _shaft() -> Image:
	var img := _material("wall", 1)
	img.adjust_bcs(0.75, 0.8, 1.0)
	var wood := [Color("#3b2414"), Color("#6b4423"), Color("#8f6236")]
	for y in range(PX):
		for x in range(5):
			var c: Color = wood[1] if x > 0 and x < 4 else wood[0]
			if x == 1:
				c = wood[2]
			_put(img, Vector2i(x, y), c)
			_put(img, Vector2i(PX - 1 - x, y), c)
	for y in range(26, 31):
		for x in range(PX):
			_put(img, Vector2i(x, y), wood[0] if y == 26 or y == 30 else (wood[2] if y == 27 else wood[1]))
	for y in range(PX):
		_put(img, Vector2i(11, y), Color("#8d949c"))
		_put(img, Vector2i(20, y), Color("#8d949c"))
		_put(img, Vector2i(12, y), Color("#3a3f45"))
		_put(img, Vector2i(21, y), Color("#3a3f45"))
	for p in [Vector2i(2, 28), Vector2i(29, 28)]:
		_put(img, p, Color("#c4ccd4"))
	return img

func _cage() -> Image:
	var img := _new_image()
	var steel := [Color("#22272d"), Color("#4b545e"), Color("#8792a0"), Color("#c3ccd6")]
	for y in range(2, PX):
		for x in range(3, PX - 3):
			var edge := x <= 4 or x >= PX - 5 or y <= 3 or y >= PX - 3
			if edge:
				_put(img, Vector2i(x, y), steel[1] if x != 4 and y != 3 else steel[3])
			elif (x - 3) % 5 == 0 or (y - 2) % 6 == 0:
				_put(img, Vector2i(x, y), steel[0])
	for x in range(3, PX - 3):
		for y in range(PX - 6, PX - 2):
			_put(img, Vector2i(x, y), Color("#e8b52e") if ((x + y) / 3) % 2 == 0 else Color("#1a1a1a"))
	for y in range(0, 3):
		_put(img, Vector2i(15, y), steel[2])
		_put(img, Vector2i(16, y), steel[1])
	_outline(img)
	return img

func _lamp() -> Image:
	var img := _new_image(16, 24)
	for y in range(0, 6):
		_put(img, Vector2i(8, y), Color("#4b545e"))
	for x in range(4, 13):
		_put(img, Vector2i(x, 6), Color("#3a2a1a"))
		_put(img, Vector2i(x, 20), Color("#3a2a1a"))
	for y in range(7, 20):
		for x in range(4, 13):
			var glass := x > 4 and x < 12
			var c := Color("#ffd27a") if glass else Color("#3a2a1a")
			if glass and absi(x - 8) <= 1 and y > 10 and y < 17:
				c = Color("#fff7d6")
			_put(img, Vector2i(x, y), c)
	for x in range(5, 12):
		_put(img, Vector2i(x, 21), Color("#3a2a1a"))
	_outline(img)
	return img

func _boulder(weight: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + weight
	var img := _new_image()
	var pal: Array = [Color("#3a3530"), Color("#5f574d"), Color("#857a6b"), Color("#ada08c")]
	if weight >= 3:
		pal = [Color("#231f2a"), Color("#3a3444"), Color("#564d63"), Color("#7a7088")]
	elif weight == 2:
		pal = [Color("#2f3438"), Color("#4c555c"), Color("#6d7880"), Color("#97a2aa")]
	var r := 13.5 if weight >= 3 else (12.5 if weight == 2 else 11.0)
	var c := Vector2(16, 17)
	var n := _noise(rng, 0.25)
	for y in range(PX):
		for x in range(PX):
			var d := Vector2(x, y) - c
			var wobble := n.get_noise_2d(x, y) * 1.6
			if d.length() <= r + wobble:
				var light := -d.normalized().dot(Vector2(-0.6, -0.8).normalized()) if d.length() > 0.1 else 0.0
				var shade := d.length() / r * 0.6 + light * 0.5 + n.get_noise_2d(x * 3, y * 3) * 0.25
				_put(img, Vector2i(x, y), pal[clampi(int(3.2 - (shade + 0.3) * 2.4), 0, 3)])
	for _k in range(3 + weight):
		var p := Vector2i(rng.randi_range(9, 22), rng.randi_range(10, 24))
		for s in range(rng.randi_range(2, 5)):
			_put(img, p + Vector2i(s, s % 2), pal[0])
	_put(img, Vector2i(10, 9), Color(1, 1, 1, 0.8))
	_put(img, Vector2i(11, 9), Color(1, 1, 1, 0.5))
	_outline(img)
	return img

func _glow(size: int) -> Image:
	var img := _new_image(size, size)
	var c := Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := (Vector2(x, y) - c).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return img

func _icon(res: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(res)
	var img := _new_image(16, 16)
	_nugget(img, rng, Vector2i(8, 8), 5, ORES[res], res)
	_outline(img)
	return img

func _hint(res: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(res) + 4242
	var ore: Array = ORES[res]
	var img := _new_image()
	var stain: Color = ore[1]
	stain.a = 0.16
	for _b in range(2):
		var c := Vector2i(rng.randi_range(6, 25), rng.randi_range(6, 25))
		for y in range(-5, 6):
			for x in range(-5, 6):
				if x * x + y * y <= 22 + rng.randi_range(-4, 4):
					_put(img, c + Vector2i(x, y), stain)
	for _f in range(4):
		var p := Vector2i(rng.randi_range(3, 28), rng.randi_range(3, 28))
		_put(img, p, ore[1])
		_put(img, p + Vector2i(1, 0), ore[0])
		_put(img, p + Vector2i(0, -1), ore[min(2, ore.size() - 1)])
	return img

func _outline(img: Image) -> void:
	var src := img.duplicate()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if src.get_pixel(x, y).a > 0.1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and src.get_pixelv(p).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break

func _build_miner() -> void:
	var poses := {
		"idle": [{"bob": 0, "legs": 0, "pick": 2.3}, {"bob": 1, "legs": 0, "pick": 2.25}],
		"walk": [{"bob": 0, "legs": 1, "pick": 2.1}, {"bob": 1, "legs": 0, "pick": 2.2}, {"bob": 0, "legs": -1, "pick": 2.1}, {"bob": 1, "legs": 0, "pick": 2.2}],
		"dig": [{"bob": 0, "legs": 0, "pick": -2.2}, {"bob": 0, "legs": 0, "pick": -0.9}, {"bob": 1, "legs": 0, "pick": 0.35}],
		"stun": [{"bob": 1, "legs": 0, "pick": 2.6, "stun": true}],
	}
	for anim in poses:
		var frames: Array = []
		for pose in poses[anim]:
			frames.append(ImageTexture.create_from_image(_miner(pose)))
		miner_frames[anim] = frames

func _miner(pose: Dictionary) -> Image:
	var img := _new_image()
	var bob := int(pose["bob"])
	var legs := int(pose["legs"])
	var skin := Color("#e9a97c")
	var skin_dark := Color("#b8714d")
	var blue := Color("#3f73b8")
	var blue_dark := Color("#294c82")
	var shirt := Color("#c2543a")
	var boot := Color("#4a2f1d")
	var helmet := Color("#f2b632")
	var helmet_dark := Color("#b97a1f")
	for side: int in [-1, 1]:
		var lx := 13 if side < 0 else 17
		var off: int = legs * side
		for y in range(23, 29):
			_rect(img, lx + off, y, 3, 1, blue_dark if side < 0 else blue)
		_rect(img, lx + off - (0 if side < 0 else 0), 29, 4, 2, boot)
	_rect(img, 11, 14 + bob, 10, 9, shirt)
	_rect(img, 12, 16 + bob, 8, 8, blue)
	_rect(img, 12, 14 + bob, 2, 3, blue)
	_rect(img, 18, 14 + bob, 2, 3, blue)
	_rect(img, 14, 18 + bob, 4, 2, blue_dark)
	_rect(img, 11, 22 + bob, 10, 1, Color("#5b3a1f"))
	_rect(img, 16, 22 + bob, 2, 1, Color("#d9b35a"))
	_rect(img, 12, 7 + bob, 9, 7, skin)
	_rect(img, 12, 12 + bob, 9, 2, skin_dark)
	_rect(img, 18, 9 + bob, 1, 2, OUTLINE)
	_rect(img, 20, 10 + bob, 2, 2, skin)
	_rect(img, 13, 12 + bob, 6, 2, Color("#6b4a32"))
	if pose.get("stun", false):
		_rect(img, 18, 9 + bob, 1, 1, Color("#ffffff"))
		_rect(img, 17, 10 + bob, 2, 1, OUTLINE)
	_rect(img, 11, 4 + bob, 11, 4, helmet)
	_rect(img, 12, 3 + bob, 8, 1, helmet)
	_rect(img, 10, 7 + bob, 14, 1, helmet_dark)
	_rect(img, 13, 3 + bob, 3, 1, Color("#ffe08a"))
	_rect(img, 21, 4 + bob, 2, 3, Color("#d8dde3"))
	_rect(img, 23, 4 + bob, 1, 3, Color("#fff6c8"))
	var shoulder := Vector2(17, 16 + bob)
	var angle := float(pose["pick"])
	var hand := shoulder + Vector2(cos(angle), sin(angle)) * 5.0
	_line(img, shoulder, hand, shirt, 2)
	_rect(img, int(hand.x) - 1, int(hand.y) - 1, 3, 3, Color("#7a4a28"))
	var tip := hand + Vector2(cos(angle), sin(angle)) * 9.0
	_line(img, hand - Vector2(cos(angle), sin(angle)) * 3.0, tip, Color("#a0703c"), 1)
	var head_dir := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5))
	_line(img, tip - head_dir * 5.0, tip + head_dir * 5.0, Color("#9aa6b2"), 2)
	_line(img, tip + head_dir * 5.0, tip + head_dir * 6.5 - Vector2(cos(angle), sin(angle)) * 1.5, Color("#dfe6ee"), 1)
	_line(img, tip - head_dir * 5.0, tip - head_dir * 6.5 - Vector2(cos(angle), sin(angle)) * 1.5, Color("#dfe6ee"), 1)
	_outline(img)
	return img

func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, Vector2i(xx, yy), color)

func _line(img: Image, a: Vector2, b: Vector2, color: Color, thickness: int) -> void:
	var steps := int(ceil(a.distance_to(b) * 2.0)) + 1
	for s in range(steps + 1):
		var p := a.lerp(b, float(s) / float(max(steps, 1)))
		for t in range(thickness):
			_put(img, Vector2i(roundi(p.x) + t % 2, roundi(p.y) + t / 2), color)
