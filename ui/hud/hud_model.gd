class_name HudModel
extends RefCounted
## Logique du HUD de commandement, portée de hud.js (73b410f) sans rendu :
##  - panel_actions() : panelActions, les ordres du panneau selon la sélection (Ancre, bâtiment, unité) ;
##  - view() : les textes de updateHUD (identité, points de vie, statut, détails, assaut, portrait) ;
##  - unit_status(), building_status(), adept_status(), format_assault().
## Chaque action est un dictionnaire {id, icon, label, key, title, disabled, active, cooldown, run}.
## tests/test_hud_actions.gd compare ces sorties à celles du jeu d'origine sur 26 contextes.

const ORB_TIME := Simulation.ORB_TIME

static var _adept_prefix := RegEx.create_from_string("^Adepte (de |d’)?")
static var _temple_prefix := RegEx.create_from_string("^Temple (de |d’)")


## Nombre au format JS (String(n)) : entier sans décimale.
static func num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


## Nombre au format fr-FR (toLocaleString) : virgule décimale.
static func num_fr(v: float) -> String:
	return num(v).replace(".", ",")


static func alive_selected() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in GameState.selected:
		if u.alive():
			out.append(u)
	return out


## selectedBuilding (buildings.js).
static func selected_building() -> Building:
	var b := GameState.hud_building
	return b if b and GameState.buildings.has(b) else null


## Incarné : un bâtiment ou une autre unité est ouvert dans le bandeau (clic gauche ou droit).
## Exilé dont l'IHM incarnée est affichée : l'Exilé incarné, ou l'Ingénieur resté dans la capsule (IHM gardée).
static func hud_exile() -> Unit:
	if GameState.incarnated != null:
		return GameState.incarnated
	return Capsule.engineer() if GameState.in_capsule else null


static func incarnated_panel() -> bool:
	var inc := hud_exile()
	return inc != null and (selected_building() != null or GameState.hud_grove != null \
		or GameState.selected.any(func(u: Unit) -> bool: return u != inc and not u.hidden))


## unlocked (buildings.js) : sans prérequis, ou un bâtiment requis achevé ; et son âge de métal ouvert (sim/ages.gd).
static func unlocked(type: String) -> bool:
	if not Ages.building_open(type):
		return false
	var r: String = Catalog.BUILDINGS[type]["requires"]
	if r.is_empty():
		return true
	var research := String(Catalog.BUILDINGS[type].get("research", ""))
	if research != "" and not GameState.research_done.has(research):
		return false
	for b in GameState.buildings:
		if b.type == r and b.complete:
			return true
	return false


## Ce qui manque pour construire `type` : « construisez d'abord un … » ou la recherche exigée.
static func lock_reason(type: String) -> String:
	var D: Dictionary = Catalog.BUILDINGS[type]
	if not Ages.building_open(type):
		return "%s requis" % Ages.AGES[Ages.BUILDING_AGE[type]]["name"]
	for b in GameState.buildings:
		if b.type == D["requires"] and b.complete:
			var research := String(D.get("research", ""))
			return "recherche « %s » requise (%s)" % [Catalog.RESEARCH[research]["name"], Catalog.BUILDINGS[Catalog.RESEARCH[research]["building"]]["name"]]
	return "construisez d’abord un %s" % Catalog.BUILDINGS[D["requires"]]["name"]


## ownTemples (adepts.js) : temples achevés du dieu de l'adepte.
static func own_temples(u: Unit) -> Array[Building]:
	var out: Array[Building] = []
	for b in GameState.buildings:
		if b.complete and b.def()["deity"] == u.role:
			out.append(b)
	return out


## Temples où l'adepte peut prier (tous pour un adepte de Sigil).
static func prayable_temples(u: Unit) -> Array[Building]:
	var out: Array[Building] = []
	for b in GameState.buildings:
		if Simulation.can_pray_at(u, b):
			out.append(b)
	return out


static func can_summon_hero() -> bool:
	return not GameState.ended and GameState.orb_active and Catalog.can_pay(Catalog.HERO_COST)


static func summon_cost(b: Building) -> Dictionary:
	return {Catalog.DEITY_RES[b.def()["deity"]]: Catalog.SUMMON_COST}


static func can_summon_at(b: Building) -> bool:
	return not GameState.ended and b and b.complete and b.is_temple() and b.queue.size() < Catalog.TEMPLE_QUEUE \
		and Catalog.can_pay(summon_cost(b)) and Simulation.pop_room(b.def()["deity"])


static func can_train(b: Building, id := "lame") -> bool:
	return not GameState.ended and b and b.complete and Catalog.TRAINERS.has(b.type) and b.queue.size() < Catalog.CASERNE_QUEUE \
		and Catalog.can_pay(Catalog.train_cost(id)) and Simulation.pop_room(id)


## Les objets de l'escouade sont apportés ensuite au coffre bleu par les adeptes d'Indra.
static func can_train_unit(b: Building, id: String) -> bool:
	if not can_train(b, id):
		return false
	var cost := Simulation.Recipes.caserne_cost(id, 4)
	for queued: String in b.queue:
		var committed := Simulation.Recipes.caserne_cost(queued, 4)
		for item: String in cost:
			cost[item] += int(committed.get(item, 0))
	for item: String in cost:
		var available := Production.count_for(b.input_box, item) + Production.in_transit(b, item)
		for src: Dictionary in Production.supply_sources(b):
			available += maxi(0, Production.count_for(Production.src_items(src), item) - Production.reserved(src, item))
		if available < int(cost[item]):
			return false
	return true


static func can_revive(b: Building, u: Unit) -> bool:
	return not GameState.ended and b and b.complete and b.type == "soulwell" and not GameState.fallen.is_empty() \
		and Simulation.revivable(u) and Catalog.can_pay(Catalog.revive_cost(u)) and Simulation.pop_room(u.role)


# ---------------------------------------------------------------- panelActions

## Boutons de commande « Émail par famille » (planches/boutons-commande-propositions.html, piste 4) : pictogramme
## ivoire sur plaque d'émail ; c = construction (ambre), a = Ancre et culte (cyan), f = combat (rouge), n = navigation.
const COMMAND_GLYPH := {"menu-build": ["build", "c"], "menu-place": ["place", "c"], "repair": ["repair", "c"],
	"orb": ["orb", "a"], "offering": ["offering", "a"], "pray": ["pray", "a"], "ability": ["ability", "f"],
	"hold": ["hold", "f"], "move": ["move", "f"], "warehouse-page": ["page", "n"], "back": ["back", "n"], "recall": ["back", "a"]}
## Recharge des compétences par rôle (Simulation.run_ability), pour le voile de recharge.
const ABILITY_TIME := {"paladin": 16.0, "healer": 12.0, "engineer": 18.0, "shooter": 10.0}


static func panel_actions(sim: Simulation) -> Array[Dictionary]:
	var A := _panel_actions(sim)
	var u: Unit = alive_selected()[0] if not alive_selected().is_empty() else null
	for a: Dictionary in A:
		if COMMAND_GLYPH.has(a["id"]):
			_command_glyph(a, u)
	return A


