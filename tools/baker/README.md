# Baker — extraction des graphismes du prototype

Les graphismes du prototype (`/home/drums/code/exilesdefense`) sont **générés par du code JS** au lancement. Le baker exécute ce code **sans le modifier**, dans Firefox sans fenêtre, et enregistre les images en PNG avec leurs métadonnées JSON dans `res://assets/baked/`.

## Version figée

Par défaut, le prototype est lu **dans l'historique git**, au commit de référence de la migration (`REFERENCE_REV` dans `serve.py`, actuellement `73b410f`). La lecture passe par `git cat-file`, sans aucune écriture. Le dossier de travail du prototype peut donc évoluer pendant la migration sans changer les extractions.

`--rev WORKTREE` lit le dossier de travail à la place, ce qui sert à préparer une resynchronisation (procédure R du plan).

## Prérequis

- `python3` avec Pillow, qui rend les PNG identiques à l'octet près d'une exécution à l'autre ;
- `firefox` dans le `PATH` ;
- `git`.

## Commandes

Extraction complète, environ 55 s :

```bash
python3 tools/baker/serve.py
```

Captures de référence du jeu d'origine (validation visuelle), environ 30 s :

```bash
python3 tools/baker/serve.py --page reference.html --out tests/visual/reference
```

HUD du prototype (étapes 6 et 7) : listes d'actions et textes du HUD dans 27 contextes, emplacements de construction (`hud_contexts.json`), catalogue, portraits, minicarte, environ 30 s :

```bash
python3 tools/baker/serve.py --page hud.html --out assets/baked/hud
```

Captures du HUD du prototype pour la revue humaine : `hud_shot.html?ctx=<contexte>`, piloté par `tests/visual/hud_review.py`.

Options utiles :

- `--page 'bake.html?only=world,units'` limite l'extraction. Parties disponibles : `world`, `portals`, `units`, `adepts`, `buildings`, `overlay`, `fixtures`.
- `--rev <commit>` ou `--rev WORKTREE` choisit une autre version du prototype.
- `--no-browser` affiche l'URL au lieu de lancer Firefox, pour un débogage dans un navigateur visible.

Le code de sortie vaut 0 seulement si l'extraction est complète, sans erreur, et si le dépôt du prototype n'a pas changé pendant l'exécution.

## Garanties sur le prototype

`serve.py` compare un instantané du dépôt avant et après l'exécution :
- `HEAD` ;
- empreinte de `git for-each-ref` ;
- empreinte de `git status --porcelain` ;
- date de `.git/index`.

Toutes les commandes git passent par `--no-optional-locks`, qui empêche le rafraîchissement de l'index. Une différence fait échouer l'exécution : elle peut venir d'une modification que tu fais toi-même au même moment ; il suffit alors de relancer.

## Fonctionnement

1. `serve.py` sert le prototype (version figée) en **lecture seule** sous `/src/` et les fichiers du baker sous `/`. Il accepte `POST /out/<chemin>`, uniquement pour des `.png` et des `.json`, et seulement dans le dossier de sortie.
2. `lib.js` charge les scripts listés par `Index.html`, dans leur ordre, puis son script principal **arrêté juste avant l'amorçage** (`generateGalleries();buildPixelWorld();`). Il remplace `Math.random` par un générateur à graine fixe (19653).
3. `bake.js` génère les galeries avec `GALLERY_SEED` (20261114), appelle les fonctions d'origine et assemble les planches.
4. Chaque PNG est relu après encodage et comparé au canvas source : les pixels opaques doivent être identiques à l'octet près.
5. `serve.py` réencode les PNG de façon déterministe et écrit `bake_report.json` : version, empreinte, instantané du dépôt et SHA-1 de chaque fichier. Les fichiers `.import` de Godot sont conservés.

## Contenu de `assets/baked/`

