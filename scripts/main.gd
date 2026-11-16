# Scène principale : table 3D, adversaires assis avec leurs cartes en main, pioche, défausse,
# main du joueur et interface. Les règles sont dans game.gd, les scores dans scoring.gd.
extends Node3D

const CardDB = preload("res://scripts/card_db.gd")
const Scoring = preload("res://scripts/scoring.gd")
const Game = preload("res://scripts/game.gd")
const CardFace = preload("res://scripts/card_face.gd")
const Choices = preload("res://scripts/choices.gd")

const HUMAN := 0
const PLAYERS := 4
const TABLE_RADIUS := 0.74
const SEAT_RADIUS := 1.0
const CARD_W := 0.105
const CARD_L := 0.147
const DISCARD_COLS := 5
const DECK_POS := Vector3(0.47, 0.0, -0.1)
const CAMERA_POS := Vector3(0, 0.92, 1.2)
const CAMERA_TARGET := Vector3(0, 0.05, -0.2)
const MOVE_TIME := 0.35        # petits mouvements (survol, tri de la main)
const ACTION_MOVE := 0.6        # carte qui change de place (pioche, défausse, main), pour tous les joueurs
const PRESENT_TIME := 1.0       # durée pendant laquelle la carte d'un ordinateur est montrée
const PRESENT_MOVE := 0.5       # trajet jusqu'à la présentation
const PRESENT_SCALE := 1.8      # carte agrandie pendant la présentation
const PRESENT_DISTANCE := 0.55  # distance de la carte présentée à la caméra
const DECK_LIFT_TIME := 0.7     # départ lent d'une carte piochée par un ordinateur
const SHIRT_COLORS := [Color(0.2, 0.3, 0.6), Color(0.7, 0.2, 0.2), Color(0.2, 0.55, 0.3), Color(0.55, 0.3, 0.6)]
const SKIN_COLORS := [Color(0.95, 0.8, 0.68), Color(0.85, 0.65, 0.5), Color(0.6, 0.42, 0.3), Color(0.98, 0.85, 0.75)]
const HAIR_COLORS := [Color.BLACK, Color(0.85, 0.35, 0.1), Color(0.08, 0.06, 0.05), Color(0.9, 0.82, 0.5)]
const LIGHT_FOLLOW_SPEED := 2.2  # plus c'est bas, plus la lumière de tour est en retard
const LIGHT_ENERGY_BOT := 5.0    # lumière de tour sur un ordinateur...
const LIGHT_ENERGY_HUMAN := 1.6  # ...et sur toi (plus douce : tes cartes sont dessous)
const HIGHLIGHT :=Color(1.0, 0.95, 0.5)

static var autostart_seed := -1   # tests : graine fixe
static var bot_delay_override := -1.0

var game: Game
var choices: Choices
var faces: CardFace
var camera: Camera3D
var card_nodes := {}      # numéro -> Node3D
var _card_mats := {}      # numéro -> StandardMaterial3D du recto
var _targets := {}        # numéro -> Transform3D visé
var seats: Array[Node3D] = []
var name_labels: Array[Label3D] = []
var turn_light: SpotLight3D
var deck_stack: MeshInstance3D
var _light_pos := Vector3(0, 1.3, 0)
var _light_goal := Vector3(0, 1.3, 0)
var _light_aim := Vector3(0, 0, 0.3)  # jamais à la verticale de la lumière (orientation indéfinie)
var _light_aim_goal := Vector3(0, 0, 0.3)
var _light_energy_goal := 5.0

var _hovered := -1
var _selected: Array = []          # cartes choisies (BAB#25)
var _mode := ""                    # "", "baba_take", "baba_drop"
var _discard_preview := {}         # carte de la main -> score si on la défausse
var _messages: Array[String] = []

# Interface
var hud_status: Label
var hud_counts: Label
var hud_score: Label
var hud_log: Label
var zoom_panel: PanelContainer
var zoom_tex: TextureRect
var zoom_text: RichTextLabel
var buttons_box: HBoxContainer
var btn_detector: Button
var btn_baba: Button
var btn_confirm: Button
var btn_cancel: Button
var dialog_layer: CanvasLayer
var results_layer: CanvasLayer


