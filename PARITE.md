# Checklist de parité — version figée `73b410f` → Godot (étape 10)

Une ligne par point de l'inventaire fonctionnel (MIGRATION_PLAN.md §2). La colonne **Auto** dit ce qui le vérifie déjà :
- un test GDScript (`tests/test_*.gd`) ;
- un scénario visuel (`etapeN_*`, rapport `tests/visual/out/rapport_visuel.html`) ;
- un scénario MCP (`tests/mcp/`).

La case **Playtest** est à cocher par toi après une partie d'environ 15 minutes :

```bash
godot --path /home/drums/code/jeu-godot/jeu-godot
```

Pour comparer côte à côte, ouvre le prototype dans un navigateur (`Index.html` de `73b410f`).

Légende de la colonne Auto :
- ✅ : vérifié automatiquement contre le prototype (mêmes valeurs ou ≥ 98 % des pixels) ;
- ◐ : vérifié par un test Godot seul, sans comparaison au prototype.

## 2.1 Projection, caméra et rendu

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Projection 3/4 et coordonnées natives, `natP` arrondi | ✅ `test_projection`, `etape2_*` | Le monde a les mêmes proportions que le prototype. | [ ] |
| Tri de profondeur par z | ✅ `etape2_*`, `etape7_batiments_*` | Un personnage passe devant ou derrière un bâtiment au bon moment. | [ ] |
| Caméra : départ (0, −148), limites, ZQSD/WASD/flèches à 10 u/s, glisser droit (seuil 5 px), molette PX 1–6 | ✅ `test_camera`, `test_keys`, MCP `camera_clavier_et_molette` | Bords de carte, glisser droit, zoom de 1 à 6. | [ ] |
| Vent : cisaillement quantifié du feuillage | ✅ `etape2_vent_t7` (±20) | Le feuillage ondule comme dans le prototype. | [ ] |
| Mode non pixel et calque Three.js absents (D3) | ✅ `test_keys` (P sans effet) | — | [ ] |

## 2.2 Carte et terrain

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Monde, salle, couloir, flanc de la montagne, jungle | ✅ `etape2_salle_*`, `etape2_couloir_px2`, `etape2_montagne_px2`, `etape2_jungle_px2` | Promenade complète de la carte. | [ ] |
| `walkable` et `pushOutOfRock` | ✅ `test_terrain_state` ; invariant « personne dans la roche » de `test_full_game` | Aucune unité ne reste coincée dans la roche. | [ ] |
| Galeries : 12 à 16 vers, réseaux, un portail maléfique par réseau, invisibles jusqu'au creusement | ✅ `test_terrain_state` (5 graines) | Creuser vers une galerie : révélation, parois, cristaux, portail. | [ ] |
| Creusement : clic droit, case 4×4, 4 coups (1 case/s), enchaînement, sol repeint, falaise, chemins invalidés | ✅ `test_dig`, `etape3_creusement_*` ; ◐ `test_full_game` (94 cases au clic droit) | Creuser une dizaine de cases d'affilée. | [ ] |
| Sol initial : roche, grotte, herbe, sentier, ombres | ✅ `etape2_*` | — | [ ] |
| Décor : arbres, rochers, fougères, falaises, éboulis, stalagmites, cristaux, autel, orbe | ✅ `etape2_*`, `test_ambiance` | — | [ ] |
| 4 portails divins et portail des Exilés | ✅ `etape2_portails_px3`, `etape4_portail_*` | — | [ ] |

## 2.3 Ancre, portails et introduction

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Introduction : Ancre éteinte, Ingénieur sorti du portail à 3 s, accueil à (−13, core.z + 7) | ✅ `test_simulation`, `etape4_portail_*`, `test_dialogue` ; MCP `introduction_et_reactivation` | Ouverture de la partie et bulle d'accueil. | [ ] |
| Réactivation : clic droit, R ou bouton ; 8 s au point ; prière de l’Ingénieur à l’Ancre éveillée (+3 de chaque mana/s) ; balistes ; premier assaut à +20 s | ✅ `test_simulation`, `test_waves` ; ◐ `test_full_game` | Réactiver, regarder le compteur de ressources et le décompte de l'assaut. | [ ] |
| Arcs de l'Ancre et crépitement pendant la réactivation | ✅ `etape4_ancre_*` | — | [ ] |
| Portails divins actifs 3,5 s à chaque invocation, effets propres au dieu | ✅ `etape4_indra_actif`, `test_ambiance` | Invoquer un adepte de chaque dieu. | [ ] |
| Portails maléfiques : un rejeton toutes les 7 s, 8 vivants au plus | ✅ `test_evil_portals` | Laisser un portail maléfique ouvert une minute. | [ ] |

