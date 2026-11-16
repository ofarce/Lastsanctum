# Temples v1 (en réserve)

Copie des temples tels qu'ils étaient avant la refonte en autels (2026-11-16) :
salle d'armes d'Indra, sanctuaire du cycle de Medeina, athénée de Sigil,
astrolabe monumental d'Aether.

- `buildings/da-<dieu>_base.png` et `_anim.png` : feuilles 320 × 240 utilisées par `entities/building/building_view.gd`.
- `portraits/bld-<dieu>.png` : vignettes du HUD.

Le dossier porte un `.gdignore` : Godot ne l'importe pas. Pour réutiliser un temple,
recopier les fichiers dans `assets/baked/` (le jeu les charge par le champ `art` de `data/catalog.gd`).
Le code de dessin d'origine reste dans `planches/assets/da-planches.js` (`sigilTemple`, `aetherTemple`, `medeinaTemple`, `indraTemple`).
