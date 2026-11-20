class_name Combat
extends RefCounted
## Combat, ennemis, vagues et balistes (Index.html, adepts.js, turret-game.js, galleries.js, 73b410f), appelés
## par Simulation.tick dans l'ordre de update() :
##   updateFireWalls → updateEvilPortals → apparitions → alliés (ciblage, charge, frappes, soins) →
##   updateTurrets → ennemis → morts → effets → fin de partie et vagues.
## Les effets (rivet, flèche, carreau, explosion, impacts, zones) sont des données dans GameState.effects ;
## WorldOverlay les dessine.

## VOLLEY : départs décalés des trois carreaux du Tireur.
const VOLLEY := [0.0, 0.13, 0.26]

var sim: Simulation
const EnemyTactics := preload("res://sim/enemy_tactics.gd")
const Ammo := preload("res://data/ammo.gd")
var tactics: RefCounted
## Journal d'événements (vagues, morts, niveaux) pour les parties scriptées ; vide si log_events est faux.
var log_events := false
var events: PackedStringArray = []


func _init(s: Simulation) -> void:
	sim = s
	tactics = preload("res://sim/enemy_tactics.gd").new(s)


func _rand() -> float:
	return sim.rng.randf()


func _log(text: String) -> void:
	if log_events:
		events.append("%.3f %s" % [GameState.sim_time, text])


## Math.hypot en double précision (les Vector2 de Godot sont en 32 bits).
static func hyp(dx: float, dz: float) -> float:
	return sqrt(dx * dx + dz * dz)


## Math.hypot en double précision : Vector2 est en 32 bits, ce qui renverse les égalités aux limites de
## portée (une brute à 3,0 unités exactement du Paladin, par exemple).
static func dist(a: Variant, b: Variant) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return sqrt(dx * dx + dz * dz)


## targetClosest : la cible vivante et visible la plus proche, strictement à moins de `range`.
static func target_closest(source: Variant, list: Array, range_ := 1e9, observer_world: World = null) -> Variant:
	var best: Variant = null
	var d := range_
	var sx: float = source.x
	var sz: float = source.z
	for t: Variant in list:
		# Écart sur un seul axe déjà hors de portée : la distance (≥ |dx| et ≥ |dz|) l'est aussi.
		var dx: float = t.x - sx
		if dx >= d or dx <= -d:
			continue
		var dz: float = t.z - sz
		if dz >= d or dz <= -d:
			continue
		if t.hp <= 0.0 or t.hidden or Martyre.blocks(source, t) or OeilMatrice.blocks(source, t):
			continue
		var nd := sqrt(dx * dx + dz * dz)
		if nd < d and (observer_world == null or observer_world.fog.visible_at(t.pos())):
			d = nd
			best = t
	return best


# ---------------------------------------------------------------- Dégâts et expérience

## damage : `src` gagne l'expérience du monstre qu'il achève.
func damage(t: Unit, amount: float, src: Unit = null) -> void:
	# Bouclier de la Martyre : seul l'Ingénieur, sous le bouclier, l'atteint.
	if t is Enemy and (t as Enemy).kind == Martyre.KIND:
		if not Martyre.can_hurt(src):
			return
		if amount > 0.0:
			Martyre.hurt(t as Enemy)
	# Salle de l'Œil de la Matrice : seul l'Ingénieur, dans la salle, l'atteint ; l'œil ouvert encaisse double.
	if t is Enemy and ((t as Enemy).kind == OeilMatrice.KIND or (t as Enemy).kind == OeilMatrice.PUPIL_KIND):
		if not OeilMatrice.can_hurt(src):
			return
		if amount > 0.0 and (t as Enemy).kind == OeilMatrice.KIND:
			amount *= OeilMatrice.damage_mult()
			OeilMatrice.hurt(t as Enemy)
	# Gorge-Cuivre : dégâts doublés dans la gueule ouverte.
	if t is Enemy and (t as Enemy).kind == Gorge.KIND and amount > 0.0:
		amount *= Gorge.damage_mult()
		(t as Enemy).hurt_at = GameState.sim_time
	# Voile de la Martyre (module d'exo) : le coup est absorbé en entier.
	if amount > 0.0 and not t.is_enemy() and Loot.veil_absorbs(t):
		flash(t.x, t.z, Color("#5fd8e8"))
		zone(t.x, t.z, 1.6, Color("#5fd8e8"))
		Sfx.at("bouclier_dore", t.x, t.z)
		return
	var was := t.hp
	if src and not src.is_enemy():
		amount *= src.power * Mages.damage_bonus(src)
		# Pointes de cuivre (recherche de la Caserne).
		if src.role == "archer" and GameState.research_done.has("copper_tips"):
			amount *= Catalog.COPPER_TIPS_DAMAGE
	if t is Enemy and amount > 0.0:
		var raw := amount
		amount = maxf(amount * 0.15, amount - Mages.armor_of(t as Enemy))
		# Frappe surtout absorbée par l'armure (bouclier doré) : « ting » qui signale l'inefficacité.
		if (t as Enemy).kind == "shield" and amount < raw * 0.5 and raw >= 4.0:
			Sfx.at("bouclier_dore", t.x, t.z)
	t.hp = maxf(0.0, t.hp - amount)
	# Gardien d'un Pylône de Merenor : il retient son agresseur pour riposter.
	if src and t is Enemy and ((t as Enemy).pylon != null or (t as Enemy).roam != null):
		t.memo["hurt_by"] = src
	if amount > 0.0 and was > 0.0:
		damage_number(t, amount)
		if not t.is_enemy() and amount >= 2.0:
			Sfx.at("exile_blesse", t.x, t.z)
	if src and t.is_enemy() and was > 0.0 and t.hp <= 0.0:
		_log("%s achève %s" % [src.name, (t as Enemy).kind])
		gain_xp(src, Catalog.KILL_XP.get((t as Enemy).kind, 10))


## Chiffre de dégâts blanc au-dessus de la cible. Les dégâts continus (lance-flammes, murs de feu) se
## cumulent dans le chiffre de la cible tant qu'il a moins de DAMAGE_MERGE secondes.
const DAMAGE_MERGE := 0.3


static func damage_number(t: Unit, amount: float) -> void:
	for i in range(GameState.damage_numbers.size() - 1, -1, -1):
		var e: Dictionary = GameState.damage_numbers[i]
		if e["target"] == t and e["age"] < DAMAGE_MERGE and e["age"] >= 0.0 and not e.get("heal", false):
			e["amount"] += amount
			return
	GameState.damage_numbers.append({"target": t, "x": t.x, "z": t.z, "amount": amount, "age": 0.0, "duration": 0.9})


## gainXP : paliers 20·1,6^(niveau−1) ; chaque niveau donne +1 dégât et +1 défense.
func gain_xp(u: Unit, n: int) -> void:
	if u == null or u.role.is_empty() or u.hp <= 0.0:
		return
	u.level = Catalog.lvl(u)
	u.xp += n
	while u.xp >= Catalog.xp_need(u.level):
		u.xp -= Catalog.xp_need(u.level)
		u.level += 1
		zone(u.x, u.z, 1.6, Color("#ffe08a"))
		flash(u.x, u.z, Color("#ffe08a"))
		Sfx.at("niveau", u.x, u.z)
		_log("%s niveau %d" % [u.name, u.level])
		sim.say("%s passe au niveau %d · +1 dégât, +1 défense." % [u.name, u.level], 2.0)


## afterArmor : dégâts subis après la défense, au moins 15 % des dégâts d'origine.
static func after_armor(u: Unit, dmg: float) -> float:
	return maxf(dmg * 0.15, dmg - Catalog.armor(u))


# ---------------------------------------------------------------- Effets (données)

## Effets sans hasard : statiques, appelables hors du combat (chantiers, portails, creusement, galeries).
static func _fx(e: Dictionary) -> void:
	GameState.effects.append(e)


static func flash(x: float, z: float, c: Color) -> void:
	_fx({"type": "hit", "x": x, "z": z, "age": 0.0, "duration": 0.22, "color": c})


