# Dragonball Realms

Jeu de cartes en 3D (Godot 4.7) aux règles de Fantasy Realms : toi contre 3 ordinateurs assis autour de la table.

- Règles et interprétations : [docs/regles.md](docs/regles.md)
- Lancer : ouvrir le dossier dans Godot 4.7, puis F5.

## Commandes

- Survoler une carte : l'afficher en grand, avec son texte.
- Clic sur la pioche ou sur une carte de la défausse : la prendre.
- Clic sur une carte de ta main : la défausser.
- Boutons « Utiliser DET#43 » et « Utiliser BAB#25 » quand tu as ces cartes.

## Images des cartes

Chaque carte est l'image de la carte d'origine, entièrement floutée : `cards/faces/<numéro>.png`
(ex. `cards/faces/1.png` pour SAN#1). Pour en changer une, remplacer le fichier puis rouvrir le projet dans Godot.
Survoler une carte affiche son texte en clair.