func _ready() -> void:
	get_viewport().physics_object_picking = true
	faces = CardFace.new()
	add_child(faces)
	faces.build()
	_build_environment()
	_build_table()
	for p in PLAYERS:
		_build_seat(p)
	_build_camera()
	_build_cards()
	_build_hud()
	choices = Choices.new()
	choices.main = self
	add_child(choices)
	choices.validated.connect(func(v): game.answer(v))

	game = Game.new()
	game.name = "Game"
	if bot_delay_override >= 0.0:
		game.bot_delay = bot_delay_override
	add_child(game)
	game.changed.connect(_on_changed)
	game.turn_started.connect(_on_turn_started)
	game.message.connect(_on_message)
	game.choice_requested.connect(_on_choice_requested)
	game.game_over.connect(_on_game_over)
	game.present_hook = _present_card
	game.start.call_deferred(autostart_seed)


# --- Construction de la scène -------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


func _box(size: Vector3, color: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _mat(color)
	inst.position = pos
	parent.add_child(inst)
	return inst


func _sphere(radius: float, color: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _mat(color)
	inst.position = pos
	parent.add_child(inst)
	return inst


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 0.75)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.6, 0.2)
	lamp.omni_range = 4.0
	lamp.light_energy = 1.1
	lamp.light_color = Color(1.0, 0.92, 0.8)
	lamp.shadow_enabled = true
	add_child(lamp)

	# Lumière au-dessus du joueur qui joue (comme dans Nervous) : elle suit le joueur actif avec un peu de retard.
	turn_light = SpotLight3D.new()
	turn_light.spot_range = 2.5
	turn_light.spot_angle = 18.0
	turn_light.spot_attenuation = 0.6
	turn_light.light_energy = 5.0
	turn_light.light_color = Color(1.0, 0.95, 0.6)
	turn_light.shadow_enabled = true
	turn_light.visible = false
	add_child(turn_light)


# Vise le joueur actif : un ordinateur est éclairé avec ses cartes, toi ce sont tes cartes sur la table.
func _aim_turn_light(p: int) -> void:
	var playing := game.phase != "over" and game.phase != "end"
	if not playing:
		turn_light.visible = false
		return
	var seat := seats[p]
	_light_goal = seat.position * 0.7 + Vector3(0, 1.4, 0)
	_light_aim_goal = seat.to_global(Vector3(0, 0, -0.35) if p == HUMAN else Vector3(0, 0.2, 0.0))
	_light_energy_goal = LIGHT_ENERGY_HUMAN if p == HUMAN else LIGHT_ENERGY_BOT  # tes cartes restent lisibles
	if not turn_light.visible:  # premier allumage : directement en place
		_light_pos = _light_goal
		_light_aim = _light_aim_goal
		turn_light.light_energy = _light_energy_goal
		turn_light.visible = true


func _process(delta: float) -> void:
	if not turn_light.visible:
		return
	# La lumière traîne derrière le joueur actif et le rattrape.
	var t := minf(1.0, delta * LIGHT_FOLLOW_SPEED)
	_light_pos = _light_pos.lerp(_light_goal, t)
	_light_aim = _light_aim.lerp(_light_aim_goal, t)
	turn_light.light_energy = lerpf(turn_light.light_energy, _light_energy_goal, t)
	turn_light.look_at_from_position(_light_pos, _light_aim)


func _build_table() -> void:
	var top := CylinderMesh.new()
	top.top_radius = TABLE_RADIUS
	top.bottom_radius = TABLE_RADIUS
	top.height = 0.04
	var top_inst := MeshInstance3D.new()
	top_inst.mesh = top
	top_inst.material_override = _mat(Color(0.12, 0.4, 0.22))
	top_inst.position.y = -0.02
	add_child(top_inst)
	var rim := CylinderMesh.new()
	rim.top_radius = TABLE_RADIUS + 0.05
	rim.bottom_radius = TABLE_RADIUS + 0.05
	rim.height = 0.06
	var rim_inst := MeshInstance3D.new()
	rim_inst.mesh = rim
	rim_inst.material_override = _mat(Color(0.35, 0.2, 0.1))
	rim_inst.position.y = -0.035
	add_child(rim_inst)
	_box(Vector3(0.12, 0.8, 0.12), Color(0.3, 0.17, 0.08), Vector3(0, -0.45, 0), self)
	_box(Vector3(6, 0.02, 6), Color(0.2, 0.14, 0.1), Vector3(0, -0.86, 0), self)

	# Pioche : un tas de cartes face cachée.
	deck_stack = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CARD_W, 1.0, CARD_L)
	deck_stack.mesh = mesh
	var side := _mat(Color(0.95, 0.93, 0.88))
	deck_stack.material_override = side
	deck_stack.position = DECK_POS
	add_child(deck_stack)
	var deck_top := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(CARD_W, CARD_L)
	deck_top.mesh = quad
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_texture = faces.back
	back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	deck_top.material_override = back_mat
	deck_top.name = "Top"
	deck_top.rotation.x = -PI / 2.0
	deck_top.position.y = 0.501
	deck_stack.add_child(deck_top)
	# Zone cliquable de la pioche.
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CARD_W, 0.06, CARD_L)
	shape.shape = box
	area.add_child(shape)
	area.position = DECK_POS + Vector3(0, 0.02, 0)
	area.input_event.connect(func(_c, event, _p, _n, _s): _on_deck_input(event))
	area.mouse_entered.connect(func(): _set_deck_hover(true))
	area.mouse_exited.connect(func(): _set_deck_hover(false))
	add_child(area)