## Foudre d'orage (core/weather.gd) : elle frappe un combattant au dehors, ennemi, bête ou allié, tiré
## au sort par la graine. Un allié à moins de BOLT_SHELTER d'un bâtiment ou d'une tourelle est à l'abri.
## Elle tombe aussi pour rien dans la jungle, d'autant plus souvent qu'il y a peu de monde dehors.
## Renvoie le point d'impact.
func lightning_strike(n: int, map_seed: int) -> Vector2:
	var pool: Array = []
	for e: Enemy in GameState.enemies:
		if e.hp > 0.0 and CaveShape.outdoors(e.x, e.z):
			pool.append(e)
	for u in GameState.units:
		if u.alive() and not u.hidden and CaveShape.outdoors(u.x, u.z) and not _sheltered(u.x, u.z):
			pool.append(u)
	var at := Vector2((Rng.hash3(n, 2, map_seed) - 0.5) * 160.0, lerpf(-60.0, 60.0, Rng.hash3(n, 3, map_seed)))
	# BOLT_MISSES tirages vides s'ajoutent aux combattants : seul dehors, on est rarement touché.
	var pick := int(Rng.hash3(n, 4, map_seed) * (pool.size() + Weather.BOLT_MISSES))
	if pick < pool.size():
		var t: Unit = pool[pick]
		at = t.pos()
		if t.is_enemy():
			damage(t, Weather.BOLT_DAMAGE)
		else:
			damage(t, after_armor(t, Weather.BOLT_DAMAGE))
	_fx({"type": "bolt", "x": at.x, "z": at.y, "seed": n, "age": 0.0, "duration": 0.4, "color": Weather.BOLT_COLOR})
	flash(at.x, at.y, Weather.BOLT_COLOR)
	zone(at.x, at.y, 2.0, Weather.BOLT_COLOR)
	Sfx.at("canon", at.x, at.y)
	if sim.world and sim.state().flora:
		sim.state().flora.burn(at.x, at.y, 2.0)
	return at


func _sheltered(x: float, z: float) -> bool:
	for b in GameState.buildings:
		if b.complete and hyp(b.x - x, b.z - z) < Weather.BOLT_SHELTER:
			return true
	for t in GameState.turrets:
		if t["complete"] and hyp(float(t["x"]) - x, float(t["z"]) - z) < Weather.BOLT_SHELTER:
			return true
	return false


static func blast(a: Variant, b: Variant, c: Color) -> void:
	_fx({"type": "laser", "x": a.x, "z": a.z, "tx": b.x, "tz": b.z, "age": 0.0, "duration": 0.13, "color": c})


static func zone(x: float, z: float, r: float, c: Color) -> void:
	_fx({"type": "zone", "x": x, "z": z, "r": r, "age": 0.0, "duration": 1.0, "color": c})


## Durée de vol d'un piton d'ancrage et de la suspension de la case (planche « Pitons d'ancrage »).
const PITON_FLIGHT := 0.12
const SUSPEND_TIME := 1.6


## piton : piton d'ancrage tiré par l'Ingénieur vers l'angle k (0 : sud-ouest, 1 : nord-ouest, 2 : nord-est,
## 3 : sud-est) de la case `key`.
static func piton(u: Unit, key: Vector2i, k: int) -> void:
	u.face = -1 if piton_corner(key, k).x < u.x else 1
	_fx({"type": "piton", "x": u.x, "z": u.z, "unit": u, "i": key.x, "j": key.y, "k": k, "face": u.face,
		"age": 0.0, "duration": PITON_FLIGHT})


## Angle k de la case `key`, en unités de monde, légèrement en retrait du bord.
static func piton_corner(key: Vector2i, k: int) -> Vector2:
	var x := key.x * 4.0
	var z := key.y * 4.0
	return [Vector2(x + 0.5, z + 3.5), Vector2(x + 0.5, z + 0.5), Vector2(x + 3.5, z + 0.5), Vector2(x + 3.5, z + 3.5)][k]


## suspend : les quatre pitons se relient, la roche (image de la case avant creusement) se fend en cubes
## suspendus, se comprime en un point lumineux, puis les pitons reviennent au poignet de l'Ingénieur.
static func suspend(u: Unit, key: Vector2i, img: Image) -> void:
	_fx({"type": "suspend", "unit": u, "i": key.x, "j": key.y, "x": key.x * 4.0 + 2.0, "z": key.y * 4.0 + 2.0,
		"img": img, "age": 0.0, "duration": SUSPEND_TIME})


func _seed() -> int:
	return int(_rand() * 1000.0)


## rivet : tir de l'Ingénieur (rivet de laiton, puis rivet fiché dans la cible).
func rivet(a: Unit, b: Unit) -> void:
	var face := -1 if b.x - a.x < 0.0 else 1
	var dur := maxf(0.08, dist(a, b) * 0.014)
	var seed := _seed()
	_fx({"type": "rivet", "x": a.x, "z": a.z, "tx": b.x, "tz": b.z, "face": face, "age": 0.0, "duration": dur, "seed": seed})
	_fx({"type": "rivethit", "x": b.x, "z": b.z, "face": face, "tgt": b, "age": -dur, "duration": 1.0, "seed": seed})


## Ennemis qui frappent à distance (refonte 16 bits) : archer (arc, portée moyenne), soldat (pilum, portée courte),
## Thuriféraire (sort, portée moyenne). Ils visent dans leur portée, pas seulement au contact.
const RANGED_KINDS := ["archer", "soldier", "spitter"]
## Au contact, le soldat frappe du pilum sans le lancer.
const MELEE_REACH := 1.6
## Alliés qui tirent des flèches (arrow) : leur tir exige une ligne dégagée (clear_shot).
const ARROW_ROLES := ["archer", "guard", "indra"]


## Ligne de tir dégagée entre a et b : aucun point de roche sur le segment (l'eau ne bloque pas).
func clear_shot(a: Vector2, b: Vector2) -> bool:
	var ts: Variant = sim.world.terrain_state if sim != null and sim.world != null else null
	if ts == null:
		return true
	var n := ceili(a.distance_to(b) / 0.5)
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n)
		if not ts.walkable(p.x, p.y) and not ts.water_at(p.x, p.y):
			return false
	return true
## Départ des projectiles en pixels natifs (devant, hauteur) depuis le pied, sur les sprites de la refonte.
const ENEMY_BOW := Vector2(7.0, 14.0)
const ENEMY_PILUM := Vector2(3.0, 21.0)
const ENEMY_STAFF := Vector2(2.0, 31.0)


## arrow : flèche de l'archer, puis étincelles à l'impact. `from` : départ (devant, hauteur) en pixels natifs.
func arrow(a: Unit, b: Variant, from := Vector2(12.0, 24.0)) -> void:
	var face := -1 if b.x - a.x < 0.0 else 1
	var dur := maxf(0.09, dist(a, b) * 0.02)
	_fx({"type": "arrow", "x": a.x, "z": a.z, "tx": b.x, "tz": b.z, "face": face, "ox": from.x, "oy": from.y, "age": 0.0, "duration": dur, "seed": _seed()})
	_fx({"type": "arrowhit", "x": b.x, "z": b.z, "age": -dur, "duration": 0.24, "seed": _seed()})
	Sfx.at("arc", a.x, a.z)
	Sfx.at("fleche_impact", b.x, b.z, dur)


## pilum : javelot du soldat du Credo, lancé en cloche à courte portée, puis éclats à l'impact.
func pilum(a: Unit, b: Variant) -> void:
	var face := -1 if b.x - a.x < 0.0 else 1
	var dur := maxf(0.14, dist(a, b) * 0.05)
	_fx({"type": "pilum", "x": a.x, "z": a.z, "tx": b.x, "tz": b.z, "face": face, "ox": ENEMY_PILUM.x, "oy": ENEMY_PILUM.y, "age": 0.0, "duration": dur, "seed": _seed()})
	Sfx.at("pilum", a.x, a.z)
	_fx({"type": "arrowhit", "x": b.x, "z": b.z, "age": -dur, "duration": 0.24, "seed": _seed()})


