extends "res://tests/econ_case.gd"


func test_armed_engineer_left_click_selects_without_attacking() -> void:
	var sim := game()
	GameState.opening_stage = ""
	var u := engineer()
	u.unarmored = true
	u.equipment["Main droite"] = "iron_sword"
	u.attack = 0.0
	GameState.selected = [u]
	var enemy := Enemy.make("brute", u.x + 10.0, u.z, 1.0)
	GameState.enemies.append(enemy)
	sim.world.fog.refresh(sim.state())
	var input: InputController = _main.get_node("Input")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = input.project(enemy.x, 1.0, enemy.z)
	var health := enemy.hp
	input._unhandled_input(click)
	check(GameState.hud_enemy == enemy, "clic gauche sélectionne l'ennemi")
	check(GameState.selected.is_empty(), "l'Ingénieur est désélectionné")
	check_eq(u.attack, 0.0, "aucune attaque déclenchée")
	check_eq(enemy.hp, health, "aucun dégât")
	check(input._box_on, "sélection par glisser disponible")
	click.pressed = false
	input._unhandled_input(click)
	check(not input._box_on, "relâchement termine la sélection")
	GameState.selected = [u]
	click.button_index = MOUSE_BUTTON_RIGHT
	var destination := Vector2(-25.0, -120.0)
	click.position = input.project(destination.x, 0.0, destination.y)
	input._unhandled_input(click)
	check_eq(u.attack, 0.0, "clic droit hors incarnation : aucune frappe directe")
	check(Vector2(u.tx, u.tz).distance_to(destination) < 1.0, "clic droit donne un ordre de déplacement")