func _seat_angle(p: int) -> float:
	return -p * TAU / PLAYERS


func _build_seat(p: int) -> void:
	var root := Node3D.new()
	root.name = "Seat%d" % p
	var a := _seat_angle(p)
	root.position = Vector3(sin(a), 0, cos(a)) * SEAT_RADIUS
	root.rotation.y = a  # -Z local vers le centre de la table
	add_child(root)
	seats.append(root)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.0004
	label.fixed_size = true
	label.font_size = 48
	label.outline_size = 12
	label.position = Vector3(0, 0.68, 0.1) if p != HUMAN else Vector3(0, -10, 0)
	root.add_child(label)
	name_labels.append(label)
	if p == HUMAN:
		return
	var shirt: Color = SHIRT_COLORS[p]
	var skin: Color = SKIN_COLORS[p]
	_box(Vector3(0.42, 0.5, 0.22), shirt, Vector3(0, 0.12, 0.12), root)
	_box(Vector3(0.5, 0.7, 0.08), Color(0.3, 0.18, 0.1), Vector3(0, 0.02, 0.3), root)  # dossier
	var head := _sphere(0.115, skin, Vector3(0, 0.5, 0.1), root)
	var hair := _sphere(0.122, HAIR_COLORS[p], Vector3(0, 0.035, 0.015), head)
	hair.scale = Vector3(1, 0.7, 1)
	for s in [-1.0, 1.0]:
		_sphere(0.024, Color.WHITE, Vector3(s * 0.042, 0.015, -0.098), head)
		_sphere(0.012, Color.BLACK, Vector3(s * 0.042, 0.015, -0.12), head)
		# Bras qui tiennent les cartes.
		var arm := _box(Vector3(0.07, 0.07, 0.3), shirt, Vector3(s * 0.17, 0.17, -0.06), root)
		arm.rotation.x = -0.5
		_sphere(0.04, skin, Vector3(s * 0.07, 0.22, -0.2), root)
	_box(Vector3(0.05, 0.01, 0.01), Color(0.5, 0.15, 0.15), Vector3(0, -0.05, -0.105), head)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	add_child(camera)
	camera.look_at_from_position(CAMERA_POS, CAMERA_TARGET)


func _build_cards() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(CARD_W, CARD_L)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_texture = faces.back
	back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	for id in CardDB.all_ids():
		var card := Node3D.new()
		card.name = "Card%d" % id
		var front := MeshInstance3D.new()
		front.mesh = quad
		var m := StandardMaterial3D.new()
		m.albedo_texture = faces.faces[id]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		front.material_override = m
		front.position.z = 0.0005
		card.add_child(front)
		var back := MeshInstance3D.new()
		back.mesh = quad
		back.material_override = back_mat
		back.rotation.y = PI
		back.position.z = -0.0005
		card.add_child(back)
		var area := Area3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(CARD_W, CARD_L, 0.004)
		shape.shape = box
		area.add_child(shape)
		area.input_event.connect(func(_c, event, _p, _n, _s): _on_card_input(id, event))
		area.mouse_entered.connect(func(): _on_card_hover(id, true))
		area.mouse_exited.connect(func(): _on_card_hover(id, false))
		card.add_child(area)
		card.visible = false
		card.position = DECK_POS
		add_child(card)
		card_nodes[id] = card
		_card_mats[id] = m


