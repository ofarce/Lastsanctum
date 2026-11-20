class_name SanctumLayout
## Placement du décor du Temple (planche sanctum-decor-propositions.html) : cinq familles semées dans les galeries
## du premier biome, le mobilier des salles à thème (TerrainState.theme_rooms) et quelques vestiges posés à la
## main le long de la paroi nord de la grotte de départ. Pur et déterministe (graine des galeries).
## Rien ne bloque le passage : seules les cases d'eau de la citerne sont infranchissables (TerrainState).
##
## Résultat : {props, braziers, rooms}
##   props     {k (sprite de SanctumArt), x, z, flip, ground (à plat, sous les unités), start (grotte de départ),
##              dy (décalage vertical en pixels), alpha, light {r, rgb, glow}, brazier (indice), room (indice),
##              role ("chest", "stand", "lectern"), flame ("candle")}
##   braziers  {x, z} : éteints tant qu'aucune unité n'est passée à côté (Sanctum.tick)
##   rooms     {kind, x, z, half, focus: Vector2} : point d'interaction de la salle

const CHUNK := 32.0
## Part des chunks de galerie qui reçoivent du décor, et taille des plaques d'une même famille.
const CHUNK_RATE := 0.9
const THEME_PATCH := 96.0
const THEMES := ["colonnade", "braziers", "roots", "siege", "quartz"]
const SHROOM_LIGHT := Color8(220, 240, 205)
const WHITE_LIGHT := Color8(230, 232, 240)
const GLYPH_LIGHT := Color8(92, 232, 255)
const WATER_LIGHT := Color8(207, 232, 230)


static func build(state: TerrainState) -> Dictionary:
	var out := {"props": [], "braziers": [], "rooms": []}
	_start_cave(out)
	if state.groves:
		_rooms(state, out)
		_galleries(state, out)
	return out


static func _add(out: Dictionary, k: String, x: float, z: float, opt := {}) -> Dictionary:
	var e := {"k": k, "x": x, "z": z}
	e.merge(opt)
	out["props"].append(e)
	return e


static func _brazier(out: Dictionary, x: float, z: float, opt := {}) -> void:
	var o := {"brazier": out["braziers"].size()}
	o.merge(opt)
	out["braziers"].append({"x": x, "z": z})
	_add(out, "brazier", x, z, o)


static func _quartz_light(big: bool) -> Dictionary:
	return {"r": 7.0 if big else 5.0, "rgb": ArtStyle.QUARTZ_LIGHT, "glow": 0.14}


# ---------------------------------------------------------------- Grotte de départ

## Colonnes, stalagmites et gravats au pied de la paroi nord (hors de l'aplomb de la capsule), deux braseros,
## quatre dalles gravées. Le décor est masqué quand un bâtiment est posé dessus (SanctumView).
static func _start_cave(out: Dictionary) -> void:
	var s := {"start": true}
	for ci in range(-22, 22):
		var x := ci * 4.0 + 2.0
		if absf(x) < 14.0:
			continue
		var foot := _cave_north_foot(x)
		if foot == INF:
			continue
		var h := Rng.hash3(ci, 11, 0x5a2c)
		var z := foot + 1.0
		if ci == -5 or ci == 4:
			_brazier(out, x, foot + 1.6, s)
		elif h < 0.2:
			_add(out, "column", x, z, s)
		elif h < 0.32:
			_add(out, "column_broken", x, z, s)
			_add(out, "rubble_a", x + 1.6, z + 1.0, s)
		elif h < 0.42:
			_add(out, "stalag_m" if h < 0.37 else "stalag_l", x, z, s)
		elif h < 0.5:
			_add(out, "rubble_b", x, z + 0.4, s)
		elif h < 0.55:
			_add(out, "drum", x, z + 0.8, s)
	var k := 0
	for p: Vector2 in [Vector2(-20, -140), Vector2(20, -140), Vector2(-32, -122), Vector2(32, -122)]:
		_add(out, "slab_%d" % (k % 3), p.x, p.y, {"start": true, "ground": true})
		k += 1


## Pied de la paroi nord de la salle à l'aplomb de x (première case de sol en venant du nord), ou INF.
static func _cave_north_foot(x: float) -> float:
	var z := -202.0
	while z < -110.0:
		if CaveShape.in_cave(x, z):
			return floorf(z / 4.0) * 4.0
		z += 4.0
	return INF


