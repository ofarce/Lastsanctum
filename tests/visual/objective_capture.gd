extends Node
## Captures du panneau d'objectif (ObjectivePanel) au fil des quêtes (Quests) : Ancre, La Salamandre (liste
## des quatre autels), Le Coffre Antique (trois étapes) puis Un mystérieux compagnon (« Bientôt ! »).
## L'état de la partie est forcé directement (simulation en pause) ; seul l'affichage est vérifié ici.
## Lancement (fenêtré : le rendu headless ne produit pas d'image) :
##   godot --path . res://tests/visual/objective_capture.tscn
## Images : tests/visual/out/objectif/objectif_<etat>.png (coin haut gauche, 460×320).

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/objectif/"

var _hud: Hud
var _viewport: SubViewport


func _ready() -> void:
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1440, 900)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var main := MAIN.instantiate()
	_viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	_hud = main.get_node("Hud")
	sim.paused = true
	world.camera.input_enabled = false
	world.finish_painting()
	var engineer: Unit = GameState.units.filter(func(u: Unit) -> bool: return u.role == "engineer")[0]
	await _wait(2.6)
	await _shot("01_ancre")
	GameState.orb_progress = Simulation.ORB_TIME * 0.55
	await _wait(0.4)
	await _shot("02_ancre_reactivation")
	GameState.orb_active = true
	await _wait(1.6)
	await _shot("03_ancre_accomplie")
	await _wait(3.0)
	engineer.unarmored = true
	await _wait(2.6)
	await _shot("04_salamandre")
	_temple("sigil")
	await _wait(2.4)
	await _shot("05_salamandre_sigil")
	_temple("sigil")
	_temple("indra")
	_temple("medeina")
	await _wait(0.5)
	_temple("aether")
	await _wait(1.8)
	await _shot("06_salamandre_accomplie")
	await _wait(3.0)
	await _shot("07_coffre_sceau")
	GameState.mining_seal = true
	await _wait(1.8)
	await _shot("08_coffre_sceau_fabrique")
	await _wait(4.0)
	await _shot("09_coffre_chemin")
	engineer.hidden = false  # simulation en pause : l'Ingénieur n'est pas encore sorti du portail
	engineer.x = (CaveShape.VAULT_X0 + CaveShape.VAULT_X1) / 2.0
	engineer.z = (CaveShape.VAULT_Z0 + CaveShape.VAULT_Z1) / 2.0
	await _wait(5.5)
	await _shot("10_coffre_ouvrir")
	GameState.base_inventory_unlocked = true
	await _wait(1.8)
	await _shot("11_coffre_accompli")
	await _wait(5.0)
	await _shot("12_compagnon_bientot")
	print("quete finale : %s, panneau : %s" % [_hud.quests.quest, _hud.objective.shown_id()])
	get_tree().quit()


## Temple achevé, hors carte : seule la quête le lit.
func _temple(deity: String) -> void:
	var b := Building.create(9000 + GameState.buildings.size(), deity, -999.0, -999.0)
	b.complete = true
	GameState.buildings.append(b)


## Le HUD ne se met à jour que si le temps de simulation avance : on le force à chaque image, et on fait
## avancer le temps de simulation (sans simuler) pour les répliques d'autel minutées.
func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + seconds * 1000.0
	while Time.get_ticks_msec() < end:
		GameState.sim_time += get_process_delta_time()
		_hud.dialogue.close()
		_hud.hide_notice()
		_hud.refresh()
		await get_tree().process_frame


func _shot(name: String) -> void:
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image().get_region(Rect2i(0, 0, 460, 320))
	img.save_png(ProjectSettings.globalize_path(OUT + "objectif_%s.png" % name))
	print("capture objectif_%s (%s, %s)" % [name, _hud.objective.shown_id(), _hud.objective.phase()])