# --- Interface 2D --------------------------------------------------------------

func _label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_status = _label(layer, 28)
	hud_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_status.offset_top = 14
	hud_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_counts = _label(layer, 20)
	hud_counts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud_counts.offset_left = 20
	hud_counts.offset_top = -84
	hud_log = _label(layer, 16)
	hud_log.position = Vector2(20, 60)
	hud_log.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hud_score = _label(layer, 24)
	hud_score.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud_score.offset_left = 20
	hud_score.offset_top = -50
	hud_score.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	var help := _label(layer, 15)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	help.offset_left = -560
	help.offset_top = -34
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.text = "Survole une carte pour la lire  ·  Clic : piocher / prendre / défausser"

	buttons_box = HBoxContainer.new()
	buttons_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	buttons_box.offset_top = -120
	buttons_box.offset_bottom = -80
	buttons_box.offset_left = -400
	buttons_box.offset_right = 400
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_box.add_theme_constant_override("separation", 16)
	layer.add_child(buttons_box)
	btn_detector = _button("Utiliser DET#43", _on_detector_pressed)
	btn_baba = _button("Utiliser BAB#25", _on_baba_pressed)
	btn_confirm = _button("Valider", _on_confirm_pressed)
	btn_cancel = _button("Annuler", _on_cancel_pressed)

	# Carte agrandie, à droite.
	zoom_panel = PanelContainer.new()
	zoom_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	zoom_panel.offset_left = -340
	zoom_panel.offset_right = -16
	zoom_panel.offset_top = -330
	zoom_panel.offset_bottom = 330
	zoom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	zoom_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_panel.add_child(vb)
	zoom_tex = TextureRect.new()
	zoom_tex.custom_minimum_size = Vector2(256, 358)
	zoom_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	zoom_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zoom_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(zoom_tex)
	zoom_text = RichTextLabel.new()
	zoom_text.bbcode_enabled = true
	zoom_text.fit_content = true
	zoom_text.custom_minimum_size = Vector2(300, 0)
	zoom_text.add_theme_font_size_override("normal_font_size", 16)
	zoom_text.add_theme_font_size_override("bold_font_size", 18)
	zoom_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(zoom_text)
	zoom_panel.visible = false
	var zoom_layer := CanvasLayer.new()
	zoom_layer.layer = 8  # au-dessus des fenêtres de choix
	add_child(zoom_layer)
	zoom_layer.add_child(zoom_panel)

	dialog_layer = CanvasLayer.new()
	dialog_layer.layer = 5
	add_child(dialog_layer)
	results_layer = CanvasLayer.new()
	results_layer.layer = 6
	add_child(results_layer)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(170, 40)
	b.pressed.connect(action)
	b.visible = false
	buttons_box.add_child(b)
	return b


func _show_zoom(id: int, extra := "") -> void:
	zoom_tex.texture = faces.faces[id]
	var t := "[b]%s[/b]  —  %s  —  valeur %d" % [CardDB.code(id), CardDB.family_code(CardDB.family(id)), CardDB.base(id)]
	if CardDB.is_bdc(id):
		t += "\nBdC %d★" % CardDB.bdc_stars(id)
	t += "\n" + CardDB.text(id)
	if extra != "":
		t += "\n[color=#ffd966]" + extra + "[/color]"
	zoom_text.text = t
	zoom_panel.visible = true


# --- Placement des cartes -----------------------------------------------------

func _on_changed() -> void:
	if game.phase != "discard" or game.current != HUMAN:
		_discard_preview.clear()
	elif _discard_preview.is_empty():
		_compute_discard_preview()
	_layout()
	_refresh_hud()


func _compute_discard_preview() -> void:
	var hand: Array = game.hands[HUMAN]
	var ctx := game.score_ctx()
	for card in hand:
		var h := hand.duplicate()
		h.erase(card)
		_discard_preview[card] = Scoring.best(h, ctx).total