## spell : orbe de lumière souillée du Thuriféraire, tirée du haut de son bâton, puis éclatement sur la cible.
func spell(a: Unit, b: Variant) -> void:
	var face := -1 if b.x - a.x < 0.0 else 1
	var dur := maxf(0.18, dist(a, b) * 0.035)
	_fx({"type": "orb", "x": a.x, "z": a.z, "tx": b.x, "tz": b.z, "face": face, "ox": ENEMY_STAFF.x, "oy": ENEMY_STAFF.y, "age": 0.0, "duration": dur, "seed": _seed()})
	Sfx.at("sort_lumiere", a.x, a.z)
	_fx({"type": "orbhit", "x": b.x, "z": b.z, "age": -dur, "duration": 0.32, "seed": _seed()})


## volley : trois carreaux du Tireur, chacun suivi d'une explosion sur la cible.
func volley(a: Unit, b: Unit) -> void:
	a.sh_t0 = GameState.sim_time
	a.face = -1 if (b.x - b.z) - (a.x - a.z) < 0.0 else 1
	var dur := maxf(0.07, dist(a, b) * 0.013)
	Sfx.at("tourelle", a.x, a.z)
	for v: float in VOLLEY:
		var jx := (_rand() - 0.5) * 0.8
		var jz := (_rand() - 0.5) * 0.8
		_fx({"type": "xbolt", "x": a.x, "z": a.z, "tx": b.x + jx, "tz": b.z + jz, "face": a.face, "age": -v, "duration": dur, "seed": _seed()})
		_fx({"type": "xboom", "x": b.x + jx, "z": b.z + jz, "age": -v - dur, "duration": 0.45, "seed": _seed()})


## swordStrike : coup d'épée (animation du Paladin, orientation).
func sword_strike(u: Unit, e: Variant) -> void:
	u.sw_t0 = GameState.sim_time
	u.sw = (u.sw + 1) % 5
	u.face = -1 if e.x - u.x < 0.0 else 1
	if not is_same(e, u):  # le moulinet (e == u) a son propre son
		Sfx.at("epee", u.x, u.z)


# ---------------------------------------------------------------- Frappes (adepts.js)

## barracksStrike : attaque d'une unité de la table FIGHT.
func barracks_strike(u: Unit, e: Enemy) -> void:
	var F: Dictionary = Catalog.FIGHT[u.role]
	var k := 1.5 if u.buff > 0.0 else 1.0
	var dmg: float = (Catalog.attack_damage(u) + Catalog.lvl_bonus(u)) * k * Catalog.damage_mult(u)
	u.attack = F["cd"]
	u.face = -1 if e.x - u.x < 0.0 else 1
	# D15 : le lance-flammes n'a plus de sillon de feu ; en jeu, il tire en continu (flame_tick).
	if u.role == "flammes":
		for o: Enemy in GameState.enemies.duplicate():
			if o.hp > 0.0 and dist(o, e) < F["splash"]:
				damage(o, dmg, u)
		blast(u, e, Color("#ff9a30"))
		flash(e.x, e.z, Color("#ffb050"))
		Sfx.at("flammes", u.x, u.z)
		return
	if u.role == "lame" and moulinet(u, dmg):
		return
	# Ingénieur armé au Creuset : même attaque que le clic droit, vers sa cible (taille en arc ou balle de canon).
	if not Catalog.gear_weapon(u).is_empty():
		gear_attack(u, Vector2(e.x, e.z))
		return
	# Arme à munitions du Creuset (canon) : une munition prise au stock par tir.
	var w := Catalog.gear_weapon(u)
	if w.has("ammo"):
		Catalog.ItemStorage.take_ammo(w["ammo"])
	# Chaque tir d'archer prend une flèche à la réserve globale ; sans flèche, il ne tire pas.
	if u.role == "archer" and not Catalog.ItemStorage.take_ammo("arrows"):
		return
	damage(e, dmg, u)
	if u.role == "archer":
		arrow(u, e)
	elif F.get("ranged", false) or w.has("reach"):
		blast(u, e, Color("#bed7df"))
		flash(e.x, e.z, Color("#bed7df"))
		Sfx.at("tourelle", u.x, u.z)
	else:
		flash(e.x, e.z, Color("#f0dba4"))
		sword_strike(u, e)


## Attaque visée de l'Ingénieur armé (clic droit) : voir gear_attack. Vrai si l'Ingénieur porte une arme utilisable
## (le clic est alors consommé, même en recharge).
func aimed_attack(u: Unit, point: Vector2) -> bool:
	if Catalog.gear_weapon(u).is_empty():
		return false
	if u.attack <= 0.0:
		gear_attack(u, point)
	return true


## Vitesse des balles du canon (unités de monde par seconde) et distance maximale d'une balle sans obstacle.
const BALL_SPEED := 40.0
const BALL_RANGE := 80.0
## Images d'attaque du Tyrien (planches/armes-attaques.html) : début de la frappe dans l'animation, en secondes.
const SLASH_DELAY := {"slash1": 0.2, "slash2": 0.28}


## Attaque de l'Ingénieur armé au Creuset vers `point` (planche planches/armes-attaques.html).
## Épée : taille en arc devant lui (de sa droite vers sa gauche, ou de l'épaule gauche à la taille côté droit à
## deux mains) ; tout ennemi visible à moins de `melee` (1,5 bloc) dans le demi-cercle avant subit les dégâts.
## Canon : une balle (une munition) file en ligne droite jusqu'au premier obstacle solide ; si c'est un ennemi,
## il subit les dégâts.
func gear_attack(u: Unit, point: Vector2) -> void:
	var w := Catalog.gear_weapon(u)
	var d := point - Vector2(u.x, u.z)
	if d.length() < 0.01:
		d = Vector2(float(u.face), 0.0)
	d = d.normalized()
	# Arbalestrie : chaque tir consomme la mana de la munition choisie (data/ammo.gd ; balles spirituelles :
	# `mana` de chaque type) ; sans assez de mana, pas de tir.
	var ammo := "spirit"
	if w.has("mana"):
		ammo = Ammo.current()
		if not Ammo.can_pay(ammo, float(w["mana"])):
			return
		Ammo.pay(ammo, float(w["mana"]))
	u.face = -1 if d.x < 0.0 else 1
	u.aim_dir = d
	u.attack = float(w.get("cd", Catalog.FIGHT["engineer"]["cd"]))
	if w.has("mana"):
		u.attack *= float(Ammo.AMMO[ammo].get("cd_mult", 1.0))
	var dmg: float = (Catalog.attack_damage(u) + Catalog.lvl_bonus(u)) * (1.5 if u.buff > 0.0 else 1.0)
	if w.has("melee"):
		var reach := float(w["melee"])
		for e: Enemy in GameState.enemies.duplicate():
			if not _can_hit(e):
				continue
			var rel := Vector2(e.x - u.x, e.z - u.z)
			# L'allonge compte jusqu'au bord de la silhouette (Enemy.BODY : corps larges, boss, alphas).
			var body := e.melee_body()
			if rel.length() <= reach + Enemy.MELEE_BASE + body and (rel.length() < 0.3 + body or rel.normalized().dot(d) >= 0.0):
				damage(e, dmg, u)
				flash(e.x, e.z, Color("#f0dba4"))
		sword_strike(u, {"x": u.x + d.x, "z": u.z + d.y})
		var anim := String(w.get("anim", "slash1"))
		_fx({"type": "slash", "x": u.x, "z": u.z, "dx": d.x, "dz": d.y, "r": reach, "two": anim == "slash2",
			"age": -float(SLASH_DELAY.get(anim, 0.2)), "duration": 0.26})
		return
	if w.has("ammo"):
		Catalog.ItemStorage.take_ammo(w["ammo"])
	u.sh_t0 = GameState.sim_time
	# Arbalestrie : son de tir dédié ; « canon » reste aux canons de Byrsa.
	Sfx.at("arbalestrie" if w.has("mana") else "canon", u.x, u.z)
	var A: Dictionary = Ammo.AMMO[ammo]
	var count := int(A.get("count", 1))
	for i in count:
		var dir := d
		if count > 1:
			dir = d.rotated(deg_to_rad(float(A.get("spread", 0.0)) * (2.0 * i / (count - 1) - 1.0)))
		_ball(u, dir, dmg * float(A["mult"]), ammo)


