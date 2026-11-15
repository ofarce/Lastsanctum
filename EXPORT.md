# Export et performances (étape 12)

## Exporter

Double-cliquer sur **Lancer Exiles.desktop** à la racine du projet pour reconstruire le build Linux et le lancer. Si le gestionnaire de fichiers le demande, autoriser l'exécution du raccourci.

Depuis un terminal : `./lancer-jeu.sh`. Le script fonctionne depuis n'importe quel dossier et lance le jeu uniquement si l'export réussit. Le journal d'export est dans `build/export.log`.

Les modèles d'export officiels de Godot 4.7.2 sont installés dans `~/.local/share/godot/export_templates/4.7.2.stable/` (Linux, Windows, Web sans threads). Ils ont été vérifiés par l'empreinte SHA-512 de la publication officielle.

```bash
godot --headless --path . --export-release "Linux"     # build/linux/exiles.x86_64
godot --headless --path . --export-release "Windows"   # build/windows/exiles.exe
godot --headless --path . --export-release "Web"       # build/web/index.html
```

Le build Web se sert depuis un serveur HTTP, par exemple `python3 -m http.server 8765 --directory build/web`. Il n'utilise pas de threads, donc il ne demande pas d'en-têtes COOP ni COEP.

**Exclus des exports** (`export_presets.cfg`) :
- `tests/`, `tools/` (baker, resynchronisation) ;
- `addons/godot_mcp/` (sonde du MCP Godot) et `addons/exiles_export/` ;
- les données de référence (`assets/baked/fixtures/`, `combat.json`, `sites.json`, `hud_actions.json`, `hud_texts.json`, rapports du baker), les fichiers Markdown et `build/`.

L'autoload de la sonde MCP est retiré des réglages exportés par le greffon `addons/exiles_export`, puis rétabli après l'export. Il ne reste aucune trace de la sonde dans les paquets (vérifié).

## Banc d'essai

Le pire cas du plan : PX = 1 avec éclairage, 3 galeries révélées, 15 adeptes et combattants, 40 ennemis, tous invulnérables pour garder une charge constante. Il est mesuré sur trois vues : entrée de la grotte en combat, jungle, salle.

```bash
./build/linux/exiles.x86_64 -- --banc               # build exporté
godot --path . -- --banc --profil-sim               # depuis le projet, avec le coût de chaque phase de la simulation
```

Pour le Web, ouvrir `index.html?banc` ; les résultats s'affichent dans la console du navigateur (lignes `PERF`).

Options de diagnostic :
- `--frames=N`, `--vues=entree,jungle,salle` ;
- `--sans=sim,hud,minimap,overlay,lighting,world,fx,decor` : coupe des sous-systèmes, pour voir ce que chacun coûte ;
- `--textures`, `--compte`.

Pour mesurer le démarrage du premier combat (compilation des shaders) :

```bash
godot --path . res://tests/visual/combat_demo.tscn -- --chrono
```

## Résultats (15/11/2026)

Machine : Intel Core i7-10510U (portable, 4 cœurs), GPU intégré Intel UHD (Mesa), écran 1440×900.

| Vue (pire cas) | Avant l'étape 12 (éditeur) | Bureau, build exporté | Web, build exporté (Chromium, plafond 60 im/s) |
|---|---|---|---|
| Entrée de la grotte, combat | 34,5 im/s (p95 32 ms) | **80,8 im/s** (p95 15,4 ms) | **51,5 im/s** (p95 24,8 ms) |
| Jungle | 43,4 im/s | **83,4 im/s** (p95 15,1 ms) | **58,0 im/s** (p95 21,5 ms) |
| Salle | 48,0 im/s | **81,3 im/s** (p95 15,5 ms) | **52,1 im/s** (p95 25,1 ms) |

Objectifs du plan : au moins 60 im/s sur bureau et au moins 30 im/s en Web, sur une machine moyenne. Ils sont atteints sur cette machine, plutôt modeste.

| Poste | Avant | Après |
|---|---|---|
| Éclairage (GPU, entrée) | 21 ms | 5 ms |
| Appels de dessin (jungle) | 3 144 | 315 |
| Recherche de chemin A\* (300 chemins) | 3,1 s | 1,2 s (résultats identiques) |
| Premier tir (compilation des shaders) | arrêt de 316 ms en combat | absorbé au chargement |
