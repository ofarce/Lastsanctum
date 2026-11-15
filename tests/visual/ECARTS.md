# Écarts visuels assumés

Ce fichier recense les écarts connus et acceptés entre Godot et le jeu d'origine (version figée `73b410f`). Chaque entrée indique les scénarios concernés, la cause et l'ordre de grandeur.

Commandes de comparaison :

```bash
godot --path . res://tests/visual/capture.tscn -- --prefix=etape2
```

```bash
python3 tests/visual/compare.py --prefix etape2
```

Les références sont produites par `tools/baker/reference.html` (voir `tools/baker/README.md`).

## Constats hérités du plan v1 (version jungle), toujours valables

Ces mécanismes n'ont pas changé dans `73b410f`. Ils seront revérifiés à l'étape 2 v2.

- **Lissage bilinéaire du feuillage** : le feuillage est dessiné lissé et agrandi ×PX. Le filtrage de Firefox et celui du GPU diffèrent de quelques niveaux, et l'écart grandit avec PX. En v1 : plus de 98,4 % des pixels à ±6 jusqu'à PX = 4, et 99 % à moins de 15 niveaux à PX 5 et 6.
- **Égalités au demi-pixel** : `Math.round` en double précision (JS) contre float32 (GPU). Ponctuellement, un objet est décalé d'un pixel natif aux positions de caméra « rondes ».
- **Précision des coordonnées** : les `Vector2` de Godot sont en float32. Les tests tolèrent 1e-3 face aux valeurs JS en double.

## Étape 2 v2 — Monde statique en 3/4

| Scénario | Identiques (±6) | Remarque |
|---|---|---|
| `etape2_salle_px1` / `px2` / `px3` | 99,96 / 99,60 / 100 % | — |
| `etape2_portails_px3` | 99,67 % | Au-dessus du seuil ; écarts ponctuels non analysés |
| `etape2_couloir_px2` | 99,98 % | — |
| `etape2_jungle_px2` | 99,96 % | Feuillage lissé (voir plus haut) |
| `etape2_montagne_px2` | 100 % | — |
| `etape2_vent_t7` | 97,37 % → **99,82 % à ±20** | Voir ci-dessous |

### Contours du feuillage cisaillé (`etape2_vent_t7`, tolérance ±20)

- **Cause** : sous le vent, le feuillage est à la fois **lissé et cisaillé**. Firefox (Skia) et le GPU n'échantillonnent pas de la même façon les bords d'une image inclinée et filtrée en bilinéaire. Les différences se concentrent en lignes d'un pixel le long des contours verticaux du feuillage.
- **Ampleur** : le cisaillement quantifié (n = round(cisaillement · ay · 3)) est identique, vérifié dans le prototype. La géométrie aussi : aucun décalage d'arbre. 99,18 % des pixels sont à ±12 et 99,82 % à ±20.
- **Correction faite pendant l'étape** : les positions du décor étaient arrondies à 4 décimales par le baker. Un arbre placé près d'un demi-pixel basculait alors d'un pixel natif. Les placements sont désormais en double précision.

## Étape 3 v2 — Terrain dynamique

| Scénario | Identiques (±6) | Exacts |
|---|---|---|
| `etape3_creusement_px1` | 100 % | 99,97 % |
| `etape3_creusement_px2` | 100 % | 99,92 % |

Le scénario creuse 15 cases depuis la paroi est de la salle et révèle une galerie : sol de grotte repeint, bandes sombres côté roche, cases mixtes avec leurs règles de bord, faces de falaise et stalagmites ajoutées, éboulis retirés.

### Peinture de la révélation répartie sur plusieurs images

- **Comportement du prototype** : toute la zone de la galerie est repeinte dans l'image où elle est découverte.
- **Godot** : l'état (galerie ouverte, praticabilité, décor) est mis à jour immédiatement. La peinture du sol est mise en file et réalisée avec un budget de 8 ms par image, soit environ 17 images (0,3 s) pour la galerie de référence (693 cases, dont 191 mixtes, environ 130 ms de GDScript au total).
- **Ordre conservé** : si une case est creusée avant la fin, la peinture en attente est terminée d'abord. Les captures et les tests forcent la peinture complète (`World.finish_painting()`).

