extends RefCounted
## Coordination des assauts : groupes de sept, front, appui et réserve.
## Les dictionnaires partagés ne référencent aucune unité : pas de cycle de RefCounted.
const GROUP_SIZE := 7
const SPACING := 1.8
const DETECTION := 28.0
## Proximité de l'Ancre qui vaut contact : restée à 14 m quand la détection des cibles a doublé (2026-11-20).
const CORE_CONTACT := 14.0
## Au combat : largeur du premier rang, durée maximale de tenue du second rang et de la réserve.
const FIRST_RANK := 3
const HOLD_RANKS := 6.0
const HOLD_RESERVE := 8.0

var sim: Simulation


func _init(s: Simulation) -> void:
	sim = s


static func role_for(kind: String) -> String:
	match kind:
		"archer", "spitter": return "support"
		"scout": return "flank"
		"strazhar": return "reserve"
		_: return "front"


## Distance parcourue par une escouade avant que la suivante soit lâchée, ou délai maximal.
const RELEASE_DISTANCE := 12.0
const RELEASE_DELAY := 6.0
## Ligne de départ des escouades (au sud, z ≈ 62) ; les rangs s'échelonnent derrière.
const ORIGIN_Z := 59.5
## En marche, une escouade ne remonte pas à moins de cette distance de la précédente (pas de dépassement).
const FOLLOW_GAP := 8.0


## Ajoute les ordres sans changer types, effectifs ni hasard d'apparition. Une entrée « squad » regroupe
## l'escouade et lui donne sa place de départ ; sinon, groupes séquentiels de sept.
static func plan(queue: Array) -> void:
	var squads: Array = []
	var index := {}
	for i in queue.size():
		var key: int = queue[i].get("squad", i / GROUP_SIZE)
		if not index.has(key):
			index[key] = squads.size()
			squads.append([])
		squads[index[key]].append(i)
	var prev: Dictionary = {}
	for members: Array in squads:
		var begin: int = members[0]
		var end_at: float = queue[members[-1]]["at"]
		var origin := Vector2(float(queue[begin]["x"]), ORIGIN_Z)
		var group := {"id": begin, "expected": members.size(), "spawned": 0, "anchor": origin,
			"origin": origin, "center": origin, "spawned_at": INF, "prev": prev, "front_count": 0,
			"release_at": minf(queue[begin]["at"] + 10.0, end_at + 3.0),
			"phase": "gather", "engaged_at": INF, "memo": {}, "stalled": 0.0,
			"last_contact": -INF, "last_center": origin}
		var front: Array = []
		for i: int in members:
			if role_for(queue[i]["kind"]) == "front":
				front.append(i)
		front.sort_custom(func(a: int, b: int) -> bool:
			var pa := front_priority(queue[a]["kind"])
			var pb := front_priority(queue[b]["kind"])
			return pa < pb if pa != pb else a < b)
		group["front_count"] = front.size()
		var cols := mini(3, front.size())
		var support_index := 0
		for i: int in members:
			queue[i]["group"] = group
			queue[i]["slot"] = i - begin
			if not queue[i].has("squad"):
				continue
			# Même disposition que la marche en terrain ouvert (vers le nord) : avant, puis appui à 4 m.
			var rank := front.find(i)
			if rank >= 0:
				queue[i]["offset"] = Vector2(((rank % cols) - (cols - 1) * 0.5) * SPACING, (rank / 3) * SPACING)
			else:
				queue[i]["offset"] = Vector2(((support_index % 3) - 1) * SPACING, 4.0 + (support_index / 3) * SPACING)
				support_index += 1
		prev = group


## Une escouade ne sort qu'une fois la précédente entièrement sortie et partie (12 m) ou au bout de 6 s.
func ready(entry: Dictionary) -> bool:
	var g: Dictionary = entry.get("group", {})
	if g.is_empty() or g["spawned"] > 0:
		return true
	var prev: Dictionary = g.get("prev", {})
	if prev.is_empty():
		return true
	if prev["spawned"] < prev["expected"]:
		return false
	if GameState.sim_time - float(prev["spawned_at"]) >= RELEASE_DELAY:
		return true
	return (prev["center"] as Vector2).distance_to(prev["origin"]) >= RELEASE_DISTANCE


func update(dt: float, alive: Array[Unit]) -> void:
	var groups := {}
	for e: Enemy in GameState.enemies:
		e.tactical_goal = null
		e.tactical_speed = e.speed
		e.tactical_retreating = false
		if e.hp <= 0.0 or e.tactical_group.is_empty():
			continue
		var id: int = e.tactical_group["id"]
		if not groups.has(id):
			groups[id] = []
		groups[id].append(e)
	for members: Array in groups.values():
		_update_group(members, alive, dt)