## Une balle de l'Arbalestrie (ou du canon) de `u` dans la direction `d`, avec les effets de la munition.
func _ball(u: Unit, d: Vector2, dmg: float, ammo: String) -> void:
	var A: Dictionary = Ammo.AMMO[ammo]
	var hit := ball_target(u, d)
	var end: Vector2 = hit["end"]
	var dur := maxf(0.04, end.distance_to(Vector2(u.x, u.z)) / BALL_SPEED)
	_fx({"type": "cball", "x": u.x, "z": u.z, "tx": end.x, "tz": end.y, "age": 0.0, "duration": dur, "seed": _seed(), "ammo": ammo})
	Sfx.at("fleche_impact", end.x, end.y, dur)
	_fx({"type": "cballhit", "x": end.x, "z": end.y, "age": -dur, "duration": 0.45 if ammo == "indra" else 0.3, "seed": _seed(), "ammo": ammo})
	var target: Enemy = hit["enemy"]
	if target == null:
		return
	var before := target.hp
	damage(target, dmg, u)
	var dealt := before - target.hp
	# Aether : onde d'un bloc autour de la cible, un quart des dégâts à chaque autre ennemi visible dedans.
	if A.has("splash"):
		var r := float(A["splash"])
		_fx({"type": "aether_wave", "x": target.x, "z": target.z, "r": r, "age": -dur, "duration": 0.55})
		for e: Enemy in GameState.enemies.duplicate():
			if e == target or not _can_hit(e) or Vector2(e.x - target.x, e.z - target.z).length() > r:
				continue
			damage(e, dmg * float(A["splash_mult"]), u)
			# Étincelle d'Aether sur le voisin quand l'onde (0,3 s pour un bloc) l'atteint.
			var reach := dur + Vector2(e.x - target.x, e.z - target.z).length() / r * 0.3
			_fx({"type": "cballhit", "x": e.x, "z": e.z, "age": -reach, "duration": 0.25, "seed": _seed(), "ammo": "aether_spark"})
	# Medeina : l'Ingénieur regagne les dégâts réellement faits (armure déduite), sans dépasser ses PV max.
	if A.get("heal", false) and dealt > 0.0 and u.alive():
		var healed := minf(dealt, u.max_hp - u.hp)
		u.hp += healed
		_fx({"type": "heal_motes", "x": end.x, "z": end.y, "unit": u, "age": -dur - 0.08, "duration": 0.6, "seed": _seed()})
		if healed > 0.0:
			GameState.damage_numbers.append({"target": u, "x": u.x, "z": u.z, "amount": healed, "age": -dur - 0.55, "duration": 0.9, "heal": true})


func _can_hit(e: Enemy) -> bool:
	return e.hp > 0.0 and not e.hidden and (sim == null or sim.world == null or sim.world.fog.visible_at(e.pos()))


## Trajectoire d'une balle de canon tirée par `u` dans la direction `d` : premier ennemi touché (ou null) et point
## d'arrêt (ennemi, roche ou bord du terrain praticable ; BALL_RANGE au plus).
func ball_target(u: Unit, d: Vector2) -> Dictionary:
	var from := Vector2(u.x, u.z)
	var best := BALL_RANGE
	var target: Enemy = null
	for e: Enemy in GameState.enemies:
		if not _can_hit(e):
			continue
		# La balle touche l'ennemi si elle passe sur sa silhouette dessinée (Enemy.body_rect).
		var th := e.ray_hit(from, d)
		if th < best:
			best = th
			target = e
	var ts: Variant = sim.world.terrain_state if sim != null and sim.world != null else null
	if ts != null:
		var s := 1.0
		while s < best:
			var p := from + d * s
			if not ts.walkable(p.x, p.y) and not ts.water_at(p.x, p.y):
				return {"enemy": null, "end": from + d * maxf(0.0, s - 0.5)}
			s += 0.5
	return {"enemy": target, "end": from + d * best}


## Cible d'un archer : l'ennemi le plus proche qu'il voit lui-même, à moins de `range_` ; un ennemi derrière
## un obstacle (pas de ligne dégagée) n'est pas repéré. Les lignes ne sont testées que du plus proche au plus
## lointain, jusqu'à la première dégagée.
func archer_target(u: Unit, range_: float) -> Variant:
	var near: Array = []
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0 or e.hidden or Martyre.blocks(u, e) or OeilMatrice.blocks(u, e):
			continue
		var d := dist(e, u)
		if d < range_ and (sim.world == null or sim.world.fog.visible_at(e.pos())):
			near.append([d, e])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in near:
		if clear_shot(u.pos(), (entry[1] as Enemy).pos()):
			return entry[1]
	return null


## archerTick : Charge du Lac. Renvoie vrai si l'archer a agi (charge, mêlée, approche).
func archer_tick(u: Unit, e: Variant, dt: float) -> bool:
	var C := Catalog.CHARGE
	var t := GameState.sim_time
	if u.dash != null:
		var target: Enemy = u.dash["e"]
		if target.hp <= 0.0 or (sim.world and not sim.world.fog.visible_at(target.pos())):
			u.dash = null
			return false
		var dx := target.x - u.x
		var dz := target.z - u.z
		var l := Combat.hyp(dx, dz)
		if l == 0.0:
			l = 1.0
		u.face = -1 if dx < 0.0 else 1
		flash(u.x, u.z, Color("#64a2f4"))
		if l > 1.4 and t - u.dash["t0"] < C["max_t"]:
			var s := minf(l - 1.3, C["speed"] * dt)
			u.x += dx / l * s
			u.z += dz / l * s
			return true
		damage(target, (C["dmg"] + Catalog.lvl_bonus(u)) * (1.5 if u.buff > 0.0 else 1.0), u)
		target.stun = C["stun"]
		flash(target.x, target.z, Color("#bcdcff"))
		zone(target.x, target.z, 1.4, Color("#64a2f4"))
		sword_strike(u, target)
		u.attack = Catalog.FIGHT["archer"]["melee"]["cd"]
		u.dash = null
		return true
	if e == null or dist(u, e) > C["reset"]:
		u.charged = false
		return false
	if u.stance == "hold" or u.force_move:
		return false
	var d := dist(u, e)
	if d >= C["trigger"]:
		return false
	if not u.charged:
		u.charged = true
		u.dash = {"e": e, "t0": t}
		Sfx.at("charge", u.x, u.z)
		return true
	var M: Dictionary = Catalog.FIGHT["archer"]["melee"]
	if d > M["reach"]:
		sim.move(u, sim.steer(u, Vector2(e.x, e.z)), dt, 0.65)
		return true
	if u.attack <= 0.0:
		u.attack = M["cd"]
		u.face = -1 if e.x - u.x < 0.0 else 1
		damage(e, (M["dmg"] + Catalog.lvl_bonus(u)) * (1.5 if u.buff > 0.0 else 1.0), u)
		flash(e.x, e.z, Color("#f0dba4"))
		sword_strike(u, e)
	return true


## moulinet : à 3 charges, la frappe suivante touche tous les ennemis dans 2,8. Vrai s'il a remplacé la frappe.
func moulinet(u: Unit, dmg: float) -> bool:
	var M := Catalog.MOULINET
	if u.orage < M["charges"]:
		u.orage += 1
		return false
	u.orage = 0
	var k: float = dmg / (Catalog.FIGHT["lame"]["dmg"] + Catalog.lvl_bonus(u))
	var hit: float = (M["dmg"] + Catalog.lvl_bonus(u)) * k
	for o: Enemy in GameState.enemies.duplicate():
		if o.hp > 0.0 and dist(o, u) < M["r"]:
			damage(o, hit, u)
			flash(o.x, o.z, Color("#bcdcff"))
	zone(u.x, u.z, M["r"], Color("#64a2f4"))
	sword_strike(u, u)
	Sfx.at("moulinet", u.x, u.z)
	return true


