extends SceneTree
## Sonde d’ablation (voir tests/perf/probe_run.gd).
## jouée avec un pas fixe Simulation.MAX_DT par image.
##   godot --path . -s res://tests/perf/bench.gd -- --mode=render --out=tests/perf/out/ref   # fenêtre, rendu réel
##   godot --headless --path . -s res://tests/perf/bench.gd -- --mode=sim --out=...           # simulation seule
## Options : --seconds=N (temps de simulation, 900 par défaut).
## Produit <out>_samples.csv (une ligne par seconde réelle) et <out>_summary.json (percentiles, profil de la
## simulation, pics mémoire, empreintes d'état toutes les 10 s de simulation). tests/perf/compare.py compare deux résumés.


func _initialize() -> void:
	# Logique chargée à l'exécution : les autoloads (GameState…) ne sont pas visibles à la compilation du script d'entrée.
	root.add_child.call_deferred(load("res://tests/perf/probe_run.gd").new())
