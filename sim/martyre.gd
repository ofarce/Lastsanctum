class_name Martyre
extends RefCounted
## Premier boss : la Martyre de Byrsa (planches/martyre-v3-propositions.html : modèle C2 « L'armure cède »,
## fissure 4.1 « Faille en relief », sceaux 5.3 « Rai du ciel » ; atlas martyre_*.png exportés par
## planches/martyre-v3-export.html, animations et attaques 30 % plus rapides que la planche, SPEED).
## Salves façon « bullet hell » : planches/martyre-bullet-hell.html (bilan du 2026-11-19).
##
## Quand la menace atteint MENACE, elle apparaît seule sur la route du sud ; la suite de l'assaut en cours est
## annulée et aucune vague ne part tant qu'elle vit. Elle lève aussitôt un bouclier circulaire de
## DOME_CELLS cases de diamètre centré sur elle (rendu : world/arena/martyre_dome.gd) :
## - invulnérable : seuls les coups de l'Ingénieur, porté depuis l'intérieur, la blessent (Combat.damage) ;
## - rien ne vise à travers : une cible n'est visée que si elle est du même côté que le tireur
##   (Combat.target_closest, ciblage des ennemis) ;
## - seul l'Ingénieur le traverse : les autres unités, alliées comme ennemies, sont repoussées au bord.
## Le combat singulier commence quand l'Ingénieur entre. Au contact, elle frappe du bâton (DAMAGE IMPACT s après
## le début du geste, esquivé en s'éloignant). À distance, elle enchaîne des motifs de balles (éclats d'or),
## chacun annoncé par un geste, suivis d'une fenêtre de souffle où elle marche vers l'Ingénieur :
## - fissure ardente : la faille court vers la position visée en crachant des braises de part et d'autre ;
##   l'éruption au bout (dégâts et étourdissement) projette un anneau d'éclats ;
## - larmes d'or : cinq grosses balles en éventail qui freinent puis éclatent chacune en éclats ;
## - rosace des sceaux : les trois sceaux sous l'Ingénieur et de part et d'autre ; à l'impact, chacun fleurit
##   en deux anneaux décalés ;
## - litanie du dôme : un pan du bouclier s'embrase et trois murs d'éclats traversent l'arène, la brèche
##   annoncée par un couloir de lumière.
## Trois phases selon ses PV (PHASE_HP) : rotation, vitesse des balles et fenêtre propres (ROTATION) ; à chaque
## changement, les balles en vol s'éteignent en éclats qui filent vers l'Ingénieur, et en phase III le bouclier se
## resserre à RADIUS_III. Après un coup, l'Ingénieur est invulnérable IFRAMES s (il clignote).
## S'il ressort du bouclier, elle regagne le centre et attend, sans se soigner ; ses balles et gestes en cours
## s'éteignent. Effets : GameState.martyre_fx et martyre_bullets (rendu : world/arena/martyre_fx.gd).
## L'objectif « Éliminer la Martyre de Byrsa en combat singulier » (Quests) dure jusqu'à sa mort.

const KIND := "martyre"
const MENACE := 500
const CELL := 4.0
## Bouclier : 24 cases de diamètre, soit 48 unités de rayon.
const DOME_CELLS := 24
const RADIUS := DOME_CELLS * CELL / 2.0
## Phase III : le bouclier se resserre à 18 cases de diamètre en SHRINK s.
const RADIUS_III := 18 * CELL / 2.0
const SHRINK := 4.0
## Sur la route du sud, là où montent les assauts, assez loin du bord du monde (z = 72) pour que tout le
## bouclier tienne sur la carte.
const SPAWN := Vector2(0.0, 22.0)
## Animations et attaques 30 % plus rapides que la planche.
const SPEED := 1.3
const DAMAGE := 10.0
## Délai entre le début de la frappe et l'impact du bâton (moitié de l'animation martyre_attack).
const IMPACT := 0.5 / SPEED
## Durée du geste de frappe (martyre_attack) et de l'incantation (martyre_cast) : elle reste sur place.
const STRIKE_TIME := 1.0 / SPEED
const CAST_TIME := 2.2 / SPEED
## Marge de portée tolérée à l'impact : au-delà, le coup est esquivé.
const DODGE := 0.8
## Point d'impact du bâton devant elle (unités), d'où part la fissure.
const STAFF_REACH := 2.4
## Fissure : portée, vitesse de la faille, dégâts et étourdissement au bout, rayon touché par l'éruption,
## durée de l'éruption puis du refroidissement ; nombre de failles en éventail et angle entre deux failles.
const FISSURE := {"range": 22.0, "speed": 20.0 * SPEED, "damage": 12.0, "stun": 1.0,
	"radius": 2.2, "erupt": 0.9 / SPEED, "cool": 0.9 / SPEED, "count": 3, "spread": deg_to_rad(35.0)}
