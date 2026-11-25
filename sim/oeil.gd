class_name OeilMatrice
extends RefCounted
## Boss de la frontière : l'Œil de la Matrice (planches/matrice-bullet-hell.html, variante 5, motif « Regard » ;
## calques exportés par planches/oeil-matrice-export.html, tools/oeil/export.sh).
##
## Il garde la salle creusée tout en haut du Temple (TerrainState.eye_room_center), seul passage vers le biome 2 :
## la bande de roche de la frontière est impossible à creuser, et le couloir nord de la salle est fermé par une
## porte de chair (TerrainState.eye_gate) qui ne s'ouvre qu'à sa mort.
## - Il s'éveille quand la salle est découverte, et ne quitte jamais son centre.
## - La salle sert d'arène : seul l'Ingénieur y entre (les autres unités sont reconduites à l'entrée), rien ne vise
##   à travers sa paroi, et seul l'Ingénieur, dans la salle, le blesse. L'œil ouvert prend OPEN_MULT fois les dégâts.
## - Combat singulier dès que l'Ingénieur entre. Les attaques s'enchaînent selon ROTATION, avec une fenêtre de souffle
##   entre deux (2026-11-23 : chaque mini-boss du Temple joue une part de ses attaques) :
##   phase I : les motifs de la Martyre de Byrsa (fissure, larmes d'or, rosace, litanie), joués par le moteur de
##   la Martyre (Martyre.host_*) depuis le pourtour de la base ;
##   phase II : ses attaques propres (celles que joue aussi l'Archiprêtre aux racines, host_*) ;
##   phase III : deux attaques à la fois, une de la phase II et un motif de la phase I ;
##   Fixation et Clignement ne sont plus joués (code gardé). Attaques propres (planches/oeil-maj.html) :
##   Regard : l'œil vise l'Ingénieur, trace un couloir d'avertissement au sol (LANE.warn s), puis lâche un torrent
##   d'yeux rapides dans cet axe, et des yeux lents qui le suivent un instant ;
##   Larmes : larmes en cloche autour de l'Ingénieur, éclaboussure, flaque qui éclate en couronne (œil mi-clos) ;
##   Cils : spirale de dents depuis toute la base, qui change de sens à mi-salve ;
##   Strabisme : deux torrents qui balaient l'un vers l'autre et se croisent sur l'Ingénieur, percés de trous ;
##   Pupilles errantes : trois pupilles volantes (ennemis PUPIL_KIND, cibles fragiles) tournent et tirent ;
##   Fixation : une marque se pose sous l'Ingénieur, le suit moins vite que lui, se resserre puis éclate ;
##   Clignement : la salle s'assombrit, l'œil se rouvre dans un éclair (couronne à deux brèches), et recommence ;
##   Les mille yeux : à l'entrée en phase II puis en phase III, les parois lâchent des murs d'yeux à une brèche, que la
##   masse arrête.
## - Racines : l'Ingénieur collé à la base est frappé (ROOT_DAMAGE toutes les ROOT_EVERY s).
## - Trois phases (PHASE_HP), balles plus rapides de l'une à l'autre ; en phase III les attaques gardent les nombres
##   de la phase II (TIER). Au changement de phase, les balles s'éteignent. Après un coup, l'Ingénieur est
##   invulnérable IFRAMES s.
## - S'il ressort de la salle, ses balles s'éteignent et l'œil se referme, sans se soigner.
## État : GameState.oeil, oeil_state, oeil_bullets, oeil_fx (couloirs, flaques, marques, événements à venir),
## oeil_run (phase, attaque en cours, état visuel : close, dark, iris_out, weep, open_to). Rendu : world/oeil/.

const KIND := "oeil"
## Emprise au sol (demi-axes, unités) : la base de chair, infranchissable pour l'Ingénieur. Les balles partent
## de son pourtour.
const FOOT := Vector2(9.5, 3.0)
## Emprise et orbite des pupilles (part de PUPILS.rx / rz) quand un autre boss joue ses attaques (host_begin).
const HOST_FOOT := Vector2(2.4, 1.2)
const HOST_ORBIT := 0.7
## Silhouette pour les tirs et les clics : demi-largeur, hauteur projetée au nord du centre, marge au sud.
const BODY := {"half_w": 9.0, "top": 11.0, "foot": 2.5, "melee": 3.0}
const OPEN_MULT := 2.0
const IFRAMES := 0.6
## Multiplicateur de tous les coups portés à l'Ingénieur (2026-11-19 : dégâts des boss doublés).
const DAMAGE_MULT := 2.0
const ROOT_REACH := 1.8
const ROOT_DAMAGE := 20.0
const ROOT_EVERY := 1.2
## Balles : rayons (petite, grosse), zone touchée chez l'Ingénieur, dégâts, hauteur de vol (px natifs), durée de vie.
const BULLET := {"r": 0.40, "big_r": 0.68, "hit": 0.375, "damage": 8.0, "big_damage": 16.0, "lift": 17.0, "life": 6.0}
## Regard : annonce, tirs du torrent (nombre, cadence, vitesse, écart, une grosse balle sur `big`), yeux chercheurs
## (un tous les `seek_every` tirs, vitesse, virage max en rad/s, durée du guidage), ouverture avant le premier,
## pause après chaque regard.
const LANE := {"warn": 0.7, "shots": 18, "every": 0.05, "speed": 21.25, "jitter": 0.035, "big": 6,
	"seek_every": 4, "seek_speed": 7.25, "seek_turn": 1.2, "seek_time": 1.3, "open": 0.5, "rest": 0.5}
const PHASE_HP := [2.0 / 3.0, 1.0 / 3.0]
const PHASE_SPEED := [1.0, 1.12, 1.25]
const PHASE_ROUNDS := [3, 4, 5]
## Enchaînement des attaques par phase (2026-11-23). Phase I : motifs de la Martyre (préfixe MARTYRE_PREFIX, joués
## par Martyre.host_start). Phase II : attaques propres, aussi jouées par l'Archiprêtre. Phase III (ligne vide) : à
## chaque tour, l'attaque suivante de la phase II et le motif suivant de la phase I partent ensemble (5 × 4 : vingt
## paires avant de boucler). INTRO se joue seule à l'entrée en phase II, puis de nouveau à l'entrée en phase III.
const MARTYRE_PREFIX := "m:"
const ROTATION := [["m:fissure", "m:larmes", "m:rosace", "m:litanie"], ["regard", "strabisme", "pupilles", "larmes", "cils"], []]
const INTRO := "milleyeux"
## Rang des nombres par attaque (rounds, larmes, bras…) selon la phase : la phase III garde ceux de la phase II,
## puisqu'elle en lance deux à la fois.
const TIER := [0, 1, 1]
## Larmes : départ, cadence, nombre par phase, vol (s) et hauteur de la cloche (px), dispersion autour de
## l'Ingénieur (une sur `exact` tombe pile sur lui), éclaboussure, flaque (éclate à `burst_at` s), pause finale ;
## l'œil reste mi-clos (open_to), donc sans dégâts doublés.
const TEARS := {"open": 0.45, "every": 0.2, "count": [8, 11, 14], "flight": 1.05, "arc": 40.0, "spread_x": 10.0,
	"spread_z": 6.25, "exact": 3, "splash": 5, "splash_speed": 4.25, "burst_at": 1.4, "puddle": 1.5, "burst": [8, 10, 12],
	"burst_speed": 5.75, "rest": 1.2, "open_to": 0.5}
