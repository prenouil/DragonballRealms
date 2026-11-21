# Vérifie le calcul des scores sur des mains connues.
# Lancer : Godot --headless --path . --script res://tests/test_scoring.gd
extends SceneTree

const Scoring = preload("res://scripts/scoring.gd")
const CardDB = preload("res://scripts/card_db.gd")

var _fails := 0


func _initialize() -> void:
	# Bases simples : PLA#27 (10, +10 par DEP_7) + VAI#32 (16, +7 par LIE_6) + NUA#34 (3, BdC)
	# PLA : 10 + 20 ; VAI : 16 + 7 + 7 (autre DEP) ; NUA : 3 ; BdC : 2 BdC -> 5.
	_check("PLA VAI NUA", [27, 32, 34], 10 + 20 + 16 + 14 + 3 + 5)
	# YAM#7 masqué sans BdC.
	_check("YAM seul", [7], 0)
	# YAM#7 avec BUL#11 (BdC, ALL_3) : YAM 8 + 8 ; BUL 8 ; 1 BdC -> 0.
	_check("YAM BUL", [7, 11], 16 + 8)
	# GOT#3 sans MAI_5 : 30 - 40 ; avec TOR#21 (MAI_5) : 30 + 7.
	_check("GOT seul", [3], -10)
	_check("GOT TOR", [3, 21], 37)
	# CEL#16 masque KRI#6 ; CEL : 13.
	_check("CEL KRI", [16, 6], 13)
	# Boucle : BUU#18 masque CEL#16 (autre ENN), CEL ne masque pas BUU. BUU : 1 + 30.
	_check("BUU CEL", [18, 16], 31)
	# KIE#38 masque SAN#2 ; IMA#40 retire le malus de KIE : KIE 24, IMA 12 + 12, SAN#2 7 (aucun ENN).
	_check("KIE SAN2", [38, 2], 24)
	_check("KIE IMA SAN2", [38, 40, 2], 24 + 24 + 7)
	# BRO#5 : immunisé, masque toutes les COM_2 sauf une (on garde la meilleure).
	# BRO 90 ; KRI 5 + 25 (BRO compte comme ENN_4) ; TEN masqué (on garde KRI).
	_check("BRO KRI TEN", [5, 6, 8], 90 + 30)
	# EXP#37 masque CEL#16 : +35. EXP 25 + 35.
	_check("EXP CEL", [37, 16], 60)
	# SEN#44 protège KRI#6 de CEL#16 : SEN 15 ; CEL 13 ; KRI 5 + 25 (avec CEL#16, un ENN_4).
	_check("SEN CEL KRI", [44, 16, 6], 15 + 13 + 30)
	# OOL#51 copie KAM#36 (40, malus -10 par carte hors familles) : avec PLA#27 (LIE).
	# KAM 40 - 20 (OOL compte comme TEC donc pas pénalisé ; PLA -10)… on vérifie juste > 0.
	var r := Scoring.best([36, 51, 27], {})
	_expect("OOL copie", r.total >= 40, "total %d" % r.total)
	# SAN#1 seul : 0 points, BdC seule -> 0.
	_check("SAN1", [1], 0)
	# 7 BdC : barème 105 (FRE absent).
	# PIL#19 choisit de ne pas être un ENN_4 (sinon YAJ#12 est masqué) : PIL 11 + 9 × 6 ;
	# BUL 8 + 8 (NUA, un DEP_7) ; PLA 10 + 10 ; NUA 3 + 7 (SAN#1).
	_check("7 BdC", [1, 11, 12, 19, 21, 27, 34], 0 + 16 + 12 + 65 + 7 + 20 + 10 + 105)
	# TEN#8 masqué si CHA#9 est dans la défausse.
	_check("TEN défausse CHA", [8], 0, {"discard": [9]})
	# KAI#24 : +8 par COM/SAY en main et défausse.
	_check("KAI", [24, 6], 4 + 16 + 5, {"discard": [2]})
	# MAI#22 : 3 LIE_6 -> +30. TOU#26 5 (aucun des 4), PLA 10, KAM#28 5 (aucun ALL_3 ni COM_2).
	_check("KAR 3 LIE", [22, 26, 27, 28], 7 + 30 + 5 + 10 + 5)
	# BUL#11 protège YAJ#12 (BdC) de son malus (masqué avec un ENN_4) : BUL 8, YAJ 12, CEL 13, 2 BdC -> 5.
	_check("BUL protège YAJ", [11, 12, 16], 8 + 12 + 13 + 5)
	var no_shield := Scoring.evaluate([11, 12, 16], {}, {"bul": -1})
	_expect("BUL sans protection", no_shield.total == 8 + 13, "obtenu %d : %s" % [no_shield.total, _detail(no_shield)])
	# NUA#34 : +27 avec SAN#2 ; sinon +7 avec SAN#1 (2 BdC -> 5).
	_check("NUA SAN2", [34, 2], 3 + 27 + 7)
	_check("NUA SAN1", [34, 1], 3 + 7 + 0 + 5)
	# KRI#6 : +15 par KAM#36 / KIE#38 / TOR#21. KIE masque… les SAY_1 seulement : KRI 5 + 30, KAM 40, KIE 24.
	_check("KRI KAM KIE", [6, 36, 38], 35 + 40 + 24)
	# ASS#49 n'ajoute plus la valeur d'un ENN_4 : ASS 9 + FRE#17 (29) non compté.
	_check("ASS FRE", [49, 17], 9 + 29)
	# OOL#51 copie obligatoirement : seul avec PLA#27, il copie PLA (10 + 0 : OOL n'est pas un DEP_7).
	var ool := Scoring.choice_specs([51, 27])
	_expect("OOL copie obligatoire", not ool[0].options.has(-1), "options %s" % [ool[0].options])
	print("Toutes les mains : ", "OK" if _fails == 0 else "%d ÉCHEC(S)" % _fails)
	_timing()
	quit(1 if _fails > 0 else 0)


func _check(label: String, hand: Array, expected: int, ctx := {}) -> void:
	var r := Scoring.best(hand, ctx)
	_expect(label, r.total == expected, "attendu %d, obtenu %d : %s" % [expected, r.total, _detail(r)])


func _expect(label: String, ok: bool, info: String) -> void:
	if ok:
		print("OK    ", label)
	else:
		_fails += 1
		print("ÉCHEC ", label, " — ", info)


func _detail(r: Dictionary) -> String:
	var parts := []
	for c in r.cards:
		parts.append("%s%s=%d" % [CardDB.code(c.id), " (masqué)" if c.masked else "", c.points])
	return ", ".join(parts) + " BdC=%d" % r.bdc_points


# Temps de calcul sur des mains au hasard (les ordinateurs en font beaucoup).
func _timing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ids := CardDB.all_ids()
	var t := Time.get_ticks_usec()
	var worst := 0
	for k in 200:
		var pool := ids.duplicate()
		var hand := []
		for _i in 8:
			hand.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		var t0 := Time.get_ticks_usec()
		Scoring.best(hand, {}, true)
		worst = maxi(worst, Time.get_ticks_usec() - t0)
	print("Calcul rapide : %.2f ms en moyenne, %.1f ms au pire" % [(Time.get_ticks_usec() - t) / 200000.0, worst / 1000.0])