## Sceaux : instant de pose après le début du geste, charge, dégâts, rayon d'un sceau, écart des sceaux
## latéraux, durée de la colonne.
const SEALS := {"place": 0.6 / SPEED, "charge": 1.3 / SPEED, "damage": 14.0,
	"radius": 2.0, "spread": 5.0, "boom": 0.9 / SPEED}
## Les autres unités sont rejetées à cette distance au-delà du bord.
const EDGE := 0.6
## Effondrement du bouclier à la mort de la Martyre (rendu).
const COLLAPSE := 1.4
## Réaction aux coups : au plus une fois par seconde.
const HURT_EVERY := 1.0

## Balles (unités de monde ; 8 px natifs par unité) : rayon d'une petite et d'une grosse, rayon de la zone qui
## encaisse chez l'Ingénieur, dégâts, hauteur de vol en pixels natifs, marge au-delà du bord où elles
## s'éteignent. Elles volent à hauteur de poitrine : la zone touchée est dessinée là (point blanc sur
## l'Ingénieur, MartyreFx), et une balle touche quand son losange passe sur ce point (son ombre au sol, sous ses pieds).
const BULLET := {"r": 0.31, "big_r": 0.62, "hit": 0.375, "damage": 4.0, "big_damage": 8.0, "lift": 17.0, "edge": 0.4}
const IFRAMES := 0.6
## Multiplicateur de tous les coups portés à l'Ingénieur (2026-11-19 : dégâts des boss doublés).
const DAMAGE_MULT := 2.0
## Silhouette (atlas martyre_idle : 77 px de haut, ~40 px de large sans le bâton), en unités au sol : la vue de
## 3/4 projette son corps vers le nord de ses pieds. Un tir (ou un clic) qui passe sur sa silhouette la touche :
## demi-largeur, hauteur projetée (au nord des pieds), marge au sud ; allonge ajoutée aux coups au contact.
const BODY := {"half_w": 2.5, "top": 9.5, "foot": 0.8, "melee": 1.4}
## Phases : fraction de PV au-dessus de laquelle on reste en phase I puis II ; vitesse des balles ; fenêtre de
## souffle après chaque motif ; pause au changement de phase ; délai du premier motif à l'entrée en duel.
const PHASE_HP := [2.0 / 3.0, 1.0 / 3.0]
const PHASE_SPEED := [1.0, 1.1, 1.2]
const PHASE_WINDOW := [1.4, 1.2, 1.0]
const PHASE_NAMES := ["I · Le serment", "II · L’armure cède", "III · Fendue"]
const PHASE_PAUSE := 1.0
const FIRST_PATTERN := 2.0
## Rotation des motifs par phase (dans l'ordre, puis on boucle) ; une ligne lance ses motifs ensemble.
const ROTATION := [
	[["fissure"], ["larmes"], ["rosace"]],
	[["litanie"], ["larmes", "fissure"], ["rosace"]],
	[["litanie", "fissure"], ["larmes", "rosace"], ["litanie", "larmes"]],
]
## Fissure ardente : une paire de braises tous les « step » u de faille (pas dans le rayon de l'éruption),
## vitesse, freinage, vitesse plancher, durée ; anneau à l'éruption.
const EMBER := {"step": 1.5, "speed": 5.6, "acc": -5.0, "min": 1.5, "life": 4.0, "ring": 16, "ring_speed": 7.5}
## Larmes d'or : nombre, écart angulaire, vitesse, freinage, plancher, éclatement (après le tir, + rang × stagger),
## éclats, vitesse des éclats, délai du tir après le début du geste, durée du motif.
const LARMES := {"count": 5, "spread": 0.5, "speed": 18.75, "acc": -20.0, "min": 1.0, "fuse": 1.0, "stagger": 0.12,
	"shards": 10, "shard_speed": 6.875, "delay": 0.5, "time": 2.4}
