# Les 54 cartes du jeu : numéro, nom codé, famille, valeur de base, Boule de Cristal (BdC) et texte.
# Nom d'une carte : 3 premières lettres + « # » + numéro. Famille : 3 premières lettres + « _ » + numéro.

const SAY := 1
const COM := 2
const ALL := 3
const ENN := 4
const MAI := 5
const LIE := 6
const DEP := 7
const TEC := 8
const OBJ := 9
const TRA := 10
const JOK := 11

const FAMILY_CODES := ["", "SAY_1", "COM_2", "ALL_3", "ENN_4", "MAI_5", "LIE_6", "DEP_7", "TEC_8", "OBJ_9", "TRA_10", "JOK_11"]
const FAMILY_COLORS := [
	Color.WHITE,
	Color(0.95, 0.55, 0.1),   # SAY_1
	Color(0.85, 0.2, 0.15),   # COM_2
	Color(0.95, 0.45, 0.65),  # ALL_3
	Color(0.5, 0.25, 0.65),   # ENN_4
	Color(0.15, 0.6, 0.6),    # MAI_5
	Color(0.3, 0.6, 0.25),    # LIE_6
	Color(0.3, 0.55, 0.9),    # DEP_7
	Color(0.95, 0.8, 0.15),   # TEC_8
	Color(0.55, 0.4, 0.3),    # OBJ_9
	Color(0.8, 0.25, 0.8),    # TRA_10
	Color(0.4, 0.4, 0.45),    # JOK_11
]

# Barème des BdC selon leur nombre dans la main (index = nombre de BdC).
const BDC_POINTS := [0, 0, 5, 20, 45, 80, 125, 180]

# Ordre des effets « FIN DE PARTIE » : FOR#50 (#1), RAD#42 (#2), SHE#54 (#3), SAN#1 (#4).
const END_EFFECTS := [50, 42, 54, 1]

