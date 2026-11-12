# Dragonball Realms

Jeu Godot 4.7 (GDScript, Forward Plus). Game design à venir : ne pas coder de gameplay avant que l'auteur l'ait expliqué.

## Lancer

Godot : `C:\Users\user\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

- Importer (après ajout de fichiers) : `Godot --headless --path . --import`
- Générer l'exe Windows : `Godot --headless --path . --export-release "Windows Desktop" build/DragonballRealms.exe`
  (le dossier `build/` doit exister ; il n'est pas versionné)
- Test de démarrage : `Godot --headless --path . --script res://tests/test_boot.gd`
- Capture d'écran : `Godot --path . --script res://tests/screenshot.gd -- <fichier.png> [secondes]`

## Organisation

- `scenes/main.tscn` : scène principale, pilotée par `scripts/main.gd`.
- `tests/` : scripts `extends SceneTree` lancés en ligne de commande.

## Conventions

- Commentaires et textes en français.
- Pas de `class_name` : les scripts se référencent par `preload` (fonctionne sans cache d'import).
- Fichiers en UTF-8, fins de ligne LF. Attention avec PowerShell : `Get-Content -Raw` lit en ANSI et casse les accents.