## Rosace : glyphes par anneau, vitesse du premier et du second anneau, délai du second.
const ROSACE := {"count": 12, "speed": 6.875, "speed2": 5.625, "second": 0.3, "time": 0.5}
## Litanie : murs, couloir d'annonce, écart entre deux murs, pas entre deux balles, demi-largeur de la brèche,
## vitesse, décalage aléatoire de la brèche autour de l'Ingénieur, part du rayon où elle peut tomber.
const LITANIE := {"walls": 3, "warn": 0.9, "every": 1.5, "step": 1.625, "gap": 3.5, "speed": 8.75, "jitter": 7.5,
	"reach": 0.6, "time": 1.0}
## Halo d'or qui se resserre avant une incantation ; éclats d'une balle éteinte.
const HALO := 0.5
const MOTE := 0.9

const QUOTE_WAIT := "Un dôme d’or s’est levé au sud. La Martyre de Byrsa m’attend : personne d’autre ne peut passer."
const QUOTE_DUEL := "Ses salves laissent toujours une brèche : je dois la lire, m’y glisser, puis frapper quand elle reprend son souffle."
const QUOTE_DONE := "La Martyre est tombée et son dôme avec elle. Les assauts vont reprendre."


## La Martyre est sur le terrain, vivante : bouclier levé, vagues suspendues.
static func active() -> bool:
	return GameState.martyre != null and GameState.martyre.hp > 0.0


static func center() -> Vector2:
	return GameState.martyre_center


## Rayon courant du bouclier (unités) : RADIUS, puis RADIUS_III une fois resserré.
static func radius() -> float:
	return GameState.martyre_radius


## p (unité, ennemi, baliste {x, z}) est-il sous le bouclier ?
static func inside(p: Variant) -> bool:
	var dx: float = p.x - GameState.martyre_center.x
	var dz: float = p.z - GameState.martyre_center.y
	var r := radius()
	return dx * dx + dz * dz < r * r


## Le bouclier sépare a et b : aucun tir ni ciblage de l'un vers l'autre.
static func blocks(a: Variant, b: Variant) -> bool:
	return active() and inside(a) != inside(b)


## Seul l'Ingénieur, sous le bouclier, peut blesser la Martyre.
static func can_hurt(src: Unit) -> bool:
	return src != null and src.role == "engineer" and inside(src)


## L'Ingénieur en duel (vivant, sorti du portail, sous le bouclier), sinon null.
static func duelist() -> Unit:
	if not active():
		return null
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden and inside(u):
			return u
	return null


## Rectangle au sol couvert par la silhouette de e (x0, z0, x1, z1).
static func body_rect(e: Enemy) -> Rect2:
	return Rect2(e.x - BODY["half_w"], e.z - BODY["top"], 2.0 * BODY["half_w"], BODY["top"] + BODY["foot"])


## Distance le long du rayon (from, d normalisé) à laquelle il entre dans la silhouette de e, ou INF.
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


## L'Ingénieur clignote pendant son invulnérabilité (rendu : UnitView).
static func blinking(u: Unit) -> bool:
	var t := GameState.sim_time
	return u.role == "engineer" and t < GameState.martyre_iframe_until and fmod(t * 20.0, 2.0) < 1.0


## Apparition, début et fin du duel, chute : appelé à chaque pas de simulation, avant les apparitions.
static func tick(sim: Simulation) -> void:
	if GameState.ended:
		return
	match GameState.martyre_state:
		"":
			if GameState.menace >= MENACE:
				spawn(sim)
		"waiting", "duel":
			var e: Enemy = GameState.martyre
			if e == null or e.hp <= 0.0:
				GameState.martyre_state = "defeated"
				GameState.martyre_down_at = GameState.sim_time
				GameState.martyre_hit_at = INF
				GameState.martyre_cast_at = INF
				# Ses balles s'éteignent avec elle et filent vers l'Ingénieur.
				_extinguish(GameState.sim_time, true)
				GameState.martyre_fx.assign(GameState.martyre_fx.filter(func(f: Dictionary) -> bool: return f["type"] == "mote"))
				GameState.martyre = null
				return
			var u := duelist()
			if GameState.martyre_state == "waiting" and u != null:
				GameState.martyre_state = "duel"
				if GameState.martyre_next_at == INF:
					GameState.martyre_next_at = GameState.sim_time + FIRST_PATTERN
			elif GameState.martyre_state == "duel" and u == null:
				GameState.martyre_state = "waiting"
				GameState.martyre_hit_at = INF
				GameState.martyre_cast_at = INF
				GameState.martyre_next_at = INF
				_extinguish(GameState.sim_time, false)


