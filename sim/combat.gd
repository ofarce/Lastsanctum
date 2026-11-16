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
static func target_closest(source: Variant, list: Array, range_ := 1e9) -> Variant:
	var best: Variant = null
	var d := range_
	for t: Variant in list:
		if t.hp <= 0.0 or t.hidden:
			continue
		var nd := dist(t, source)
		if nd < d:
			d = nd
			best = t
	return best


# ---------------------------------------------------------------- Dégâts et expérience

## damage : `src` gagne l'expérience du monstre qu'il achève.
func damage(t: Unit, amount: float, src: Unit = null) -> void:
	var was := t.hp
	if t is Enemy and amount > 0.0:
		amount = maxf(amount * 0.15, amount - (t as Enemy).armor)
	t.hp = maxf(0.0, t.hp - amount)
	if src and t.is_enemy() and was > 0.0 and t.hp <= 0.0:
		_log("%s achève %s" % [src.name, (t as Enemy).kind])
		gain_xp(src, Catalog.KILL_XP.get((t as Enemy).kind, 10))


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


## arrow : flèche de l'archer, puis étincelles à l'impact.
func arrow(a: Unit, b: Variant) -> void:
	var face := -1 if b.x - a.x < 0.0 else 1
	var dur := maxf(0.09, dist(a, b) * 0.02)
	_fx({"type": "arrow", "x": a.x, "z": a.z, "tx": b.x, "tz": b.z, "face": face, "age": 0.0, "duration": dur, "seed": _seed()})
	_fx({"type": "arrowhit", "x": b.x, "z": b.z, "age": -dur, "duration": 0.24, "seed": _seed()})


## volley : trois carreaux du Tireur, chacun suivi d'une explosion sur la cible.
func volley(a: Unit, b: Unit) -> void:
	a.sh_t0 = GameState.sim_time
	a.face = -1 if (b.x - b.z) - (a.x - a.z) < 0.0 else 1
	var dur := maxf(0.07, dist(a, b) * 0.013)
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


# ---------------------------------------------------------------- Frappes (adepts.js)

## barracksStrike : attaque d'une unité de la table FIGHT.
func barracks_strike(u: Unit, e: Enemy) -> void:
	var F: Dictionary = Catalog.FIGHT[u.role]
	var k := 1.5 if u.buff > 0.0 else 1.0
	var dmg: float = (Catalog.attack_damage(u) + Catalog.lvl_bonus(u)) * k
	u.attack = F["cd"]
	u.face = -1 if e.x - u.x < 0.0 else 1
	# D15 : le lance-flammes n'a plus de sillon de feu ; en jeu, il tire en continu (flame_tick).
	if u.role == "flammes":
		for o: Enemy in GameState.enemies.duplicate():
			if o.hp > 0.0 and dist(o, e) < F["splash"]:
				damage(o, dmg, u)
		blast(u, e, Color("#ff9a30"))
		flash(e.x, e.z, Color("#ffb050"))
		return
	if u.role == "lame" and moulinet(u, dmg):
		return
	damage(e, dmg, u)
	if u.role == "archer":
		arrow(u, e)
	elif F.get("ranged", false):
		blast(u, e, Color("#bed7df"))
		flash(e.x, e.z, Color("#bed7df"))
	else:
		flash(e.x, e.z, Color("#f0dba4"))
		sword_strike(u, e)


## archerTick : Charge du Lac. Renvoie vrai si l'archer a agi (charge, mêlée, approche).
func archer_tick(u: Unit, e: Variant, dt: float) -> bool:
	var C := Catalog.CHARGE
	var t := GameState.sim_time
	if u.dash != null:
		var target: Enemy = u.dash["e"]
		if target.hp <= 0.0:
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
	var dmg: float = (Catalog.attack_damage(u) + Catalog.lvl_bonus(u)) * k / F["cd"] * dt
	u.attack = 0.1
	u.face = -1 if e.x - u.x < 0.0 else 1
	for o: Enemy in GameState.enemies.duplicate():
		if o.hp > 0.0 and dist(o, e) < F["splash"]:
			damage(o, dmg, u)
	var now := GameState.sim_time
	if now >= u.flame_fx:
		u.flame_fx = now + 0.06
		blast(u, e, Color("#ff9a30"))
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
	_log("%s explose" % u.name)


