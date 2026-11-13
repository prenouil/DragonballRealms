# Calcul du score d'une main (règles de Fantasy Realms, cartes de Dragonball Realms).
#
# Étapes : 1) identités (jokers, TRA#47, VEG#20, PIC#10, BRO#5, PIL#19) ;
# 2) cartes masquées, calculées par tours jusqu'à stabilité (une carte masquée ne masque plus rien,
#    deux cartes qui se masquent l'une l'autre restent masquées toutes les deux) ;
# 3) valeur de base + bonus + malus des cartes non masquées, plus le barème des BdC.
#
# Les choix laissés au joueur (cible d'EXP#37, carte protégée par SEN#44 ou CHA#9, identité des
# jokers, famille changée par TRA#47, carte gardée par BRO#5…) sont faits au mieux par best().
#
# ctx : {"discard": Array (cartes de la défausse), "premasked": Dictionary (numéro -> true,
#        cartes masquées par FOR#50)}

const CardDB = preload("res://scripts/card_db.gd")

const SAY := CardDB.SAY
const COM := CardDB.COM
const ALL := CardDB.ALL
const ENN := CardDB.ENN
const MAI := CardDB.MAI
const LIE := CardDB.LIE
const DEP := CardDB.DEP
const TEC := CardDB.TEC
const OBJ := CardDB.OBJ
const TRA := CardDB.TRA
const JOK := CardDB.JOK

# Numéros des cartes utilisées par les règles.
const SAN1 := 1
const SAN2 := 2
const GOT := 3
const TRU := 4
const BRO := 5
const KRI := 6
const YAM := 7
const TEN := 8
const CHA := 9
const PIC := 10
const BUL := 11
const YAJ := 12
const VID := 13
const SAT := 14
const CHI := 15
const CEL := 16
const FRE := 17
const BUU := 18
const PIL := 19
const VEG := 20
const TOR := 21
const KAR := 22
const TPU := 23
const KAI := 24
const TMO := 26
const PLA := 27
const KAH := 28
const CAN := 29
const SAL := 30
const MOD := 31
const VAI := 32
const MAC := 33
const NUA := 34
const DIN := 35
const KAM := 36
const EXP := 37
const KIE := 38
const GEN := 39
const IMA := 40
const PET := 41
const RAD := 42
const SEN := 44
const CAP := 45
const SIN := 46
const TRM := 47
const SUP := 48
const ASS := 49
const FOR := 50
const OOL := 51
const DRB := 52
const CHG := 53
const SHE := 54

const MAX_ROUNDS := 12


# Meilleur score possible de la main, en essayant les choix. fast : moins d'essais (ordinateurs).
static func best(hand: Array, ctx: Dictionary, fast := false) -> Dictionary:
	var specs := choice_specs(hand)
	var choices := {}
	for s in specs:
		choices[s.key] = s.options[0]
	var product := 1
	for s in specs:
		product *= s.options.size()
		if product > 1000000:
			break
	var limit := 120 if fast else 3000
	if product <= limit:
		return _exhaustive(hand, ctx, specs)
	# Trop de combinaisons : on améliore un choix à la fois.
	var best_r := evaluate(hand, ctx, choices)
	for _pass in (1 if fast else 3):
		var improved := false
		for s in specs:
			for o in s.options:
				if o == choices[s.key]:
					continue
				var trial := choices.duplicate()
				trial[s.key] = o
				var r := evaluate(hand, ctx, trial)
				if r.total > best_r.total:
					best_r = r
					choices = trial
					improved = true
		if not improved:
			break
	return best_r


static func _exhaustive(hand: Array, ctx: Dictionary, specs: Array) -> Dictionary:
	var idx := []
	idx.resize(specs.size())
	idx.fill(0)
	var best_r := {}
	while true:
		var choices := {}
		for k in specs.size():
			choices[specs[k].key] = specs[k].options[idx[k]]
		var r := evaluate(hand, ctx, choices)
		if best_r.is_empty() or r.total > best_r.total:
			best_r = r
		# Combinaison suivante.
		var k := 0
		while k < specs.size():
			idx[k] += 1
			if idx[k] < specs[k].options.size():
				break
			idx[k] = 0
			k += 1
		if k >= specs.size():
			break
	return best_r