# ---------------------------------------------------------------- Salles à thème

static func _rooms(state: TerrainState, out: Dictionary) -> void:
	for i in state.theme_rooms.size():
		var room: Dictionary = state.theme_rooms[i]
		var c := Vector2(room["x"], room["z"])
		var half: Vector2i = room["half"]
		var north := c.y - half.y * 4.0 - 2.0
		# Coordonnées de la planche (vignette 176 × 128, salle centrée en 88, 70) ramenées à la salle du jeu.
		var P := func(px: float, py: float) -> Vector2: return Vector2(c.x + (px - 88.0) / 8.0 * 1.1, c.y + (py - 70.0) / 8.0 * 1.2)
		# Contre la paroi nord, à `off` unités du pied du mur.
		var N := func(px: float, off: float) -> Vector2: return Vector2(c.x + (px - 88.0) / 8.0 * 1.1, north + off)
		var put := func(k: String, p: Vector2, opt := {}) -> void: _add(out, k, p.x, p.y, opt)
		var focus := c
		match room["kind"]:
			"crypt":
				put.call("dais", P.call(88, 80), {"ground": true})
				for px: float in [44.0, 88.0]:
					put.call("sarco", P.call(px, 54))
				put.call("sarco_open", P.call(128, 54))
				put.call("bones_a", P.call(146, 62))
				for px: float in [64.0, 112.0]:
					put.call("lamp", P.call(px, 70), {"light": {"r": 6.5, "rgb": ArtStyle.QUARTZ_LIGHT, "glow": 0.16}})
				focus = P.call(88, 83)
				put.call("chest", focus, {"room": i, "role": "chest", "light": {"r": 4.0, "rgb": GLYPH_LIGHT, "glow": 0.12}})
				put.call("sarco", P.call(44, 100))
				put.call("sarco", P.call(132, 100))
				put.call("rubble_a", P.call(30, 70))
			"library":
				put.call("shelf_w", N.call(47, 0.6))
				put.call("shelf_n", N.call(86, 0.6))
				put.call("shelf_w", N.call(125, 0.6))
				put.call("column_marble", P.call(24, 98))
				put.call("column_marble_broken", P.call(150, 70))
				for n in 11:
					var sp: Vector2 = P.call(40.0 + Rng.hash3(n, 3, i) * 70.0, 60.0 + Rng.hash3(n, 5, i) * 40.0)
					put.call(["scroll_a", "scroll_b", "scroll_c"][n % 3], sp, {"ground": true})
				put.call("toppled", P.call(54, 86))
				focus = P.call(96, 78)
				put.call("lectern", focus, {"room": i, "role": "lectern", "light": {"r": 7.0, "rgb": WHITE_LIGHT, "glow": 0.18}})
				put.call("rubble_b", P.call(140, 96))
			"armory":
				put.call("sand", P.call(88, 78), {"ground": true, "alpha": 0.8})
				for px: float in [76.0, 88.0, 100.0]:
					put.call("wall_shield", N.call(px, 0.05), {"dy": -10})
				put.call("rack", N.call(44, 0.7))
				put.call("rack", N.call(130, 0.7))
				put.call("crate", P.call(28, 62))
				focus = P.call(146, 66)
				put.call("stand", focus, {"room": i, "role": "stand"})
				var b1: Vector2 = P.call(34, 92)
				var b2: Vector2 = P.call(142, 96)
				_brazier(out, b1.x, b1.y)
				put.call("dummy", P.call(88, 82))
				_brazier(out, b2.x, b2.y)
				put.call("sword", P.call(66, 96))
			"oratory":
				put.call("moss_a", P.call(54, 70), {"ground": true})
				put.call("moss_b", P.call(124, 96), {"ground": true})
				var st: Vector2 = N.call(88, 1.4)
				put.call("statue", st)
				for o: Vector2 in [Vector2(-1.9, 0.3), Vector2(-1.3, 0.8), Vector2(1.4, 0.7), Vector2(2.0, 0.2)]:
					put.call("candle", st + o, {"flame": "candle"})
				put.call("menhir_a", P.call(52, 66))
				put.call("menhir_b", P.call(124, 66))
				focus = P.call(88, 78)
				put.call("basin", focus, {"ground": true, "room": i, "role": "basin", "light": {"r": 6.5, "rgb": WATER_LIGHT, "glow": 0.14}})
				put.call("menhir_c", P.call(46, 98))
				put.call("menhir_a", P.call(130, 100))
				put.call("tuft_a", P.call(60, 100))
				put.call("tuft_b", P.call(118, 70))
			"cistern":
				for sx: float in [-7.0, 7.0]:
					put.call("column", c + Vector2(sx, -3.0))
				put.call("column_broken", c + Vector2(-7.0, 5.0))
				put.call("column", c + Vector2(7.0, 5.0))
				put.call("wheel", c + Vector2(0.0, 0.6))
				put.call("slab_lit", c + Vector2(0.0, 4.0), {"ground": true, "light": {"r": 3.5, "rgb": ArtStyle.QUARTZ_LIGHT, "glow": 0.1}})
				put.call("quartz_s", Vector2(c.x - 12.0, north + 1.2), {"light": _quartz_light(false)})
				put.call("quartz_m", Vector2(c.x + 12.0, north + 1.2), {"light": _quartz_light(false)})
		out["rooms"].append({"kind": room["kind"], "x": c.x, "z": c.y, "half": half, "focus": focus})


