extends Node
## Capture de l'Église des Oublieux (planches/biomes-batiments-finaux.html, modèle 1) et de son Oublieux
## (planches/biomes-personnages-finaux.html, modèle 5) : une nuit jouée pas à pas. Corps à fouiller et objets
## au sol posés dans la salle ; l'Oublieux sort, ramasse, rapporte au coffre rouge, rentre à l'aube.
## godot --path . res://tests/visual/eglise_capture.tscn
const OUT := "res://tests/visual/out/eglise/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var _world: World
var _sim: Simulation
## Ennemis posés par l'essai, épargnés par le nettoyage des assauts.
var _foes: Array[Enemy] = []


func _process(_d: float) -> void:
	pass  # la caméra suit l'Exilé incarné : ne pas la forcer ici (le calque d'effets se décalerait des sprites)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(seconds: float) -> void:
	var n := int(seconds / 0.04)
	for i in n:
		# Pas d'assaut pendant l'essai : seule la faune neutre reste.
		GameState.spawn_queue.clear()
		GameState.next_wave = 1e9
		GameState.enemies = GameState.enemies.filter(func(e: Enemy) -> bool: return e.neutral or _foes.has(e))
		_sim.tick(0.04)


func _corpse(kind: String, x: float, z: float, loot: Array[String]) -> Enemy:
	var e := Enemy.make(kind, x, z, 1.0)
	e.hp = 0.0
	e.dead = true
	e.died_at = GameState.sim_time - 4.0
	e.loot = loot
	GameState.enemy_corpses.append(e)
	return e


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1500, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	_sim = sim
	sim.new_game(20261114)
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.x = 6.0
	eng.z = -105.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	# Fin d'après-midi du premier jour : la nuit tombe pendant la capture.
	GameState.sim_time = (0.66 - DayNight.START) * DayNight.LENGTH
	GameState.next_wave = 1e9
	var b := Building.create(1, "eglise", 4.0, -116.0)
	b.complete = true
	b.finished_at = -10.0
	GameState.buildings.append(b)
	var ad := sim.spawn("Adepte de Medeina", b.x, b.z, "medeina")
	ad.job = {"type": "staff", "building": b, "post": "worker", "step": "post"}
	var p := Production.post_spot(b, 0)
	ad.x = p.x
	ad.z = p.y
	ad.tx = p.x
	ad.tz = p.y
	world.camera.input_enabled = false
	_world = world
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	_run(2.0)
	_corpse("soldier", -8.0, -104.0, ["ration"])
	_corpse("archer", 14.0, -102.0, ["arrows", "arrows", "arrows", "arrows", "arrows"])
	_corpse("strazhar", 20.0, -110.0, ["iron_sword", "iron_armor"])
	_corpse("creep", -14.0, -110.0, [])
	GameState.ground_items.append({"item": "ichor", "position": Vector2(-2.0, -100.0)})
	GameState.ground_items.append({"item": "acid_gland", "position": Vector2(2.0, -100.0)})
	GameState.ground_items.append({"item": "iron_sword", "position": Vector2(8.0, -98.0)})
	await get_tree().create_timer(0.6).timeout
	print("phase ", DayNight.phase(GameState.sim_time), " · au poste ", Production.at_post(b), " · ", HudModel.building_status(b))
	await _shot("1_jour")
	# Jusqu'à la nuit.
	while DayNight.phase(GameState.sim_time) != "nuit":
		_run(1.0)
	_run(1.0)
	var o := Oublieux.gleaner(b)
	print("nuit · oublieux ", o != null, " · explorés ", world.fog.explored_at(Vector2(-8, -104)), world.fog.explored_at(Vector2(20, -110)), " · ", Oublieux.status(b))
	await _shot("2_sortie")
	for k in 6:
		_run(4.0)
		o = Oublieux.gleaner(b)
		print("t+%d · %s · pos %s · étape %s" % [(k + 1) * 4, Oublieux.status(b), o.pos() if o else Vector2.ZERO, o.job.get("step") if o else "-"])
		if k == 0 or k == 2:
			await _shot("3_ramasse_%d" % k)
	_run(20.0)
	print("coffre ", b.output_box, " · sol ", GameState.ground_items.size(), " · corps ", GameState.enemy_corpses.map(func(e: Enemy) -> String: return "%s%s" % [e.kind, e.loot]))
	await _shot("4_coffre")
	# Jusqu'à l'aube.
	while DayNight.phase(GameState.sim_time) == "nuit":
		_run(2.0)
	_run(12.0)
	print("aube · oublieux dehors ", Oublieux.gleaner(b) != null, " · ", Oublieux.status(b), " · unités ", GameState.units.map(func(u: Unit) -> String: return u.role))
	await _shot("5_aube")
	await _suite(sim, eng, b)
	# Nuit suivante : il ressort ; tué, son chargement tombe et il ne revient que la nuit d'après.
	while DayNight.phase(GameState.sim_time) != "nuit":
		_run(4.0)
	_corpse("soldier", -8.0, -104.0, ["ration", "ration"])
	_run(6.0)
	o = Oublieux.gleaner(b)
	print("nuit 2 · tombés ", GameState.fallen.map(func(f: Unit) -> String: return f.role), " · ennemis ", GameState.enemies.map(func(e: Enemy) -> String: return e.kind), " · vague ", GameState.wave, " · au poste ", Production.at_post(b), " · adepte ", ad.hp, " ", ad.job)
	print("nuit 2 · dehors ", o != null, " · sur lui ", Oublieux.load_of(o) if o else -1)
	if o:
		o.hp = 0.0
	_run(1.0)
	print("tué · dehors ", Oublieux.gleaner(b) != null, " · sol ", GameState.ground_items.size(), " · tombés ", GameState.fallen.size(), " · ", Oublieux.status(b))
	_run(20.0)
	print("même nuit · dehors ", Oublieux.gleaner(b) != null, " · phase ", DayNight.phase(GameState.sim_time))
	while DayNight.phase(GameState.sim_time) == "nuit":
		_run(4.0)
	while DayNight.phase(GameState.sim_time) != "nuit":
		_run(4.0)
	_run(8.0)
	print("nuit 3 · dehors ", Oublieux.gleaner(b) != null, " · ", Oublieux.status(b), " · coffre ", b.output_box.size(), " piles")
	get_tree().quit()