static func on_wall(w: Dictionary, o: Variant) -> bool:
	var px: float = o.x - w["x"]
	var pz: float = o.z - w["z"]
	var t := clampf(px * w["dx"] + pz * w["dz"], 0.0, w["len"])
	return Combat.hyp(px - w["dx"] * t, pz - w["dz"] * t) < Catalog.SILLON["w"]


## sillon : ligne de feu vers la cible (dégâts au passage), puis mur de 2 s qui brûle et ralentit.
func sillon(u: Unit, e: Enemy) -> void:
	var S := Catalog.SILLON
	var now := GameState.sim_time
	u.sillon_at = now + S["cd"]
	var dx := e.x - u.x
	var dz := e.z - u.z
	var l := Combat.hyp(dx, dz)
	if l == 0.0:
		l = 1.0
	var w := {"x": u.x + dx / l * 0.6, "z": u.z + dz / l * 0.6, "dx": dx / l, "dz": dz / l, "len": S["len"], "t0": now, "until": now + S["wall"] + 0.4}
	GameState.fire_walls.append(w)
	Sfx.at("sillon", u.x, u.z)
	for o: Enemy in GameState.enemies.duplicate():
		if o.hp > 0.0 and on_wall(w, o):
			damage(o, S["dmg"] + Catalog.lvl_bonus(u), u)


func update_fire_walls(dt: float) -> void:
	var now := GameState.sim_time
	GameState.fire_walls = GameState.fire_walls.filter(func(w: Dictionary) -> bool: return w["until"] > now)
	for w in GameState.fire_walls:
		if now - w["t0"] < 0.4:
			continue
		for o: Enemy in GameState.enemies:
			if o.hp > 0.0 and on_wall(w, o):
				damage(o, Catalog.SILLON["burn"] * dt)
				o.slow_until = now + 0.15


## Tir continu du lance-flammes (D15) : dmg / cd par seconde aux ennemis dans `splash` autour de la cible,
## jet de flammes redessiné toutes les 0,06 s.
func flame_tick(u: Unit, e: Enemy, dt: float) -> void:
	var F: Dictionary = Catalog.FIGHT["flammes"]
	var k := 1.5 if u.buff > 0.0 else 1.0
	var dmg: float = (Catalog.attack_damage(u) + Catalog.lvl_bonus(u)) * k * Catalog.damage_mult(u) / F["cd"] * dt
	u.attack = 0.1
	u.face = -1 if e.x - u.x < 0.0 else 1
	Sfx.at("flammes", u.x, u.z)  # boucle : réémis tant qu'il tire (MIN_GAP ≈ durée du son)
	for o: Enemy in GameState.enemies.duplicate():
		if o.hp > 0.0 and dist(o, e) < F["splash"]:
			damage(o, dmg, u)
	# Les flammes brûlent la végétation basse autour de la cible, sauf sous la pluie.
	if sim.state().flora and not Weather.wet(e.x, e.z):
		sim.state().flora.burn(e.x, e.z, F["splash"])
	var now := GameState.sim_time
	if now >= u.flame_fx:
		u.flame_fx = now + 0.06
		# « nozzle » = sens du tireur : le rendu fait partir le jet de la buse du sprite (soldat 4.1).
		_fx({"type": "laser", "x": u.x, "z": u.z, "tx": e.x, "tz": e.z, "age": 0.0, "duration": 0.13,
			"color": Color("#ff9a30"), "nozzle": u.face if u.face != 0 else 1})
		flash(e.x, e.z, Color("#ffb050"))


## Explosion du lance-flammes à sa mort (D15) : dégâts fixes aux ennemis proches.
func flame_explosion(u: Unit) -> void:
	var X := Catalog.FLAME_DEATH
	for o: Enemy in GameState.enemies.duplicate():
		if o.hp > 0.0 and dist(o, u) < X["r"]:
			damage(o, X["dmg"], u)
			flash(o.x, o.z, Color("#ffb050"))
	zone(u.x, u.z, X["r"], Color("#ff7a20"))
	flash(u.x, u.z, Color("#fff0d0"))
	Sfx.at("flammes_mort", u.x, u.z)
	_log("%s explose" % u.name)


## fightBusy : l'unité est en train de frapper (animation de travail des adeptes).
static func fight_busy(u: Unit) -> bool:
	var F: Dictionary = Catalog.FIGHT.get(u.role, {})
	if F.is_empty():
		return u.attack > 0.25
	return u.attack > (-0.05 if u.role == "flammes" else F["cd"] * 0.45)


# ---------------------------------------------------------------- Alliés (update, Index.html)

## Distance maximale (en blocs) au-delà de la portée à laquelle une unité se déplace pour engager.
const ENGAGE_MARGIN := 2.0


func update_units(dt: float, alive: Array[Unit]) -> void:
	Mages.refresh(alive)
	if sim.world and not GameState.enemies.is_empty():
		sim.world.fog.refresh(sim.state())
	for u in alive:
		# Étourdi (fissure de la Martyre) : ni déplacement ni attaque.
		if u.stunned_until > GameState.sim_time:
			continue
		if u.force_move and Combat.hyp(u.x - u.tx, u.z - u.tz) < 0.6:
			u.force_move = false
		# Mages cristallisés : ni tir ni mêlée, leur conduite est dans sim/mages.gd.
		if Catalog.is_mage(u.role):
			if not u.hidden:
				Mages.act(sim, u, dt, alive)
			continue
		var enemy: Variant = null
		var busy := u.hidden or (u.role == "engineer" and (u.job != null or u.build_job != null or u.orb_job)) \
			or (Catalog.is_adept(u) and u.job != null)
		# L'Ingénieur ne tire plus automatiquement : il n'attaque que sur ordre (clic droit, gear_attack).
		if not u.force_move and not busy and u.role != "engineer":
			# Une unité ne va au-devant d'un ennemi que s'il est visible et à au plus ENGAGE_MARGIN blocs hors de sa portée.
			var seek: float = Catalog.unit_reach(u) + ENGAGE_MARGIN
			enemy = archer_target(u, seek) if u.role == "archer" else target_closest(u, GameState.enemies, seek, sim.world)
		if u.role == "archer" and archer_tick(u, enemy, dt):
			continue
		# Posture « hold » (poste de tir, tenir la position) : l'unité rejoint sa place puis tire sans poursuivre.
		var holding := u.stance == "hold"
		if enemy != null:
			var fight: bool = Catalog.FIGHT.has(u.role)
			var reach: float = Catalog.unit_reach(u)
			# Corps larges (Martyre, Œil, croco, Strazhar, alphas…) : on les frappe dès le bord de leur silhouette.
			if enemy is Enemy:
				reach += (enemy as Enemy).melee_body()
			# Les flèches ne traversent pas les murs : sans ligne de tir dégagée, l'archer s'approche au lieu de tirer.
			if ARROW_ROLES.has(u.role) and dist(u, enemy) > MELEE_REACH and not clear_shot(u.pos(), enemy.pos()):
				reach = MELEE_REACH
			if dist(u, enemy) > reach and not holding:
				sim.move(u, sim.steer(u, Vector2(enemy.x, enemy.z)), dt, 0.65)
			if u.role == "flammes":
				if dist(u, enemy) < reach:
					flame_tick(u, enemy, dt)
			elif dist(u, enemy) < reach and u.attack <= 0.0 and fight:
				barracks_strike(u, enemy)
			elif dist(u, enemy) < reach and u.attack <= 0.0:
				var base: int = {"paladin": 30, "shooter": 19, "healer": 9}.get(u.role, 12)
				var dmg := float(base + Catalog.lvl_bonus(u))
				if u.buff > 0.0:
					dmg *= 1.5
				damage(enemy, dmg, u)
				if u.role != "paladin":
					if u.role == "guard" or u.role == "indra":
						arrow(u, enemy)
					elif u.role == "shooter":
						volley(u, enemy)
					elif u.role == "engineer":
						rivet(u, enemy)
					else:
						blast(u, enemy, Color("#f4d780") if u.role == "shooter" else Color("#bed7df"))
						Sfx.at("tourelle", u.x, u.z)
				else:
					flash(enemy.x, enemy.z, Color("#f0dba4"))
					sword_strike(u, enemy)
				u.attack = {"paladin": 0.88, "shooter": 0.78, "indra": 0.55}.get(u.role, 1.15)
		elif not holding or u.force_move:
			sim.move(u, sim.steer(u, Vector2(u.tx, u.tz)), dt)
		if u.role == "healer" and u.attack <= 0.0:
			var hurt := alive.filter(func(t: Unit) -> bool: return t.hp < t.max_hp * 0.75 and dist(t, u) < 8.0)
			hurt.sort_custom(func(a: Unit, b: Unit) -> bool: return a.hp / a.max_hp < b.hp / b.max_hp)
			if not hurt.is_empty():
				var target: Unit = hurt[0]
				target.hp = minf(target.max_hp, target.hp + 10.0)
				target.healed_at = GameState.sim_time
				u.attack = 1.0
				zone(target.x, target.z, 0.9, Color("#80ddb8"))
				Sfx.at("soin", target.x, target.z)