func _layout() -> void:
	var placed := {}
	var over := game.phase == "over"
	# Main du joueur, triée par famille, en éventail face à la caméra.
	var hand: Array = _sorted(game.hands[HUMAN])
	var n := hand.size()
	for k in n:
		var id: int = hand[k]
		var x := (k - (n - 1) / 2.0) * (CARD_W * 0.95)
		var pos := Vector3(x, 0.15 - absf(x) * 0.08, 0.58)
		var lift := 0.0
		if id == _hovered and _hand_clickable():
			lift = 0.03
		if _selected.has(id):
			lift = 0.045
		var basis := Basis.looking_at(pos - CAMERA_POS, Vector3.UP)
		basis = basis * Basis(Vector3.BACK, -x * 0.6)
		pos += basis.y * lift
		_targets[id] = Transform3D(basis, pos)
		placed[id] = true
	# Mains des adversaires : éventail tenu devant eux (dos vers le centre), étalées à la fin.
	for p in range(1, PLAYERS):
		var h: Array = _sorted(game.hands[p])
		var m := h.size()
		for k in m:
			var id: int = h[k]
			var t: Transform3D
			var spread := (k - (m - 1) / 2.0)
			if over:
				var seat := seats[p]
				var local := Vector3(spread * CARD_W * 1.02, 0.002, -0.42)
				var world_pos := seat.transform * local
				t = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), world_pos)
			else:
				var local_basis := Basis(Vector3.BACK, -spread * 0.13) * Basis(Vector3.RIGHT, -0.25)
				var local_pos := Vector3(spread * 0.022, 0.28 - absf(spread) * 0.006, -0.22 + k * 0.001)
				t = seats[p].transform * Transform3D(local_basis, local_pos)
			_targets[id] = t
			placed[id] = true
	# Défausse : grille face visible au centre.
	var d: Array = game.discard
	for k in d.size():
		var id: int = d[k]
		var col := k % DISCARD_COLS
		@warning_ignore("integer_division")
		var row := k / DISCARD_COLS
		var pos := Vector3((col - (DISCARD_COLS - 1) / 2.0) * (CARD_W + 0.012), 0.002, -0.13 + row * (CARD_L + 0.012))
		if _selected.has(id) or (id == _hovered and _discard_clickable()):
			pos.y += 0.012
		_targets[id] = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), pos)
		placed[id] = true
	# Pioche : cartes cachées sur le tas.
	var h_deck := 0.002 + game.deck.size() * 0.0006
	deck_stack.scale.y = maxf(game.deck.size(), 1) * 0.0006
	deck_stack.position.y = deck_stack.scale.y / 2.0
	deck_stack.visible = not game.deck.is_empty()
	for id in game.deck:
		_targets[id] = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), DECK_POS + Vector3(0, h_deck, 0))
	var zones := {}
	for id in game.discard:
		zones[id] = "discard"
	for p in PLAYERS:
		for id in game.hands[p]:
			zones[id] = "hand%d" % p
	for id in card_nodes:
		var node: Node3D = card_nodes[id]
		var in_deck := not placed.has(id)
		var zone: String = zones.get(id, "deck")
		var moved_zone: bool = node.get_meta("zone", "deck") != zone
		node.set_meta("zone", zone)
		var target: Transform3D = _targets.get(id, Transform3D(Basis(), DECK_POS))
		var mat: StandardMaterial3D = _card_mats[id]
		var lit := _selected.has(id) or choices.card_pending(id)
		mat.albedo_color = Color(0.35, 0.35, 0.35) if game.masked_discard.has(id) else (HIGHLIGHT if lit else Color.WHITE)
		if node.has_meta("held"):
			continue  # en cours de présentation
		if in_deck:
			node.visible = false
			node.transform = target
			continue
		if not node.visible:
			node.visible = true
		_move(node, target, ACTION_MOVE if moved_zone else MOVE_TIME)


func _move(node: Node3D, target: Transform3D, duration := MOVE_TIME) -> void:
	if node.has_meta("target") and node.get_meta("target").is_equal_approx(target):
		return
	node.set_meta("target", target)
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", target.origin, duration)
	tw.tween_property(node, "quaternion", target.basis.get_rotation_quaternion(), duration)
	if not node.scale.is_equal_approx(Vector3.ONE):
		tw.tween_property(node, "scale", Vector3.ONE, duration)
	node.set_meta("tween", tw)


func _kill_tween(node: Node3D) -> void:
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old and old.is_valid():
			old.kill()