## Recherches du biome 1 et nom du porteur (2026-11-20).
func _suite(sim: Simulation, eng: Unit, church: Building) -> void:
	# Nom du porteur : un Strazhar tombe, l'Exilé le fouille en marchant dessus, puis s'équipe.
	var e := Enemy.make("strazhar", eng.x + 6.0, eng.z, 1.0)
	e.died_at = GameState.sim_time - 4.0
	e.hp = 0.0
	e.dead = true
	Loot.roll(e)
	GameState.enemy_corpses.append(e)
	print("porteur · ", e.bearer, " · butin ", e.loot)
	eng.unarmored = true
	eng.x = e.x
	eng.z = e.z
	eng.tx = e.x
	eng.tz = e.z
	_run(0.5)
	print("sac · ", eng.inventory)
	for i in eng.inventory.size():
		if not eng.inventory[i].is_empty() and Loot.Gear.slot_of(eng.inventory[i]["item"]) != "":
			var slot: String = Loot.Gear.slot_of(eng.inventory[i]["item"])
			print("équipe ", eng.inventory[i]["item"], " → ", Loot.Gear.equip(eng, eng.inventory, i, slot), " · porteur en place ", eng.equipment_owner.get(slot, ""))
			break
	var worn: String = eng.equipment_owner.keys()[0] if not eng.equipment_owner.is_empty() else ""
	if worn != "":
		print("retire → ", Loot.Gear.unequip(eng, worn, eng.inventory, -1, eng.inventory_capacity), " · sac ", eng.inventory)
	# Recherches : coût en bois pris au stock, effets.
	GameState.base_inventory_unlocked = true
	for i in 200:
		Loot.ItemStorage.store(GameState.base_inventory, 100, "wood")
	for k: String in GameState.res:
		GameState.res[k] = 1000.0
	var types := {"workshop": "aether", "soulwell": "medeina", "caserne": "indra"}
	var n := 0
	var built := {}
	for t: String in types:
		var bb := Building.create(50 + n, t, -20.0 + n * 12.0, -128.0)
		bb.complete = true
		bb.finished_at = -10.0
		GameState.buildings.append(bb)
		var u := sim.spawn("Adepte", bb.x, bb.z, types[t])
		u.job = {"type": "staff", "building": bb, "post": "worker", "step": "post"}
		var p := Production.post_spot(bb, 0)
		u.x = p.x
		u.z = p.y
		u.tx = p.x
		u.tz = p.y
		built[t] = bb
		n += 1
	var archer := sim.spawn("Archer", eng.x - 4.0, eng.z + 3.0, "archer")
	var aether := sim.spawn("Adepte", 0.0, -100.0, "aether")
	print("avant · portée archer ", Catalog.unit_reach(archer), " · minage ", Simulation.adept_mining_seconds(aether), " s · bois ", Loot.ItemStorage.count("wood"))
	_run(1.0)
	for id: String in ["gallery_props", "sylviculture", "fletching"]:
		var bb: Building = built[Catalog.RESEARCH[id]["building"]]
		print(id, " · possible ", Simulation.can_research(bb, id), " · ", Catalog.research_cost_text(id))
		sim.start_research(bb, id)
	_run(12.0)
	print("après · faites ", GameState.research_done.keys(), " · portée archer ", Catalog.unit_reach(archer), " · minage ", Simulation.adept_mining_seconds(aether), " s · bois ", Loot.ItemStorage.count("wood"))
	# Sylviculture : un bosquet abattu repousse trois vagues plus tard.
	var st := sim.state()
	var origin: Vector2i = st.wood_left.keys()[0]
	st.fell_grove(origin)
	st.felled_groves[origin] = GameState.wave
	GameState.wave += 2
	sim.regrow_groves()
	var early := st.wood_left.has(origin)
	GameState.wave += 1
	sim.regrow_groves()
	print("bosquet · repoussé à 2 vagues ", early, " · à 3 vagues ", st.wood_left.has(origin))
	aether.hp = 0.0
	await _shot("6_empennage")
	# Barricades : PV, Palissades, un ennemi de mêlée s'arrête pour la frapper, elle cède.
	Loot.ItemStorage.store(GameState.base_inventory, 100, "barricade")
	Loot.ItemStorage.store(GameState.base_inventory, 100, "barricade")
	for i in 100:
		Loot.ItemStorage.store(GameState.base_inventory, 100, "wood")
	var at := Vector2(eng.x + 8.0, eng.z + 6.0)
	for dx: float in [8.0, -8.0, 12.0, -12.0, 4.0]:
		for dz: float in [6.0, -6.0, 10.0, 2.0]:
			if Simulation.Placeables.refusal(sim, "barricade", Vector2(eng.x + dx, eng.z + dz)) == "":
				at = Vector2(eng.x + dx, eng.z + dz)
	print("refus : « ", Simulation.Placeables.refusal(sim, "barricade", at), " » en ", at, " · Exilé en ", eng.pos())
	print("pose ", Simulation.Placeables.place(sim, "barricade", at), " · ", GameState.placed.map(func(o: Dictionary) -> String: return "%s %s/%s" % [o["item"], o.get("hp"), o.get("max_hp")]))
	var lib := Building.create(60, "library", 30.0, -128.0)
	lib.complete = true
	lib.finished_at = -10.0
	GameState.buildings.append(lib)
	var sg := sim.spawn("Adepte", 0.0, 0.0, "sigil")
	sg.job = {"type": "staff", "building": lib, "post": "worker", "step": "post"}
	var lp := Production.post_spot(lib, 0)
	sg.x = lp.x
	sg.z = lp.y
	sg.tx = lp.x
	sg.tz = lp.y
	_run(1.0)
	print("palissades · possible ", Simulation.can_research(lib, "palisades"), " · ", Catalog.research_cost_text("palisades"))
	sim.start_research(lib, "palisades")
	_run(12.0)
	print("après · ", GameState.placed.map(func(o: Dictionary) -> String: return "%s %s/%s" % [o["item"], o.get("hp"), o.get("max_hp")]))
	var o: Dictionary = GameState.placed[0]
	var foe := Enemy.make("creep", float(o["x"]) - 2.6, float(o["z"]), 0.0)
	foe.neutral = false
	foe.hp = 99999.0
	foe.max_hp = foe.hp
	_foes.append(foe)
	GameState.enemies.append(foe)
	for k in 5:
		_sim.tick(0.04)
	_run(3.0)
	print("frappée · ", GameState.placed.map(func(q: Dictionary) -> String: return "%s %s/%s" % [q["item"], q.get("hp"), q.get("max_hp")]), " · ennemi en ", foe.pos())
	await _shot("7_barricade")
	foe.damage = 400.0
	print("cible de l'ennemi : PV ", foe.hp, " · Exilé à ", foe.pos().distance_to(eng.pos()))
	eng.x -= 30.0
	eng.tx = eng.x
	_run(4.0)
	print("cédée · posées ", GameState.placed.size(), " · mur ", sim.state().walls.has(o["cell"]))
	foe.hp = 0.0
	_run(0.2)
	await _ecole(sim, eng)