# [numéro, 3 lettres, famille, valeur de base, étoiles de BdC (0 : pas une BdC), texte]
const CARDS := [
	[1, "SAN", SAY, 0, 4, "FIN DE PARTIE #4 : vous devez piocher une carte et SAN#1 est placé dans la défausse.\nSPÉCIAL : dans la défausse, SAN#1 peut compter comme étant dans la main de chaque joueur (au choix de ce joueur)."],
	[2, "SAN", SAY, 7, 0, "BONUS : +33 avec un ENN_4.\nMALUS : SAN#2 perd son bonus si aucune carte n'est masquée."],
	[3, "GOT", SAY, 30, 0, "MALUS : sauf avec un MAI_5, -40 et enlève le bonus des autres SAY_1 et des COM_2."],
	[4, "TRU", SAY, 10, 0, "BONUS : +15 par BUL#11, VEG#20, MAC#33 OU +100 avec les trois."],
	[5, "BRO", SAY, 90, 0, "BONUS : ne peut pas être masqué.\nMALUS ULTIME (ne peut être supprimé) : compte aussi comme un ENN_4, un COM_2 et une TRA_10. Pour chaque famille, BRO#5 masque toutes les cartes sauf une par famille (les cartes immunisées ne peuvent pas être choisies)."],
	[6, "KRI", COM, 5, 0, "BONUS : +15 avec une TEC_8, +10 par ALL_3."],
	[7, "YAM", COM, 8, 0, "BONUS : +8 par ALL_3 et autre COM_2.\nMALUS : devient masqué sauf avec une BdC."],
	[8, "TEN", COM, 15, 0, "BONUS : +11 par SAN#1, YAM#7, TOR#21.\nMALUS : masqué si CHA#9 est masqué ou dans la défausse."],
	[9, "CHA", COM, 9, 0, "BONUS : +21 avec TEN#8.\nSPÉCIAL : vous pouvez masquer CHA#9 pour qu'une autre carte de votre main ne puisse pas être masquée (sauf par BRO#5)."],
	[10, "PIC", COM, 6, 0, "BONUS : avec SAN#2 ou GOT#3, +30 et est aussi un MAI_5. Sinon, avec une BdC, +20, est aussi un ENN_4 et masque TOU#23."],
	[11, "BUL", ALL, 8, 5, "BONUS : +8 par OBJ_9, +5 par autre carte citant BUL#11 ou les ALL_3."],
	[12, "YAJ", ALL, 16, 2, "BONUS : +20 avec SEN#44 ou CAN#29.\nMALUS : masqué avec au moins un ENN_4."],
	[13, "VID", ALL, 11, 0, "BONUS : +19 avec SAN#2, +14 avec SAT#14."],
	[14, "SAT", ALL, 1, 0, "BONUS : +50 avec TOU#26 et aucun COM_2, SAY_1 ou ENN_4, +20 avec GEN#39, +30 avec BUU#18."],
	[15, "CHI", ALL, 15, 0, "BONUS : +25 avec SAN#2 ou GOT#3, ces cartes perdent leur malus.\nMALUS : -20 avec SAN#1."],
	[16, "CEL", ENN, 13, 0, "BONUS : +20 avec MAC#33, +13 par SAY_1.\nMALUS : masque les COM_2, les MAI_5 et SAT#14."],
	[17, "FRE", ENN, 29, 0, "MALUS : masque KRI#6, VEG#20 et les BdC, sauf SAN#1."],
	[18, "BUU", ENN, 1, 0, "BONUS : +25 par carte masquée.\nMALUS : masque les autres ENN_4, les MAI_5 et les ALL_3, sauf SAT#14."],
	[19, "PIL", ENN, 11, 1, "BONUS : +11 par autre BdC. Peut ne pas être un ENN_4.\nMALUS : masqué avec PET#41."],
	[20, "VEG", ENN, 12, 0, "BONUS : avec TRU#4, GOT#3 ou BUL#11, +20 et devient SAY_1 et ALL_3 à la place d'ENN_4.\nMALUS : si VEG#20 est un ENN_4, masque les COM_2 et +20 par COM_2 masqué."],
	[21, "TOR", MAI, 4, 3, "BONUS : +8 par TEC_8, +20 avec KAM#28."],
	[22, "MAI", MAI, 7, 0, "BONUS : +20 / +60 / +120 si vous avez trois / quatre / cinq cartes de la même famille."],
	[23, "TOU", MAI, 12, 0, "BONUS : +21 avec SHE#54, +14 par PLA#27 et VAI#32."],
	[24, "MAI", MAI, 4, 0, "BONUS : +8 par COM_2 et SAY_1 dans la main et dans la défausse."],
	[25, "BAB", MAI, 13, 0, "SPÉCIAL : vous pouvez prendre 3 cartes de la défausse (pas de la pioche) au lieu d'une et défausser 3 cartes de votre main si l'une d'elles est BAB#25."],
	[26, "TOU", LIE, 5, 0, "BONUS : +30 avec strictement un seul parmi SAT#14, TEN#8, TOR#21 ou SAN#1."],
	[27, "PLA", LIE, 10, 7, "BONUS : +10 par DEP_7."],
	[28, "KAM", LIE, 5, 0, "BONUS : +11 par ALL_3, +5 par COM_2, +5 par autre LIE_6."],
	[29, "CAN", LIE, 6, 0, "BONUS : +7 par ENN_4, +7 par TRA_10, +12 par COM_2 masqué."],
	[30, "SAL", LIE, 2, 0, "BONUS : +40 avec exactement 2 cartes parmi SAY_1, COM_2 ou ENN_4."],
	[31, "MOD", DEP, 11, 0, "SPÉCIAL : au moment de défausser MOD#31, vous pouvez chercher SAN#1 dans la pioche. S'il y est, placez-le dans la défausse puis mélangez MOD#31 avec la pioche.\nBONUS : +11 par LIE_6."],
	[32, "VAI", DEP, 16, 0, "BONUS : +7 par LIE_6, +7 par autre DEP_7."],
	[33, "MAC", DEP, 25, 0, "SPÉCIAL : si cela ne met pas fin à la partie, lorsque MAC#33 est défaussée, vous pouvez rejouer immédiatement."],
	[34, "NUA", DEP, 3, 6, "BONUS : +17 avec MAI#22, SAN#1 ou SAN#2."],
	[35, "DEP", DEP, 9, 0, "BONUS : +9 par LIE_6, +10 avec SAN#1."],
	[36, "KAM", TEC, 40, 0, "MALUS : -10 pour chaque carte qui n'est pas un SAY_1, un ENN_4, une TEC_8, un DEP_7, KRI#6 ou TOR#21."],
	[37, "EXP", TEC, 25, 0, "BONUS : +35 si VEG#20, CHA#9 ou CEL#16 est masqué par le malus de EXP#37.\nMALUS : masque une autre carte de votre main. Elle ne peut pas être protégée."],
	[38, "KIE", TEC, 25, 0, "MALUS : masque les SAY_1, FRE#17 et SIN#46."],
	[39, "GEN", TEC, 10, 0, "BONUS : +60 avec SAN#1, un ENN_4, un LIE_6 et un DEP_7."],
	[40, "IMA", TEC, 12, 0, "BONUS : +8 par autre TEC_8. Retire le malus des autres TEC_8."],
	[41, "PET", OBJ, 14, 0, "BONUS : +16 avec BUL#11 ou TOR#21, mais +0 avec les deux. +6 avec OOL#51 ou SHE#54, mais +36 avec les deux."],
	[42, "RAD", OBJ, 20, 0, "FIN DE PARTIE #2 : vous pouvez prendre une BdC dans la défausse.\nBONUS : +20 par paire BdC / LIE_6."],
	[43, "DET", OBJ, 21, 0, "SPÉCIAL : vous pouvez défausser DET#43 avant de piocher. Si vous le faites, vous pouvez piocher 3 cartes sur le dessus de la pioche, en choisir 1 et remettre les 2 autres sur le dessus de la pioche."],
	[44, "SEN", OBJ, 15, 0, "BONUS : ne peut pas être masqué. Une autre carte ne peut pas être masquée, sauf par BRO#5."],
	[45, "CAP", OBJ, 11, 0, "BONUS : +20 avec BUL#11 ou DRB#52, +11 par autre OBJ_9."],
	[46, "SIN", TRA, 20, 0, "BONUS : +25 avec TOU#26, CAN#29 ou PIL#19.\nMALUS : masqué sauf avec un SAY_1 ou VEG#20."],
	[47, "TRA", TRA, 3, 0, "BONUS : vous pouvez changer la famille d'une autre carte. Son nom ainsi que le reste des textes restent les mêmes."],
	[48, "SUP", TRA, 6, 0, "BONUS : +10 par SAY_1 et par ENN_4.\nMALUS : masqué sauf avec un SAY_1."],
	[49, "ASS", TRA, 10, 0, "BONUS : +20 avec CEL#16 ou BUU#18. Ajoute la valeur de base de n'importe quel SAY_1, COM_2, ALL_3, MAI_5 ou ENN_4 sauf BRO#5."],
	[50, "FOR", TRA, 8, 0, "FIN DE PARTIE #1 : vous pouvez masquer une carte de la défausse.\nBONUS : +35 avec FRE#17, BUU#18 ou CEL#16."],
	[51, "OOL", JOK, 0, 0, "BONUS : peut copier le nom, la valeur de base, la famille et le malus MAIS PAS LE RESTE de n'importe quelle autre carte en main, sauf BRO#5. Compte toujours comme étant OOL#51."],
	[52, "DRB", JOK, 0, 0, "BONUS : prend le nom et la famille de n'importe quel DEP_7, OBJ_9, LIE_6, TEC_8 ou TRA_10. Compte toujours comme étant DRB#52."],
	[53, "CHA", JOK, 0, 0, "BONUS : prend le nom et la famille de n'importe quel SAY_1, COM_2, ENN_4, ALL_3 ou MAI_5."],
	[54, "SHE", JOK, 3, 0, "FIN DE PARTIE #3 : vous pouvez prendre n'importe quelle carte dans la défausse sauf une BdC.\nMALUS : masqué sauf avec une BdC."],
]

const COUNT := 54


static func code(id: int) -> String:
	return "%s#%d" % [CARDS[id - 1][1], id]


static func family(id: int) -> int:
	return CARDS[id - 1][2]


static func family_code(fam: int) -> String:
	return FAMILY_CODES[fam]


static func base(id: int) -> int:
	return CARDS[id - 1][3]


static func bdc_stars(id: int) -> int:
	return CARDS[id - 1][4]


static func is_bdc(id: int) -> bool:
	return CARDS[id - 1][4] > 0


static func text(id: int) -> String:
	return CARDS[id - 1][5]


# Carte dont le texte cite BUL#11 ou les ALL_3 (bonus de BUL#11).
static func cites_bulma(id: int) -> bool:
	var t: String = CARDS[id - 1][5]
	return t.contains("BUL#11") or t.contains("ALL_3")


static func all_ids() -> Array[int]:
	var ids: Array[int] = []
	for i in COUNT:
		ids.append(i + 1)
	return ids


static func ids_of_families(fams: Array) -> Array[int]:
	var ids: Array[int] = []
	for i in COUNT:
		if fams.has(CARDS[i][2]):
			ids.append(i + 1)
	return ids