## 2.4 Économie et bâtiments

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| 10 bâtiments : coûts, déblocages, tailles, durées | ✅ `test_catalog`, `test_construction`, `etape7_batiments_a/b` | Construire chaque type. | [ ] |
| Placement : grille, `validSite`, distances minimales | ✅ `test_site` (180 cas) | Les cases libres et l'empreinte rouge ou verte sous le pointeur. | [ ] |
| Chantier : paiement, remboursement à l'annulation, `workSpot`, Incantation (pierres, agenouillement, miroir, vers) | ✅ `test_construction`, `etape7_incantation_*` | Poser puis annuler un chantier ; regarder une Énonciation complète. | [ ] |
| Invocation d'adepte (50) et prière (+1/s, popup « +5 » toutes les 5 s) | ✅ `test_prayer` ; ◐ `test_full_game` | Invoquer, voir l'adepte prier et le « +5 ». | [ ] |
| Caserne : 3 combattants, 100 Discipline, 6 s, file de 5 | ✅ `test_caserne` ; ◐ `test_full_game` (11 entraînés) | Remplir la file, regarder les sorties. | [ ] |
| Puits des Âmes : rappel pour coût initial × niveau en Vie, niveau conservé | ✅ `test_soulwell` | Faire tomber une unité, la rappeler. | [ ] |
| Héros Tireur depuis l'Ancre (100 de chaque) | ✅ `test_hud_actions`, `test_heroes` | Invoquer le Tireur, Espace pour le tir de précision. | [ ] |

## 2.5 Unités, combat et expérience

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Table des unités (PV, détection, portée, dégâts, recharge) | ✅ `test_fight` (table `FIGHT`), `test_heroes` | — | [ ] |
| Ingénieur : rivets | ✅ `test_fight`, `etape9_effets` | — | [ ] |
| Lance-flammes : zone et sillon de feu | ✅ `test_fight`, `etape9_effets` | — | [ ] |
| Archer : Charge du Lac, puis mêlée | ✅ `test_fight` (charge pas à pas) | — | [ ] |
| Épée et bouclier : 55 % des dégâts, moulinet | ✅ `test_fight` | — | [ ] |
| Tireur : salve de 3 carreaux, tir de précision | ✅ `test_heroes`, `etape9_attaques` | — | [ ] |
| Expérience : gains, paliers, +1/+1, plancher de 15 %, badge ★ | ✅ `test_xp` | Une unité passe au niveau 2 : badge et annonce. | [ ] |
| Déplacement : A\* à 8 directions, lissage, cache invalidé au creusement, glissement | ✅ `test_pathfinding`, `test_simulation` | Ordres de déplacement autour des obstacles. | [ ] |
| Sélection : clic, Maj+clic, cadre, bâtiment, orbe ; Ctrl+A (D2) ; 1–9 | ✅ `test_keys`, `hud_interact.tscn` | Toutes les façons de sélectionner. | [ ] |
| Clic droit : Ancre, tourelle, creuser ou prier, attaquer, se déplacer | ✅ `test_simulation`, `test_prayer`, `test_full_game` | Chaque cas de clic droit. | [ ] |

## 2.6 Ennemis et vagues

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Rampant, cracheur, brute, rejeton : statistiques, chemins | ✅ `test_waves`, `etape8_ennemis` | — | [ ] |
| Vagues : premier assaut à +20 s, sans fin, 4 + 3w ennemis, intervalles, apparition au sud, pause de 4 s | ✅ `test_waves` (6 vagues) ; ◐ `test_full_game` (8 vagues) | Tenir 5 vagues. | [ ] |
| Approche stratégique (écart voulu) : rassemblement, front et appui, réserve, débordement praticable, colonne et rupture après pertes ; composition et cadence conservées | ◐ `test_enemy_tactics`, `test_waves` | Cohésion, passage des goulets, réaction aux attaques et réserve de Strazhar. | [ ] |
| Balistes (±11, −71) : éveil avec l'Ancre, portée 70, 40 dégâts, cycle de 3,6 s | ✅ `test_fight`, `etape8_balistes_*` | Les balistes pivotent et tirent. | [ ] |
| Défaite : Ancre à 0, plus d'allié, Ingénieur tombé ; Maj+R | ✅ `test_defeat`, `test_restart` ; MCP `redemarrage` | Perdre une fois, Maj+R. | [ ] |

