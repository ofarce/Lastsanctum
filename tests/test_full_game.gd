extends "res://tests/econ_case.gd"
## Étape 10 : partie complète jouée par un joueur automatique, uniquement par les entrées du joueur
## (InputController : touches, clics gauche et droit à l'écran ; raccourcis du panneau d'actions).
## Introduction (sortie du portail), réactivation de l'Ancre, quatre temples, adeptes en prière, caserne et
## combattants, Puits des Âmes, creusement jusqu'à une galerie, vagues tenues jusqu'à la 8e ou 15 minutes.
## Invariants vérifiés chaque seconde ; partie rejouée deux fois : journal et état final identiques.

const STEP := Simulation.MAX_DT
const MAX_TIME := 900.0
const ORDER := ["sigil", "indra", "medeina", "aether", "caserne", "soulwell"]

var sim: Simulation
var ic: InputController
var log := PackedStringArray()
var stats := {}
var violations := PackedStringArray()


func test_full_game_by_player_inputs() -> void:
	var a := _play()
	var first_stats := stats.duplicate(true)
	var first_violations := violations.duplicate()
	var b := _play()
	for v in first_violations:
		check(false, v)
	check(first_violations.is_empty(), "aucun invariant violé en %d s de jeu" % roundi(first_stats["time"]))
	var S: Dictionary = first_stats
	print("    bilan : " + JSON.stringify(S))
	print("    jalons : " + " | ".join(a.slice(0, 40)))
	check(S["orb_at"] > 3.0 and S["orb_at"] < 30.0, "Ancre réactivée à la touche R (%.1f s)" % S["orb_at"])
	for t: String in ORDER:
		check(S["built"].has(t), "%s construit (B puis sa touche, clic sur le sol)" % Catalog.BUILDINGS[t]["name"])
	check(S["adepts"] >= 4, "au moins 4 adeptes invoqués (%d)" % S["adepts"])
	check(S["prayer_gain"] > 0.0, "la prière rapporte (+%.0f au-delà de l'Ancre)" % S["prayer_gain"])
	check(S["trained"] >= 2, "au moins 2 combattants entraînés à la caserne (%d)" % S["trained"])
	check(S["dug"] >= 1, "creusement au clic droit (%d case(s))" % S["dug"])
	check(S["galleries"] >= 1, "au moins une galerie révélée (%d)" % S["galleries"])
	check(S["wave"] >= 5, "au moins 5 vagues affrontées (%d)" % S["wave"])
	check(S["kills"] >= 30, "au moins 30 ennemis abattus (%d)" % S["kills"])
	check(S["levels"] >= 1, "au moins une montée de niveau (%d)" % S["levels"])
	check_eq(b, a, "partie rejouée : journal identique")
	check_eq(stats, first_stats, "partie rejouée : bilan identique")