static func _command_glyph(a: Dictionary, u: Unit) -> void:
	var g: Array = COMMAND_GLYPH[a["id"]]
	a["command_icon"] = g[0]
	a["family"] = g[1]
	var label: String = a["label"]
	var name := label.get_slice(" · ", 0).trim_suffix(" ›")
	var why := ""
	var recall_left := maxf(0.0, Mods.at(u, "recall_ready") - GameState.sim_time) if u else 0.0
	if a["id"] == "recall" and recall_left > 0.0:
		a["cd_frac"] = clampf(recall_left / Mods.RECALL_CD, 0.0, 1.0)
		a["cd_text"] = str(ceili(recall_left))
		why = "Recharge · %s s" % a["cd_text"]
	elif a["id"] == "ability" and u and u.ability > 0.0:
		a["cd_frac"] = clampf(u.ability / float(ABILITY_TIME.get(u.role, 18.0)), 0.0, 1.0)
		a["cd_text"] = str(ceili(u.ability))
		why = "Recharge · %s s" % a["cd_text"]
	elif a["id"] == "offering" and a["disabled"]:
		a["poor"] = true
		why = "Mana insuffisant"
	elif a["id"] == "menu-place":
		a["craft_count"] = int(label.get_slice(" · ", 1)) if label.contains(" · ") else 0
	elif a["disabled"]:
		a["locked"] = true
		why = "Indisponible"
	if a["id"] == "warehouse-page":
		name = "Catégorie « %s »" % name
	a["bubble"] = [name, "", true, why, a["title"]]


static func _panel_actions(sim: Simulation) -> Array[Dictionary]:
	var A: Array[Dictionary] = []
	if GameState.ended:
		return A
	var alive := alive_selected()
	var u: Unit = alive[0] if not alive.is_empty() else null
	var B := selected_building()
	if GameState.anchor_selected:
		if not GameState.orb_active:
			var has_engineer := GameState.units.any(func(o: Unit) -> bool: return o.role == "engineer" and o.alive() and not o.hidden)
			A.append(_act("orb", "rune", "Réactiver", "r", "Envoyer l’Ingénieur réactiver l’Ancre · %s s" % num(ORB_TIME),
				func() -> void: sim.order_orb(), not has_engineer, GameState.orb_owner != null))
		A.append(_act("hero", "sword", "Tireur · " + Catalog.short_cost(Catalog.HERO_COST), "t",
			"Invoquer le héros Tireur · " + Catalog.cost_text(Catalog.HERO_COST), sim.summon_hero, not can_summon_hero()))
		A[-1]["unit_sprite"] = "shooter"
		A[-1]["poor"] = GameState.orb_active and not Catalog.can_pay(Catalog.HERO_COST)
		A[-1]["locked"] = not GameState.orb_active
		A[-1]["bubble"] = ["Tireur", _mana_text(Catalog.HERO_COST), Catalog.can_pay(Catalog.HERO_COST),
			"" if GameState.orb_active else "Ancre éteinte", "Héros invoqué à l’Ancre."]
		A.append(_act("offering", "menace", "Offrande · +50 menace", "o",
			"Offrande tyrienne · " + Catalog.cost_text(Catalog.ANCHOR_MENACE_COST) + " · +50 menace · Réutilisable",
			sim.offer_menace, not Simulation.can_offer_menace()))
		return A
	if u == null and B:
		if not B.complete:
			return A
		# Recherches du bâtiment : touches 1, 2, 3… (les fabrications et résurrections prennent les chiffres suivants).
		var rk := 0
		for id: String in building_research(B):
			var research: Dictionary = Catalog.RESEARCH[id]
			rk += 1
			var pos := Simulation.research_queue_pos(id)
			var key := str(rk) if rk <= 9 else ""
			var action := _act("research-" + id, String(research.get("icon", "mining_seal")), research["name"], key, research["name"],
				func() -> void: sim.start_research(B, id), not Simulation.can_research(B, id))
			action["status"] = "En cours" if pos == 0 else ("En file" if pos > 0 else "")
			_research_glyph(action, id, false, pos >= 0)
			A.append(action)
		var D := B.def()
		var deity: String = D["deity"]
		if not deity.is_empty():
			var r: String = Catalog.RES_INFO[Catalog.DEITY_RES[deity]]["name"]
			A.append(_act("summon", D["icon"], "Adepte · %d" % Catalog.SUMMON_COST, "i",
				"Invoquer un %s · %d %s · prie au temple : +1 %s / s" % [String(Catalog.ADEPT[deity]["name"]).to_lower(), Catalog.SUMMON_COST, r, r],
				func() -> void: sim.summon_adept(B), not can_summon_at(B)))
			_summon_glyph(A[-1], B, deity, r)
		if Catalog.TRAINERS.has(B.type):
			var times := " ×4" if B.type == "caserne" else ""
			for t: Dictionary in Catalog.TRAINERS[B.type]:
				var id: String = t["id"]
				var title := "Former : %s · %s · %s s" % [String(Catalog.ADEPT[id]["name"]).to_lower(), Catalog.cost_text(Catalog.train_cost(id)), num(Catalog.CASERNE_TIME)]
				var items := Simulation.Recipes.caserne_cost(id, 4)
				if not items.is_empty():
					title += " · " + _stock_text(items)
				A.append(_act("train-" + id, t["icon"], "%s%s · %s" % [t["label"], times, Catalog.short_cost(Catalog.train_cost(id))], t["key"],
					title, func() -> void: sim.train_unit(B, id), not can_train_unit(B, id)))
				_train_glyph(A[-1], B, id, t["label"] + times)
		if B.type == "warehouse":
			_warehouse_actions(A, B)
		if Simulation.Recipes.has_station(B.type):
			_craft_actions(A, sim, B)
		if B.type == "soulwell":
			var eligible := GameState.fallen.filter(func(f: Unit) -> bool: return Simulation.revivable(f))
			var last := eligible.slice(maxi(0, eligible.size() - 9))
			last.reverse()
			for i in last.size():
				var f: Unit = last[i]
				var rkey := research_keys(B) + i + 1
				A.append(_act("revive-%d" % f.id, "heart", "%s ★%d" % [_adept_prefix.sub(f.name, ""), Catalog.lvl(f)], str(rkey) if rkey <= 9 else "",
					"Ressusciter %s (niveau %d) · %s" % [f.name, Catalog.lvl(f), Catalog.cost_text(Catalog.revive_cost(f))],
					func() -> void: sim.revive_unit(B, f), not can_revive(B, f)))
				var rc := Catalog.revive_cost(f)
				A[-1]["unit_sprite"] = _sprite_key(f)
				A[-1]["poor"] = not Catalog.can_pay(rc)
				A[-1]["locked"] = A[-1]["disabled"] and not A[-1]["poor"]
				A[-1]["bubble"] = ["%s · niveau %d" % [f.name, Catalog.lvl(f)], _mana_text(rc), not A[-1]["poor"], "Résurrection",
					String(Catalog.ADEPT.get(f.role, {}).get("lore", ""))]
		return A
	# Désincarné, Ingénieur dans la capsule : les constructions restent accessibles, sans sélection.
	if GameState.in_capsule and (u == null or u.hidden):
		_build_family_tabs(A, false)
		_build_actions(A, sim)
		return A
	if u == null or u.hidden:
		return A
	if u.role == "engineer" and GameState.hud_menu == "build":
		_build_family_tabs(A, true)
		_build_actions(A, sim)
		A.append(_act("back", "restart", "Retour", "b", "Revenir aux ordres de l’Ingénieur (B ou Échap)", func() -> void:
			GameState.hud_menu = ""
			GameState.hud_mode = ""))
		return A
	if u.role == "engineer" and GameState.hud_menu == "place":
		var keys := "123"
		for i in Simulation.Placeables.ITEMS.size():
			var item: String = Simulation.Placeables.ITEMS[i]
			var n := Simulation.ItemStorage.count_ammo(item)
			var R := Simulation.Recipes
			A.append(_act("place-" + item, CRAFT_ICON.get(item, "hammer"), "%s · %d" % [R.name_of(item), n], keys[i],
				"%s · %d en stock · %s" % [R.name_of(item), n, R.desc_of(item)], func() -> void: sim.arm_place(item), n <= 0,
				GameState.hud_mode == "place" and GameState.hud_place_item == item))
			A[-1]["craft_item"] = item
			A[-1]["craft_count"] = n
			A[-1]["bubble"] = [R.name_of(item), "%d en stock" % n, n > 0, "" if n > 0 else "À fabriquer à l’Atelier", R.desc_of(item)]
		A.append(_act("back", "restart", "Retour", "p", "Revenir aux ordres de l’Ingénieur (P ou Échap)", func() -> void:
			GameState.hud_menu = ""
			GameState.hud_mode = ""))
		return A
	if u.role == "engineer":
		A.append(_act("menu-build", "hammer", "Construire", "b", "Construire un temple ou un bâtiment", func() -> void:
			GameState.hud_menu = "build"))
		var stock: int = Simulation.Placeables.ITEMS.reduce(func(acc: int, it: String) -> int: return acc + Simulation.ItemStorage.count_ammo(it), 0)
		A.append(_act("menu-place", "flag", "Poser · %d" % stock, "p", "Poser une défense de l’Atelier : poste de tir, barricade, chausse-trappe",
			func() -> void: GameState.hud_menu = "place"))
		if GameState.orb_active:
			A.append(_act("repair", "repair", "Réparer", "r", "Prier à l’Ancre · la répare de %s PV / s · +%s de chaque mana / s · coûte %s PV / s à l’Ingénieur" \
				% [num(Simulation.ANCHOR_REPAIR), num(Simulation.ANCHOR_PRAY), num(Simulation.ANCHOR_PRAY_HP)], sim.run_ability, false, Capsule.praying(u)))
		else:
			A.append(_act("orb", "rune", "Réactiver", "r", "Réactiver l’Ancre · %s s" % num(ORB_TIME), func() -> void: sim.order_orb(u),
				false, u.orb_job))
		# Ancre de rappel (sim/mods.gd) : retour à la capsule, hors combat.
		if Mods.worn(u, "anchor"):
			var left := maxf(0.0, Mods.at(u, "recall_ready") - GameState.sim_time)
			A.append(_act("recall", "restart", "Rappel", "g", "Ancre de rappel · retour à la capsule, hors combat · toutes les %d min" % int(Mods.RECALL_CD / 60.0),
				func() -> void: Mods.recall(sim, u), left > 0.0, false, "%d s" % ceili(left) if left > 0.0 else ""))
	elif Catalog.prays(u):
		var any_temple := alive.any(func(o: Unit) -> bool: return Catalog.prays(o) and not prayable_temples(o).is_empty())
		A.append(_act("pray", "rune", "Prier", "y", "Prier au temple de son dieu", sim.pray_selected, not any_temple))
	elif u.role == "shooter":
		A.append(_act("ability", "flame", "Compétence", " ", "Tir de précision", sim.run_ability, u.ability > 0.0, false,
			"%d s" % ceili(u.ability) if u.ability > 0.0 else ""))
	if u.squad_capacity > 0 and alive.all(func(member: Unit) -> bool: return member.squad == u.squad):
		var losses := Simulation.squad_losses(u)
		if not losses.is_empty():
			var cost := Simulation.squad_revive_cost(u)
			A.append(_act("revive-squad", "heart", "Renforts · " + Catalog.cost_text(cost), "r",
				"Ressusciter %d membre(s) au Puits des Âmes et rallier l’escouade · %s" % [losses.size(), Catalog.cost_text(cost)],
				func() -> void: sim.revive_squad(u), Simulation.life_well() == null or not Catalog.can_pay(cost)))
			A[-1]["cost_text"] = Catalog.cost_text(cost)
			A[-1]["unit_sprite"] = _sprite_key(u)
			A[-1]["craft_count"] = losses.size()
			A[-1]["poor"] = not Catalog.can_pay(cost)
			A[-1]["locked"] = Simulation.life_well() == null
			A[-1]["bubble"] = ["Renforts", _mana_text(cost), Catalog.can_pay(cost),
				"Puits des Âmes requis" if A[-1]["locked"] else "%d membre(s) à ressusciter" % losses.size(),
				"Ressuscités au Puits des Âmes, ils rallient l’escouade."]
	A.append(_act("hold", "flag", "Position", "h", "Tenir position", sim.hold, false, u.stance == "hold"))
	A.append(_act("move", "move", "Déplacer", "m", "Déplacer : choisir une destination", sim.arm_move, false, GameState.hud_mode == "move"))
	return A


