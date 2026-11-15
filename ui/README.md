# ui/

Interface à la résolution écran : HUD de commandement, minicarte, notices, bannière de fin, bulles de dialogue. La logique du HUD est dans `hud/hud_model.gd` (sans rendu, testée contre le prototype), le style (couleurs, polices, icônes SVG d'origine rastérisées depuis `assets/baked/overlay/hud_icons.json`) dans `hud/hud_style.gd`.

La Menace apparaît après les Exilés dans le bandeau supérieur, avec l’Œil qui veille cuivré. Ce compteur cumulatif démarre à zéro : +1 par soldat ennemi tué (hors créatures de la caverne), +1 par adepte invoqué au temple ou sorti de la caserne. Une mise en file d’attente, une résurrection ou la production de l’Ancre ne l’augmentent pas. L’état entier `GameState.menace` est réinitialisé à chaque nouvelle partie.

L’inventaire de l’Ingénieur (`inventory/engineer_inventory.gd`) reprend la proposition C de `planches/inventaire-propositions.html`. C devient actif après la perte de son armure et ouvre ou ferme l’écran ; Échap et le bouton Fermer le ferment aussi. Les entrées sont interceptées pendant l’ouverture. Le coffre 10×10 est grisé et inaccessible (« Coffre antique nécessaire »). Le paquetage commence vide ; l’emplacement Minage affiche automatiquement le Sceau de minage lorsque `mining_artifact` est achevé. Cet équipement est dérivé de la recherche, comme l’autorisation de miner, et disparaît à la nouvelle partie.

Le minage produit désormais un objet par bloc : définition dans `data/mineable_blocks.gd`
(résistance en coups, matière, item). `TerrainState.block_types` permet d'affecter un type à une
cellule ; en l'absence d'entrée, la roche est utilisée. Un type inconnu n'est pas minable.
`sim/item_storage.gd` dépose exclusivement dans le coffre de 100 cases si
`GameState.base_inventory_unlocked` est vrai ; sinon dans les 10 cases du paquetage accessible
après la perte d'armure. Une destination pleine ou absente laisse l'objet au centre du bloc,
dans `GameState.ground_items`, dessiné dans le monde. Chaque case contient une pile de 1 à 9 999 objets identiques, avec quantité affichée. Les piles existantes sont complétées avant de créer une nouvelle pile ; si aucune place n’est disponible, l’objet reste au sol.
Le futur mécanisme du coffre antique doit activer `base_inventory_unlocked` ; aucun déverrouillage
anticipé n'est ajouté. Les objets au sol restent en place (ramassage non implémenté).
Les stocks, objets au sol et types de cellules sont réinitialisés à la nouvelle partie.

Le Sceau de minage reprend la proposition 03 (Prisme de forage) : cristal cyan enchâssé dans une monture de laiton. La texture partagée `assets/ui/mining_seal.png` est utilisée par les quatre recherches et l’emplacement Minage, avec filtrage au plus proche.

Le survol de minage est intégré via `input/mining_hover.gd`, dans le calque d'entrée au-dessus
de l'éclairage et sous le HUD. `InputController` recalcule la cible chaque image avec la même
résolution de case que le clic droit : Sceau recherché, Ingénieur vivant et visible sélectionné,
roche minable sous le pointeur. L'interface, les modes d'ordre explicites, le glissement de
sélection, le bouton droit maintenu et la sortie de fenêtre masquent cet aperçu.
La teinte cyan, le contour à angles renforcés et l'infobulle suivent le zoom de la case ;
l'infobulle reste dans les limites de l'écran. Capture : `tests/visual/mining_hover_board.tscn`.

Les noms des bâtiments et de l’Ancre ne sont affichés dans le monde que sur sélection. Les bâtiments achevés n’ont plus d’empreinte au sol. Une recherche et la formation active affichent chacune leur icône et leur barre de progression au-dessus du sommet du bâtiment ; les deux indicateurs coexistent à la caserne. Les unités en attente prennent le relais de l’indicateur à leur entrée en formation.

Le bandeau affiche chaque ressource sous la forme `500 (+ 2/s)` : +1/s de l’Ancre éveillée et +1/s par adepte effectivement en prière pour cette ressource. Le panneau s’adapte à la largeur disponible. L’Ancre éveillée propose « Offrande » (O) : 100 de chaque ressource contre +50 menace, réutilisable immédiatement tant que les fonds suffisent.

La résurrection au Puits des Âmes coûte le coût initial total de recrutement multiplié par le niveau, payé uniquement en Vie : 50 × niveau pour les adeptes de temple, 100 × niveau pour les combattants de caserne et 400 × niveau pour les héros. Chaque action vérifie et affiche son coût individuel ; le niveau et l’expérience sont conservés.

Chaque entrée de formation de la caserne produit une escouade indivisible de quatre soldats du même type (100 Discipline et 6 secondes pour l’escouade). Clic, rectangle et ordres s’appliquent à tous les survivants ; le HUD affiche leur effectif sur 4. Les membres éloignés rallient leur escouade.

Après des pertes, « Renforts » (R) rappelle tous les membres manquants depuis un Puits des Âmes achevé : le coût affiché est la somme des coûts de résurrection individuels (100 × niveau Vie par soldat). Le paiement n’est lancé que si la totalité est disponible. Le Puits permet aussi de rappeler un membre individuellement. Les ressuscités apparaissent au Puits, gardent niveau et expérience, puis rallient les survivants même en déplacement. Une escouade sans aucun survivant perd définitivement ses âmes et ne peut plus être ressuscitée.
