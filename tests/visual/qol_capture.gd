extends Node
## Confort de jeu (2026-11-22) dans le vrai jeu : oisifs, vitesse ×2, alerte hors champ et ping, menu de pause,
## puis sauvegarde → partie modifiée → chargement, avec comparaison de l'état.
## godot --path . res://tests/visual/qol_capture.tscn
const MAIN = preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/qol/"

var _vp: SubViewport
var _fails := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Simulation.play_opening = false
	SaveGame.autosave = false
	_vp = SubViewport.new()
	_vp.size = Vector2i(1440, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var hud: Hud = main.get_node("Hud")
	var world: World = main.get_node("World")
	await _frames(5)
	GameState.sim_time = DayNight.at_hour(1, 10.0)
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.x = 0.0
	eng.z = -140.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.res["savoir"] = 120.0
	GameState.research_done["minimap"] = true
	# Bâtiment servi sans personnel au poste, et trois adeptes de culte désœuvrés.
	var lib := Building.create(GameState.buildings.size(), "library", -40.0, -125.0)
	lib.complete = true
	lib.progress = Catalog.BUILDINGS["library"]["time"]
	lib.finished_at = -10.0
	GameState.buildings.append(lib)
	for i in 3:
		var u := sim.spawn("Adepte de Medeina", -10.0 + 4.0 * i, -132.0, "medeina")
		u.tx = u.x
		u.tz = u.z
	GameState.selected = [eng]
	world.camera.set_view(Vector2(0, -135), world.camera.px)
	sim.speed = 2
	await _wait(3.0)
	_check(hud.idle_button.visible and hud.idle_button.adepts.size() == 3, "3 adeptes oisifs comptés (%d)" % hud.idle_button.adepts.size())
	_check(hud.idle_button.buildings.size() == 1, "1 bâtiment à l'arrêt (%d)" % hud.idle_button.buildings.size())
	_shot("1_oisifs_vitesse")
	# Adepte loin de la caméra, frappé : alerte, ping, retour à ×1.
	var far := sim.spawn("Adepte d’Aether", 60.0, 40.0, "aether")
	far.tx = far.x
	far.tz = far.z
	await _frames(3)
	far.hp -= 10.0
	await _frames(3)
	_check(sim.speed == 1, "alerte : vitesse revenue à ×1")
	_check(not hud.minimap.pings.is_empty(), "ping sur la minicarte")
	_check(hud._wave_alert.text.begins_with("Adepte d’Aether sous attaque"), "texte d'alerte : " + hud._wave_alert.text)
	await _wait(0.6)
	_shot("2_alerte_ping")
	_check(hud.jump_to_alert() and world.camera.cam.distance_to(Vector2(60, 40)) < 30.0, "Retour arrière : caméra sur l'alerte (%s)" % world.camera.cam)
	world.camera.set_view(Vector2(0, -135), world.camera.px)
	# Menu de pause.
	Events.pause_requested.emit()
	await _frames(4)
	_check(PauseMenu.open and sim.paused, "menu ouvert, jeu en pause")
	_shot("3_menu_pause")
	hud.pause_menu.close()
	_check(not sim.paused, "menu fermé, jeu repris")
	# Sauvegarde : quelques cases creusées, ressources, un ennemi, sélection et tâche qui pointe un bâtiment.
	var st := sim.state()
	var dug := 0
	for j in range(-44, -36):
		for i in range(24, 30):
			if not st.ground(i * 4.0 + 2.0, j * 4.0 + 2.0) and dug < 12:
				world.dig_cell(i, j)
				dug += 1
	var foe := Enemy.make("creep", 30.0, -100.0, 1.0)
	GameState.enemies.append(foe)
	var worker := sim.spawn("Adepte de Sigil", lib.x, lib.z + 4.0, "sigil")
	worker.job = {"type": "staff", "building": lib, "post": "worker", "step": "walk"}
	GameState.selected = [worker]
	GameState.wave = 4
	GameState.res["forge"] = 77.0
	await _frames(2)
	for p: Dictionary in st.portals:
		Pylons.zone(p)
	var noise_before := Pylons.local_noise(st.portals[0], float(st.portals[0]["x"]) + 3.0, float(st.portals[0]["z"])) if not st.portals.is_empty() else 0.0
	var before := _state(sim)
	var gs_before := _gs_dump()
	var why := SaveGame.cannot_save(sim)
	_check(why == "", "sauvegarde permise (%s)" % why)
	var t0 := Time.get_ticks_msec()
	_check(SaveGame.store(sim, hud), "sauvegarde écrite")
	print("sauvegarde : %d ms, %d octets" % [Time.get_ticks_msec() - t0, FileAccess.get_file_as_bytes(SaveGame.FILE).size()])
	print("résumé : ", SaveGame.summary())
	# Partie modifiée…
	sim.new_game()
	await _frames(5)
	_check(_state(sim) != before, "nouvelle partie différente")
	# … puis chargement.
	t0 = Time.get_ticks_msec()
	_check(SaveGame.restore(sim, hud), "sauvegarde chargée")
	print("chargement : %d ms" % (Time.get_ticks_msec() - t0))
	var after := _state(sim)
	var gs_after := _gs_dump()
	var rngs := 0
	for g: Variant in _find_rngs(GameState.roamers):
		rngs += 1
	print("errants : %d hasard(s) de ronde rechargé(s)" % rngs)
	if not sim.state().portals.is_empty():
		var p0: Dictionary = sim.state().portals[0]
		_check(is_equal_approx(Pylons.local_noise(p0, float(p0["x"]) + 3.0, float(p0["z"])), noise_before), "pylône : nappe recalculée à l'identique")
	for k: String in gs_before:
		if gs_before[k] != gs_after.get(k, "?"):
			print("DIFF GameState.%s : %s → %s" % [k, gs_before[k].left(160), String(gs_after.get(k, "?")).left(160)])
	await _frames(5)
	for k: String in before:
		_check(str(before[k]) == str(after[k]), "%s : %s → %s" % [k, before[k], after[k]])
	var w2: Unit = GameState.selected[0] if not GameState.selected.is_empty() else null
	_check(w2 != null and w2.job is Dictionary and w2.job["building"] == GameState.buildings[0], "référence tâche → bâtiment conservée")
	await _wait(2.0)
	_shot("4_apres_chargement")
	# La partie chargée tourne un moment à ×3 (erreurs éventuelles des systèmes après chargement).
	sim.speed = 3
	await _wait(12.0)
	print("après chargement : %.0f s de jeu" % GameState.sim_time)
	# Maj+R : le premier prévient, le second recommence.
	var ic: InputController = main.get_node("Input")
	var n := GameState.units.size()
	ic.request_restart()
	_check(GameState.units.size() == n, "premier Maj+R : partie conservée")
	ic.request_restart()
	_check(GameState.units.size() == 1, "second Maj+R : nouvelle partie")
	# La sauvegarde d'essai ne doit pas rester dans les données du joueur.
	for f: String in [SaveGame.FILE, SaveGame.INFO]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("ECHECS=%d" % _fails)
	get_tree().quit()


func _state(sim: Simulation) -> Dictionary:
	var st := sim.state()
	return {
		"graine": sim.world.gallery_seed,
		"unités": GameState.units.map(func(u: Unit) -> String: return "%s@%.1f,%.1f/%d" % [u.role, u.x, u.z, int(u.hp)]),
		"ennemis": GameState.enemies.size(),
		"bâtiments": GameState.buildings.map(func(b: Building) -> String: return "%s@%d,%d" % [b.type, b.x, b.z]),
		"creusées": st.dug.size(),
		"vague": GameState.wave,
		"forge": GameState.res["forge"],
		"recherches": GameState.research_done.keys(),
		"heure": snappedf(GameState.sim_time, 0.01),
	}


func _find_rngs(v: Variant) -> Array:
	var out := []
	if v is Rng:
		out.append(v)
	elif v is Dictionary:
		for x: Variant in (v as Dictionary).values():
			out.append_array(_find_rngs(x))
	elif v is Array:
		for x: Variant in v:
			out.append_array(_find_rngs(x))
	return out


func _gs_dump() -> Dictionary:
	var out := {}
	for p: Dictionary in GameState.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not SaveGame.GS_SKIP.has(p["name"]):
			var v: Variant = GameState.get(p["name"])
			out[p["name"]] = _flat(v, 0).left(400)
	return out


## Valeur lisible sans identifiants d'objets (qui changent forcément au chargement).
func _flat(v: Variant, depth: int) -> String:
	if depth > 3:
		return "…"
	if v is Unit:
		return "<%s %d>" % [(v as Unit).role, (v as Unit).id]
	if v is Building:
		return "<%s %d>" % [(v as Building).type, (v as Building).id]
	if v is Object:
		return "<obj>" if v != null else "null"
	if v is Array:
		var a: Array = (v as Array).slice(0, 12)
		return "[%d:" % (v as Array).size() + ",".join(a.map(func(x: Variant) -> String: return _flat(x, depth + 1))) + "]"
	if v is Dictionary:
		var parts := []
		for k: Variant in (v as Dictionary).keys().slice(0, 12):
			parts.append(_flat(k, depth + 1) + ":" + _flat(v[k], depth + 1))
		return "{" + ",".join(parts) + "}"
	return str(v)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("OK    " if ok else "ÉCHEC ") + what)


func _shot(name: String) -> void:
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
