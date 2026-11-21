extends RefCounted
## Récolte lisible des esprits (planches/recolte-effets-propositions.html, choix « 1 + 3 + saut » du 2026-11-21).
## Entre deux objets (Simulation.adept_mining_seconds : 2 s pour Aether, 4 s sinon), la récolte est découpée en coups
## visuels d'environ STROKE secondes, calés sur la boucle de travail des esprits (24 images à 24 i/s). Chaque coup
## pose un effet `harvest_hit` (éclats, poussière, fissures du bloc, feuille du bosquet, tressaillement du filon et
## du bosquet) ; le dernier coup est celui qui donne l'objet. Rien d'ici ne touche aux règles : un esprit n'épuise
## ni bloc, ni filon, ni bosquet.

const STROKE := 1.0


## Nombre de coups visuels par objet.
static func strokes(interval: float) -> int:
	return maxi(1, roundi(interval / STROKE))


## Point frappé sur la case `key`, vu depuis `from` (position de l'esprit) : {x, z, h (hauteur, unités de monde),
## node ("block" | "lode" | "grove"), origin (case d'origine du filon ou du bosquet, sinon la case)}.
static func target(st: TerrainState, key: Vector2i, from: Vector2) -> Dictionary:
	var lode := st.lode_cells.has(key)
	if lode or st.grove_cells.has(key):
		var o: Vector2i = st.lode_cells[key] if lode else st.grove_cells[key]
		var r := Rect2(o.x * 4.0, o.y * 4.0, 8.0, 8.0)
		var p := Vector2(clampf(from.x, r.position.x, r.end.x), clampf(from.y, r.position.y, r.end.y))
		p = p.move_toward(r.get_center(), 1.6)
		return {"x": p.x, "z": p.y, "h": 1.6 if lode else 1.4, "node": "lode" if lode else "grove", "origin": o}
	var c := Rect2(key.x * 4.0, key.y * 4.0, 4.0, 4.0)
	var q := Vector2(clampf(from.x, c.position.x + 0.6, c.end.x - 0.6), clampf(from.y, c.position.y, c.end.y))
	# Par le sud, l'esprit frappe la paroi dessinée (face5, 45 px au-dessus du bord sud) ; ailleurs, le bord du bloc.
	var south := from.y >= c.end.y - 0.2
	return {"x": q.x, "z": q.y, "h": 2.0 if south else 0.6, "node": "block", "origin": key}


## Le travail de `u` sur `key` passe de `before` à `after` secondes (avant la remise à zéro de l'objet) : pose un
## effet par coup franchi. Renvoie le point frappé, que l'objet reprend pour son saut.
static func work(u: Unit, st: TerrainState, key: Vector2i, item: String, before: float, after: float, interval: float) -> Dictionary:
	var t := target(st, key, u.pos())
	var n := strokes(interval)
	var period := interval / n
	var done := floori(before / period + 1e-6)
	var reached := mini(n, floori(after / period + 1e-6))
	for k in range(done + 1, reached + 1):
		var leaf: bool = t["node"] == "grove" and k % 2 == 1
		var e := t.duplicate()
		e.merge({"type": "harvest_hit", "item": item, "k": k, "n": n, "period": period,
			"dir": 1.0 if t["x"] >= u.x else -1.0, "seed": (int(GameState.sim_time * 60.0) * 31 + k * 7 + key.x * 13 + key.y) & 0xFFFF,
			"age": 0.0, "duration": 1.9 if leaf else (period + 0.05 if t["node"] == "block" else 0.75)})
		GameState.effects.append(e)
	return t