## Cils : bras par phase, tirs par phase, cadence, pas de rotation (rad par tir), vitesse de départ, accélération,
## vitesse max.
const CILS := {"open": 0.45, "arms": [4, 5, 6], "shots": [44, 52, 60], "every": 0.075, "turn": 0.13, "speed": 7.25,
	"acc": 4.25, "max": 13.75, "rest": 0.4}
## Strabisme : écart des deux couloirs de part et d'autre de l'Ingénieur, annonce, balayage (rad/s), cadence, trous
## (tirs `on` sur `cycle`), vitesse, une grosse balle sur `big`.
const SQUINT := {"spread": 1.25, "warn": 0.8, "turn": 0.62, "every": 0.045, "on": 4, "cycle": 7, "speed": 18.75, "big": 14}
## Pupilles errantes : nombre, sortie et retour (s), durée, orbite (rad/s, demi-axes), tir visé (cadence, vitesse),
## couronnes de larmes (cadence, nombre, vitesse), hauteur de vol (px, à la sortie puis en orbite).
const PUPILS := {"count": 3, "out": 0.6, "dur": 5.2, "orbit": 0.5, "rx": 18.75, "rz": 12.25, "shot": 0.75, "shot_speed": 10.25,
	"ring_every": 1.9, "ring": 9, "ring_speed": 5.75, "h0": 31.0, "h1": 16.0}
const PUPIL_KIND := "oeil_pupille"
## Silhouette d'une pupille (en vol, à PUPILS.h1 px plus BULLET.lift au-dessus de son ombre).
const PUPIL_BODY := {"half_w": 1.1, "top": 5.4, "foot": 0.6, "melee": 0.0}
## Fixation : marques par phase, durée, rayon de départ et final, poursuite (u/s par phase), yeux chercheurs par
## marque, couronnes (nombre, vitesse ; grosses balles), dégâts de l'éclatement, pause entre deux marques.
const FIX := {"open": 0.3, "count": [2, 3, 4], "dur": 1.9, "r0": 6.25, "r1": 1.9, "follow": [7.75, 9.5, 11.25], "seekers": 4,
	"ring": [14, 16, 18], "ring_speed": 7.25, "big": 6, "big_speed": 4.25, "damage": 16.0, "gap": 0.35}
## Clignement : noir initial, paupière fermée avant chaque couronne suivante, couronnes par phase, yeux par couronne,
## demi-largeur des deux brèches, écart max de la brèche visée, vitesse (+ step par couronne), intervalle.
const BLINK := {"dark": 1.0, "shut": 0.32, "rings": [3, 4, 5], "n": 42, "gap": 0.24, "aim": 0.6, "speed": 7.75, "step": 0.875,
	"every": 0.28, "big": 7}
## Les mille yeux : réveil des parois, premier mur, murs (nombre, intervalle), pas entre deux yeux d'un mur,
## demi-brèche, vitesses (d'ouest en est, du fond vers l'avant), durée de vie, pause finale.
const WALLS := {"wake": 0.5, "start": 1.1, "waves": 5, "every": 1.7, "row": 1.5, "gap": 3.25, "speed_x": 9.0, "speed_z": 6.5,
	"life": 14.0, "rest": 1.2}
## Fermeture brusque de l'œil (clignement, réveil des parois), part par seconde.
const SHUT_RATE := 8.0
const PHASE_WINDOW := [1.6, 1.4, 1.2]
const PHASE_NAMES := ["I · Le credo", "II · L’iris", "III · Le credo et l’iris"]
const PHASE_PAUSE := 1.0
const FIRST_PATTERN := 1.5
## Ouverture et fermeture de l'œil (part par seconde), suivi du regard (rad/s).
const OPEN_RATE := 4.0
const CLOSE_RATE := 1.5
const LOOK_RATE := 5.0
## Unités reconduites hors de la salle : marge au-delà de la paroi.
const EDGE := 1.0
const COLLAPSE := 2.4

const QUOTE_WAKE := "Une salle immense, tout en haut du Temple… et un œil qui s’ouvre. C’est lui qui garde la frontière."
const QUOTE_DUEL := "Il vise avant de tirer : je dois sortir de son axe, puis frapper l’œil quand il est grand ouvert."
const QUOTE_DONE := "L’Œil s’est fermé pour de bon. La porte de chair cède : la route du nord est ouverte."


static func active() -> bool:
	return GameState.oeil != null and GameState.oeil.hp > 0.0


## Un autre boss joue ses attaques (l'Archiprêtre aux racines) : centre, emprise, salle et cibles sont les siens.
static func hosted() -> bool:
	return GameState.oeil_host != ""


static func center() -> Vector2:
	return Archipretre.center() if hosted() else TerrainState.eye_room_center()


static func foot() -> Vector2:
	return HOST_FOOT if hosted() else FOOT


## (x, z) est dans la salle où volent les balles (grow : marge en unités).
static func in_room(x: float, z: float, grow := 0.0) -> bool:
	return Archipretre.in_arena(x, z, grow) if hosted() else TerrainState.in_eye_room(x, z, grow)


## État du combat : celui de l'Œil, ou celui de l'hôte tant qu'un autre boss joue ses attaques.
static func run() -> Dictionary:
	return GameState.oeil_host_run if hosted() else GameState.oeil_run


## p (unité, ennemi, baliste {x, z}) est-il dans la salle ?
static func inside(p: Variant) -> bool:
	return TerrainState.in_eye_room(p.x, p.z, -0.5)


## La paroi de la salle sépare a et b : aucun tir ni ciblage de l'un vers l'autre.
static func blocks(a: Variant, b: Variant) -> bool:
	return active() and inside(a) != inside(b)


static func can_hurt(src: Unit) -> bool:
	if hosted():
		return true
	return src != null and src.role == "engineer" and inside(src)