# Choix possibles pour une main : [{key, options}], la première option est celle par défaut.
static func choice_specs(hand: Array) -> Array:
	var specs := []
	var others := func(self_id: int) -> Array:
		var a := []
		for id in hand:
			if id != self_id:
				a.append(id)
		return a
	if hand.has(OOL):
		var opts := [-1]
		for id in hand:
			if id != OOL and id != BRO:
				opts.append(id)
		specs.append({"key": "ool", "options": opts})
	if hand.has(DRB):
		specs.append({"key": "drb", "options": [-1] + CardDB.ids_of_families([DEP, OBJ, LIE, TEC, TRA])})
	if hand.has(CHG):
		specs.append({"key": "chg", "options": [-1] + CardDB.ids_of_families([SAY, COM, ENN, ALL, MAI])})
	if hand.has(TRM):
		var opts := [-1]
		for id in others.call(TRM):
			for f in range(1, 12):
				if f != CardDB.family(id):
					opts.append(id * 100 + f)
		specs.append({"key": "tra", "options": opts})
	if hand.has(PIL):
		specs.append({"key": "pil", "options": [false, true]})
	if hand.has(SEN):
		specs.append({"key": "sen", "options": [-1] + others.call(SEN)})
	if hand.has(CHA):
		specs.append({"key": "cha", "options": [-1] + others.call(CHA)})
	if hand.has(EXP):
		var opts: Array = others.call(EXP)
		specs.append({"key": "exp", "options": opts if not opts.is_empty() else [-1]})
	if hand.has(BRO):
		for f in range(1, 12):
			var cands := []
			for id in hand:
				if id != BRO and id != SEN and (CardDB.family(id) == f or CardDB.family(id) == JOK):
					cands.append(id)
			if cands.size() > 1:
				specs.append({"key": "bro%d" % f, "options": cands})
	return specs