const CRAFT_KEYS := "1234567890"
## Icône du HUD par objet fabriqué (marteau par défaut).
const CRAFT_ICON := {"torch": "flame", "arrows": "bow", "bow": "bow", "wood_fiber": "wood", "plank": "wood", "chest": "repair",
	"firing_post": "flag", "barricade": "shield", "caltrops": "skull", "sword": "sword", "shield": "shield",
	"copper_ingot": "iron", "iron_ingot": "iron", "gold_ingot": "iron", "copper_armor": "shield", "iron_armor": "shield",
	"iron_greatsword": "sword", "iron_sword": "sword", "copper_greatsword": "sword", "copper_sword": "sword",
	"iron_shield": "shield", "copper_shield": "shield", "cannon": "flame"}


static func _warehouse_actions(actions: Array[Dictionary], b: Building) -> void:
	var groups := ["Matériaux", "Atelier", "Scierie", "Archerie", "Fonderie", "Armurerie"]
	var catalogs := [Simulation.Blocks.ITEMS, Simulation.Recipes.RECIPES["workshop"], Simulation.Recipes.RECIPES["scierie"],
		Simulation.Recipes.RECIPES["archerie"], Simulation.Recipes.RECIPES["forge"], Simulation.Recipes.RECIPES["creuset"]]
	var next := (b.warehouse_page + 1) % groups.size()
	actions.append(_act("warehouse-page", "book", groups[b.warehouse_page] + " ›", "p",
		"Afficher la catégorie suivante · " + groups[next], func() -> void: b.warehouse_page = next))
	for item: String in catalogs[b.warehouse_page]:
		if not Ages.recipe_open(item):
			continue
		var selected := b.requested_items.has(item)
		var label := Simulation.Recipes.name_of(item)
		var title := "Maintenir %d exemplaires de %s dans cet entrepôt." % [Production.WAREHOUSE_TARGET, label]
		actions.append(_act("request-" + item, CRAFT_ICON.get(item, "iron"), ("✓ " if selected else "") + label,
			"", title, func() -> void:
				if b.requested_items.has(item):
					b.requested_items.erase(item)
				else:
					b.requested_items.append(item), false, selected))
		actions[-1]["craft_item"] = item
		actions[-1]["bubble"] = [label, "Maintenir %d exemplaires" % Production.WAREHOUSE_TARGET, true,
			"Demandé" if selected else "Cliquer pour demander", ""]