## Étape 4 v2 — Ambiance : Ancre, portails, éclairage

| Scénario | Identiques (±6) | Exacts |
|---|---|---|
| `etape4_ancre_t0_5` / `t1_3` / `t2_7` | 99,65 / 99,65 / 99,64 % | idem |
| `etape4_ancre_reactivation` (60 %) | 99,68 % | 99,64 % |
| `etape4_portail_t2` / `t5` | 99,66 / 99,66 % | 99,61 % |
| `etape4_indra_actif` | 100 % | 100 % |
| `etape4_eclairage` | 99,57 % | 22,38 % |

- **Éclairage** : le calque d'obscurité du prototype est un canvas au quart de la résolution, en couleurs 8 bits prémultipliées, agrandi par le navigateur. Godot le recalcule en flottants dans un shader, au centre des mêmes pixels, avec une interpolation bilinéaire. Les dégradés diffèrent donc d'une unité ou deux presque partout (22 % de pixels exactement égaux), mais 99,57 % restent à ±6. La référence est composée par `compare.py` : capture du jeu, plus le calque `*_light.png` agrandi en bilinéaire.
- **Unités masquées** dans les références de l'étape 4 (`disable: units`) : l'Ingénieur sort du portail à t = 3 s, et il est migré à l'étape 5.

## Étape 5 v2 — Unités, déplacement, réactivation de l'Ancre

- **Non-régression** : les 18 scénarios des étapes 2 à 4 donnent les mêmes scores qu'avant, avec le nouveau `pixel_snap` (décalage ramené dans le repère local du sprite, pour les unités retournées).
- **Unités** : les images viennent des planches précalculées (`assets/baked/units/`). Le contrôle est visuel, en jeu : repos, marche et agenouillement de l'Ingénieur. Aucun scénario de référence ne contient d'unité pour l'instant. Une comparaison automatique avec unités sera ajoutée quand les unités seront déterministes dans les deux moteurs (combat, étape 8).
- **Dialogue d'accueil** : le signal `engineer_greeted` est émis à la sortie du portail. Son affichage relève du HUD (étape 6).

## Étape 6 v2 — HUD et dialogue