## L'Ingénieur est tombé pendant le duel : elle retrouve tous ses PV, sa première phase et son dôme entier.
## Le retour à l'attente (balles éteintes) se fait au pas suivant, faute de duelliste (tick).
static func reset_duel() -> void:
	var e: Enemy = GameState.martyre
	if e == null or e.hp <= 0.0:
		return
	e.hp = e.max_hp
	GameState.martyre_phase = 0
	GameState.martyre_next = []
	GameState.martyre_rot = [0, 0, 0]
	GameState.martyre_radius = RADIUS
	GameState.martyre_shrink_at = INF


static func spawn(sim: Simulation) -> Enemy:
	var p := SPAWN
	if not sim.state().walkable(p.x, p.y):
		p = sim.state().push_out_of_rock(p)
	var e := Enemy.make(KIND, p.x, p.y, 1.0)
	e.face = -1
	GameState.enemies.append(e)
	GameState.martyre = e
	GameState.martyre_state = "waiting"
	GameState.martyre_center = p
	GameState.martyre_at = GameState.sim_time
	GameState.martyre_hit_at = INF
	GameState.martyre_cast_at = INF
	GameState.martyre_busy_until = -INF
	GameState.martyre_fx.clear()
	GameState.martyre_bullets.clear()
	GameState.martyre_events.clear()
	GameState.martyre_phase = 0
	GameState.martyre_next_at = INF
	GameState.martyre_next = []
	GameState.martyre_rot = [0, 0, 0]
	GameState.martyre_radius = RADIUS
	GameState.martyre_shrink_at = INF
	GameState.martyre_iframe_until = -INF
	# Elle vient seule : le reste de l'assaut en cours n'entre pas.
	GameState.spawn_queue.clear()
	GameState.next_wave = 0.0
	Combat.zone(p.x, p.y, 6.0, Color("#f0cc66"))
	Combat.flash(p.x, p.y, Color("#e2382e"))
	Sfx.play("martyre")
	sim.say("La Martyre de Byrsa est entrée par le sud. Son bouclier ne laisse passer que moi.", 4.0)
	enforce(sim)
	return e


## Comportement de la Martyre (à la place de celui des autres ennemis, Combat.update_enemies).
static func act(sim: Simulation, e: Enemy, dt: float) -> void:
	e.cooldown -= dt
	e.stun = 0.0
	var now := GameState.sim_time
	_shrink(e, now)
	var u := duelist()
	_resolve_staff(sim, e, u, now)
	_resolve_cast(e, u, now)
	_run_events(sim, e, u, now)
	update_fx(sim, u, now)
	update_bullets(sim, u, now, dt)
	if u != null:
		_check_phase(sim, e, now)
	if now < GameState.martyre_busy_until:
		return
	if u == null:
		if e.pos().distance_to(center()) > 1.0:
			_walk(sim, e, center(), dt)
		return
	var d := Combat.dist(e, u)
	if d <= e.reach and e.cooldown <= 0.0:
		_start_strike(e, u, "melee", now)
		return
	if now >= GameState.martyre_next_at:
		_start_patterns(sim, e, u, now)
		return
	# Fenêtre de souffle : elle marche vers l'Ingénieur.
	if d > e.reach:
		_walk(sim, e, u.pos(), dt)
	e.face = -1 if u.x < e.x else 1


## Phase d'après les PV : 0 au-dessus des deux tiers, 1 au-dessus du tiers, 2 ensuite.
static func phase_of(e: Enemy) -> int:
	var f := e.hp / maxf(1.0, e.max_hp)
	return 0 if f > PHASE_HP[0] else 1 if f > PHASE_HP[1] else 2


## Changement de phase : balles éteintes, pause, annonce ; en phase III le bouclier commence à se resserrer.
static func _check_phase(sim: Simulation, e: Enemy, now: float) -> void:
	var ph := phase_of(e)
	if ph <= GameState.martyre_phase:
		return
	GameState.martyre_phase = ph
	_extinguish(now, true)
	GameState.martyre_cast_at = INF
	GameState.martyre_busy_until = maxf(GameState.martyre_busy_until, now + PHASE_PAUSE)
	GameState.martyre_next_at = GameState.martyre_busy_until
	Combat.flash(e.x, e.z, Color("#fff2b0"))
	if ph == 2:
		GameState.martyre_shrink_at = now
		sim.say("Phase %s : le dôme se resserre." % PHASE_NAMES[ph], 3.0)
	else:
		sim.say("Phase %s." % PHASE_NAMES[ph], 3.0)