# ---------------------------------------------------------------- Ennemis

func update_enemies(dt: float, alive: Array[Unit]) -> void:
	tactics.update(dt, alive)
	var core := {"x": CaveShape.CORE.x, "z": CaveShape.CORE.y}
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0 or e.neutral:
			continue
		if e.kind == Martyre.KIND:
			Martyre.act(sim, e, dt)
			continue
		if e.kind == OeilMatrice.KIND:
			OeilMatrice.act(sim, e, dt)
			continue
		if e.kind == Gorge.KIND:
			Gorge.act(sim, e, dt, alive)
			continue
		# Pupilles errantes : menées par l'Œil (OeilMatrice.update_fx).
		if e.kind == OeilMatrice.PUPIL_KIND:
			continue
		if e.pylon != null:
			Pylons.act(sim, e, dt, alive)
			continue
		if e.stun > 0.0:
			e.stun -= dt
			continue
		e.cooldown -= dt
		# Coup annoncé en cours d'armement : l'ennemi reste campé, puis le coup tombe si la cible est encore à portée.
		if e.strike_at < INF:
			if GameState.sim_time >= e.strike_at:
				_land_strike(e, core)
			continue
		var espd := e.speed * (Catalog.SILLON["slow"] if e.slow_until > GameState.sim_time else 1.0) * Weather.speed_at(e.x, e.z)
		var coordinated := not e.tactical_group.is_empty()
		var target: Variant = tactics.target(e, alive) if coordinated else target_closest(e, alive, maxf(e.reach * Weather.reach_at(e.x, e.z), 4.5) if RANGED_KINDS.has(e.kind) else 4.5)
		# Errant des galeries : il ne vise que ce qui entre sur son territoire, jamais l'Ancre.
		var roaming := e.roam != null
		if roaming:
			target = Roamers.target(e, alive)
		# Attaqué par une bête de la jungle : il riposte.
		var wild := Wildlife.attacker_of(e)
		if wild and (target == null or dist(wild, e) < dist(target, e)):
			target = wild
		# Rien ne frappe à travers le bouclier de la Martyre.
		if target != null and (Martyre.blocks(e, target) or OeilMatrice.blocks(e, target)):
			target = null
		var is_core := target == null
		if is_core and roaming:
			Roamers.wander(sim, e, espd, dt)
			continue
		# Barricade sur son passage : sans autre cible, un ennemi de mêlée qui la touche s'arrête pour la frapper.
		if is_core and not GameState.placed.is_empty() and not RANGED_KINDS.has(e.kind):
			var bar: Dictionary = Simulation.Placeables.barricade_touched(e)
			if not bar.is_empty():
				if e.cooldown <= 0.0:
					e.attack_started = GameState.sim_time
					e.face = -1 if float(bar["x"]) < e.x else 1
					e.cooldown = Catalog.ENEMY[e.kind]["cd"]
					Simulation.Placeables.hit(sim, bar, e.damage)
				continue
		var tx: float = core["x"] if is_core else target.x
		var tz: float = core["z"] if is_core else target.z
		var d := Combat.hyp(e.x - tx, e.z - tz)
		var ordered: bool = coordinated and e.tactical_goal != null
		# Chien de la Bête : il crache une petite boule de feu en pleine course, sans s'arrêter.
		if e.kind == "beast" and not is_core:
			EnemyShots.spit(sim, e, target, d)
		# Au contact, la mêlée se défend même pendant le rassemblement ou la réserve.
		# Les flèches ne traversent pas les murs : sans ligne de tir dégagée, l'archer s'approche au lieu de tirer.
		# Brume : les tireurs portent moins loin dehors.
		var reach := e.reach * Weather.reach_at(e.x, e.z) if RANGED_KINDS.has(e.kind) else e.reach
		if e.kind == "archer" and d > MELEE_REACH and not clear_shot(e.pos(), Vector2(tx, tz)):
			reach = minf(reach, MELEE_REACH)
		var in_contact: bool = not is_core and d <= reach
		var retreating: bool = e.tactical_retreating
		if ordered and (not in_contact or retreating):
			_move_enemy(e, e.tactical_goal, minf(espd, e.tactical_speed), dt)
		elif d > reach:
			if coordinated:
				_move_enemy(e, Vector2(tx, tz), espd, dt)
			else:
				var next := sim.steer(e, Vector2(tx, tz))
				var dx := next.x - e.x
				var dz := next.y - e.z
				var length := Combat.hyp(dx, dz)
				if length == 0.0:
					length = 1.0
				e.x += dx / length * espd * dt
				e.z += dz / length * espd * dt
				sim.clamp_world(e)
		if d <= reach and e.cooldown <= 0.0 and not retreating:
			e.attack_started = GameState.sim_time
			e.face = -1 if tx < e.x else 1
			e.cooldown = Catalog.ENEMY[e.kind]["cd"]
			e.windup = float(Catalog.ENEMY_WINDUP.get(e.kind, 0.0))
			# Tir à distance sur l'Exilé incarné : annoncé, puis de vraies balles à esquiver (EnemyShots).
			var shot := EnemyShots.windup(e, target, d)
			if shot > 0.0:
				e.windup = shot
				e.shot_aim = Vector2(tx, tz)
			if e.windup > 0.0:
				e.strike_at = GameState.sim_time + e.windup / maxf(e.pace, 0.01)
				e.strike_target = null if is_core else target
				continue
			_enemy_hit(e, null if is_core else target, core)
			if e.kind == "archer":
				arrow(e, core if is_core else target, ENEMY_BOW)
			elif e.kind == "soldier" and d > MELEE_REACH:
				pilum(e, core if is_core else target)
			elif e.kind == "spitter":
				spell(e, core if is_core else target)
			else:
				Sfx.at(ENEMY_MELEE_SFX.get(e.kind, "fanatique"), e.x, e.z)
			e.cooldown = Catalog.ENEMY[e.kind]["cd"]


## Dégâts d'un coup d'ennemi sur sa cible (null = l'Ancre) : bouclier, garde et armure de la cible, éclair d'impact.
func _enemy_hit(e: Enemy, target: Unit, core: Dictionary) -> void:
	var dmg := e.damage
	if target != null:
		hit_unit(target, dmg)
	else:
		GameState.core_hp = maxf(0.0, GameState.core_hp - dmg)
		flash(core["x"], core["z"], Color("#e17b63"))