# Score de la main pour des choix donnés.
# Résultat : {total, bdc_count, bdc_points, cards: [{id, masked, base, bonus, malus, points, notes}]}
static func evaluate(hand: Array, ctx: Dictionary, choices: Dictionary) -> Dictionary:
	var discard: Array = ctx.get("discard", [])
	var premasked: Dictionary = ctx.get("premasked", {})
	var n := hand.size()
	var cs := []
	for id in hand:
		cs.append({"id": id, "names": [id], "fams": [CardDB.family(id)], "base": CardDB.base(id),
			"bdc": CardDB.is_bdc(id), "malus": id, "pic": 0, "veg": false, "notes": []})

	# --- 1. Identités ------------------------------------------------------------
	var all_present := {}  # aucune carte masquée à ce stade
	var t_ool: int = choices.get("ool", -1)
	var t_drb: int = choices.get("drb", -1)
	var t_chg: int = choices.get("chg", -1)
	for c in cs:
		match c.id:
			OOL:
				c.malus = -1
				if t_ool > 0 and hand.has(t_ool):
					c.names.append(t_ool)
					c.base = CardDB.base(t_ool)
					c.fams = [CardDB.family(t_ool)]
					c.malus = t_ool
					c.notes.append("copie " + CardDB.code(t_ool))
			DRB:
				c.malus = -1
				if t_drb > 0:
					c.names.append(t_drb)
					c.fams = [CardDB.family(t_drb)]
					c.notes.append("devient " + CardDB.code(t_drb))
			CHG:
				c.malus = -1
				if t_chg > 0:
					c.names.append(t_chg)
					c.fams = [CardDB.family(t_chg)]
					c.notes.append("devient " + CardDB.code(t_chg))
	var t_tra: int = choices.get("tra", -1)
	if t_tra > 0:
		@warning_ignore("integer_division")
		var target := t_tra / 100
		var fam := t_tra % 100
		for c in cs:
			if c.id == target:
				c.fams = [fam]
				c.notes.append("famille changée en " + CardDB.family_code(fam) + " par TRA#47")
	for me in n:
		var c: Dictionary = cs[me]
		match c.id:
			BRO:
				for f in [ENN, COM, TRA]:
					if not c.fams.has(f):
						c.fams.append(f)
			VEG:
				if _has_any_name(cs, all_present, [TRU, GOT, BUL], me):
					c.fams = [SAY, ALL]
					c.veg = true
					c.notes.append("devient SAY_1 et ALL_3")
			PIC:
				if _has_any_name(cs, all_present, [SAN2, GOT], me):
					c.pic = 1
					if not c.fams.has(MAI):
						c.fams.append(MAI)
					c.notes.append("aussi MAI_5")
				elif _count_bdc(cs, all_present, me) > 0:
					c.pic = 2
					if not c.fams.has(ENN):
						c.fams.append(ENN)
					c.notes.append("aussi ENN_4")
			PIL:
				if choices.get("pil", false):
					c.fams.erase(ENN)
					c.notes.append("n'est pas un ENN_4")

	# --- 2. Cartes masquées ------------------------------------------------------
	var immune := {}     # index -> true : ne peut jamais être masquée
	var protected := {}  # index -> true : protégée (sauf contre BRO#5 et EXP#37)
	var fixed := {}      # index -> true : masquée quoi qu'il arrive
	var index_of := {}
	for i in n:
		index_of[cs[i].id] = i
		if cs[i].id == BRO or cs[i].id == SEN:
			immune[i] = true
		if premasked.has(cs[i].id):
			fixed[i] = true
			cs[i].notes.append("masquée par FOR#50")
	var t_sen: int = choices.get("sen", -1)
	if index_of.has(SEN) and index_of.has(t_sen) and t_sen != SEN:
		protected[index_of[t_sen]] = true
		cs[index_of[t_sen]].notes.append("protégée par SEN#44")
	var t_cha: int = choices.get("cha", -1)
	if index_of.has(CHA) and index_of.has(t_cha) and t_cha != CHA:
		fixed[index_of[CHA]] = true
		protected[index_of[t_cha]] = true
		cs[index_of[CHA]].notes.append("se masque pour protéger " + CardDB.code(t_cha))
		cs[index_of[t_cha]].notes.append("protégée par CHA#9")
	var t_exp: int = choices.get("exp", -1)
	var exp_target: int = index_of.get(t_exp, -1) if t_exp != EXP else -1

	var masked := fixed.duplicate()
	var previous := {}
	var cleared := {}
	var exp_hit := false
	for _round in MAX_ROUNDS:
		cleared = _cleared(cs, masked)
		var result := _apply_masks(cs, masked, cleared, immune, protected, fixed, exp_target, discard, choices)
		var new_masked: Dictionary = result.masked
		exp_hit = result.exp_hit
		if _same_keys(new_masked, masked):
			break
		if _same_keys(new_masked, previous):
			# Les cartes se masquent l'une l'autre en boucle : toutes restent masquées.
			for k in new_masked:
				masked[k] = true
			cleared = _cleared(cs, masked)
			break
		previous = masked
		masked = new_masked

	# --- 3. Points -----------------------------------------------------------------
	var got_active := false   # malus de GOT#3 (ou d'une copie) : enlève les bonus des SAY_1 / COM_2
	var got_source := -1
	for i in n:
		if cs[i].malus == GOT and not masked.has(i) and not cleared.has(i) and _count_fam(cs, masked, MAI, i) == 0:
			got_active = true
			got_source = i
	var masked_count := masked.size()
	var cards := []
	var total := 0
	for i in n:
		var c: Dictionary = cs[i]
		var entry := {"id": c.id, "masked": masked.has(i), "base": 0, "bonus": 0, "malus": 0, "points": 0,
			"notes": c.notes}
		if not masked.has(i):
			entry.base = c.base
			var bonus := _bonus(cs, i, masked, discard, premasked, exp_hit, exp_target)
			var malus_on: bool = c.malus > 0 and (not cleared.has(i) or c.malus == BRO)
			if got_active and i != got_source and (c.fams.has(SAY) or c.fams.has(COM)) and bonus != 0:
				bonus = 0
				c.notes.append("bonus enlevé par GOT#3")
			if malus_on and c.malus == SAN2 and masked_count == 0 and bonus != 0:
				bonus = 0
				c.notes.append("perd son bonus (aucune carte masquée)")
			if cleared.has(i) and c.malus > 0 and c.malus != BRO:
				c.notes.append("malus supprimé")
			entry.bonus = bonus
			if malus_on:
				entry.malus = _malus(cs, i, masked)
			entry.points = entry.base + entry.bonus + entry.malus
			total += entry.points
		cards.append(entry)
	var bdc_count := _count_bdc(cs, masked, -1)
	var bdc_points: int = CardDB.BDC_POINTS[mini(bdc_count, 7)]
	total += bdc_points
	return {"total": total, "bdc_count": bdc_count, "bdc_points": bdc_points, "cards": cards, "choices": choices}


