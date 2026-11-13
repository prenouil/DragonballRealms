# Décisions des joueurs gérés par l'ordinateur : ils comparent le score de leur main
# pour chaque possibilité (calcul rapide de scoring.gd).

const CardDB = preload("res://scripts/card_db.gd")
const Scoring = preload("res://scripts/scoring.gd")

const DECK_HOPE := 6        # gain espéré en piochant une carte inconnue
const DETECTOR_HOPE := 10   # gain espéré en choisissant parmi 3 cartes
const DET := 43
const BAB := 25


static func score(hand: Array, ctx: Dictionary) -> int:
	return Scoring.best(hand, ctx, true).total


static func without(hand: Array, card: int) -> Array:
	var h := hand.duplicate()
	h.erase(card)
	return h


# Meilleure carte à défausser d'une main : {card, score}.
static func best_discard(hand: Array, ctx: Dictionary) -> Dictionary:
	var best := {"card": hand[0], "score": -100000}
	for card in hand:
		var s := score(without(hand, card), ctx)
		if s > best.score:
			best = {"card": card, "score": s}
	return best


# Choix du début de tour : {"kind": "deck"} ; {"kind": "discard", "card"} ;
# {"kind": "detector"} ; {"kind": "baba", "take": [3 cartes], "drop": [3 cartes dont BAB#25]}.
static func plan_turn(hand: Array, discard: Array, deck_size: int, ctx: Dictionary) -> Dictionary:
	var current := score(hand, ctx)
	var plan := {"kind": "deck"}
	var value := current + DECK_HOPE
	if deck_size == 0:
		value = -100000
	for card in discard:
		var r := best_discard(hand + [card], ctx)
		if r.card != card and r.score > value:
			value = r.score
			plan = {"kind": "discard", "card": card}
	if hand.has(DET) and deck_size >= 3:
		var v := score(without(hand, DET), ctx) + DETECTOR_HOPE + DECK_HOPE
		if v > value:
			value = v
			plan = {"kind": "detector"}
	if hand.has(BAB) and discard.size() >= 3:
		var baba := _plan_baba(hand, discard, ctx)
		if baba.score > value + 2:
			value = baba.score
			plan = {"kind": "baba", "take": baba.take, "drop": baba.drop}
	return plan


# BAB#25 : prendre 3 cartes de la défausse puis en défausser 3 dont BAB#25 (choix gloutons).
static func _plan_baba(hand: Array, discard: Array, ctx: Dictionary) -> Dictionary:
	var h := hand.duplicate()
	var take := []
	for _k in 3:
		var best_card := -1
		var best_s := -100000
		for card in discard:
			if take.has(card):
				continue
			var s := score(h + [card], ctx)
			if s > best_s:
				best_s = s
				best_card = card
		take.append(best_card)
		h.append(best_card)
	h.erase(BAB)
	var drop := [BAB]
	for _k in 2:
		var r := best_discard(h, ctx)
		drop.append(r.card)
		h.erase(r.card)
	return {"take": take, "drop": drop, "score": score(h, ctx)}


# DET#43 : la meilleure des cartes proposées.
static func pick_best(hand: Array, options: Array, ctx: Dictionary) -> int:
	var best_card: int = options[0]
	var best_s := -100000
	for card in options:
		var s := score(hand + [card], ctx)
		if s > best_s:
			best_s = s
			best_card = card
	return best_card


# MOD#31 : chercher SAN#1 seulement s'il rapporte nettement plus en 8e carte.
static func wants_module(hand: Array, ctx: Dictionary) -> bool:
	return score(hand + [1], ctx) > score(hand, ctx) + 10


# FIN DE PARTIE : prendre une carte de la défausse (RAD#42, SHE#54), ou -1.
static func pick_from_discard(hand: Array, options: Array, ctx: Dictionary) -> int:
	var best_card := -1
	var best_s := score(hand, ctx)
	for card in options:
		var s := score(hand + [card], ctx)
		if s > best_s:
			best_s = s
			best_card = card
	return best_card


# FOR#50 : masquer la carte de la défausse qui avantage le plus ce joueur face aux autres.
# hands : mains de tous les joueurs ; p : ce joueur.
static func pick_discard_to_mask(hands: Array, p: int, discard: Array, base_ctx: Dictionary) -> int:
	var best_card := -1
	var best_gap := _gap(hands, p, discard, base_ctx.get("premasked", {}))
	for card in discard:
		var premasked: Dictionary = base_ctx.get("premasked", {}).duplicate()
		premasked[card] = true
		var gap := _gap(hands, p, discard, premasked)
		if gap > best_gap:
			best_gap = gap
			best_card = card
	return best_card


static func _gap(hands: Array, p: int, discard: Array, premasked: Dictionary) -> int:
	var mine := 0
	var others := -100000
	for q in hands.size():
		var s: int = best_with_sangoku(hands[q], discard, premasked).score
		if q == p:
			mine = s
		else:
			others = maxi(others, s)
	return mine - others


# Score avec ou sans SAN#1 en 8e carte (s'il est dans la défausse) : {score, include}.
static func best_with_sangoku(hand: Array, discard: Array, premasked: Dictionary) -> Dictionary:
	var ctx := {"discard": discard, "premasked": premasked}
	var without_s := score(hand, ctx)
	if not discard.has(1):
		return {"score": without_s, "include": false}
	var ctx2 := {"discard": without(discard, 1), "premasked": premasked}
	var with_s := score(hand + [1], ctx2)
	return {"score": maxi(with_s, without_s), "include": with_s > without_s}
