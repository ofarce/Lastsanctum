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
une vague fige son palier P : `6 + 4w + 2P` ennemis, composition de la vague
`w + floor(P/2)`, PV ×`(1 + 0,04P)`, dégâts ×`(1 + 0,02P)` et armure
+`floor(P/5)`. La cadence d’apparition reste liée à la vraie vague. Le Strazhar
arrive dès la vague effective 8 ou 1000 de menace ; un champion supplémentaire
s’ajoute aux paliers 15, 20, etc., dans l’effectif total.

Chaque apparition de portail relit la menace : intervalle `max(3,5 ; 7 − 0,35P)`
secondes, plafond `min(16 ; 8 + P)` créatures vivantes par portail, PV
×`(1 + 0,08P)` et dégâts ×`(1 + 0,05P)`. Les créatures existantes gardent
leurs statistiques et ne rapportent aucune menace à leur mort. Le palier 0
conserve les paramètres de base. Les coefficients sont regroupés dans `Catalog`.

La menace ne vient plus des recherches (`RESEARCH_MENACE` = 0) : elle monte à la mort de chaque ennemi
d'assaut, selon son type (`Catalog.KILL_MENACE` : fanatique 1, archer 2, bouclier 5, brute 6, Strazhar 12).

## Nuit

`night.gd` (après le premier assaut). Flot de squelettes levés un peu partout dehors (jamais dans la grotte), du crépuscule à la fin de nuit, rare
puis serré puis nul avant l'aube (`Catalog.NIGHT_FLOW`). Chaque nuit, chaque pylône éveillé et non
canalisé, ainsi que le pylône non canalisé le plus proche de l'Ancre même endormi, lâche une meute de chiens qui
marche sur l'Ancre (`Catalog.NIGHT_RAID` : 3 + 1 par palier, 12 au plus).
Squelettes et meutes sont hors menace et hors fin de vague (`Enemy.beast`).

## Pylônes de Merenor

`pylons.gd` remplace les portails maléfiques des galeries (un par réseau, dans `TerrainState.portals`).
Chaque pylône est posé sur 2 × 2 cases infranchissables (`TerrainState.pylon_cells`), au centre d'une salle
creusée (`PYLON_CHAMBER`), et s'éveille quand sa galerie est découverte. Une meute de 4 à 6 bêtes, dont un
alpha (PV et dégâts × 2), garde la nappe ; une bête tuée renaît à sa place au bout de 60 s. Un esprit de
chaque dieu en prière autour (job `pray_pylon`, clic droit sur le pylône) le canalise : plus de renaissance,
la nappe se retire. S'il manque un culte, chaque place vide repart pour 60 s. La nappe (`Pylons.edge`, même
forme que `shaders/pylon_corruption.gdshader`) retire 1 PV/s à l'Ingénieur ; les adeptes y sont immunisés.
Capture : `tests/visual/pylon_capture.tscn`.

## Œil de la Matrice (frontière Temple / biome 2)

`sim/oeil.gd` (classe `OeilMatrice`). Une bande de roche impossible à creuser (`TerrainState.frontier_cell`,
2 × `FRONTIER_HALF` u) court tout le long de la limite nord du Temple. Seule la grande salle de l'Œil
(`TerrainState.eye_room_center`, ellipse de 116 × 52 u au nord de la zone d'origine) la perce : un couloir part vers
le nord, fermé par une porte de chair (`eye_gate`, infranchissable tant que `eye_gate_closed`), et s'arrête à une ou
deux cases d'une galerie du biome 2 (la salle et le biome 2 restent deux réseaux). Le boss s'éveille quand la salle
est découverte ; la salle sert d'arène (seul l'Ingénieur y entre et l'y blesse ; l'œil ouvert prend double dégâts).
Huit attaques (`planches/oeil-maj.html`) enchaînées par phase selon `ROTATION` : Regard, Larmes, Cils (I) ;
plus Strabisme et Pupilles errantes (II) ; Regard sur deux axes, Fixation, Clignement (III), et Les mille yeux une
fois à l'entrée en phase III (`INTRO`). Chaque attaque pose des événements datés et des contrôleurs dans
`GameState.oeil_fx` ; les pupilles errantes sont des ennemis `PUPIL_KIND` menés par l'Œil (cibles fragiles,
seul l'Ingénieur les touche). Racines au contact. Sa mort ouvre la porte. Rendu : `world/oeil/` (piste « L'Orbite »,
calques par phase dans `assets/imported/oeil/`, exportés par `tools/oeil/export.sh`). Capture :
`tests/visual/oeil_capture.tscn` (une image par attaque).
