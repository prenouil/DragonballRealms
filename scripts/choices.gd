# Choix que le joueur humain fait lui-même en cliquant sur ses cartes :
# - au décompte : EXP#37, SEN#44, CHA#9, BUL#11, OOL#51, DRB#52, CHA#53, TRA#47, PIL#19, BRO#5 ;
# - effets FIN DE PARTIE : FOR#50, RAD#42, SHE#54.
# Les cartes concernées sont en surbrillance ; un clic (ou « Choisir ») affiche tous les choix
# possibles. Chaque choix peut être annulé ; « Valider » n'est possible que quand tout est choisi.
extends CanvasLayer

const CardDB = preload("res://scripts/card_db.gd")
const Scoring = preload("res://scripts/scoring.gd")

signal validated(value)

const LABELS := {
	"ool": [51, "OOL#51 : copier une autre carte de ta main"],
	"drb": [52, "DRB#52 : prendre le nom et la famille d'une carte (DEP_7, OBJ_9, LIE_6, TEC_8 ou TRA_10)"],
	"chg": [53, "CHA#53 : prendre le nom et la famille d'une carte (SAY_1, COM_2, ENN_4, ALL_3 ou MAI_5)"],
	"tra": [47, "TRA#47 : changer la famille d'une autre carte"],
	"pil": [19, "PIL#19 : être ou non un ENN_4"],
	"sen": [44, "SEN#44 : protéger une autre carte"],
	"cha": [9, "CHA#9 : se masquer pour protéger une autre carte"],
	"exp": [37, "EXP#37 : masquer une autre carte"],
	"bul": [11, "BUL#11 : protéger une BdC de ta main"],
}

var main: Node           # main.gd : cartes, fenêtres, carte agrandie
var kind := ""           # "" (inactif), "scoring", "end_mask", "end_take"
var items := []          # {key, card, label, options, allow_none, picker, value, done}
var hand := []
var ctx := {}

var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _score: Label
var _validate: Button


func _ready() -> void:
	layer = 4
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	sb.border_color = Color(0.85, 0.65, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_panel.offset_left = 16
	_panel.offset_right = 660
	_panel.offset_top = 70
	_panel.offset_bottom = -20
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_title)
	var help := Label.new()
	help.text = "Clique sur une carte en surbrillance (ou sur « Choisir ») pour voir les choix possibles."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vb.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_score = Label.new()
	_score.add_theme_font_size_override("font_size", 20)
	_score.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vb.add_child(_score)
	_validate = Button.new()
	_validate.text = "Valider"
	_validate.custom_minimum_size = Vector2(200, 44)
	_validate.add_theme_font_size_override("font_size", 22)
	_validate.pressed.connect(_on_validate)
	var center := CenterContainer.new()
	center.add_child(_validate)
	vb.add_child(center)
	_panel.visible = false


func active() -> bool:
	return kind != ""


# Choix du décompte pour la main donnée. Renvoie false s'il n'y a rien à choisir.
func start_scoring(h: Array, c: Dictionary) -> bool:
	hand = h
	ctx = c
	items.clear()
	for s in Scoring.choice_specs(h):
		var key: String = s.key
		var it := {"key": key, "options": [], "allow_none": false, "picker": "card", "value": null, "done": false}
		if key == "pil":
			it.card = 19
			it.label = LABELS.pil[1]
			it.picker = "pil"
			it.options = [false, true]
		elif key.begins_with("bro"):
			it.card = 5
			it.label = "BRO#5 : carte gardée parmi les %s" % CardDB.family_code(int(key.substr(3)))
			it.options = s.options.duplicate()
		else:
			it.card = LABELS[key][0]
			it.label = LABELS[key][1]
			for o in s.options:
				if o == -1:
					it.allow_none = true
				else:
					it.options.append(o)
			if key == "tra":
				it.picker = "tra"
			if it.options.is_empty():
				continue  # EXP#37 seul : rien à masquer
		items.append(it)
	if items.is_empty():
		return false
	kind = "scoring"
	_title.text = "Décompte : fais tes choix"
	_open_panel()
	return true


# Effet FIN DE PARTIE : une carte de la défausse à choisir (ou aucune).
func start_end(k: String, data: Dictionary) -> void:
	kind = k
	hand = []
	ctx = {}
	var card: int = 50 if k == "end_mask" else int(data.effect)
	var label := "FOR#50 : masquer une carte de la défausse"
	if card == 42:
		label = "RAD#42 : prendre une BdC dans la défausse"
	elif card == 54:
		label = "SHE#54 : prendre une carte de la défausse (sauf une BdC)"
	items = [{"key": "end", "card": card, "label": label, "options": data.options, "allow_none": true,
		"picker": "card", "value": null, "done": false}]
	_title.text = "FIN DE PARTIE #%d" % (CardDB.END_EFFECTS.find(card) + 1)
	_open_panel()


# Carte en surbrillance : un choix reste à faire avec elle.
func card_pending(id: int) -> bool:
	if not active():
		return false
	for it in items:
		if it.card == id and not it.done:
			return true
	return false


func handles(id: int) -> bool:
	if not active():
		return false
	for it in items:
		if it.card == id:
			return true
	return false


# Clic sur une carte : ouvre son premier choix non fait (ou le premier).
func open_for_card(id: int) -> void:
	var first := -1
	for i in items.size():
		if items[i].card == id:
			if not items[i].done:
				_open_picker(i)
				return
			if first < 0:
				first = i
	if first >= 0:
		_open_picker(first)