func _play() -> PackedStringArray:
	sim = game()
	ic = sim.get_node("../Input")
	log = PackedStringArray()
	violations = PackedStringArray()
	stats = {"orb_at": -1.0, "built": [], "adepts": 0, "trained": 0, "dug": 0, "galleries": 0, "wave": 0, "kills": 0,
		"levels": 0, "revived": 0, "prayer_gain": 0.0, "time": 0.0, "ended": ""}
	# Partie depuis le tout début : l'Ingénieur sort du portail (game() le sort d'office).
	sim.new_game(SEED)
	sim.combat.log_events = true
	sim.combat.events.clear()
	var eng: Unit = GameState.units[0]
	var next_think := 0.0
	var next_check := 1.0
	var res_prev := 0.0
	var trained_flip := 0
	var dig_cells: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/fixtures/dig_scenario.json"))["cells"]
	var on_ended := func(won: bool) -> void: stats["ended"] = "victoire" if won else "défaite"
	Events.game_over.connect(on_ended)
	while GameState.sim_time < MAX_TIME and not GameState.ended and GameState.wave < 8:
		sim.tick(STEP)
		var t := GameState.sim_time
		if t >= next_check:
			next_check += 1.0
			_invariants()
		if t < next_think:
			continue
		next_think = t + 0.5
		# 1. Réactivation : l'Ingénieur sorti, touche R (bouton Réactiver du panneau).
		if not GameState.orb_active:
			if not eng.hidden and GameState.orb_owner == null:
				_select(eng)
				_key(KEY_R)
				_mark("R : réactivation demandée")
			continue
		if stats["orb_at"] < 0.0:
			stats["orb_at"] = GameState.orb_finished_at
			_mark("Ancre active")
		var idle := eng.alive() and eng.build_job == null and eng.job == null and not eng.orb_job
		# 2. Bâtiments dans l'ordre, dès qu'ils sont payables.
		var todo := ""
		for type: String in ORDER:
			if not GameState.buildings.any(func(b: Building) -> bool: return b.type == type):
				todo = type
				break
		if idle and todo and HudModel.unlocked(todo) and Catalog.can_pay(Catalog.BUILDINGS[todo]["cost"]):
			var site: Variant = _site(todo)
			if site != null:
				_select(eng)
				_key(KEY_B)
				_key(OS.find_keycode_from_string(String(Catalog.BUILDINGS[todo]["key"]).to_upper()))
				ic._left_click(ic.project(site.x, 0.0, site.y), false)
				if GameState.buildings.any(func(b: Building) -> bool: return b.type == todo):
					_mark("chantier %s" % todo)
				continue
		# 3. Creusement vers une galerie quand les temples sont posés et l'Ingénieur libre.
		if idle and todo == "caserne" and stats["galleries"] == 0:
			for c: Array in dig_cells:
				if not sim.state().dug.has(Vector2i(int(c[0]), int(c[1]))):
					_select(eng)
					ic._right_click(ic.project(c[0] * 4.0 + 2.0, 0.0, c[1] * 4.0 + 2.0))
					if eng.job != null:
						_mark("clic droit : creuser %s" % [c])
					break
		# 4. Invocations : 2 adeptes par temple achevé.
		for b: Building in GameState.buildings:
			if b.complete and b.is_temple():
				var n := GameState.units.filter(func(u: Unit) -> bool: return u.role == b.type and u.alive()).size()
				if n < 2 and HudModel.can_summon_at(b):
					_click_building(b)
					var before := GameState.units.size()
					_key(KEY_I)
					if GameState.units.size() > before:
						stats["adepts"] += 1
						_mark("I : adepte de %s" % b.type)
		# 5. Caserne : archer (U) et épée et bouclier (E) en alternance, file de 1.
		for b: Building in GameState.buildings:
			if b.type == "caserne" and b.complete and b.queue.is_empty() and Catalog.can_pay(Catalog.CASERNE_COST):
				_click_building(b)
				_key(KEY_U if trained_flip % 2 == 0 else KEY_E)
				if not b.queue.is_empty():
					trained_flip += 1
					_mark("caserne : %s" % b.queue[0])
		# 6. Puits des Âmes : rappel de la première âme (touche 1).
		for b: Building in GameState.buildings:
			if b.type == "soulwell" and b.complete and not GameState.fallen.is_empty() and Catalog.can_pay(Catalog.revive_cost(GameState.fallen.back())):
				_click_building(b)
				var n := GameState.fallen.size()
				var revive_price: int = Catalog.revive_cost(GameState.fallen.back())["vie"]
				_key(KEY_1)
				if GameState.fallen.size() < n:
					stats["revive_spent"] = stats.get("revive_spent", 0) + revive_price
					stats["revived"] += 1
					_mark("Puits : âme rappelée")
		# 7. Combattants libres : rassemblés à l'entrée de la grotte (clic droit sur le sol).
		var idle_fighters := GameState.units.filter(func(u: Unit) -> bool:
			return u.alive() and Catalog.FIGHT.has(u.role) and u.role != "engineer" and not Catalog.prays(u) and u.job == null \
				and Vector2(u.x, u.z).distance_to(Vector2(0, -84)) > 10.0 and Vector2(u.tx, u.tz).distance_to(Vector2(0, -84)) > 6.0)
		if not idle_fighters.is_empty():
			GameState.anchor_selected = false
			GameState.hud_building = null
			GameState.selected.assign(idle_fighters)
			ic._right_click(ic.project(0.0, 0.0, -84.0))
	Events.game_over.disconnect(on_ended)
	stats["time"] = snappedf(GameState.sim_time, 0.001)
	stats["wave"] = GameState.wave
	stats["built"] = GameState.buildings.filter(func(b: Building) -> bool: return b.complete).map(func(b: Building) -> String: return b.type)
	stats["trained"] = GameState.units.filter(func(u: Unit) -> bool: return u.role in ["archer", "lame", "flammes"]).size()
	stats["dug"] = sim.state().dug.size()
	stats["galleries"] = sim.state().found
	for e: String in sim.combat.events:
		if e.contains(" niveau "):
			stats["levels"] += 1
		elif e.contains(" abattu "):
			stats["kills"] += 1
	# Gain de prière : ressources totales au-delà de ce que l'Ancre seule aurait rapporté.
	var total := 0.0
	for k: String in Catalog.RES_ORDER:
		total += GameState.res[k]
	var spent := _spent()
	stats["prayer_gain"] = snappedf(total + spent - 4.0 * (GameState.sim_time - stats["orb_at"]), 0.01)
	stats["res"] = Catalog.RES_ORDER.map(func(k: String) -> int: return int(GameState.res[k]))
	stats["units"] = GameState.units.filter(func(u: Unit) -> bool: return u.alive()).size()
	stats["fallen"] = GameState.fallen.size()
	var out := log.duplicate()
	out.append_array(sim.combat.events)
	sim.combat.log_events = false
	return out