## Coup d'ennemi de dmg sur une unité : bouclier, garde et armure de la cible, éclair d'impact.
func hit_unit(target: Unit, dmg: float) -> void:
	if target.shield > 0.0:
		dmg *= 0.35
	if Catalog.FIGHT.has(target.role) and Catalog.FIGHT[target.role].has("guard"):
		dmg *= Catalog.FIGHT[target.role]["guard"]
	damage(target, after_armor(target, dmg))
	flash(target.x, target.z, Color("#e17b63"))


## Fin de l'armement d'un coup annoncé : il porte si la cible vit encore et n'est pas sortie de portée (esquive).
func _land_strike(e: Enemy, core: Dictionary) -> void:
	var target := e.strike_target
	e.strike_at = INF
	e.strike_target = null
	if e.shot_aim != null:
		var aim: Vector2 = e.shot_aim
		e.shot_aim = null
		EnemyShots.fire(sim, e, aim)
		return
	Sfx.at(ENEMY_MELEE_SFX.get(e.kind, "fanatique"), e.x, e.z)
	if target != null:
		if target.hp <= 0.0 or target.hidden or dist(target, e) > e.reach + Catalog.ENEMY_WINDUP_SLACK:
			return
	elif Combat.hyp(e.x - core["x"], e.z - core["z"]) > e.reach + Catalog.ENEMY_WINDUP_SLACK:
		return
	_enemy_hit(e, target, core)


## Son des coups au corps à corps par type d'ennemi (fanatique par défaut).
const ENEMY_MELEE_SFX := {"brute": "automate", "strazhar": "automate", "beast": "aberration", "croc": "croc", "feline": "felin"}


func _move_enemy(e: Enemy, goal: Vector2, speed: float, dt: float) -> void:
	var next := sim.steer(e, goal)
	var direction := next - e.pos()
	var separation := Vector2.ZERO
	var here := e.pos()
	for other: Enemy in GameState.enemies:
		if other == e or other.hp <= 0.0:
			continue
		var away := here - other.pos()
		# Trop loin sur un axe pour gêner (la longueur est au moins |x| et |y|).
		if absf(away.x) >= 1.25 or absf(away.y) >= 1.25:
			continue
		var distance := away.length()
		if distance < 1.25:
			if distance < 0.001:
				away = Vector2(-1 if e.tactical_slot < other.tactical_slot else 1, 0)
			else:
				away /= distance
			separation += away * (1.25 - distance)
	var movement := direction.limit_length(speed * dt)
	if direction.length() > 0.1:
		movement = (movement + separation.limit_length(1.0) * speed * dt * 0.5).limit_length(speed * dt)
	var step := e.pos() + movement
	# Les corrections de formation ne doivent jamais pousser dans la roche.
	if sim.state().walkable(step.x, step.y):
		e.x = step.x
		e.z = step.y
	elif sim.state().walkable(step.x, e.z):
		e.x = step.x
	elif sim.state().walkable(e.x, step.y):
		e.z = step.y
	sim.clamp_world(e)


# ---------------------------------------------------------------- Vagues

## Menace figée au lancement : effectif, composition et statistiques de toute la vague.
func start_wave() -> void:
	GameState.wave += 1
	Sfx.play("vague")
	# Chaque vague, la végétation abîmée regagne un stade (trois vagues pour repousser).
	if sim.state().flora:
		sim.state().flora.regrow()
	if GameState.research_done.has("sylviculture"):
		sim.regrow_groves()
	# La faune hostile s'installe au premier assaut, puis se repeuple vague après vague.
	if GameState.wildlife_lairs.is_empty() and sim.world:
		Wildlife.populate(sim, sim.state().seed)
	else:
		Wildlife.on_wave(GameState.wave)
	var w := GameState.wave
	var menace := GameState.menace
	var tier := Catalog.menace_tier(menace)
	var n: int = Catalog.MENACE_WAVE["base"] + w * Catalog.MENACE_WAVE["per_wave"] + Catalog.MENACE_WAVE["count"] * tier
	GameState.spawn_queue = []
	var squads := wave_squads(w, n, menace)
	for k in squads.size():
		# Escouades en colonnes décalées : la suivante n'est lâchée qu'une fois la précédente partie (tactics.ready).
		var x := -2.0 if k % 2 == 0 else 2.0
		for kind: String in squads[k]:
			GameState.spawn_queue.append({"at": GameState.sim_time + 2.0, "x": x, "kind": kind, "menace_tier": tier, "squad": k})
	tactics.plan(GameState.spawn_queue)
	GameState.wave_squads = squads.size()
	GameState.squads_out = 0
	_log("vague %d (%d ennemis, %d escouades)" % [w, n, squads.size()])
	# Alerte rouge en bas à gauche, au-dessus de la minicarte (ui/hud/hud.gd), hors de la bannière bleue.
	Events.wave_alert.emit("Assaut %d : %d escouade%s remonte%s la jungle par le sud !" % [w, squads.size(),
		"s" if squads.size() > 1 else "", "nt" if squads.size() > 1 else ""], 5.0)


## Modèles d'escouade, par ordre d'importance : une escouade réduite garde ses premiers membres
## (puis le tri par rang les place). Les types encore verrouillés se rabattent sur un voisin.
const SQUADS := {
	"horde": ["creep", "brute", "spitter", "creep", "creep", "spitter", "creep"],
	"meute": ["creep", "scout", "creep", "scout", "creep", "creep", "creep"],
	"ligne": ["heavy", "heavy", "ranged", "creep", "heavy", "ranged", "creep"],
	"siege": ["brute", "soldier", "spitter", "brute", "soldier", "ranged", "creep"],
}
## Vague à partir de laquelle chaque modèle entre dans la rotation.
const SQUAD_UNLOCK := {"horde": 1, "meute": 2, "ligne": 3, "siege": 4}
const ROLE_ORDER := {"front": 0, "flank": 1, "support": 2, "reserve": 3}


## Composition de toute la vague, escouade par escouade, triée par rang (avant, flanc, appui, réserve).
## Effectif inchangé ; champions (Strazhar) en serre-file des premières escouades.
static func wave_squads(w: int, n: int, menace: int = 0) -> Array:
	var tier := Catalog.menace_tier(menace)
	w += floori(float(tier) / Catalog.MENACE_WAVE["composition_step"])
	var champions := 0
	if w >= 8 or menace >= Catalog.STRAZHAR_MENACE:
		champions = 1 + maxi(0, floori(float(tier - Catalog.MENACE_WAVE["champion_start"]) / Catalog.MENACE_WAVE["champion_step"]))
	# Le dernier modèle débloqué ouvre la vague ; la rotation tourne ensuite d'une vague à l'autre.
	var pool: Array = []
	for name: String in ["siege", "ligne", "meute", "horde"]:
		if w >= SQUAD_UNLOCK[name]:
			pool.append(name)
	var out: Array = []
	# Escouades de tailles équilibrées (10 → 5 + 5) : pas de reliquat isolé en fin de vague.
	var count := ceili(float(n) / EnemyTactics.GROUP_SIZE)
	for k in count:
		var size := n / count + (1 if k < n % count else 0)
		var kinds: Array = []
		for kind: String in (SQUADS[pool[(k + maxi(0, w - 4)) % pool.size()]] as Array).slice(0, size):
			kinds.append(_squad_kind(kind, w))
		if k < champions:
			kinds[-1] = "strazhar"
		kinds.sort_custom(func(a: String, b: String) -> bool:
			var ra: int = ROLE_ORDER[EnemyTactics.role_for(a)]
			var rb: int = ROLE_ORDER[EnemyTactics.role_for(b)]
			return ra < rb if ra != rb else EnemyTactics.front_priority(a) < EnemyTactics.front_priority(b))
		out.append(kinds)
	return out


static func _squad_kind(kind: String, w: int) -> String:
	match kind:
		"heavy": return "shield" if w >= 5 else ("soldier" if w >= 3 else "brute")
		"ranged": return "archer" if w >= 4 else "spitter"
		"soldier": return "soldier" if w >= 3 else "creep"
		"scout": return "scout" if w >= 2 else "creep"
	return kind