func _update_group(members: Array, alive: Array[Unit], dt: float) -> void:
	var g: Dictionary = members[0].tactical_group
	var center := Vector2.ZERO
	var front: Array = []
	var speed := INF
	var contact := false
	for e: Enemy in members:
		center += e.pos()
		if e.tactical_role == "front":
			front.append(e)
		if e.tactical_role != "reserve":
			speed = minf(speed, e.speed)
		if e.hp < e.tactical_last_hp or Combat.target_closest(e, alive, DETECTION) != null or e.pos().distance_to(CaveShape.CORE) < CORE_CONTACT:
			contact = true
		e.tactical_last_hp = e.hp
	center /= members.size()
	g["center"] = center
	g["seen_at"] = GameState.sim_time
	if speed == INF:
		speed = members[0].speed
	front.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		var pa := front_priority(a.kind)
		var pb := front_priority(b.kind)
		return pa < pb if pa != pb else a.tactical_slot < b.tactical_slot)
	if contact:
		g["last_contact"] = GameState.sim_time
	if g["phase"] == "engage" and GameState.sim_time - g["last_contact"] > 3.0:
		g["phase"] = "march"
		g["anchor"] = center
		g["memo"].clear()
	if contact and g["phase"] not in ["engage", "assault"]:
		g["phase"] = "engage"
		g["engaged_at"] = GameState.sim_time
	elif g["phase"] == "gather":
		if GameState.sim_time >= g["release_at"] or (members.size() == g["expected"] and center.distance_to(g["anchor"]) < 4.0):
			g["phase"] = "march"
	# Après de fortes pertes, aucun survivant n'attend sa formation ou sa réserve.
	var broken: bool = members.size() * 2 <= int(g["spawned"])
	if broken:
		g["phase"] = "assault"
	var tailgating: bool = g["phase"] == "march" and _tailgating(g, center)
	if g["phase"] == "march":
		var anchor: Vector2 = g["anchor"]
		# L'ancre attend brièvement les retardataires, sans pouvoir immobiliser l'assaut.
		if (center.distance_to(anchor) < 8.0 or g["stalled"] > 3.0) and not tailgating:
			var next := sim.world.pathfinder.steer(anchor, _march_goal(anchor), g["memo"])
			g["anchor"] = anchor.move_toward(next, speed * dt)
	# Attendre l'escouade de devant n'est pas un blocage.
	if tailgating or center.distance_to(g["last_center"]) > 0.5:
		g["last_center"] = center
		g["stalled"] = 0.0
	else:
		g["stalled"] += dt
	if g["stalled"] > 8.0 and g["phase"] != "gather":
		g["phase"] = "assault"
	var anchor: Vector2 = g["anchor"]
	# Orienter les rangs selon le prochain segment du chemin, y compris dans les galeries coudées.
	var forward := (sim.world.pathfinder.steer(anchor, _march_goal(anchor), g["memo"]) - anchor).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2(0, -1)
	var side := Vector2(-forward.y, forward.x)
	var column := not _open(anchor, side * 3.0)
	var support_index := 0
	for e: Enemy in members:
		var target := _target(e, alive)
		if g["phase"] == "assault":
			continue
		if g["phase"] == "engage":
			_combat_order(e, target, front, g, dt)
			continue
		var offset := Vector2.ZERO
		if column:
			# Rang calculé par rôle, pour que les boucliers ouvrent aussi les colonnes.
			var rank := front.find(e)
			if rank < 0:
				rank = front.size() + support_index
				support_index += 1
			offset = -forward * rank * SPACING
		elif e.tactical_role == "front":
			var rank := front.find(e)
			var cols := mini(3, front.size())
			offset = side * ((rank % cols) - (cols - 1) * 0.5) * SPACING - forward * (rank / 3) * SPACING
		else:
			offset = side * ((support_index % 3) - 1) * SPACING - forward * (4.0 + (support_index / 3) * SPACING)
			support_index += 1
		var goal := anchor + offset
		if not sim.state().walkable(goal.x, goal.y):
			goal = anchor
		e.tactical_goal = goal
		# Rattrapage autorisé à la vitesse naturelle ; aucune unité n'est accélérée.
		e.tactical_speed = e.speed if e.pos().distance_to(goal) > 3.0 else minf(e.speed, speed)


## L'escouade précédente, encore en marche et toute proche, impose son allure : on reste derrière elle.
static func _tailgating(g: Dictionary, center: Vector2) -> bool:
	var prev: Dictionary = g.get("prev", {})
	if prev.is_empty() or prev["phase"] not in ["gather", "march"]:
		return false
	if GameState.sim_time - float(prev.get("seen_at", -INF)) > 0.5:
		return false
	return center.distance_to(prev["center"]) < FOLLOW_GAP


static func front_priority(kind: String) -> int:
	return {"shield": 0, "soldier": 1, "brute": 2}.get(kind, 3)


func _open(origin: Vector2, offset: Vector2) -> bool:
	return sim.world.pathfinder.clear_line(origin, origin + offset) and sim.world.pathfinder.clear_line(origin, origin - offset)


