# Plan de migration v2 — *Exilés — Sanctum Lacertae* vers Godot 4

**Source (lecture seule)** : `/home/drums/code/exilesdefense`
**Version de référence figée** : commit **`73b410f`** (14/11/2026 20:44, « Réorganisation : … galeries, éclairage, adeptes… »)
**Cible** : `/home/drums/code/jeu-godot/jeu-godot` (Godot 4.7.2-stable)
**Statut** : plan v2 à valider. Il remplace le plan v1, établi sur le commit `6bd9261` (version « jungle isométrique »).
**Date** : 14 novembre 2026

---

## 0. Pourquoi une v2, et ce qui change

Le commit `73b410f` transforme le prototype : vue, carte, économie et unités. Le plan v1 et les étapes 1 et 2 visaient la version précédente (jungle vue en isométrique).

| Domaine | v1 (`6bd9261`) | v2 (`73b410f`) |
|---|---|---|
| Vue | Isométrique (losanges 64×32) | **De dessus en 3/4** : x vers la droite, z vers le bas, la hauteur monte à l'écran |
| Carte | Jungle, clairière, temple, 256×244 unités | **Montagne** : salle de départ sous la roche, couloir vers la jungle au sud, galeries cachées, 464×408 unités |
| Terrain | Statique | **Dynamique** : l'Ingénieur creuse la roche case par case, et les galeries cachées se révèlent |
| Ambiance | Plein jour | **Éclairage** : obscurité d'ambiance et halos autour des sources |
| Économie | Ressources produites mais jamais dépensées | **4 ressources** (Forge, Vie, Discipline, Savoir) avec coûts, déblocages et invocations |
| Unités | Ingénieur et soldats d'Indra | Ingénieur (qui tire et creuse), **7 types d'adeptes**, héros Tireur, expérience et niveaux, réanimation |
| Ennemis | 3 types, 5 vagues, en ligne droite | 4 types (dont les rejetons des **portails maléfiques**), vagues sans fin, **calcul de chemin A\*** |
| Fin de partie | Victoire après 5 vagues | **Plus de victoire** ; défaite si l'Ancre tombe, si tous les alliés meurent ou si l'Ingénieur meurt |

### Figer la référence sans toucher au prototype

Le prototype évolue vite : le commit `73b410f` a moins d'une heure au moment de ce plan. La migration vise donc **une version figée**. Le baker et le harnais de référence liront les fichiers **depuis l'historique git** (`git show 73b410f:<chemin>`, en lecture seule), et non depuis le dossier de travail. Tu peux continuer à faire évoluer le prototype pendant la migration.

Le passage à une version plus récente est une **resynchronisation** explicite (§5, procédure R) : rapport des écarts, puis mise à jour ciblée du plan et du code. Elle se fait à ta demande, jamais en silence.

### Ce qui est déjà fait et reste valable

| Élément | État | Réutilisation |
|---|---|---|
| Étape 0 : socle (git, réglages pixel art, autoloads, lanceur de tests) | ✅ Fait (`69fa39c`) | Telle quelle |
| Baker : serveur en lecture seule, chargement du prototype, aller-retour PNG, PNG déterministes, conservation des `.import` | ✅ Fait (`2304437`, `9198315`) | À étendre : lecture depuis git, nouveau marqueur d'amorçage, nouveaux kits |
| Harnais de captures de référence et graine fixée | ✅ Fait | À étendre : galeries à graine fixée, scénarios de creusement |
| Capture Godot et comparateur de pixels | ✅ Fait | Tels quels |
| Shader d'alignement sur la grille native (`pixel_snap`) | ✅ Fait | Tel quel : `natP()` est inchangé |
| Shader de vent sur le feuillage | ✅ Fait | À adapter : le cisaillement est maintenant **quantifié** par pas de PX/3 (cache de variantes, `decor-renderer.js`) |
| `core/rng.gd` (LCG, `hash`, `vnoise` au bit près) | ✅ Fait | Tel quel |
| Caméra (clavier, glisser droit, molette) | ✅ Fait | À adapter : projection, limites, position de départ |
| `core/iso.gd` et décor de la jungle isométrique | ✅ Fait | **Remplacés** (projection 3/4) |
| Références visuelles `etape2_*` / `etape3_*` | ✅ Faites | **Obsolètes**, à régénérer |

---

## 1. État de l'environnement cible (constaté via le MCP Godot)