# Cartes dont le malus est supprimé (CHI#15, IMA#40), d'après les cartes non masquées.
static func _cleared(cs: Array, masked: Dictionary) -> Dictionary:
	var cleared := {}
	for i in cs.size():
		if masked.has(i):
			continue
		match cs[i].id:
			CHI:
				if _has_any_name(cs, masked, [SAN2, GOT], i):
					for j in cs.size():
						if j != i and (cs[j].names.has(SAN2) or cs[j].names.has(GOT)):
							cleared[j] = true
			IMA:
				for j in cs.size():
					if j != i and cs[j].fams.has(TEC):
						cleared[j] = true
	return cleared


# Un tour de calcul des cartes masquées, à partir des cartes masquées du tour précédent.
static func _apply_masks(cs: Array, masked: Dictionary, cleared: Dictionary, immune: Dictionary,
		protected: Dictionary, fixed: Dictionary, exp_target: int, discard: Array, choices: Dictionary) -> Dictionary:
	var out := fixed.duplicate()
	var exp_hit := false
	var n := cs.size()
	var hit := func(j: int, ignore_protection: bool) -> bool:
		if immune.has(j):
			return false
		if protected.has(j) and not ignore_protection:
			return false
		out[j] = true
		return true
	for i in n:
		if masked.has(i):
			continue  # une carte masquée n'a plus d'effet
		var c: Dictionary = cs[i]
		# Effet de bonus : PIC#10 (en ENN_4) masque TOU#23.
		if c.id == PIC and c.pic == 2:
			for j in n:
				if j != i and cs[j].names.has(TPU):
					hit.call(j, false)
		var m: int = c.malus
		if m <= 0 or (cleared.has(i) and m != BRO):
			continue
		match m:
			BRO:
				for f in range(1, 12):
					var cands := []
					for j in n:
						if j != i and not immune.has(j) and cs[j].fams.has(f):
							cands.append(j)
					if cands.size() <= 1:
						continue
					var keep: int = cands[0]
					var wanted: int = choices.get("bro%d" % f, -1)
					for j in cands:
						if cs[j].id == wanted:
							keep = j
					for j in cands:
						if j != keep:
							hit.call(j, true)
			YAM:
				if _count_bdc(cs, masked, i) == 0:
					hit.call(i, false)
			TEN:
				var cha_masked := false
				for j in n:
					if cs[j].id == CHA and masked.has(j):
						cha_masked = true
				if cha_masked or discard.has(CHA):
					hit.call(i, false)
			YAJ:
				if _count_fam(cs, masked, ENN, i) > 0:
					hit.call(i, false)
			CEL:
				for j in n:
					if j != i and (cs[j].fams.has(COM) or cs[j].fams.has(MAI) or cs[j].names.has(SAT)):
						hit.call(j, false)
			FRE:
				for j in n:
					if j == i:
						continue
					if cs[j].names.has(KRI) or cs[j].names.has(VEG) or (cs[j].bdc and not cs[j].names.has(SAN1)):
						hit.call(j, false)
			BUU:
				for j in n:
					if j != i and not cs[j].names.has(SAT) and (cs[j].fams.has(ENN) or cs[j].fams.has(MAI) or cs[j].fams.has(ALL)):
						hit.call(j, false)
			PIL:
				if _has_any_name(cs, masked, [PET], i):
					hit.call(i, false)
			VEG:
				if c.fams.has(ENN):
					for j in n:
						if j != i and cs[j].fams.has(COM):
							hit.call(j, false)
			EXP:
				if exp_target >= 0 and exp_target != i:
					if hit.call(exp_target, true):
						exp_hit = true
			KIE:
				for j in n:
					if j != i and (cs[j].fams.has(SAY) or cs[j].names.has(FRE) or cs[j].names.has(SIN)):
						hit.call(j, false)
			SIN:
				if _count_fam(cs, masked, SAY, i) == 0 and not _has_any_name(cs, masked, [VEG], i):
					hit.call(i, false)
			SUP:
				if _count_fam(cs, masked, SAY, i) == 0:
					hit.call(i, false)
			SHE:
				if _count_bdc(cs, masked, i) == 0:
					hit.call(i, false)
	return {"masked": out, "exp_hit": exp_hit}