## Éteint les balles en vol (en éclats qui filent vers l'Ingénieur si motes), les gestes à venir, les sceaux
## pas encore tombés et les annonces. La faille en cours reste.
static func _extinguish(now: float, motes: bool) -> void:
	if motes:
		for b: Dictionary in GameState.martyre_bullets:
			if not b["hide"]:
				GameState.martyre_fx.append({"type": "mote", "x": b["x"], "z": b["z"], "at": now, "until": now + MOTE})
	GameState.martyre_bullets.clear()
	GameState.martyre_events.clear()
	GameState.martyre_fx.assign(GameState.martyre_fx.filter(func(f: Dictionary) -> bool:
		return f["type"] == "fissure" or f["type"] == "mote" or (f["type"] == "seal" and f["hit"])))


## Resserrement du bouclier en phase III ; l'Ingénieur et la Martyre restent dedans.
static func _shrink(e: Enemy, now: float) -> void:
	if GameState.martyre_shrink_at == INF:
		return
	var u := duelist()
	var a := clampf((now - GameState.martyre_shrink_at) / SHRINK, 0.0, 1.0)
	GameState.martyre_radius = lerpf(RADIUS, RADIUS_III, a * a * (3.0 - 2.0 * a))
	var r := radius()
	for o: Variant in [u, e]:
		if o == null:
			continue
		var off := Vector2(o.x, o.z) - center()
		if off.length() > r - 1.0:
			var p := center() + off.limit_length(r - 1.0)
			o.x = p.x
			o.z = p.y


## Lance la combinaison suivante (imposée par martyre_next, sinon la rotation de la phase).
static func _start_patterns(sim: Simulation, e: Enemy, u: Unit, now: float) -> void:
	var ph: int = GameState.martyre_phase
	var combo: Array = GameState.martyre_next
	if combo.is_empty():
		var rot: Array = ROTATION[ph]
		var i: int = GameState.martyre_rot[ph]
		combo = rot[i % rot.size()]
		GameState.martyre_rot[ph] = i + 1
	GameState.martyre_next = []
	var until := now
	for id: String in combo:
		until = maxf(until, _start(sim, e, u, id, now))
	GameState.martyre_busy_until = until
	GameState.martyre_next_at = until + PHASE_WINDOW[ph]


## Début d'un motif ; renvoie l'instant où elle a fini.
static func _start(sim: Simulation, e: Enemy, u: Unit, id: String, now: float) -> float:
	match id:
		"fissure":
			_start_strike(e, u, "fissure", now)
			var at := e.pos() + Vector2(e.face * STAFF_REACH, 0.0)
			return now + maxf(STRIKE_TIME, IMPACT + minf(at.distance_to(u.pos()), FISSURE["range"]) / FISSURE["speed"]) + 0.4
		"larmes":
			_cast(e, u, now)
			_halo(e, now)
			GameState.martyre_events.append({"at": now + LARMES["delay"], "kind": "larmes"})
			return now + LARMES["time"]
		"rosace":
			_cast(e, u, now)
			GameState.martyre_cast_at = now
			return now + SEALS["place"] + SEALS["charge"] + ROSACE["second"] + ROSACE["time"]
		"litanie":
			var side := 1.0 if sim.rng.randf() < 0.5 else -1.0
			var th0 := (u.pos() - center()).angle() + side * PI / 2.0
			var turns := [0.0, PI / 2.0, -PI / 2.0]
			for w in LITANIE["walls"]:
				GameState.martyre_events.append({"at": now + w * LITANIE["every"], "kind": "wall_warn",
					"th": th0 + turns[w % turns.size()]})
			_cast(e, u, now)
			return now + (LITANIE["walls"] - 1) * LITANIE["every"] + LITANIE["warn"] + LITANIE["time"]
	return now


static func _cast(e: Enemy, u: Unit, now: float) -> void:
	e.face = -1 if u.x < e.x else 1
	e.cast_started = now


static func _halo(e: Enemy, now: float) -> void:
	GameState.martyre_fx.append({"type": "halo", "x": e.x, "z": e.z, "at": now, "until": now + HALO})


static func _start_strike(e: Enemy, u: Unit, kind: String, now: float) -> void:
	e.face = -1 if u.x < e.x else 1
	e.attack_started = now
	e.cooldown = Catalog.ENEMY[KIND]["cd"]
	GameState.martyre_hit_at = now + IMPACT
	GameState.martyre_hit_kind = kind
	GameState.martyre_aim = u.pos()
	GameState.martyre_busy_until = now + STRIKE_TIME


