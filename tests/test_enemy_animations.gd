extends "res://tests/fight_case.gd"


## Ennemis sans atlas dans le manifeste : l'Œil de la Matrice, ses pupilles et Gorge-Cuivre ont leurs propres
## calques et leur propre vue ; un type à clé « art » (squelette) emprunte l'atlas d'un autre.
static func _own_atlas(kind: String) -> bool:
	return kind not in [OeilMatrice.KIND, OeilMatrice.PUPIL_KIND, "gorge", Archipretre.KIND] and not Catalog.ENEMY[kind].has("art")


func test_all_enemies_have_complete_atlases() -> void:
	for kind: String in Catalog.ENEMY:
		if not _own_atlas(kind):
			var borrowed: String = Catalog.ENEMY[kind].get("art", "")
			check(borrowed.is_empty() or EnemyArt.all().has(borrowed), "%s emprunte un atlas existant" % kind)
			continue
		check(EnemyArt.all().has(kind), "atlas de " + kind)
		if not EnemyArt.all().has(kind):
			continue
		var meta: Dictionary = EnemyArt.all()[kind]
		for action: String in ["idle", "walk", "attack", "death"]:
			var a: Dictionary = meta[action]
			var tex: Texture2D = load(EnemyArt.ROOT + "%s_%s.png" % [kind, action])
			check(tex != null, kind + " " + action)
			check_eq(tex.get_width(), int(a["frame_w"]) * int(a["cols"]))
			check_eq(tex.get_height(), int(a["frame_h"]) * int(a["rows"]))
			check(int(a["count"]) <= int(a["cols"]) * int(a["rows"]))
		# 45 images pour les ennemis de la refonte, 36 pour la faune, les monstres du biome 2 et les squelettes,
		# 24 pour le squelette explosif (il tombe à genoux puis explose).
		check(int(meta["death"]["count"]) >= 24, "chute complète : " + kind)


func test_corpses_are_visual_and_count_menace_once() -> void:
	var sim := game()
	var e := foe("soldier", 10.0, -110.0, 5.0)
	sim.combat.damage(e, 100.0)
	sim.combat.finish_tick(DT, [engineer()])
	check(GameState.enemies.is_empty(), "aucun ennemi mort dans les cibles")
	check_eq(GameState.enemy_corpses.size(), 1)
	check(e.dead and e.died_at == GameState.sim_time)
	var reward: int = Catalog.KILL_MENACE["soldier"]
	check_eq(GameState.menace, reward, "menace du soldat abattu")
	sim.combat.finish_tick(DT, [engineer()])
	check_eq(GameState.menace, reward, "pas de double comptage")
	check_eq(GameState.enemy_corpses.size(), 1, "pas de corps dupliqué")
	GameState.sim_time += EnemyArt.CORPSE_LIFETIME
	sim.combat.finish_tick(DT, [engineer()])
	check(GameState.enemy_corpses.is_empty(), "nettoyage")


func test_corpses_do_not_delay_next_assault_and_reset() -> void:
	var sim := game()
	GameState.orb_active = true
	GameState.next_wave = 0.0
	var e := foe("creep", 10.0, -110.0, 1.0)
	sim.combat.damage(e, 100.0)
	sim.combat.finish_tick(DT, [engineer()])
	# Un assaut par jour : le suivant est fixé au matin (DayNight.next_assault), cadavres ou non.
	check_near(GameState.next_wave, DayNight.next_assault(GameState.sim_time, GameState.wave, sim.state().seed))
	sim.new_game(SEED)
	check(GameState.enemy_corpses.is_empty())


func test_defense_profiles_and_damage_floor() -> void:
	var sim := game()
	var heavy := Enemy.make("shield", 0, -110, 0)
	var light := Enemy.make("scout", 0, -110, 0)
	sim.combat.damage(heavy, 10.0)
	sim.combat.damage(light, 10.0)
	check_near(heavy.max_hp - heavy.hp, 1.5, 1e-6, "au moins 15 % passent")
	check_near(light.max_hp - light.hp, 9.0)
	check(Catalog.ENEMY["strazhar"]["speed"] > Catalog.ENEMY["scout"]["speed"])


func test_attack_records_animation_and_orientation() -> void:
	var sim := game()
	var u := engineer()
	var e := Enemy.make("strazhar", u.x + 1.0, u.z, 0.0)
	GameState.enemies.append(e)
	sim.combat.update_enemies(DT, [u])
	check_eq(e.attack_started, GameState.sim_time)
	check_eq(e.face, -1)
	check(u.hp < u.max_hp)


