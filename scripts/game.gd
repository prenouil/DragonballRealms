# Déroulement d'une partie (règles de Fantasy Realms) : chacun a 7 cartes ; à son tour, on prend
# la carte du dessus de la pioche ou n'importe quelle carte de la défausse, puis on défausse une
# carte. La partie s'arrête dès que la défausse compte 10 cartes (ou que la pioche est vide).
# L'affichage (main.gd) écoute les signaux ; le joueur humain agit par les fonctions human_*.

extends Node

const CardDB = preload("res://scripts/card_db.gd")
const Scoring = preload("res://scripts/scoring.gd")
const Bot = preload("res://scripts/bot.gd")

signal changed                              # l'état a changé : rafraîchir l'affichage
signal turn_started(player: int)
signal message(text: String)
signal choice_requested(kind: String, data: Dictionary)  # question au joueur humain
signal game_over(results: Array)

const HAND_SIZE := 7
const DISCARD_LIMIT := 10
const SAN1 := 1
const MOD := 31
const MAC := 33
const DET := 43
const BAB := 25

var player_count := 4
var humans: Array[bool] = [true, false, false, false]
var names: Array[String] = ["Toi", "Léa", "Hugo", "Inès"]
var hands: Array = []          # une liste de numéros de cartes par joueur
var deck: Array[int] = []      # le dessus de la pioche est la fin de la liste
var discard: Array[int] = []   # dans l'ordre d'arrivée
var masked_discard := {}       # cartes de la défausse masquées par FOR#50
var included_sangoku: Array[bool] = []
var current := 0
var phase := "idle"            # idle, draw, discard, baba_discard, busy, end, over
var bot_delay := 0.9           # pause (s) avant chaque action d'un ordinateur
var results: Array = []
var rng := RandomNumberGenerator.new()

var _answer = null
signal _answered

# Animation qui montre au joueur humain ce que fait un ordinateur (main.gd) ; le jeu attend sa fin.
# Appelée avec (sorte, joueur, carte) : "deck" (pioche), "take" (prise dans la défausse), "discard".
var present_hook := Callable()