## Boutons de fabrication : une recette par bouton (touches 1 à 0), puis « Annuler » si la file n'est pas vide.
static func _craft_actions(A: Array[Dictionary], sim: Simulation, B: Building) -> void:
	var R := Simulation.Recipes
	var recipes: Dictionary = R.RECIPES[B.type]
	var i := 0
	for item: String in recipes:
		# Âge de métal fermé, ou plan pas encore appris : la recette est masquée (sim/ages.gd, Recipes.PLANS).
		if not Ages.recipe_open(item) or not R.plan_known(item):
			continue
		var cost: Dictionary = recipes[item]
		var title := "%s · %s · %s s" % [R.name_of(item), _stock_text(cost), num(R.craft_time(B.type))]
		var desc := R.desc_of(item)
		if desc != "":
			title += " · " + desc
		if not Simulation.recipe_unlocked(item):
			title += " · Recherche « %s » requise (%s)." % [Catalog.RESEARCH[Catalog.RECIPE_RESEARCH[item]]["name"], Catalog.BUILDINGS[Catalog.RESEARCH[Catalog.RECIPE_RESEARCH[item]]["building"]]["name"]]
		if R.ITEMS.get(item, {}).get("pending", false):
			title += " · Effet pas encore en jeu : l’objet est stocké."
		if R.disabled(item):
			title += " · Pas encore disponible."
		if R.PLANS.has(item):
			title += " · Fabriqué une seule fois par les adeptes au poste ; cliquer de nouveau pour annuler."
		else:
			title += " · Fabriqué en boucle par les adeptes au poste ; cliquer de nouveau pour arrêter."
		var action := _act("craft-" + item, CRAFT_ICON.get(item, "hammer"), R.name_of(item), CRAFT_KEYS[i + research_keys(B)] if i + research_keys(B) < CRAFT_KEYS.length() else "", title,
			func() -> void: sim.craft(B, item), not Simulation.can_craft(B, item), B.recipe == item)
		# Bouton « Laiton et objet franc » (planches/boutons-fabrication-propositions.html, piste 1) :
		# l'objet seul, la touche et le compteur ; nom et coût dans la bulle au survol.
		action["craft_item"] = item
		action["craft_count"] = Production.count_in(B.output_box, item)
		action["craft_progress"] = B.craft / R.craft_time(B.type) if B.recipe == item else 0.0
		action["locked"] = not Simulation.recipe_unlocked(item) or R.disabled(item)
		var why := ""
		if R.disabled(item):
			why = "Pas encore disponible"
		elif action["locked"]:
			why = "Recherche « %s » requise" % Catalog.RESEARCH[Catalog.RECIPE_RESEARCH[item]]["name"]
		action["bubble"] = [R.name_of(item), "%s · %s s" % [_stock_text(cost), num(R.craft_time(B.type))], _stock_ok(cost), why]
		A.append(action)
		i += 1


## Recherches non achevées d'un bâtiment, dans l'ordre du catalogue (les achevées passent dans la ResearchShelf).
static func building_research(B: Building) -> Array[String]:
	var out: Array[String] = []
	if B == null:
		return out
	for id: String in Catalog.RESEARCH:
		if Catalog.RESEARCH[id]["building"] == B.type and not GameState.research_done.has(id) and Ages.research_open(id):
			out.append(id)
	return out


## Nombre de chiffres pris par les recherches du bâtiment (au plus 9).
static func research_keys(B: Building) -> int:
	return mini(9, building_research(B).size())


