extends "res://tests/test_case.gd"
## Étape 6 (v2) : le panneau d'actions et les textes du HUD sont identiques à ceux du prototype (73b410f)
## sur 27 contextes (Ingénieur, menu de construction, Ancre éteinte ou active, temples, caserne, Puits des
## Âmes, adeptes, héros, sélection multiple, fin de partie). Référence : assets/baked/hud/hud_actions.json,
## extraite par tools/baker/hud.js.

const Ctx := preload("res://tests/hud_context.gd")
const ACTION_FIELDS := ["id", "icon", "label", "key", "title", "disabled", "active", "cooldown"]
const TEXT_FIELDS := ["wave", "res", "population", "kind", "chosen", "health_text", "health_label", "status", "damage", "armor",
	"speed", "lore", "assault", "anchor_details", "portrait_enabled", "portrait_key"]

## Bâtiments du prototype ; ceux ajoutés depuis (Creuset, Entrepôt, Église, École…) sont écartés de la comparaison.
const PROTOTYPE_BUILDINGS := ["sigil", "aether", "medeina", "indra", "library", "forge", "workshop", "bedroom", "soulwell", "caserne"]

static var _main: Node


func _sim() -> Simulation:
	if _main == null:
		_main = shared_main()
		var s: Simulation = _main.get_node("Simulation")
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
		# Creuset des Exilés : bâtiment ajouté après le prototype (fabrication). « Vider le coffre » : coffre rouge des
		# bâtiments servis par des adeptes (2026-11-17).
		# Poser (défenses de l’Atelier, sim/placeables.gd) : ordre ajouté après le prototype.
		var got := HudModel.panel_actions(sim).filter(func(a: Dictionary) -> bool: return not a["id"].begins_with("research-") and a["id"] != "offering" and not (a["id"].begins_with("b-") and a["id"].substr(2) not in PROTOTYPE_BUILDINGS) and a["id"] != "collect" and a["id"] != "menu-place" and not a["id"].begins_with("bfam-"))
		# Menu Construire par familles (2026-11-20) : seuls les bâtiments débloqués de l'onglet ouvert restent.
		var shown := HudModel.family_buildings(GameState.hud_build_family)
		var want: Array = (results[k]["hud"]["actions"] as Array).filter(func(a: Dictionary) -> bool:
			return not a["id"].begins_with("b-") or a["id"].substr(2) in shown)
		if got.size() != want.size():
			check(false, "%s : %d actions au lieu de %d (%s)" % [c["name"], got.size(), want.size(), _ids(got)])
			continue
		for i in want.size():
			for f: String in ACTION_FIELDS:
				var expected: Variant = want[i][f]
				# Prérequis reformulé : « construisez d’abord un Temple… ».
				if f == "title" and got[i]["id"].begins_with("b-"):
					expected = str(expected).replace(" · nécessite un ", " · construisez d’abord un ")
				if f == "title" and got[i]["id"].begins_with("b-") and not str(expected).ends_with(" · 2 × 2"):
					expected = str(expected) + " · 2 × 2"
				# Réparer : plus de réparation instantanée à recharge ; le bouton envoie l'Ingénieur prier à l'Ancre,
				# et la prière la répare (2026-11-20).
				if got[i]["id"] == "repair":
					if f == "title":
						check(str(got[i][f]).begins_with("Prier à l’Ancre · la répare"), "%s : Réparer décrit la prière" % c["name"])
						continue
					elif f == "disabled":
						expected = false
					elif f == "cooldown":
						expected = ""
				# Règle demandée : coût initial × niveau, en remplacement des 200 Vie fixes.
				if got[i]["id"].begins_with("revive-"):
					var unit: Unit = GameState.fallen.filter(func(u: Unit) -> bool: return "revive-%d" % u.id == got[i]["id"])[0]
					var cost := Catalog.revive_cost(unit)
					if f == "title":
						expected = "Ressusciter %s (niveau %d) · %s" % [unit.name, Catalog.lvl(unit), Catalog.cost_text(cost)]
					elif f == "disabled":
						expected = not Catalog.can_pay(cost)
					# Les recherches du Puits prennent les premières touches (HudModel.research_keys).
					elif f == "key" and str(expected) != "":
						expected = str(int(expected) + HudModel.research_keys(HudModel.selected_building()))
				if got[i]["id"].begins_with("train-"):
					if f == "label":
						expected = str(expected).replace(" · ", " ×4 · ")
					elif f == "title":
						expected = str(expected).replace("Entraîner un ", "Former : ")
					# Fabrication : archers et Épée et bouclier demandent leurs objets, affichés avec le stock.
					var role: String = got[i]["id"].substr(6)
					# Le bouton de l'unité en tête de file est actif (jauge de formation dessus).
					if f == "active":
						var caserne := HudModel.selected_building()
						expected = not caserne.queue.is_empty() and caserne.queue[0] == role
					var items: Dictionary = Simulation.Recipes.caserne_cost(role, 4)
					if not items.is_empty():
						if f == "title":
							expected = str(expected) + " · " + HudModel._stock_text(items)
						elif f == "disabled":
							# Les contextes de référence ne contiennent aucun équipement.
							expected = true
				check_eq(got[i][f], expected, "%s, action %d, %s" % [c["name"], i, f])


