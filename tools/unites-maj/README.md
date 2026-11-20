# Mise à jour des unités

- `build.py` + `template.html` : planche de propositions `planches/unites-maj-propositions.html` (atlas embarqués,
  mesures recalculées). Attention : elle lit les atlas du jeu, donc ceux d'après la mise à jour.
- `avant/` : atlas et manifestes d'avant la mise à jour (ennemis, Caserne, esprits), seule copie tant que rien n'est
  commité.
- `export.py` : réexporte vers le jeu sans serveur d'aperçu (Firefox headless, port local temporaire) :

      python3 tools/unites-maj/export.py refonte    # ennemis de la refonte + Caserne
      python3 tools/unites-maj/export.py esprits    # quatre esprits

  puis `godot --headless --path . --import` pour importer les nouveaux PNG.
- Contrôle en jeu : `godot --path . res://tests/visual/unites_maj_capture.tscn` écrit `tests/visual/out/unites_maj/`.