func start(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	deck.assign(CardDB.all_ids())
	_shuffle(deck)
	hands.clear()
	included_sangoku.clear()
	for p in player_count:
		var h: Array[int] = []
		for _k in HAND_SIZE:
			h.append(deck.pop_back())
		hands.append(h)
		included_sangoku.append(false)
	discard.clear()
	masked_discard.clear()
	results.clear()
	current = rng.randi_range(0, player_count - 1)
	changed.emit()
	_begin_turn()


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func score_ctx() -> Dictionary:
	return {"discard": discard.duplicate(), "premasked": masked_discard}


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


# Pose une question au joueur humain (ou à personne : réponse par défaut) et attend la réponse.
func _ask(p: int, kind: String, data: Dictionary, bot_answer: Callable) -> Variant:
	if not humans[p]:
		return bot_answer.call()
	_answer = null
	choice_requested.emit(kind, data)
	await _answered
	return _answer


func answer(value) -> void:
	_answer = value
	_answered.emit()


# --- Tours ----------------------------------------------------------------------

func _begin_turn() -> void:
	if phase == "over" or phase == "end":
		return
	if deck.is_empty():
		message.emit("La pioche est vide : fin de la partie.")
		_end_game()
		return
	phase = "draw"
	turn_started.emit(current)
	changed.emit()
	if not humans[current]:
		_bot_turn(current)


func _bot_turn(p: int) -> void:
	phase = "busy"
	await _wait(bot_delay)
	var hand: Array = hands[p].duplicate()
	var disc: Array = discard.duplicate()
	var deck_size := deck.size()
	var ctx := score_ctx()
	var plan: Dictionary = await _think(func(): return Bot.plan_turn(hand, disc, deck_size, ctx))
	match plan.kind:
		"discard":
			await _present("take", p, plan.card)
			_take_from_discard(p, plan.card)
		"detector":
			await _use_detector(p)
			return
		"baba":
			for card in plan.take:
				await _present("take", p, card)
			_baba_take(p, plan.take)
			await _wait(bot_delay)
			await _discard_cards(p, plan.drop)
			return
		_:
			await _present("deck", p, deck.back())
			_draw_from_deck(p)
	await _wait(bot_delay)
	var hand2: Array = hands[p].duplicate()
	var ctx2 := score_ctx()
	var choice: Dictionary = await _think(func(): return Bot.best_discard(hand2, ctx2))
	await _discard_cards(p, [choice.card])


# Réflexion d'un ordinateur : dans un fil séparé pour ne pas figer l'image (sauf en test rapide).
var _thought = null


func _think(task: Callable) -> Variant:
	if bot_delay <= 0.0:
		return task.call()
	_thought = null
	var id := WorkerThreadPool.add_task(func(): _thought = task.call())
	while not WorkerThreadPool.is_task_completed(id):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	return _thought


func _present(kind: String, p: int, card: int) -> void:
	# Les actions d'un ordinateur sont montrées ; pour toi, seulement la carte que tu pioches.
	if not present_hook.is_valid() or (humans[p] and kind != "deck"):
		return
	await present_hook.call(kind, p, card)


func _draw_from_deck(p: int) -> void:
	var card: int = deck.pop_back()
	hands[p].append(card)
	message.emit("%s pioche une carte." % names[p] if not humans[p] else "Tu pioches %s." % CardDB.code(card))
	phase = "discard"
	changed.emit()


func _take_from_discard(p: int, card: int) -> void:
	discard.erase(card)
	hands[p].append(card)
	message.emit("%s prend %s dans la défausse." % [names[p], CardDB.code(card)])
	phase = "discard"
	changed.emit()


func _baba_take(p: int, cards: Array) -> void:
	for card in cards:
		discard.erase(card)
		hands[p].append(card)
	message.emit("%s utilise BAB#25 et prend 3 cartes de la défausse." % names[p])
	phase = "baba_discard"
	changed.emit()


# DET#43 : défausser DET#43, regarder les 3 cartes du dessus de la pioche, en garder une.
func _use_detector(p: int) -> void:
	phase = "busy"
	await _present("discard", p, DET)
	hands[p].erase(DET)
	discard.append(DET)
	message.emit("%s défausse DET#43 et regarde les 3 cartes du dessus de la pioche." % names[p])
	changed.emit()
	if discard.size() >= DISCARD_LIMIT:
		_end_game()
		return
	var top: Array = deck.slice(maxi(0, deck.size() - 3))
	top.reverse()
	var ctx := score_ctx()
	var hand: Array = hands[p]
	var pick: int = await _ask(p, "detector", {"options": top}, func(): return Bot.pick_best(hand, top, ctx))
	await _present("deck", p, pick)
	deck.erase(pick)
	hands[p].append(pick)
	changed.emit()
	await _wait(bot_delay * 0.5)
	_next_player(false)


# Défausse une ou plusieurs cartes (plusieurs : BAB#25), puis applique MOD#31 et MAC#33.
func _discard_cards(p: int, cards: Array) -> void:
	phase = "busy"
	var replay := false
	for card in cards:
		await _present("discard", p, card)
		hands[p].erase(card)
		discard.append(card)
		changed.emit()
	message.emit("%s défausse %s." % [names[p], ", ".join(cards.map(func(c): return CardDB.code(c)))])
	changed.emit()
	if cards.has(MOD) and deck.has(SAN1):
		var hand: Array = hands[p]
		var ctx := score_ctx()
		var yes: bool = await _ask(p, "module", {}, func(): return Bot.wants_module(hand, ctx))
		if yes:
			deck.erase(SAN1)
			discard.erase(MOD)
			deck.append(MOD)
			_shuffle(deck)
			discard.append(SAN1)
			message.emit("%s place SAN#1 dans la défausse et mélange MOD#31 avec la pioche." % names[p])
			changed.emit()
	if discard.size() >= DISCARD_LIMIT:
		_end_game()
		return
	if cards.has(MAC):
		replay = await _ask(p, "machine", {}, func(): return true)
		if replay:
			message.emit("%s rejoue grâce à MAC#33." % names[p])
	_next_player(replay)


func _next_player(replay: bool) -> void:
	if not replay:
		current = (current + 1) % player_count
	_begin_turn()


# --- Actions du joueur humain -------------------------------------------------

func _human_can(p: int, wanted_phase: String) -> bool:
	return phase == wanted_phase and p == current and humans[p]


func human_draw_deck(p: int) -> void:
	if _human_can(p, "draw") and not deck.is_empty():
		phase = "busy"
		changed.emit()
		await _present("deck", p, deck.back())
		_draw_from_deck(p)


func human_take_discard(p: int, card: int) -> void:
	if _human_can(p, "draw") and discard.has(card):
		_take_from_discard(p, card)


func human_discard(p: int, card: int) -> void:
	if _human_can(p, "discard") and hands[p].has(card):
		_discard_cards(p, [card])


func human_use_detector(p: int) -> void:
	if _human_can(p, "draw") and hands[p].has(DET) and deck.size() >= 1:
		_use_detector(p)


func human_baba_take(p: int, cards: Array) -> void:
	if _human_can(p, "draw") and hands[p].has(BAB) and cards.size() == 3:
		for card in cards:
			if not discard.has(card):
				return
		_baba_take(p, cards)


# Deux cartes en plus de BAB#25.
func human_baba_discard(p: int, cards: Array) -> void:
	if _human_can(p, "baba_discard") and cards.size() == 2 and not cards.has(BAB):
		_discard_cards(p, [BAB] + cards)


# --- Fin de partie -------------------------------------------------------------

func _end_game() -> void:
	phase = "end"
	message.emit("La défausse est pleine : fin de la partie !" if discard.size() >= DISCARD_LIMIT else "Fin de la partie !")
	changed.emit()
	await _wait(bot_delay)
	for effect in CardDB.END_EFFECTS:
		for k in player_count:
			var p := (current + 1 + k) % player_count
			if hands[p].has(effect):
				await _end_effect(p, effect)
	# SAN#1 dans la défausse : chacun choisit de le compter ou non comme 8e carte.
	for p in player_count:
		included_sangoku[p] = false
		if discard.has(SAN1):
			var hand: Array = hands[p]
			var d := discard.duplicate()
			var pm := masked_discard
			var with_s: int = Scoring.best(hand + [SAN1], {"discard": _without(d, SAN1), "premasked": pm}).total
			var without_s: int = Scoring.best(hand, {"discard": d, "premasked": pm}).total
			included_sangoku[p] = await _ask(p, "sangoku", {"with": with_s, "without": without_s},
				func(): return with_s > without_s)
	results.clear()
	for p in player_count:
		var hand: Array = hands[p].duplicate()
		var d := discard.duplicate()
		if included_sangoku[p]:
			hand.append(SAN1)
			d.erase(SAN1)
		var ctx := {"discard": d, "premasked": masked_discard}
		var r: Dictionary
		if humans[p] and not Scoring.choice_specs(hand).is_empty():
			# Le joueur humain fait lui-même les choix de ses cartes.
			var choices: Dictionary = await _ask(p, "scoring", {"hand": hand, "ctx": ctx}, func(): return {})
			r = Scoring.evaluate(hand, ctx, choices)
		else:
			r = Scoring.best(hand, ctx)
		r["player"] = p
		r["name"] = names[p]
		r["hand"] = hand
		results.append(r)
	phase = "over"
	changed.emit()
	game_over.emit(results)


func _without(a: Array, card: int) -> Array:
	var b := a.duplicate()
	b.erase(card)
	return b


func _end_effect(p: int, effect: int) -> void:
	var ctx := score_ctx()
	var hand: Array = hands[p]
	match effect:
		50:  # FOR#50 : masquer une carte de la défausse
			if discard.is_empty():
				return
			var pick: int = await _ask(p, "end_mask", {"options": discard.duplicate()},
				func(): return Bot.pick_discard_to_mask(hands, p, discard, ctx))
			if pick > 0:
				masked_discard[pick] = true
				message.emit("%s masque %s dans la défausse (FOR#50)." % [names[p], CardDB.code(pick)])
		42:  # RAD#42 : prendre une BdC de la défausse
			var options := discard.filter(func(c): return CardDB.is_bdc(c))
			if options.is_empty():
				return
			var pick: int = await _ask(p, "end_take", {"options": options, "effect": effect},
				func(): return Bot.pick_from_discard(hand, options, ctx))
			if pick > 0:
				await _present("take", p, pick)
				discard.erase(pick)
				hands[p].append(pick)
				message.emit("%s prend %s dans la défausse (RAD#42)." % [names[p], CardDB.code(pick)])
		54:  # SHE#54 : prendre une carte de la défausse sauf une BdC
			var options := discard.filter(func(c): return not CardDB.is_bdc(c))
			if options.is_empty():
				return
			var pick: int = await _ask(p, "end_take", {"options": options, "effect": effect},
				func(): return Bot.pick_from_discard(hand, options, ctx))
			if pick > 0:
				await _present("take", p, pick)
				discard.erase(pick)
				hands[p].append(pick)
				message.emit("%s prend %s dans la défausse (SHE#54)." % [names[p], CardDB.code(pick)])
		1:  # SAN#1 : piocher une carte, SAN#1 part dans la défausse
			if not deck.is_empty():
				await _present("deck", p, deck.back())
				hands[p].append(deck.pop_back())
				changed.emit()
			await _present("discard", p, SAN1)
			hands[p].erase(SAN1)
			discard.append(SAN1)
			message.emit("%s pioche une carte et place SAN#1 dans la défausse." % names[p])
	changed.emit()
	await _wait(bot_delay)