static func _bonus(cs: Array, i: int, masked: Dictionary, discard: Array, premasked: Dictionary,
		exp_hit: bool, exp_target: int) -> int:
	var c: Dictionary = cs[i]
	match c.id:
		SAN2:
			return 33 if _count_fam(cs, masked, ENN, i) > 0 else 0
		TRU:
			var k := _names_present(cs, masked, [BUL, VEG, MAC], i)
			return 100 if k == 3 else 15 * k
		KRI:
			return (15 if _count_fam(cs, masked, TEC, i) > 0 else 0) + 10 * _count_fam(cs, masked, ALL, i)
		YAM:
			return 8 * (_count_fam(cs, masked, ALL, i) + _count_fam(cs, masked, COM, i))
		TEN:
			return 11 * _names_present(cs, masked, [SAN1, YAM, TOR], i)
		CHA:
			return 21 if _has_any_name(cs, masked, [TEN], i) else 0
		PIC:
			if c.pic == 1 and _has_any_name(cs, masked, [SAN2, GOT], i):
				return 30
			if c.pic == 2 and _count_bdc(cs, masked, i) > 0:
				return 20
			return 0
		BUL:
			var cites := 0
			for j in cs.size():
				if j != i and not masked.has(j) and CardDB.cites_bulma(cs[j].id):
					cites += 1
			return 8 * _count_fam(cs, masked, OBJ, i) + 5 * cites
		YAJ:
			return 20 if _has_any_name(cs, masked, [SEN, CAN], i) else 0
		VID:
			return (19 if _has_any_name(cs, masked, [SAN2], i) else 0) + (14 if _has_any_name(cs, masked, [SAT], i) else 0)
		SAT:
			var b := 0
			if _has_any_name(cs, masked, [TMO], i) and _count_fam(cs, masked, COM, i) == 0 \
					and _count_fam(cs, masked, SAY, i) == 0 and _count_fam(cs, masked, ENN, i) == 0:
				b += 50
			if _has_any_name(cs, masked, [GEN], i):
				b += 20
			if _has_any_name(cs, masked, [BUU], i):
				b += 30
			return b
		CHI:
			return 25 if _has_any_name(cs, masked, [SAN2, GOT], i) else 0
		CEL:
			return (20 if _has_any_name(cs, masked, [MAC], i) else 0) + 13 * _count_fam(cs, masked, SAY, i)
		BUU:
			return 25 * masked.size()
		PIL:
			return 11 * _count_bdc(cs, masked, i)
		VEG:
			return 20 if c.veg and _has_any_name(cs, masked, [TRU, GOT, BUL], i) else 0
		TOR:
			return 8 * _count_fam(cs, masked, TEC, i) + (20 if _has_any_name(cs, masked, [KAH], i) else 0)
		KAR:
			var best_count := 0
			for f in range(1, 12):
				best_count = maxi(best_count, _count_fam(cs, masked, f, -1))
			if best_count >= 5:
				return 120
			if best_count == 4:
				return 60
			return 20 if best_count == 3 else 0
		TPU:
			return (21 if _has_any_name(cs, masked, [SHE], i) else 0) + 14 * _names_present(cs, masked, [PLA, VAI], i)
		KAI:
			var k := 0
			for j in cs.size():
				if not masked.has(j) and (cs[j].fams.has(COM) or cs[j].fams.has(SAY)):
					k += 1
			for id in discard:
				if not premasked.has(id) and (CardDB.family(id) == COM or CardDB.family(id) == SAY):
					k += 1
			return 8 * k
		TMO:
			return 30 if _names_present(cs, masked, [SAT, TEN, TOR, SAN1], i) == 1 else 0
		PLA:
			return 10 * _count_fam(cs, masked, DEP, i)
		KAH:
			return 11 * _count_fam(cs, masked, ALL, i) + 5 * _count_fam(cs, masked, COM, i) + 5 * _count_fam(cs, masked, LIE, i)
		CAN:
			var masked_com := 0
			for j in masked:
				if cs[j].fams.has(COM):
					masked_com += 1
			return 7 * _count_fam(cs, masked, ENN, i) + 7 * _count_fam(cs, masked, TRA, i) + 12 * masked_com
		SAL:
			var k := 0
			for j in cs.size():
				if not masked.has(j) and (cs[j].fams.has(SAY) or cs[j].fams.has(COM) or cs[j].fams.has(ENN)):
					k += 1
			return 40 if k == 2 else 0
		MOD:
			return 11 * _count_fam(cs, masked, LIE, i)
		VAI:
			return 7 * _count_fam(cs, masked, LIE, i) + 7 * _count_fam(cs, masked, DEP, i)
		NUA:
			return 17 if _has_any_name(cs, masked, [KAR, SAN1, SAN2], i) else 0
		DIN:
			return 9 * _count_fam(cs, masked, LIE, i) + (10 if _has_any_name(cs, masked, [SAN1], i) else 0)
		EXP:
			if exp_hit and exp_target >= 0:
				var t: Dictionary = cs[exp_target]
				if t.names.has(VEG) or t.names.has(CHA) or t.names.has(CEL):
					return 35
			return 0
		GEN:
			if _has_any_name(cs, masked, [SAN1], i) and _count_fam(cs, masked, ENN, i) > 0 \
					and _count_fam(cs, masked, LIE, i) > 0 and _count_fam(cs, masked, DEP, i) > 0:
				return 60
			return 0
		IMA:
			return 8 * _count_fam(cs, masked, TEC, i)
		PET:
			var b := 0
			if _has_any_name(cs, masked, [BUL], i) != _has_any_name(cs, masked, [TOR], i):
				b += 16
			var k := _names_present(cs, masked, [OOL, SHE], i)
			b += 36 if k == 2 else 6 * k
			return b
		RAD:
			return 20 * mini(_count_bdc(cs, masked, -1), _count_fam(cs, masked, LIE, -1))
		CAP:
			return (20 if _has_any_name(cs, masked, [BUL, DRB], i) else 0) + 11 * _count_fam(cs, masked, OBJ, i)
		SIN:
			return 25 if _has_any_name(cs, masked, [TMO, CAN, PIL], i) else 0
		SUP:
			return 10 * _count_fam(cs, masked, SAY, i) + 10 * _count_fam(cs, masked, ENN, i)
		ASS:
			var b := 20 if _has_any_name(cs, masked, [CEL, BUU], i) else 0
			var best_base := 0
			for j in cs.size():
				if j == i or masked.has(j) or cs[j].names.has(BRO):
					continue
				for f in [SAY, COM, ALL, MAI, ENN]:
					if cs[j].fams.has(f):
						best_base = maxi(best_base, cs[j].base)
			return b + best_base
		FOR:
			return 35 if _has_any_name(cs, masked, [FRE, BUU, CEL], i) else 0
	return 0


