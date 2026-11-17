# entities/

Entités de jeu : unités alliées, ennemis, bâtiments, ouvriers, tourelles. Chaque entité porte son état. Les vues (sprites, animations) lisent cet état sans le modifier. Le point d'origine du nœud est le point au sol, ce qui donne le tri de profondeur par Y.

Le sceau de minage équipé (`mining_artifact`) affiche trois sphères argentées derrière l’épaule de l’Ingénieur : ronde de 5 s et relais de trois petits arcs électriques sur 2,4 s (`unit/mining_seal_fx.gd`). Le rendu suit son orientation et sa lévitation, utilise le temps de simulation et disparaît avec le corps pendant le rappel.

Sans armure, l’Ingénieur porte la tenue « Le Tyrien » (`unit/tyrien_art.gd`) : un corps et un calque par pièce d’équipement visible, pour chaque animation (repos, marche, à genoux, incantation, assise, lotus, visée). `UnitView` empile sur le corps, comme enfants de `_body`, les calques des pièces de `Unit.equipment` (emplacement → objet de `data/gear_items.gd`) dans l’ordre `order` de `tyrien.json`. Planches régénérées par `planches/tyrien-export.html?save=1` servi par `tools/tyrien/serve.py` (port 8149), depuis `planches/assets/engineer-volume.js`. Capture : `tests/visual/tyrien_capture.tscn`.