## Multiplicateur des coups portés : l'œil grand ouvert encaisse double.
static func damage_mult() -> float:
	return OPEN_MULT if float(run().get("open", 0.0)) > 0.6 else 1.0


static func duelist() -> Unit:
	if not active():
		return null
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden and inside(u):
			return u
	return null


## L'Exilé que visent les balles en vol (zone touchée, regard des pupilles) : le duelliste, ou celui de l'hôte.
static func aimed() -> Unit:
	return Archipretre.exile() if hosted() else duelist()


static func body_rect(e: Enemy) -> Rect2:
	return Rect2(e.x - BODY["half_w"], e.z - BODY["top"], 2.0 * BODY["half_w"], BODY["top"] + BODY["foot"])


static func ray_hit(e: Enemy, from: Vector2, d: Vector2) -> float:
	var r := body_rect(e)
	var t0 := 0.0
	var t1 := INF
	for axis in 2:
		var o := from[axis]
		var v := d[axis]
		var lo := r.position[axis]
		var hi := r.end[axis]
		if absf(v) < 1e-6:
			if o < lo or o > hi:
				return INF
			continue
		var a := (lo - o) / v
		var b := (hi - o) / v
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	return t0 if t0 <= t1 else INF


static func blinking(u: Unit) -> bool:
	var t := GameState.sim_time
	return u.role == "engineer" and t < float(run().get("iframe_until", -INF)) and fmod(t * 20.0, 2.0) < 1.0


## (x, z) dans l'emprise de la base, grossie de `grow` unités.
static func in_foot(x: float, z: float, grow := 0.0) -> bool:
	var c := center()
	var dx := (x - c.x) / (foot().x + grow)
	var dz := (z - c.y) / (foot().y + grow)
	return dx * dx + dz * dz < 1.0


## Point du pourtour de la base dans la direction a, d'où partent les balles.
static func emit(a: float) -> Vector2:
	return center() + Vector2(cos(a) * (foot().x + 0.4), sin(a) * (foot().y + 0.4))


# ---------------------------------------------------------------- Cycle de vie

static func tick(sim: Simulation) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	match GameState.oeil_state:
		"":
			# Éveil à la vue (comme les pylônes) : les galeries sont toutes ouvertes dès le départ (galeries reliées,
			# Temple en salles), « galerie ouverte » ne suffit plus — sinon il s'éveillait au premier pas de la partie.
			var own := TerrainState.eye_room_center()
			if st.frontier and st.is_gallery_open(own.x, own.y) and Awaken.seen(own, Awaken.SIGHT):
				spawn(sim)
		"waiting", "duel":
			var e: Enemy = GameState.oeil
			if e == null or e.hp <= 0.0:
				_defeat(sim)
				return
			var u := duelist()
			if GameState.oeil_state == "waiting" and u != null:
				GameState.oeil_state = "duel"
				var r := run()
				r["next_at"] = GameState.sim_time + FIRST_PATTERN
			elif GameState.oeil_state == "duel" and u == null:
				GameState.oeil_state = "waiting"
				_extinguish(false)
				run()["cast"] = false
				_clear_vis(run())
				run()["next_at"] = INF
		"defeated":
			# Failles et éclats des motifs de la Martyre : ils finissent de s'éteindre, puis son moteur est rendu.
			if Martyre.host() == KIND:
				Martyre.host_tick(sim, null, null, GameState.sim_time, 0.0, 0)
				if GameState.martyre_fx.is_empty():
					Martyre.host_end()


## L'Ingénieur est tombé pendant le duel : l'Œil retrouve tous ses PV et sa première phase.
## Le retour à l'attente (balles éteintes) se fait au pas suivant, faute de duelliste (tick).
static func reset_duel() -> void:
	var e: Enemy = GameState.oeil
	if e == null or e.hp <= 0.0:
		return
	e.hp = e.max_hp
	var r := run()
	r["phase"] = 0
	r["rounds"] = 0
	r["idx"] = 0
	r.erase("intro")
	r.erase("lock")


static func spawn(sim: Simulation) -> Enemy:
	# Toujours dans sa salle : center() suit l'hôte (l'Archiprêtre) quand un autre boss joue ses attaques.
	var c := TerrainState.eye_room_center()
	var e := Enemy.make(KIND, c.x, c.y, 1.0)
	# Boss de salle : hors menace et hors fin de vague, sinon il bloque les assauts dès le début (comme Gorge).
	e.beast = true
	e.face = 1
	GameState.enemies.append(e)
	GameState.oeil = e
	GameState.oeil_state = "waiting"
	# Un hôte en plein combat (l'Archiprêtre) garde ses balles : l'Œil s'éveille dès qu'il est vu, parfois avant.
	if not hosted():
		GameState.oeil_bullets.clear()
		GameState.oeil_fx.clear()
	GameState.oeil_run = {"at": GameState.sim_time, "phase": 0, "next_at": INF, "busy_until": -INF, "cast": false,
		"open": 0.0, "look": PI / 2.0, "iframe_until": -INF, "root_at": -INF, "down_at": INF, "rounds": 0, "idx": 0,
		"pattern": ""}
	Sfx.at("martyre", c.x, c.y)
	sim.say(QUOTE_WAKE, 4.5)
	return e


static func _defeat(sim: Simulation) -> void:
	GameState.oeil_state = "defeated"
	run()["down_at"] = GameState.sim_time
	run()["cast"] = false
	_extinguish(true)
	_clear_vis(run())
	GameState.oeil = null
	var st := sim.state()
	st.eye_gate_closed = false
	st.version += 1
	Combat.flash(0.0, TerrainState.frontier_z(), Color("#e2382e"))


# ---------------------------------------------------------------- Combat

## Comportement de l'Œil (à la place de celui des autres ennemis, Combat.update_enemies).
static func act(sim: Simulation, e: Enemy, dt: float) -> void:
	e.stun = 0.0
	e.cooldown -= dt
	# Ses attaques sont prêtées à un autre boss : il attend, paupière close, sans toucher aux balles de l'hôte.
	if hosted():
		return
	var now := GameState.sim_time
	var r := run()
	var u := duelist()
	_eye(r, u, now, dt)
	update_fx(sim, u, now, dt)
	update_bullets(sim, u, now, dt)
	if Martyre.host() == KIND:
		Martyre.host_tick(sim, e, u, now, dt, int(r["phase"]))
	if u == null:
		return
	_roots(sim, r, u, now)
	_check_phase(sim, e, r, now)
	if now >= float(r["busy_until"]) and r["cast"]:
		r["cast"] = false
		_clear_vis(r)
	if now >= float(r["next_at"]) and now >= float(r["busy_until"]):
		_start_pattern(sim, e, r, u, now)


