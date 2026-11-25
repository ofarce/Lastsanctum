class_name Mods
extends RefCounted
## Règles des douze mods de l'Exilé ajoutés le 2026-11-21 (planches/mods-icones-propositions.html ; les trois butins
## de boss, Voile, Iris et Foreuse, ont leurs règles dans sim/loot.gd et sim/simulation.gd). Chaque mod est un objet
## de data/gear_items.gd (champ « module ») ; son dessin porté est dans entities/unit/mods_worn_fx.gd, qui lit les
## instants rangés ici dans Unit.mods. Chiffres de la planche (proposés par moi, gardés au bilan), à régler.

const Gear := preload("res://data/gear_items.gd")
const Ammo := preload("res://data/ammo.gd")
const ItemStorage := preload("res://sim/item_storage.gd")

## Écaille d'esquive : un tir ennemi qui frôle l'Exilé incarné sans le toucher (à moins de GRAZE unités au-delà de
## la touche) charge l'écaille ; sa prochaine attaque fait SCALE_MULT fois les dégâts.
const GRAZE := 0.6
const SCALE_MULT := 1.5
## Cœur de braise : sous EMBER_HP des PV max, cadence × EMBER_RATE pendant EMBER_TIME s, au plus une fois par EMBER_CD s.
const EMBER_HP := 0.3
const EMBER_RATE := 1.25
const EMBER_TIME := 6.0
const EMBER_CD := 60.0
## Aimant d'ichor : chaque ennemi abattu par le porteur lui rend MAGNET_HEAL de ses PV max.
const MAGNET_HEAL := 0.03
## Culasse froide : pendant FROST_TIME s après un changement de munition, recharge × FROST_MULT.
const FROST_MULT := 0.7
const FROST_TIME := 3.0
## Sceau sensible : filons à moins de SEAL_CELLS cases (4 unités chacune) montrés à travers la roche.
const SEAL_CELLS := 12
## Lanterne de Medeina : cases de vision en plus (5 → 8).
const WISP_CELLS := 3
## Ancre de rappel : retour à la sortie de la capsule, hors combat, toutes les RECALL_CD s.
const RECALL_CD := 180.0
## Voix du Chantre : chantiers, ateliers, casernes et adeptes à moins de CHANT_RANGE unités (8 cases) du porteur
## travaillent CHANT_MULT fois plus vite.
const CHANT_RANGE := 32.0
const CHANT_MULT := 1.2
## Sac sans fond : rayon de fouille des corps (unités), au lieu de ItemStorage.PICKUP_RADIUS.
const SACK_REACH := 6.0
## Écho du pylône : assauts et meutes nocturnes annoncés ECHO_LEAD s avant leur départ.
const ECHO_LEAD := 15.0


## Analyse (2026-11-22, planches/intro-capsule-planche.html) : un Exilé vivant porte le mod, les ennemis à l'écran
## affichent leur barre de PV (entities/unit/unit_view.gd). Sans lui, ils n'en ont pas. Lu une fois par image.
static var _analysis_frame := -1
static var _analysis := false


static func analysis() -> bool:
	var f := Engine.get_process_frames()
	if f != _analysis_frame:
		_analysis_frame = f
		_analysis = GameState.units.any(func(u: Unit) -> bool: return u.alive() and Gear.has_module(u, "analyse"))
	return _analysis


## Rendu porté d'Analyse (planches/etabli-propositions.html, piste B) : la loupe se lève devant l'œil tant qu'un ennemi
## vivant est à ANALYSIS_SEEN unités ou moins du porteur (environ la moitié de l'écran au zoom de jeu).
const ANALYSIS_SEEN := 18.0


static func analysis_seen(u: Unit) -> bool:
	var r2 := ANALYSIS_SEEN * ANALYSIS_SEEN
	return GameState.enemies.any(func(e: Enemy) -> bool: return e.alive() and not e.hidden and e.pos().distance_squared_to(u.pos()) <= r2)


static func worn(u: Unit, effect: String) -> bool:
	return u != null and not u.is_enemy() and u.alive() and Gear.has_module(u, effect)


static func at(u: Unit, key: String) -> float:
	return float(u.mods.get(key, -INF))


## Premier Exilé vivant et dehors qui porte le mod `effect` (null sinon).
static func wearer(effect: String) -> Unit:
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and Gear.has_module(u, effect):
			return u
	return null


# ---------------------------------------------------------------- Combat

## Tir ennemi qui a frôlé l'Exilé sans le toucher (sim/enemy_shots.gd).
static func graze(u: Unit) -> void:
	if worn(u, "scale") and not scale_charged(u):
		u.mods["graze"] = GameState.sim_time
		Sfx.at("sort_lumiere", u.x, u.z)


