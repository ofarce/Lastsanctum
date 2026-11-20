class_name Opening
extends RefCounted
## Séquence d'ouverture (planches/sequence-ouverture-v2.html, choix du 2026-11-18) :
##   « arrival »  J1, cinématique : portail d'argent aux arcs au sol (1.2), l'Ingénieur sans armure en est
##                expulsé, tombe à genoux, halète, se relève. Porte sud (2.1) fermée.
##   « day1 »     jeu : réveiller l'Ancre. Le réveil enchaîne la surcharge (sim/overload.gd) sous barres de
##                cinéma, puis le bouclier d'énergie se forme (« shield_form ») ; la porte reste fermée jusqu'à l'explosion.
##   « siege_intro » début J2, cinématique : carton « Jour 2 » encadré (9.3), trois canons de Byrsa montent
##                la route et pilonnent le bouclier en salve décalée (6.1).
##   « siege »    jeu au J2 : le pilonnage continue, le bouclier (film de savon, 3.3) bloque la sortie ;
##                réplique de l'Ingénieur au contact (5.1).
##   « blast »    fin du J2, cinématique : fissures, contraction franche (7.1), onde rose qui renverse les
##                canons et souffle le mur sud ; les remparts (8.3 « Arc gardé ») sont découverts.
##   « waves »    les assauts commencent (premier au matin du J3).
## La logique vit ici ; le rendu dans world/opening/ et ui/cinema/cinema_layer.gd. Instants en secondes de
## simulation depuis GameState.opening_at (début de l'étape courante).

## Ancienne suite du réveil de l'Ancre (étincelle, surcharge et nova, bouclier, siège, explosion, remparts),
## mise de côté le 2026-11-19 : vrai pour la rejouer. Faux : un trait d'énergie court au sol de l'Ancre à la
## capsule (« link »), qui s'allume et devient utilisable (« awake »).
const ANCHOR_SEQUENCE := false
## Durée de la course du trait jusqu'à la capsule.
const LINK_LEN := 2.2
## Une fois arrivé, le trait reste allumé LINK_HOLD s puis s'éteint en LINK_FADE s.
const LINK_HOLD := 3.0
const LINK_FADE := 1.2

# ---- Arrivée (J1)
const ARR_OPEN := [0.6, 1.6]
const ARR_EJECT := 2.4
const ARR_CLOSE := [3.6, 4.3]
## À genoux de ARR_EJECT à ARR_RISE : 2,4 s (moitié des 4,8 s d'origine, 2026-11-19) ; la suite est avancée d'autant.
const ARR_RISE := 4.8  # se relève (images 24 → 35 de l'agenouillement)
const ARR_STAND := 5.8
const ARR_END := 7.6
## Sphère au-dessus du point d'atterrissage, sous la paroi nord.
const PORTAL_AT := Vector2(0.0, -163.5)
const LAND := Vector2(0.0, -162.5)

# ---- Bouclier
const SHIELD_FORM := 4.5  # durée de la formation, dans la grotte, après la surcharge
const SHIELD_C := Vector2(0.0, -77.0)  # centre au sol : sortie du tunnel
const SHIELD_R := 14.0
const SHIELD_H := 10.0

# ---- Siège (J2)
const SIEGE_INTRO := 12.0
const ARRIVE := [0.4, 4.4]
const FIRE := 5.0
const PERIOD := 1.6
const SHELL_FLIGHT := 0.45  # fraction de la période passée en vol
const CANNONS := [Vector2(-12.0, -53.0), Vector2(0.0, -50.0), Vector2(12.0, -53.0)]
const CANNON_FROM := 34.0  # ils arrivent de si loin au sud
const SIEGE_MIN := 30.0  # durée minimale de jeu sous le pilonnage avant l'explosion
const SIEGE_CAM := Vector2(0.0, -62.0)

# ---- Explosion (fin J2)
const BLAST_LEN := 12.0
const CRACK := [1.2, 4.2]
const CONTRACT := [4.2, 5.4]
const BURST := 5.4
const FLING := 1.1
const SMOKE := 6.0

const BLOCK_LINE := "Le bouclier nous enferme autant qu’il nous protège."
const DOOR_LINE := "Barrée de l’extérieur. Il faut d’abord réveiller l’Ancre."