## Impact du bâton : coup au contact, ou départ de la fissure vers la position visée.
static func _resolve_staff(sim: Simulation, e: Enemy, u: Unit, now: float) -> void:
	if now < GameState.martyre_hit_at:
		return
	GameState.martyre_hit_at = INF
	var at := e.pos() + Vector2(e.face * STAFF_REACH, 0.0)
	Combat.zone(at.x, at.y, 2.6, Color("#e2382e"))
	if GameState.martyre_hit_kind == "fissure":
		var to: Vector2 = GameState.martyre_aim
		var dir := (to - at)
		var length := minf(dir.length(), FISSURE["range"])
		if length < 1.0:
			dir = Vector2(e.face, 0.0)
			length = 1.0
		# Trois failles en éventail : la centrale sur la cible, les deux autres à ±spread.
		var n: int = FISSURE["count"]
		for i in n:
			var off: float = FISSURE["spread"] * (i - (n - 1) / 2.0)
			var end := at + dir.normalized().rotated(off) * length
			GameState.martyre_fx.append({"type": "fissure", "x0": at.x, "z0": at.y, "x1": end.x, "z1": end.y,
				"at": now, "erupt": now + length / FISSURE["speed"], "seed": (int(now * 1000.0) + i * 977) % 10000,
				"hit": false, "embers": 0})
		return
	if u != null and Combat.dist(e, u) <= e.reach + DODGE:
		if hurt_engineer(sim, u, DAMAGE, now):
			Combat.flash(u.x, u.z, Color("#e17b63"))


## Pose des trois sceaux, en cours d'incantation : sous l'Ingénieur et de part et d'autre, à l'est et à
## l'ouest, pour que les trois colonnes restent distinctes à l'écran.
static func _resolve_cast(e: Enemy, u: Unit, now: float) -> void:
	if GameState.martyre_cast_at == INF or now < GameState.martyre_cast_at + SEALS["place"]:
		return
	GameState.martyre_cast_at = INF
	if u == null:
		return
	var side := Vector2(SEALS["spread"], 0.0)
	for k in 3:
		var p := u.pos() + side * (k - 1)
		GameState.martyre_fx.append({"type": "seal", "x": p.x, "z": p.y, "at": now, "boom": now + SEALS["charge"],
			"index": k, "hit": false})


## Gestes programmés des motifs (tir des larmes, annonce et départ des murs, second anneau des rosaces).
static func _run_events(sim: Simulation, e: Enemy, u: Unit, now: float) -> void:
	if GameState.martyre_events.is_empty():
		return
	var due: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	for ev: Dictionary in GameState.martyre_events:
		if now >= ev["at"]:
			due.append(ev)
		else:
			keep.append(ev)
	GameState.martyre_events = keep
	var k: float = PHASE_SPEED[GameState.martyre_phase]
	for ev: Dictionary in due:
		match ev["kind"]:
			"larmes":
				if u == null:
					continue
				var a := (u.pos() - e.pos()).angle()
				for j in LARMES["count"]:
					var b := shoot(e.x, e.z, a + (j - (LARMES["count"] - 1) / 2.0) * LARMES["spread"], LARMES["speed"] * k,
						{"big": true, "acc": LARMES["acc"], "min": LARMES["min"], "r0": 1.5})
					b["fuse"] = now + LARMES["fuse"] + j * LARMES["stagger"]
			"wall_warn":
				if u == null:
					continue
				var th: float = ev["th"]
				var p := Vector2(-sin(th), cos(th))
				var r := radius()
				var g := clampf((u.pos() - center()).dot(p) + (sim.rng.randf() * 2.0 - 1.0) * LITANIE["jitter"],
					-r * LITANIE["reach"], r * LITANIE["reach"])
				var fire: float = now + LITANIE["warn"]
				GameState.martyre_fx.append({"type": "lane", "th": th, "g": g, "at": now, "fire": fire,
					"until": fire + 2.0 * r / (LITANIE["speed"] * k)})
				GameState.martyre_events.append({"at": fire, "kind": "wall", "th": th, "g": g})
				e.cast_started = now
			"wall":
				_wall(ev["th"], ev["g"], k, now)
			"ring":
				ring(ev["x"], ev["z"], ev["n"], ev["v"], ev["off"])


