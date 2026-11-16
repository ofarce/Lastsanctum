# sim/

Systèmes de simulation appelés par `Simulation` dans l'ordre exact de `update()` du prototype (Index.html:83-86) : portail, bâtiments, unités, tourelles, ennemis, fin de partie. Ils travaillent en coordonnées de monde (x, z) et en secondes de simulation.

## Assauts coordonnés

`enemy_tactics.gd` analyse la file d'apparition et la répartit en groupes d'au plus sept unités.
Les types, statistiques, positions aléatoires et instants d'apparition sont conservés.
Chaque groupe se rassemble (dix secondes au plus après sa première apparition), puis progresse
à l'allure du plus lent, avec rattrapage à la vitesse naturelle. Les boucliers et soldats ouvrent
le front, les automates suivent au centre, les archers et thuriféraires restent en appui.
Les emplacements se replient en colonne si la largeur praticable est insuffisante.

Au contact détecté (14 unités), ou dès qu'un membre subit des dégâts, le groupe combat.
Les éclaireurs débordent d'un seul côté si les deux segments du détour sont libres ; Strazhar
reste en réserve quatre secondes au plus et réagit immédiatement s'il est attaqué. Les tireurs
peuvent reculer pendant trois secondes cumulées, puis reprennent le tir. Les cibles visibles
restent verrouillées 1,2 seconde, dans la limite du rayon de détection. Après trois secondes
sans contact, le groupe se reforme. Si la moitié des membres déjà apparus est perdue, ou si la
formation ne progresse plus pendant huit secondes, les survivants passent à l'assaut individuel.
Les aberrations des portails restent indépendantes.

Les ordres vivent dans les entrées de la file puis les ennemis, sans référence des groupes vers
les unités : une nouvelle partie les efface avec les ennemis et la file. Aucun hasard supplémentaire
n'est consommé. `test_enemy_tactics.gd` couvre cohésion, apparition partielle, contact anticipé,
réserve, repli borné, débordement, goulet, pertes, ralentissement et remise à zéro.

Inspiration : [Végèce, livre III](https://facultystaff.richmond.edu/~wstevens/history331texts/Vegetius.html)
(front, ailes, réserve) et [English Heritage, Hastings](https://www.english-heritage.org.uk/visit/places/1066-battle-of-hastings-abbey-and-battlefield/history-and-stories/what-happened-battle-hastings/)
(coopération entre armes). Ce sont des adaptations aux unités et au terrain du jeu.

La menace renforce la difficulté par paliers de 100 (`Catalog.menace_tier`). Au lancement,
une vague fige son palier P : `4 + 3w + 2P` ennemis, composition de la vague
`w + floor(P/2)`, PV ×`(1 + 0,04P)`, dégâts ×`(1 + 0,02P)` et armure
+`floor(P/5)`. La cadence d’apparition reste liée à la vraie vague. Le Strazhar
arrive dès la vague effective 8 ou 1000 de menace ; un champion supplémentaire
s’ajoute aux paliers 15, 20, etc., dans l’effectif total.

Chaque apparition de portail relit la menace : intervalle `max(3,5 ; 7 − 0,35P)`
secondes, plafond `min(16 ; 8 + P)` créatures vivantes par portail, PV
×`(1 + 0,08P)` et dégâts ×`(1 + 0,05P)`. Les créatures existantes gardent
leurs statistiques et ne rapportent aucune menace à leur mort. Le palier 0
conserve les paramètres de base. Les coefficients sont regroupés dans `Catalog`.