func test_hud_texts_match_js() -> void:
	var sim := _sim()
	var data := Ctx.load_actions()
	for k in data["results"].size():
		var c: Dictionary = data["contexts"][k]
		Ctx.apply(sim, c, false)
		var got := HudModel.view(sim)
		var want: Dictionary = data["results"][k]["hud"]
		var shown: Unit = GameState.selected[0] if not GameState.selected.is_empty() else null
		var armored := shown != null and shown.role == "engineer" and not shown.unarmored
		for f: String in TEXT_FIELDS:
			var expected: Variant = want[f]
			# Ingénieur : dégâts de base réduits de 80 à 5 ; en armure, 1 000 de dégâts et +500 de défense.
			if f == "damage" and str(expected) in ["80", "82"]:
				expected = str(int(expected) - 80 + (1000 if armored else 5))
			if f == "armor" and armored:
				expected = str(int(expected) + 500)
			if f == "status" and c["name"] == "puits_des_ames":
				expected = "3 âmes à rappeler · coût initial × niveau en Vie"
			# Bâtiment servi par des adeptes (2026-11-17) : statut des postes tant que personne n'y travaille.
			var shown_b := HudModel.selected_building()
			if f == "status" and shown == null and shown_b != null and Production.idle(shown_b):
				expected = HudModel.building_status(shown_b)
				check(str(expected).begins_with("À l’arrêt"), "%s : signalé à l'arrêt" % c["name"])
			# Population : « occupées/plafond » (Catalog.POP_BASE et Chambres), au lieu du seul nombre d'unités.
			# L'Ingénieur ne gagne plus de niveaux (2026-11-22) : plus de niveau ni d'XP dans son titre.
			if f == "kind" and shown != null and shown.role == "engineer":
				expected = str(expected).split(" · NIV.")[0]
			if f == "population":
				expected = "%d/%d" % [Simulation.pop_used(), Simulation.pop_cap()]
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


func test_repair_key_sends_engineer_to_pray_at_anchor() -> void:
	var sim := _sim()
	var input: InputController = _main.get_node("Input")
	var data := Ctx.load_actions()
	Ctx.apply(sim, data["contexts"][7], false)  # Ingénieur, Ancre active (ancien contexte « Réparer en recharge »)
	var eng: Unit = GameState.units[0]
	var hp := GameState.core_hp
	check(input.hud_key("r"), "R : Réparer")
	check(Capsule.praying(eng), "l'Ingénieur part prier à l'Ancre")
	check_eq(GameState.core_hp, hp, "aucune réparation instantanée")
	var repair: Dictionary = HudModel.panel_actions(sim).filter(func(a: Dictionary) -> bool: return a["id"] == "repair")[0]
	check(repair["active"] and not repair["disabled"], "bouton actif pendant la prière, jamais en recharge")
	check(input.hud_key("r"), "R de nouveau")
	check(not Capsule.praying(eng), "second ordre : il se relève")


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