static func scale_charged(u: Unit) -> bool:
	return at(u, "graze") > at(u, "scale_spent")


## Facteur de dégâts de l'attaque que lance `u` (Combat.gear_attack) ; l'écaille chargée se décharge.
static func attack_mult(u: Unit) -> float:
	if worn(u, "scale") and scale_charged(u):
		u.mods["scale_spent"] = GameState.sim_time
		return SCALE_MULT
	return 1.0


## Coup reçu par `u` (Combat.damage) : le Cœur de braise s'embrase sous EMBER_HP.
static func hurt(u: Unit) -> void:
	var now := GameState.sim_time
	if worn(u, "ember") and u.hp < u.max_hp * EMBER_HP and now >= at(u, "ember_ready"):
		u.mods["ember"] = now
		u.mods["ember_ready"] = now + EMBER_CD
		Sfx.at("flammes", u.x, u.z)


static func ember_on(u: Unit) -> bool:
	return worn(u, "ember") and GameState.sim_time - at(u, "ember") < EMBER_TIME


## Facteur de recharge de l'arme de `u` (Combat.gear_attack) : Cœur de braise, Culasse froide.
static func cd_mult(u: Unit) -> float:
	var m := 1.0
	if ember_on(u):
		m /= EMBER_RATE
	if worn(u, "frost") and GameState.sim_time - GameState.ammo_changed_at < FROST_TIME:
		m *= FROST_MULT
	return m


## Ennemi `e` abattu par `src` (Combat.damage) : l'Aimant d'ichor soigne son porteur.
static func killed(src: Unit, e: Enemy) -> void:
	if not worn(src, "magnet"):
		return
	var healed := minf(src.max_hp * MAGNET_HEAL, src.max_hp - src.hp)
	src.mods["kill"] = GameState.sim_time
	src.mods["kill_from"] = Vector2(e.x - src.x, e.z - src.z)
	if healed <= 0.0:
		return
	src.hp += healed
	GameState.damage_numbers.append({"target": src, "x": src.x, "z": src.z, "amount": healed, "age": -0.4, "duration": 0.9, "heal": true})


## Mines de patine : un tir manqué laisse une mine PATINE_LIFE s ; un ennemi à moins de PATINE_TOUCH la fait éclater
## (dégâts du tir). Le canon verdit (Unit.mods["patine"], entities/unit/mods_worn_fx.gd).
const PATINE_LIFE := 3.0
const PATINE_TOUCH := 0.9
const PATINE_MAX := 12


static func patine_drop(u: Unit, at: Vector2, dmg: float) -> void:
	if not worn(u, "patine"):
		return
	if GameState.patine_mines.size() >= PATINE_MAX:
		GameState.patine_mines.pop_front()
	GameState.patine_mines.append({"x": at.x, "z": at.y, "at": GameState.sim_time, "until": GameState.sim_time + PATINE_LIFE,
		"dmg": dmg, "src": u})


static func patine_tick(sim: Simulation) -> void:
	if GameState.patine_mines.is_empty():
		return
	var now := GameState.sim_time
	var keep: Array[Dictionary] = []
	for m: Dictionary in GameState.patine_mines:
		if now >= float(m["until"]):
			continue
		var hit: Enemy = null
		for e: Enemy in GameState.enemies:
			if e.hp > 0.0 and not e.hidden and absf(e.x - float(m["x"])) < PATINE_TOUCH and absf(e.z - float(m["z"])) < PATINE_TOUCH:
				hit = e
				break
		if hit == null:
			keep.append(m)
			continue
		var src: Unit = m["src"]
		sim.combat.damage(hit, float(m["dmg"]), src)
		Combat.flash(m["x"], m["z"], Color("#78e098"))
		Combat.zone(m["x"], m["z"], 1.2, Color("#2aa452"))
		if src != null:
			src.mods["patine"] = now
	GameState.patine_mines = keep


## Ennemis percés en plus par un carreau de `u` (Lentille de souffle).
static func pierce(u: Unit) -> int:
	return 1 if worn(u, "lens") else 0


## Munition du tir qui part (le Barillet double, qui l’alternait, est retiré le 2026-11-23).
static func shot_ammo(_u: Unit) -> String:
	return Ammo.current()


# ---------------------------------------------------------------- Exploration

static func vision_bonus(u: Unit) -> int:
	return WISP_CELLS * 4 if Gear.has_module(u, "wisp") and u.alive() else 0


