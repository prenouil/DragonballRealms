# Dragonball Realms

Jeu de cartes 3D, Godot 4.7 (GDScript, Forward Plus) : règles de Fantasy Realms avec les 54 cartes de l'auteur,
en solo contre 3 ordinateurs (l'esprit de la table de Nervous). Règles et interprétations : `docs/regles.md`.

## Lancer

Godot : `C:\Users\user\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

- Importer (après ajout de fichiers) : `Godot --headless --path . --import`
- Générer l'exe Windows : `Godot --headless --path . --export-release "Windows Desktop" build/DragonballRealms.exe`
  (le dossier `build/` doit exister ; il n'est pas versionné)
- Tests :
  - `Godot --headless --path . --script res://tests/test_scoring.gd` (scores de mains connues + temps de calcul)
  - `Godot --headless --path . --script res://tests/test_simulation.gd -- 10` (parties entre 4 ordinateurs)
  - `Godot --headless --path . --script res://tests/test_boot.gd`
- Capture d'écran : `Godot --path . --script res://tests/screenshot.gd -- <fichier.png> [secondes]`
  (`SHOT_AUTOPLAY=1` joue la partie entière et capture l'écran de fin ; `SHOT_SEED`, `SHOT_SPEED`,
  `SHOT_HAND="37,44,52"` main imposée, `SHOT_CHOICES=1|picker` capture les choix du décompte ;
  en partie automatique, [secondes] capture à cet instant, `SHOT_EVERY=0.25` une série d'images ; `SHOT_DRAG=1` capture un glisser-déposer dans la main)

## Organisation

- `scripts/card_db.gd` : les 54 cartes (numéro, 3 lettres, famille, valeur, étoiles de BdC, texte codé).
- `scripts/scoring.gd` : score d'une main (identités, cartes masquées par tours, bonus/malus, BdC) ;
  `best()` essaie les choix possibles (exhaustif, sinon un choix à la fois ; `fast` pour les ordinateurs).
- `scripts/game.gd` : déroulement (pioche, défausse, cartes spéciales, fin de partie) ; questions au joueur
  humain par `choice_requested` / `answer()` ; réflexion des ordinateurs dans un fil (`_think`).
- `scripts/bot.gd` : décisions des ordinateurs (comparaison des scores).
- `scripts/card_face.gd` : images des cartes : `res://cards/faces/<numéro>.png` (cartes du document de l'auteur,
  entièrement floutées : réduites à 9×12 pixels puis agrandies en 128×176 ; aucun détail reconnaissable ne
  doit rester), sinon carte reconstruite dans un SubViewport.
- `scripts/choices.gd` : choix du joueur humain au décompte et pour FIN DE PARTIE (cartes en surbrillance,
  fenêtres de tous les choix possibles, Annuler / Valider).
- `scripts/main.gd` : table 3D, personnages, placement animé des 54 cartes, interface, fenêtres de choix, écran de fin.

## Conventions

- Commentaires et textes en français.
- Noms des cartes et des familles toujours codés (`SAN#1`, `SAY_1`, `BdC`) : jamais les noms d'origine.
  Pour tout autre nom « spécial », demander à l'auteur au cas par cas.
- Pas de `class_name` : les scripts se référencent par `preload` (fonctionne sans cache d'import).
- Fichiers en UTF-8, fins de ligne LF. Attention avec PowerShell : `Get-Content -Raw` lit en ANSI et casse les accents.
