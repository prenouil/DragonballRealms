# Règles

Les règles sont celles de **Fantasy Realms**, avec les 54 cartes du jeu.

## Noms

- Carte : 3 premières lettres du nom, `#`, numéro de la carte (ordre du document des cartes). Exemple : `SAN#1`.
- Famille : 3 premières lettres, `_`, numéro de la famille :
  `SAY_1`, `COM_2`, `ALL_3`, `ENN_4`, `MAI_5`, `LIE_6`, `DEP_7`, `TEC_8`, `OBJ_9`, `TRA_10`, `JOK_11`.
- Boule de Cristal : `BdC`.

## Partie

- 4 joueurs (toi + 3 ordinateurs), 7 cartes chacun ; le premier joueur est tiré au sort.
- À son tour : prendre la carte du dessus de la pioche **ou** n'importe quelle carte de la défausse, puis défausser une carte.
- La partie s'arrête dès que la défausse compte **10 cartes** (ou si la pioche est vide).

## Décompte

1. Effets **FIN DE PARTIE** dans l'ordre #1 `FOR#50`, #2 `RAD#42`, #3 `SHE#54`, #4 `SAN#1`,
   seulement pour les cartes **dans la main** d'un joueur.
2. Si `SAN#1` est dans la défausse, chaque joueur choisit de le compter ou non comme 8e carte.
3. Score : valeur de base + bonus + malus des cartes non masquées, plus le barème des BdC
   (nombre de BdC dans la main : 1 → 0, 2 → 5, 3 → 20, 4 → 45, 5 → 80, 6 → 125, 7 → 180).

## Interprétations retenues (à valider)

- **Choix au décompte** (cible d'`EXP#37`, carte protégée par `SEN#44` ou `CHA#9`, carte copiée par `OOL#51`,
  identité de `DRB#52` / `CHA#53`, famille changée par `TRA#47`, carte gardée par `BRO#5`, `PIL#19` ENN_4 ou non) :
  tu les fais toi-même (cartes en surbrillance : clic pour voir tous les choix, « Annuler » pour revenir sur
  un choix, « Valider » quand tout est choisi). Les ordinateurs choisissent au mieux pour eux.
- **Effets FIN DE PARTIE** de tes cartes (`FOR#50`, `RAD#42`, `SHE#54`) : même principe, clic sur la carte.
- **Cartes masquées** : une carte masquée n'a plus aucun effet. Si deux cartes se masquent l'une l'autre,
  elles restent masquées toutes les deux.
- **`DET#43`** : on le défausse à la place de piocher, on garde 1 des 3 cartes du dessus de la pioche,
  et le tour s'arrête (la main revient à 7 cartes).
- **`BAB#25`** : à la place de piocher, on prend 3 cartes de la défausse puis on en défausse 3, dont `BAB#25`.
- **`MAC#33`** et **`MOD#31`** s'appliquent aussi quand ils sont défaussés avec `BAB#25`.
- **`ASS#49`** : ajoute la plus forte valeur de base parmi les autres cartes de **ta main**
  (SAY_1, COM_2, ALL_3, MAI_5 ou ENN_4, sauf `BRO#5`).
- **`DRB#52` / `CHA#53`** : peuvent prendre le nom et la famille de **n'importe quelle carte du jeu** (comme dans Fantasy Realms).
- **`BRO#5`** : pour chaque famille, il ne reste qu'une carte non immunisée ; les autres sont masquées
  (une carte de plusieurs familles peut être masquée par l'une d'elles). On choisit la carte gardée parmi les
  cartes de la famille imprimée ; un joker qui prend cette famille est masqué.
- **« +X par A, B, C »** : chaque nom compte une fois.
- **`MAI#24`** : une carte qui est à la fois SAY_1 et COM_2 compte une fois.
- **`FOR#50`** : une carte de la défausse masquée le reste si elle est reprise (`RAD#42`, `SHE#54`, `SAN#1` en 8e carte).
- Une carte qui prend un nom (jokers, `OOL#51`) compte pour ce nom, mais pas comme BdC.