# Malus en points (les malus qui masquent sont traités dans _apply_masks).
static func _malus(cs: Array, i: int, masked: Dictionary) -> int:
	match cs[i].malus:
		GOT:
			return -40 if _count_fam(cs, masked, MAI, i) == 0 else 0
		CHI:
			return -20 if _has_any_name(cs, masked, [SAN1], i) else 0
		VEG:
			if cs[i].fams.has(ENN):
				var k := 0
				for j in masked:
					if cs[j].fams.has(COM):
						k += 1
				return 20 * k
			return 0
		KAM:
			var k := 0
			for j in cs.size():
				if j == i or masked.has(j):
					continue
				var f: Array = cs[j].fams
				if f.has(SAY) or f.has(ENN) or f.has(TEC) or f.has(DEP):
					continue
				if cs[j].names.has(KRI) or cs[j].names.has(TOR):
					continue
				k += 1
			return -10 * k
	return 0


# --- Outils ---------------------------------------------------------------------

# Nombre de cartes non masquées (autres que skip) de la famille f.
static func _count_fam(cs: Array, masked: Dictionary, f: int, skip: int) -> int:
	var k := 0
	for j in cs.size():
		if j != skip and not masked.has(j) and cs[j].fams.has(f):
			k += 1
	return k


static func _count_bdc(cs: Array, masked: Dictionary, skip: int) -> int:
	var k := 0
	for j in cs.size():
		if j != skip and not masked.has(j) and cs[j].bdc:
			k += 1
	return k


static func _has_any_name(cs: Array, masked: Dictionary, names: Array, skip: int) -> bool:
	for j in cs.size():
		if j == skip or masked.has(j):
			continue
		for nm in names:
			if cs[j].names.has(nm):
				return true
	return false


# Combien de noms de la liste sont présents (chacun compte une fois).
static func _names_present(cs: Array, masked: Dictionary, names: Array, skip: int) -> int:
	var k := 0
	for nm in names:
		if _has_any_name(cs, masked, [nm], skip):
			k += 1
	return k


static func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
	return true