**Parité vérifiée par les tests**
- Panneau d'ordres et textes du HUD : identiques au prototype sur 26 contextes (`test_hud_actions.gd`, référence `assets/baked/hud/hud_actions.json`). Sont comparés les identifiants, icônes, libellés, touches, infobulles, états désactivé et actif, recharges, ainsi que les surtitres, noms, points de vie, statuts, statistiques, légendes, prochain assaut et portraits.
- Catalogue (bâtiments, coûts, adeptes, table FIGHT, paliers d'expérience) : identique (`test_catalog.gd`).
- Minicarte : fond à 99,99 % des pixels à ±6, avant et après le scénario de creusement (`test_minimap.gd`).
- Dialogue d'accueil, notice d'ouverture et 3 textes de bannière : identiques (`test_dialogue.gd`).

**Écarts assumés**
- **Police (décision D7)** : Noto Serif (libre) remplace Georgia. Le prototype tourne ici avec la police de repli du navigateur, plus étroite. Les textes Godot sont donc 4 à 8 % plus larges : le panneau des ressources s'élargit et certains statuts tiennent sur deux lignes au lieu d'une (par exemple « L’Ancre est éteinte · clic droit dessus (ou R) pour la réactiver »). Le symbole ★ vient de DejaVu Sans, comme le repli du navigateur.
- **Mise en page** : les règles de `hud.css` sont portées pour une fenêtre d'au moins 1150 px de large, avec les dimensions relevées à 1440×900. Les variantes pour petits écrans (`max-width` 1150, 900, 720 et 520 px) ne sont pas portées : en dessous de 1150 px, la grille garde ses minimums et les tailles de police du bureau.
- **Rendu des panneaux** : dégradés, anneaux intérieurs et ombres CSS sont redessinés (`HudStyle`). Les ombres floues sont approchées par quelques couches transparentes.
- **Clic droit sur le bandeau** : dans le prototype, l'ordre du clic droit est écouté sur toute la fenêtre, si bien qu'un clic droit sur le HUD donne un ordre au monde, sous le panneau. Dans Godot, le HUD intercepte le clic.
- **Infobulles** : celles de Godot (`tooltip_text`) remplacent l'attribut `title` du navigateur ; leur délai et leur style diffèrent.
- **Ordres des bâtiments** : les boutons Invoquer, Entraîner et Ressusciter s'affichent avec les mêmes états que dans le prototype. Leur effet n'arrive qu'à l'étape 7, avec la construction ; en attendant, ils affichent une notice. Le placement au clic en mode construction relève aussi de l'étape 7. L'invocation du héros Tireur depuis l'Ancre est déjà migrée.
- **Textes dessinés dans le monde** : le libellé de l'Ancre (ÉTEINTE, RÉACTIVATION n %, ANCRE) et l'anneau de l'Ancre sélectionnée sont migrés. Les noms des bâtiments, la file de la caserne, les badges de niveau (★n) et les étiquettes d'escouade arrivent aux étapes 7 et 8.
- **Dialogue** : seul le mode compact est utilisé dans 73b410f (accueil de l'Ingénieur). Le mode complet est porté sans son interface de choix, que le prototype n'appelle jamais.

**Revue humaine** : `python3 tests/visual/hud_review.py` capture le prototype dans Firefox sans fenêtre (`tools/baker/hud_shot.html`), à partir des mêmes contextes, et assemble `tests/visual/out/etape6/revue_hud.png` ainsi que les images `cote_a_cote_*.png`. Les captures Godot se font avec `godot --path . res://tests/visual/hud_capture.tscn`.

## Étape 7 v2 — Économie et bâtiments

| Scénario | Identiques (±6) | Exacts |
|---|---|---|
| `etape7_batiments_a` (4 temples, caserne, Puits des Âmes) | 99,68 % | 96,00 % |
| `etape7_batiments_b` (Bibliothèque, Forge, Atelier, Chambre) | 99,79 % | 97,00 % |
| `etape7_incantation_25` / `50` / `75` (Temple de Sigil) | 99,62 / 99,76 / 99,81 % | 95,39 / 96,85 / 97,95 % |

**Parité vérifiée par les tests**
- `snapFor`, `buildableGround`, `validSite` et `workSpot` : identiques au prototype sur 60 points témoins × 3 types, soit 180 cas (`test_site.gd`, référence `assets/baked/hud/sites.json`).
- Chantier (paiement, Ingénieur sur son point, 4 ou 8 s d'Énonciation, annulation remboursée, déblocages), prière, caserne et Puits des Âmes : `test_construction.gd`, `test_prayer.gd`, `test_caserne.gd`, `test_soulwell.gd`.
- Parcours en jeu (`tests/visual/hud_interact.tscn`) : placer le Temple de Sigil au clavier et à la souris, voir l'Énonciation, sélectionner le temple, invoquer un adepte, le voir prier.

**Écarts assumés**
- **Écarts de pixels** (environ 3 % de pixels non exacts) : contours anticrénelés des emprises (`drawBuildGrid`) et empreinte animée du chantier. Celle-ci est un tracé vectoriel dans le prototype ; Godot la redessine à partir d'une image précalculée au double, lissée.
- **Ordre de dessin des libellés** : les noms des bâtiments, la file de la caserne, les âmes en attente et le nombre d'adeptes en prière sont dessinés après tous les objets du monde, toujours sous l'éclairage. Dans le prototype, ils sont dessinés avec chaque bâtiment, donc parfois recouverts par un objet plus au sud.
- **Bulle d'incantation** : la police « Pixelify Sans » n'est pas chargée par le prototype, qui retombe sur la police système. Godot utilise DejaVu Sans grasse.
- **Effets** : l'éclair de sortie d'un adepte (`flash`) et l'onde d'achèvement d'un chantier (`zone`) sont regroupés avec les autres effets à l'étape 9. L'onde du miroir de l'Ancre à l'achèvement est, elle, migrée.
- **Images des bâtiments** : les boucles animées précalculées ne bouclent pas exactement (« raccord » du baker). Après la première boucle, une image peut différer légèrement de celle que le prototype calcule en continu.
- **Catalogue** : il reste dans `data/catalog.gd` (constantes GDScript, vérifiées contre le prototype par `test_catalog.gd`), et non en fichiers `.tres` comme le prévoyait la règle 4 du plan. Le test garantit la parité, et un second format serait une source de divergence.

## Étape 8 v2 — Combat, ennemis, vagues, expérience, balistes

| Scénario | Identiques (±6) | Exacts |
|---|---|---|
| `etape8_balistes_ruine` | 99,54 % | 88,89 % |
| `etape8_balistes_actives` (Gardes tyriennes éveillées) | 99,53 % | 88,89 % |
| `etape8_ennemis` (rampant, cracheur, brute, rejeton) | 99,79 % | 99,75 % |

Les 11 % de pixels non exacts des scénarios de balistes viennent du sol de la jungle autour de l'entrée (écarts de ±1 à ±6). Ils sont déjà présents dans `etape2_couloir_px2`.

**Parité vérifiée par les tests** (référence `assets/baked/hud/combat.json`, extraite par `tools/baker/hud.js`)
- Table `FIGHT` complète, `CHARGE`, `MOULINET`, `SILLON`, `KILL_XP`, `TURRET_CONFIG`, `EVIL`, `VOLLEY` (`test_fight.gd`).
- 8 séquences de frappes, rejouées frappe par frappe et identiques au prototype : PV des ennemis, recharge, charges du moulinet, murs de feu, expérience. Elles couvrent l'Ingénieur aux niveaux 1 et 3, l'adepte de Sigil, l'archer, l'épée et bouclier aux niveaux 1 et 4, et le lance-flammes aux niveaux 1 et 2.
- Charge du Lac : 30 pas de 0,05 s identiques au prototype (position, dégâts, étourdissement).
- `afterArmor`, gains d'expérience successifs (`test_xp.gd`) ; 6 vagues (nombre, instants, positions, types) et statistiques des ennemis (`test_waves.gd`).
- Portails maléfiques (7 s, plafond de 8), 3 conditions de défaite et leurs bannières, Maj+R : `test_evil_portals.gd`, `test_defeat.gd`, `test_restart.gd`.
- Partie scriptée de 5 vagues, avec Ingénieur, balistes, archer et épée et bouclier : 65 ennemis abattus, journal d'événements identique sur 3 exécutions (`test_scripted_game.gd`).

**Écarts assumés**
- **Hasard** : Godot tire ses nombres d'un `RandomNumberGenerator` dont la graine est celle de la partie. Les tirages sont les mêmes (dispersion des apparitions, recharges initiales, dispersion des carreaux, sorties de la caserne), mais la suite de nombres diffère de `Math.random`. Une partie est rejouable à l'identique avec la même graine.
- **Impact (`hit`)** : le disque à dégradé radial du canvas (`sphere3`) est approché par des disques concentriques.
- **Garde tyrienne active** : l'arme est précalculée en 16 orientations × 24 phases du cycle de tir, à l'instant 0. Une éventuelle animation de l'arme au repos, qui dépendrait du temps, n'est pas reproduite. L'orientation est arrondie au 16e de tour le plus proche.
- **Héros** : le code du Paladin, du Soigneur et des disciples d'Indra (attaques, compétences, animations d'épée) est porté. Ces héros ne sont toutefois pas invocables dans 73b410f (décision D9, voir l'étape 9). Les images de tir du garde (`shoot`) ne sont pas utilisées.
- **Performances** : en combat soutenu (13 combattants, balistes, effets), le jeu tourne à 55–58 im/s sur ce GPU intégré, dont environ 5 im/s pour l'éclairage. Les deux premières secondes du premier combat descendent vers 46 im/s, le temps de compiler les shaders à la première apparition des effets ; c'est à traiter à l'étape 12 (export et performances). Mesure : `godot --path . res://tests/visual/combat_demo.tscn -- --profil`.

## Étape 9 v2 — Héros et effets restants

| Scénario | Identiques (±6) | Exacts |
|---|---|---|
| `etape9_heros` (Paladin sélectionné et blessé, Soigneur, Tireur, Ingénieur, garde) | 99,95 % | 99,81 % |
| `etape9_attaques` (5 coups d'épée du Paladin, 2 salves du Tireur en cours) | 99,97 % | 99,85 % |
| `etape9_effets` (11 effets : impacts, ondes, rayon, rivet, flèche, carreau, explosion ; 2 murs de feu) | 99,76 % | 99,60 % |

Les sprites des héros, les 12 images de chaque coup d'épée et de la salve, et tous les effets dessinés pixel par pixel (rivet, flèche, carreau, explosion, étincelles, murs de feu) sont exacts. Les pixels restants sont les bords anticrénelés des tracés vectoriels du canvas : ombres et anneau de sélection (ellipses), ondes (`zone`), rayon (`laser`) et impacts (`hit`).

**Parité vérifiée par les tests** (`test_heroes.gd`, référence `assets/baked/hud/combat.json` : `heroes`, `abilities`)
- 4 combats de 40 pas de 0,05 s dans la boucle complète, identiques au prototype à chaque pas (positions, PV, recharges, PV de l'Ancre, nombre d'effets) : Paladin niveaux 1 et 3 (avec le Tireur en allié), Tireur niveau 2 (salves), Soigneur et Ingénieur blessé (soins).
- Compétences : Égide (Paladin), Restauration (Soigneur), Discipline martiale (toute autre unité, ici un archer), Tir de précision (Tireur), puis recharge. Mêmes PV, boucliers, bonus, recharges et même effet que le prototype.
- Drapeau D9 (`Simulation.legacy_heroes`, réglage de projet `exiles/debug/heros_historiques`, désactivé par défaut) : Paladin, Soigneur et Tireur posés en début de partie aux coordonnées des lignes commentées de `init()`, sur un sol praticable (sentier de la jungle au sud de l'entrée), et `selected = [units[0]]` sélectionne le Paladin, comme le ferait le prototype en décommentant la ligne.
- Effets différés depuis l'étape 7, désormais émis aux mêmes moments que dans le prototype : onde d'achèvement d'un chantier, éclair de sortie d'un adepte (couleur du portail de son dieu), éclair de sortie de la caserne, onde et éclair de résurrection, ondes de l'Ancre éveillée (7 et 12), éclair à chaque coup de creusement, onde de la case creusée, ondes de la galerie révélée et des portails maléfiques éveillés.
- Démonstration en jeu réel avec le drapeau (`tests/visual/heroes_demo.tscn`) : combat des trois héros, Tir de précision à la touche Espace, Égide et Restauration.

**Corrections de parité trouvées en route**
- **Précision des positions** : `clampWorld` repassait chaque position par un `Vector2` de Godot, en 32 bits, à chaque déplacement. Les positions restent maintenant en double précision, comme en JavaScript, sauf quand l'unité doit être sortie de la roche. Les distances (`dist`, et les seuils de travail et d'arrivée) sont aussi calculées en double précision. Sans cette correction, une brute arrivée à exactement 3,0 unités du Paladin, la limite de sa recherche, était ignorée.
- **Barres de vie** : épaisses de 4 pixels natifs au lieu de 4 pixels d'écran quand la vue n'avait pas de simulation (captures). Elles lisent maintenant PX dans le monde. `etape8_ennemis` passe de 99,79 à 99,99 %.
- **Orientation** : la vue des héros partage désormais `u._face` avec les frappes, comme le prototype. Une orientation imposée par un coup tient tant qu'aucun ennemi n'est visé et que l'unité ne bouge pas.
- **Scénarios « text »** : `capture.gd` masquait toute la surimpression. Il n'en masque plus que les textes, comme `ctx.fillText` neutralisé dans le prototype. Les autres scénarios sont inchangés ou meilleurs.

**Écarts assumés**
- **Comportements du prototype reproduits tels quels** : la Restauration rend aussi 55 PV à une unité tombée dans son rayon, qui reste pourtant parmi les âmes du Puits. La Discipline martiale s'applique à toute l'escouade de l'unité, et donc à toutes les unités hors escouade (escouade 0). Le Paladin et le Soigneur n'ont pas de bouton de compétence dans le panneau, comme dans le prototype.
- **Positions des héros** : les coordonnées commentées dans `init()` datent de la forêt ; elles tombent sur le sentier de la jungle, à environ 170 unités au sud de l'Ancre.

## Étape 12 v2 — Export et performances

Les 29 scénarios visuels gardent exactement leurs scores après les optimisations. Seule exception, `etape4_eclairage`, qui reste à 99,57 % à ±6 mais passe de 22 à 35 % de pixels exacts. Mesures et procédure : `EXPORT.md`.

**Optimisations, sans changement de comportement**
- **Éclairage** : le calque d'obscurité est rendu une seule fois par image au quart de la résolution (une SubViewport en 8 bits prémultipliés, comme le canvas du prototype), puis agrandi en bilinéaire. Avant, chaque pixel d'écran recalculait quatre valeurs du quart. Chaque lueur est maintenant un quadrilatère additif, au lieu d'une boucle sur toutes les sources pour chaque pixel. La liste des cristaux lumineux n'est recalculée que quand le décor change.
- **Planche commune du décor** (`tools/baker/decor_atlas.py`) : les 247 sprites sont rassemblés sur une texture de 1024×512, avec des bords prolongés de 2 pixels. Un seul matériau couvre tous les objets triés (`shaders/world_sprite.gdshader`), qui remplace `pixel_snap` et `wind_foliage` pour eux. Le feuillage y est reconnu par une texture de métadonnées lue au point d'ancrage ; son cisaillement par le vent et son lissage bilinéaire sont calculés dans le shader. Une modulation propre à chaque feuillage aurait cassé le regroupement des appels de dessin (mesuré : 2 000 appels pour 1 000 arbres). Résultat : la jungle passe de 3 144 à 315 appels de dessin.
- **Recherche de chemin** : tables de l'A\* en tableaux compactés réutilisés, tas en tableaux parallèles, lecture directe du cache de praticabilité, voisins déroulés. Les chemins sont identiques au prototype (30 chemins de référence) et à l'ancienne version (2 000 trajets au hasard), et 2,7 fois plus rapides.
- **HUD** : mis à jour toutes les 0,1 s de simulation, comme `updateHUD` dans le prototype (`HUD.lastUpdate`), et aussitôt que la sélection, le menu, le mode, le bâtiment choisi ou la fin de partie changent.
- **Vues des unités et des adeptes** : elles ne sont redessinées que si l'image, l'orientation, la sélection, les PV, le niveau ou PX changent.
- **Préchauffage des shaders** : un exemplaire de chaque effet est dessiné hors de l'écran pendant les deux premières images. L'arrêt de 316 ms au premier rivet a lieu au chargement, plus en combat.

**Écarts assumés**
- **Planche du décor** : les PNG bruts sont identiques au pixel près aux sprites extraits (`test_baked_assets.gd`). L'import de Godot recolore les pixels transparents des bords (« fix alpha border ») différemment selon l'image, sans effet visible.
- **Pics de la simulation** : dans le pire cas (40 ennemis qui poursuivent des alliés en mouvement), plusieurs ennemis recalculent parfois leur chemin dans le même tick, ce qui donne des images à 25–36 ms. Les étaler sur plusieurs ticks changerait le comportement par rapport au prototype ; ce n'est pas fait.
- **Mesure Web** : le navigateur synchronise sur l'écran, la mesure est donc plafonnée à 60 im/s.
