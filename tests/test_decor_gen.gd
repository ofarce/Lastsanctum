extends "res://tests/econ_case.gd"
## Monde procédural, étape 4 : décor généré par chunk hors de la zone d'origine.


func test_chunks_deterministic_and_outside_start() -> void:
	var cr := DecorGen.chunk_range()
	var total := 0
	var kinds := {}
	for cz in range(cr.position.y, cr.end.y):
		for cx in range(cr.position.x, cr.end.x):
			var c := Vector2i(cx, cz)
			var a := DecorGen.chunk(7, c)
			if cx % 5 == 0:
				check_eq(a, DecorGen.chunk(7, c), "chunk %s reproductible" % c)
			for e in a:
				total += 1
				var x: float = e["x"]
				var z: float = e["z"]
				check(not CaveShape.in_start(x, z), "hors de la zone d'origine")
				check(x >= c.x * 32.0 and x < c.x * 32.0 + 32.0 and z >= c.y * 32.0 and z < c.y * 32.0 + 32.0, "dans son chunk")
				var s: String = e["s"]
				var kind := s.substr(0, s.rfind("_"))
				kinds[kind] = kinds.get(kind, 0) + 1
				if kind == "mountain_rock":
					check(z < CaveShape.mountain_edge(x), "rocher sur la montagne")
				elif kind.begins_with("tree"):
					check(z > CaveShape.mountain_edge(x) + 2.9 and e.has("wind"), "arbre dans la jungle, avec vent")
	print("     décor généré : %d objets %s" % [total, kinds])
	check(kinds.get("face", 0) > 100, "faces du flanc")
	check(kinds.get("mountain_rock", 0) > 4000 and kinds.get("tree_big", 0) > 1500, "densités du baker")
	check(DecorGen.chunk(7, Vector2i(0, -5)).is_empty(), "rien dans un chunk de la zone d'origine")
	check(DecorGen.chunk(7, Vector2i(-12, -20)) != DecorGen.chunk(8, Vector2i(-12, -20)), "dépend de la graine")


func test_streaming_creates_nodes_near_camera_and_respects_removals() -> void:
	var sim := game()
	var world: World = sim.world
	world.camera.set_view(Vector2(0, -150), 3)
	world.apply_view()
	check_eq(world.generated_decor_nodes(), 0, "aucun nœud généré au-dessus de la base")
	world.camera.set_view(Vector2(-400, -40), 3)
	world.apply_view()
	var n := world.generated_decor_nodes()
	check(n > 50, "nœuds créés près de la caméra (%d)" % n)
	# Retire le décor d'une zone puis revient : rien ne réapparaît.
	world.decor.remove_in_rect(-420.0, -60.0, -380.0, -20.0, func(e: Dictionary) -> bool: return not DecorRegistry.is_fixed(e))
	world.camera.set_view(Vector2(0, -150), 3)
	world.apply_view()
	check_eq(world.generated_decor_nodes(), 0, "nœuds libérés en s'éloignant")
	world.camera.set_view(Vector2(-400, -40), 3)
	world.apply_view()
	for c: Vector2i in world._gen_live:
		for e: Dictionary in world._gen_decor[c]:
			if e["x"] >= -420.0 and e["x"] < -380.0 and e["z"] >= -60.0 and e["z"] < -20.0 and not DecorRegistry.is_fixed(e):
				check(not e.has("node"), "objet retiré jamais recréé")