## Ouverture de l'œil et regard : il suit l'Ingénieur (ou erre quand personne n'est là), reste fixé sur l'axe
## visé pendant le torrent.
static func _eye(r: Dictionary, u: Unit, now: float, dt: float) -> void:
	var shut: bool = r.get("close", false)
	var target := 0.0 if shut else float(r.get("open_to", 1.0)) if r["cast"] else 0.0
	var open: float = r["open"]
	open = move_toward(open, target, dt * (OPEN_RATE if target > open else SHUT_RATE if shut else CLOSE_RATE))
	r["open"] = open
	var want: float = r["look"]
	if r.has("lock"):
		want = r["lock"]
	elif u != null:
		want = (u.pos() - center()).angle()
	else:
		want = PI / 2.0 + sin(now * 0.4) * 1.2
	var cur: float = r["look"]
	r["look"] = cur + clampf(wrapf(want - cur, -PI, PI), -LOOK_RATE * dt, LOOK_RATE * dt)


static func _roots(sim: Simulation, r: Dictionary, u: Unit, now: float) -> void:
	# La base est infranchissable : l'Ingénieur glisse sur son pourtour.
	if in_foot(u.x, u.z, 0.4):
		var off := u.pos() - center()
		if off.length() < 0.01:
			off = Vector2(0.0, 1.0)
		var a := off.angle()
		var p := center() + Vector2(cos(a) * (foot().x + 0.45), sin(a) * (foot().y + 0.45))
		u.x = p.x
		u.z = p.y
	if in_foot(u.x, u.z, ROOT_REACH) and now >= float(r["root_at"]):
		r["root_at"] = now + ROOT_EVERY
		Combat.zone(u.x, u.z, 1.4, Color("#a03a32"))
		if hurt_engineer(sim, u, ROOT_DAMAGE, now):
			Combat.flash(u.x, u.z, Color("#e2382e"))


static func phase_of(e: Enemy) -> int:
	var f := e.hp / maxf(1.0, e.max_hp)
	return 0 if f > PHASE_HP[0] else 1 if f > PHASE_HP[1] else 2


static func _check_phase(sim: Simulation, e: Enemy, r: Dictionary, now: float) -> void:
	var ph := phase_of(e)
	if ph <= int(r["phase"]):
		return
	r["phase"] = ph
	_extinguish(true)
	r["cast"] = false
	_clear_vis(r)
	r["idx"] = 0
	if ph >= 1:
		r["intro"] = INTRO
	r.erase("lock")
	r["busy_until"] = now + PHASE_PAUSE
	r["next_at"] = now + PHASE_PAUSE
	Combat.flash(e.x, e.z, Color("#ff8a6a"))
	sim.say("Phase %s." % PHASE_NAMES[ph], 3.0)


# ---------------------------------------------------------------- Attaques

## Attaques du tour : l'intro de phase si elle attend, sinon la rotation de la phase ; en phase III, l'attaque
## suivante de la phase II et le motif suivant de la phase I, ensemble.
static func next_patterns(r: Dictionary) -> Array:
	if r.has("intro"):
		var p: String = r["intro"]
		r.erase("intro")
		return [p]
	var ph: int = r["phase"]
	var i: int = r.get("idx", 0)
	r["idx"] = i + 1
	var own: Array = ROTATION[1]
	var lent: Array = ROTATION[0]
	var out: Array = [own[i % own.size()], lent[i % lent.size()]] if ph >= 2 else [ROTATION[ph][i % ROTATION[ph].size()]]
	# Les motifs de la Martyre passent par son moteur : pris si elle est elle-même sur le terrain (partie sans plan).
	if Martyre.active():
		out = out.filter(func(p: String) -> bool: return not p.begins_with(MARTYRE_PREFIX))
		if out.is_empty():
			out = [own[i % own.size()]]
	return out


## Lance les attaques du tour, ensemble : fin à busy_until (la plus longue), puis souffle PHASE_WINDOW.
static func _start_pattern(sim: Simulation, e: Enemy, r: Dictionary, u: Unit, now: float) -> void:
	var ph: int = r["phase"]
	var list := next_patterns(r)
	r["pattern"] = "+".join(PackedStringArray(list))
	r["cast"] = true
	e.cast_started = now
	var end := now
	for p: String in list:
		if p.begins_with(MARTYRE_PREFIX):
			if Martyre.host() != KIND:
				Martyre.host_begin(KIND, center(), TerrainState.EYE_ROOM_RX)
			end = maxf(end, Martyre.host_start(sim, e, u, p.trim_prefix(MARTYRE_PREFIX), now))
		else:
			end = maxf(end, cast(sim, r, u, p, now))
	r["busy_until"] = end
	r["next_at"] = end + PHASE_WINDOW[ph]


