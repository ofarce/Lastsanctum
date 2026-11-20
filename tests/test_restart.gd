extends "res://tests/fight_case.gd"
## Étape 8 (v2) : Maj+R (init) remet tout à l'état initial : nouvelle graine de galeries, cases creusées,
## bâtiments, ennemis, effets, balistes, ressources, vague.


func test_restart_resets_everything() -> void:
	var sim := game()
	var world: World = _main.get_node("World")
	var seed0 := world.gallery_seed
	var st := sim.state()
	var cell: Variant = st.diggable_cell(Vector2(64.0, -138.0))
	world.dig_cell(cell["i"], cell["j"])
	built("sigil", -26.0, -118.0)
	GameState.orb_active = true
	sim.combat.activate_turrets()
	GameState.wave = 3
	GameState.enemies.append(Enemy.make("creep", 0.0, 50.0, 1.0))
	sim.combat.flash(0.0, 0.0, Color.WHITE)
	GameState.fire_walls.append({"until": 1e9})
	GameState.res["forge"] = 99.0
	GameState.core_hp = 10.0
	GameState.ended = true
	var input: InputController = _main.get_node("Input")
	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.key_label = KEY_R
	ev.shift_pressed = true
	ev.pressed = true
	input._key(ev)
	check(world.gallery_seed != seed0, "nouvelle graine de galeries")
	check(sim.state().dug.is_empty(), "aucune case creusée")
	check(GameState.buildings.is_empty() and GameState.enemies.is_empty() and GameState.effects.is_empty() and GameState.fire_walls.is_empty(), "monde vidé")
	check(GameState.turrets.is_empty(), "aucune baliste")
	check(not GameState.orb_active and GameState.wave == 0 and GameState.core_hp == 1.0 and not GameState.ended, "Ancre, vague, intégrité, fin")
	check_eq(GameState.res["forge"], 0.0, "ressources à zéro")
	check_eq(GameState.units.size(), 1, "seul l'Ingénieur")
	check(GameState.units[0].hidden, "derrière le portail")
	var hud: Hud = _main.get_node("Hud")
	check(not hud._banner.visible, "bannière masquée")
