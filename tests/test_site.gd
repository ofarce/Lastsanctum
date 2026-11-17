extends "res://tests/econ_case.gd"
## Étape 7 (v2) : snapFor et workSpot identiques au prototype sur 60 points témoins × 3 types (temple, chambre,
## caserne : tous en 2 × 2, la chambre du prototype sert de référence), avec un temple déjà construit et l'Ingénieur dans la salle. Référence :
## assets/baked/hud/sites.json (tools/baker/hud.js).
## Écart voulu : tout sol praticable est constructible (allées et galeries comprises) et l'écart entre
## bâtiments a changé (test_requested_changes) ; buildableGround et validSite ne suivent donc plus le prototype,
## on vérifie leur cohérence avec la praticabilité.


func test_sites_match_js() -> void:
	var sim := game()
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/hud/sites.json"))
	var e := engineer()
	e.x = f["engineer"][0]
	e.z = f["engineer"][1]
	for b: Dictionary in f["buildings"]:
		built(b["type"], b["x"], b["z"])
	var ok := 0
	for r: Dictionary in f["points"]:
		var p := Vector2(r["p"][0], r["p"][1])
		check_eq(sim.buildable_ground(p.x, p.y), sim.state().walkable(p.x, p.y), "buildableGround%s = praticable" % p)
		for t: String in ["sigil", "bedroom", "caserne"]:
			# Tous les bâtiments sont en 2 × 2 (planche batiments-2x2) : la chambre 2 × 2 du prototype sert de
			# référence aux types qui y étaient en 3 × 3.
			var want: Dictionary = r["bedroom" if int(Catalog.BUILDINGS[t]["size"]) == 2 else t]
			var q := Simulation.snap_for(t, p)
			check_eq(q, Vector2(want["snap"][0], want["snap"][1]), "snapFor(%s, %s)" % [t, p])
			if sim.valid_site(t, q):
				check(sim.buildable_ground(q.x, q.y), "validSite(%s, %s) : centre constructible" % [t, q])
			check_eq(sim.work_spot(t, q), Vector2(want["spot"][0], want["spot"][1]), "workSpot(%s, %s)" % [t, q])
			ok += 1
	check_eq(ok, 180, "180 cas comparés")


func test_snap_rounds_like_js() -> void:
	# Math.round(-2.5) = -2 (arrondi vers +∞), contrairement à roundf.
	check_eq(Simulation.snap_for("bedroom", Vector2(-10.0, -18.0)), Vector2(-8.0, -16.0), "côté pair : demi arrondi vers le haut")
	# Plus aucun bâtiment de côté impair (tous en 2 × 2) : le temple suit la règle du côté pair.
	check_eq(Simulation.snap_for("sigil", Vector2(-10.0, -18.0)), Vector2(-8.0, -16.0), "temple 2 × 2 : nœud de la grille")