## École de magie cristallisée, recherche, formation et effets des trois mages (2026-11-20).
func _ecole(sim: Simulation, eng: Unit) -> void:
	eng.x += 30.0
	eng.tx = eng.x
	var well: Building = null
	for bb: Building in GameState.buildings:
		if bb.type == "soulwell":
			well = bb
	for i in 12:
		Loot.ItemStorage.store(GameState.base_inventory, 100, "copper_ingot")
	for i in 3:
		Loot.ItemStorage.store(GameState.base_inventory, 100, "focus_staff")
	for k: String in GameState.res:
		GameState.res[k] = 2000.0
	print("école · débloquée avant ", HudModel.unlocked("ecole"), " (", HudModel.lock_reason("ecole"), ") · recherche possible ", Simulation.can_research(well, "limbo_mastery"), " · ", Catalog.research_cost_text("limbo_mastery"))
	sim.start_research(well, "limbo_mastery")
	_run(12.0)
	print("école · débloquée après ", HudModel.unlocked("ecole"), " · bâton débloqué ", Simulation.recipe_unlocked("focus_staff"))
	var sch := Building.create(70, "ecole", eng.x - 8.0, eng.z - 12.0)
	sch.complete = true
	sch.finished_at = -10.0
	GameState.buildings.append(sch)
	var md := sim.spawn("Adepte", 0.0, 0.0, "medeina")
	md.job = {"type": "staff", "building": sch, "post": "worker", "step": "post"}
	var sp := Production.post_spot(sch, 0)
	md.x = sp.x
	md.z = sp.y
	md.tx = sp.x
	md.tz = sp.y
	for i in 3:
		Loot.ItemStorage.store(sch.input_box, 16, "focus_staff")
	_run(1.0)
	# Place dans la population : les unités des essais précédents s'en vont.
	GameState.units = GameState.units.filter(func(u: Unit) -> bool: return u.role == "engineer" or u.role == "oublieux" or u == md or (u.role == "medeina" and u.job != null))
	print("population ", Simulation.pop_used(), " / ", Simulation.pop_cap())
	for id: String in ["guerisseuse", "chantre", "envouteur"]:
		print("former ", id, " · possible ", HudModel.can_train_unit(sch, id))
		sim.train_unit(sch, id)
	_run(30.0)
	var mages := GameState.units.filter(func(u: Unit) -> bool: return Catalog.is_mage(u.role))
	print("mages · ", mages.map(func(u: Unit) -> String: return "%s %d PV puissance %s" % [u.role, int(u.hp), u.power]), " · coffre bleu ", sch.input_box, " · ", HudModel.building_status(sch))
	if mages.size() < 3:
		return
	# Effets : un allié blessé, un ennemi cuirassé, un archer pour mesurer le bonus de dégâts.
	var k := 0
	for m: Unit in mages:
		m.x = eng.x - 6.0 + k * 6.0
		m.z = eng.z + 6.0
		m.tx = m.x
		m.tz = m.z
		k += 1
	eng.hp = 20.0
	var foe := Enemy.make("shield", eng.x + 14.0, eng.z + 6.0, 99.0)
	foe.hp = 99999.0
	foe.max_hp = foe.hp
	foe.speed = 0.0
	foe.damage = 0.0
	_foes.append(foe)
	GameState.enemies.append(foe)
	var chantre: Unit = mages.filter(func(u: Unit) -> bool: return u.role == "chantre")[0]
	var probe := sim.spawn("Sonde", chantre.x, chantre.z, "aether")
	probe.hidden = true
	_run(0.2)
	var before := foe.hp
	var cx := chantre.x
	chantre.x += 200.0
	Mages.refresh([chantre])
	foe.hexed_until = -INF
	sim.combat.damage(foe, 20.0, probe)
	var plain := before - foe.hp
	before = foe.hp
	chantre.x = cx
	Mages.refresh([chantre])
	foe.hexed_until = -INF
	sim.combat.damage(foe, 20.0, probe)
	var sung := before - foe.hp
	before = foe.hp
	foe.hexed_until = GameState.sim_time + 5.0
	sim.combat.damage(foe, 20.0, probe)
	print("dégâts sur porte-bouclier (armure ", foe.armor, ") · nu ", plain, " · avec Chantre ", sung, " · Chantre + envoûté ", before - foe.hp)
	var hp0 := eng.hp
	_run(3.0)
	print("soin · Exilé ", hp0, " → ", eng.hp, " en 3 s · envoûté ", Mages.hexed(foe), " · mages au travail ", mages.map(func(u: Unit) -> String: return "%s %s" % [u.role, u.working]))
	await get_tree().create_timer(2.0).timeout
	eng.hp = 20.0
	_run(0.12)
	await _shot("8_mages")
	# Recul au contact.
	var g: Unit = mages[0]
	var gx := g.x
	var brute := Enemy.make("creep", g.x + 2.0, g.z, 99.0)
	brute.hp = 99999.0
	brute.speed = 0.0
	brute.damage = 0.0
	_foes.append(brute)
	GameState.enemies.append(brute)
	_run(1.0)
	print("recul · ", g.role, " de x ", gx, " à ", g.x)
	brute.hp = 0.0
	foe.hp = 0.0
	_run(0.2)
	await _biome2(sim, eng)


