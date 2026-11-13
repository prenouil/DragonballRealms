# Fabrique l'image de chaque carte et du dos des cartes (rendue une fois dans un SubViewport).
# Recto : valeur, nom codé, famille et BdC lisibles ; illustration et texte floutés.
# Pour remplacer l'illustration d'une carte : déposer res://cards/art/<numéro>.png.

extends Node

const CardDB = preload("res://scripts/card_db.gd")

const W := 256
const H := 358

const BLUR_IMAGE_SHADER := "
shader_type canvas_item;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform float seed;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.3) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV * vec2(3.0, 2.2);
	float a = n(uv) * 0.65 + n(uv * 2.1 + 3.7) * 0.35;
	float b = n(uv * 1.3 + 9.1);
	vec3 col = mix(c1.rgb, c2.rgb, smoothstep(0.3, 0.75, a));
	col = mix(col, c3.rgb, smoothstep(0.55, 0.85, b) * 0.7);
	COLOR = vec4(col, 1.0);
}
"

const BLUR_TEXT_SHADER := "
shader_type canvas_item;
uniform float lines = 5.0;
uniform float seed;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 3.1) * 43758.5453); }
void fragment() {
	float row = floor(UV.y * lines);
	float inl = fract(UV.y * lines);
	float len = row == lines - 1.0 ? 0.35 + 0.4 * h(vec2(row, 2.0)) : 0.75 + 0.25 * h(vec2(row, 1.0));
	float v = smoothstep(0.1, 0.4, inl) * smoothstep(0.9, 0.6, inl);
	v *= smoothstep(len, len - 0.06, UV.x) * smoothstep(0.0, 0.04, UV.x);
	float words = 0.55 + 0.45 * sin(UV.x * 38.0 + h(vec2(row, 4.0)) * 6.0);
	COLOR = vec4(0.18, 0.14, 0.1, v * mix(0.35, 0.6, words));
}
"

var faces := {}  # numéro -> Texture2D
var back: Texture2D
var _image_shader := Shader.new()
var _text_shader := Shader.new()


func build() -> void:
	_image_shader.code = BLUR_IMAGE_SHADER
	_text_shader.code = BLUR_TEXT_SHADER
	for id in CardDB.all_ids():
		faces[id] = _render(_face(id))
	back = _render(_back())


func _render(control: Control) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(control)
	add_child(vp)
	return vp.get_texture()


func _panel(bg: Color, border: Color, border_w: int, radius: int) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int, color: Color, pos: Vector2, box: Vector2, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = box
	return l


func _face(id: int) -> Control:
	var fam := CardDB.family(id)
	var color: Color = CardDB.FAMILY_COLORS[fam]
	var root := _panel(Color(0.97, 0.94, 0.86), color, 10, 18)
	root.size = Vector2(W, H)

	# Illustration (floutée, ou image fournie).
	var art_path := "res://cards/art/%d.png" % id
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.position = Vector2(18, 58)
		art.size = Vector2(W - 36, 150)
		root.add_child(art)
	else:
		var img := ColorRect.new()
		var m := ShaderMaterial.new()
		m.shader = _image_shader
		m.set_shader_parameter("c1", color.darkened(0.35))
		m.set_shader_parameter("c2", color.lightened(0.35))
		m.set_shader_parameter("c3", Color.from_hsv(fmod(color.h + 0.5, 1.0), 0.4, 0.8))
		m.set_shader_parameter("seed", float(id))
		img.material = m
		img.position = Vector2(18, 58)
		img.size = Vector2(W - 36, 150)
		root.add_child(img)

	# Nom codé et valeur de base.
	root.add_child(_label(CardDB.code(id), 34, Color(0.1, 0.08, 0.06), Vector2(56, 8), Vector2(W - 112, 44)))
	var value := _panel(color.darkened(0.2), Color(1, 1, 1, 0.9), 3, 24)
	value.position = Vector2(10, 8)
	value.size = Vector2(46, 46)
	root.add_child(value)
	root.add_child(_label(str(CardDB.base(id)), 26, Color.WHITE, Vector2(10, 8), Vector2(46, 46), 4))

	# BdC : pastille orange avec ses étoiles.
	if CardDB.is_bdc(id):
		var ball := _panel(Color(1.0, 0.6, 0.1), Color(0.75, 0.35, 0.0), 3, 24)
		ball.position = Vector2(W - 56, 8)
		ball.size = Vector2(46, 46)
		root.add_child(ball)
		root.add_child(_label("%d★" % CardDB.bdc_stars(id), 20, Color(0.75, 0.05, 0.05), Vector2(W - 56, 8), Vector2(46, 46)))

	# Bandeau de famille.
	var ribbon := _panel(color, color.darkened(0.3), 2, 8)
	ribbon.position = Vector2(40, 200)
	ribbon.size = Vector2(W - 80, 30)
	root.add_child(ribbon)
	var fam_text := CardDB.family_code(fam) + ("  ·  BdC" if CardDB.is_bdc(id) else "")
	root.add_child(_label(fam_text, 18, Color.WHITE, Vector2(40, 200), Vector2(W - 80, 30), 4))

	# Texte (flouté).
	var text := ColorRect.new()
	var tm := ShaderMaterial.new()
	tm.shader = _text_shader
	tm.set_shader_parameter("lines", float(clampi(CardDB.text(id).length() / 32, 2, 7)))
	tm.set_shader_parameter("seed", float(id))
	text.material = tm
	text.position = Vector2(22, 242)
	text.size = Vector2(W - 44, 100)
	root.add_child(text)
	return root


func _back() -> Control:
	var root := _panel(Color(0.12, 0.14, 0.35), Color(0.85, 0.65, 0.2), 10, 18)
	root.size = Vector2(W, H)
	var inner := _panel(Color(0.18, 0.2, 0.48), Color(0.85, 0.65, 0.2, 0.6), 3, 12)
	inner.position = Vector2(22, 22)
	inner.size = Vector2(W - 44, H - 44)
	root.add_child(inner)
	var ball := _panel(Color(1.0, 0.6, 0.1), Color(0.75, 0.35, 0.0), 4, 40)
	ball.position = Vector2(W / 2.0 - 40, H / 2.0 - 90)
	ball.size = Vector2(80, 80)
	root.add_child(ball)
	root.add_child(_label("★", 40, Color(0.75, 0.05, 0.05), ball.position, ball.size))
	root.add_child(_label("Realms", 46, Color(0.95, 0.8, 0.35), Vector2(0, H / 2.0 + 10), Vector2(W, 60), 6))
	return root
