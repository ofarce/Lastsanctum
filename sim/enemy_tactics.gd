extends RefCounted
## Coordination des assauts : groupes de sept, front, appui et réserve.
## Les dictionnaires partagés ne référencent aucune unité : pas de cycle de RefCounted.
const GROUP_SIZE := 7
const SPACING := 1.8
const DETECTION := 14.0

var sim: Simulation


func _init(s: Simulation) -> void:
	sim = s


static func role_for(kind: String) -> String:
	match kind:
		"archer", "spitter": return "support"
		"scout": return "flank"
		"strazhar": return "reserve"
		_: return "front"


## Ajoute les ordres sans changer types, effectifs, cadence ni hasard d'apparition.
static func plan(queue: Array) -> void:
	for begin in range(0, queue.size(), GROUP_SIZE):
		var end := mini(begin + GROUP_SIZE, queue.size())
		var group := {"id": begin, "expected": end - begin, "spawned": 0, "anchor": Vector2(0, 59),
			"release_at": minf(queue[begin]["at"] + 10.0, queue[end - 1]["at"] + 3.0),
			"phase": "gather", "engaged_at": INF, "memo": {}, "stalled": 0.0,
			"last_contact": -INF, "last_center": Vector2(0, 64)}
		for i in range(begin, end):
			queue[i]["group"] = group
			queue[i]["slot"] = i - begin


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
		if e.hp < e.tactical_last_hp or Combat.target_closest(e, alive, DETECTION) != null or e.pos().distance_to(CaveShape.CORE) < DETECTION:
			contact = true
		e.tactical_last_hp = e.hp
	center /= members.size()
	if speed == INF:
		speed = members[0].speed
	front.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		var pa := _front_priority(a.kind)
		var pb := _front_priority(b.kind)
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
	if g["phase"] == "march":
		var anchor: Vector2 = g["anchor"]
		# L'ancre attend brièvement les retardataires, sans pouvoir immobiliser l'assaut.
		if center.distance_to(anchor) < 8.0 or g["stalled"] > 3.0:
			var next := sim.world.pathfinder.steer(anchor, CaveShape.CORE, g["memo"])
			g["anchor"] = anchor.move_toward(next, speed * dt)
	if center.distance_to(g["last_center"]) > 0.5:
		g["last_center"] = center
		g["stalled"] = 0.0
	else:
		g["stalled"] += dt
	if g["stalled"] > 8.0 and g["phase"] != "gather":
		g["phase"] = "assault"
	var anchor: Vector2 = g["anchor"]
	# Orienter les rangs selon le prochain segment du chemin, y compris dans les galeries coudées.
	var forward := (sim.world.pathfinder.steer(anchor, CaveShape.CORE, g["memo"]) - anchor).normalized()
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


static func _front_priority(kind: String) -> int:
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
	for u: Unit in alive:
		if u.hp <= 0.0 or u.hidden:
			continue
		var d := Combat.dist(e, u)
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
	if e.tactical_role == "reserve" and not front.is_empty() and elapsed < 4.0 and e.hp == e.max_hp:
		var front_center := Vector2.ZERO
		for f: Enemy in front:
			front_center += f.pos()
		front_center /= front.size()
		e.tactical_goal = front_center + (front_center - destination).normalized() * 5.0
		e.tactical_speed = minf(e.speed, 2.1)
	elif e.tactical_role == "support":
		if not front.is_empty() and e.pos().distance_to(destination) > e.reach:
			var front_center := Vector2.ZERO
			for f: Enemy in front:
				front_center += f.pos()
			front_center /= front.size()
			e.tactical_goal = front_center + (front_center - destination).normalized() * 4.0
			e.tactical_speed = minf(e.speed, 2.1)
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