# ---------------------------------------------------------------- Galeries

static func _galleries(state: TerrainState, out: Dictionary) -> void:
	var r := Rng.new(state.seed ^ 0xdec2)
	var occupied := {}
	var z_north := maxf(CaveShape.WORLD_Z0, TerrainState.frontier_z())
	var cz := floorf(z_north / CHUNK) * CHUNK
	while cz < -70.0:
		var cx := CaveShape.WORLD_X0
		while cx < CaveShape.WORLD_X1:
			var roll := r.next()
			var mix := r.next()
			var count := 3 + floori(r.next() * 4.0)
			if roll < CHUNK_RATE and Biomes.index_at(cz + CHUNK / 2.0) == 0:
				var theme := _theme(state.seed, cx, cz, mix)
				for g in mini(count, 3) if theme == "braziers" else count:
					_group(state, r, out, occupied, theme, cx, cz)
			cx += CHUNK
		cz += CHUNK


## Famille du chunk : la même sur une plaque de THEME_PATCH unités, un chunk sur quatre tiré à part.
## Les racines dominent près du flanc sud (la jungle s'infiltre) et disparaissent vers le nord.
static func _theme(map_seed: int, cx: float, cz: float, mix: float) -> String:
	var depth := Biomes.depth(0, cz + CHUNK / 2.0)
	var weights := [1.0, 0.7, 3.2 * pow(1.0 - depth, 2.0), 1.0, 1.0]
	var total := 0.0
	for w: float in weights:
		total += w
	var h := Rng.hash3(floori(cx / THEME_PATCH), floori(cz / THEME_PATCH), map_seed ^ 0x7e3)
	if mix < 0.25:
		h = mix * 4.0
	var pick := h * total
	for k in weights.size():
		pick -= weights[k]
		if pick <= 0.0:
			return THEMES[k]
	return THEMES[4]


static func _ok(state: TerrainState, x: float, z: float) -> bool:
	if not AmbienceLayout._free(state, x, z) or Biomes.index_at(z) != 0 or TerrainState.in_eye_room(x, z, 4.0):
		return false
	for room: Dictionary in state.theme_rooms:
		var half: Vector2i = room["half"]
		if absf(x - float(room["x"])) < half.x * 4.0 + 5.0 and absf(z - float(room["z"])) < half.y * 4.0 + 5.0:
			return false
	for p: Dictionary in state.portals:
		if Vector2(x - float(p["x"]), z - float(p["z"])).length() < TerrainState.PYLON_CHAMBER + 2.0:
			return false
	return true


