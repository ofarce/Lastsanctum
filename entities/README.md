# entities/

Entités de jeu : unités alliées, ennemis, bâtiments, ouvriers, tourelles. Chaque entité porte son état. Les vues (sprites, animations) lisent cet état sans le modifier. Le point d'origine du nœud est le point au sol, ce qui donne le tri de profondeur par Y.

Le sceau de minage équipé (`mining_artifact`) affiche trois sphères argentées derrière l’épaule de l’Ingénieur : ronde de 5 s et relais de trois petits arcs électriques sur 2,4 s (`unit/mining_seal_fx.gd`). Le rendu suit son orientation et sa lévitation, utilise le temps de simulation et disparaît avec le corps pendant le rappel.