func current_choices() -> Dictionary:
	var ch := {}
	for it in items:
		if it.done:
			ch[it.key] = it.value
	return ch


# Réponse donnée sans passer par l'interface (tests).
func close() -> void:
	kind = ""
	items.clear()
	_panel.visible = false
	main._clear_dialogs()


func _open_panel() -> void:
	_panel.visible = true
	_refresh()
	main.refresh_cards()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var all_done := true
	for i in items.size():
		var it: Dictionary = items[i]
		all_done = all_done and it.done
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = "%s\n→ %s" % [it.label, _value_text(it)]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 16)
		if not it.done:
			l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		row.add_child(l)
		var choose := Button.new()
		choose.text = "Changer" if it.done else "Choisir"
		choose.custom_minimum_size = Vector2(100, 36)
		var idx := i
		choose.pressed.connect(func(): _open_picker(idx))
		row.add_child(choose)
		var cancel := Button.new()
		cancel.text = "Annuler"
		cancel.custom_minimum_size = Vector2(100, 36)
		cancel.visible = it.done
		cancel.pressed.connect(func(): _reset(idx))
		row.add_child(cancel)
		_list.add_child(row)
	_validate.disabled = not all_done
	if kind == "scoring":
		var r := Scoring.evaluate(hand, ctx, current_choices())
		_score.text = "Score avec ces choix : %d%s" % [r.total, "" if all_done else "  (choix incomplets)"]
		_score.visible = true
	else:
		_score.visible = false


func _value_text(it: Dictionary) -> String:
	if not it.done:
		return "à choisir"
	match it.picker:
		"pil":
			return "n'est pas un ENN_4" if it.value else "reste un ENN_4"
		"tra":
			if it.value == -1:
				return "aucune"
			@warning_ignore("integer_division")
			return "%s devient %s" % [CardDB.code(it.value / 100), CardDB.family_code(it.value % 100)]
	return "aucune" if it.value == -1 else CardDB.code(it.value)


func _choose(i: int, value) -> void:
	items[i].value = value
	items[i].done = true
	main._clear_dialogs()
	_refresh()
	main.refresh_cards()


func _reset(i: int) -> void:
	items[i].value = null
	items[i].done = false
	_refresh()
	main.refresh_cards()


func _on_validate() -> void:
	var value = current_choices() if kind == "scoring" else items[0].value
	kind = ""
	items.clear()
	_panel.visible = false
	main.refresh_cards()
	validated.emit(value)


# --- Fenêtres de choix ---------------------------------------------------------

func _open_picker(i: int) -> void:
	main._clear_dialogs()
	var it: Dictionary = items[i]
	match it.picker:
		"pil":
			var vb: VBoxContainer = main._dialog_box(it.label)
			var row := _row(vb)
			row.add_child(_text_button("Reste un ENN_4", func(): _choose(i, false)))
			row.add_child(_text_button("N'est pas un ENN_4", func(): _choose(i, true)))
			_footer(vb, false, i)
		"tra":
			var targets := []
			for code in it.options:
				@warning_ignore("integer_division")
				var t: int = code / 100
				if not targets.has(t):
					targets.append(t)
			var vb: VBoxContainer = main._dialog_box(it.label + " — choisis la carte")
			_card_grid(vb, targets, func(t): _open_family_picker(i, t))
			_footer(vb, it.allow_none, i)
		_:
			var vb: VBoxContainer = main._dialog_box(it.label)
			_card_grid(vb, it.options, func(card): _choose(i, card))
			_footer(vb, it.allow_none, i)


func _open_family_picker(i: int, target: int) -> void:
	main._clear_dialogs()
	var it: Dictionary = items[i]
	var vb: VBoxContainer = main._dialog_box("TRA#47 : nouvelle famille de %s" % CardDB.code(target))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for code in it.options:
		@warning_ignore("integer_division")
		if code / 100 != target:
			continue
		var fam: int = code % 100
		var b := _text_button(CardDB.family_code(fam), func(): _choose(i, code))
		b.custom_minimum_size = Vector2(110, 40)
		b.add_theme_color_override("font_color", CardDB.FAMILY_COLORS[fam].lightened(0.3))
		grid.add_child(b)
	var row := _row(vb)
	row.add_child(_text_button("Retour", func(): _open_picker(i)))
	row.add_child(_text_button("Annuler", func(): main._clear_dialogs()))


func _card_grid(vb: VBoxContainer, cards: Array, on_pick: Callable) -> void:
	var big := cards.size() <= 7
	var grid := GridContainer.new()
	grid.columns = mini(cards.size(), 7 if big else 10)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var center := CenterContainer.new()
	center.add_child(grid)
	vb.add_child(center)
	for id in cards:
		var b := TextureButton.new()
		b.texture_normal = main.faces.faces[id]
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(110, 154) if big else Vector2(78, 109)
		var card: int = id
		b.pressed.connect(func(): on_pick.call(card))
		b.mouse_entered.connect(func(): main._show_zoom(card))
		grid.add_child(b)


func _footer(vb: VBoxContainer, allow_none: bool, i: int) -> void:
	var row := _row(vb)
	if allow_none:
		row.add_child(_text_button("Aucune", func(): _choose(i, -1)))
	row.add_child(_text_button("Annuler", func(): main._clear_dialogs()))


func _row(vb: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	return row


func _text_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	return b