## Lance l'attaque p : événements datés (fx "ev") et contrôleurs (fx "sweep", "orbs", "walleyes"…) ; renvoie
## l'instant où elle finit. Nombres de la phase selon TIER, vitesses selon PHASE_SPEED.
static func cast(sim: Simulation, r: Dictionary, u: Unit, p: String, now: float) -> float:
	var k: float = PHASE_SPEED[int(r["phase"])]
	var ph: int = TIER[int(r["phase"])]
	var end := now
	match p:
		"regard":
			var rounds: int = PHASE_ROUNDS[ph]
			var step: float = LANE["warn"] + LANE["shots"] * LANE["every"] + LANE["rest"]
			for i in rounds:
				GameState.oeil_fx.append({"type": "aim", "at": now + LANE["open"] + i * step})
			end = now + LANE["open"] + rounds * step
		"larmes":
			r["open_to"] = TEARS["open_to"]
			r["weep"] = true
			var n: int = TEARS["count"][ph]
			for i in n:
				_ev(now + TEARS["open"] + i * TEARS["every"], "tear", {"exact": i % int(TEARS["exact"]) == 0})
			end = now + TEARS["open"] + n * TEARS["every"] + TEARS["flight"] / k + TEARS["burst_at"] + TEARS["rest"]
		"cils":
			var arms: int = CILS["arms"][ph]
			var n: int = CILS["shots"][ph]
			var off := (u.pos() - center()).angle() + PI / arms
			var w: float = CILS["turn"] * (1.0 if sim.rng.randf() < 0.5 else -1.0)
			for i in n:
				_ev(now + CILS["open"] + i * CILS["every"], "spiral", {"off": off, "arms": arms})
				off += w
				if i == n / 2:
					w = -w
			end = now + CILS["open"] + n * CILS["every"] + CILS["rest"]
		"strabisme":
			var g := (u.pos() - center()).angle()
			var fire: float = now + SQUINT["warn"]
			var dur: float = SQUINT["spread"] * 2.0 / (SQUINT["turn"] * k) + 0.6
			for dir: float in [1.0, -1.0]:
				var a0: float = g - dir * SQUINT["spread"]
				GameState.oeil_fx.append({"type": "sweep", "a0": a0, "a": a0, "dir": dir, "at": now, "fire": fire,
					"shots": 0, "until": fire + dur})
			r["lock"] = g
			end = fire + dur
		"pupilles":
			r["iris_out"] = true
			var base := sim.rng.randf() * TAU
			var list: Array = []
			for i in PUPILS["count"]:
				var pe := Enemy.make(PUPIL_KIND, center().x, center().y + foot().y, 99.0)
				pe.beast = true
				pe.memo["slot"] = i
				pe.memo["h"] = PUPILS["h0"]
				GameState.enemies.append(pe)
				list.append(pe)
			var t1: float = now + PUPILS["out"] + PUPILS["dur"]
			GameState.oeil_fx.append({"type": "orbs", "at": now, "base": base, "pupils": list,
				"shot": now + PUPILS["out"] + 0.3, "ring": now + PUPILS["out"] + 1.0, "back": t1, "until": t1 + PUPILS["out"]})
			end = t1 + PUPILS["out"] + 0.2
		"fixation":
			var n: int = FIX["count"][ph]
			var span: float = FIX["dur"] + FIX["gap"]
			for i in n:
				var t0: float = now + FIX["open"] + i * span
				_ev(t0, "mark", {})
				for j in FIX["seekers"]:
					_ev(t0 + j * FIX["dur"] / FIX["seekers"], "seek", {})
			end = now + FIX["open"] + n * span
		"clignement":
			r["close"] = true
			r["dark"] = true
			var n: int = BLINK["rings"][ph]
			var t0: float = now + BLINK["dark"]
			for i in n:
				var ti: float = t0 + i * (BLINK["every"] + BLINK["shut"])
				if i > 0:
					_ev(ti - BLINK["shut"], "shut", {})
				_ev(ti, "blink", {"i": i})
			var last: float = t0 + (n - 1) * (BLINK["every"] + BLINK["shut"]) + BLINK["every"]
			_ev(last, "light", {})
			end = last + 0.3
		"milleyeux":
			r["close"] = true
			var t0: float = now + WALLS["start"]
			var every: float = WALLS["every"] / k
			end = t0 + WALLS["waves"] * every + WALLS["rest"]
			GameState.oeil_fx.append({"type": "walleyes", "at": now, "until": end})
			_ev(now + WALLS["wake"], "wake", {})
			for i in WALLS["waves"]:
				_ev(t0 + i * every, "wall", {"both": i >= 2 and i % 2 == 0, "side": i % 2})
	return end


static func _ev(at: float, op: String, args: Dictionary) -> void:
	var f := {"type": "ev", "at": at, "op": op}
	f.merge(args)
	GameState.oeil_fx.append(f)


## Retour à l'état visuel neutre (fin d'attaque, changement de phase, sortie de la salle).
static func _clear_vis(r: Dictionary) -> void:
	for key: String in ["close", "dark", "iris_out", "weep", "open_to"]:
		r.erase(key)


## Événement daté d'une attaque.
static func _event(sim: Simulation, f: Dictionary, u: Unit, now: float, k: float, born: Array[Dictionary]) -> void:
	var r := run()
	var ph: int = TIER[int(r.get("phase", 0))]
	match f["op"]:
		"tear":
			if u == null:
				return
			var t := u.pos()
			if not f["exact"]:
				t += Vector2((sim.rng.randf() * 2.0 - 1.0) * TEARS["spread_x"], (sim.rng.randf() * 2.0 - 1.0) * TEARS["spread_z"])
			t = _landing(t)
			var s := center() + Vector2((sim.rng.randf() - 0.5) * 2.0, foot().y - 0.5)
			var b := shoot(s, 0.0, 0.0, false, {"style": "larme"})
			b["arc"] = {"x0": s.x, "z0": s.y, "tx": t.x, "tz": t.y, "t0": now, "T": TEARS["flight"] / k, "h0": PUPILS["h0"],
				"H": TEARS["arc"]}
		"spiral":
			var arms: int = f["arms"]
			for j in arms:
				var a: float = f["off"] + j * TAU / arms
				shoot(emit(a), a, CILS["speed"] * k, false, {"style": "cil", "acc": CILS["acc"], "max": CILS["max"] * k})
		"mark":
			if u == null:
				return
			born.append({"type": "ret", "x": u.x, "z": u.z, "at": now, "until": now + FIX["dur"], "r": FIX["r0"],
				"follow": FIX["follow"][ph]})
		"seek":
			if u == null:
				return
			var q := emit(sim.rng.randf() * TAU)
			var b := shoot(q, (u.pos() - q).angle(), LANE["seek_speed"] * k, false)
			b["home_until"] = now + LANE["seek_time"]
		"shut":
			r["close"] = true
		"blink":
			r["close"] = false
			r["flash_at"] = now
			var i: int = f["i"]
			var gap := ((u.pos() - center()).angle() if u != null else PI / 2.0) + (sim.rng.randf() * 2.0 - 1.0) * BLINK["aim"]
			var off := sim.rng.randf() * TAU
			var n: int = BLINK["n"]
			for j in n:
				var a := off + j * TAU / n
				if absf(wrapf(a - gap, -PI, PI)) < BLINK["gap"] or absf(wrapf(a - gap - PI, -PI, PI)) < BLINK["gap"]:
					continue
				shoot(emit(a), a, (BLINK["speed"] + i * BLINK["step"]) * k, j % int(BLINK["big"]) == 0)
		"light":
			r["dark"] = false
		"wake":
			r["close"] = false
		"wall":
			if f["both"]:
				_wall(sim, 0, k)
				_wall(sim, 1, k)
			else:
				_wall(sim, int(f["side"]), k)


## Point de chute d'une larme : hors de la base, dans la salle.
static func _landing(t: Vector2) -> Vector2:
	var c := center()
	if in_foot(t.x, t.y, 2.0):
		var a := atan2((t.y - c.y) / (foot().y + 2.0), (t.x - c.x) / (foot().x + 2.0))
		t = c + Vector2(cos(a) * (foot().x + 2.3), sin(a) * (foot().y + 2.3))
	while not in_room(t.x, t.y, -1.0) and t.distance_to(c) > 1.0:
		t = t.lerp(c, 0.1)
	return t