## Biome 2 (2026-11-20) : roche de vert-de-gris et Sceau de cuivre, tique et chauve-souris.
func _biome2(sim: Simulation, eng: Unit) -> void:
	var st := sim.state()
	var z2 := Biomes.north_z(0) - 60.0
	var j2 := floori(z2 / 4.0)
	var i2 := 0
	for i in range(-40, 40):
		if not st.block_types.has(Vector2i(i, j2)) and not st.cell_clear(i, j2):
			i2 = i
			break
	print("biome en z ", z2, " : ", Biomes.at(z2)["name"], " · roche ", st.block_definition(i2, j2)["material_name"], " ", st.block_definition(i2, j2)["resistance"], " coups · sceau requis « ", st.seal_needed(i2, j2), " » · Temple : ", st.block_definition(20, -30)["material_name"], " ", st.block_definition(20, -30)["resistance"])
	print("minerais du biome 2 · sud ", Biomes.ores_at(1, 0.1), " · nord ", Biomes.ores_at(1, 0.9))
	var counts := {}
	for key: Vector2i in st.block_types:
		if key.y * 4.0 < Biomes.north_z(0) and not st.grove_cells.has(key):
			counts[st.block_types[key]] = int(counts.get(st.block_types[key], 0)) + 1
	print("blocs de minerai posés dans le biome 2 · ", counts)
	var temple := {}
	for key: Vector2i in st.block_types:
		if key.y * 4.0 >= Biomes.north_z(0) and not st.grove_cells.has(key):
			temple[st.block_types[key]] = int(temple.get(st.block_types[key], 0)) + 1
	print("blocs de minerai posés dans le Temple · ", temple, " · filons ", st.lodes.values().filter(func(v: String) -> bool: return true).size(), " dont hors cuivre au sud ", st.lodes.keys().filter(func(o: Vector2i) -> bool: return o.y * 4.0 >= Biomes.north_z(0) and st.lodes[o] != "copper").size())
	eng.unarmored = false
	var cell := {"i": i2, "j": j2, "at": Vector2(i2 * 4.0, z2)}
	sim.set_job(eng, {"type": "dig", "cells": [cell], "index": 0, "cell": cell, "at": cell["at"]})
	print("creuser sans sceau · tâche ", eng.job)
	GameState.mining_seal = true
	var forge := Building.create(80, "forge", eng.x + 10.0, eng.z - 12.0)
	forge.complete = true
	forge.finished_at = -10.0
	GameState.buildings.append(forge)
	var ae := sim.spawn("Adepte", 0.0, 0.0, "aether")
	ae.job = {"type": "staff", "building": forge, "post": "worker", "step": "post"}
	var fp := Production.post_spot(forge, 0)
	ae.x = fp.x
	ae.z = fp.y
	ae.tx = fp.x
	ae.tz = fp.y
	for i in 20:
		Loot.ItemStorage.store(GameState.base_inventory, 100, "copper")
	_run(1.0)
	print("sceau de cuivre · possible ", Simulation.can_research(forge, "copper_seal"), " · ", Catalog.research_cost_text("copper_seal"))
	sim.start_research(forge, "copper_seal")
	_run(12.0)
	sim.set_job(eng, {"type": "dig", "cells": [cell], "index": 0, "cell": cell, "at": cell["at"]})
	print("creuser avec sceau · tâche ", "dig" if eng.job != null and eng.job.get("type") == "dig" else str(eng.job), " · sceau requis « ", st.seal_needed(i2, j2), " »")
	sim.cancel_work(eng)
	eng.tx = eng.x
	eng.tz = eng.z
	var made: Array[Enemy] = []
	var k := 0
	for kind: String in ["tick", "tick", "tick", "bat", "bat", "bat"]:
		var e := Enemy.make(kind, eng.x - 10.0 + k * 4.0, eng.z + (5.0 if kind == "tick" else 8.0), 1.0)
		e.beast = true
		made.append(e)
		_foes.append(e)
		GameState.enemies.append(e)
		k += 1
	eng.hp = eng.max_hp
	_run(3.0)
	await get_tree().create_timer(1.0).timeout
	_run(0.12)
	await _shot("9_faune")
	print("faune · Exilé ", eng.hp, " / ", eng.max_hp, " après 3 s · positions ", made.map(func(e: Enemy) -> String: return "%s %.0f,%.0f" % [e.kind, e.x - eng.x, e.z - eng.z]))
	for e: Enemy in made:
		sim.combat.damage(e, 9999.0, eng)
	_run(0.2)
	print("butin · ", GameState.enemy_corpses.filter(func(c: Enemy) -> bool: return c.kind in ["tick", "bat"]).map(func(c: Enemy) -> String: return "%s %s" % [c.kind, c.loot]))
	_run(2.5)
	await get_tree().create_timer(0.5).timeout
	_run(0.08)
	await _shot("10_faune_morte")
	await _restes(sim, eng)


