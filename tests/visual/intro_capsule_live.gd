extends Node
## Nouvelle intro jouée pour de vrai (planches/intro-capsule-planche.html) : capsule éteinte, Ancre qui se recharge,
## trait, capsule allumée, sortie, invite du Coffre Antique, bannière des objets reçus, barres de PV avec Analyse.
## godot --path . res://tests/visual/intro_capsule_live.tscn
const OUT := "res://tests/visual/out/intro_capsule_live/"
const MAIN = preload("res://main/main.tscn")
const DT := 1.0 / 30.0

var _vp: SubViewport
var _sim: Simulation


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_sim.tick(DT)
	await get_tree().process_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	_sim = main.get_node("Simulation")
	var world: World = main.get_node("World")
	_sim.paused = true
	_sim.opening = true
	_sim.new_game(20261114)
	world.wind_scale = 0
	world.finish_painting()
	await _run(0.9)
	await _shot("1_capsule_eteinte")
	await _run(Opening.BOOT_WAKE - 0.9 + 0.5)
	await _shot("2_rallumage_coffre")
	await _run(Opening.RECHARGE_LEN * 0.5)
	await _shot("3_recharge")
	await _run(Opening.RECHARGE_LEN * 0.5 + 1.0)
	await _shot("4_trait")
	await _run(Opening.LINK_LEN)
	await _shot("5_capsule_allumee")
	Capsule.toggle(_sim)
	var eng := Capsule.engineer()
	await _run(0.3)
	await _shot("6_sortie")
	eng.x = CaveShape.CHEST_SPOT.x
	eng.z = CaveShape.CHEST_SPOT.y
	eng.tx = eng.x
	eng.tz = eng.z
	await _run(0.3)
	await _shot("7_invite_coffre")
	Capsule.toggle(_sim)
	await _run(1.0)
	await _shot("8_banniere")
	(main.get_node("Hud") as Hud).item_banner.close()
	# Ennemi posé près de l'Ingénieur : sans Analyse, pas de barre de PV ; avec, la barre s'affiche.
	var e := Enemy.make("scout", eng.x - 6.0, eng.z + 6.0, 0.0)
	e.hp *= 0.6
	GameState.enemies.append(e)
	await _run(0.2)
	await _shot("9_sans_analyse")
	eng.equipment["Module 1"] = "module_analyse"
	await _run(0.2)
	await _shot("10_avec_analyse")
	get_tree().quit()