func test_progressive_roster() -> void:
	var sim := game()
	var seen := {}
	for w in range(1, 9):
		GameState.wave = w - 1
		sim.combat.start_wave()
		for spawn: Dictionary in GameState.spawn_queue:
			seen[spawn["kind"]] = true
			check(spawn["kind"] != "beast", "faune hors assauts")
			if w < 8:
				check(spawn["kind"] != "strazhar", "champion à partir du huitième assaut")
	# Les troupes d'assaut sont celles qui rapportent de la menace (Catalog.KILL_MENACE) ; faune, errants,
	# squelettes de la nuit et boss ne viennent pas en vague.
	for kind: String in Catalog.KILL_MENACE:
		if int(Catalog.KILL_MENACE[kind]) > 0:
			check(seen.has(kind), "renfort présent : " + kind)
	for kind: String in seen:
		check(int(Catalog.KILL_MENACE.get(kind, 0)) > 0, "type d'assaut : " + kind)
	check(not seen.has(Martyre.KIND), "le boss ne vient jamais en vague")
	check(not seen.has(OeilMatrice.KIND), "l'Œil ne vient jamais en vague")
	check(not seen.has(OeilMatrice.PUPIL_KIND), "ses pupilles non plus")


func test_menace_unlocks_strazhar_before_wave_eight() -> void:
	var sim := game()
	for menace: int in [0, Catalog.STRAZHAR_MENACE - 1, Catalog.STRAZHAR_MENACE, 3500]:
		GameState.wave = 0
		GameState.menace = menace
		sim.combat.start_wave()
		var champions := GameState.spawn_queue.filter(func(s: Dictionary) -> bool: return s["kind"] == "strazhar")
		# Effectif et champions supplémentaires suivent les paliers de menace (détaillés dans test_menace).
		var tier := Catalog.menace_tier(menace)
		var extra := maxi(0, floori(float(tier - Catalog.MENACE_WAVE["champion_start"]) / Catalog.MENACE_WAVE["champion_step"]))
		check_eq(champions.size(), 1 + extra if menace >= Catalog.STRAZHAR_MENACE else 0, "Menace %d" % menace)
		check_eq(GameState.spawn_queue.size(), Catalog.MENACE_WAVE["base"] + Catalog.MENACE_WAVE["per_wave"] + Catalog.MENACE_WAVE["count"] * tier, "effectif de la vague 1 au palier %d" % tier)
		if menace >= Catalog.STRAZHAR_MENACE:
			var last := int(GameState.spawn_queue[0]["group"]["expected"]) - 1
			check_eq(GameState.spawn_queue[last]["kind"], "strazhar", "champion en serre-file de la première escouade")
			var e := sim.combat.spawn_enemy(GameState.spawn_queue[last])
			check_eq(e.kind, "strazhar", "apparition effective")
	# Une vague déjà préparée ne change pas quand la Menace monte.
	GameState.wave = 0
	GameState.menace = 0
	sim.combat.start_wave()
	var planned := GameState.spawn_queue.map(func(s: Dictionary) -> String: return s["kind"])
	GameState.menace = 3500
	check_eq(GameState.spawn_queue.map(func(s: Dictionary) -> String: return s["kind"]), planned, "instantané au lancement")
	check(not planned.has("strazhar"), "pas de champion sans Menace")


func test_views_play_attacks_then_hold_final_corpse_frame() -> void:
	var sim := game()
	var world: World = sim.get_node("../World")
	world.fog.refresh(sim.state())
	for kind: String in Catalog.ENEMY:
		if not _own_atlas(kind):
			continue
		var e := Enemy.make(kind, -3, -130, 0)
		e.attack_started = GameState.sim_time - 0.2
		var v := UnitView.new()
		world.ysort.add_child(v)
		v.setup(e, EnemyArt.all()[kind], sim, world)
		v._update()
		var body: Sprite2D = v.get("_body")
		check((body.texture as AtlasTexture).atlas.resource_path.ends_with(kind + "_attack.png"), "attaque : " + kind)
		e.hp = 0.0
		e.dead = true
		e.died_at = GameState.sim_time - 3.0
		v._update()
		var frames: Array = v.get("_enemy_death")
		check(v.visible, "cadavre encore visible : " + kind)
		check(body.texture == frames.back(), "dernière image maintenue : " + kind)
		check(not (v.get("_over") as Node2D).visible, "aucune barre de vie sur le corps")
		v.queue_free()


func test_archer_shoots_an_arrow_at_allies_in_range() -> void:
	var sim := game()
	var u := engineer()
	var e := Enemy.make("archer", u.x + 8.0, u.z, 0.0)
	GameState.enemies.append(e)
	sim.combat.update_enemies(DT, [u])
	check(u.hp < u.max_hp, "cible à huit unités")
	check(GameState.effects.any(func(f: Dictionary) -> bool: return f["type"] == "arrow"), "flèche, pas rayon")