# Montre au joueur humain une action d'un ordinateur (et la carte qu'il pioche lui-même) ;
# game.gd attend la fin avant de continuer.
# "deck" : la carte quitte lentement la pioche (si c'est toi, elle vient ensuite se présenter) ;
# "take" / "discard" : la carte vient se présenter face à la caméra pendant PRESENT_TIME,
# puis la mise en place normale l'emmène à destination.
func _present_card(kind: String, p: int, card: int) -> void:
	var node: Node3D = card_nodes[card]
	node.set_meta("held", true)
	_kill_tween(node)
	if kind == "deck":
		node.visible = true
		node.scale = Vector3.ONE
		node.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), DECK_POS + Vector3(0, deck_stack.scale.y + 0.003, 0))
		var lift := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		lift.tween_property(node, "position", node.position + Vector3(0, 0.1, 0), DECK_LIFT_TIME)
		await lift.finished
	if kind != "deck" or p == HUMAN:  # ta carte piochée se montre à toi, celle d'un ordinateur reste cachée
		node.visible = true
		var forward := (CAMERA_TARGET - CAMERA_POS).normalized()
		var pos := CAMERA_POS + forward * PRESENT_DISTANCE
		var basis := Basis.looking_at(pos - CAMERA_POS, Vector3.UP)
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position", pos, PRESENT_MOVE)
		tw.tween_property(node, "quaternion", basis.get_rotation_quaternion(), PRESENT_MOVE)
		tw.tween_property(node, "scale", Vector3.ONE * PRESENT_SCALE, PRESENT_MOVE)
		await tw.finished
		var what := "prend cette carte dans la défausse" if kind == "take" else "défausse cette carte"
		_show_zoom(card, "Tu pioches cette carte" if kind == "deck" else "%s %s" % [game.names[p], what])
		await get_tree().create_timer(PRESENT_TIME).timeout
		if _hovered < 0:
			zoom_panel.visible = false
	node.remove_meta("held")
	# Le jeu change l'état juste après : la mise en place suivante emmène la carte depuis ici.
	node.set_meta("target", Transform3D(Basis(), Vector3(0, -100, 0)))


func _sorted(cards: Array) -> Array:
	var a := cards.duplicate()
	a.sort_custom(func(x, y):
		var fx := CardDB.family(x)
		var fy := CardDB.family(y)
		return fx < fy or (fx == fy and x < y))
	return a


# --- Interface : textes ---------------------------------------------------------

func _refresh_hud() -> void:
	hud_counts.text = "Défausse : %d / %d     Pioche : %d" % [game.discard.size(), Game.DISCARD_LIMIT, game.deck.size()]
	for p in PLAYERS:
		var label := name_labels[p]
		label.text = "%s (%d)" % [game.names[p], game.hands[p].size()]
		label.modulate = HIGHLIGHT if p == game.current and game.phase != "over" else Color.WHITE
	_aim_turn_light(game.current)
	var my_turn := game.current == HUMAN
	match game.phase:
		"draw":
			if my_turn:
				if _mode == "baba_take":
					hud_status.text = "BAB#25 : choisis 3 cartes de la défausse (%d / 3)" % _selected.size()
				else:
					hud_status.text = "À toi : prends la carte du dessus de la pioche ou une carte de la défausse"
			else:
				hud_status.text = "%s réfléchit…" % game.names[game.current]
		"discard":
			hud_status.text = "À toi : défausse une carte de ta main" if my_turn else "%s réfléchit…" % game.names[game.current]
		"baba_discard":
			hud_status.text = "BAB#25 : choisis 2 cartes à défausser avec BAB#25 (%d / 2)" % _selected.size() if my_turn else "%s réfléchit…" % game.names[game.current]
		"busy":
			hud_status.text = "%s joue…" % game.names[game.current] if not my_turn else ""
		"end":
			hud_status.text = "Fin de la partie : effets de FIN DE PARTIE"
		"over":
			hud_status.text = "Partie terminée"
	var hand: Array = game.hands[HUMAN]
	if game.phase == "over" and game.results.size() > HUMAN:
		hud_score.text = "Ton score : %d" % game.results[HUMAN].total
	elif hand.size() == Game.HAND_SIZE:
		hud_score.text = "Score de ta main : %d" % Scoring.best(hand, game.score_ctx()).total
	elif game.phase == "discard":
		hud_score.text = "Survole une carte pour voir ton score si tu la défausses"
	else:
		hud_score.text = ""
	var human_draw := game.phase == "draw" and my_turn
	btn_detector.visible = human_draw and _mode == "" and hand.has(Game.DET) and not game.deck.is_empty()
	btn_baba.visible = human_draw and _mode == "" and hand.has(Game.BAB) and game.discard.size() >= 3
	btn_confirm.visible = (_mode == "baba_take" and _selected.size() == 3) or (_mode == "baba_drop" and _selected.size() == 2)
	btn_cancel.visible = _mode == "baba_take"
	hud_log.text = "\n".join(_messages)


