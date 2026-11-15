# tests/

Lancer tous les tests :

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

N'en lancer qu'une partie (fichiers dont le nom contient le motif) :

```bash
godot --headless --path . -s res://tests/run_tests.gd -- --only=full_game
```

Le lanceur découvre les fichiers `test_*.gd` (qui étendent `TestCase`), exécute chaque méthode `test_*`, affiche PASS/FAIL et se termine avec le code 1 en cas d'échec. `test_full_game.gd` joue une partie complète par les seules entrées du joueur (environ 1 min).

- `visual/` : références de captures, `capture.tscn`, `compare.py`, `report.py` (rapport visuel global `out/rapport_visuel.html`), démonstrations en jeu réel (`hud_interact`, `combat_demo`, `heroes_demo`) et `ECARTS.md` (écarts visuels assumés).
- `mcp/` : tests de fumée joués dans l'éditeur par le MCP Godot (`smoke_scenarios.json`, `RESULTATS.md`).
- Checklist de parité avec le prototype : `../PARITE.md`.