## Un groupe d'objets : adossé à une paroi nord ou posé au milieu du passage.
static func _group(state: TerrainState, r: Rng, out: Dictionary, occupied: Dictionary, theme: String, cx: float, cz: float) -> void:
	var wall := r.next() < 0.55
	var h := r.next()
	var flip := r.next() < 0.5
	var p: Vector2
	if wall:
		p = AmbienceLayout._foot(state, AmbienceLayout._spot(state, r, cx, cz,
			func(s: TerrainState, x: float, z: float) -> bool: return AmbienceLayout._under_wall(s, x, z) and _ok(s, x, z)))
	else:
		p = AmbienceLayout._spot(state, r, cx, cz, func(s: TerrainState, x: float, z: float) -> bool: return _ok(s, x, z))
	if p == Vector2.INF:
		return
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for o: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT]:
		if occupied.has(key + o):
			return
	occupied[key] = true
	var f := {"flip": flip}
	var g := {"flip": flip, "ground": true}
	# Compagnon posé à côté : seulement s'il reste dans la galerie.
	var side := func(k: String, dx: float, dz: float, opt: Dictionary) -> void:
		if state.is_gallery(p.x + dx, p.y + dz):
			_add(out, k, p.x + dx, p.y + dz, opt)
	match theme:
		"colonnade":
			if wall:
				if h < 0.55:
					_add(out, "column", p.x, p.y + 1.0, f)
				else:
					_add(out, "column_broken" if h < 0.85 else "column_stump", p.x, p.y + 1.0, f)
					side.call("rubble_a", 1.6, 2.0, f)
					if h > 0.7:
						side.call("drum", -2.2, 2.8, f)
			elif h < 0.5:
				_add(out, "slab_%d" % floori(h * 6.0), p.x, p.y, {"ground": true})
			elif h < 0.8:
				_add(out, "rubble_b", p.x, p.y, f)
			else:
				_add(out, "drum", p.x, p.y, f)
		"braziers":
			if wall:
				_brazier(out, p.x, p.y + 1.6)
			elif h < 0.5:
				_add(out, "slab_%d" % floori(h * 6.0), p.x, p.y, {"ground": true})
			else:
				_add(out, "rubble_a", p.x, p.y, f)
		"roots":
			if wall:
				_add(out, "root_a" if h < 0.5 else "root_b", p.x, p.y - 0.3, g)
				side.call("tuft_a", 1.2, 1.6, f)
			else:
				_add(out, "moss_a" if h < 0.5 else "moss_b", p.x, p.y, g)
				if h < 0.3:
					_add(out, "shrooms_a" if h < 0.15 else "shrooms_b", p.x, p.y + 0.4, {"flip": flip, "light": {"r": 4.5, "rgb": SHROOM_LIGHT, "glow": 0.1}})
				elif h < 0.6:
					_add(out, "tuft_b", p.x, p.y + 0.3, f)
				elif h < 0.8:
					side.call("puddle", 2.4, 0.6, {"ground": true})
		"siege":
			if wall:
				if h < 0.35:
					_add(out, "banner", p.x, p.y + 0.05, {"dy": -22})
				else:
					_add(out, "crate", p.x, p.y + 1.2, f)
					if h > 0.65:
						side.call("crate_broken", 1.9, 1.8, f)
			elif h < 0.35:
				_add(out, "bones_a" if h < 0.18 else "bones_b", p.x, p.y, f)
			elif h < 0.6:
				_add(out, "sword" if h < 0.45 else "sword_rust", p.x, p.y, f)
			elif h < 0.8:
				_add(out, "shield" if h < 0.7 else "shield_rust", p.x, p.y, f)
			elif h < 0.9:
				_add(out, "spear", p.x, p.y, f)
			else:
				_add(out, "crate_broken", p.x, p.y, f)
		"quartz":
			if wall:
				if h < 0.45:
					_add(out, "quartz_l" if h < 0.15 else "quartz_m", p.x, p.y + 1.0, {"flip": flip, "light": _quartz_light(h < 0.15)})
				else:
					_add(out, "stalag_l" if h < 0.7 else "stalag_m", p.x, p.y + 0.9, f)
					side.call("stalag_s", 1.4, 1.5, f)
			elif h < 0.35:
				_add(out, "boulder" if h < 0.2 else "boulder_s", p.x, p.y, f)
				side.call("rubble_b", 1.8, 0.6, f)
			elif h < 0.65:
				_add(out, "stalag_m" if h < 0.5 else "stalag_s", p.x, p.y, f)
			elif h < 0.8:
				_add(out, "quartz_s", p.x, p.y, {"flip": flip, "light": _quartz_light(false)})
			else:
				_add(out, "puddle", p.x, p.y, {"ground": true})
