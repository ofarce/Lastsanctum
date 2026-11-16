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


## unlocked (buildings.js) : sans prérequis, ou un bâtiment requis achevé.
static func unlocked(type: String) -> bool:
	var r: String = Catalog.BUILDINGS[type]["requires"]
	if r.is_empty():
		return true
	for b in GameState.buildings:
		if b.type == r and b.complete:
			return true
	return false


## ownTemples (adepts.js) : temples achevés du dieu de l'adepte.
static func own_temples(u: Unit) -> Array[Building]:
	var out: Array[Building] = []
	for b in GameState.buildings:
		if b.complete and b.def()["deity"] == u.role:
			out.append(b)
	return out


static func can_summon_hero() -> bool:
	return not GameState.ended and GameState.orb_active and Catalog.can_pay(Catalog.HERO_COST)


static func summon_cost(b: Building) -> Dictionary:
	return {Catalog.DEITY_RES[b.def()["deity"]]: Catalog.SUMMON_COST}


static func can_summon_at(b: Building) -> bool:
	return not GameState.ended and b and b.complete and b.is_temple() and Catalog.can_pay(summon_cost(b))


static func can_train(b: Building) -> bool:
	return not GameState.ended and b and b.complete and b.type == "caserne" and b.queue.size() < Catalog.CASERNE_QUEUE \
		and Catalog.can_pay(Catalog.CASERNE_COST)


static func can_revive(b: Building, u: Unit) -> bool:
	return not GameState.ended and b and b.complete and b.type == "soulwell" and not GameState.fallen.is_empty() \
		and Simulation.revivable(u) and Catalog.can_pay(Catalog.revive_cost(u))


# ---------------------------------------------------------------- panelActions

static func panel_actions(sim: Simulation) -> Array[Dictionary]:
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
		A.append(_act("offering", "menace", "Offrande · +50 menace", "o",
			"Offrande tyrienne · " + Catalog.cost_text(Catalog.ANCHOR_MENACE_COST) + " · +50 menace · Réutilisable",
			sim.offer_menace, not Simulation.can_offer_menace()))
		return A
	if u == null and B:
		if not B.complete:
			return A
		for id: String in Catalog.RESEARCH:
			var research: Dictionary = Catalog.RESEARCH[id]
			if research["building"] != B.type:
				continue
			var done := GameState.research_done.has(id)
			var pending := GameState.research_jobs.has(id)
			var title: String = research["name"] + " · 10 s · " + Catalog.cost_text(Catalog.MINING_COST) + " · +20 menace à l’achèvement"
			if not research["requires"].is_empty():
				var names: PackedStringArray = []
				for required: String in research["requires"]:
					names.append(Catalog.RESEARCH[required]["name"])
				title += " · Prérequis : " + ", ".join(names)
			var action := _act("research-" + id, "mining_seal", research["name"], "r", title,
				func() -> void: sim.start_research(B, id), not Simulation.can_research(B, id))
			action["status"] = "Déjà achevée" if done else ("En cours · %d %%" % int(GameState.research_jobs[id]["progress"] / Catalog.RESEARCH_TIME * 100.0) if pending else "")
			action["completed"] = done
			A.append(action)
		var D := B.def()
		var deity: String = D["deity"]
		if not deity.is_empty():
			var r: String = Catalog.RES_INFO[Catalog.DEITY_RES[deity]]["name"]
			A.append(_act("summon", D["icon"], "Adepte · %d" % Catalog.SUMMON_COST, "i",
				"Invoquer un %s · %d %s · prie au temple : +1 %s / s" % [String(Catalog.ADEPT[deity]["name"]).to_lower(), Catalog.SUMMON_COST, r, r],
				func() -> void: sim.summon_adept(B), not can_summon_at(B)))
		if B.type == "caserne":
			for t: Dictionary in Catalog.CASERNE_UNITS:
				var id: String = t["id"]
				A.append(_act("train-" + id, t["icon"], "%s ×4 · %s" % [t["label"], Catalog.short_cost(Catalog.CASERNE_COST)], t["key"],
					"Former une escouade de 4 · %s · %s · %s s" % [String(Catalog.ADEPT[id]["name"]).to_lower(), Catalog.cost_text(Catalog.CASERNE_COST), num(Catalog.CASERNE_TIME)],
					func() -> void: sim.train_unit(B, id), not can_train(B)))
		if B.type == "soulwell":
			var eligible := GameState.fallen.filter(func(f: Unit) -> bool: return Simulation.revivable(f))
			var last := eligible.slice(maxi(0, eligible.size() - 9))
			last.reverse()
			for i in last.size():
				var f: Unit = last[i]
				A.append(_act("revive-%d" % f.id, "heart", "%s ★%d" % [_adept_prefix.sub(f.name, ""), Catalog.lvl(f)], str(i + 1),
					"Ressusciter %s (niveau %d) · %s" % [f.name, Catalog.lvl(f), Catalog.cost_text(Catalog.revive_cost(f))],
					func() -> void: sim.revive_unit(B, f), not can_revive(B, f)))
		return A
	if u == null or u.hidden:
		return A
	if u.role == "engineer" and GameState.hud_menu == "build":
		for type: String in Catalog.BUILDINGS:
			var D: Dictionary = Catalog.BUILDINGS[type]
			var ok := unlocked(type)
			var title: String = D["name"] + " · " + Catalog.cost_text(D["cost"])
			if not ok:
				title += " · nécessite un " + Catalog.BUILDINGS[D["requires"]]["name"]
			if D["size"] == 2:
				title += " · 2 × 2"
			A.append(_act("b-" + type, D["icon"], _temple_prefix.sub(D["name"], "T. ") + " · " + Catalog.short_cost(D["cost"]), D["key"], title,
				func() -> void: sim.arm_build(type), not ok or not Catalog.can_pay(D["cost"]),
				GameState.hud_mode == "build" and GameState.hud_build_type == type))
		A.append(_act("back", "restart", "Retour", "b", "Revenir aux ordres de l’Ingénieur (B ou Échap)", func() -> void:
			GameState.hud_menu = ""
			GameState.hud_mode = ""))
		return A
	if u.role == "engineer":
		A.append(_act("menu-build", "hammer", "Construire", "b", "Construire un temple ou un bâtiment", func() -> void:
			GameState.hud_menu = "build"))
		if GameState.orb_active:
			A.append(_act("repair", "repair", "Réparer", "r", "Réparer l’Ancre · +15 % d’intégrité", sim.run_ability, u.ability > 0.0, false,
				"%d s" % ceili(u.ability) if u.ability > 0.0 else ""))
		else:
			A.append(_act("orb", "rune", "Réactiver", "r", "Réactiver l’Ancre · %s s" % num(ORB_TIME), func() -> void: sim.order_orb(u),
				false, u.orb_job))
	elif Catalog.prays(u):
		var any_temple := alive.any(func(o: Unit) -> bool: return Catalog.prays(o) and not own_temples(o).is_empty())
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
	A.append(_act("hold", "flag", "Position", "h", "Tenir position", sim.hold, false, u.stance == "hold"))
	A.append(_act("move", "move", "Déplacer", "m", "Déplacer : choisir une destination", sim.arm_move, false, GameState.hud_mode == "move"))
	return A


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
	return "%02d:%02d" % [t / 60, t % 60]