- Godot 4.7.2-stable. Rendu **Compatibility**, filtre nearest, arrondi 2D global désactivé (l'alignement est fait par le shader).
- Fenêtre 1440×900 sans étirement.
- Autoloads : `MCPRuntimeProbe`, `Events`, `GameState`, `Balance`.
- Scène principale : `res://main/main.tscn` (le monde de l'étape 2, en version jungle).
- 19 tests GDScript au vert. Le baker et le comparateur fonctionnent.
- Templates d'export : toujours **non installés**.
- Outils locaux : `python3` + Pillow et numpy, `firefox`, `godot`. **Pas** de Node ni de Chromium.

Toolsets MCP utilisés : `scripts`, `scene_edit`, `composite`, `project`, `resources_edit`, `input_map`, `theme_ui`, `shader`, `runtime`, `input`, `testing`, `profiling`, `export`.

---

## 2. Inventaire fonctionnel de `73b410f`

> Valeurs tirées du code. Les numéros de ligne renvoient au script principal d'`Index.html` (extrait) ou aux modules `assets/*.js`.

### 2.1 Projection, caméra et rendu

- **Projection 3/4** : `project(x, y, z) = (W/2 + (x − cam.x)·8·PX, H·0,45 + (z − cam.z)·8·PX − y·8·0,96/0,86·PX)`.
- **Coordonnées natives** : `natW(x, y, z) = (x·8, z·8 − y·KH)`. Une case de 4×4 unités devient une **tuile carrée de 32×32 px**. `natP` arrondit toujours avec `Math.round`.
- **Tri de profondeur** par `d = z` (ou par `dz`, propre à chaque objet) : c'est directement l'ordonnée écran.
- **Caméra** :
  - départ en (0, −148) ;
  - limites `x ∈ [−202, 202]`, `z ∈ [−316, 44]` (`clampCam`) ;
  - mêmes commandes qu'avant : ZQSD/WASD/flèches à 10 u/s, glisser droit avec un seuil de 5 px, molette pour PX de 1 à 6.
- **Vent** : feuillage lissé et cisaillé, avec un cisaillement **quantifié** (sommet décalé par pas de PX/3 pixels d'écran, `treeVariant`).
- Le mode non pixel (`P`) et le calque Three.js ne sont **plus chargés** (`tireur_saurus_lite.js` retiré) : décision D3 confirmée.

### 2.2 Carte et terrain

- **Monde** : `x ∈ [−232, 232]`, `z ∈ [−336, 72]`.
- **Salle de départ** (`CAVE`) : `x ∈ [−56, 56]`, `z ∈ [−168, −96]`, avec des parois ondulées (`caveW`, `caveE`, `caveN`, `caveS`).
- **Couloir** de demi-largeur 7 vers le sud. Le flanc de la montagne suit `mountainEdge(x) = −78 + 4 sin(0,13x) + 3 sin(0,31x + 1)`. Au sud, la jungle.
- **Praticable** : `walkable` = dehors, ou salle, ou couloir, ou case creusée, ou galerie découverte. `pushOutOfRock` replace une entité sortie du sol praticable.
- **Galeries** (`galleries.js`) :
  - 12 à 16 « vers » aléatoires sur une grille à 1 unité, **graine tirée par `Math.random`** à chaque partie ;
  - composantes connexes, et un portail maléfique par réseau ;
  - **invisibles** (roche) jusqu'à ce qu'un creusement les touche ; la révélation repeint la zone et ajoute parois, cristaux et portail.
- **Creusement** (`adepts.js`) :
  - clic droit de l'Ingénieur sur la roche ; case de 4×4 ;
  - 4 coups d'1 s (vitesse ×4 pour l'Ingénieur, donc 1 case par seconde) ;
  - enchaînement automatique sur une case voisine ;
  - le sol est repeint (`caveTile`), une falaise est ajoutée au nord, et la grille de cheminement est invalidée.
- **Sol initial** (`buildPixelWorld`), environ 3808×3360 px natifs :
  - roche, sol de grotte, bords ;
  - herbe et sentier en textures 512 px répétées ;
  - ombres portées des arbres et des rochers.
- **Décor** :
  - arbres (6600 tirages), rochers (2600), fougères (2000) dans la jungle ;
  - faces de falaise (`faceSprite`) ;
  - éboulis de la salle (70), éboulis du dos de la montagne (1900) ;
  - stalagmites et cristaux le long des parois (certains émettent de la lumière) ;
  - autel (`topBox`) et orbe ;
  - **4 portails divins** (Indra, Sigil, Medeina, Aether) avec leurs décorations et effets ;
  - le **portail des Exilés** au fond nord.

### 2.3 Ancre, portails et introduction

- **Introduction** : l'Ancre est **éteinte** au départ (orbe grisée, sans arcs). L'Ingénieur sort du portail central (atlas de 554 images, dessiné **cisaillé** contre la paroi nord) au bout de 3 s, rejoint (−13, core.z + 7), puis le dialogue d'accueil s'ouvre.
- **Réactivation** : par l'Ingénieur (clic droit sur l'orbe, `R`, ou bouton) : 8 s de présence au point (core.x − 5, core.z + 4). Ensuite :
  - +1 de chaque ressource par seconde ;
  - les tourelles s'éveillent ;
  - premier assaut 20 s plus tard.
- **Arcs de l'Ancre** : actifs une fois l'Ancre réveillée ; pendant la réactivation, ils crépitent de plus en plus souvent avec la progression.
- **Portails divins** : actifs 3,5 s à chaque invocation d'adepte, avec des effets propres au dieu (arcs d'Indra, glyphes de Sigil, lucioles de Medeina, éclats d'Aether).
- **Portails maléfiques** : chacun fait sortir un rejeton (`beast` : 22 PV, vitesse 2,6, dégâts 4) toutes les 7 s, avec au plus 8 rejetons vivants par portail.

### 2.4 Économie et bâtiments (`buildings.js`)

| Bâtiment | Coût | Débloqué par | Taille | Durée | Rôle |
|---|---|---|---|---|---|
| Temple de Sigil (`G`) | 20 Savoir | — | 3×3 | 4 s | Adeptes de Sigil, prière → Savoir |
| Temple d'Aether (`E`) | 20 Forge | — | 3×3 | 4 s | Prière → Forge |
| Temple de Medeina (`V`) | 20 Vie | — | 3×3 | 4 s | Prière → Vie |
| Temple d'Indra (`I`) | 20 Discipline | — | 3×3 | 4 s | Prière → Discipline |
| Bibliothèque (`L`) | 200 Savoir | Sigil | 3×3 | 8 s | (sans effet pour l'instant) |
| Forge (`F`), Atelier (`T`) | 200 Forge | Aether | 3×3 | 8 s | (sans effet) |
| Chambre à coucher (`N`) | 200 Vie | Medeina | 2×2 | 8 s | (sans effet) |
| Puits des Âmes (`U`) | 200 Vie | Medeina | 2×2 | 8 s | Réanimation d'une unité tombée (200 Vie), qui garde son niveau |
| Caserne (`C`) | 200 Discipline | Indra | 3×3 | 8 s | Entraînement : lance-flammes, archer, épée et bouclier (100 Discipline, 6 s, file de 5) |

- **Placement** :
  - grille de 4 unités (`snapFor`, cases centrées pour les tailles impaires) ;
  - `validSite` : sol constructible, hors couloir, chemin, allée centrale et rangée des portails ;
  - distance minimale aux autres bâtiments, aux tourelles, à l'Ancre et aux unités.
- **Chantier** :
  - le coût est payé à la pose, et **remboursé si le chantier est annulé** ;
  - l'Ingénieur se place sur le côté (`workSpot`) ;
  - construction « **Incantation** » (`temple-incantation.js`) : les pierres du sprite montent d'un éboulis, l'Ingénieur s'agenouille, un miroir de l'Ancre flotte au-dessus de lui, et une bulle affiche les vers de la formule propre au bâtiment.
- **Invocation d'adepte** : depuis un temple achevé, pour 50 de la ressource du dieu. L'adepte sort du portail divin et va prier : +1 de la ressource par seconde et par adepte, avec un popup « +5 » toutes les 5 s.
- **Héros Tireur** : 100 de chaque ressource, invoqué depuis l'Ancre active, sort du portail central.

### 2.5 Unités, combat et expérience (`adepts.js`, `Index.html`)

| Unité | PV | Détection / portée | Dégâts / recharge | Particularités |
|---|---|---|---|---|
| Ingénieur | 140 | 86 / 86 | 80 / 1,15 s | Rivet de Sigil (tir) ; creuse, construit, réactive ; vitesse 15,2 |
| Adepte priant (×4 dieux) | 90 à 110 | 6 / 1,9 | 4 / 1,1 s | Prie au temple de son dieu ; vitesse 7,6 |
| Lance-flammes | 120 | 9 / 4,5 | 6 / 0,3 s | Brûlure en zone de 2,2 ; **sillon de feu** toutes les 4 s (mur de 2 s, brûlure 3/s, ralentissement de 40 %) |
| Archer | 85 | 17 / 14 | 11 / 0,95 s | **Charge du Lac** sous 5 de distance (élan, 22 dégâts, étourdissement 0,5 s), puis mêlée 13 / 0,6 s |
| Épée et bouclier | 170 | 7 / 2,2 | 16 / 0,85 s | Ne subit que 55 % des dégâts ; **moulinet** (24 dégâts en zone de 2,8) toutes les 3 frappes |
| Tireur (héros) | 110 | 20 / 17,2 | 19 / 0,78 s | Salve de 3 carreaux ; tir de précision de 95 (recharge 10 s) |

- **Expérience** :
  - une unité gagne l'expérience des ennemis qu'elle achève (rampant 10, cracheur 15, brute 35, rejeton 6) ;
  - palier : `20·1,6^(niveau−1)` ;
  - chaque niveau donne +1 dégât et +1 défense ;
  - dégâts subis : `max(15 %, dégâts − défense)` ;
  - badge ★niveau au-dessus de l'unité.
- **Déplacement** :
  - **A\*** à 8 directions sur une grille de 2 unités, lissé par ligne de vue (`findPath`, `steer`) ;
  - chemin en cache, invalidé à chaque creusement ;
  - glissement le long des murs (`move`).
- **Sélection** : clic, Maj+clic, **cadre de sélection** au clic gauche, clic sur un bâtiment, clic sur l'orbe.
- **Clic droit**, par ordre de priorité :
  1. réactiver l'Ancre ;
  2. tourelle ;
  3. creuser (Ingénieur) ou prier (adeptes sur leur temple) ;
  4. attaquer un ennemi ;
  5. se déplacer.

### 2.6 Ennemis et vagues

- **Ennemis** : rampant, cracheur et brute, aux statistiques inchangées, plus le rejeton des portails maléfiques. Ils suivent les chemins A\* et sont replacés hors de la roche.
- **Vagues** :
  - premier assaut 20 s après la réactivation de l'Ancre, **sans fin** ensuite ;
  - `4 + 3w` ennemis, intervalle `max(0,35 ; 1,5 − 0,14w)` ;
  - apparition au sud, en z ≈ 62–66 et x = ±2 ;
  - pause de 4 s entre deux vagues, et seulement quand aucun ennemi hors rejeton ne reste.
- **Tourelles** : en (±11, −71), à l'entrée du couloir. Elles **s'éveillent avec l'Ancre** (plus de réparation). Portée 70, dégâts 40, cycle de 3,6 s.
- **Défaite** : l'Ancre tombe à 0, ou plus aucun allié n'est vivant, ou l'Ingénieur meurt (« L'INGÉNIEUR EST TOMBÉ »).

### 2.7 Éclairage (`lighting.js`)

- Calque d'ombre calculé au **quart de la résolution**, puis agrandi et lissé par le navigateur.
- Ambiance `rgba(12,7,4,0,28)`, creusée par un dégradé radial autour de chaque source :
  - unités (8, avec scintillement) ;
  - bâtiments (selon leur type) ;
  - tourelles ;
  - Ancre active ;
  - cristaux.
- Vignette sombre sur les bords.

### 2.8 HUD et dialogue

- **Bandeau du haut** : vague (« — » avant le premier assaut), **Forge, Vie, Discipline, Savoir, Exilés**.
- **Panneau d'actions dynamique** (`panelActions`) : de 6 à 12 boutons selon le contexte, avec leur touche :
  - Ingénieur (Construire, Réactiver/Réparer, Position, Déplacer) ;
  - menu de construction (10 bâtiments + Retour) ;
  - Ancre (Réactiver, héros Tireur) ;
  - temple (Adepte) ;
  - caserne (3 unités) ;
  - Puits des Âmes (jusqu'à 9 unités tombées) ;
  - adeptes (Prier).
- Minicarte (nouvelles proportions), portrait (nouveau sprite de l'Ingénieur), statuts contextuels, notice, bannière.
- Dialogue d'accueil : bulle reliée à la tête de l'Ingénieur (texte mis à jour).

### 2.9 Animations et effets

- Sprites de repos et de marche ; **nouvel Ingénieur** (`engineer.js` : 24 images de repos, 12 de marche avec son propre rebond, casque rétractable) ; agenouillement pendant l'incantation.
- **Adeptes** (`adept-sprites.js`) : grilles de 24×28 px, repos, marche et travail sur 4 images à 6 im/s, agrandis ×1,9.
- Effets dessinés pixel par pixel : rivet, flèche, carreau, explosion, impacts, sillons de feu, arcs de l'Ancre, effets des portails divins, braises des portails maléfiques.
- Bâtiments : base et couche animée (`pixel-buildings.js` v12), balistes (`ballista-tyrienne-models.js`, modèles d'arme en 3D isométrique).

### 2.10 Sauvegarde

Toujours **aucune**. Elle devient plus utile, puisque l'état comprend désormais la graine des galeries, les cases creusées, les bâtiments, les adeptes et l'expérience (étape 11, décision D6 : **annulée** le 15/11/2026, le jeu reste sans sauvegarde comme le prototype).

### 2.11 Tests du prototype

Les tests `tests/*.test.mjs` et les tests de fumée Python visent encore des modules qui ne sont **plus chargés** (`foundry-game.js`, `sawmill-game.js`…). Ils ne servent plus de référence. Les tests Godot seront écrits directement à partir du code de `73b410f`.

---

## 3. Ressources graphiques

### 3.1 Réutilisées telles quelles

- `assets/portal-atlas.png` de `73b410f` (2080×3920, 554 images de 130×112, **nouvelle version** de 1,48 Mo), dessiné avec la transformation `(k, k·0,5, 0, k)`.
- Icônes SVG du HUD (`HUD_ICONS` de `hud.js` v23, dont les nouvelles : `book`, `flame`, `bow`…).

### 3.2 Extraites par le baker (fonctions d'origine, graine fixée)

| Famille | Source | Sortie |
|---|---|---|
| Sol initial | `buildPixelWorld` | 3808×3360 en blocs de 1024 (16 blocs), origine (`gx0`, `gy0`) |
| Décor initial | `PW.objs` | Sprites uniques + placements : arbres, rochers, fougères, falaises, éboulis, stalagmites et cristaux (indicateur de lumière), autel, orbe, décorations divines |
| Décor créé en cours de partie | `faceSprite(5, rng(v·41+5))` v = 0–5 ; `caveSpire(…, rng(v·17+3), cristal)` | 6 faces de falaise, 12 stalagmites et cristaux |
| Tuiles de terrain dynamique | `caveTile` / `rockTile` en coordonnées locales 32×32 | Bases constantes du sol de grotte et de la roche, à composer en jeu (§4.4) |
| Portails | `PortalKit.render` | 4 dieux × 12 images + l'image éteinte ; portail maléfique (12 images) |
| Unités et ennemis | `buildUnitSprites`, `buildEnemySprites` (dont `beast`), `EngineerKit` | Planches de repos, marche et tir |
| Attaques | `buildAttackSprites` | Épée ×5, arbalète |
| Adeptes | `AdeptArt.build` | 7 rôles × repos, marche et travail |
| Bâtiments | `PixelBuildings` v12 | 10 sprites (temple, foundry, sawmill, barracks, library, forge, workshop, bedroom, soulwell, caserne) : base et boucle animée ; baliste en ruine et active (16 orientations × 24 phases) |
| Surimpression | `TempleKit.footprint`, icônes | Empreintes ×2, icônes de ressources |
| Valeurs de test | Fonctions JS | Projection 3/4, vent quantifié, galeries pour 5 graines (masque, nombre, portails), chemins A\* témoins, tests `walkable` |

### 3.3 Réécrits en GDScript ou en shader (algorithme d'origine)

Ces éléments sont trop dynamiques pour être extraits :
- arcs de l'Ancre et effets des portails ;
- effets d'attaque et sillons de feu ;
- incantation de construction (pierres du sprite, miroir, bulle) ;
- peinture du terrain creusé (§4.4) ;
- calque d'éclairage ;
- empreintes et libellés à la résolution écran.

---

## 4. Architecture Godot cible (v2)

### 4.1 Principes (inchangés)

1. **Monde à la résolution écran, échelle ×PX**, sprites alignés par `pixel_snap` (équivalent de `natP`) ; feuillage lissé ; HUD net.
2. **Simulation séparée du rendu** : unités de monde et secondes de simulation, mêmes constantes que le JS, **même ordre de mise à jour** qu'`update()`.
3. **Tri par Y** : nœud trié placé à `y = 8·d`. Comme l'ordonnée native vaut maintenant `8z`, la plupart des objets sont directs.
4. **Données dans des `Resource` (`.tres`)** : catalogue des bâtiments, adeptes, table de combat, vagues, coûts.
5. **GDScript typé**, modules découplés par le bus `Events`.
6. **Déterminisme** : toute source d'aléa passe par un générateur à graine (galeries, dispersion à l'apparition, effets), pour des tests reproductibles.

### 4.2 Pile de rendu

```text
Main (Node)
├── Simulation (Node)                      # ordre d'update() : portail, bâtiments+Ancre, adeptes, portails maléfiques, unités, tourelles, ennemis, fin
├── World (Node2D, échelle PX, décalage caméra × PX, filtre nearest)
│   ├── Camera (caméra 3/4 : clavier, glisser droit, molette, clampCam)
│   ├── Terrain (16 Sprite2D sur des ImageTexture modifiables : sol initial + cases repeintes)
│   ├── YSort (y_sort_enabled)
│   │   ├── décor (statique + ajouté ou retiré en cours de partie)
│   │   ├── portails (Exilés : cisaillé ; divins ; maléfiques), orbe, autel
│   │   └── bâtiments, tourelles, unités, adeptes, ennemis
│   ├── FxLayer (_draw sur la grille native : arcs, rivets, flèches, carreaux, sillons, effets des portails)
│   └── Lighting (CanvasLayer + shader : ambiance, halos, vignette)
├── OverlayLayer (résolution écran : barres de PV, badges ★, libellés, empreintes, grille de construction, popups, miroir et bulles d'incantation)
└── HUD (CanvasLayer) + Dialogue (CanvasLayer) + SelectBox
```

### 4.3 Arborescence (évolution de la v1)

```text
res://
├── core/            projection.gd (remplace iso.gd), rng.gd, wind.gd, targeting.gd
├── sim/             simulation.gd, wave_director.gd, combat_system.gd, xp.gd, economy.gd, construction.gd,
│                    orb.gd, pathfinding.gd (A* + steer), evil_portals.gd
├── world/
│   ├── terrain/     cave_shape.gd (walkable, inCave…), galleries.gd, dig.gd, terrain_painter.gd
│   ├── decor_loader.gd, world.gd, camera/, anchor/, portals/
│   └── lighting/    lighting.gd, lighting.gdshader
├── entities/        unit/, adept/, enemy/, building/, turret/
├── fx/              pixel_fx.gd, fire_walls.gd, incantation.gd
├── ui/              hud/ (actions dynamiques), minimap/, dialogue/, select_box/
├── data/            buildings.tres, adepts.tres, fight.tres, waves.tres, costs.tres
├── assets/baked/    sorties du baker (régénérées pour 73b410f)
├── tools/baker/     serve.py (--rev), bake.js, reference.js
└── tests/
```

### 4.4 Terrain dynamique : choix technique

Le prototype repeint son canvas de sol à chaque creusement. Dans Godot :

- Le sol est composé de **16 blocs `Image` + `ImageTexture`**, initialisés depuis le sol extrait par le baker.
- **Case creusée** (`digCell`) : copie de la base constante `caveTile` 32×32, plus 6 grains tirés de `rng(i·977 + j·31 + 7)`, plus les bandes `#0008` du côté de la roche. Puis `ImageTexture.update()` du bloc concerné.
- **Révélation de galerie** (`paintRegion`) :
  - les cases entièrement creuses reçoivent la base de grotte et les grains de `rng((x·977 + z·31) >>> 0)` ;
  - les cases mixtes combinent la base de roche, la base de grotte masquée pixel par pixel par `hol()`, et les règles de bord de l'original ;
  - le travail est **réparti sur plusieurs images** si la zone est grande, pour éviter un à-coup ;
  - performance visée : moins de 2 ms par case mixte.
- `walkable` est porté tel quel (formules de la salle, du couloir et du flanc, plus `DUG`, plus le masque des galeries). La grille A\* a un cache invalidé à chaque changement.

### 4.5 Correspondances principales JS → Godot

| JS | Godot |
|---|---|
| `PW.ground` (canvas modifiable) | `Terrain` : `Image` + `ImageTexture` par bloc |
| `PW.objs` trié, filtré et complété à chaud | Nœuds du `YSort` indexés par case de 4×4 (retrait et ajout en O(1)) |
| `RES`, `BUILDINGS`, `ADEPT`, `FIGHT` | Autoload `Economy` + ressources `.tres` |
| `panelActions()` (liste reconstruite) | `HudActions.compute(context) -> Array[ActionSpec]`, puis réutilisation des boutons |
| `drawLighting` (canvas au 1/4) | Shader plein écran : tableau uniforme de N lumières maximum (64), ambiance et vignette |
| `ctx.filter = 'grayscale(.75) brightness(.55)'` (orbe éteinte) | Shader de l'orbe (niveaux de gris et luminosité) |
| `transform(k, k·0,5, 0, k)` (portails) | `Transform2D` avec cisaillement vertical sur le nœud du portail |

---

## 5. Plan de migration par étapes (v2)

Conventions inchangées :
- un ou plusieurs commits par étape ;
- tests `godot --headless --path . -s res://tests/run_tests.gd` (code 0) ;
- validation visuelle : `capture.tscn` + `compare.py` contre les références de `73b410f` ;
- seuil de **98 %** de pixels identiques à ±6, les écarts étant documentés dans `tests/visual/ECARTS.md` ;
- **arrêt pour ta revue** aux étapes 1, 2, 3, 6, 7 et 10.

Complexité : **S** < ½ journée, **M** ½ à 1 journée, **L** 1 à 2 jours, **XL** > 2 jours.

---

### Étape 0 — Socle ✅ (fait, `69fa39c`)

---

### Étape 1 — Baker v2 sur la version figée · **L**

**Tâches :**

1. `serve.py --rev 73b410f` : les fichiers `/src/…` sont servis par `git show <rev>:<chemin>`, sans aucune écriture dans le dépôt source. L'empreinte de référence est le hash du commit.
2. `lib.js` :
   - nouvelle liste de scripts (27, ordre d'`Index.html`) ;
   - nouveau marqueur d'amorçage `generateGalleries();buildPixelWorld();` ;
   - `Math.random` à graine fixe ;
   - **`generateGalleries(SEED)`** à graine explicite.
3. `bake.js`, nouvelles sections :
   - sol de 16 blocs, décor initial et décor créé en cours de partie ;
   - bases `caveTile` / `rockTile` locales ;
   - portails divins et maléfique ;
   - Ingénieur (`EngineerKit`) ;
   - adeptes (`AdeptArt`) ;
   - `beast` ;
   - 10 bâtiments et balistes ;
   - fixtures (projection 3/4, vent quantifié, galeries pour 5 graines, A\* témoins, `walkable` sur une grille de points).
4. Copier le nouvel atlas du portail.
5. `reference.js` :
   - scénarios de grotte : salle de départ à PX 1, 2 et 3 ; couloir et tourelles ; jungle sud ; rangée des portails ;
   - galerie révélée après une série de creusements scriptée (graine fixée) ;
   - Ancre éteinte, en réactivation, active.
6. Supprimer les sorties et références de la version jungle (elles restent dans l'historique git).

**Validation :**

- [ ] Reproductibilité : deux exécutions donnent des SHA-1 identiques.
- [ ] Intégrité de la source : le dossier de travail du prototype est inchangé (`git status` identique avant et après), et **aucune écriture dans `.git`** (l'empreinte de `.git/HEAD` et la liste des refs sont identiques).
- [ ] Exhaustivité : chaque entrée du §3.2 figure dans `bake_report.json`.
- [ ] Les pixels opaques de chaque PNG relu correspondent exactement au canvas source.
- [ ] Planche de contrôle relue par l'utilisateur.

**Risques** :

- **R1** : rendu des grilles d'adeptes et des portails divins sous Firefox. Ils sont en pixels (`Px` / grilles), donc peu exposés.
- **R2b** : `generateGalleries` sans graine dans l'original. Le baker et le jeu passent la graine explicitement.

---

### Étape 2 — Monde statique en 3/4 · **L**

**Tâches :**

1. `core/projection.gd` : `project`, `ground_from_screen`, `nat`, avec le centre vertical à 0,45. `iso.gd` est supprimé, et ses tests réécrits contre les fixtures.
2. Caméra : départ (0, −148), `clampCam`, même ergonomie.
3. `Terrain` : 16 blocs du sol initial, sur des `ImageTexture` modifiables (même si l'étape ne les modifie pas encore).
4. `DecorLoader` v2 :
   - tri `y = 8·d` ;
   - falaises et blocs avec leur `dz` ;
   - stalagmites et cristaux (avec l'indicateur de lumière) ;
   - décorations divines ;
   - autel ;
   - orbe éteinte (shader de grisé).
5. Vent quantifié dans `wind_foliage.gdshader` : `n = round(shear·ay·3)`, cisaillement `n/(3·ay)`.

**Validation :**

- [ ] Fonctionnel : `test_projection.gd` (fixtures, aller-retour sur 1000 points) et `test_camera.gd` adapté.
- [ ] Visuel : salle de départ (PX 1, 2, 3), couloir et jungle sud. Au moins 98 %, avec arcs, portails, unités, textes et tourelles désactivés dans la référence.
- [ ] Visuel : vent à t = 7,3, au moins 98 % (la quantification doit coïncider).
- [ ] Performance : au moins 60 im/s à PX = 1 dans la jungle, la zone la plus dense.

---

### Étape 3 — Terrain dynamique : galeries, creusement, praticabilité · **XL** — *risque principal*

**Tâches :**

1. `cave_shape.gd` : `mountainEdge`, `caveW/E/N/S`, `inCave`, `inTunnel`, `inPath`, `walkable`, `pushOutOfRock`, `intoCave`.
2. `galleries.gd` : port **exact** de `generateGalleries` (vers, salles, embranchements, composantes, choix des portails) et de `revealGallery`.
3. `dig.gd` : `DUG`, `diggableCell`, `digCellAt`, `digCell`, `nextDig`.
4. `terrain_painter.gd` : peinture des cases creusées et des régions révélées (§4.4), et mise à jour du décor (retrait des éboulis, ajout des falaises, cristaux et portails maléfiques).
5. `pathfinding.gd` : grille de 2 unités, cache invalidé, **A\* identique** (heuristique octile, pas de diagonale entre deux murs, budget de 60 000), lissage par ligne de vue, `steer`.
6. Minicarte (fond régénéré à chaque révélation) : version minimale ici, complétée à l'étape 6.

**Validation :**

- [ ] Fonctionnel : `test_galleries.gd`. Pour 5 graines, le masque est **identique** au JS (SHA-1 du masque), ainsi que le nombre de réseaux et la position des portails.
- [ ] Fonctionnel : `test_walkable.gd`, 10 000 points comparés aux fixtures.
- [ ] Fonctionnel : `test_pathfinding.gd`. 30 chemins témoins donnent des points identiques au JS.
- [ ] Fonctionnel : `test_dig.gd`. Une série de 20 creusements scriptée produit le même `DUG` et révèle les mêmes galeries que le JS.
- [ ] Visuel : capture après la série de creusements scriptée, au moins 98 % (zone creusée, bords, falaises, galerie révélée, portail maléfique sans animation).
- [ ] Performance : creuser une case en moins de 2 ms ; révéler la plus grande galerie des 5 graines en moins de 100 ms d'à-coup, en répartissant le travail si nécessaire.

**Risques** :

- **R24** : cases mixtes. Le masque `hol()` est évalué pixel par pixel : il faut porter exactement l'ordre des tests et les z-index locaux du `Px`.
- **R25** : coût de `ImageTexture.update()` sur un bloc de 1024² à chaque creusement. Mesuré à l'étape 3 ; repli : blocs de 256².

---

### Étape 4 — Ambiance : vent, Ancre, portails, éclairage · **L**

**Tâches :**

1. Arcs de l'Ancre (port de `drawOrbArcs`), états éteint, en réactivation (crépitement selon la progression) et actif ; flottement de l'orbe (`orbY`).
2. Portail des Exilés : atlas, cisaillement, séquence relançable (`openPortal`).
3. Portails divins : images éteintes ou actives, `deityFx` par dieu.
4. Portails maléfiques : images et braises.
5. Éclairage : `collectLights` porté, shader (ambiance, dégradé 0 / 0,45 / 1, scintillement, vignette), calcul au 1/4 de résolution imité par le flou du dégradé.

**Validation :**

- [ ] Fonctionnel : `windAt` et `vnoise` restent conformes (déjà testés).
- [ ] Visuel :
  - Ancre aux temps t = 0,5, 1,3 et 2,7 (active) ;
  - portail aux images 120 et 300 ;
  - portail d'Indra actif ;
  - tous au moins à 95 %.
- [ ] Visuel : éclairage sur la salle avec 5 sources, au moins 95 % à ±10. Le flou du calque au quart de la résolution est un écart attendu, documenté.

---

### Étape 5 — Ingénieur, sélection, ordres, introduction, Ancre · **L**

**Tâches :**

1. Modèle d'unité (PV, niveau, expérience, posture, tâches `job`, `buildJob`, `orbJob`, `forceMove`).
2. `move` avec glissement le long des murs et `pushOutOfRock` ; `steer` pour toutes les cibles.
3. Sprite du nouvel Ingénieur (repos 24, marche 12, rebond propre) et agenouillement.
4. Sélection : clic, Maj+clic, cadre, Ancre, bâtiment.
5. Clic droit avec ses priorités (§2.5) ; `issueMove` ; `M`, `H`, `A`, `1`–`9`, `Échap`.
6. Introduction : portail, sortie à 3 s, déplacement, événement `engineer_greeted`.
7. Réactivation de l'Ancre (8 s), revenus de +1/s par ressource, éveil des tourelles, premier assaut programmé à +20 s.

**Validation :**

- [ ] Fonctionnel : `test_movement.gd` (glissement, `pushOutOfRock`, vitesse 15,2) et `test_orb.gd` (8 s, revenus de 4×1/s, tourelles éveillées, `nextWave` = t + 20).
- [ ] Fonctionnel : `test_selection.gd`, cadre de sélection et priorités du clic droit sur des scénarios scriptés.
- [ ] En jeu, via le toolset `input` du MCP : sélection, clic droit sur l'orbe, attente de 8 s, puis `RES` à environ 1/s.
- [ ] Visuel : Ingénieur au repos, en marche et agenouillé, identique aux planches.

---

### Étape 6 — HUD v2 et dialogue · **L**

**Tâches :**

1. Thème (charbon et laiton, police libre D7), 18 icônes SVG.
2. Bandeau du haut avec les 4 ressources et la population.
3. Panneau d'actions **dynamique** : port de `panelActions`, `hudKey` et `renderActions`, avec `disabled`, `active`, recharge et infobulles.
4. Portrait, identité, statuts (`unitStatus`, `buildingStatus`, `adeptStatus`), détails et lore.
5. Minicarte : fond, révélations, points, trapèze de vue, navigation.
6. Notice, bannière (3 textes de fin), dialogue d'accueil (texte de `73b410f`).

**Validation :**

- [ ] Fonctionnel : `test_hud_actions.gd`. Pour 10 contextes (Ingénieur, menu de construction, Ancre éteinte ou active, temple, caserne, Puits des Âmes avec 3 unités tombées, adepte, héros, fin de partie), les listes d'actions (`id`, `key`, `disabled`, `active`) sont **identiques** à celles du JS, extraites en fixtures.
- [ ] Fonctionnel : `test_dialogue.gd`.
- [ ] Visuel : HUD comparé à la capture HTML de `73b410f` (revue humaine : proportions, couleurs, hiérarchie).

---

### Étape 7 — Économie et bâtiments · **XL**

**Tâches :**

1. Catalogue des 10 bâtiments (`.tres`), coûts, déblocages, tailles 2 et 3.
2. Placement : `snapFor`, `buildableGround`, `validSite`, grille et cellules de construction (`drawBuildGrid`, `drawBuildCells`), aperçu.
3. Chantier : paiement, `workSpot`, progression, **annulation remboursée**, `cancelWork`.
4. **Incantation** : port de `TempleIncantation.drawSite` (pierres du sprite, éboulis, arcs), miroir et bulle de vers (`drawTempleOverlays`).
5. Temples : invocation d'adepte (50), portail divin actif 3,5 s, prière (+1/s, popups +5), `prayerSpot`.
6. Caserne : file de 5, 100 Discipline, 6 s, sortie des combattants.
7. Puits des Âmes : unités tombées (`FALLEN`), réanimation (200 Vie, niveau conservé).
8. Héros Tireur : 100 de chaque ressource, sortie par le portail central.

**Validation :**

- [ ] Fonctionnel : `test_construction.gd` (paiement, remboursement, durée, Ingénieur requis sur place, déblocages en chaîne).
- [ ] Fonctionnel : `test_site.gd` (60 points témoins de `validSite` × 3 tailles, identiques au JS).
- [ ] Fonctionnel : `test_prayer.gd` (N adeptes donnent N/s ; popup toutes les 5 s) ; `test_caserne.gd` ; `test_soulwell.gd`.
- [ ] Visuel : 10 bâtiments achevés, au moins 98 % ; incantation à 25, 50 et 75 % (Temple de Sigil), au moins 95 %.

---

### Étape 8 — Combat, ennemis, vagues, expérience, tourelles · **L**

**Tâches :**

1. Table `FIGHT` et `barracksStrike` : Ingénieur (rivet), lance-flammes (zone et sillon), archer (charge et mêlée), épée et bouclier (garde et moulinet), adeptes en mêlée.
2. Expérience, niveaux, défense (`afterArmor`), badges ★.
3. Ennemis : chemins A\*, étourdissement, ralentissement, rejetons des portails maléfiques (cadence et plafond).
4. Vagues sans fin après l'Ancre ; pauses ; apparition au sud.
5. Tourelles (portée 70, dégâts 40, sans tir superflu sur un ennemi déjà condamné) et éveil.
6. Fin de partie : 3 conditions et 3 textes ; `Maj+R` réinitialise **tout** (nouvelle graine de galeries, `DUG`, sol repeint).
7. Effets : rivet, flèche, carreau, explosion, impacts, sillons de feu.

**Validation :**

- [ ] Fonctionnel : `test_fight.gd` (chaque rôle de `FIGHT`, valeurs exactes) et `test_xp.gd` (paliers 20, 32, 51…, +1/+1, plancher de 15 %).
- [ ] Fonctionnel : `test_waves.gd` (nombre, types, instants, attente des non-rejetons) et `test_evil_portals.gd` (7 s, plafond de 8).
- [ ] Fonctionnel : `test_defeat.gd` (3 conditions) et `test_restart.gd` (état initial complet).
- [ ] Partie scriptée accélérée de 5 vagues : aucune erreur, et journal d'événements stable sur 3 exécutions.

---

### Étape 9 — Héros et effets restants · **M**

Tireur (salve, tir de précision), Paladin et Soigneur (toujours désactivés dans `73b410f`, migrés derrière un drapeau), animations d'attaque, dernières vérifications au pixel des effets.

---

### Étape 10 — Parité, non-régression et procédure de resynchronisation · **M** — livrée, en attente du playtest

**Tâches :**

1. Partie scriptée complète, tests de fumée portés en scénarios MCP, rapport visuel global.
2. Revue des touches (D2) : `A` et `S` sont toujours partagés entre la caméra et le jeu, et le menu de construction utilise `E`, `G`, `V`, `I`, `L`, `F`, `T`, `N`, `U`, `C`.
3. **Procédure R (resynchronisation)** : `tools/resync.py <nouvelle_rev>` produit
   - les fichiers du jeu modifiés ;
   - les fonctions JS ajoutées, retirées ou modifiées ;
   - les sorties du baker qui changent ;
   - les références visuelles qui changent.

   Le rapport sert à décider, avec toi, des étapes à rouvrir.

**Validation :** tous les tests passent ; checklist de parité (une ligne par point du §2) cochée par l'utilisateur après un playtest de 15 minutes.

---

### Étape 11 — Sauvegarde (nouvelle fonctionnalité) · **M** — ❌ annulée (décision du 15/11/2026)

Sérialisation versionnée :
- graine des galeries et masque `open` ;
- `DUG` et coups en cours ;
- ressources, bâtiments (progression, file de la caserne), unités (niveau, expérience, tâches), unités tombées ;
- état de l'Ancre et des tourelles, ennemis, vague, temps.

Le sol est **repeint depuis l'état** au chargement : il n'est pas enregistré en image.

**Validation :** sauvegarde, chargement puis sauvegarde donnent un résultat identique à l'octet ; le journal d'événements est le même 30 s après un chargement ; un fichier corrompu est refusé proprement.

---

### Étape 12 — Export et performances · **M** — livrée (`EXPORT.md`)

- Templates d'export, presets Web (sans threads) et bureau, exclusion du baker et de la sonde MCP.
- Profilage dans le pire cas : jungle à PX = 1 avec éclairage, 3 galeries révélées, 40 ennemis, 15 adeptes.
- Planche de textures commune pour le décor (2195 appels de dessin mesurés en v1).

**Validation :** au moins 60 im/s sur le bureau et au moins 30 im/s en Web, sur une machine moyenne.

---

## 6. Synthèse de la complexité

| Étape | Contenu | Complexité | Dépend de |
|---|---|---|---|
| 0 | Socle | ✅ fait | — |
| 1 | Baker v2 (version figée) | L | 0 |
| 2 | Monde statique en 3/4 | L | 1 |
| 3 | Terrain dynamique, galeries, A\* | **XL** | 2 |
| 4 | Ambiance (Ancre, portails, éclairage) | L | 2 |
| 5 | Ingénieur, ordres, Ancre | L | 3 |
| 6 | HUD v2 et dialogue | L | 5 |
| 7 | Économie et bâtiments | **XL** | 5, 6 |
| 8 | Combat, vagues, expérience, tourelles | L | 5 (7 pour les adeptes combattants) |
| 9 | Héros et effets | M | 8 |
| 10 | Parité et resynchronisation | M | 4 à 9 |
| 11 | Sauvegarde (annulée) | — | — |
| 12 | Export et performances | M | 10 |

**Estimation** : environ 16 à 22 sessions de travail. Une fois l'étape 3 faite, l'étape 4 peut avancer en parallèle de l'étape 5.

**Difficultés principales :**
1. Terrain dynamique fidèle au pixel : peinture des cases mixtes, révélation des galeries.
2. A\* identique au JS : ordre du tas binaire, égalités et lissage.
3. Panneau d'actions contextuel et nombreux états.
4. Incantation de construction (animation procédurale riche).
5. Éclairage à coût maîtrisé en Web.
6. **Évolution continue du prototype**, maîtrisée par la version figée et la procédure R.

---

## 7. Registre des risques (v2)

| # | Risque | Probabilité | Impact | Parade |
|---|---|---|---|---|
| R0 | Le prototype évolue pendant la migration | **Certaine** | **Élevé** | Version figée `73b410f`, procédure R aux moments choisis |
| R2b | Galeries non déterministes dans l'original | Certaine | Moyen | Graine explicite, fixtures pour 5 graines |
| R5 | Performance (décor, éclairage, sol de 3808×3360) | Moyenne | Moyen | Planche de textures, `MultiMesh`, éclairage par shader |
| R9 | Pas fixe ≠ `dt` variable | Certaine | Faible | Tolérances d'un pas |
| R14 | Ordre de mise à jour | Moyenne | **Élevé** | `Simulation` centralisée, ordre d'`update()` |
| R24 | Peinture des cases mixtes | Moyenne | Moyen | Port ligne à ligne, tests au pixel |
| R25 | Mises à jour de textures au creusement | Moyenne | Moyen | Blocs plus petits, mises à jour groupées par image |
| R26 | Égalités de l'A\* (ordre du tas) | Moyenne | Moyen | Port exact du tas binaire, 30 chemins témoins |
| R27 | Éclairage au 1/4 lissé par CSS | Certaine | Faible | Dégradé équivalent, tolérance documentée |
| R11 | Police Georgia | Certaine | Faible | Police libre (D7) |
| R16 | Personnages vectoriels | Moins probable en v2 (adeptes en pixels) | Faible | Extraction native |
| R21 | Touches partagées (`A` seulement ; `S` ne sert qu'à la caméra) | Levé | — | D2 : Ctrl+A |
| R23 | Écriture accidentelle dans le prototype | Faible | **Élevé** | Lecture via `git show`, empreintes de `.git` vérifiées |

---

## 8. Décisions

| # | Question | Statut |
|---|---|---|
| D1 | Cible 2D | ✅ Confirmée (vue 3/4 et non plus isométrique : toujours 2D) |
| D2 | Touches partagées | ✅ Ctrl+A sélectionne tout ; A ne sert plus qu'à la caméra (seule touche partagée dans le prototype ; S ne l'était pas) |
| D3 | Abandon du mode non pixel et du modèle GLB | ✅ De fait : le prototype ne les charge plus |
| D4 | Graine fixe | ✅ Étendue aux galeries (graine explicite) |
| D5 | Visuel de la baliste | Celui du jeu (`pixel-buildings` v12 + `ballista-tyrienne-models`) |
| D6 | Sauvegarde | ❌ Non : étape 11 annulée, aucune sauvegarde (comme le prototype) |
| D7 | Police libre | Proposée à l’étape 6 : Noto Serif (OFL), repli DejaVu Sans pour ★ — à valider |
| D8 | Scène de test | ✅ Supprimée |
| D9 | Héros désactivés | ✅ Derrière un drapeau (`exiles/debug/heros_historiques`, étape 9) |
| **D10** | **Version de référence figée sur `73b410f`, resynchronisation sur demande** | **À valider** |
| **D11** | **Bâtiments sans effet (Bibliothèque, Forge, Atelier, Chambre) : migrés tels quels, sans effet** | **À valider** |
| **D12** | **Graine des galeries : aléatoire en jeu comme l'original, mais affichée (debug) et réutilisable** | **À valider** |
| D13 | Portées relevées après `73b410f` | ✅ Demandé : lance-flammes ×2 (portée 9, détection 18), archer ×4 (portée 56, détection 68) ; portée affichée dans le HUD à côté des dégâts (`Catalog.unit_reach`, test `test_enemy_selection`) |
| D14 | Sélection d'un ennemi | ✅ Demandé : clic gauche sur un ennemi → anneau rouge et fiche dans le HUD (nom, PV en rouge, dégâts, portée, armure, vitesse, portrait), sans ordres ; oubliée à sa mort (`Catalog.ENEMY_INFO`, test `test_enemy_selection`) |
| D15 | Lance-flammes | ✅ Demandé : portée 12, tir continu (20 dégâts/s au niveau 1 autour de la cible), plus de sillon de feu ni d'autre attaque ; explose à sa mort (45 dégâts, rayon 3) (`Combat.flame_tick`, `Combat.flame_explosion`, test `test_flamethrower`) |
| **D16** | **Charte graphique (prototype `direction-artistique.html`) : la référence figée devient `c1bbe75` = `73b410f` + la charte seule (branche `charte-graphique` du prototype). Portails divins aux couleurs des cultes (Medeina vert, Indra orange, Sigil blanc, Aether bleu-violet), Ancre noire aux reflets et éclairs pourpres, lumières par culte, adeptes recolorés, quatre temples redessinés (`da-sigil`, `da-aether`, `da-medeina`, `da-indra`). Report à la main : `Catalog.DEITY_GLOW` et `art` des temples, `PixelDraw.ORB_ARC`, `Lighting.ANCRE`/`CULT`, `World._building_lights`. Bâtiments secondaires : pistes A retenues sur `batiments-secondaires.html` (galerie des rouleaux, forge stellaire, atelier des instruments, hutte-cocon, puits du cycle, caserne palissadée), `art` = `da-<type>`.** | **✅ Validée (charte)** |

---

## 9. Règles d'exécution pour Claude Code

1. **Ne jamais écrire dans `/home/drums/code/exilesdefense`**, ni dans son dossier de travail, ni dans `.git`. Lire la version figée par `git show 73b410f:<chemin>` (ou `git cat-file`), qui est en lecture seule.
2. Avant chaque étape :
   - `godot_health_check`, `godot_list_toolsets`, `godot_enable_toolset(...)` ;
   - `godot_checkpoint_create` avant toute modification de scène.
3. Scripts via le toolset `scripts` (0 erreur d'analyse), scènes via `scene_edit` / `composite`, puis `godot_runtime_run_and_capture` (0 erreur).
4. Toute constante de gameplay vient de `data/*.tres`, avec sa référence source (`73b410f:<fichier>`).
5. Fin d'étape :
   - tests verts ;
   - captures dans `tests/visual/out/<étape>/` ;
   - commit `Étape N — <titre>` ;
   - compte rendu, avec **arrêt pour validation** aux étapes 1, 2, 3, 6, 7 et 10.
6. Si le prototype change, ne pas suivre en silence : signaler le nouveau commit et proposer la procédure R.