func _on_message(text: String) -> void:
	_messages.append(text)
	while _messages.size() > 5:
		_messages.pop_front()
	hud_log.text = "\n".join(_messages)


func _on_turn_started(_player: int) -> void:
	_mode = "baba_drop" if game.phase == "baba_discard" else ""
	_selected.clear()


# --- Souris -------------------------------------------------------------------

func _hand_clickable() -> bool:
	if choices.active():
		return choices.handles(_hovered)
	return game.current == HUMAN and (game.phase == "discard" or game.phase == "baba_discard")


func _discard_clickable() -> bool:
	return game.current == HUMAN and game.phase == "draw"


func _card_location(id: int) -> String:
	if game.hands[HUMAN].has(id):
		return "hand"
	if game.discard.has(id):
		return "discard"
	for p in range(1, PLAYERS):
		if game.hands[p].has(id):
			return "revealed" if game.phase == "over" else "hidden"
	return "deck"


func _on_card_hover(id: int, entered: bool) -> void:
	if not entered:
		if _hovered == id:
			_hovered = -1
			zoom_panel.visible = false
			_layout()
		return
	var loc := _card_location(id)
	if loc == "hidden" or loc == "deck":
		return
	_hovered = id
	var extra := ""
	if loc == "hand" and game.phase == "discard" and _discard_preview.has(id):
		extra = "Si tu la défausses : score %d" % _discard_preview[id]
	if loc == "discard" and game.masked_discard.has(id):
		extra = "Masquée par FOR#50"
	_show_zoom(id, extra)
	_layout()


