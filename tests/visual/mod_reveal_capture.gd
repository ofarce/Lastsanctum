extends Node
## Grand écrin du premier ramassage d'un mod (ui/hud/mod_reveal.gd) : règles de la file (déjà vu, attente en
## combat, tri par rareté, coupure) puis captures de chaque étape.
## godot --path . res://tests/visual/mod_reveal_capture.tscn
const OUT := "res://tests/visual/out/mod_reveal/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK    " if ok else "ÉCHEC ") + what)
	if not ok:
		_fails += 1


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var hud: Hud = main.get_node("Hud")
	sim.paused = true
	GameState.sim_time = 30.0
	GameState.opening_stage = ""
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	eng.equipment["Main droite"] = "cannon"
	eng.equipment["Torse"] = "combinaison"
	eng.x = -8.0
	eng.z = -150.0
	world.camera.set_view(Vector2(eng.x, eng.z), 4)
	var mr: ModReveal = hud.mod_reveal
	mr.set_process(false)
	mr.busy = func() -> bool: return false
	await _shot("0_avant")

	# ---- Règles de la file
	var foe := Enemy.make("creep", eng.x + 3.0, eng.z, 1.0)
	GameState.enemies.append(foe)
	_check(ModReveal.in_combat(), "un ennemi à 3 unités : en combat")
	Loot.picked("module_magnet")
	Loot.picked("module_drill")
	Loot.picked("module_magnet")
	_check(mr.queue == ["module_magnet", "module_drill"], "déjà vu : l'Aimant ne revient pas en file %s" % [mr.queue])
	mr._process(3.0)
	_check(not mr.active(), "en combat : rien ne s'affiche")
	await _shot("1_combat_pastille")
	GameState.enemies.erase(foe)
	mr._process(1.0)
	_check(not mr.active(), "calme depuis 1 s : on attend encore")
	mr._process(0.6)
	_check(mr.active() and mr.current["item"] == "module_drill", "après 1,5 s : la Foreuse (unique) passe d'abord")
	# ---- Captures de chaque étape (Foreuse, unique : tenue 5 s)
	var hold := mr._hold()
	for st: Array in [["2_in_eclair", 0.3], ["3_in_onde", 0.6], ["4_in_soleil", 0.95], ["5_hold_range", ModReveal.IN + 0.3],
			["6_hold", ModReveal.IN + 1.6], ["7_out_pli", ModReveal.IN + hold + 0.15], ["8_out_point", ModReveal.IN + hold + 0.42],
			["9_out_etoile", ModReveal.IN + hold + 0.6]]:
		mr.current["t"] = st[1]
		mr.queue_redraw()
		mr._icon.queue_redraw()
		mr._fx.queue_redraw()
		await _shot(st[0])
	# ---- Coupure par un combat qui reprend
	mr.current["t"] = ModReveal.IN + 1.0
	GameState.enemies.append(foe)
	mr._process(0.01)
	_check(mr.current["t"] >= ModReveal.IN + hold and mr.queue.front() == "module_drill", "combat qui reprend : disparition jouée, Foreuse remise en file")
	mr._process(1.0)
	_check(not mr.active(), "fin de la disparition coupée")
	GameState.enemies.erase(foe)
	mr._process(1.6)
	mr._process(0.01)
	_check(mr.active() and mr.current["item"] == "module_drill", "la Foreuse repasse au calme")
	mr.current["t"] = ModReveal.IN + 1.6
	mr._process(0.0)
	# Aimant (peu commun) : soleil réduit, pas d'étincelles, tenue 3 s.
	mr.current = {"item": "module_magnet", "t": ModReveal.IN + 1.6}
	mr.queue_redraw(); mr._icon.queue_redraw(); mr._fx.queue_redraw()
	await _shot("10_hold_peu_commun")
	print("ÉCHECS=", _fails)
	get_tree().quit()