| Dossier | Contenu |
|---|---|
| `world/ground/` | Sol initial de 3808×3360 en 16 blocs de 1024². L'origine du monde est au pixel (`gx0`, `gy0`) |
| `world/sprites/` + `decor_sprites.json` | Sprites uniques du décor : arbres (tronc et feuillage séparés), rochers, fougères, falaises, éboulis, stalagmites, cristaux, autel, orbe, décorations divines |
| `world/decor_placements.json` | Placements dans l'ordre de dessin d'origine, avec les objets spéciaux (portail des Exilés, 4 portails divins et leurs effets) |
| `world/runtime/` | Décor ajouté en cours de partie : 6 faces de falaise, 6 stalagmites de galerie |
| `world/tiles/` | Bases 32×32 du sol de grotte et de la roche, pour repeindre les cases creusées |
| `portals/` | Portail divin éteint, 4 portails divins actifs (12 images chacun), portail maléfique (12 images) |
| `units/`, `enemies/` | Repos, marche et tir ; nouvel Ingénieur (marche sur 12 images) et son agenouillement ; `beast` |
| `attacks/` | 5 coups d'épée, salve d'arbalète |
| `adepts/` | 7 rôles × repos (1 image), marche (2), travail (4) |
| `buildings/` | 10 sprites de bâtiment (base et boucle animée) ; baliste en ruine et active (16 orientations × 24 phases) |
| `overlay/` | Empreintes de chantier (×2), icônes SVG du HUD |
| `hud/` (page `hud.html`) | Actions et textes du HUD pour 27 contextes, emplacements de construction (`sites.json`, 60 points × 3 types), combat (`combat.json` : tables, frappes, charge, expérience, vagues, combats des héros sur 40 pas, compétences), catalogue et textes fixes, 24 portraits (`drawHUDPortrait`), fonds de minicarte avant et après creusement, arbres et tourelles de la minicarte |
| `fixtures/` | Valeurs de référence pour les tests : projection 3/4, vent, bruit, générateurs, galeries pour 5 graines, praticabilité, 30 chemins A\*, scénario de creusement |
| `manifest.json` | Métadonnées : constantes du monde, palettes, catalogue des bâtiments, table de combat, ancres, planches, boucles |
| `_contact_sheet.png` | Planche de contrôle pour la revue humaine |

L'atlas du portail des Exilés est **réutilisé tel quel** : il est copié dans `assets/imported/portal/portal_atlas.png`.

## Captures de référence

`reference.html` charge `Index.html` de la version figée dans une iframe, en mémoire (`srcdoc` avec la graine injectée), puis applique les scénarios de `reference_scenarios.json` :
- caméra, PX et temps de simulation ;
- galeries avec la graine de référence ;
- creusement scripté ;
- état de l'Ancre et du portail divin ;
- bâtiments, ennemis et balistes posés directement (étapes 7 et 8) ;
- héros posés directement, avec coup d'épée ou salve en cours, orientation, PV et sélection (`units`), effets à un âge donné (`effects`) et murs de feu (`fire_walls`) (étape 9) ;
- éléments désactivés selon l'étape.

Le calque d'éclairage, un canvas superposé en CSS dans l'original, est enregistré à part (`*_light.png`).

## Écarts connus

- **Boucles d'animation** : les animations des bâtiments ne sont pas exactement périodiques. `manifest.json` indique pour chaque boucle sa durée et le nombre de pixels qui diffèrent au raccord, ce qui chiffre sa qualité.
- **Empreintes de chantier** : elles sont tracées à la résolution écran, avec un flou lumineux. Elles seront probablement redessinées dans Godot ; la version extraite sert de référence.
- **Adeptes** : l'ombre vectorielle (ellipse) n'est pas extraite ; elle sera redessinée.

## Planche du décor (étape 12)

Après une extraction, `python3 tools/baker/decor_atlas.py` reconstruit `assets/baked/world/decor_atlas.png`, `decor_atlas.json` et `decor_atlas_meta.png`. C'est la planche commune des sprites du décor, avec les repères du feuillage. `test_baked_assets.gd` vérifie qu'elle correspond aux sprites.
