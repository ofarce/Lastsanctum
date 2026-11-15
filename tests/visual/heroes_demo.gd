extends Node
## Démonstration des héros en jeu réel (étape 9), fenêtrée : drapeau D9 activé, Paladin, Soigneur et Tireur
## à leurs positions d'origine, face à une vague de rampants et d'une brute ; Tir de précision du Tireur à la
## touche Espace (bouton Compétence du HUD), Égide du Paladin et Restauration du Soigneur par ability().
## Lancement : godot --path . res://tests/visual/heroes_demo.tscn
## Captures : tests/visual/out/etape9/demo_<n>.png ; bilan et vérifications sur la sortie standard.

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/etape9/"

var failures := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Simulation.legacy_heroes = true
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var hud: Hud = main.get_node("Hud")
	sim.new_game(20261114)
	Simulation.legacy_heroes = false
	var pal: Unit = GameState.units[0]
	var heal: Unit = GameState.units[1]
	var sho: Unit = GameState.units[2]
	_check(GameState.selected == [pal], "Paladin sélectionné au départ")
	GameState.next_wave = 1e9
	for i in 7:
		var kind := "brute" if i == 3 else "creep"
		sim.combat.spawn_enemy({"x": -6.0 + i * 2.0, "kind": kind})
		var e: Enemy = GameState.enemies[-1]
		e.z = 28.0 + (i % 2) * 2.0
	world.camera.set_view(Vector2(0, 18), 2)
	await _wait(1.6)
	await _shot(0)
	# Tireur : bouton Compétence (Espace).
	GameState.selected = [sho]
	await _wait(0.1)
	var before: float = GameState.enemies.reduce(func(a: float, e: Enemy) -> float: return a + e.hp, 0.0)
	_key(KEY_SPACE)
	await _wait(0.05)
	_check(sho.ability > 9.0, "Espace : Tir de précision (recharge %.1f s)" % sho.ability)
	_check(GameState.enemies.reduce(func(a: float, e: Enemy) -> float: return a + e.hp, 0.0) < before, "Tir de précision : dégâts")
	await _shot(1)
	# Paladin : Égide ; Soigneur : Restauration (pas de bouton dans le prototype : ability()).
	await _wait(0.8)
	GameState.selected = [pal]
	sim.ability()
	_check(pal.ability > 15.0 and pal.shield > 6.0, "Égide : boucliers")
	await _wait(0.15)
	await _shot(2)
	GameState.selected = [heal]
	pal.hp = 60.0
	sim.ability()
	_check(pal.hp >= 115.0, "Restauration : +55 PV au Paladin (%d)" % pal.hp)
	await _wait(0.2)
	await _shot(3)
	await _wait(3.0)
	await _shot(4)
	var lv := GameState.units.filter(func(u: Unit) -> bool: return not u.hidden).map(func(u: Unit) -> String:
		return "%s niv.%d %d PV" % [u.role, Catalog.lvl(u), int(u.hp)])
	print("ennemis restants %d ; %s" % [GameState.enemies.filter(func(e: Enemy) -> bool: return e.hp > 0.0).size(), ", ".join(lv)])
	print("%s : %d échec(s)" % ["OK" if failures == 0 else "ÉCHEC", failures])
	get_tree().quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "ÉCHEC ") + what)
	if not ok:
		failures += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.key_label = k
		e.physical_keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)


func _shot(n: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "demo_%d.png" % n))