## Type du i-ème ennemi de la vague (ordre d'apparition).
static func wave_kind(w: int, i: int, n: int, menace: int = 0) -> String:
	var flat: Array = []
	for squad: Array in wave_squads(w, maxi(n, i + 1), menace):
		flat.append_array(squad)
	return flat[i]


## spawn : apparition au sud (z ≈ 62–66).
func spawn_enemy(s: Dictionary) -> Enemy:
	var x: float = s["x"] + (_rand() * 3.2 - 1.6)
	var z := 62.0 + _rand() * 4.0
	# Escouade : chacun sort directement à sa place dans la formation.
	if s.has("offset"):
		var p: Vector2 = s["group"]["origin"] + s["offset"]
		if not sim.state().walkable(p.x, p.y):
			p = sim.state().push_out_of_rock(p)
		x = p.x
		z = p.y
	var e := Enemy.make(s["kind"], x, z, 0.3 + _rand() * 0.7, Catalog.menace_stats(s.get("menace_tier", 0)))
	e.pace = Catalog.WAVE_PACE
	e.speed *= e.pace
	if s.has("group"):
		e.tactical_group = s["group"]
		e.tactical_group["spawned"] += 1
		if e.tactical_group["spawned"] == 1:
			e.tactical_group["spawned_at"] = GameState.sim_time
			GameState.squads_out += 1
		e.tactical_role = tactics.role_for(e.kind)
		e.tactical_slot = s["slot"]
	GameState.enemies.append(e)
	if e.kind == "strazhar":
		Sfx.play("strazhar")
	return e


## Les portails maléfiques sont devenus des Pylônes de Merenor (sim/pylons.gd), avancés par Simulation.tick.
## Gardé pour les appels existants (tests) : un pas de simulation des pylônes.
func update_evil_portals(dt := 1.0 / 60.0) -> void:
	Pylons.tick(sim, dt)


# ---------------------------------------------------------------- Balistes (turret-game.js)

static func reset_turrets() -> void:
	GameState.turrets.clear()
	GameState.turret_bolts.clear()
	# Les deux balistes de l'entrée sont retirées (séquence d'ouverture, 2026-11-18) : la liste reste vide.


## activateTurrets : les balistes s'éveillent avec l'Ancre.
func activate_turrets() -> void:
	for b in GameState.turrets:
		if b["complete"]:
			continue
		b["complete"] = true
		b["progress"] = Catalog.TURRET["repair_time"]
		b["cycle_age"] = 0.0
		b["finished_at"] = GameState.sim_time
		zone(b["x"], b["z"], 4.0, Color("#dccc9e"))
		flash(b["x"], b["z"], Color("#ffe6ae"))


## Dégâts déjà en vol vers un ennemi (turretPending) : pas de tir superflu sur un ennemi condamné.
static func turret_pending(e: Enemy) -> float:
	var n := 0.0
	for p in GameState.turret_bolts:
		if p["target"] == e:
			n += Catalog.TURRET["damage"]
	return n


func update_turrets(dt: float) -> void:
	var T := Catalog.TURRET
	for p in GameState.turret_bolts:
		p["age"] += dt
		if not p["hit"] and p["age"] >= p["duration"]:
			p["hit"] = true
			var tg: Enemy = p["target"]
			if tg.hp > 0.0:
				damage(tg, T["damage"])
				flash(tg.x, tg.z, Color("#dccc9e"))
				Sfx.at("fleche_impact", tg.x, tg.z)
	GameState.turret_bolts = GameState.turret_bolts.filter(func(p: Dictionary) -> bool: return not p["hit"])
	for b in GameState.turrets:
		if not b["complete"]:
			continue
		if b["firing"]:
			b["cycle_age"] += dt
			if b["cycle_age"] >= T["cycle"]:
				b["cycle_age"] = 0.0
				b["firing"] = false
				b["target"] = null
			continue
		b["cycle_age"] = minf(T["cycle"] * 0.73, b["cycle_age"] + dt)
		var cands := GameState.enemies.filter(func(e: Enemy) -> bool:
			return e.hp > 0.0 and e.hp - turret_pending(e) > 0.0 and Combat.hyp(b["x"] - e.x, b["z"] - e.z) <= T["range"])
		var target: Variant = target_closest(b, cands, T["range"] + 0.001, sim.world)
		if target:
			b["aim"] = target
		if target == null or b["cycle_age"] < T["cycle"] * 0.73:
			continue
		b["target"] = target
		b["firing"] = true
		b["cycle_age"] = T["cycle"] * 0.76
		var duration := maxf(0.12, dist(b, target) / T["bolt_speed"])
		GameState.turret_bolts.append({"x": b["x"], "z": b["z"], "target": target, "tx": target.x, "tz": target.z, "age": 0.0, "duration": duration, "hit": false})
		Sfx.at("tourelle", b["x"], b["z"])


## orderTurretRepair : les balistes s'éveillent seules avec l'Ancre ; le clic droit renseigne seulement.
func order_turret(b: Dictionary) -> void:
	if GameState.ended:
		return
	if b["complete"]:
		sim.say("Garde tyrienne active · portée %d · dégâts %d." % [int(Catalog.TURRET["range"]), Catalog.TURRET["damage"]], 2.0)
		return
	sim.say("Garde tyrienne endormie · elle s’éveillera quand l’Ingénieur aura réactivé l’Ancre.", 3.0)


# ---------------------------------------------------------------- Fin de partie et vagues

## Morts, effets, fin de partie (Ancre détruite), vagues sans fin après l'Ancre.
func finish_tick(dt: float, alive: Array[Unit]) -> void:
	for u in GameState.units:
		if u.hp <= 0.0 and not u.dead:
			u.dead = true
			_log("%s tombe" % u.name)
			Sfx.at("exile_mort", u.x, u.z)
			if u.role == "flammes":
				flame_explosion(u)
			sim.on_unit_death(u)
	# Comptage avant retrait : une seule fois par mort, hors faune de la caverne.
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0:
			e.dead = true
			e.died_at = GameState.sim_time
			Sfx.at("ennemi_mort", e.x, e.z)
			Loot.roll(e)
			GameState.enemy_corpses.append(e)
			if not e.beast:
				GameState.menace += int(Catalog.KILL_MENACE.get(e.kind, 1))
			if log_events:
				_log("%s abattu en (%.2f, %.2f)" % [e.kind, e.x, e.z])
	GameState.enemies = GameState.enemies.filter(func(e: Enemy) -> bool: return e.hp > 0.0)
	Loot.prune()
	GameState.effects = GameState.effects.filter(func(e: Dictionary) -> bool:
		e["age"] += dt
		return e["age"] < e["duration"])
	GameState.damage_numbers = GameState.damage_numbers.filter(func(e: Dictionary) -> bool:
		e["age"] += dt
		return e["age"] < e["duration"])
	# Seule la destruction de l'Ancre termine la partie : l'Ingénieur tombé revient à la capsule (Simulation.engineer_fell).
	if GameState.core_hp <= 0.0:
		end_game(false)
	elif GameState.orb_active and not GameState.enemies.any(func(e: Enemy) -> bool: return not e.beast) and GameState.spawn_queue.is_empty():
		if GameState.next_wave == 0.0:
			# La nuit reste calme : l'assaut suivant vient le lendemain matin (un assaut par jour).
			var at := DayNight.next_assault(GameState.sim_time, GameState.wave, sim.state().seed)
			GameState.next_wave = at
		elif GameState.sim_time >= GameState.next_wave and DayNight.is_day(GameState.sim_time):
			GameState.next_wave = 0.0
			start_wave()


## end(won) : la simulation se fige, la bannière s'affiche.
func end_game(won: bool) -> void:
	GameState.ended = true
	_log("fin : %s" % ("victoire" if won else "défaite"))
	Sfx.play("victoire" if won else "defaite")
	Events.game_over.emit(won)
