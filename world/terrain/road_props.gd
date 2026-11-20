class_name RoadProps
extends RefCounted
## Objets le long des chemins (fonction de la graine) : panneaux aux croisements, épaves de chariots,
## bornes de pierre, restes du Credo près de l'arrivée des vagues, petits détails, et un poste abandonné
## à un croisement, et un petit dépôt du Credo au bout nord de chaque pont écarté. Entrées : {k (type), x, z,
## flip} ; « cache » (cart, outpost, bridge) marque les objets à fouiller (Loot.place_caches).

const OUTPOST_R := 7.0


static func place(road: Road, map_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := Rng.new(map_seed ^ 0x9209)
	var side_of := func(z: float, s: float, off: float) -> Vector2:
		return Vector2(road.main_x(z) + s * (Road.MAIN_HALF + off), z)
	# Panneaux aux croisements.
	for j in road.junctions:
		var s: float = -float(j["side"])
		out.append({"k": "sign", "x": float(j["x"]) + s * (Road.MAIN_HALF + 1.4), "z": float(j["z"]) - Road.BRANCH_HALF - 1.2, "flip": s < 0.0})
	# Poste abandonné, au nord du chemin secondaire, à un croisement tiré au sort.
	if not road.junctions.is_empty():
		var j: Dictionary = road.junctions[floori(r.next() * road.junctions.size())]
		var s: float = float(j["side"])
		var c := Vector2(float(j["x"]) + s * 17.0, road.branch_z(j, float(j["x"]) + s * 17.0) - Road.BRANCH_HALF - OUTPOST_R - 0.5)
		out.append({"k": "outpost", "x": c.x, "z": c.y, "flip": false})
		for k in 7:
			var a := PI * 0.15 + k * PI * 0.12
			if k == 3:
				continue
			out.append({"k": "palisade" if k % 3 else "palisade_broken", "x": c.x + cos(a + PI) * OUTPOST_R, "z": c.y - sin(a) * OUTPOST_R * 0.8, "flip": k > 3})
		out.append({"k": "campfire", "x": c.x, "z": c.y + 1.0, "flip": false})
		out.append({"k": "tent", "x": c.x + 3.2 * s, "z": c.y - 1.5, "flip": s < 0.0})
		out.append({"k": "crate", "x": c.x - 3.0 * s, "z": c.y - 0.5, "flip": false, "cache": "outpost"})
		out.append({"k": "crate", "x": c.x - 3.8 * s, "z": c.y + 0.6, "flip": true})
		out.append({"k": "barrel", "x": c.x - 2.2 * s, "z": c.y + 2.2, "flip": false})
	# Épaves : près de l'arrivée des vagues, sur la route du nord, sur un chemin secondaire.
	var p := side_of.call(50.0 + r.next() * 8.0, 1.0, 1.8) as Vector2
	out.append({"k": "cart", "x": p.x, "z": p.y, "flip": true, "cache": "cart"})
	p = side_of.call(-30.0 + r.next() * 20.0, -1.0, 2.0)
	out.append({"k": "cart", "x": p.x, "z": p.y, "flip": false, "cache": "cart"})
	out.append({"k": "wheel", "x": p.x - 2.4, "z": p.y + 1.0, "flip": false})
	if not road.junctions.is_empty():
		var j: Dictionary = road.junctions[0]
		var x := lerpf(float(j["x"]), float(j["bx"]), 0.55)
		out.append({"k": "cart", "x": x, "z": road.branch_z(j, x) + Road.BRANCH_HALF + 1.6, "flip": true, "cache": "cart"})
		out.append({"k": "crate", "x": x + 2.5, "z": road.branch_z(j, x) + Road.BRANCH_HALF + 2.4, "flip": false})
	# Dépôts du Credo au bout nord des ponts écartés : une raison d'aller voir les ponts lointains.
	if road.river != null:
		for b in road.river.bridges:
			var bx: float = b["x"]
			if absf(bx) < 20.0:
				continue
			var s := 1.0 if bx > 0.0 else -1.0
			var c := Vector2(bx + s * (River.DECK_HALF + 3.0), float(b["z0"]) - 2.5)
			out.append({"k": "crate", "x": c.x, "z": c.y, "flip": s < 0.0, "cache": "bridge"})
			out.append({"k": "barrel", "x": c.x + s * 1.6, "z": c.y + 0.7, "flip": false})
			out.append({"k": "banner", "x": c.x + s * 0.4, "z": c.y - 1.4, "flip": s < 0.0})
	# Bornes de pierre le long de la route principale.
	var z := -50.0
	var flip := 1.0
	while z < 70.0:
		if absf(z - road.bridge_z) > 14.0:
			var q := side_of.call(z, flip, 0.9) as Vector2
			out.append({"k": "milestone", "x": q.x, "z": q.y, "flip": flip < 0.0})
		z += 30.0
		flip = -flip
	# Restes du Credo, près de l'arrivée des vagues.
	for k in 3:
		var q := side_of.call(58.0 + r.next() * 9.0, -1.0 if k % 2 else 1.0, 1.0 + r.next() * 3.0) as Vector2
		out.append({"k": ["banner", "helmet", "spear"][k], "x": q.x, "z": q.y, "flip": r.next() < 0.5})
	# Petits détails.
	for k in 7:
		var zz := -45.0 + r.next() * 110.0
		if absf(zz - road.bridge_z) < 12.0:
			continue
		var kind: String = ["stones", "stones", "stones", "basket", "skull", "stones", "crate"][k]
		var q := side_of.call(zz, 1.0 if r.next() < 0.5 else -1.0, 1.0 + r.next() * 2.5) as Vector2
		out.append({"k": kind, "x": q.x, "z": q.y, "flip": r.next() < 0.5})
	return out