static func stage() -> String:
	return GameState.opening_stage


static func elapsed() -> float:
	return GameState.sim_time - GameState.opening_at


static func _go(s: String) -> void:
	GameState.opening_stage = s
	GameState.opening_at = GameState.sim_time
	_cues.clear()


## Bruitages de la séquence déjà joués dans l'étape courante, et dernière phase de tir de chaque canon.
static var _cues := {}
static var _fire := [-1.0, -1.0, -1.0]


## Joue `sound` une fois, quand l'étape courante atteint `at` secondes.
static func _cue(sound: String, at: float, t: float) -> void:
	if t >= at and not _cues.has(sound):
		_cues[sound] = true
		Sfx.play(sound)


## Un coup par canon à chaque reprise de sa phase de tir.
static func _cannon_sounds() -> void:
	for i in CANNONS.size():
		var p := fire_phase(i)
		if p >= 0.0 and (_fire[i] < 0.0 or p < _fire[i]):
			var c: Vector2 = CANNONS[i]
			Sfx.at("canon", c.x, c.y)
		_fire[i] = p


## Nouvelle partie avec séquence : l'Ingénieur attend dans le portail, la porte est fermée.
static func start(sim: Simulation, eng: Unit) -> void:
	_go("arrival")
	eng.hidden = true
	eng.x = LAND.x
	eng.z = LAND.y
	eng.tx = LAND.x
	eng.tz = LAND.y
	eng.unarmored = true
	# Le portail des Exilés ne joue plus son ouverture : l'arrivée a sa propre sphère.
	GameState.portal_start = -1000.0
	set_door(sim.state(), true)


## Une cinématique est en cours : barres, HUD masqué, commandes coupées.
static func cinematic() -> bool:
	match GameState.opening_stage:
		"arrival", "siege_intro", "blast", "shield_form":
			return true
		"day1":
			# Du réveil de l'Ancre à la fin de la surcharge : on reste dans la grotte, sous barres.
			return ANCHOR_SEQUENCE and GameState.orb_active
	return false


static func tick(sim: Simulation) -> void:
	var s := GameState.opening_stage
	if s == "":
		return
	var t := elapsed()
	match s:
		"arrival":
			_cue("portail", ARR_OPEN[0], t)
			_cue("expulsion", ARR_EJECT, t)
			var eng := _engineer()
			if eng and eng.hidden and t >= ARR_EJECT:
				eng.hidden = false
			if t >= ARR_END:
				_go("day1")
				if eng:
					ExileGallery.incarnate(eng)
					sim.engineer_greeted.emit(eng)
		"day1":
			# Le réveil de l'Ancre ne programme pas d'assaut : la séquence s'en charge.
			if GameState.orb_active and not ANCHOR_SEQUENCE:
				GameState.next_wave = INF
				_go("link")
			elif GameState.orb_active:
				GameState.next_wave = INF
				if GameState.overload_stage >= 3 or GameState.sim_time - GameState.orb_finished_at > 40.0:
					_go("shield_form")
					GameState.shield_up = true
					GameState.shield_at = GameState.sim_time
					set_shield(sim.state(), true)
					Combat.zone(CaveShape.CORE.x, CaveShape.CORE.y, 14.0, Color("#f4bfd6"))
		"link":
			_cue("ancre_trait", 0.0, t)
			GameState.next_wave = INF
			if t >= LINK_LEN:
				GameState.capsule_on = true
				_go("awake")
		"awake":
			_cue("capsule", 0.0, t)
			# Capsule allumée : le premier assaut est fixé à 9 h du jour 2 (une seule fois).
			if is_inf(GameState.next_wave):
				GameState.next_wave = DayNight.first_wave(GameState.sim_time)
		"shield_form":
			_cue("bouclier_forme", 0.0, t)
			if t >= SHIELD_FORM:
				# La porte sud reste fermée : l'Ancre ne l'ouvre pas (elle cède avec le mur sud, à l'explosion).
				_go("shielded")
				sim.say("Un bouclier d’énergie enveloppe la grotte.", 4.0)
		"shielded":
			GameState.next_wave = INF
			if DayNight.day(GameState.sim_time) >= 2:
				_go("siege_intro")
		"siege_intro":
			_cannon_sounds()
			GameState.next_wave = INF
			if t >= SIEGE_INTRO:
				_go("siege")
		"siege":
			_cannon_sounds()
			GameState.next_wave = INF
			_block_line(sim)
			var dusk := (1.0 + DayNight.DUSK_START - DayNight.START) * DayNight.LENGTH
			if t >= SIEGE_MIN and (GameState.sim_time >= dusk or DayNight.day(GameState.sim_time) > 2):
				_go("blast")
		"blast":
			_cannon_sounds()
			_cue("onde", BURST - 1.2, t)  # la montée du son (1,2 s) précède l'onde
			GameState.next_wave = INF
			if t >= BURST and GameState.shield_up:
				GameState.shield_up = false
				set_shield(sim.state(), false)
				if GameState.door_closed:
					set_door(sim.state(), false)
				if sim.world:
					sim.world.open_breach()
				else:
					sim.state().breach_open = true
					sim.state().version += 1
			if t >= BLAST_LEN:
				_go("waves")
				GameState.next_wave = DayNight.morning(DayNight.day(GameState.sim_time) + 1)
				sim.say("Le mur sud a cédé. Postez vos troupes sur les remparts · premier assaut au matin du jour %d." % DayNight.day(GameState.next_wave), 6.0)