## Restes du biome 1 (2026-11-20) : modules d'exo, ration, guano, butin du Strazhar et des boss.
func _restes(sim: Simulation, eng: Unit) -> void:
	eng.unarmored = true
	eng.inventory.clear()
	eng.equipment.erase("Module 1")
	eng.equipment.erase("Module 2")
	for kind: String in ["martyre", "oeil", "strazhar"]:
		var e := Enemy.new()
		e.kind = kind
		e.x = eng.x
		e.z = eng.z
		Loot.roll(e)
		print("butin ", kind, " · ", e.loot, " · porteur « ", e.bearer, " » · raretés ", e.loot.map(func(i: String) -> String: return Loot.rarity_name(i)))
	Loot.ItemStorage.store(eng.inventory, 10, "module_veil")
	Loot.ItemStorage.store(eng.inventory, 10, "module_iris")
	for i in 2:
		Loot.ItemStorage.store(eng.inventory, 10, "ration")
	print("équipe voile ", Loot.Gear.equip(eng, eng.inventory, 0, "Module 1"), " · iris ", Loot.Gear.equip(eng, eng.inventory, 1, "Module 2"), " · mauvais emplacement refusé ", not Loot.Gear.equip(eng, eng.inventory, 2, "Module 1"), " · portés ", eng.equipment.get("Module 1"), ", ", eng.equipment.get("Module 2"), " · iris porté ", Loot.iris_worn())
	eng.hp = eng.max_hp
	var src := Enemy.make("creep", eng.x + 50.0, eng.z, 99.0)
	sim.combat.damage(eng, 30.0, src)
	var after_first := eng.hp
	sim.combat.damage(eng, 30.0, src)
	print("voile · PV ", eng.max_hp, " → ", after_first, " (coup absorbé) → ", eng.hp, " (second coup) · se reforme dans ", snappedf(eng.veil_ready_at - GameState.sim_time, 0.1), " s")
	var hp0 := eng.hp
	_run(0.2)
	print("ration · PV ", hp0, " → ", eng.hp, " · rations restantes ", Production.count_in(eng.inventory, "ration"))
	# Guano : un bosquet abattu repousse tout de suite.
	var st := sim.state()
	var origin: Vector2i = st.wood_left.keys()[0]
	st.fell_grove(origin)
	st.felled_groves[origin] = GameState.wave
	GameState.research_done.erase("sylviculture")
	_run(1.5)
	var without := st.wood_left.has(origin)
	Loot.ItemStorage.store(GameState.base_inventory, 100, "guano")
	_run(1.5)
	print("guano · repoussé sans guano ", without, " · avec ", st.wood_left.has(origin), " · guano restant ", Loot.ItemStorage.count("guano"))
	await _biome2_restes(sim, eng)