## fightBusy : l'unité est en train de frapper (animation de travail des adeptes).
static func fight_busy(u: Unit) -> bool:
	var F: Dictionary = Catalog.FIGHT.get(u.role, {})
	if F.is_empty():
		return u.attack > 0.25
	return u.attack > (-0.05 if u.role == "flammes" else F["cd"] * 0.45)


# ---------------------------------------------------------------- Alliés (update, Index.html)

func update_units(dt: float, alive: Array[Unit]) -> void:
	for u in alive:
		if u.force_move and Combat.hyp(u.x - u.tx, u.z - u.tz) < 0.6:
			u.force_move = false
		var enemy: Variant = null
		var busy := u.hidden or (u.role == "engineer" and (u.job != null or u.build_job != null or u.orb_job)) \
			or (Catalog.is_adept(u) and u.job != null)
		if not u.force_move and not busy:
			var seek: float = Catalog.FIGHT[u.role]["seek"] if Catalog.FIGHT.has(u.role) else Catalog.HERO.get(u.role, {"seek": 10.0})["seek"]
			if u.role == "engineer" and not u.unarmored:
				seek = 250.0
			enemy = target_closest(u, GameState.enemies, seek)
		if u.role == "archer" and archer_tick(u, enemy, dt):
			continue
		if u.stance != "hold" and enemy != null:
			var fight: bool = Catalog.FIGHT.has(u.role)
			var reach: float = Catalog.unit_reach(u)
			if dist(u, enemy) > reach:
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
				else:
					flash(enemy.x, enemy.z, Color("#f0dba4"))
					sword_strike(u, enemy)
				u.attack = {"paladin": 0.88, "shooter": 0.78, "indra": 0.55}.get(u.role, 1.15)
		elif u.stance != "hold":
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


# ---------------------------------------------------------------- Ennemis

func update_enemies(dt: float, alive: Array[Unit]) -> void:
	tactics.update(dt, alive)
	var core := {"x": CaveShape.CORE.x, "z": CaveShape.CORE.y}
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0:
			continue
		if e.stun > 0.0:
			e.stun -= dt
			continue
		var espd := e.speed * (Catalog.SILLON["slow"] if e.slow_until > GameState.sim_time else 1.0)
		e.cooldown -= dt
		var coordinated := not e.tactical_group.is_empty()
		var target: Variant = tactics.target(e, alive) if coordinated else target_closest(e, alive, e.reach if e.kind == "archer" else 4.5)
		var is_core := target == null
		var tx: float = core["x"] if is_core else target.x
		var tz: float = core["z"] if is_core else target.z
		var d := Combat.hyp(e.x - tx, e.z - tz)
		var ordered: bool = coordinated and e.tactical_goal != null
		# Au contact, la mêlée se défend même pendant le rassemblement ou la réserve.
		var in_contact: bool = not is_core and d <= e.reach
		var retreating: bool = e.tactical_retreating
		if ordered and (not in_contact or retreating):
			_move_enemy(e, e.tactical_goal, minf(espd, e.tactical_speed), dt)
		elif d > e.reach:
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
		if d <= e.reach and e.cooldown <= 0.0 and not retreating:
			e.attack_started = GameState.sim_time
			e.face = -1 if tx < e.x else 1
			var dmg := e.damage
			if not is_core:
				var u: Unit = target
				if u.shield > 0.0:
					dmg *= 0.35
				if Catalog.FIGHT.has(u.role) and Catalog.FIGHT[u.role].has("guard"):
					dmg *= Catalog.FIGHT[u.role]["guard"]
				damage(u, after_armor(u, dmg))
			else:
				GameState.core_hp = maxf(0.0, GameState.core_hp - dmg)
			flash(tx, tz, Color("#e17b63"))
			if e.kind == "archer":
				arrow(e, core if is_core else target)
			elif e.kind == "spitter":
				blast(e, {"x": tx, "z": tz}, Color("#c88f9e"))
			e.cooldown = Catalog.ENEMY[e.kind]["cd"]