## Un mur d'éclats qui entre par le bord du bouclier (côté th) et traverse l'arène, brèche en g.
static func _wall(th: float, g: float, k: float, now: float) -> void:
	var n := Vector2(cos(th), sin(th))
	var p := Vector2(-n.y, n.x)
	var r := radius()
	var v: float = LITANIE["speed"] * k
	var s := -r
	while s <= r:
		if absf(s - g) >= LITANIE["gap"]:
			var at := center() + n * (r + 0.75) + p * s
			var b := shoot(at.x, at.y, th + PI, v)
			b["hide"] = true
			b["until"] = now + (2.0 * r + 2.0) / v
		s += LITANIE["step"]


## Nouvelle balle : position, direction, vitesse (u/s) ; o : big, acc (u/s²), min, r0 (départ décalé).
static func shoot(x: float, z: float, a: float, v: float, o: Dictionary = {}) -> Dictionary:
	var r0: float = o.get("r0", 0.0)
	var b := {"x": x + cos(a) * r0, "z": z + sin(a) * r0, "vx": cos(a) * v, "vz": sin(a) * v,
		"acc": o.get("acc", 0.0), "min": o.get("min", 0.0), "big": o.get("big", false), "fuse": INF,
		"hide": false, "until": GameState.sim_time + 14.0}
	GameState.martyre_bullets.append(b)
	return b


static func ring(x: float, z: float, n: int, v: float, off: float) -> void:
	for i in n:
		shoot(x, z, off + i * TAU / n, v)


## Coup porté à l'Ingénieur, sauf pendant son invulnérabilité ; renvoie s'il a porté.
static func hurt_engineer(sim: Simulation, u: Unit, amount: float, now: float) -> bool:
	if now < GameState.martyre_iframe_until:
		return false
	sim.combat.damage(u, amount * DAMAGE_MULT)
	GameState.martyre_iframe_until = now + IFRAMES
	return true


## Vol des balles : freinage, éclatement des larmes, entrée des murs par le bord, extinction au bouclier,
## touche sur l'Ingénieur en duel.
static func update_bullets(sim: Simulation, u: Unit, now: float, dt: float) -> void:
	if GameState.martyre_bullets.is_empty():
		return
	var c := center()
	var r := radius()
	var k: float = PHASE_SPEED[GameState.martyre_phase]
	var bursts: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	for b: Dictionary in GameState.martyre_bullets:
		if b["acc"] != 0.0:
			var s := Vector2(b["vx"], b["vz"]).length()
			var ns := maxf(b["min"], s + b["acc"] * dt)
			if s > 0.0:
				b["vx"] *= ns / s
				b["vz"] *= ns / s
		b["x"] += b["vx"] * dt
		b["z"] += b["vz"] * dt
		if now >= b["fuse"]:
			bursts.append(b)
			continue
		var dc := Vector2(b["x"] - c.x, b["z"] - c.y).length()
		if b["hide"]:
			if dc < r - 0.25:
				b["hide"] = false
			else:
				if now < b["until"]:
					keep.append(b)
				continue
		if dc > r + BULLET["edge"] or now >= b["until"]:
			continue
		if u != null:
			var big: bool = b["big"]
			var reach: float = BULLET["hit"] + (BULLET["big_r"] if big else BULLET["r"])
			var dx: float = u.x - b["x"]
			var dz: float = u.z - b["z"]
			if dx * dx + dz * dz < reach * reach and hurt_engineer(sim, u, BULLET["big_damage"] if big else BULLET["damage"], now):
				Combat.flash(u.x, u.z, Color("#fff2b0"))
				continue
		keep.append(b)
	GameState.martyre_bullets = keep
	for b: Dictionary in bursts:
		Combat.flash(b["x"], b["z"], Color("#f0cc66"))
		ring(b["x"], b["z"], LARMES["shards"], LARMES["shard_speed"] * k, sim.rng.randf() * TAU)