## Coûts payés pendant la partie (bâtiments posés, adeptes, entraînements, rappels).
func _spent() -> float:
	var s := 0.0
	for b: Building in GameState.buildings:
		for k: String in Catalog.BUILDINGS[b.type]["cost"]:
			s += Catalog.BUILDINGS[b.type]["cost"][k]
	s += stats["adepts"] * Catalog.SUMMON_COST
	for k: String in Catalog.CASERNE_COST:
		s += Catalog.CASERNE_COST[k] * stats["trained"]
	s += stats.get("revive_spent", 0)
	return s


func _invariants() -> void:
	var t := GameState.sim_time
	for u: Unit in GameState.units:
		if not (is_finite(u.x) and is_finite(u.z) and is_finite(u.hp)):
			violations.append("%.0f s : %s position ou PV non finis" % [t, u.name])
		elif u.alive() and not u.hidden and not sim.state().walkable(u.x, u.z):
			violations.append("%.0f s : %s dans la roche (%.2f, %.2f)" % [t, u.name, u.x, u.z])
	for e: Enemy in GameState.enemies:
		if not (is_finite(e.x) and is_finite(e.z) and is_finite(e.hp)):
			violations.append("%.0f s : ennemi %s non fini" % [t, e.kind])
	for k: String in Catalog.RES_ORDER:
		if GameState.res[k] < -1e-6:
			violations.append("%.0f s : ressource %s négative" % [t, k])
	if GameState.effects.size() > 600:
		violations.append("%.0f s : %d effets en cours" % [t, GameState.effects.size()])
	for u: Unit in GameState.selected:
		if not u.alive():
			violations.append("%.0f s : unité morte sélectionnée (%s)" % [t, u.name])
	if violations.size() > 20:
		violations.resize(20)


## Site constructible le plus proche de l'Ancre, au sud de l'allée (grille de 4).
func _site(type: String) -> Variant:
	var best: Variant = null
	var bd := INF
	for x in range(-48, 49, 4):
		for z in range(-146, -99, 4):
			var p := Simulation.snap_for(type, Vector2(x, z))
			if sim.valid_site(type, p):
				var d := p.distance_to(Vector2(0, -128))
				if d < bd:
					bd = d
					best = p
	return best


func _select(u: Unit) -> void:
	GameState.anchor_selected = false
	GameState.hud_building = null
	GameState.hud_menu = ""
	GameState.hud_mode = ""
	ic._left_click(ic.project(u.x, 1.0, u.z), false)
	if not GameState.selected.has(u):
		GameState.selected = [u]


func _click_building(b: Building) -> void:
	GameState.selected = []
	GameState.anchor_selected = false
	GameState.hud_mode = ""
	GameState.hud_menu = ""
	ic._left_click(ic.project(b.x, 0.0, b.z - 0.5), false)
	if GameState.hud_building != b:
		GameState.hud_building = b


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.key_label = k
	e.pressed = true
	ic._key(e)


func _mark(what: String) -> void:
	log.append("%.2f %s" % [GameState.sim_time, what])