## Restes du biome 2 (2026-11-20) : Pointes de cuivre, Baume, tique neutre, anguille, teinte de la roche.
func _biome2_restes(sim: Simulation, eng: Unit) -> void:
	var st := sim.state()
	var north := Biomes.north_z(0)
	var lairs := Wildlife.lairs(st, st.seed)
	var counts := {}
	for l: Dictionary in lairs:
		counts[l["kind"]] = int(counts.get(l["kind"], 0)) + 1
	print("repaires · ", counts, " · filons du biome 2 ", st.lodes.keys().filter(func(o: Vector2i) -> bool: return o.y * 4.0 < north).size(), " · bassins du biome 2 ", st.pools.filter(func(p: Dictionary) -> bool: return (p["center"] as Vector2).y < north).size())
	var terrain: Node = _world.get_node_or_null("Terrain")
	if terrain == null:
		for c: Node in _world.get_children():
			if c.has_method("rock_tier_px"):
				terrain = c
	if terrain:
		var rows := {}
		for ky in range(-8, 4):
			var z: float = (float(ky * int(terrain.chunk) - int(terrain.origin.y)) + float(terrain.chunk) * 0.5) / 8.0
			rows[ky] = "z %.0f %s" % [z, "vert-de-gris" if terrain.rock_tier_px(ky * int(terrain.chunk) + int(terrain.chunk) / 2) == 1 else "ardoise"]
		print("roche par rangée de blocs (frontière en z ", north, ") · ", rows)
	# Archer : dégâts avec et sans Pointes de cuivre ; Puits : soin avec et sans Baume.
	var archer := sim.spawn("Archer", eng.x + 300.0, eng.z, "archer")
	var dummy := Enemy.make("creep", eng.x + 300.0, eng.z + 2.0, 99.0)
	dummy.hp = 9999.0
	GameState.research_done.erase("copper_tips")
	sim.combat.damage(dummy, 20.0, archer)
	var plain := 9999.0 - dummy.hp
	GameState.research_done["copper_tips"] = true
	dummy.hp = 9999.0
	sim.combat.damage(dummy, 20.0, archer)
	print("archer · 20 de dégâts → ", plain, " sans Pointes, ", 9999.0 - dummy.hp, " avec")
	GameState.units.erase(archer)
	# Tique neutre et anguille, posées près de l'Exilé comme le ferait Wildlife.
	GameState.units = GameState.units.filter(func(u: Unit) -> bool: return u.role == "engineer")
	eng.hp = eng.max_hp
	eng.equipment.erase("Module 1")
	var tick_lair := {"kind": "tick", "x": eng.x + 12.0, "z": eng.z + 2.0, "beast": null, "empty_since": -1}
	var eel_lair := {"kind": "eel", "x": eng.x - 30.0, "z": eng.z + 2.0, "beast": null, "empty_since": -1}
	Wildlife._spawn(tick_lair)
	Wildlife._spawn(eel_lair)
	var tick: Enemy = tick_lair["beast"]
	var eel: Enemy = eel_lair["beast"]
	_foes.append(tick)
	_foes.append(eel)
	_run(3.0)
	print("tique à 12 unités · Exilé ", eng.hp, " / ", eng.max_hp, " · tique en ", tick.pos() - tick.home, " de son filon")
	eng.x = tick.x - 2.5
	eng.tx = eng.x
	_run(4.0)
	print("tique à 2,5 unités · Exilé ", eng.hp, " / ", eng.max_hp)
	eng.x = eel.x + 10.0
	eng.z = eel.z
	eng.tx = eng.x
	eng.tz = eng.z
	eng.hp = eng.max_hp
	_run(1.5)
	await get_tree().create_timer(1.0).timeout
	_run(0.12)
	await _shot("11_anguille")
	_run(5.0)
	print("anguille à 10 unités · Exilé ", eng.hp, " / ", eng.max_hp, " après 6,5 s · anguille en ", eel.pos() - eel.home)
	sim.combat.damage(eel, 9999.0, eng)
	_run(0.2)
	print("butin anguille · ", GameState.enemy_corpses.filter(func(c: Enemy) -> bool: return c.kind == "eel").map(func(c: Enemy) -> String: return str(c.loot)))
	await _gorge(sim, eng)