## Mur d'yeux des mille yeux : side 0 depuis la paroi ouest vers l'est, side 1 depuis le fond vers l'avant ; une brèche.
static func _wall(sim: Simulation, side: int, k: float) -> void:
	var c := center()
	var rx := TerrainState.EYE_ROOM_RX
	var rz := TerrainState.EYE_ROOM_RZ
	var step: float = WALLS["row"]
	if side == 0:
		var gap := c.y + (sim.rng.randf() * 2.0 - 1.0) * (rz - 6.0)
		var z := c.y - rz + 1.0
		while z < c.y + rz - 1.0:
			if absf(z - gap) >= WALLS["gap"]:
				var x := c.x
				while TerrainState.in_eye_room(x - 0.5, z, -0.8):
					x -= 0.5
				if x < c.x - 1.0:
					shoot(Vector2(x, z), 0.0, WALLS["speed_x"] * k, false, {"wall": true, "life": WALLS["life"]})
			z += step
	else:
		var gap := c.x + (sim.rng.randf() * 2.0 - 1.0) * (rx - 8.0)
		var x := c.x - rx + 1.0
		while x < c.x + rx - 1.0:
			if absf(x - gap) >= WALLS["gap"]:
				var z := c.y
				while TerrainState.in_eye_room(x, z - 0.5, -0.8):
					z -= 0.5
				if z < c.y - 1.0:
					shoot(Vector2(x, z), PI / 2.0, WALLS["speed_z"] * k, false, {"wall": true, "life": WALLS["life"]})
			x += step * 1.1


## Position et hauteur de vol (px) de la pupille `slot` à l'instant now.
static func pupil_at(f: Dictionary, slot: int, now: float) -> Array:
	var out: float = PUPILS["out"]
	var t := now - float(f["at"])
	var o := clampf(t / out, 0.0, 1.0) if now < float(f["back"]) else clampf(1.0 - (now - float(f["back"])) / out, 0.0, 1.0)
	o = o * o * (3.0 - 2.0 * o)
	var k: float = PHASE_SPEED[int(run().get("phase", 0))]
	var a: float = f["base"] + slot * TAU / PUPILS["count"] + PUPILS["orbit"] * k * maxf(0.0, t - out)
	var c := center()
	var reach := HOST_ORBIT if hosted() else 1.0
	var p := (c + Vector2(0.0, foot().y)).lerp(c + Vector2(cos(a) * PUPILS["rx"], sin(a) * PUPILS["rz"]) * reach, o)
	return [p, lerpf(PUPILS["h0"], PUPILS["h1"], o)]


static func _remove_pupils() -> void:
	GameState.enemies = GameState.enemies.filter(func(e: Enemy) -> bool: return e.kind != PUPIL_KIND)


## Annonces, couloirs, balayages, pupilles, flaques et marques ; événements datés lancés à leur heure.
static func update_fx(sim: Simulation, u: Unit, now: float, dt: float) -> void:
	if GameState.oeil_fx.is_empty():
		return
	var r := run()
	var k: float = PHASE_SPEED[int(r.get("phase", 0))]
	var ph: int = TIER[int(r.get("phase", 0))]
	var keep: Array[Dictionary] = []
	var born: Array[Dictionary] = []
	for f: Dictionary in GameState.oeil_fx:
		match f["type"]:
			"ev":
				if now < float(f["at"]):
					keep.append(f)
				else:
					_event(sim, f, u, now, k, born)
			"aim":
				if now < float(f["at"]):
					keep.append(f)
					continue
				if u == null:
					continue
				var a := (u.pos() - center()).angle()
				r["lock"] = a
				var fire: float = now + LANE["warn"]
				born.append({"type": "lane", "a": a, "at": now, "fire": fire, "shots": 0,
					"until": fire + LANE["shots"] * LANE["every"] + 0.25})
			"lane":
				var fire: float = f["fire"]
				while now >= fire + f["shots"] * LANE["every"] and f["shots"] < LANE["shots"]:
					var i: int = f["shots"]
					f["shots"] = i + 1
					var p := emit(f["a"])
					shoot(p, f["a"] + (sim.rng.randf() * 2.0 - 1.0) * LANE["jitter"], LANE["speed"] * k, i % LANE["big"] == 0)
					if u != null and i % LANE["seek_every"] == 0:
						var q := emit(sim.rng.randf() * TAU)
						var b := shoot(q, (u.pos() - q).angle(), LANE["seek_speed"] * k, false)
						b["home_until"] = now + LANE["seek_time"]
				if now < float(f["until"]):
					keep.append(f)
				else:
					r.erase("lock")
			"sweep":
				var fire: float = f["fire"]
				if now >= fire:
					var every: float = SQUINT["every"]
					while now >= fire + f["shots"] * every and fire + f["shots"] * every < float(f["until"]):
						var i: int = f["shots"]
						f["shots"] = i + 1
						var a: float = f["a0"] + f["dir"] * SQUINT["turn"] * k * i * every
						f["a"] = a
						if i % int(SQUINT["cycle"]) < int(SQUINT["on"]):
							shoot(emit(a), a, SQUINT["speed"] * k, i % int(SQUINT["big"]) == 0)
					r["lock"] = wrapf(float(f["a"]) - f["dir"] * (SQUINT["turn"] * k * (now - fire) - SQUINT["spread"]), -PI, PI)
				if now < float(f["until"]):
					keep.append(f)
				else:
					r.erase("lock")
			"orbs":
				var alive: Array = []
				for pe: Enemy in f["pupils"]:
					if pe.hp > 0.0 and GameState.enemies.has(pe):
						alive.append(pe)
						var at := pupil_at(f, int(pe.memo["slot"]), now)
						pe.x = at[0].x
						pe.z = at[0].y
						pe.memo["h"] = at[1]
				f["pupils"] = alive
				var shooting := now < float(f["back"])
				if shooting and u != null and now >= float(f["shot"]):
					f["shot"] = float(f["shot"]) + PUPILS["shot"]
					for pe: Enemy in alive:
						shoot(pe.pos(), (u.pos() - pe.pos()).angle(), PUPILS["shot_speed"] * k, false)
				if shooting and now >= float(f["ring"]):
					f["ring"] = float(f["ring"]) + PUPILS["ring_every"]
					for pe: Enemy in alive:
						_ring(pe.pos(), PUPILS["ring"], PUPILS["ring_speed"] * k, sim.rng.randf() * TAU, {"style": "larme"})
				if now < float(f["until"]) and not alive.is_empty():
					keep.append(f)
				else:
					_remove_pupils()
					r.erase("iris_out")
			"puddle":
				if not f["done"] and now >= float(f["burst"]):
					f["done"] = true
					_ring(Vector2(f["x"], f["z"]), TEARS["burst"][ph], TEARS["burst_speed"] * k, sim.rng.randf() * TAU,
						{"style": "larme", "acc": 3.0, "max": 11.5 * k})
				if now < float(f["until"]):
					keep.append(f)
			"ret":
				var span: float = FIX["dur"]
				var q := clampf((now - float(f["at"])) / span, 0.0, 1.0)
				f["r"] = lerpf(FIX["r0"], FIX["r1"], q)
				if u != null:
					var d := u.pos() - Vector2(f["x"], f["z"])
					var m := d.length()
					if m > 0.05:
						var s := minf(m, float(f["follow"]) * dt)
						f["x"] = float(f["x"]) + d.x / m * s
						f["z"] = float(f["z"]) + d.y / m * s
				if now < float(f["until"]):
					keep.append(f)
					continue
				var c := Vector2(f["x"], f["z"])
				if u != null and u.pos().distance_to(c) < FIX["r1"] + BULLET["hit"] and hurt_engineer(sim, u, FIX["damage"], now):
					_heal_on_hit()
					Combat.flash(u.x, u.z, Color("#ff8a6a"))
				_ring(c, FIX["ring"][ph], FIX["ring_speed"] * k, sim.rng.randf() * TAU, {})
				_ring(c, FIX["big"], FIX["big_speed"] * k, sim.rng.randf() * TAU, {"big": true})
				born.append({"type": "boom", "x": c.x, "z": c.y, "at": now, "until": now + 0.7})
			_:
				if now < float(f["until"]):
					keep.append(f)
	keep.append_array(born)
	GameState.oeil_fx = keep


