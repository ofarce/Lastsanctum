extends "res://tests/test_case.gd"
## Étape 2 (v2) : la projection 3/4 correspond au prototype (fixtures du baker, 73b410f).

const Fixtures := preload("res://tests/fixtures.gd")
## Les Vector2 de Godot sont en float32 (le JS calcule en double) : écart attendu ~1e-4.
const EPS := 2e-3


func test_project_matches_js() -> void:
	var f := Fixtures.load_json("projection")
	var screen := Vector2(f["screen"][0], f["screen"][1])
	var cam := Vector2(f["cam"]["x"], f["cam"]["z"])
	var px := int(f["px"])
	check_eq(f["points"].size(), 20, "nombre de points témoins")
	for p: Dictionary in f["points"]:
		var nat := Proj.nat(p["x"], p["y"], p["z"])
		check_near(nat.x, p["natW"][0], EPS, "natW.x")
		check_near(nat.y, p["natW"][1], EPS, "natW.y")
		var s := Proj.project(p["x"], p["y"], p["z"], cam, px, screen)
		check_near(s.x, p["project"][0], EPS, "project.x")
		check_near(s.y, p["project"][1], EPS, "project.y")
		var g := Proj.ground_from_screen(s + Vector2(0, p["y"] * Proj.KH * px), cam, px, screen)
		check_near(g.x, p["ground_from_screen"][0], EPS, "ground.x")
		check_near(g.y, p["ground_from_screen"][1], EPS, "ground.z")


func test_roundtrip_1000_points() -> void:
	var r := Rng.new(99)
	var screen := Vector2(1440, 900)
	var worst := 0.0
	for i in 1000:
		var x := (r.next() - 0.5) * 460.0
		var z := -336.0 + r.next() * 408.0
		var cam := Vector2((r.next() - 0.5) * 404.0, -316.0 + r.next() * 360.0)
		var px := 1 + int(r.next() * 6.0)
		var g := Proj.ground_from_screen(Proj.project(x, 0, z, cam, px, screen), cam, px, screen)
		worst = maxf(worst, maxf(absf(g.x - x), absf(g.y - z)))
	check(worst < 1e-3, "écart maximal aller-retour %s" % worst)


func test_initial_px() -> void:
	check_eq(Proj.initial_px(1440), 2, "1440 px")
	check_eq(Proj.initial_px(1920), 3, "1920 px")
	check_eq(Proj.initial_px(2560), 4, "2560 px")