static func _engineer() -> Unit:
	for u in GameState.units:
		if u.role == "engineer":
			return u
	return null


## Réplique unique quand une unité vient buter contre le bouclier.
static func _block_line(sim: Simulation) -> void:
	if GameState.shield_line_said:
		return
	for u in GameState.units:
		if u.alive() and not u.hidden and Vector2(u.x, u.z).distance_to(SHIELD_C) > SHIELD_R - 3.0 and CaveShape.outdoors(u.x, u.z):
			GameState.shield_line_said = true
			Combat.zone(u.x, u.z + 1.5, 1.5, Color("#ffd6e6"))
			var eng := _engineer()
			if eng:
				sim.engineer_spoke.emit(eng, BLOCK_LINE)
			return


# ---------------------------------------------------------------- Terrain

## Porte posée à l'ouverture de la grotte (sortie du tunnel, au pied du flanc).
const DOOR_Z := -75.5


## Cases sous la porte (une rangée en z −80…−76, x −8…8) : infranchissables tant que la porte est fermée.
static func door_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(-2, 2):
		out.append(Vector2i(i, -20))
	return out


static func set_door(st: TerrainState, closed: bool) -> void:
	GameState.door_closed = closed
	for c in door_cells():
		if closed:
			st.walls[c] = true
		else:
			st.walls.erase(c)
	st.version += 1


## Anneau de cases dehors, sous la paroi du bouclier.
static func shield_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := ceili(SHIELD_R / 4.0) + 1
	var ci := floori(SHIELD_C.x / 4.0)
	var cj := floori(SHIELD_C.y / 4.0)
	for i in range(ci - r, ci + r + 1):
		for j in range(cj - r, cj + r + 1):
			var p := Vector2(i * 4.0 + 2.0, j * 4.0 + 2.0)
			var d := p.distance_to(SHIELD_C)
			if d >= SHIELD_R - 2.0 and d < SHIELD_R + 2.0 and CaveShape.outdoors(p.x, p.y):
				out.append(Vector2i(i, j))
	return out


static func set_shield(st: TerrainState, up: bool) -> void:
	for c in shield_cells():
		if up:
			st.walls[c] = true
		else:
			st.walls.erase(c)
	st.version += 1


# ---------------------------------------------------------------- Lecture pour le rendu