static func _ring(p: Vector2, n: int, v: float, off: float, opts: Dictionary) -> void:
	for i in n:
		var a := off + i * TAU / n
		shoot(p, a, v, opts.get("big", false), opts)


## Vitesse des petites balles (tout sauf les grosses) : ×1,5 depuis le 2026-11-21, accélération et vitesse max comprises.
const SMALL_SPEED := 1.5


## Balle : style ("oeil", "larme", "cil"), accélération (acc, vitesse max), mur des mille yeux (wall : arrêtée par la
## masse), durée de vie (life). Une larme en cloche (arc) ne touche qu'à l'atterrissage.
static func shoot(p: Vector2, a: float, v: float, big: bool, opts: Dictionary = {}) -> Dictionary:
	var m := 1.0 if big else SMALL_SPEED
	v *= m
	var b := {"x": p.x, "z": p.y, "vx": cos(a) * v, "vz": sin(a) * v, "big": big, "home_until": -INF,
		"until": GameState.sim_time + float(opts.get("life", BULLET["life"])), "style": opts.get("style", "oeil"),
		"acc": float(opts.get("acc", 0.0)) * m, "max": float(opts.get("max", INF)) * m, "wall": opts.get("wall", false), "h": 0.0}
	GameState.oeil_bullets.append(b)
	return b


static func hurt_engineer(sim: Simulation, u: Unit, amount: float, now: float) -> bool:
	var r := run()
	if now < float(r.get("iframe_until", -INF)):
		return false
	sim.combat.damage(u, Combat.boss_shot(u.z))
	r["iframe_until"] = now + IFRAMES
	return true


## Cibles des balles : l'Ingénieur en duel ; quand un autre boss joue ses attaques, toutes les unités de son arène.
static func _victims(u: Unit) -> Array[Unit]:
	if hosted():
		return Archipretre.squad()
	var out: Array[Unit] = []
	if u != null:
		out.append(u)
	return out


## Une balle touche v. L'Ingénieur : coup de boss et invulnérabilité (hurt_engineer). Les autres unités (attaques
## prêtées) : dégâts de la balle après armure, et la même invulnérabilité, chacune la sienne.
static func _hit(sim: Simulation, v: Unit, amount: float, now: float) -> bool:
	if v.role == "engineer":
		return hurt_engineer(sim, v, amount, now)
	var safe: Dictionary = run().get("hit_until", {})
	var id := v.get_instance_id()
	if now < float(safe.get(id, -INF)):
		return false
	safe[id] = now + IFRAMES
	run()["hit_until"] = safe
	sim.combat.damage(v, Combat.after_armor(v, amount))
	return true


## L'Œil reprend HEAL_ON_HIT de ses PV max à chaque projectile qui touche l'Exilé (2026-11-23).
const HEAL_ON_HIT := 0.05


static func _heal_on_hit() -> void:
	var e: Enemy = GameState.oeil
	if e == null or e.hp <= 0.0:
		return
	var healed := minf(e.max_hp - e.hp, e.max_hp * HEAL_ON_HIT)
	if healed <= 0.0:
		return
	e.hp += healed
	GameState.damage_numbers.append({"target": e, "x": e.x, "z": e.z, "amount": healed, "age": -0.2, "duration": 0.9, "heal": true})


