extends SceneTree
## Banc de mesure CPU / mémoire : la partie complète de tests/test_full_game.gd (graine fixe, joueur automatique)
## jouée avec un pas fixe Simulation.MAX_DT par image.
##   godot --path . -s res://tests/perf/bench.gd -- --mode=render --out=tests/perf/out/ref   # fenêtre, rendu réel
##   godot --headless --path . -s res://tests/perf/bench.gd -- --mode=sim --out=...           # simulation seule
## Options : --seconds=N (temps de simulation, 900 par défaut).
## Produit <out>_samples.csv (une ligne par seconde réelle) et <out>_summary.json (percentiles, profil de la
## simulation, pics mémoire, empreintes d'état toutes les 10 s de simulation). tests/perf/compare.py compare deux résumés.


func _initialize() -> void:
	# Logique chargée à l'exécution : les autoloads (GameState…) ne sont pas visibles à la compilation du script d'entrée.
	root.add_child.call_deferred(load("res://tests/perf/bench_run.gd").new())