## Barres de cinéma (0 → 1).
static func bars() -> float:
	var t := elapsed()
	match GameState.opening_stage:
		"arrival":
			return clampf(t / 0.5, 0.0, 1.0) * (1.0 - clampf((t - (ARR_END - 0.6)) / 0.6, 0.0, 1.0))
		"siege_intro":
			return clampf(t / 0.5, 0.0, 1.0) * (1.0 - clampf((t - (SIEGE_INTRO - 0.6)) / 0.6, 0.0, 1.0))
		"blast":
			return clampf(t / 0.5, 0.0, 1.0) * (1.0 - clampf((t - (BLAST_LEN - 0.6)) / 0.6, 0.0, 1.0))
		"day1":
			return clampf((GameState.sim_time - GameState.orb_finished_at) / 0.5, 0.0, 1.0) if GameState.orb_active else 0.0
		"shield_form":
			return 1.0 - clampf((t - (SHIELD_FORM - 0.6)) / 0.6, 0.0, 1.0)
	return 0.0


## Carton de jour : [texte, opacité] ou [].
static func card() -> Array:
	if GameState.opening_stage != "siege_intro":
		return []
	var t := elapsed()
	var a := clampf(minf((t - 0.6) * 2.0, (3.4 - t) * 2.0), 0.0, 1.0)
	return ["Jour 2", a] if a > 0.0 else []


## Flash plein écran : [opacité, couleur].
static func flash() -> Array:
	var t := elapsed()
	match GameState.opening_stage:
		"arrival":
			var a := maxf(clampf(1.0 - absf(t - (ARR_CLOSE[1] + 0.05)) * 7.0, 0.0, 1.0) * 0.85,
				clampf(1.0 - absf(t - ARR_EJECT) * 10.0, 0.0, 1.0) * 0.4)
			return [a, Color("#eef3ff")]
		"blast":
			return [clampf(1.0 - absf(t - BURST) * 4.0, 0.0, 1.0) * 0.95, Color("#fde4ee")]
		"shield_form":
			return [clampf(1.0 - absf(t - 0.4) * 2.5, 0.0, 1.0) * 0.45, Color("#f6c9dc")]
	return [0.0, Color.WHITE]


## Tremblement de caméra, en pixels natifs.
static func shake() -> float:
	var t := elapsed()
	if GameState.opening_stage == "blast":
		if t >= CONTRACT[0] and t < BURST:
			return 2.0 * (t - CONTRACT[0]) / (BURST - CONTRACT[0])
		if t >= BURST and t < BURST + 0.5:
			return 3.0 * (1.0 - (t - BURST) / 0.5)
	return 0.0


## Cible de caméra pendant les cinématiques extérieures : {"cam", "px"} ou {}.
static func camera() -> Dictionary:
	var t := elapsed()
	match GameState.opening_stage:
		"siege_intro":
			if t < SIEGE_INTRO - 1.0:
				return {"cam": SIEGE_CAM, "px": 2}
		"blast":
			if t < BLAST_LEN - 1.0:
				return {"cam": SIEGE_CAM, "px": 2}
		"arrival":
			return {"cam": LAND + Vector2(0.0, -1.0), "px": 3}
	return {}


## Avancée d'un canon sur la route (0 → 1) ; les canons n'existent qu'à partir du siège.
static func cannon_arrival(i: int) -> float:
	match GameState.opening_stage:
		"siege_intro":
			var t := elapsed()
			var k := clampf((t - (ARRIVE[0] + i * 0.5)) / (ARRIVE[1] - ARRIVE[0] + i * -0.1), 0.0, 1.0)
			return k * k * (3.0 - 2.0 * k)
		"siege", "blast":
			return 1.0
	return -1.0


## Phase de tir d'un canon (0 → 1 sur PERIOD) ou −1 s'il ne tire pas.
static func fire_phase(i: int) -> float:
	var s := GameState.opening_stage
	var t := elapsed()
	if s == "siege_intro":
		if t < FIRE:
			return -1.0
		t -= FIRE
	elif s == "blast":
		if t >= BURST:
			return -1.0
		t += 0.37 * i
		return fmod(t, 1.1) / 1.1
	elif s != "siege":
		return -1.0
	return fmod(t + PERIOD - i * PERIOD / 3.0, PERIOD) / PERIOD


## Point d'impact d'un canon sur la paroi avant du bouclier (x, hauteur, z).
static func impact(i: int) -> Vector3:
	var c: Vector2 = CANNONS[i]
	var x := c.x * 0.6
	var z := SHIELD_C.y + sqrt(maxf(0.0, SHIELD_R * SHIELD_R - x * x))
	return Vector3(x, 3.0 + i, z)
