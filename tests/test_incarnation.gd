extends "res://tests/econ_case.gd"
## Galerie des Exilés et incarnation : seul l'Ingénieur est un Exilé ; Incarner / Désincarner.


func test_only_engineer_is_exile() -> void:
	var sim := game()
	var u := engineer()
	u.hidden = false
	sim.spawn("Tireur", 0.0, 0.0, "shooter")
	var exiles := ExileGallery.unlocked()
	check_eq(exiles.size(), 1, "un seul Exilé")
	check(exiles[0] == u, "l'Ingénieur")


func test_incarnate_and_release() -> void:
	var sim := game()
	var u := engineer()
	u.hidden = false
	GameState.hud_mode = "build"
	ExileGallery.incarnate(u)
	check(GameState.incarnated == u, "incarné")
	check_eq(GameState.hud_mode, "", "mode de construction annulé")
	ExileGallery.disincarnate()
	check(GameState.incarnated == null, "désincarné")
	ExileGallery.incarnate(u)
	sim.new_game(1)
	check(GameState.incarnated == null, "nouvelle partie : désincarné")