## Coût d'une recherche en pastilles : ressources puis objets, avec le stock.
static func research_cost_lines(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cost := Catalog.research_cost(id)
	for k: String in Catalog.RES_ORDER:
		if cost.has(k):
			out.append({"res": k, "need": int(cost[k]), "have": int(GameState.res[k])})
	var items := Catalog.research_items(id)
	for k: String in items:
		out.append({"item": k, "need": int(items[k]), "have": Catalog.ItemStorage.count(k)})
	return out


## État d'une recherche, pour la fiche et le grimoire : « done », « run », « stopped » (en tête de file sans
## personnel), « queue », « locked », « poor », « ready », avec sa phrase.
static func research_state(id: String) -> Dictionary:
	if GameState.research_done.has(id):
		return {"kind": "done", "text": "Achevée"}
	var pos := Simulation.research_queue_pos(id)
	if pos == 0:
		var job: Dictionary = GameState.research_jobs[id]
		var p: float = job["progress"] / Catalog.RESEARCH_TIME
		var b: Building = job["building"]
		var speed := Production.speed(b)
		if speed <= 0.0:
			return {"kind": "stopped", "progress": p, "text": "À l’arrêt · personnel requis au bâtiment"}
		return {"kind": "run", "progress": p, "text": "En cours · encore %s s" % num(ceilf((Catalog.RESEARCH_TIME - job["progress"]) / speed))}
	if pos > 0:
		var ahead: String = Catalog.RESEARCH[Simulation.research_queue(GameState.research_jobs[id]["building"])[0]]["name"]
		return {"kind": "queue", "pos": pos, "text": "En file · n° %d, après %s" % [pos, ahead] if pos == 1 else "En file · n° %d" % pos}
	if not Simulation.research_requirements_met(id):
		var names: PackedStringArray = []
		for required: String in Catalog.RESEARCH[id]["requires"]:
			if not GameState.research_done.has(required):
				names.append(Catalog.RESEARCH[required]["name"])
		return {"kind": "locked", "text": "Prérequis : " + ", ".join(names)}
	var missing: PackedStringArray = []
	for line: Dictionary in research_cost_lines(id):
		if line["have"] < line["need"]:
			var nm: String = Catalog.RES_INFO[line["res"]]["name"] if line.has("res") else Simulation.Recipes.name_of(line["item"])
			missing.append("%d %s" % [line["need"] - line["have"], nm])
	if not missing.is_empty():
		return {"kind": "poor", "text": "Il manque " + ", ".join(missing)}
	var host := _research_host(id)
	if host != null and not Simulation.research_queue(host).is_empty():
		return {"kind": "ready", "text": "Prête · ira en file d’attente"}
	return {"kind": "ready", "text": "Prête · %s s" % num(Catalog.RESEARCH_TIME)}


## Bâtiment où une recherche se lance : celui qui est ouvert s'il est du bon type, sinon le premier achevé.
static func _research_host(id: String) -> Building:
	var type: String = Catalog.RESEARCH[id]["building"]
	var b := selected_building()
	if b != null and b.type == type and b.complete:
		return b
	for o: Building in GameState.buildings:
		if o.type == type and o.complete:
			return o
	return null


## Bouton de recherche « Laiton, trait d'or et cachet » (planches/boutons-recherche-unites-propositions.html, piste 1) :
## l'objet au trait d'or, la couleur qui monte pendant la recherche ; nom, coût, effet et état dans la fiche du panneau
## central (planches/recherches-interface-propositions.html, piste A).
static func _research_glyph(action: Dictionary, id: String, done: bool, _pending: bool) -> void:
	var st := research_state(id)
	action["research_icon"] = id
	action["research_done"] = done
	action["active"] = st["kind"] in ["run", "stopped"]
	action["craft_progress"] = st.get("progress", 0.0)
	action["research_queue"] = st.get("pos", 0)
	action["locked"] = st["kind"] == "locked"
	action["poor"] = st["kind"] == "poor"
	action["research_state"] = st
	action["research_name_below"] = true
	var parts: PackedStringArray = []
	for line: Dictionary in research_cost_lines(id):
		var nm: String = Catalog.RES_INFO[line["res"]]["name"] if line.has("res") else Simulation.Recipes.name_of(line["item"])
		parts.append("%d %s (%d)" % [line["need"], nm, line["have"]])
	# Bulle de secours, quand la fiche du panneau central n'est pas affichée.
	action["bubble"] = [Catalog.RESEARCH[id]["name"], " + ".join(parts) + " · %s s" % num(Catalog.RESEARCH_TIME),
		st["kind"] not in ["poor", "locked"], st["text"], Catalog.RESEARCH[id].get("desc", "")]


## Bouton d'escouade de la Caserne : sprite de l'unité, file d'attente en pastille grenat, jauge de l'escouade en cours.
static func _train_glyph(action: Dictionary, B: Building, id: String, label: String) -> void:
	var items := Simulation.Recipes.caserne_cost(id, 4)
	var front := not B.queue.is_empty() and B.queue[0] == id
	action["unit_sprite"] = id
	action["craft_count"] = B.queue.count(id)
	action["active"] = front
	action["craft_progress"] = B.train / Catalog.CASERNE_TIME if front else 0.0
	action["poor"] = not Catalog.can_pay(Catalog.train_cost(id))
	action["locked"] = action["disabled"] and not action["poor"]
	var why := ""
	if B.queue.size() >= Catalog.CASERNE_QUEUE:
		why = "File pleine"
	elif action["locked"]:
		why = "Objets manquants dans les coffres"
	elif action["craft_count"] > 0:
		why = "%d en file" % action["craft_count"]
	var cost := _mana_text(Catalog.train_cost(id)) + (" · " + _stock_text(items) if not items.is_empty() else "")
	action["bubble"] = [label, "%s · %s s" % [cost, num(Catalog.CASERNE_TIME)], not action["poor"], why, Catalog.ADEPT[id]["lore"]]


## Bouton d'invocation d'un temple : l'esprit du dieu, file d'attente, jauge de l'arrivée en cours.
static func _summon_glyph(action: Dictionary, B: Building, deity: String, res_name: String) -> void:
	var cost := summon_cost(B)
	var arriving := Simulation.temple_arrival(B)
	action["unit_sprite"] = deity
	action["craft_count"] = B.queue.size() + (1 if arriving else 0)
	action["active"] = arriving != null
	action["craft_progress"] = clampf(1.0 - (arriving.arrival_end - GameState.sim_time) / Simulation.ARRIVAL, 0.0, 1.0) if arriving else 0.0
	action["poor"] = not Catalog.can_pay(cost)
	action["locked"] = action["disabled"] and not action["poor"]
	var why := "File pleine" if B.queue.size() >= Catalog.TEMPLE_QUEUE else ("%d en file" % action["craft_count"] if action["craft_count"] > 0 else "")
	action["bubble"] = [Catalog.ADEPT[deity]["name"], _mana_text(cost), not action["poor"], why,
		"Prie au temple : +1 %s / s." % res_name]


## Portrait du HUD d'une unité (assets/baked/hud/portraits) : son rôle, l'Ingénieur sinon.
static func _sprite_key(u: Unit) -> String:
	return u.role if ResourceLoader.exists("res://assets/baked/hud/portraits/%s.png" % u.role) else "engineer"


## « 100 Discipline (260) » : coût en mana et réserve actuelle.
static func _mana_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in cost:
		parts.append("%d %s (%d)" % [cost[k], Catalog.RES_INFO[k]["name"], floori(GameState.res[k])])
	return " + ".join(parts)


## « 3/5 Cuivre + 5/5 Fer » : ingrédients d'une recette présents dans le réseau des coffres.
static func _box_text(items: Array, cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in cost:
		parts.append("%d/%d %s" % [mini(Production.count_in(items, k), int(cost[k])), cost[k], Simulation.Recipes.name_of(k)])
	return " + ".join(parts)


## Le stock couvre-t-il le coût d'une recette ?
static func _stock_ok(cost: Dictionary) -> bool:
	for k: String in cost:
		if Simulation.ItemStorage.count(k) < int(cost[k]):
			return false
	return true


## « 5 Cuivre (3/5) + 5 Fer (5/5) » : coût et quantités disponibles dans le stock.
static func _stock_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in cost:
		parts.append("%d %s (%d)" % [cost[k], Simulation.Recipes.name_of(k), Simulation.ItemStorage.count(k)])
	return " + ".join(parts)


static func _act(id: String, icon: String, label: String, key: String, title: String, run: Callable,
		disabled := false, active := false, cooldown := "") -> Dictionary:
	return {"id": id, "icon": icon, "label": label, "key": key, "title": title, "disabled": disabled, "active": active,
		"cooldown": cooldown, "run": run}


# ---------------------------------------------------------------- Statuts

static func format_assault() -> String:
	if GameState.ended:
		return "Sanctuaire perdu" if GameState.core_hp <= 0.0 else "Assauts terminés"
	if not GameState.orb_active:
		return "Au réveil de l’Ancre"
	var due := GameState.next_wave
	if due == 0.0 and not GameState.spawn_queue.is_empty() and not GameState.enemies.any(func(e: Variant) -> bool: return not e.beast):
		due = GameState.spawn_queue[0]["at"]
	if due == 0.0:
		return "Assaut en cours"
	var t := maxi(0, ceili(due - GameState.sim_time))
	# Assaut lointain (un autre jour) : on annonce le jour plutôt qu'un compte à rebours.
	if DayNight.day(due) != DayNight.day(GameState.sim_time) and t > 120:
		return "Jour %d au matin" % DayNight.day(due)
	return "%02d:%02d" % [t / 60, t % 60]


## Jour, heure et météo du bandeau : {"day", "time", "time_icon", "weather", "next"} ; "next" annonce le
## prochain changement de temps (« Pluie 11:30 »), ou "" si rien ne change dans la journée qui vient.
static func sky_status() -> Dictionary:
	var t := GameState.sim_time
	var lbl := DayNight.label(t)
	var icon := "moon" if lbl == "nuit" else "dawn" if lbl == "aube" or lbl == "crépuscule" else "sun"
	var f := Weather.forecast()
	var next := "" if f.is_empty() else "%s %s" % [Weather.NAMES[f["kind"]], DayNight.clock(float(f["at"]) + 0.01)]
	return {"day": "Jour %d" % DayNight.day(t), "time": DayNight.clock(t), "time_icon": icon,
		"weather": Weather.NAMES[Weather.kind()], "next": next}


static func dig_hits(sim: Simulation, cell: Dictionary) -> int:
	return sim.state().dig_hits.get(Vector2i(cell["i"], cell["j"]), 0)


static func dig_status(sim: Simulation, cell: Dictionary) -> String:
	var block := sim.state().block_definition(cell["i"], cell["j"])
	if block.is_empty():
		return "Bloc non minable"
	var label: String = block.get("mining_label", "Creuse : " + block["material_name"])
	var seal := sim.state().seal_needed(cell["i"], cell["j"])
	if seal != "":
		return "%s · recherche « %s » requise" % [block["material_name"], Catalog.RESEARCH[seal]["name"]]
	return "%s · %d / %d" % [label, dig_hits(sim, cell), block["resistance"]]


static func adept_status(sim: Simulation, u: Unit) -> String:
	var j: Variant = u.job
	if u.role == Oublieux.ROLE:
		return "Ramasse ce qui est tombé · %d / %d sur lui · n’obéit à aucun ordre" % [Oublieux.load_of(u), Oublieux.CAPACITY]
	if Catalog.is_mage(u.role):
		return Catalog.MAGE[u.role]["status"]
	if j == null:
		return Catalog.FIGHT[u.role]["status"] if Catalog.FIGHT.has(u.role) else "En attente d’ordres"
	if j["type"] == "pray_pylon":
		if not u.working:
			return "Se rend au Pylône de Merenor"
		var n: int = (j["pylon"].get("praying", []) as Array).size()
		return "Canalise le Pylône de Merenor · %d / 4 dieux" % n
	if j["type"] == "pray":
		var t: Building = j["temple"]
		if u.working:
			return "Prie au %s · +%s %s / s" % [t.def()["name"], num_fr(Simulation.pray_rate(u, t)), Catalog.RES_INFO[Catalog.DEITY_RES[t.def()["deity"]]]["name"]]
		return "Se rend au " + t.def()["name"]
	if j["type"] == "dig":
		if not u.carrying.is_empty():
			return "Transporte sa récolte"
		return "Mine · 1 ressource toutes les %s s" % num(Simulation.adept_mining_seconds(u)) if u.working else "Se rend au bloc"
	if j["type"] == "staff":
		return staff_status(u)
	return "En attente d’ordres"


## Statut d'une unité affectée à un bâtiment (poste, transport, minage).
static func staff_status(u: Unit) -> String:
	var j: Dictionary = u.job
	var name: String = (j["building"] as Building).def()["name"]
	var lot := "%d %s" % [u.carrying["quantity"], Simulation.Recipes.name_of(u.carrying["item"])] if not u.carrying.is_empty() else ""
	match String(j.get("step", "post")):
		"post":
			return ("Au poste · " + name) if u.working else ("Rejoint son poste · " + name)
		"fetch":
			return "Va chercher %d %s pour le %s" % [j["fetch"]["qty"], Simulation.Recipes.name_of(j["fetch"]["item"]), name]
		"deliver":
			return "Transporte %s au dépôt" % lot
		"return":
			return "Rapporte %s à l’entrepôt" % lot if j["building"].type == "warehouse" else "Rapporte %s au coffre bleu · %s" % [lot, name]
		"mine":
			return "Mine pour le %s · lot %d / %d" % [name, int(j.get("mined", 0)), Catalog.MINE_BATCH]
	return name


static func unit_status(sim: Simulation, u: Unit) -> String:
	if u.hidden:
		if u.role == "engineer" and GameState.in_capsule:
			return "Dans la capsule · E : Sortir" if Capsule.powered() else "Dans la capsule éteinte…"
		return "Franchit le portail…"
	if Catalog.is_adept(u):
		return adept_status(sim, u)
	if u.role == "engineer":
		if GameState.hud_mode == "build" and not GameState.hud_build_type.is_empty():
			var D: Dictionary = Catalog.BUILDINGS[GameState.hud_build_type]
			return "Placez : %s · %s" % [D["name"], Catalog.cost_text(Catalog.building_cost(GameState.hud_build_type))]
		if u.build_job != null:
			var b: Building = u.build_job
			return "Construction · %s · %d %%" % [b.def()["name"], floori(b.progress / b.def()["time"] * 100.0)]
		if u.job != null and u.job["type"] == "bless_pylon":
			var bl := float(u.job["pylon"].get("blessing", 0.0))
			var run := float(u.job["pylon"].get("bless_run", 0.0))
			return "Bénit le Pylône de Merenor · canalisé dans %d s · répit %d s" % [ceili(Pylons.BLESS_CHANNEL - run), floori(bl)] \
				if u.working else "Se rend au Pylône de Merenor"
		if u.job != null and u.job["type"] == "anchor_pray":
			return "Prie à l’Ancre · répare %s PV / s · +%s de chaque mana / s" % [num(Simulation.ANCHOR_REPAIR), num(Simulation.ANCHOR_PRAY)] \
				if u.working else "Se rend à l’Ancre pour prier"
		if u.orb_job:
			return "Réactivation de l’Ancre · %d %%" % floori(GameState.orb_progress / ORB_TIME * 100.0)
		if u.job != null and u.job["type"] == "dig":
			return dig_status(sim, u.job["cell"])
		if u.job != null and u.job["type"] == "pray":
			var t: Building = u.job["temple"]
			if u.working:
				return "Médite au %s · +%s %s / s" % [t.def()["name"], num_fr(Simulation.pray_rate(u, t)), Catalog.RES_INFO[Catalog.DEITY_RES[t.def()["deity"]]]["name"]]
			return "Se rend au " + t.def()["name"]
		if GameState.hud_menu == "build":
			return "Choisissez un bâtiment à construire"
		if GameState.hud_mode == "place":
			return "Cliquez une case pour poser : %s · clic droit pour arrêter" % Simulation.Recipes.name_of(GameState.hud_place_item)
		if GameState.hud_menu == "place":
			return "Choisissez une défense à poser"
		if not GameState.orb_active:
			return "L’Ancre est éteinte · clic droit dessus (ou R) pour la réactiver"
	if GameState.hud_mode == "move":
		return "Choisissez une destination"
	if u.stance == "hold":
		return "Tient sa position"
	return "Prêt à recevoir vos ordres"


static func building_status(b: Building) -> String:
	var D := b.def()
	if not b.complete:
		return "Construction · %d %%" % floori(b.progress / D["time"] * 100.0)
	var deity: String = D["deity"]
	if not deity.is_empty():
		var r: String = Catalog.RES_INFO[Catalog.DEITY_RES[deity]]["name"]
		var n := 0
		var rate := 0.0
		for u in GameState.units:
			if u.alive() and u.working and u.job != null and u.job.get("temple") == b:
				n += 1
				rate += Simulation.pray_rate(u, b)
		return "Adepte de %s · %d %s · %d en prière (+%s %s / s)" % [Catalog.DEITY_NAMES[deity], Catalog.SUMMON_COST, r, n, num_fr(rate), r]
	if Production.staffed(b):
		var role := Production.staff_role(b)
		var posts := "Postes %d / %d" % [Production.members(b, "worker").size(), Catalog.STAFF_MAX]
		if Production.has_chests(b) and b.type not in ["warehouse", "eglise"]:
			posts += " · mineurs %d / %d" % [Production.members(b, "miner").size(), Catalog.MINERS_MAX]
		if b.type == "warehouse":
			return ("Sélectionnez les objets à maintenir en stock · " + posts) if Production.source_open(b) else "Affectez un adepte de Sigil par clic droit pour ouvrir le dépôt."
		if Production.at_post(b) == 0:
			return "À l’arrêt · un adepte de %s (ou l’Ingénieur) requis au poste · clic droit avec l’unité · %s" % [Catalog.DEITY_NAMES[role], posts]
		var speed := "×%d" % Production.at_post(b)
		if b.type == "caserne":
			return "Entraînement %s · %s · file %d / %d · %s" % [speed, Catalog.cost_text(Catalog.CASERNE_COST), b.queue.size(), Catalog.CASERNE_QUEUE, posts]
		if b.type == "ecole":
			return "Formation des mages %s · %s et un bâton à focale chacun · file %d / %d · %s" % [speed, Catalog.cost_text(Catalog.ECOLE_COST), b.queue.size(), Catalog.CASERNE_QUEUE, posts]
		if Simulation.Recipes.has_station(b.type):
			if b.recipe == "":
				return "Choisissez une recette · %s" % posts
			var cost: Dictionary = Simulation.Recipes.RECIPES[b.type][b.recipe]
			var state := "%d %%" % floori(b.craft / Simulation.Recipes.craft_time(b.type) * 100.0) \
				if Production.has_items(b.input_box, cost) else "attend : " + _box_text(b.input_box, cost)
			return "Fabrique %s %s · %s · %s" % [Simulation.Recipes.name_of(b.recipe), speed, state, posts]
		if b.type == "eglise":
			return "%s · %s" % [Oublieux.status(b), posts]
		if b.type != "soulwell":
			return "En activité %s · %s" % [speed, posts]
	if b.type == "eglise":
		return Oublieux.status(b)
	if b.type == "bedroom":
		return "Loge %d Exilés de plus" % Catalog.POP_PER_BEDROOM
	if b.type == "soulwell":
		var n := GameState.fallen.size()
		if n == 0:
			return "Aucune unité tombée pour l’instant"
		return "%d âme%s à rappeler · coût initial × niveau en Vie" % [n, "s" if n > 1 else ""]
	return "Achevé · débloqué par le " + Catalog.BUILDINGS[D["requires"]]["name"]


# ---------------------------------------------------------------- updateHUD

## Textes et valeurs du HUD (updateHUD) : mêmes clés que tools/baker/hud.js (readHUD).
static func view(sim: Simulation) -> Dictionary:
	if GameState.hud_building and not GameState.buildings.has(GameState.hud_building):
		GameState.hud_building = null
	var alive := alive_selected()
	var u: Unit = alive[0] if not alive.is_empty() else null
	var anchor := GameState.anchor_selected
	var B: Building = selected_building() if not anchor and u == null else null
	var v := {}
	v["wave"] = str(GameState.wave) if GameState.wave > 0 else "—"
	# Escouades de l'assaut en cours (sorties / total), tant qu'il en reste sur le terrain ou en file.
	if GameState.wave_squads > 1 and (not GameState.spawn_queue.is_empty() or GameState.enemies.any(func(e: Variant) -> bool: return not e.beast and e.hp > 0.0)):
		v["wave"] += " · escouade %d/%d" % [GameState.squads_out, GameState.wave_squads]
	v["sky"] = sky_status()
	var res := {}
	for k in Catalog.RES_ORDER:
		res[k] = str(floori(GameState.res[k]))
	v["res"] = res
	v["resource_rates"] = Simulation.resource_rates()
	v["menace"] = str(GameState.menace)
	var tier := Catalog.menace_tier(GameState.menace)
	var wave_stats := Catalog.menace_stats(tier)
	var portal_stats := Catalog.menace_stats(tier, true)
	v["menace_tooltip"] = ("Menace %d · palier %d\nVagues : +%d ennemis · composition +%d vagues\nPV ×%.2f · dégâts ×%.2f · armure +%d\nStrazhar : dès la vague effective 8 ou %d menace ; +1 tous les %d paliers après %d\nPylônes de Merenor : meute de %d à %d bêtes dont un alpha ×%d, renaissance en %d s\nPV ×%.2f · dégâts ×%.2f\nLa nuit : squelettes levés dehors, et %d chiens lâchés par chaque pylône non canalisé relié à l’Ancre\nLa menace monte à chaque ennemi d'assaut abattu, selon son type (fanatique 1, bouclier 5, Strazhar 12).\nVagues : menace figée au lancement. Pylônes : menace relue à chaque renaissance." % [
		GameState.menace, tier, Catalog.MENACE_WAVE["count"] * tier,
		floori(float(tier) / Catalog.MENACE_WAVE["composition_step"]), wave_stats["hp"], wave_stats["damage"], wave_stats["armor"],
		Catalog.STRAZHAR_MENACE, Catalog.MENACE_WAVE["champion_step"], Catalog.MENACE_WAVE["champion_start"],
		Pylons.PACK_MIN, Pylons.PACK_MAX, int(Pylons.ALPHA), int(Pylons.RESPAWN), portal_stats["hp"], portal_stats["damage"], Night.raid_size(tier)])
	v["population"] = "%d/%d" % [Simulation.pop_used(), Simulation.pop_cap()]
	if anchor:
		v["chosen"] = "Ancre tyrienne"
	elif u and u.squad_capacity > 0 and alive.all(func(member: Unit) -> bool: return member.squad == u.squad):
		v["chosen"] = "%s · %d/%d" % [Catalog.ADEPT[u.role]["name"], Simulation.squad_survivors(u).size(), u.squad_capacity]
	elif alive.size() > 1:
		v["chosen"] = "%d Exilés" % alive.size()
	elif u:
		v["chosen"] = u.name
	else:
		v["chosen"] = B.def()["name"] if B else "Aucune sélection"
	var lv := ""
	# L'Ingénieur n'a plus de niveaux : pas de ligne NIV. / XP pour lui.
	if u and alive.size() == 1 and not u.hidden and u.role != "engineer":
		lv = " · NIV. %d · %d / %d XP" % [Catalog.lvl(u), floori(u.xp), Catalog.xp_need(Catalog.lvl(u))]
	if anchor:
		v["kind"] = "SANCTUAIRE · ANCRE"
	elif B:
		v["kind"] = "BÂTIMENT" + (" · TEMPLE" if B.is_temple() else "")
	elif Catalog.is_adept(u):
		v["kind"] = "ÉGLISE · OUBLIEUX" if u.role == Oublieux.ROLE else "MAGE CRISTALLISÉ" + lv if Catalog.is_mage(u.role) else ("COMBATTANT" if Catalog.FIGHT.has(u.role) and Catalog.ADEPT[u.role]["task"] == "fight" else "ADEPTE · " + u.role.to_upper()) + lv
	elif u and u.hidden:
		v["kind"] = "PORTAIL · ÉMERGENCE"
	elif u and u.role == "engineer":
		v["kind"] = "EXILÉ · SOUTIEN" + lv
	elif u:
		v["kind"] = "EXILÉ · COMBATTANT" + lv
	else:
		v["kind"] = "SANCTUAIRE"
	var hp := 0.0
	var max_hp := 0.0
	if anchor:
		hp = GameState.core_hp
		max_hp = 100.0
	else:
		for o in alive:
			hp += o.hp
			max_hp += o.max_hp
	v["health_label"] = "Intégrité de l’Ancre" if anchor else "Points de vie"
	if B:
		v["health_pct"] = 100.0 if B.complete else B.progress / B.def()["time"] * 100.0
	else:
		v["health_pct"] = maxf(0.0, hp / max_hp) * 100.0 if max_hp > 0.0 else 0.0
	if anchor:
		v["health_text"] = "Intégrité : %d %%" % ceili(hp)
	elif B:
		v["health_text"] = "Achevé" if B.complete else "En construction"
	else:
		v["health_text"] = "%d / %s" % [ceili(hp), num(max_hp)] if max_hp > 0.0 else "—"
	if anchor:
		if GameState.orb_active:
			v["status"] = "Éveillée · clic droit avec l’Ingénieur pour prier (+3 de chaque mana / s)"
		elif GameState.orb_owner:
			v["status"] = "Réactivation · %d %%" % floori(GameState.orb_progress / ORB_TIME * 100.0)
		else:
			v["status"] = "Éteinte · l’Ingénieur doit la réactiver"
	elif B:
		v["status"] = building_status(B)
	elif u:
		v["status"] = unit_status(sim, u)
	else:
		v["status"] = "Cliquez une unité, un bâtiment ou l’Ancre"
	v["anchor_details"] = anchor
	v["assault"] = format_assault() if anchor else ""
	var base := 0
	if u:
		base = Catalog.attack_damage(u)
	v["damage"] = "—" if u == null or B or base == 0 else str(roundi((base + Catalog.lvl_bonus(u)) * Catalog.damage_mult(u)))
	v["armor"] = str(Catalog.armor(u)) if u and not B else "—"
	var speed := 3.45 if u and u.role == "guard" else (7.6 if Catalog.is_adept(u) else 15.2)
	v["speed"] = num_fr(speed) if u and not B else "—"
	if B:
		v["lore"] = B.def()["lore"]
	elif u:
		v["lore"] = Catalog.ADEPT[u.role]["lore"] if Catalog.ADEPT.has(u.role) else Catalog.HUD_LORE.get(u.role, Catalog.HUD_LORE["guard"])
	else:
		v["lore"] = "Un serment veille encore sur ces pierres."
	# Écart voulu D13 : portée d'attaque, à côté des dégâts.
	v["range"] = "—" if u == null or B or base == 0 else num_fr(Catalog.unit_reach(u))
	v["portrait_enabled"] = anchor or u != null or B != null
	v["portrait_key"] = "anchor" if anchor else (portrait_key(u) if u else (B.def().get("portrait", "bld-" + B.type) if B else "empty"))
	v["enemy"] = false
	var foe := selected_enemy() if not anchor and u == null and B == null else null
	if foe:
		_enemy_view(v, foe)
	elif not anchor and u == null and B == null and GameState.hud_grove != null:
		_grove_view(v, sim.state().lodes)
	return v


## Fiche du bosquet pétrifié (ou du filon illimité, `lodes` : TerrainState.lodes) sélectionné (GameState.hud_grove).
static func _grove_view(v: Dictionary, lodes: Dictionary = {}) -> void:
	if lodes.has(GameState.hud_grove):
		_lode_view(v, String(lodes[GameState.hud_grove]))
		return
	v["chosen"] = "Bosquet pétrifié"
	v["kind"] = "GISEMENT · BOIS NOIR"
	v["status"] = "Clic droit avec un adepte : récolte"
	v["health_label"] = "Bois noir"
	v["health_pct"] = 100.0
	v["health_text"] = "Inépuisable"
	for k: String in ["damage", "range", "armor", "speed"]:
		v[k] = "—"
	v["lore"] = "Arbres changés en pierre, au bois noir inépuisable."
	v["portrait_enabled"] = true
	v["portrait_key"] = "grove"


## Fiche d'un filon illimité sélectionné (GameState.hud_grove, origine dans TerrainState.lodes).
static func _lode_view(v: Dictionary, item: String) -> void:
	var name := String(preload("res://data/mineable_blocks.gd").TYPES.get(item, {}).get("material_name", item))
	v["chosen"] = "Filon de %s" % name.to_lower() if item != "rock" else "Filon de pierre"
	v["kind"] = "GISEMENT · %s" % name.to_upper()
	v["status"] = "Clic droit avec un adepte : minage"
	v["health_label"] = name
	v["health_pct"] = 100.0
	v["health_text"] = "Inépuisable"
	for k: String in ["damage", "range", "armor", "speed"]:
		v[k] = "—"
	v["lore"] = "Veine affleurant du sol, qui ne s’épuise jamais."
	v["portrait_enabled"] = true
	v["portrait_key"] = "lode-" + item


## Ennemi sélectionné encore en vie (écart voulu D14), sinon null (et la sélection est oubliée).
static func selected_enemy() -> Enemy:
	var e := GameState.hud_enemy
	if e and (not e.alive() or not GameState.enemies.has(e)):
		GameState.hud_enemy = null
	return GameState.hud_enemy


## Clé du portrait d'une unité : son rôle, « engineer-bare » pour l'Ingénieur qui a perdu son armure,
## « engineer-exil » tant que la capsule ne lui a pas remis la combinaison.
static func portrait_key(u: Unit) -> String:
	if u.role == "engineer" and u.unarmored:
		return "engineer-exil" if TyrienArt.ragged() else "engineer-bare"
	return u.role


## Fiche d'un ennemi sélectionné : identité, points de vie, statistiques, légende, portrait.
static func _enemy_view(v: Dictionary, e: Enemy) -> void:
	var I: Dictionary = Catalog.ENEMY_INFO.get(e.kind, Catalog.ENEMY_INFO["creep"])
	v["enemy"] = true
	v["chosen"] = I["name"]
	v["kind"] = I["kind"]
	if e.stun > 0.0:
		v["status"] = "Étourdi"
	elif e.slow_until > GameState.sim_time:
		v["status"] = "Ralenti par les flammes"
	else:
		v["status"] = "Marche sur l’Ancre"
	v["health_pct"] = maxf(0.0, e.hp / e.max_hp) * 100.0
	v["health_text"] = "%d / %s" % [ceili(e.hp), num(e.max_hp)]
	v["damage"] = num(e.damage)
	v["range"] = num_fr(e.reach)
	v["armor"] = num(e.armor)
	v["speed"] = num_fr(e.speed)
	v["lore"] = I["lore"]
	v["portrait_enabled"] = true
	v["portrait_key"] = "enemy-" + e.kind


## Familles du menu Construire : [id, nom, icône, bâtiments]. Un bâtiment absent de la liste tombe dans « Utilitaires ».
const BUILD_FAMILIES := [
	["temples", "Temples", "rune", ["sigil", "aether", "medeina", "indra"]],
	["raw", "Matières premières", "wood", ["scierie", "forge"]],
	["production", "Production", "hammer", ["workshop", "archerie", "creuset", "etabli"]],
	["utility", "Utilitaires", "people", ["bedroom", "eglise", "library", "warehouse"]],
	["military", "Militaire", "sword", ["caserne", "soulwell", "ecole"]],
]


static func build_family_of(type: String) -> String:
	for f: Array in BUILD_FAMILIES:
		if type in f[3]:
			return f[0]
	return "utility"


## Bâtiments débloqués d'une famille, dans l'ordre du catalogue ; les verrouillés sont masqués.
static func family_buildings(family: String) -> Array[String]:
	var out: Array[String] = []
	for type: String in Catalog.BUILDINGS:
		if build_family_of(type) == family and unlocked(type):
			out.append(type)
	return out


## Onglets du menu Construire : une famille n'apparaît qu'avec au moins un bâtiment débloqué.
## Touches 1 à 5 dans le menu de l'Ingénieur ; aucune depuis la capsule (les chiffres y choisissent les groupes).
static func _build_family_tabs(A: Array[Dictionary], keys: bool) -> void:
	var shown: Array[String] = []
	for f: Array in BUILD_FAMILIES:
		if not family_buildings(f[0]).is_empty():
			shown.append(f[0])
	if not GameState.hud_build_family in shown:
		GameState.hud_build_family = shown[0] if not shown.is_empty() else "temples"
	for f: Array in BUILD_FAMILIES:
		var fam: String = f[0]
		if not fam in shown:
			continue
		var n := family_buildings(fam).size()
		var open_tab := func() -> void:
			GameState.hud_build_family = fam
			if GameState.hud_mode == "build" and build_family_of(GameState.hud_build_type) != fam:
				GameState.hud_mode = ""
				GameState.hud_build_type = ""
		A.append(_act("bfam-" + fam, f[2], f[1], str(shown.find(fam) + 1) if keys else "",
			"%s · %d bâtiment(s) disponible(s)" % [f[1], n], open_tab, false, GameState.hud_build_family == fam))
		A[-1]["bubble"] = [f[1], "", true, ""]


## Boutons de construction de l'onglet ouvert (bâtiments débloqués seulement).
static func _build_actions(A: Array[Dictionary], sim: Simulation) -> void:
	for type: String in family_buildings(GameState.hud_build_family):
		A.append(_build_action(type, sim))


## Touche d'un bâtiment d'un autre onglet : ouvre son onglet et l'arme (raccourcis inchangés).
static func build_key(sim: Simulation, k: String) -> bool:
	for type: String in Catalog.BUILDINGS:
		if Catalog.BUILDINGS[type]["key"] == k and unlocked(type):
			GameState.hud_build_family = build_family_of(type)
			var a := _build_action(type, sim)
			if not a["disabled"]:
				(a["run"] as Callable).call()
			return true
	return false


static func _build_action(type: String, sim: Simulation) -> Dictionary:
	var D: Dictionary = Catalog.BUILDINGS[type]
	var ok := unlocked(type)
	var cost := Catalog.building_cost(type)
	var title: String = D["name"] + " · " + Catalog.cost_text(cost)
	if not ok:
		title += " · " + lock_reason(type)
	if D["size"] == 2:
		title += " · 2 × 2"
	var a := _act("b-" + type, D["icon"], _temple_prefix.sub(D["name"], "T. ") + " · " + Catalog.short_cost(cost), D["key"], title,
		func() -> void: sim.arm_build(type), not ok or not Catalog.can_pay(cost),
		GameState.hud_mode == "build" and GameState.hud_build_type == type)
	a["build_type"] = type
	a["locked"] = not ok
	return a
