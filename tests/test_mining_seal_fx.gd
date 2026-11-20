extends "res://tests/econ_case.gd"


func test_seal_visual_follows_equipment_and_body_visibility() -> void:
	var sim := game()
	var u := engineer()
	var view := UnitView.new()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))
	view.setup(u, manifest["units"]["roles"]["engineer"], sim)
	var fx = view._mining_seal
	fx.tick(1, Vector2.ZERO, true)
	check(not fx.visible, "pas de sphères avec la seule armure de minage")
	GameState.mining_seal = true
	fx.tick(-1, Vector2(0, -8), true)
	check(fx.visible, "sceau équipé rend les sphères visibles")
	check_eq(fx.scale, Vector2(-1, 1), "sillage suit l'orientation")
	check_eq(fx.position, Vector2(0, -8), "sillage suit la lévitation")
	fx.tick(1, Vector2.ZERO, false)
	check(not fx.visible, "sillage masqué pendant la formation du rappel")
	u.hp = 0
	fx.tick(1, Vector2.ZERO, true)
	check(not fx.visible, "pas de sphères sur un ingénieur mort")
	sim.new_game(SEED)
	view.unit = engineer()
	fx.tick(1, Vector2.ZERO, true)
	check(not fx.visible, "nouvelle partie retire le sceau visuel")
	view.free()