## Filons (cases de minerai) à moins de SEAL_CELLS cases de `u` : [[centre, minerai]], le plus proche d'abord.
static func ores_near(u: Unit, st: TerrainState) -> Array:
	var out: Array = []
	if st == null:
		return out
	var ci := floori(u.x / 4.0)
	var cj := floori(u.z / 4.0)
	for j in range(cj - SEAL_CELLS, cj + SEAL_CELLS + 1):
		for i in range(ci - SEAL_CELLS, ci + SEAL_CELLS + 1):
			var item: Variant = st.block_types.get(Vector2i(i, j))
			if item == null or not TerrainState.Blocks.ORES.has(item):
				continue
			var c := Vector2(i * 4 + 2, j * 4 + 2)
			var d := c.distance_to(u.pos())
			if d <= SEAL_CELLS * 4.0:
				out.append([c, String(item), d])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	return out


static func recall_ready(u: Unit) -> bool:
	return worn(u, "anchor") and GameState.sim_time >= at(u, "recall_ready")


## Ancre de rappel : l'Exilé revient à la sortie de la capsule (hors combat). Vrai s'il est parti.
static func recall(sim: Simulation, u: Unit) -> bool:
	if not recall_ready(u) or u.hidden or Simulation.in_combat(u):
		if worn(u, "anchor") and not u.hidden:
			if not recall_ready(u):
				sim.say("Ancre de rappel · prête dans %d s." % ceili(at(u, "recall_ready") - GameState.sim_time), 2.5)
			elif Simulation.in_combat(u):
				sim.say("Ancre de rappel · impossible en combat.", 2.5)
		return false
	var now := GameState.sim_time
	u.mods["recall"] = now
	u.mods["recall_from"] = u.pos()
	u.mods["recall_ready"] = now + RECALL_CD
	warp_home(sim, u)
	return true


## Retour à la sortie de la capsule (Ancre de rappel, rappel d'assaut de PortalNet) : travail lâché, charge posée,
## éclair au départ et à l'arrivée.
static func warp_home(sim: Simulation, u: Unit) -> void:
	sim.cancel_work(u)
	if not u.carrying.is_empty():
		sim.production._drop(u)
	Combat.zone(u.x, u.z, 1.8, Color("#8a7ad0"))
	Sfx.at("portail", u.x, u.z)
	u.x = Capsule.EXIT.x
	u.z = Capsule.EXIT.y
	u.tx = u.x
	u.tz = u.z
	u.force_move = false
	Combat.zone(u.x, u.z, 1.8, Color("#8a7ad0"))


# ---------------------------------------------------------------- Gestion

## Facteur de vitesse du travail fait au point `p` (Voix du Chantre).
static func work_mult(p: Vector2) -> float:
	var w := wearer("chant")
	return CHANT_MULT if w != null and w.pos().distance_squared_to(p) <= CHANT_RANGE * CHANT_RANGE else 1.0


static func pickup_reach(u: Unit) -> float:
	return SACK_REACH if Gear.has_module(u, "sack") else ItemStorage.PICKUP_RADIUS


# ---------------------------------------------------------------- Défense

## Instant du départ des meutes nocturnes du jour n (sim/night.gd, NIGHT_RAID.at).
static func raid_time(n: int) -> float:
	return (float(n - 1) + float(Catalog.NIGHT_RAID["at"]) - DayNight.START) * DayNight.LENGTH


static func _raid_due(sim: Simulation, n: int) -> bool:
	if GameState.wave < 1 or sim.world == null:
		return false
	for p: Dictionary in sim.state().portals:
		if int(p.get("raid_day", 0)) != n and not bool(p.get("channeled", false)):
			return true
	return false


## Annonces de l'Écho du pylône, et pulsation des adeptes touchés par la Voix du Chantre.
static func tick(sim: Simulation) -> void:
	if GameState.ended:
		return
	patine_tick(sim)
	if not GameState.orb_active:
		return
	var now := GameState.sim_time
	var echo := wearer("echo")
	if echo == null:
		return
	var due := GameState.next_wave
	if due > now and not is_inf(due) and due - now <= ECHO_LEAD and GameState.echo_wave != due:
		GameState.echo_wave = due
		echo.mods["echo"] = now
		Events.wave_alert.emit("L’Écho du pylône bourdonne · un assaut dans %d s." % ceili(due - now), 4.0)
		Sfx.at("onde", echo.x, echo.z)
	var n := DayNight.day(now)
	var rt := raid_time(n)
	if GameState.echo_raid_day != n and now < rt and rt - now <= ECHO_LEAD and _raid_due(sim, n):
		GameState.echo_raid_day = n
		echo.mods["echo"] = now
		Events.wave_alert.emit("L’Écho du pylône bourdonne · les meutes de Merenor sortent dans %d s." % ceili(rt - now), 4.0)
		Sfx.at("onde", echo.x, echo.z)
