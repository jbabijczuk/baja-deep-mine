extends Control

const MineModel = preload("res://scripts/mine_prototype/mine_model.gd")
const PLAY_SCENE = "res://scenes/MinePrototype.tscn"
const SKY = Color("#0b0d18")
const GRASS = Color("#2f3a24")
const STRATA = [Color("#3b2a1c"), Color("#2e2118"), Color("#241a16"), Color("#1b1517"), Color("#130f14")]
const ORE_COLORS = [Color("#4a4b52"), Color("#d4733a"), Color("#e8b52e")]

var save_path: String = MineModel.SAVE_PATH
var play_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func has_progress() -> bool:
	return FileAccess.file_exists(save_path)

func play_label() -> String:
	return "KONTYNUUJ" if has_progress() else "GRAJ"

func _draw() -> void:
	var w := size.x
	var h := size.y
	var surface := h * 0.46
	draw_rect(Rect2(0, 0, w, surface), SKY)
	draw_rect(Rect2(0, surface - 10, w, 14), GRASS)
	var band := (h - surface) / STRATA.size()
	for i in range(STRATA.size()):
		draw_rect(Rect2(0, surface + 4 + band * i, w, band + 1), STRATA[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2501
	for _n in range(70):
		var pos := Vector2(rng.randf() * w, surface + 24 + rng.randf() * (h - surface - 24))
		var depth := (pos.y - surface) / (h - surface)
		var color: Color = ORE_COLORS[mini(int(depth * ORE_COLORS.size()), ORE_COLORS.size() - 1)] if rng.randf() < 0.35 else Color(0, 0, 0, 0.25)
		draw_circle(pos, 3.0 + rng.randf() * 5.0, color)
	var shaft_x := w * 0.5
	draw_rect(Rect2(shaft_x - 34, surface - 30, 68, h - surface + 30), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(shaft_x - 46, surface - 38, 92, 12), Color("#5a3d22"))

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.add_child(_title("DEEP MINE", 76, "#ffcf6e"))
	box.add_child(_title("CURSED DEPTHS", 34, "#e0a050"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 220)
	box.add_child(gap)
	play_button = Button.new()
	play_button.text = play_label()
	play_button.focus_mode = Control.FOCUS_NONE
	play_button.custom_minimum_size = Vector2(440, 128)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.add_theme_font_size_override("font_size", 46)
	play_button.add_theme_color_override("font_color", Color("#ffe6b8"))
	play_button.add_theme_stylebox_override("normal", _button_style(Color("#3a2514")))
	play_button.add_theme_stylebox_override("hover", _button_style(Color("#55361c")))
	play_button.add_theme_stylebox_override("pressed", _button_style(Color("#22160c")))
	play_button.pressed.connect(_play)
	box.add_child(play_button)

func _title(text_value: String, font_size: int, color: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color))
	label.add_theme_color_override("font_outline_color", Color("#120c08"))
	label.add_theme_constant_override("outline_size", 10)
	return label

func _button_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color("#e0a050")
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	return style

func _play() -> void:
	get_tree().change_scene_to_file(PLAY_SCENE)