static func dig_hits(sim: Simulation, cell: Dictionary) -> int:
	return sim.state().dig_hits.get(Vector2i(cell["i"], cell["j"]), 0)


static func dig_status(sim: Simulation, cell: Dictionary) -> String:
	var block := sim.state().block_definition(cell["i"], cell["j"])
	if block.is_empty():
		return "Bloc non minable"
	var label: String = block.get("mining_label", "Creuse : " + block["material_name"])
	return "%s · %d / %d" % [label, dig_hits(sim, cell), block["resistance"]]


static func adept_status(sim: Simulation, u: Unit) -> String:
	var j: Variant = u.job
	if j == null:
		return Catalog.FIGHT[u.role]["status"] if Catalog.FIGHT.has(u.role) else "En attente d’ordres"
	if j["type"] == "pray":
		var t: Building = j["temple"]
		if u.working:
			return "Prie au %s · +1 %s / s" % [t.def()["name"], Catalog.RES_INFO[Catalog.DEITY_RES[u.role]]["name"]]
		return "Se rend au " + t.def()["name"]
	if j["type"] == "dig":
		return dig_status(sim, j["cell"])
	return "En attente d’ordres"


static func unit_status(sim: Simulation, u: Unit) -> String:
	if u.hidden:
		return "Franchit le portail…"
	if Catalog.is_adept(u):
		return adept_status(sim, u)
	if u.role == "engineer":
		if GameState.hud_mode == "build" and not GameState.hud_build_type.is_empty():
			var D: Dictionary = Catalog.BUILDINGS[GameState.hud_build_type]
			return "Placez : %s · %s" % [D["name"], Catalog.cost_text(D["cost"])]
		if u.build_job != null:
			var b: Building = u.build_job
			return "Construction · %s · %d %%" % [b.def()["name"], floori(b.progress / b.def()["time"] * 100.0)]
		if u.orb_job:
			return "Réactivation de l’Ancre · %d %%" % floori(GameState.orb_progress / ORB_TIME * 100.0)
		if u.job != null and u.job["type"] == "dig":
			return dig_status(sim, u.job["cell"])
		if u.job != null and u.job["type"] == "pray":
			var t: Building = u.job["temple"]
			if u.working:
				return "Médite au %s · +%d %s / s" % [t.def()["name"], Simulation.pray_rate(u), Catalog.RES_INFO[Catalog.DEITY_RES[t.def()["deity"]]]["name"]]
			return "Se rend au " + t.def()["name"]
		if GameState.hud_menu == "build":
			return "Choisissez un bâtiment à construire"
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
		return "Construction · %d %% · l’Ingénieur doit rester sur le chantier" % floori(b.progress / D["time"] * 100.0)
	var deity: String = D["deity"]
	if not deity.is_empty():
		var r: String = Catalog.RES_INFO[Catalog.DEITY_RES[deity]]["name"]
		var n := 0
		var rate := 0
		for u in GameState.units:
			if u.alive() and u.working and u.job != null and u.job.get("temple") == b:
				n += 1
				rate += Simulation.pray_rate(u)
		return "Adepte de %s · %d %s · %d en prière (+%d %s / s)" % [Catalog.DEITY_NAMES[deity], Catalog.SUMMON_COST, r, n, rate, r]
	if b.type == "caserne":
		return "Entraînement · %s · %s s · file %d / %d" % [Catalog.cost_text(Catalog.CASERNE_COST), num(Catalog.CASERNE_TIME), b.queue.size(), Catalog.CASERNE_QUEUE]
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
	var res := {}
	for k in Catalog.RES_ORDER:
		res[k] = str(floori(GameState.res[k]))
	v["res"] = res
	v["resource_rates"] = Simulation.resource_rates()
	v["menace"] = str(GameState.menace)
	var tier := Catalog.menace_tier(GameState.menace)
	var wave_stats := Catalog.menace_stats(tier)
	var portal_stats := Catalog.menace_stats(tier, true)
	v["menace_tooltip"] = ("Menace %d · palier %d\nVagues : +%d ennemis · composition +%d vagues\nPV ×%.2f · dégâts ×%.2f · armure +%d\nStrazhar : dès la vague effective 8 ou %d menace ; +1 tous les %d paliers après %d\nPortails : toutes les %.2f s · %d créatures vivantes maximum\nPV ×%.2f · dégâts ×%.2f\nVagues : menace figée au lancement. Portails : menace relue à chaque apparition." % [
		GameState.menace, tier, Catalog.MENACE_WAVE["count"] * tier,
		floori(float(tier) / Catalog.MENACE_WAVE["composition_step"]), wave_stats["hp"], wave_stats["damage"], wave_stats["armor"],
		Catalog.STRAZHAR_MENACE, Catalog.MENACE_WAVE["champion_step"], Catalog.MENACE_WAVE["champion_start"],
		Catalog.menace_portal_interval(tier), Catalog.menace_portal_cap(tier), portal_stats["hp"], portal_stats["damage"]])
	v["population"] = str(GameState.units.filter(func(o: Unit) -> bool: return o.alive() and not o.hidden).size())
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
	if u and alive.size() == 1 and not u.hidden:
		lv = " · NIV. %d · %d / %d XP" % [Catalog.lvl(u), floori(u.xp), Catalog.xp_need(Catalog.lvl(u))]
	if anchor:
		v["kind"] = "SANCTUAIRE · ANCRE"
	elif B:
		v["kind"] = "BÂTIMENT" + (" · TEMPLE" if B.is_temple() else "")
	elif Catalog.is_adept(u):
		v["kind"] = ("COMBATTANT" if Catalog.FIGHT.has(u.role) and Catalog.ADEPT[u.role]["task"] == "fight" else "ADEPTE · " + u.role.to_upper()) + lv
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
			v["status"] = "Éveillée · +1 Forge, Vie, Discipline et Savoir / s"
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
	v["damage"] = "—" if u == null or B or base == 0 else str(base + Catalog.lvl_bonus(u))
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
	v["portrait_key"] = "anchor" if anchor else (portrait_key(u) if u else ("bld-" + B.type if B else "empty"))
	v["enemy"] = false
	var foe := selected_enemy() if not anchor and u == null and B == null else null
	if foe:
		_enemy_view(v, foe)
	return v


## Ennemi sélectionné encore en vie (écart voulu D14), sinon null (et la sélection est oubliée).
static func selected_enemy() -> Enemy:
	var e := GameState.hud_enemy
	if e and (not e.alive() or not GameState.enemies.has(e)):
		GameState.hud_enemy = null
	return GameState.hud_enemy


## Clé du portrait d'une unité : son rôle, ou « engineer-bare » pour l'Ingénieur qui a perdu son armure.
static func portrait_key(u: Unit) -> String:
	return "engineer-bare" if u.role == "engineer" and u.unarmored else u.role


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