func _move_enemy(e: Enemy, goal: Vector2, speed: float, dt: float) -> void:
	var next := sim.steer(e, goal)
	var direction := next - e.pos()
	var separation := Vector2.ZERO
	for other: Enemy in GameState.enemies:
		if other == e or other.hp <= 0.0:
			continue
		var away := e.pos() - other.pos()
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
	var w := GameState.wave
	var menace := GameState.menace
	var tier := Catalog.menace_tier(menace)
	var n: int = 4 + w * 3 + Catalog.MENACE_WAVE["count"] * tier
	GameState.spawn_queue = []
	for i in n:
		var kind := wave_kind(w, i, n, menace)
		GameState.spawn_queue.append({"at": GameState.sim_time + 2.0 + i * maxf(0.35, 1.5 - w * 0.14), "x": -2.0 if i % 2 == 0 else 2.0, "kind": kind, "menace_tier": tier})
	tactics.plan(GameState.spawn_queue)
	_log("vague %d (%d ennemis)" % [w, n])
	sim.say("Assaut %d : des créatures remontent la jungle par le sud." % w, 3.0)


## Renforts avancés par la menace ; champions supplémentaires aux paliers 15, 20…
static func wave_kind(w: int, i: int, _n: int, menace: int = 0) -> String:
	var tier := Catalog.menace_tier(menace)
	w += floori(float(tier) / Catalog.MENACE_WAVE["composition_step"])
	var champions := 1 + maxi(0, floori(float(tier - Catalog.MENACE_WAVE["champion_start"]) / Catalog.MENACE_WAVE["champion_step"]))
	if (w >= 8 or menace >= Catalog.STRAZHAR_MENACE) and i < champions:
		return "strazhar"
	if w >= 5 and i % 7 == 5:
		return "shield"
	if w >= 4 and i % 7 == 3:
		return "archer"
	if w >= 3 and i % 7 == 2:
		return "soldier"
	if w >= 2 and i % 7 == 1:
		return "scout"
	return "brute" if i % 5 == 4 else ("spitter" if i % 6 == 3 else "creep")


## spawn : apparition au sud (z ≈ 62–66).
func spawn_enemy(s: Dictionary) -> Enemy:
	var x: float = s["x"] + (_rand() * 3.2 - 1.6)
	var z := 62.0 + _rand() * 4.0
	var e := Enemy.make(s["kind"], x, z, 0.3 + _rand() * 0.7, Catalog.menace_stats(s.get("menace_tier", 0)))
	if s.has("group"):
		e.tactical_group = s["group"]
		e.tactical_group["spawned"] += 1
		e.tactical_role = tactics.role_for(e.kind)
		e.tactical_slot = s["slot"]
	GameState.enemies.append(e)
	return e


## Chaque apparition relit la menace ; les créatures déjà présentes gardent leurs statistiques.
func update_evil_portals() -> void:
	if GameState.ended:
		return
	for p: Dictionary in sim.state().portals:
		if not p["active"] or GameState.sim_time < p["next"]:
			continue
		var tier := Catalog.menace_tier(GameState.menace)
		p["next"] = GameState.sim_time + Catalog.menace_portal_interval(tier)
		var n := 0
		for e: Enemy in GameState.enemies:
			if e.portal == p and e.hp > 0.0:
				n += 1
		if n >= Catalog.menace_portal_cap(tier):
			continue
		var e := Enemy.make("beast", p["x"] + (_rand() - 0.5) * 2.0, p["z"] + 2.0 + _rand(), 0.0, Catalog.menace_stats(tier, true))
		e.cooldown = 0.3 + _rand() * 0.7
		e.portal = p
		if not sim.state().walkable(e.x, e.z):
			var q := sim.state().push_out_of_rock(e.pos())
			e.x = q.x
			e.z = q.y
		GameState.enemies.append(e)
		flash(e.x, e.z, Color("#ff5030"))