## Gorge-Cuivre (2026-11-20) : salle, éveil, Percée, Pluie, sillon, phase III, mort et butin.
func _gorge(sim: Simulation, eng: Unit) -> void:
	var st := sim.state()
	print("salle de la Gorge · ", st.gorge_room, " · biome ", Biomes.at((st.gorge_room as Vector2).y)["name"] if st.gorge_room != null else "-", " · profondeur ", snappedf(Biomes.depth(1, (st.gorge_room as Vector2).y), 0.01) if st.gorge_room != null else -1.0)
	if st.gorge_room == null:
		return
	var c: Vector2 = st.gorge_room
	# La salle n'est praticable qu'une fois sa galerie découverte : l'essai l'ouvre.
	print("salle creusée · centre ", st.is_gallery(c.x, c.y), " · à 20 unités ", st.is_gallery(c.x + 20.0, c.y), st.is_gallery(c.x, c.y - 20.0), " · à 26 unités ", st.is_gallery(c.x + 26.0, c.y))
	_world.terrain_ops.reveal_gallery(c.x, c.y)
	var open := 0
	for a in 16:
		if st.walkable(c.x + cos(a * TAU / 16.0) * 20.0, c.y + sin(a * TAU / 16.0) * 20.0):
			open += 1
	print("salle · points praticables à 20 unités du centre ", open, " / 16")
	GameState.units = GameState.units.filter(func(u: Unit) -> bool: return u.role == "engineer")
	eng.unarmored = false
	eng.max_hp = 100000.0
	eng.hp = eng.max_hp
	eng.x = c.x + 10.0
	eng.z = c.y + 4.0
	eng.tx = eng.x
	eng.tz = eng.z
	Gorge.tick(sim)
	var boss := Gorge.boss()
	_foes.append(boss)
	if not GameState.enemies.has(boss):
		GameState.enemies.append(boss)
	_run(0.5)
	print("éveil · mode ", Gorge.run().get("mode"), " · boss dans les ennemis ", GameState.enemies.has(boss), " · Exilé ", eng.pos(), " vivant ", eng.alive(), " caché ", eng.hidden, " · distance au centre ", eng.pos().distance_to(c), " · état identique ", Gorge.run().get("state") == st, " · neutre ", boss.neutral, " PV ", boss.hp)
	var seen := {}
	var log: PackedStringArray = []
	var last := ""
	var shots := {"open": "12_gorge_percee", "rain": "13_gorge_pluie", "furrow_warn": "14_gorge_sillon"}
	for step in 1500:
		_run(0.04)
		var mode := String(Gorge.run().get("mode", ""))
		if mode != last:
			log.append("%s(%.0f %%)" % [mode, boss.hp / boss.max_hp * 100.0])
			last = mode
			if shots.has(mode) and not seen.has(mode):
				seen[mode] = true
				_run(0.5 if mode != "open" else 0.1)
				await get_tree().create_timer(1.0).timeout
				_run(0.08)
				await _shot(shots[mode])
		# L'essai fait baisser ses PV pour traverser les trois phases.
		if step == 420:
			boss.hp = boss.max_hp * 0.6
		if step == 900:
			boss.hp = boss.max_hp * 0.3
		if log.size() > 44:
			break
	print("modes · ", " → ".join(log))
	print("Exilé · ", int(eng.max_hp - eng.hp), " PV perdus · ennemis appelés ", GameState.enemies.map(func(e: Enemy) -> String: return e.kind).filter(func(k: String) -> bool: return k != "gorge" and k != "croc" and k != "feline" and k != "eel"), " · cuivre au sol ", GameState.ground_items.filter(func(d: Dictionary) -> bool: return d["item"] == "copper").size())
	var hp0 := boss.hp
	boss.hidden = false
	Gorge.run()["mode"] = "idle"
	Gorge.run()["phase"] = 0
	boss.hp = boss.max_hp
	sim.combat.damage(boss, 100.0, eng)
	var closed := boss.max_hp - boss.hp
	boss.hp = boss.max_hp
	Gorge.run()["mode"] = "open"
	sim.combat.damage(boss, 100.0, eng)
	print("100 de dégâts · gueule fermée ", closed, " · gueule ouverte ", boss.max_hp - boss.hp)
	sim.combat.damage(boss, 99999.0, eng)
	_run(2.0)
	await get_tree().create_timer(0.5).timeout
	_run(0.08)
	await _shot("15_gorge_morte")
	print("mort · mode ", Gorge.run().get("mode"), " · butin ", boss.loot.slice(0, 3), "… (", boss.loot.size(), " objets) · barre de boss ", Gorge.active())