## 2.7 Éclairage

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Calque au quart de résolution, ambiance, sources (unités, bâtiments, balistes, Ancre, cristaux), vignette | ✅ `etape4_eclairage` (99,57 %) | L'ambiance sombre de la grotte, la lumière des balistes et des explosions. | [ ] |

## 2.8 HUD et dialogue

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Bandeau : vague et ressources | ✅ `test_hud_actions` (textes de 27 contextes) | — | [ ] |
| Panneau d'actions dynamique et ses touches | ✅ `test_hud_actions` (27 contextes), `test_keys` ; MCP `menu_de_construction` | Les boutons changent selon la sélection ; raccourcis clavier. | [ ] |
| Minicarte, portrait, statuts, notice, bannière | ✅ `test_minimap` (99,99 %), `hud_capture.tscn` | Cliquer sur la minicarte. | [ ] |
| Dialogue d'accueil relié à la tête de l'Ingénieur | ✅ `test_dialogue` | Entrée pour avancer, Échap pour fermer. | [ ] |

## 2.9 Animations et effets

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Sprites de repos et de marche ; nouvel Ingénieur ; agenouillement | ✅ `etape9_heros`, `etape7_incantation_*` | — | [ ] |
| Adeptes : repos, marche, travail à 6 im/s, ×1,9 | ✅ `etape7_*`, `test_baked_assets` | — | [ ] |
| Effets pixel par pixel : rivet, flèche, carreau, explosion, impacts, sillons, arcs, portails, braises | ✅ `etape9_effets`, `etape4_*` | Combat fourni : lisibilité des effets. | [ ] |
| Bâtiments : base et couche animée ; balistes en 3D isométrique | ✅ `etape7_batiments_*`, `etape8_balistes_*` | — | [ ] |

## 2.10–2.11

| Point | Auto | À regarder en jeu | Playtest |
|---|---|---|---|
| Sauvegarde : aucune, comme le prototype (étape 11 annulée, D6) | — | — | — |
| Tests du prototype : obsolètes, remplacés par les tests Godot | ✅ 98 tests GDScript, 29 scénarios visuels, 6 scénarios MCP | — | — |

## Robustesse (hors §2)

| Point | Auto | Playtest |
|---|---|---|
| Partie complète par les seules entrées du joueur (réactivation, 6 bâtiments, 8 adeptes, 11 combattants, creusement, galerie, 8 vagues, 122 ennemis), sans invariant violé et rejouée à l'identique | ◐ `test_full_game` | — |
| 400 entrées aléatoires sans erreur | ◐ MCP `fuzz` | — |
| Partie de 15 minutes sans erreur ni chute de fluidité | — | [ ] |

## Touches (D2) — décidé : Ctrl+A sélectionne

Table relevée dans le prototype (`Index.html:509-510`, `hud.js:34`), vérifiée par `test_keys.gd` :

| Touche | Rôle |
|---|---|
| Z/W, Q/A, S, D, flèches | Caméra, maintenue, 10 u/s. Avec la minicarte, les flèches font aussi un saut de 5. |
| **Ctrl+A** (Cmd+A) | **Sélectionne toutes les unités visibles. Écart voulu (D2) : dans le prototype, c'est A, qui déplace aussi la caméra. Ctrl maintenu bloque le défilement au clavier.** |
| 1–9 | Sélection par héros ou escouade (Maj : ajout) ; 1–3 servent d'abord au Puits des Âmes |
| B, E, G, V, I, L, F, T, N, U, C, R, H, M, Y, Espace | Panneau d'actions, selon le contexte |
| Échap | Annule le mode et le menu, ou ferme le dialogue |
| Entrée | Fait avancer le dialogue |
| Maj+R | Nouvelle partie |
| P | Sans effet (D3) |

Dans le prototype, la seule collision était **A**, qui sélectionnait tout et déplaçait aussi la caméra. S ne sert qu'à la caméra : aucune action du panneau ne l'utilise. Avec Ctrl+A, il n'y a plus aucun conflit, en AZERTY comme en QWERTY.
