extends Node
## Ramassage réel d'un mod (simulation en marche) : corps qui porte une Lentille au pied de l'Exilé, puis
## suivi de l'écrin image par image (file, combat, calme, affichage).
## godot --path . res://tests/visual/mod_reveal_live.tscn
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var hud: Hud = main.get_node("Hud")
	GameState.sim_time = 30.0
	GameState.opening_stage = ""
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	eng.x = -8.0
	eng.z = -150.0
	GameState.incarnated = eng
	var e := Enemy.make("creep", eng.x + 0.3, eng.z, 1.0)
	e.hp = 0.0
	e.died_at = GameState.sim_time
	e.loot = ["module_lens"]
	GameState.enemy_corpses.append(e)
	var mr: ModReveal = hud.mod_reveal
	print("opening_stage=", GameState.opening_stage, " cinematic=", Opening.cinematic(), " paused=", sim.paused)
	for i in 40:
		await get_tree().create_timer(0.1).timeout
		if i % 4 == 0:
			print("t=%.1f queue=%s current=%s combat=%s busy=%s calm=%.2f vis=%s size=%s inv=%s" % [i * 0.1, mr.queue, mr.current,
				ModReveal.in_combat(), mr.busy.call(), mr._calm, mr.visible, mr.size, eng.inventory.size()])
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/visual/out/mod_reveal/live_lentille.png"))
	# Bouton de debug « Donner les mods » : ne passe pas par le ramassage, l'écrin doit les relever quand même.
	hud._give_mods()
	await get_tree().create_timer(0.5).timeout
	print("APRES_DEBUG queue=%d current=%s" % [mr.queue.size(), mr.current.get("item", "")])
	get_tree().quit()
