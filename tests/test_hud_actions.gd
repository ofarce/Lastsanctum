extends "res://tests/test_case.gd"
## Étape 6 (v2) : le panneau d'actions et les textes du HUD sont identiques à ceux du prototype (73b410f)
## sur 27 contextes (Ingénieur, menu de construction, Ancre éteinte ou active, temples, caserne, Puits des
## Âmes, adeptes, héros, sélection multiple, fin de partie). Référence : assets/baked/hud/hud_actions.json,
## extraite par tools/baker/hud.js.

const Ctx := preload("res://tests/hud_context.gd")
const ACTION_FIELDS := ["id", "icon", "label", "key", "title", "disabled", "active", "cooldown"]
const TEXT_FIELDS := ["wave", "res", "population", "kind", "chosen", "health_text", "health_label", "status", "damage", "armor",
	"speed", "lore", "assault", "anchor_details", "portrait_enabled", "portrait_key"]

static var _main: Node


func _sim() -> Simulation:
	if _main == null:
		_main = load("res://main/main.tscn").instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(_main)
		var s: Simulation = _main.get_node("Simulation")
		s.paused = true
		s.new_game(Ctx.GALLERY_SEED)
	return _main.get_node("Simulation")


func test_panel_actions_match_js() -> void:
	var sim := _sim()
	var data := Ctx.load_actions()
	var results: Array = data["results"]
	check_eq(results.size(), 27, "nombre de contextes")
	for k in results.size():
		var c: Dictionary = data["contexts"][k]
		Ctx.apply(sim, c, false)
		var got := HudModel.panel_actions(sim).filter(func(a: Dictionary) -> bool: return not a["id"].begins_with("research-") and a["id"] != "offering")
		var want: Array = results[k]["hud"]["actions"]
		if got.size() != want.size():
			check(false, "%s : %d actions au lieu de %d (%s)" % [c["name"], got.size(), want.size(), _ids(got)])
			continue
		for i in want.size():
			for f: String in ACTION_FIELDS:
				var expected: Variant = want[i][f]
				# Règle demandée : coût initial × niveau, en remplacement des 200 Vie fixes.
				if got[i]["id"].begins_with("revive-"):
					var unit: Unit = GameState.fallen.filter(func(u: Unit) -> bool: return "revive-%d" % u.id == got[i]["id"])[0]
					var cost := Catalog.revive_cost(unit)
					if f == "title":
						expected = "Ressusciter %s (niveau %d) · %s" % [unit.name, Catalog.lvl(unit), Catalog.cost_text(cost)]
					elif f == "disabled":
						expected = not Catalog.can_pay(cost)
				if got[i]["id"].begins_with("train-"):
					if f == "label":
						expected = str(expected).replace(" · ", " ×4 · ")
					elif f == "title":
						expected = str(expected).replace("Entraîner un ", "Former une escouade de 4 · ")
				check_eq(got[i][f], expected, "%s, action %d, %s" % [c["name"], i, f])


func test_hud_texts_match_js() -> void:
	var sim := _sim()
	var data := Ctx.load_actions()
	for k in data["results"].size():
		var c: Dictionary = data["contexts"][k]
		Ctx.apply(sim, c, false)
		var got := HudModel.view(sim)
		var want: Dictionary = data["results"][k]["hud"]
		for f: String in TEXT_FIELDS:
			var expected: Variant = want[f]
			# Ingénieur : dégâts de base réduits de 80 à 5.
			if f == "damage" and str(expected) in ["80", "82"]:
				expected = str(int(expected) - 75)
			if f == "status" and c["name"] == "puits_des_ames":
				expected = "3 âmes à rappeler · coût initial × niveau en Vie"
			if f == "lore" and c["name"] in ["puits_des_ames", "puits_des_ames_vide"]:
				expected = Catalog.BUILDINGS["soulwell"]["lore"]
			check_eq(got[f], expected, "%s, %s" % [c["name"], f])
		check_near(got["health_pct"], want["health_pct"], 1e-3, "%s, health_pct" % c["name"])


func test_hud_key_runs_visible_action() -> void:
	var sim := _sim()
	var input: InputController = _main.get_node("Input")
	var data := Ctx.load_actions()
	Ctx.apply(sim, data["contexts"][1], false)  # Ingénieur, Ancre éteinte
	check(input.hud_key("b"), "B ouvre le menu de construction")
	check_eq(GameState.hud_menu, "build", "menu")
	check(input.hud_key("b"), "B : Retour")
	check_eq(GameState.hud_menu, "", "retour aux ordres")
	check(input.hud_key("m"), "M : Déplacer")
	check_eq(GameState.hud_mode, "move", "mode déplacement")
	check(not input.hud_key("y"), "Y n'appartient à aucune action visible")
	check(input.hud_key("r"), "R : Réactiver")
	check(GameState.units[0].orb_job, "l'Ingénieur part réactiver l'Ancre")


func test_disabled_action_consumes_key() -> void:
	var sim := _sim()
	var input: InputController = _main.get_node("Input")
	var data := Ctx.load_actions()
	Ctx.apply(sim, data["contexts"][7], false)  # Réparer en recharge
	var hp := GameState.core_hp
	check(input.hud_key("r"), "la touche reste prise par le bouton désactivé")
	check_eq(GameState.core_hp, hp, "aucune réparation pendant la recharge")


func test_hero_summon_from_anchor() -> void:
	var sim := _sim()
	var data := Ctx.load_actions()
	Ctx.apply(sim, data["contexts"][10], false)  # Ancre active, 120 de chaque ressource
	var n := GameState.units.size()
	sim.summon_hero()
	check_eq(GameState.units.size(), n + 1, "le Tireur est invoqué")
	var u: Unit = GameState.units[-1]
	check(u.role == "shooter" and u.hidden, "Tireur caché derrière le portail")
	check_near(GameState.res["forge"], 20.0, 1e-6, "100 de chaque ressource payés")
	check_eq(GameState.portal_start, GameState.sim_time, "le portail s'ouvre")


func _ids(actions: Array[Dictionary]) -> String:
	return ", ".join(actions.map(func(a: Dictionary) -> String: return a["id"]))
