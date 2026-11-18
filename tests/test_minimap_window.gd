extends "res://tests/econ_case.gd"
## Monde procédural, étape 5 : fenêtre de minicarte qui suit la caméra ; menace des portails par biome.


func test_window_follows_camera_within_map() -> void:
	var start := Minimap.start_window()
	check_eq(Minimap.window_for(Vector2(0, -150)), start, "base : zone d'origine (dessin du prototype)")
	check_eq(Minimap.window_for(Vector2(60, -200)), start, "petits déplacements : fenêtre fixe")
	var w := Minimap.window_for(Vector2(-400, -600))
	check_eq(w.size, start.size, "même taille")
	check(w.position.x >= CaveShape.WORLD_X0 and w.end.x <= CaveShape.WORLD_X1 and w.position.y >= CaveShape.WORLD_Z0 and w.end.y <= CaveShape.WORLD_Z1, "bornée à la carte")
	check(w.has_point(Vector2(-400, -600)), "contient la caméra")


func test_minimap_redraws_far_window() -> void:
	var sim := game()
	var map: Minimap = _main.get_node("Hud").minimap
	sim.world.camera.set_view(Vector2(-380, -560), 3)
	var t0 := Time.get_ticks_usec()
	map.refresh()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("     (minicarte, nouvelle fenêtre : %.1f ms)" % ms)
	check(Minimap.win != Minimap.start_window(), "fenêtre déplacée")
	check(Minimap.win.has_point(Vector2(-380, -560)), "caméra dans la fenêtre")
	map.background().save_png(ProjectSettings.globalize_path("user://minimap_far.png"))
	sim.world.camera.set_view(Vector2(-380, -150), 3)
	map.refresh()
	map.background().save_png(ProjectSettings.globalize_path("user://minimap_west.png"))
	sim.world.camera.set_view(Vector2(0, -150), 3)
	map.refresh()
	check_eq(Minimap.win, Minimap.start_window(), "retour à la zone d'origine")


func test_portal_threat_raises_spawn_tier() -> void:
	check_eq(Biomes.threat_tiers(1), 0, "Temple : menace courante")
	check_eq(Biomes.threat_tiers(2), Biomes.THREAT_STEP, "biome 2 : paliers en plus")
	var sim := game()
	var st := sim.state()
	var deep: Dictionary = {}
	for p: Dictionary in st.portals:
		if p["threat"] == 2:
			deep = p
			break
	check(not deep.is_empty(), "un portail du biome 2")
	deep["active"] = true
	deep["next"] = 0.0
	GameState.menace = 0
	sim.combat.update_evil_portals()
	var spawned: Enemy = null
	for e: Enemy in GameState.enemies:
		if e.portal == deep:
			spawned = e
	check(spawned != null, "rejeton apparu")
	if spawned:
		var base := Catalog.menace_stats(0, true)
		var hard := Catalog.menace_stats(Biomes.THREAT_STEP, true)
		check(hard["hp"] > base["hp"], "statistiques de palier plus élevées")
		check_eq(spawned.max_hp, Enemy.make("beast", 0, 0, 0.0, hard).max_hp, "rejeton au palier du biome 2")