## Vol des balles : larmes en cloche, accélération, guidage des yeux chercheurs, murs arrêtés par la masse, sortie de
## la salle, touche sur l'Ingénieur en duel.
static func update_bullets(sim: Simulation, u: Unit, now: float, dt: float) -> void:
	if GameState.oeil_bullets.is_empty():
		return
	var keep: Array[Dictionary] = []
	var landed: Array[Dictionary] = []
	var victims := _victims(u)
	for b: Dictionary in GameState.oeil_bullets:
		if b.has("arc"):
			var A: Dictionary = b["arc"]
			var q := (now - float(A["t0"])) / float(A["T"])
			if q >= 1.0:
				landed.append(b)
				continue
			b["x"] = lerpf(A["x0"], A["tx"], q)
			b["z"] = lerpf(A["z0"], A["tz"], q)
			b["vx"] = float(A["tx"]) - float(A["x0"])
			b["vz"] = float(A["tz"]) - float(A["z0"])
			b["h"] = lerpf(A["h0"], 0.0, q) + 4.0 * float(A["H"]) * q * (1.0 - q)
			keep.append(b)
			continue
		var acc: float = b.get("acc", 0.0)
		if acc != 0.0:
			var v := Vector2(b["vx"], b["vz"])
			var sp := v.length()
			if sp > 1e-4:
				v *= minf(sp + acc * dt, float(b["max"])) / sp
				b["vx"] = v.x
				b["vz"] = v.y
		if u != null and now < float(b["home_until"]):
			var v := Vector2(b["vx"], b["vz"])
			var want := (u.pos() - Vector2(b["x"], b["z"])).angle()
			var na := v.angle() + clampf(wrapf(want - v.angle(), -PI, PI), -LANE["seek_turn"] * dt, LANE["seek_turn"] * dt)
			v = Vector2.from_angle(na) * v.length()
			b["vx"] = v.x
			b["vz"] = v.y
		b["x"] += b["vx"] * dt
		b["z"] += b["vz"] * dt
		if now >= float(b["until"]) or not in_room(b["x"], b["z"], 0.5):
			# Fin de la braise (ShotEnds « fire ») : gerbe et suie contre la paroi, ou braise étouffée en fin de vie.
			var mode := "range" if now >= float(b["until"]) else "wall"
			GameState.oeil_fx.append({"type": "end", "mode": mode, "x": b["x"], "z": b["z"], "vx": b["vx"], "vz": b["vz"],
				"big": b["big"] and b.get("style", "oeil") == "oeil", "h": b.get("h", 0.0),
				"at": now, "until": now + float(ShotEnds.DUR["fire"][0 if mode == "wall" else 1])})
			continue
		if b.get("wall", false) and in_foot(b["x"], b["z"], -0.5):
			GameState.oeil_fx.append({"type": "mote", "x": b["x"], "z": b["z"], "at": now, "until": now + 0.9})
			continue
		var big: bool = b["big"]
		var reach: float = BULLET["hit"] + (BULLET["big_r"] if big else BULLET["r"])
		var spent := false
		for v: Unit in victims:
			var dx: float = v.x - b["x"]
			var dz: float = v.z - b["z"]
			if dx * dx + dz * dz < reach * reach and _hit(sim, v, BULLET["big_damage"] if big else BULLET["damage"], now):
				_heal_on_hit()
				Combat.flash(v.x, v.z, Color("#ff8a6a"))
				spent = true
				break
		if not spent:
			keep.append(b)
	GameState.oeil_bullets = keep
	# Larmes posées : éclaboussure tout de suite, flaque qui éclate un peu plus tard.
	var k: float = PHASE_SPEED[int(run().get("phase", 0))]
	for b: Dictionary in landed:
		var A: Dictionary = b["arc"]
		var p := Vector2(A["tx"], A["tz"])
		GameState.oeil_fx.append({"type": "puddle", "x": p.x, "z": p.y, "at": now, "burst": now + TEARS["burst_at"],
			"until": now + TEARS["puddle"], "done": false})
		GameState.oeil_fx.append({"type": "splash", "x": p.x, "z": p.y, "at": now, "until": now + 0.6})
		_ring(p, TEARS["splash"], TEARS["splash_speed"] * k, sim.rng.randf() * TAU, {"style": "larme", "acc": 3.75, "max": 8.75 * k})


## Balles éteintes (en éclats si motes), annonces, couloirs et pupilles retirés.
static func _extinguish(motes: bool) -> void:
	var now := GameState.sim_time
	var keep: Array[Dictionary] = []
	if motes:
		for b: Dictionary in GameState.oeil_bullets:
			keep.append({"type": "mote", "x": b["x"], "z": b["z"], "at": now, "until": now + 0.9})
	GameState.oeil_bullets.clear()
	GameState.oeil_fx = keep
	_remove_pupils()
	run().erase("lock")
	# Motifs de la Martyre en cours (phases I et III) : éteints avec le reste.
	if Martyre.host() == KIND:
		Martyre.host_clear(motes)


# ---------------------------------------------------------------- Attaques prêtées

## Phase dont un hôte joue les attaques (nombres et vitesses de la phase II).
const HOST_PHASE := 1


## Un autre boss (`who` : son KIND) joue les attaques de la phase II : balles, annonces et pupilles passent par les
## mêmes listes (GameState.oeil_bullets, oeil_fx) et le même rendu (world/oeil/oeil_fx.gd), centrées sur lui.
static func host_begin(who: String) -> void:
	GameState.oeil_host = who
	GameState.oeil_bullets.clear()
	GameState.oeil_fx.clear()
	GameState.oeil_host_run = {"at": GameState.sim_time, "phase": HOST_PHASE, "cast": false, "open": 0.0, "look": PI / 2.0,
		"iframe_until": -INF, "hit_until": {}, "pattern": ""}


## L'hôte lance l'attaque p sur u ; renvoie l'instant où elle finit.
static func host_cast(sim: Simulation, u: Unit, p: String, now: float) -> float:
	var r := run()
	r["pattern"] = p
	return cast(sim, r, u, p, now)


## À chaque pas de l'hôte : annonces, événements et vol des balles ; u est la cible visée (ou null).
static func host_tick(sim: Simulation, u: Unit, now: float, dt: float) -> void:
	update_fx(sim, u, now, dt)
	update_bullets(sim, u, now, dt)


## Balles, annonces et pupilles de l'hôte éteintes (en éclats si motes).
static func host_clear(motes: bool) -> void:
	_extinguish(motes)
	_clear_vis(run())


static func host_end() -> void:
	GameState.oeil_bullets.clear()
	GameState.oeil_fx.clear()
	_remove_pupils()
	GameState.oeil_host = ""
	GameState.oeil_host_run = {}


static func hurt(e: Enemy) -> void:
	if GameState.sim_time - e.hurt_at >= 0.3:
		e.hurt_at = GameState.sim_time


## Les autres unités ne restent pas dans la salle : reconduites au point de sortie praticable le plus proche.
static func enforce(sim: Simulation) -> void:
	if not active():
		return
	var exits: Array[Vector2] = []
	for u: Unit in GameState.units:
		if u.role == "engineer" or not u.alive() or u.hidden or not TerrainState.in_eye_room(u.x, u.z):
			continue
		if exits.is_empty():
			exits = _exits(sim)
			if exits.is_empty():
				return
		var best := exits[0]
		for p: Vector2 in exits:
			if p.distance_to(u.pos()) < best.distance_to(u.pos()):
				best = p
		u.x = best.x
		u.z = best.y
		u.tx = best.x
		u.tz = best.y
		u.force_move = false


## Points praticables juste au-delà de la paroi (l'entrée creusée par les Exilés).
static func _exits(sim: Simulation) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var c := center()
	for k in 96:
		var a := k * TAU / 96.0
		var s := TerrainState.eye_room_scale(atan2(sin(a), cos(a)))
		for g: float in [EDGE, EDGE + 1.5, EDGE + 3.0]:
			var p := c + Vector2(cos(a) * (TerrainState.EYE_ROOM_RX * s + g), sin(a) * (TerrainState.EYE_ROOM_RZ * s + g))
			if sim.state().walkable(p.x, p.y) and not TerrainState.in_eye_room(p.x, p.y):
				out.append(p)
				break
	return out


static func objective() -> Dictionary:
	if not active() or GameState.oeil_state != "duel":
		return {}
	var e: Enemy = GameState.oeil
	return {"id": "oeil", "quest": "L’Œil de la Matrice", "interrupt": true,
		"label": "Abattre l’Œil de la Matrice pour ouvrir la frontière", "quote": "", "done_quote": "",
		"value": "%d PV" % ceili(e.hp), "progress": 1.0 - e.hp / e.max_hp}
