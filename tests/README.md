# tests/

Lancer tous les tests :

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

N'en lancer qu'une partie (fichiers dont le nom contient le motif) :

```bash
godot --headless --path . -s res://tests/run_tests.gd -- --only=full_game
```

Le lanceur découvre les fichiers `test_*.gd` (qui étendent `TestCase`), exécute chaque méthode `test_*`, affiche PASS/FAIL avec la durée, récapitule les échecs à la fin et se termine avec le code 1 en cas d'échec.

- **Plusieurs processus.** Les fichiers sont répartis en lots, un processus Godot par lot (par défaut la moitié des fils du processeur, en priorité basse pour laisser la machine utilisable). `-- --jobs=2` en change le nombre, `-- --jobs=1` joue tout dans un seul processus (sortie brute du moteur visible, pratique pour déboguer un test). Les lots sont équilibrés d'après les durées du dernier passage (`tests/.durations.json`, ignoré par git). `-- --verbose` recopie la sortie brute des lots.
- **Une seule scène de jeu par processus.** Les tests qui ont besoin du jeu passent par `TestCase.shared_main()` (ou `econ_case.gd` : `game()`), jamais par leur propre `main.tscn` : chaque instance pèse environ 500 Mo.
- **Erreurs de script.** Une erreur de script levée pendant un test (accès hors bornes, appel sur `null`…) le fait échouer, même si aucune assertion n'a parlé.
- **Références de terrain.** `dig_scenario.json`, `walkable.json`, `paths.json`, `minimap_*.png` et `sites.json` venaient du prototype JS ; la salle de départ et les galeries s'en sont écartées, ils servent maintenant de non-régression du jeu Godot. Après un changement voulu du terrain, de l'A* ou de la minicarte : `godot --headless --path . -s res://tests/run_tests.gd -- --rebaseline`, puis relire le diff. Relancer le baker sur ces fichiers les écraserait.
- Les valeurs d'équilibrage (dégâts, effectifs des vagues, menace) sont lues dans `Catalog` plutôt que recopiées dans les tests : un rééquilibrage ne casse pas la suite.

- `visual/` : références de captures, `capture.tscn`, `compare.py`, `report.py` (rapport visuel global `out/rapport_visuel.html`), démonstrations en jeu réel (`hud_interact`, `combat_demo`, `heroes_demo`) et `ECARTS.md` (écarts visuels assumés).
- `mcp/` : tests de fumée joués dans l'éditeur par le MCP Godot (`smoke_scenarios.json`, `RESULTATS.md`).
- Checklist de parité avec le prototype : `../PARITE.md`.