# ---------------------------------------------------------------- Balistes (turret-game.js)

static func reset_turrets() -> void:
	GameState.turrets.clear()
	GameState.turret_bolts.clear()
	for i in 2:
		GameState.turrets.append({"id": i, "x": -11.0 if i == 0 else 11.0, "z": -71.0, "progress": 0.0, "complete": false,
			"cycle_age": 0.0, "firing": false, "target": null, "aim": null, "finished_at": INF})


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
		var target: Variant = target_closest(b, cands, T["range"] + 0.001)
		if target:
			b["aim"] = target
		if target == null or b["cycle_age"] < T["cycle"] * 0.73:
			continue
		b["target"] = target
		b["firing"] = true
		b["cycle_age"] = T["cycle"] * 0.76
		var duration := maxf(0.12, dist(b, target) / T["bolt_speed"])
		GameState.turret_bolts.append({"x": b["x"], "z": b["z"], "target": target, "tx": target.x, "tz": target.z, "age": 0.0, "duration": duration, "hit": false})


## orderTurretRepair : les balistes s'éveillent seules avec l'Ancre ; le clic droit renseigne seulement.
func order_turret(b: Dictionary) -> void:
	if GameState.ended:
		return
	if b["complete"]:
		sim.say("Garde tyrienne active · portée %d · dégâts %d." % [int(Catalog.TURRET["range"]), Catalog.TURRET["damage"]], 2.0)
		return
	sim.say("Garde tyrienne endormie · elle s’éveillera quand l’Ingénieur aura réactivé l’Ancre.", 3.0)


# ---------------------------------------------------------------- Fin de partie et vagues

## Morts, effets, fin de partie (3 conditions), vagues sans fin après l'Ancre.
func finish_tick(dt: float, alive: Array[Unit]) -> void:
	for u in GameState.units:
		if u.hp <= 0.0 and not u.dead:
			u.dead = true
			_log("%s tombe" % u.name)
			if u.role == "flammes":
				flame_explosion(u)
			sim.on_unit_death(u)
	# Comptage avant retrait : une seule fois par mort, hors faune de la caverne.
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0:
			e.dead = true
			e.died_at = GameState.sim_time
			GameState.enemy_corpses.append(e)
			if not e.beast:
				GameState.menace += 1
			if log_events:
				_log("%s abattu en (%.2f, %.2f)" % [e.kind, e.x, e.z])
	GameState.enemies = GameState.enemies.filter(func(e: Enemy) -> bool: return e.hp > 0.0)
	GameState.enemy_corpses = GameState.enemy_corpses.filter(func(e: Enemy) -> bool:
		return GameState.sim_time - e.died_at < EnemyArt.CORPSE_LIFETIME)
	while GameState.enemy_corpses.size() > EnemyArt.MAX_CORPSES:
		GameState.enemy_corpses.pop_front()
	GameState.effects = GameState.effects.filter(func(e: Dictionary) -> bool:
		e["age"] += dt
		return e["age"] < e["duration"])
	var engineer_down := GameState.units.any(func(u: Unit) -> bool: return u.role == "engineer" and u.hp <= 0.0)
	if GameState.core_hp <= 0.0 or alive.is_empty() or engineer_down:
		end_game(false)
	elif GameState.orb_active and not GameState.enemies.any(func(e: Enemy) -> bool: return not e.beast) and GameState.spawn_queue.is_empty():
		if GameState.next_wave == 0.0:
			GameState.next_wave = GameState.sim_time + 4.0
			sim.say("Zone sécurisée. Prochain assaut imminent.", 3.0)
		elif GameState.sim_time >= GameState.next_wave:
			GameState.next_wave = 0.0
			start_wave()


## end(won) : la simulation se fige, la bannière s'affiche.
func end_game(won: bool) -> void:
	GameState.ended = true
	_log("fin : %s" % ("victoire" if won else "défaite"))
	Events.game_over.emit(won)