func _target(e: Enemy, alive: Array[Unit]) -> Unit:
	if GameState.sim_time < e.tactical_target_until:
		for u: Unit in alive:
			if u.id == e.tactical_target_id and u.hp > 0.0 and not u.hidden and Combat.dist(e, u) < DETECTION:
				return u
	var best: Unit = null
	var score := INF
	var ex := e.x
	var ez := e.z
	for u: Unit in alive:
		# Écart sur un seul axe déjà hors de détection : la distance (≥ |dx| et ≥ |dz|) l'est aussi.
		var dx := ex - u.x
		if dx >= DETECTION or dx <= -DETECTION:
			continue
		var dz := ez - u.z
		if dz >= DETECTION or dz <= -DETECTION:
			continue
		if u.hp <= 0.0 or u.hidden:
			continue
		var d := sqrt(dx * dx + dz * dz)
		if d >= DETECTION:
			continue
		var value := d
		if e.tactical_role in ["flank", "reserve"] and u.role in ["healer", "shooter", "engineer"]:
			value -= 3.0
		if value < score:
			score = value
			best = u
	e.tactical_target_id = best.id if best != null else -1
	e.tactical_target_until = GameState.sim_time + 1.2
	return best


func target(e: Enemy, alive: Array[Unit]) -> Unit:
	return _target(e, alive)


func _combat_order(e: Enemy, target_unit: Unit, front: Array, g: Dictionary, dt: float) -> void:
	var destination := target_unit.pos() if target_unit != null else CaveShape.CORE
	var elapsed: float = GameState.sim_time - g["engaged_at"]
	var rank := front.find(e)
	# Seul le premier rang (trois de front) s'engage ; le second tient à deux pas et comble les vides.
	if rank >= FIRST_RANK and elapsed < HOLD_RANKS and e.hp == e.max_hp and e.pos().distance_to(destination) > e.reach:
		var line := Vector2.ZERO
		for f: Enemy in front.slice(0, FIRST_RANK):
			line += f.pos()
		line /= FIRST_RANK
		var back := (line - destination).normalized()
		e.tactical_goal = line + back * 2.0 + Vector2(-back.y, back.x) * ((rank % 3) - 1) * SPACING
		e.tactical_speed = minf(e.speed, 2.1 * e.pace)
	# La réserve ne charge qu'à l'ordre : front à moitié détruit, ou passé huit secondes.
	elif e.tactical_role == "reserve" and not front.is_empty() and elapsed < HOLD_RESERVE and e.hp == e.max_hp \
			and front.size() * 2 > int(g.get("front_count", front.size())):
		var front_center := Vector2.ZERO
		for f: Enemy in front:
			front_center += f.pos()
		front_center /= front.size()
		e.tactical_goal = front_center + (front_center - destination).normalized() * 5.0
		e.tactical_speed = minf(e.speed, 2.1 * e.pace)
	elif e.tactical_role == "support":
		if not front.is_empty() and e.pos().distance_to(destination) > e.reach:
			var front_center := Vector2.ZERO
			for f: Enemy in front:
				front_center += f.pos()
			front_center /= front.size()
			e.tactical_goal = front_center + (front_center - destination).normalized() * 4.0
			e.tactical_speed = minf(e.speed, 2.1 * e.pace)
		# Repli limité à trois secondes cumulées : pas de fuite interminable.
		if target_unit != null and Combat.dist(e, target_unit) < e.reach * 0.55 and e.tactical_retreat < 3.0:
			var away := (e.pos() - destination).normalized()
			if away == Vector2.ZERO:
				away = Vector2(0, 1)
			var goal := e.pos() + away * 2.0
			if sim.world.pathfinder.clear_line(e.pos(), goal):
				e.tactical_goal = goal
				e.tactical_retreat += dt
				e.tactical_retreating = true
	elif e.tactical_role == "flank" and target_unit != null and elapsed < 6.0 and not front.is_empty():
		var forward := (destination - e.pos()).normalized()
		var side := Vector2(-forward.y, forward.x) * (-1.0 if int(g["id"]) % 2 == 0 else 1.0)
		var goal := destination + side * 4.0
		# On ne contourne que dans l'espace visible et réellement libre.
		if e.pos().distance_to(destination) > 4.5 and sim.world.pathfinder.clear_line(e.pos(), goal) and sim.world.pathfinder.clear_line(goal, destination):
			e.tactical_goal = goal


## But de marche d'une escouade : l'Ancre, sauf dans la jungle près de la route principale, où elle vise
## un point de la route un peu plus au nord. Les assauts remontent donc le chemin (pont central, virages,
## entrée) au lieu de couper tout droit à travers la jungle.
const ROAD_PULL := 24.0
const ROAD_AHEAD := 10.0
func _march_goal(anchor: Vector2) -> Vector2:
	var road: Road = sim.state().road
	if road == null or anchor.y <= Road.GATE_Z + 4.0 or absf(anchor.x - road.main_x(anchor.y)) > ROAD_PULL:
		return CaveShape.CORE
	var z := maxf(anchor.y - ROAD_AHEAD, Road.GATE_Z)
	return Vector2(road.main_x(z), z)