func _on_card_input(id: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if dialog_layer.get_child_count() > 0:
		return
	if choices.handles(id) and game.hands[HUMAN].has(id):
		choices.open_for_card(id)
		return
	var loc := _card_location(id)
	if loc == "discard" and _discard_clickable():
		if _mode == "baba_take":
			if _selected.has(id):
				_selected.erase(id)
			elif _selected.size() < 3:
				_selected.append(id)
			_layout()
			_refresh_hud()
		else:
			game.human_take_discard(HUMAN, id)
	elif loc == "hand" and game.current == HUMAN:
		if game.phase == "discard":
			zoom_panel.visible = false
			_hovered = -1
			game.human_discard(HUMAN, id)
		elif game.phase == "baba_discard" and id != Game.BAB:
			if _selected.has(id):
				_selected.erase(id)
			elif _selected.size() < 2:
				_selected.append(id)
			_layout()
			_refresh_hud()


func _on_deck_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _mode == "" and dialog_layer.get_child_count() == 0:
			game.human_draw_deck(HUMAN)


func _set_deck_hover(on: bool) -> void:
	deck_stack.material_override.albedo_color = HIGHLIGHT if on and _discard_clickable() and _mode == "" else Color(0.95, 0.93, 0.88)


func _on_detector_pressed() -> void:
	game.human_use_detector(HUMAN)


func _on_baba_pressed() -> void:
	_mode = "baba_take"
	_selected.clear()
	_refresh_hud()


func _on_cancel_pressed() -> void:
	_mode = ""
	_selected.clear()
	_layout()
	_refresh_hud()


func _on_confirm_pressed() -> void:
	var chosen := _selected.duplicate()
	_selected.clear()
	if _mode == "baba_take":
		_mode = "baba_drop"
		game.human_baba_take(HUMAN, chosen)
	elif _mode == "baba_drop":
		_mode = ""
		game.human_baba_discard(HUMAN, chosen)
	_layout()
	_refresh_hud()


# --- Questions au joueur --------------------------------------------------------

func _dialog_box(title: String) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.16, 0.95)
	sb.border_color = Color(0.85, 0.65, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	dim.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	vb.add_child(l)
	panel.resized.connect(func(): panel.position = (dim.size - panel.size) / 2.0)
	dim.resized.connect(func(): panel.position = (dim.size - panel.size) / 2.0)
	return vb


func _close_dialog(value) -> void:
	_clear_dialogs()
	game.answer(value)


func _clear_dialogs() -> void:
	for c in dialog_layer.get_children():
		dialog_layer.remove_child(c)
		c.queue_free()
	zoom_panel.visible = false


func refresh_cards() -> void:
	_layout()


# Répond à la question en cours sans passer par l'interface (tests).
func auto_answer(value) -> void:
	if choices.active():
		choices.close()
	_close_dialog(value)


func _yes_no(title: String, yes_text := "Oui", no_text := "Non") -> void:
	var vb := _dialog_box(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	for pair in [[yes_text, true], [no_text, false]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(180, 44)
		b.add_theme_font_size_override("font_size", 20)
		var v: bool = pair[1]
		b.pressed.connect(func(): _close_dialog(v))
		row.add_child(b)


func _pick_card(title: String, options: Array, allow_none: bool) -> void:
	var vb := _dialog_box(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	for id in options:
		var b := TextureButton.new()
		b.texture_normal = faces.faces[id]
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(110, 154)
		var card: int = id
		b.pressed.connect(func(): _close_dialog(card))
		b.mouse_entered.connect(func(): _show_zoom(card))
		row.add_child(b)
	if allow_none:
		var none := Button.new()
		none.text = "Aucune"
		none.custom_minimum_size = Vector2(180, 44)
		none.add_theme_font_size_override("font_size", 20)
		none.pressed.connect(func(): _close_dialog(-1))
		var center := CenterContainer.new()
		center.add_child(none)
		vb.add_child(center)


func _on_choice_requested(kind: String, data: Dictionary) -> void:
	match kind:
		"detector":
			_pick_card("DET#43 : choisis une carte parmi les 3 du dessus de la pioche", data.options, false)
		"module":
			_yes_no("MOD#31 : chercher SAN#1 dans la pioche et le placer dans la défausse ?\n(MOD#31 est alors mélangé avec la pioche)")
		"machine":
			_yes_no("MAC#33 : rejouer immédiatement ?")
		"end_mask", "end_take":
			choices.start_end(kind, data)
		"scoring":
			if not choices.start_scoring(data.hand, data.ctx):
				game.answer.call_deferred({})
		"sangoku":
			_yes_no("SAN#1 est dans la défausse. Veux-tu le compter comme 8e carte de ta main ?\nAvec : %d points  ·  Sans : %d points" % [data["with"], data.without],
				"Oui, je l'inclus", "Non")


# --- Fin de partie --------------------------------------------------------------

func _on_game_over(results: Array) -> void:
	_layout()
	_refresh_hud()
	var best := -100000
	for r in results:
		best = maxi(best, r.total)
	var winners := results.filter(func(r): return r.total == best).map(func(r): return r.name)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_layer.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	sb.border_color = Color(0.85, 0.65, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 16
	panel.offset_top = -330
	panel.offset_right = 760
	panel.offset_bottom = 330
	dim.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := Label.new()
	var win_text := " et ".join(winners)
	title.text = ("Tu gagnes !" if winners.has(game.names[HUMAN]) and winners.size() == 1 else "Victoire : " + win_text)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vb.add_child(title)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_font_size_override("bold_font_size", 20)
	var sorted := results.duplicate()
	sorted.sort_custom(func(a, b): return a.total > b.total)
	var t := ""
	for r in sorted:
		t += "[b]%s : %d points[/b]\n" % [r.name, r.total]
		var parts := []
		for c in r.cards:
			var line := CardDB.code(c.id)
			if c.masked:
				line += " [color=#888888]masquée[/color]"
			else:
				line += " [color=#ffd966]%d[/color]" % c.points
				var detail := []
				if c.bonus != 0:
					detail.append("bonus %+d" % c.bonus)
				if c.malus != 0:
					detail.append("malus %+d" % c.malus)
				if not detail.is_empty():
					line += " (%s)" % ", ".join(detail)
			if not c.notes.is_empty():
				line += " [color=#9fc5e8]— %s[/color]" % ", ".join(c.notes)
			parts.append(line)
		t += "   " + "\n   ".join(parts) + "\n"
		if r.bdc_count > 0:
			t += "   BdC × %d : [color=#ffd966]+%d[/color]\n" % [r.bdc_count, r.bdc_points]
		t += "\n"
	text.text = t
	vb.add_child(text)
	var again := Button.new()
	again.text = "Nouvelle partie"
	again.custom_minimum_size = Vector2(220, 46)
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	var center := CenterContainer.new()
	center.add_child(again)
	vb.add_child(center)