## Braises de la faille, éruptions, colonnes et rosaces : dégâts au moment où elles jaillissent, puis retrait
## une fois éteintes. Annonces et éclats éteints : retirés à leur fin.
static func update_fx(sim: Simulation, u: Unit, now: float) -> void:
	var k: float = PHASE_SPEED[GameState.martyre_phase]
	var keep: Array[Dictionary] = []
	for f: Dictionary in GameState.martyre_fx:
		match f["type"]:
			"fissure":
				var a := Vector2(f["x0"], f["z0"])
				var end := Vector2(f["x1"], f["z1"])
				var dir := end - a
				var length := dir.length()
				var ang := dir.angle()
				# Braises crachées de part et d'autre, tant que la faille court (hors du rayon de l'éruption).
				var run := minf(length - FISSURE["radius"], (now - float(f["at"])) * FISSURE["speed"])
				while (f["embers"] + 1) * EMBER["step"] <= run:
					f["embers"] += 1
					var p: Vector2 = a + dir.normalized() * (f["embers"] * EMBER["step"])
					for sd: float in [-1.0, 1.0]:
						var b := shoot(p.x, p.y, ang + sd * PI / 2.0 + (sim.rng.randf() - 0.5) * 0.4, EMBER["speed"] * k,
							{"acc": EMBER["acc"], "min": EMBER["min"]})
						b["until"] = now + EMBER["life"]
				if not f["hit"] and now >= f["erupt"]:
					f["hit"] = true
					Combat.flash(end.x, end.y, Color("#ffa846"))
					if u != null and u.pos().distance_to(end) <= FISSURE["radius"]:
						if hurt_engineer(sim, u, FISSURE["damage"], now):
							u.stunned_until = now + FISSURE["stun"]
					ring(end.x, end.y, EMBER["ring"], EMBER["ring_speed"] * k, sim.rng.randf() * TAU)
				if now < f["erupt"] + FISSURE["erupt"] + FISSURE["cool"]:
					keep.append(f)
			"seal":
				if not f["hit"] and now >= f["boom"]:
					f["hit"] = true
					if u != null and u.pos().distance_to(Vector2(f["x"], f["z"])) <= SEALS["radius"]:
						if hurt_engineer(sim, u, SEALS["damage"], now):
							Combat.flash(u.x, u.z, Color("#fff2b0"))
					# Rosace : deux anneaux décalés.
					var off: float = f["index"] * TAU / (2.0 * ROSACE["count"])
					ring(f["x"], f["z"], ROSACE["count"], ROSACE["speed"] * k, off)
					GameState.martyre_events.append({"at": now + ROSACE["second"], "kind": "ring", "x": f["x"], "z": f["z"],
						"n": ROSACE["count"], "v": ROSACE["speed2"] * k, "off": off + TAU / (2.0 * ROSACE["count"])})
				if now < f["boom"] + SEALS["boom"]:
					keep.append(f)
			_:
				if now < f["until"]:
					keep.append(f)
	GameState.martyre_fx = keep


## Réaction aux coups (animation martyre_hit), au plus toutes les HURT_EVERY secondes.
static func hurt(e: Enemy) -> void:
	if GameState.sim_time - e.hurt_at >= HURT_EVERY:
		e.hurt_at = GameState.sim_time


static func _walk(sim: Simulation, e: Enemy, goal: Vector2, dt: float) -> void:
	var next := sim.steer(e, goal)
	var step := (next - e.pos()).limit_length(e.speed * dt)
	var p := _clamp_inside(e.pos() + step, radius() - 1.0)
	if sim.state().walkable(p.x, p.y):
		e.x = p.x
		e.z = p.y


static func _clamp_inside(p: Vector2, r: float) -> Vector2:
	var off := p - center()
	return center() + off.limit_length(r)


## Le bouclier repousse au bord tout ce qui n'est ni la Martyre ni l'Ingénieur.
static func enforce(sim: Simulation) -> void:
	if not active():
		return
	for u: Unit in GameState.units:
		if u.role == "engineer" or not u.alive() or u.hidden or not inside(u):
			continue
		var p := _push_out(sim, u.pos())
		u.x = p.x
		u.z = p.y
		# Il ne s'obstine pas à entrer : il attend au bord.
		u.tx = p.x
		u.tz = p.y
		u.force_move = false
	for e: Enemy in GameState.enemies:
		if e == GameState.martyre or e.hp <= 0.0 or not inside(e):
			continue
		var p := _push_out(sim, e.pos())
		e.x = p.x
		e.z = p.y


static func _push_out(sim: Simulation, p: Vector2) -> Vector2:
	var off := p - center()
	if off.length() < 0.01:
		off = Vector2(0.0, -1.0)
	var q := center() + off.normalized() * (radius() + EDGE)
	return q if sim.state().walkable(q.x, q.y) else sim.state().push_out_of_rock(q)


## Objectif affiché tant que la Martyre vit (Quests.objective), sinon {}.
static func objective() -> Dictionary:
	if not active():
		return {}
	var e: Enemy = GameState.martyre
	return {"id": "martyre", "quest": "La Martyre de Byrsa", "interrupt": true,
		"label": "Éliminer la Martyre de Byrsa en combat singulier",
		"quote": "", "done_quote": "",
		"value": "%d PV" % ceili(e.hp), "progress": 1.0 - e.hp / e.max_hp}
