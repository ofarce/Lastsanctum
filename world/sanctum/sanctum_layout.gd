class_name SanctumLayout
## Placement du décor du Temple (planche sanctum-decor-propositions.html) : cinq familles semées dans les galeries
## du premier biome, le mobilier des salles à thème (TerrainState.theme_rooms) et quelques vestiges posés à la
## main le long de la paroi nord de la grotte de départ. Pur et déterministe (graine des galeries).
## Rien ne bloque le passage : seules les cases d'eau de la citerne sont infranchissables (TerrainState).
##
## Résultat : {props, braziers, rooms}
##   props     {k (sprite de SanctumArt), x, z, flip, ground (à plat, sous les unités), start (grotte de départ),
##              dy (décalage vertical en pixels), alpha, light {r, rgb, glow}, brazier (indice), room (indice),
##              role ("chest", "stand", "lectern"), flame ("candle"), torch ("n" paroi nord, "w"/"e" rebord ouest/est)}
##   braziers  {x, z} : éteints tant qu'aucune unité n'est passée à côté (Sanctum.tick)
##   rooms     {kind, x, z, half, focus: Vector2} : point d'interaction de la salle

const CHUNK := 32.0
## Part des chunks de galerie qui reçoivent du décor, et taille des plaques d'une même famille.
const CHUNK_RATE := 0.9
const THEME_PATCH := 96.0
const THEMES := ["colonnade", "braziers", "roots", "siege", "quartz", "cloister", "niches", "cells", "refectory", "bell", "ossuary"]
## Monastère (planche couloirs-boss-decor-propositions.html, choix « tout » du 2026-11-24) : décalages des flammes
## des candélabres depuis leur pied, en pixels, et lumières des cierges et des lampes.
const CANDELABRA := [Vector2(-4, -15), Vector2(0, -15), Vector2(4, -15)]
const CANDLE_LIGHT := {"r": 6.0, "rgb": Color8(255, 176, 92), "glow": 0.14}
const NICHE_LIGHT := {"r": 4.0, "rgb": Color8(255, 176, 92), "glow": 0.11}
const TROPHY := {"mb1": "mitre", "mb2": "veil", "oeil": "skull_big",
	"mb1@veines": "o_tr_port", "mb2@veines": "o_tr_helm", "gorge": "o_tr_ring"}
const SHROOM_LIGHT := Color8(220, 240, 205)
const WHITE_LIGHT := Color8(230, 232, 240)
const GLYPH_LIGHT := Color8(92, 232, 255)
const WATER_LIGHT := Color8(207, 232, 230)


static func build(state: TerrainState) -> Dictionary:
	var out := {"props": [], "braziers": [], "rooms": [], "bells": {}}
	_start_cave(out)
	if state.groves:
		_rooms(state, out)
		_galleries(state, out)
		_arenas(state, out)
		_veines(state, out)
		_forges(state, out)
	_corridor_torches(state, out)
	_veines_fanals(state, out)
	_keep_clear(state, out)
	return out


## Rien de debout sur les repères de quartier (stèle et arche, QuarterMarks.marks), ni sur les portes des tunnels et
## leurs ruines (CaveDoors) : le décor des salles-seuils posait des bancs sous l'arche. Les braseros (indexés) et le
## décor à plat restent.
static func _keep_clear(state: TerrainState, out: Dictionary) -> void:
	if state.temple_layout.is_empty():
		return
	var zones: Array[Rect2] = []
	for m: Dictionary in QuarterMarks.marks(state):
		var half := Vector2(float(m.get("span", 14.0)) * 0.5 + 3.0, 5.0) if m["kind"] == "arch" else Vector2(4.0, 4.0)
		zones.append(Rect2(Vector2(m["x"], m["z"]) - Vector2(half.x, half.y + 2.0), half * 2.0 + Vector2(0.0, 2.0)))
	var gates: Array[Dictionary] = []
	for i in CaveDoors.MOUTHS.size():
		var md: Dictionary = CaveDoors.MOUTHS[i]
		gates.append({"a": md["a"], "b": md["b"]})
	gates.append_array(CaveDoors.ruins(state))
	for g: Dictionary in gates:
		var r := Rect2(g["a"], Vector2.ZERO).expand(g["b"])
		zones.append(r.grow(9.0))
	if zones.is_empty():
		return
	var kept: Array = []
	for e: Dictionary in out["props"]:
		var p := Vector2(float(e["x"]), float(e["z"]))
		var hit := false
		if not e.get("ground", false) and not e.has("brazier"):
			for z: Rect2 in zones:
				if z.has_point(p):
					hit = true
					break
		if not hit:
			kept.append(e)
	out["props"] = kept


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
			# Salles oubliées (planches/salles-oubliees-decor-propositions.html, R1 et R3).
			"vcistern":
				for sx: float in [-7.0, 7.0]:
					put.call("o_col", c + Vector2(sx, -3.0))
				put.call("o_col_broken", c + Vector2(-7.0, 5.0))
				put.call("o_col", c + Vector2(7.0, 5.0))
				focus = c + Vector2(0.0, 0.6)
				put.call("o_pump", focus, {"room": i, "role": "pump"})
				var nw := AmbienceLayout._north_wall(state, c)
				if nw != Vector2.INF:
					put.call("o_seep", nw + Vector2(-6.0, 0.05))
					put.call("o_seep_b", nw + Vector2(5.0, 0.05))
					put.call("o_stal", nw + Vector2(1.0, 0.05))
				put.call("shrooms_a", c + Vector2(-11.0, 4.0), {"light": {"r": 4.5, "rgb": SHROOM_LIGHT, "glow": 0.1}})
				put.call("rubble_a", c + Vector2(11.0, 5.0))
			"vworkshop":
				put.call("o_bench", P.call(47, 60))
				put.call("o_anvil", P.call(84, 62))
				put.call("o_crucible", P.call(110, 60))
				put.call("rack", P.call(140, 62))
				put.call("crate", P.call(40, 96))
				put.call("crate_broken", P.call(54, 98))
				put.call("o_cart", P.call(104, 100))
				focus = P.call(130, 96)
				put.call("o_ingots", focus, {"room": i, "role": "ingots", "light": {"r": 4.0, "rgb": Color8(255, 176, 92), "glow": 0.08}})
				var nw := AmbienceLayout._north_wall(state, c)
				if nw != Vector2.INF:
					put.call("o_fanal", nw + Vector2(-4.0, 0.05), {"light": FANAL_LIGHT})
					put.call("o_pipe", nw + Vector2(6.0, 0.05))
			# Forges mortes (planches/forges-mortes-decor-propositions.html, R1, R3 et R4) : salles 7 × 5 cases.
			"ftrempe", "fspirits", "fstore":
				# Pièce murale contre la paroi nord de la salle, seulement là où la paroi existe.
				var wall_put := func(k: String, px: float, opt := {}) -> void:
					var q: Vector2 = N.call(px, 0.05)
					if AmbienceLayout._under_wall(state, q.x, q.y + 0.5):
						put.call(k, q, opt)
				match room["kind"]:
					"ftrempe":
						put.call("f_blades", c + Vector2(-5.5, -2.5))
						put.call("f_blades", c + Vector2(5.0, 1.5), {"flip": true})
						wall_put.call("f_furnace", 32.0)
						wall_put.call("f_rust", 120.0)
						put.call("rack", P.call(146, 62))
						put.call("f_moulds_stack", P.call(30, 100))
						put.call("f_anvil", P.call(146, 100))
						put.call("f_slag_b", P.call(122, 104))
					"fspirits":
						put.call("brazier", c + Vector2(0.0, 1.0))
						var spots := [Vector2(54, 62), Vector2(122, 62), Vector2(54, 100), Vector2(122, 100)]
						for n in spots.size():
							var sp: Vector2 = spots[n]
							put.call("f_chained", P.call(sp.x, sp.y), {"flip": sp.x > 88.0, "room": i, "role": "chain", "chain": n})
						put.call("f_moulds", P.call(80, 48))
						put.call("f_scrap", P.call(148, 82))
						put.call("f_slag", P.call(26, 82))
						wall_put.call("f_furnace", 40.0)
						wall_put.call("f_furnace_ember", 136.0, {"light": EMBER_LIGHT})
					"fstore":
						wall_put.call("f_beam", 88.0)
						wall_put.call("f_hoist_pot", 72.0)
						wall_put.call("f_hoist_hook", 104.0)
						put.call("f_moulds_stack", P.call(28, 60))
						put.call("f_moulds_stack", P.call(140, 60), {"flip": true})
						focus = P.call(70, 92)
						put.call("f_bars_big", focus, {"room": i, "role": "store", "done_k": "f_bars"})
						put.call("f_bars", P.call(120, 96))
						put.call("crate", P.call(92, 82))
						put.call("crate_broken", P.call(106, 86))
						put.call("rack", P.call(36, 100))
						put.call("f_scrap", P.call(148, 100))
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
				var q := _quarter(state, cx, cz)
				var theme := _theme(state.seed, cx, cz, mix, q)
				# Une seule cloche tombée par quartier : un repère n'en est un que s'il est unique.
				if theme == "bell":
					if out["bells"].has(q):
						theme = "niches"
					else:
						out["bells"][q] = true
				for g in mini(count, 3) if theme == "braziers" else count:
					_group(state, r, out, occupied, theme, cx, cz)
			cx += CHUNK
		cz += CHUNK


## Famille du chunk : la même sur une plaque de THEME_PATCH unités, un chunk sur quatre tiré à part.
## Les racines dominent près du flanc sud (la jungle s'infiltre) et disparaissent vers le nord.
## Quartier du Temple en salles sous le chunk (« A », « B », « C », « R » route du boss, "" ailleurs).
static func _quarter(state: TerrainState, cx: float, cz: float) -> String:
	if state.temple_layout.is_empty():
		return ""
	return QuarterMarks.quarter_at(state, Vector2(cx + CHUNK / 2.0, cz + CHUNK / 2.0))


## Famille du chunk : la même sur une plaque de THEME_PATCH unités, un chunk sur quatre tiré à part.
## Les racines dominent près du flanc sud (la jungle s'infiltre) et disparaissent vers le nord. Le monastère domine :
## cellules et réfectoire surtout dans le quartier C (là où vivaient les moines), ossuaire sur la route de l'Œil.
static func _theme(map_seed: int, cx: float, cz: float, mix: float, q := "") -> String:
	var depth := Biomes.depth(0, cz + CHUNK / 2.0)
	var home := 2.0 if q == "C" else 1.0
	var weights := [0.5, 0.35, 1.6 * pow(1.0 - depth, 2.0), 0.5, 0.5,
		1.2, 1.2, 0.6 * home, 0.45 * home, 0.4, 0.4 * (4.0 if q == "R" else 1.0)]
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
	return THEMES[THEMES.size() - 1]


static func _ok(state: TerrainState, x: float, z: float) -> bool:
	if not AmbienceLayout._free(state, x, z) or Biomes.index_at(z) != 0 or TerrainState.in_eye_room(x, z, 4.0):
		return false
	if state.temple_room(x, z).get("kind", "") in ["miniboss", "boss"]:
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
		"cloister":
			if wall:
				_add(out, "arcade", p.x, p.y + 0.05)
			elif h < 0.15:
				_add(out, "well", p.x, p.y, f)
			elif h < 0.65:
				_add(out, "herbs" if h < 0.4 else "herbs_b", p.x, p.y, {"ground": true})
				side.call("tuft_a", 1.8, 0.8, f)
			else:
				_add(out, "tuft_b", p.x, p.y, f)
		"niches":
			if wall:
				if h < 0.6:
					_add(out, "niche_lit", p.x, p.y + 0.05, {"flames": [Vector2.ZERO], "light": NICHE_LIGHT})
				else:
					_add(out, "niche", p.x, p.y + 0.05)
				side.call("offering", 0.4, 1.0, f)
			elif h < 0.5:
				_add(out, "offering", p.x, p.y, f)
			else:
				_add(out, "slab_%d" % floori(h * 6.0 - 3.0), p.x, p.y, {"ground": true})
		"cells":
			if wall:
				_add(out, "celldoor_broken" if h < 0.4 else "celldoor", p.x, p.y + 0.05, f)
				if h > 0.5:
					side.call(["pallet", "jug", "stool"][floori(h * 30.0) % 3], 1.6, 1.8, f)
			else:
				_add(out, ["pallet", "jug", "stool", "stool_top", "bowl"][floori(h * 5.0)], p.x, p.y, f)
		"refectory":
			if wall:
				if state.is_gallery(p.x - 4.5, p.y + 1.8) and state.is_gallery(p.x + 4.5, p.y + 1.8):
					_add(out, "table", p.x, p.y + 1.8, f)
				else:
					_add(out, "table_s", p.x, p.y + 1.8, f)
			elif h < 0.3:
				_add(out, "cauldron", p.x, p.y, f)
			else:
				_add(out, ["jug", "bowl", "stool_top"][floori(h * 30.0) % 3], p.x, p.y, f)
		"bell":
			if wall:
				# Accrochée par le haut de la paroi : l'ancre du sprite est son point d'attache, il se balance autour.
				_add(out, "rope_l" if h < 0.5 else "rope_s", p.x, p.y - 1.5, {"anim": "swing"})
			elif not out["bells"].get("placed_" + str(floori(cx / THEME_PATCH)) + "_" + str(floori(cz / THEME_PATCH)), false):
				out["bells"]["placed_" + str(floori(cx / THEME_PATCH)) + "_" + str(floori(cz / THEME_PATCH))] = true
				_add(out, "bell", p.x, p.y, f)
				side.call("timber", -3.0, 0.8, f)
				side.call("rubble_b", 2.6, 1.2, f)
			else:
				_add(out, "timber" if h < 0.5 else "rubble_a", p.x, p.y, f)
		"ossuary":
			if wall:
				_add(out, "ossuary" if h < 0.5 else "ossuary_b", p.x, p.y + 0.05)
				side.call("candle", 0.8, 0.9, {"flame": "candle"})
			elif h < 0.6:
				_add(out, "bonepile" if h < 0.3 else "bonepile_b", p.x, p.y, f)
			else:
				_add(out, "bones_a", p.x, p.y, f)
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


# ---------------------------------------------------------------- Torches des couloirs

## Torches à bras de fer (planche torches-tunnels, T2) le long des couloirs du plan du Temple : une toutes les
## TORCH_SPACING cases de couloir, sur la paroi nord d'un tronçon horizontal, sur le rebord d'un tronçon vertical
## (côté tiré au hasard). Jamais dans une salle ; deux torches restent à TORCH_GAP unités l'une de l'autre.
const TORCH_SPACING := 6
const TORCH_GAP := 14.0

static func _corridor_torches(state: TerrainState, out: Dictionary) -> void:
	var tl := state.temple_layout
	if tl.is_empty():
		return
	var paths: Array = []
	for l: Dictionary in tl["links"]:
		if l["kind"] == "corridor":
			paths.append(l["path"])
	if tl.get("arrival", []).size() > 1:
		paths.append(tl["arrival"])
	var placed: Array[Vector2] = []
	for path: Array in paths:
		var run := TORCH_SPACING / 2
		for k in path.size() - 1:
			var p: Vector2i = path[k]
			var q: Vector2i = path[k + 1]
			var d := (q - p).sign()
			for s in maxi(absi(q.x - p.x), absi(q.y - p.y)):
				run += 1
				if run >= TORCH_SPACING and _torch(state, out, placed, p + d * s, d):
					run = 0


static func _torch(state: TerrainState, out: Dictionary, placed: Array[Vector2], c: Vector2i, d: Vector2i) -> bool:
	var at := Vector2.INF
	var side := "n"
	if d.y == 0:
		for j in range(c.y, c.y - 3, -1):
			if AmbienceLayout._cell_open(state, c.x, j) and AmbienceLayout._cell_rock(state, c.x, j - 1):
				at = Vector2(c.x * 4.0 + 2.0, j * 4.0)
				break
	else:
		var west := Rng.hash3(c.x, c.y, state.seed ^ 0x70c) < 0.5
		var step := -1 if west else 1
		side = "w" if west else "e"
		for i in range(c.x, c.x + 3 * step, step):
			if AmbienceLayout._cell_open(state, i, c.y) and AmbienceLayout._cell_rock(state, i + step, c.y):
				at = Vector2(i * 4.0 + (0.2 if west else 3.8), c.y * 4.0 + 2.0)
				break
	if at == Vector2.INF or not state.temple_room(at.x, at.y + 1.0).is_empty():
		return false
	for o: Vector2 in placed:
		if o.distance_to(at) < TORCH_GAP:
			return false
	placed.append(at)
	_add(out, "torch", at.x, at.y, {"torch": side})
	return true


# ---------------------------------------------------------------- Arènes du monastère (B1–B4)

## Chœur de l'Archiprêtre (mb1), salle capitulaire de la Martyre (mb2), crypte des abbés de l'Œil ; dans chacune, le
## seuil (arche et statues) et le trophée sur son piédestal, posé une fois le boss tombé. Rien au centre des salles.
static func _arenas(state: TerrainState, out: Dictionary) -> void:
	if state.temple_layout.is_empty():
		return
	for room: Dictionary in state.temple_layout["rooms"]:
		var rr: Rect2i = room["rect"]
		var R := Rect2(Vector2(rr.position) * 4.0, Vector2(rr.size) * 4.0)
		match room["role"]:
			"mb1":
				_choir(out, R)
				_threshold(state, out, R, "mb1", R.get_center() + Vector2(0.0, 6.0))
			"mb2":
				_chapter(out, R)
				_threshold(state, out, R, "mb2", R.get_center())
	_crypt(state, out)


static func _choir(out: Dictionary, R: Rect2) -> void:
	var cx := R.get_center().x
	var top := R.position.y
	# Même autel que celui où l'Archiprêtre est soudé (Archipretre._setup).
	_add(out, "altar", cx, top + 8.0)
	for o: Vector2 in [Vector2(-2.6, 8.4), Vector2(2.4, 8.6), Vector2(0.0, 9.0), Vector2(-5.0, 9.4), Vector2(5.2, 9.2)]:
		_add(out, "root_a" if o.x <= 0.0 else "root_b", cx + o.x, top + o.y, {"ground": true, "flip": o.x > 2.0})
	_add(out, "moss_b", cx, top + 13.0, {"ground": true})
	_add(out, "moss_a", cx - 8.0, top + 11.0, {"ground": true})
	# Stalles : de part et d'autre, du pied de l'autel jusqu'au tiers sud, en laissant libre le couloir central.
	var span := R.size.x / 2.0 - 16.0
	for side: float in [-1.0, 1.0]:
		_add(out, "candelabra", cx + side * 6.5, top + 6.0, {"flames": CANDELABRA, "light": CANDLE_LIGHT})
		var z := top + 14.0
		var row := 0
		while z < R.end.y - 14.0:
			var x := 0.0
			while x + 4.6 <= span:
				var px := cx + side * (14.0 + x + 2.3)
				_add(out, "stalls_b" if Rng.hash3(row, floori(x), floori(side)) < 0.25 else "stalls", px, z, {"flip": side > 0.0})
				x += 4.6
			_add(out, "censer", cx + side * 11.0, z - 2.0, {"anim": "censer"})
			z += 9.0
			row += 1
		_add(out, "candelabra", cx + side * 11.0, R.end.y - 8.0, {"flames": CANDELABRA, "light": CANDLE_LIGHT})
	_add(out, "lectern", cx, R.end.y - 5.0, {"light": {"r": 6.0, "rgb": WHITE_LIGHT, "glow": 0.14}})


static func _chapter(out: Dictionary, R: Rect2) -> void:
	var c := R.get_center()
	var top := R.position.y
	var x := R.position.x + 10.0
	while x <= R.end.x - 10.0:
		_add(out, "bench_h", x, top + 0.7)
		x += 4.0
	var z := top + 8.0
	while z <= R.end.y - 8.0:
		_add(out, "bench_v", R.position.x + 1.2, z, {"ground": true})
		_add(out, "bench_v", R.end.x - 1.2, z, {"ground": true})
		z += 4.0
	_add(out, "rose", c.x, top + 0.05, {"light": {"r": 9.0, "rgb": Color8(255, 236, 170), "glow": 0.08}})
	# Bannières sur la paroi nord, candélabres le long des murs, rangées de prie-Dieu entre les deux.
	var n := 0
	x = R.position.x + 16.0
	while x <= R.end.x - 16.0:
		if absf(x - c.x) > 8.0:
			_add(out, "gbanner", x, top + 0.05)
		x += 14.0
	for side: float in [-1.0, 1.0]:
		var wx := c.x + side * (R.size.x / 2.0 - 7.0)
		z = top + 6.0
		while z <= R.end.y - 5.0:
			_add(out, "candelabra", wx, z, {"flames": CANDELABRA, "light": CANDLE_LIGHT})
			z += 16.0
		z = top + 12.0
		while z <= R.end.y - 10.0:
			for k in 2:
				var px := c.x + side * (R.size.x / 2.0 - 14.0 - k * 5.0)
				var h := Rng.hash3(n, k, floori(side) + 3)
				_add(out, "priedieu_top" if h < 0.3 else "priedieu", px, z + h, {"flip": side > 0.0})
			if Rng.hash3(n, 9, 1) < 0.6:
				_add(out, ["shards_a", "shards_b"][n % 2], c.x + side * (R.size.x / 2.0 - 20.0), z + 3.0, {"ground": true, "flip": side > 0.0})
			z += 8.0
			n += 1
	# Médaillon de dalles gravées au centre (à plat, sous le dôme) : la salle du chapitre n'est pas vide avant le combat.
	for ring: Array in [[9.0, 8], [17.0, 14], [25.0, 20]]:
		for i in int(ring[1]):
			var a := TAU * (i + 0.5 * (int(ring[1]) % 2)) / float(ring[1])
			var p := c + Vector2(cos(a) * float(ring[0]) * 1.15, sin(a) * float(ring[0]) * 0.9)
			_add(out, "slab_%d" % ((i + int(ring[0])) % 3), p.x, p.y, {"ground": true, "alpha": 0.85})
	_add(out, "slab_lit", c.x, c.y, {"ground": true})
	# Éclats de la rosace au pied de la paroi nord.
	for k in 5:
		_add(out, ["shards_a", "shards_b"][k % 2], c.x + (k - 2) * 6.0 + Rng.hash3(k, 2, 7) * 2.0, top + 4.0 + Rng.hash3(k, 3, 7) * 3.0, {"ground": true})
	z = R.end.y - 3.5
	while z > c.y + 14.0:
		_add(out, "runner", c.x, z, {"ground": true, "alpha": 0.9})
		z -= 7.0


static func _crypt(state: TerrainState, out: Dictionary) -> void:
	var c := TerrainState.eye_room_center()
	var rx := TerrainState.EYE_ROOM_RX
	var rz := TerrainState.EYE_ROOM_RZ
	var at := func(a: float, k: float) -> Vector2: return c + Vector2(cos(a) * rx * k, sin(a) * rz * k)
	_add(out, "flesh_a", c.x, c.y, {"ground": true})
	_add(out, "crater", c.x, c.y + 1.0, {"ground": true, "light": {"r": 9.0, "rgb": Color8(226, 56, 46), "glow": 0.1}})
	# Tombeaux des abbés en couronne, colonnes de la crypte plus près du centre.
	for i in 10:
		var a := TAU * (i + 0.5) / 10.0
		var p: Vector2 = at.call(a, 0.74)
		if absf(sin(a)) > 0.85 and sin(a) > 0.0:
			continue
		if TerrainState.in_eye_room(p.x, p.y, -3.0):
			_add(out, "gisant_open" if i % 3 == 1 else "gisant", p.x, p.y, {"flip": cos(a) > 0.0})
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p: Vector2 = at.call(a, 0.5)
		if sin(a) > 0.8:
			continue
		_add(out, "column_broken" if i % 3 == 0 else "column", p.x, p.y)
	# Veines : du pied de la paroi nord vers la salle, battant comme le pouls de l'Œil.
	var k := 0
	var fx := -0.8
	while fx <= 0.81:
		var x := c.x + fx * rx
		var z := c.y - rz * 1.1
		while z < c.y and not (TerrainState.in_eye_room(x, z) and state.is_gallery(x, z)):
			z += 0.5
		if z < c.y:
			_add(out, ["vein_a", "vein_b", "vein_c", "vein_d"][k % 4], x, z + 0.1, {"ground": true, "anim": "pulse"})
		k += 1
		fx += 0.2
	# Chair, pustules, ichor : plus dense vers le cratère.
	for i in 14:
		var a := Rng.hash3(i, 1, 91) * TAU
		var d := 0.25 + Rng.hash3(i, 2, 91) * 0.55
		var p: Vector2 = at.call(a, d)
		match i % 4:
			0, 1:
				_add(out, "flesh_b", p.x, p.y, {"ground": true, "flip": i % 2 == 0})
			2:
				_add(out, "pustule_l" if d > 0.5 else "pustule", p.x, p.y, {"anim": "pulse", "light": {"r": 3.0, "rgb": Color8(226, 56, 46), "glow": 0.08}})
			3:
				_add(out, "ichor", p.x, p.y, {"ground": true})
	for i in 8:
		var p: Vector2 = at.call(TAU * i / 8.0, 0.86)
		if TerrainState.in_eye_room(p.x, p.y, -2.0):
			_add(out, "candle", p.x, p.y, {"flame": "candle"})
			_add(out, "bonepile" if i % 2 == 0 else "bonepile_b", p.x + 2.0, p.y + 0.6)
	_threshold(state, out, Rect2(c - Vector2(rx, rz), Vector2(rx, rz) * 2.0), "oeil", c + Vector2(0.0, 1.0))


## Seuil (B4) : arche gardée par deux statues à l'entrée sud, braseros aux quatre coins ; au centre, piédestal, cercle
## de glyphes et trophée qui n'apparaissent qu'une fois le boss tombé (SanctumView, Sanctum.boss_down).
static func _threshold(state: TerrainState, out: Dictionary, R: Rect2, key: String, center: Vector2) -> void:
	var gate := _south_gate(state, R, key)
	if gate != Vector2.INF:
		_add(out, "arch", gate.x, gate.y)
		for side: float in [-1.0, 1.0]:
			_add(out, "statue", gate.x + side * 7.5, gate.y - 0.4, {"flip": side > 0.0})
	var inset := Vector2(minf(10.0, R.size.x * 0.2), minf(8.0, R.size.y * 0.22))
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p := R.get_center() + (R.size / 2.0 - inset) * o
		if key == "oeil" and not TerrainState.in_eye_room(p.x, p.y, -3.0):
			p = R.get_center() + (R.size / 2.0 - inset) * o * Vector2(0.62, 0.5)
		_brazier(out, p.x, p.y)
	var t := {"trophy": key}
	_add(out, "seal_ring", center.x, center.y, {"ground": true, "trophy": key, "light": {"r": 10.0, "rgb": GLYPH_LIGHT, "glow": 0.1}})
	_add(out, "plinth", center.x, center.y, {"ground": true, "trophy": key})
	_add(out, TROPHY[key], center.x, center.y + 0.6, t)


## Pied de l'arche : milieu des cases de galerie qui touchent le bord sud de la salle (hors portes scellées), ou INF.
static func _south_gate(state: TerrainState, R: Rect2, key: String) -> Vector2:
	var xs: Array[float] = []
	var z_out := R.end.y + 2.0
	if key == "oeil":
		var c := TerrainState.eye_room_center()
		var z := c.y + TerrainState.EYE_ROOM_RZ * 1.2
		while z > c.y and not TerrainState.in_eye_room(c.x, z, -1.0):
			z -= 0.5
		return Vector2(c.x, z)
	var x := R.position.x + 2.0
	while x < R.end.x:
		var cell := Vector2i(floori(x / 4.0), floori(z_out / 4.0))
		if state.is_gallery(x, z_out) and not state.door_cells.has(cell):
			xs.append(x)
		x += 4.0
	if xs.is_empty():
		return Vector2.INF
	return Vector2((xs[0] + xs[xs.size() - 1]) / 2.0, R.end.y - 0.6)


# ---------------------------------------------------------------- Salles oubliées

## Couloirs des Salles oubliées (planches/salles-oubliees-decor-propositions.html, V1–V6 choisies le 2026-11-25) :
## le premier Temple tyrien, muré par les moines, exploité puis abandonné par Byrsa. Galerie rongée et suintements
## partout, portes murées près des murs de quartier, canalisations surtout aux Écluses (VB), rigoles surtout aux Puits
## (VA), voie des wagonnets vers la Grande Patine (VC) et l'Antre de la Gorge (VR).
const VEINES_THEMES := ["vcolumns", "vseep", "vwalled", "vpipes", "vchannel", "vrails"]
## Fanaux de Byrsa (L1) : halo doux comme les torches du Temple, un fanal sur deux allumé.
const FANAL_LIGHT := {"r": 7.5, "rgb": Color8(255, 176, 92), "glow": 0.16, "soft": true}
const PIPES := ["o_pipe", "o_pipe", "o_pipe2", "o_pipe_leak", "o_pipe_valve", "o_pipe_gauge"]


static func _veines(state: TerrainState, out: Dictionary) -> void:
	var lay := state.veines_layout
	if lay.is_empty():
		return
	var band: Rect2i = lay["band"]
	var r := Rng.new(state.seed ^ 0xdec3)
	var occupied := {}
	var cz := floorf(band.position.y * 4.0 / CHUNK) * CHUNK
	while cz < band.end.y * 4.0:
		var cx := floorf(band.position.x * 4.0 / CHUNK) * CHUNK
		while cx < band.end.x * 4.0:
			var roll := r.next()
			var mix := r.next()
			var count := 3 + floori(r.next() * 4.0)
			if roll < CHUNK_RATE:
				var q := QuarterMarks.quarter_at(state, Vector2(cx + CHUNK / 2.0, cz + CHUNK / 2.0))
				var theme := _vtheme(state, cx, cz, mix, q)
				for g in count:
					_vgroup(state, r, out, occupied, theme, cx, cz)
			cx += CHUNK
		cz += CHUNK
	_veines_arenas(state, out)


## Famille du chunk : la même sur une plaque de THEME_PATCH unités, un chunk sur quatre tiré à part.
static func _vtheme(state: TerrainState, cx: float, cz: float, mix: float, q: String) -> String:
	var near_wall := false
	var walls: Dictionary = state.veines_layout["walls"]
	for dj in range(-1, 9, 3):
		for di in range(-1, 9, 3):
			if walls.has(Vector2i(floori(cx / 4.0) + di, floori(cz / 4.0) + dj)):
				near_wall = true
	var weights := [1.2, 1.2, 0.5 * (3.0 if near_wall else 1.0), 0.5 * (3.0 if q == "VB" else 1.0),
		0.5 * (3.0 if q == "VA" else 1.0), 0.4 * (3.0 if q in ["VC", "VR"] else 1.0)]
	var total := 0.0
	for w: float in weights:
		total += w
	var h := Rng.hash3(floori(cx / THEME_PATCH), floori(cz / THEME_PATCH), state.seed ^ 0x7e4)
	if mix < 0.25:
		h = mix * 4.0
	var pick := h * total
	for k in weights.size():
		pick -= weights[k]
		if pick <= 0.0:
			return VEINES_THEMES[k]
	return VEINES_THEMES[VEINES_THEMES.size() - 1]


static func _vok(state: TerrainState, x: float, z: float) -> bool:
	if not AmbienceLayout._free(state, x, z) or Biomes.index_at(z) != 1:
		return false
	var room := state.temple_room(x, z)
	if room.get("kind", "") in ["miniboss", "boss"]:
		return false
	if state.gorge_room != null and Vector2(x, z).distance_to(state.gorge_room) < Gorge.ROOM + 4.0:
		return false
	for tr: Dictionary in state.theme_rooms:
		var half: Vector2i = tr["half"]
		if absf(x - float(tr["x"])) < half.x * 4.0 + 5.0 and absf(z - float(tr["z"])) < half.y * 4.0 + 5.0:
			return false
	for p: Dictionary in state.portals:
		if Vector2(x - float(p["x"]), z - float(p["z"])).length() < TerrainState.PYLON_CHAMBER + 2.0:
			return false
	return true


static func _vgroup(state: TerrainState, r: Rng, out: Dictionary, occupied: Dictionary, theme: String, cx: float, cz: float) -> void:
	var wall := r.next() < 0.6
	var h := r.next()
	var flip := r.next() < 0.5
	var p: Vector2
	if wall:
		p = AmbienceLayout._foot(state, AmbienceLayout._spot(state, r, cx, cz,
			func(s: TerrainState, x: float, z: float) -> bool: return AmbienceLayout._under_wall(s, x, z) and _vok(s, x, z)))
	else:
		p = AmbienceLayout._spot(state, r, cx, cz, func(s: TerrainState, x: float, z: float) -> bool: return _vok(s, x, z))
	if p == Vector2.INF:
		return
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for o: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT]:
		if occupied.has(key + o):
			return
	occupied[key] = true
	var f := {"flip": flip}
	var g := {"flip": flip, "ground": true}
	var side := func(k: String, dx: float, dz: float, opt: Dictionary) -> void:
		if state.is_gallery(p.x + dx, p.y + dz):
			_add(out, k, p.x + dx, p.y + dz, opt)
	# Pièce murale voisine, seulement si la paroi nord continue à dx et que la case est libre.
	var beside := func(k: String, dx: float, opt: Dictionary) -> bool:
		var c2 := Vector2i(floori((p.x + dx) / 4.0), key.y)
		if occupied.has(c2) or not AmbienceLayout._under_wall(state, p.x + dx, p.y + 0.5):
			return false
		occupied[c2] = true
		_add(out, k, p.x + dx, p.y + 0.05, opt)
		return true
	match theme:
		"vcolumns":
			if wall:
				if h < 0.3:
					_add(out, "o_glyph" if h < 0.15 else "o_glyph_b", p.x, p.y + 0.05, {"light": {"r": 2.5, "rgb": GLYPH_LIGHT, "glow": 0.05}})
				elif h < 0.7:
					_add(out, "o_col", p.x, p.y + 1.0, f)
				else:
					_add(out, "o_col_broken", p.x, p.y + 1.0, f)
					side.call("o_drum", 2.2, 2.6, f)
			elif h < 0.45:
				_add(out, "slab_%d" % floori(h * 6.0), p.x, p.y, {"ground": true, "alpha": 0.85})
			elif h < 0.75:
				_add(out, "rubble_b", p.x, p.y, f)
			else:
				_add(out, "o_drum", p.x, p.y, f)
		"vseep":
			if wall:
				if h < 0.65:
					_add(out, "o_seep" if h < 0.35 else "o_seep_b", p.x, p.y + 0.05)
					beside.call("o_seam", 8.0, {})
				else:
					_add(out, "o_stal" if h < 0.85 else "o_stal_s", p.x, p.y + 0.05)
			elif h < 0.5:
				_add(out, "puddle", p.x, p.y, {"ground": true})
			elif h < 0.75:
				_add(out, "shrooms_a" if h < 0.62 else "shrooms_b", p.x, p.y, {"flip": flip, "light": {"r": 4.5, "rgb": SHROOM_LIGHT, "glow": 0.1}})
			else:
				_add(out, "rubble_a", p.x, p.y, f)
		"vwalled":
			if wall:
				if h < 0.55:
					_add(out, ["o_walled", "o_walled_b", "o_walled_broken"][floori(h / 0.55 * 3.0)], p.x, p.y + 0.05, f)
					if h > 0.36:
						side.call("rubble_a", 1.4, 1.6, f)
				elif h < 0.75:
					_add(out, "o_plaque", p.x, p.y + 0.05)
				else:
					_add(out, "o_niche_stat" if h < 0.88 else "o_niche", p.x, p.y + 0.05)
			elif h < 0.4:
				_add(out, "candle", p.x, p.y, {"flame": "candle"})
			else:
				_add(out, "rubble_a" if h < 0.7 else "rubble_b", p.x, p.y, f)
		"vpipes":
			if wall:
				if h < 0.15:
					_add(out, "o_sluice", p.x, p.y + 0.05)
				else:
					_add(out, PIPES[floori(h * 37.0) % PIPES.size()], p.x, p.y + 0.05)
					for dx: float in [8.0, -8.0, 16.0]:
						if not beside.call(PIPES[floori(h * 53.0 + dx) % PIPES.size()], dx, {}):
							break
			elif h < 0.5:
				_add(out, "puddle", p.x, p.y, {"ground": true})
			else:
				_add(out, "rubble_b", p.x, p.y, f)
		"vchannel":
			if wall:
				_add(out, "o_seep_b" if h < 0.5 else "o_stal", p.x, p.y + 0.05)
			elif h < 0.6 and state.is_gallery(p.x - 5.0, p.y) and state.is_gallery(p.x + 5.0, p.y):
				_add(out, "o_channel", p.x, p.y, {"ground": true})
				if h < 0.25:
					_add(out, "o_plank", p.x + 1.0, p.y, {"ground": true})
			elif h < 0.8:
				_add(out, "shrooms_b", p.x, p.y, {"flip": flip, "light": {"r": 4.5, "rgb": SHROOM_LIGHT, "glow": 0.1}})
			else:
				_add(out, "puddle", p.x, p.y, {"ground": true})
		"vrails":
			if wall:
				_add(out, "o_seam", p.x, p.y + 0.05)
			elif h < 0.45 and state.is_gallery(p.x - 5.0, p.y) and state.is_gallery(p.x + 5.0, p.y):
				_add(out, "o_rails_broken" if h < 0.12 else "o_rails", p.x, p.y, {"ground": true})
				if h < 0.3:
					side.call("o_cart" if h < 0.2 else "o_cart_tip", 0.5, 0.4, f)
			elif h < 0.65:
				_add(out, "o_helmet", p.x, p.y, f)
			elif h < 0.85:
				_add(out, "timber", p.x, p.y, f)
			else:
				_add(out, "o_cart_tip", p.x, p.y, f)


## Fanaux de Byrsa (L1) le long des couloirs du plan des Salles oubliées : même cadence que les torches du Temple
## (une toutes les TORCH_SPACING cases), pendus sous la paroi nord des tronçons horizontaux ; un sur deux allumé.
static func _veines_fanals(state: TerrainState, out: Dictionary) -> void:
	var lay := state.veines_layout
	if lay.is_empty():
		return
	var paths: Array = []
	for l: Dictionary in lay["links"]:
		if l["kind"] == "corridor":
			paths.append(l["path"])
	if lay.get("arrival", []).size() > 1:
		paths.append(lay["arrival"])
	var placed: Array[Vector2] = []
	var n := 0
	for path: Array in paths:
		var run := TORCH_SPACING / 2
		for k in path.size() - 1:
			var p: Vector2i = path[k]
			var q: Vector2i = path[k + 1]
			var d := (q - p).sign()
			if d.y != 0:
				continue
			for st in absi(q.x - p.x):
				run += 1
				if run < TORCH_SPACING:
					continue
				var c := p + d * st
				var at := Vector2.INF
				for j in range(c.y, c.y - 3, -1):
					if AmbienceLayout._cell_open(state, c.x, j) and AmbienceLayout._cell_rock(state, c.x, j - 1):
						at = Vector2(c.x * 4.0 + 2.0, j * 4.0)
						break
				if at == Vector2.INF or not state.temple_room(at.x, at.y + 1.0).is_empty():
					continue
				if placed.any(func(o: Vector2) -> bool: return o.distance_to(at) < TORCH_GAP):
					continue
				placed.append(at)
				run = 0
				n += 1
				if n % 2 == 0:
					_add(out, "o_fanal_off", at.x, at.y + 0.05)
				else:
					_add(out, "o_fanal", at.x, at.y + 0.05, {"light": FANAL_LIGHT})


## Arènes des Salles oubliées (A1–A4) : Grande Écluse de l'Éclusier (mb1), Nef verte de la Martyre de la Patine (mb2),
## Antre de la Gorge (salle du boss) ; dans chacune, le seuil et le trophée posé une fois le boss tombé. Rien au
## centre : eau, dôme et attaques restent lisibles.
static func _veines_arenas(state: TerrainState, out: Dictionary) -> void:
	for room: Dictionary in state.veines_layout["rooms"]:
		var rr: Rect2i = room["rect"]
		var R := Rect2(Vector2(rr.position) * 4.0, Vector2(rr.size) * 4.0)
		if room["role"] == "mb1":
			_ecluse(out, R)
			_vthreshold(state, out, R, "mb1@veines", R.get_center())
		elif room["role"] == "mb2":
			_nef(out, R)
			_vthreshold(state, out, R, "mb2@veines", R.get_center())
		elif room["kind"] == "boss":
			_antre(state, out, R)
			_vthreshold(state, out, R, "gorge", state.gorge_room if state.gorge_room != null else R.get_center())


## A1 : vannes de bois et de fer sur la paroi nord, chaînes entre elles, manomètre au milieu.
static func _ecluse(out: Dictionary, R: Rect2) -> void:
	var top := R.position.y + 0.05
	for k in 4:
		var x := R.position.x + R.size.x * (k + 0.5) / 4.0
		_add(out, "o_sluice", x, top)
		if k < 3:
			_add(out, "o_chain" if k % 2 == 0 else "o_chain_s", x + R.size.x / 8.0, top)
	_add(out, "o_pipe_gauge", R.get_center().x, top + 0.02)
	_add(out, "rubble_b", R.end.x - 6.0, R.end.y - 4.0)
	_add(out, "o_helmet", R.position.x + 7.0, R.end.y - 5.0)


## A2 : tuyaux d'orgue de cuivre sur la paroi nord, colonnes verdies le long des parois est et ouest, lustre tombé
## et statue renversée dans les coins, hors du dôme (Patine.RADIUS autour du centre).
static func _nef(out: Dictionary, R: Rect2) -> void:
	var c := R.get_center()
	var top := R.position.y + 0.05
	for side: float in [-1.0, 1.0]:
		_add(out, "o_organ" if side < 0.0 else "o_organ_b", c.x + side * 13.0, top)
		_add(out, "candle", c.x + side * 8.0, top + 1.2, {"flame": "candle"})
		var z := R.position.y + 7.0
		var k := 0
		while z < R.end.y - 3.0:
			_add(out, "o_col_broken" if (k + int(side)) % 3 == 0 else "o_col", c.x + side * (R.size.x / 2.0 - 3.5), z, {"flip": side > 0.0})
			z += 9.0
			k += 1
		_add(out, "o_seep", c.x + side * (R.size.x / 2.0 - 9.0), top)
	_add(out, "o_chandelier", R.position.x + 10.0, R.end.y - 4.5)
	_add(out, "toppled", R.end.x - 11.0, R.position.y + 5.0)
	_add(out, "rubble_a", R.end.x - 9.0, R.end.y - 5.0)


## A3 : filons vidés et parois griffées au nord, rails coupés et wagonnets renversés au sud, mues de cuivre et
## carcasses de tiques le long des parois, son trou au centre.
static func _antre(state: TerrainState, out: Dictionary, R: Rect2) -> void:
	var c: Vector2 = state.gorge_room if state.gorge_room != null else R.get_center()
	var top := R.position.y + 0.05
	var x := R.position.x + 6.0
	var k := 0
	while x < R.end.x - 4.0:
		_add(out, "o_lode" if k % 2 == 0 else "o_gnaw", x, top)
		x += 9.0
		k += 1
	_add(out, "o_burrow", c.x, c.y + 1.0, {"ground": true})
	var z := R.end.y - 6.0
	x = R.position.x + 6.0
	while x < R.end.x - 8.0:
		if absf(x - c.x) > 8.0:
			_add(out, "o_rails_broken" if k % 3 == 0 else "o_rails", x, z, {"ground": true})
		x += 10.0
		k += 1
	_add(out, "o_cart_tip", R.position.x + 8.0, R.end.y - 3.0)
	_add(out, "o_cart_tip", R.end.x - 8.0, R.position.y + 8.0, {"flip": true})
	for i in 8:
		var a := TAU * (i + 0.3) / 8.0
		var p := c + Vector2(cos(a) * R.size.x * 0.4, sin(a) * R.size.y * 0.36)
		if state.is_gallery(p.x, p.y) and p.distance_to(c) > 12.0:
			_add(out, ["o_plate", "o_plate_b", "o_husk"][i % 3], p.x, p.y, {"flip": i % 2 == 0})


## A4 : portique de fer de Byrsa à l'entrée sud, deux braseros, et au centre le cercle de glyphes, le piédestal et le
## trophée, posés une fois le boss tombé (Sanctum.boss_down).
static func _vthreshold(state: TerrainState, out: Dictionary, R: Rect2, key: String, center: Vector2) -> void:
	var gate := _south_gate(state, R, key)
	if gate != Vector2.INF:
		_add(out, "o_arch", gate.x, gate.y)
		for side: float in [-1.0, 1.0]:
			_brazier(out, gate.x + side * 8.5, gate.y - 1.5)
	_add(out, "seal_ring", center.x, center.y, {"ground": true, "trophy": key, "light": {"r": 10.0, "rgb": GLYPH_LIGHT, "glow": 0.1}})
	_add(out, "plinth", center.x, center.y, {"ground": true, "trophy": key})
	_add(out, TROPHY[key], center.x, center.y + 0.6, {"trophy": key})


# ---------------------------------------------------------------- Forges mortes (biome 3)

## Planche planches/forges-mortes-decor-propositions.html, recommandation acceptée le 2026-11-25 : F1 fours, F5 scories
## et rouille, F6 fissures de lave partout ; F2 rigoles de coulée et F3 lingotières près des salles à thème ; F4 palans
## (prévus vers la chapelle de la Martyre du Fer, qui n'existe pas encore : semés un peu partout). Les galeries du
## biome 3 sont des vers, sans plan de salles : le décor est semé par chunk sur toute la bande du biome.
const FORGE_THEMES := ["ffurnace", "fslag", "fcrack", "frigole", "fmoulds", "fhoist"]
const LAVA_LIGHT := Color8(240, 120, 50)
const EMBER_LIGHT := {"r": 4.0, "rgb": LAVA_LIGHT, "glow": 0.1}
const CRACK_LIGHT := {"r": 4.5, "rgb": LAVA_LIGHT, "glow": 0.12, "dz": -2.5}
const CRACKF_LIGHT := {"r": 3.5, "rgb": LAVA_LIGHT, "glow": 0.08}
## Lanternes de fondeur (L2) : fixes, halo doux comme les torches du Temple, une sur deux allumée.
const LAMP_LIGHT := {"r": 7.5, "rgb": Color8(255, 176, 92), "glow": 0.16, "soft": true}
const FORGE_ROOM_NEAR := 44.0
## Part des pieds de paroi qui reçoivent une pièce murale (passe dédiée : les galeries du biome 3 sont étroites, un
## point tiré au hasard dans un chunk y tombe rarement au pied d'une paroi).
const FORGE_WALL_RATE := 0.3


static func _forges(state: TerrainState, out: Dictionary) -> void:
	var k := Biomes.index_of("forges")
	if k < 0:
		return
	var lim := TerrainState.band_range(k)
	var rooms: Array[Vector2] = []
	for tr: Dictionary in state.theme_rooms:
		if String(tr["kind"]).begins_with("f"):
			rooms.append(Vector2(tr["x"], tr["z"]))
	var r := Rng.new(state.seed ^ 0xf0e3)
	var occupied := {}
	_forge_lamps(state, out, occupied)
	var cz := floorf(lim.x / CHUNK) * CHUNK
	while cz < lim.y:
		var cx := floorf(CaveShape.WORLD_X0 / CHUNK) * CHUNK
		while cx < CaveShape.WORLD_X0 + TerrainState.GAL_W:
			var roll := r.next()
			var mix := r.next()
			var count := 3 + floori(r.next() * 4.0)
			if roll < CHUNK_RATE:
				var c := Vector2(cx + CHUNK / 2.0, cz + CHUNK / 2.0)
				var near := rooms.any(func(o: Vector2) -> bool: return o.distance_to(c) < FORGE_ROOM_NEAR)
				var theme := _ftheme(state, cx, cz, mix, near)
				for g in count:
					_fgroup(state, r, out, occupied, theme, cx, cz, k)
			cx += CHUNK
		cz += CHUNK
	# Passe murale : chaque pied de paroi du biome, trois fois sur dix, reçoit la pièce murale de la famille du chunk.
	for cj in range(floori(lim.x / 4.0) + 1, floori(lim.y / 4.0)):
		for ci in range(floori(CaveShape.WORLD_X0 / 4.0), floori((CaveShape.WORLD_X0 + TerrainState.GAL_W) / 4.0)):
			if occupied.has(Vector2i(ci, cj)) or Rng.hash3(ci, cj, state.seed ^ 0xf3a1) > FORGE_WALL_RATE:
				continue
			var at := Vector2(ci * 4.0 + 1.0 + Rng.hash3(ci, cj, 5) * 2.0, cj * 4.0)
			if not _fwall(state, at.x, at.y + 0.5) or not _fok(state, at.x, at.y + 0.5, k):
				continue
			var ccx := floorf(at.x / CHUNK) * CHUNK
			var ccz := floorf(at.y / CHUNK) * CHUNK
			var c := Vector2(ccx + CHUNK / 2.0, ccz + CHUNK / 2.0)
			var near := rooms.any(func(o: Vector2) -> bool: return o.distance_to(c) < FORGE_ROOM_NEAR)
			_fgroup(state, r, out, occupied, _ftheme(state, ccx, ccz, 0.5, near), ccx, ccz, k, at)


## Famille du chunk : la même sur une plaque de THEME_PATCH unités, un chunk sur quatre tiré à part.
static func _ftheme(state: TerrainState, cx: float, cz: float, mix: float, near_room: bool) -> String:
	var weights := [1.2, 1.2, 1.2, 0.4 * (4.0 if near_room else 1.0), 0.4 * (4.0 if near_room else 1.0), 0.5]
	var total := 0.0
	for w: float in weights:
		total += w
	var h := Rng.hash3(floori(cx / THEME_PATCH), floori(cz / THEME_PATCH), state.seed ^ 0xf7e4)
	if mix < 0.25:
		h = mix * 4.0
	var pick := h * total
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0.0:
			return FORGE_THEMES[i]
	return FORGE_THEMES[FORGE_THEMES.size() - 1]


## Pied de paroi nord : case ouverte sous une case de roche. Les galeries du biome 3 (des vers) n'ont souvent qu'une
## case de haut : contrairement au Temple, on n'exige pas de case ouverte en dessous.
static func _fwall(state: TerrainState, x: float, z: float) -> bool:
	var ci := floori(x / 4.0)
	var cj := floori(z / 4.0)
	return AmbienceLayout._cell_open(state, ci, cj) and AmbienceLayout._cell_rock(state, ci, cj - 1)


static func _fok(state: TerrainState, x: float, z: float, k: int) -> bool:
	if not AmbienceLayout._free(state, x, z) or Biomes.index_at(z) != k:
		return false
	for tr: Dictionary in state.theme_rooms:
		var half: Vector2i = tr["half"]
		if absf(x - float(tr["x"])) < half.x * 4.0 + 5.0 and absf(z - float(tr["z"])) < half.y * 4.0 + 5.0:
			return false
	for p: Dictionary in state.portals:
		if Vector2(x - float(p["x"]), z - float(p["z"])).length() < TerrainState.PYLON_CHAMBER + 2.0:
			return false
	return true


## `forced` : pied de paroi imposé (passe murale) ; sinon un point tiré dans le chunk, au mur six fois sur dix.
static func _fgroup(state: TerrainState, r: Rng, out: Dictionary, occupied: Dictionary, theme: String, cx: float, cz: float, k: int, forced := Vector2.INF) -> void:
	var wall := r.next() < 0.6 or forced != Vector2.INF
	var h := r.next()
	var flip := r.next() < 0.5
	var p: Vector2
	if forced != Vector2.INF:
		p = forced
	elif wall:
		p = AmbienceLayout._foot(state, AmbienceLayout._spot(state, r, cx, cz,
			func(s: TerrainState, x: float, z: float) -> bool: return _fwall(s, x, z) and _fok(s, x, z, k)))
	else:
		p = AmbienceLayout._spot(state, r, cx, cz, func(s: TerrainState, x: float, z: float) -> bool: return _fok(s, x, z, k))
	if p == Vector2.INF:
		return
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for o: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT]:
		if occupied.has(key + o):
			return
	occupied[key] = true
	var f := {"flip": flip}
	var side := func(kk: String, dx: float, dz: float, opt: Dictionary) -> void:
		if _fok(state, p.x + dx, p.y + dz, k):
			_add(out, kk, p.x + dx, p.y + dz, opt)
	# Pièce murale voisine, seulement si la paroi nord continue à dx et que la case est libre.
	var beside := func(kk: String, dx: float, opt: Dictionary) -> bool:
		var c2 := Vector2i(floori((p.x + dx) / 4.0), key.y)
		if occupied.has(c2) or not _fwall(state, p.x + dx, p.y + 0.5):
			return false
		occupied[c2] = true
		_add(out, kk, p.x + dx, p.y + 0.05, opt)
		return true
	# Rigole (80 px = 10 unités) : seulement sur un tronçon horizontal assez long.
	var flat := func(x: float, z: float) -> bool:
		return _fok(state, x - 5.0, z, k) and _fok(state, x + 5.0, z, k) and _fok(state, x, z, k)
	match theme:
		"ffurnace":
			if wall:
				if h < 0.6:
					if h < 0.22:
						_add(out, "f_furnace_ember", p.x, p.y + 0.05, {"light": EMBER_LIGHT})
					else:
						_add(out, "f_furnace", p.x, p.y + 0.05)
					side.call("f_bellows", 0.6 if flip else -0.6, 1.8, f)
				else:
					_add(out, "f_rust" if h < 0.8 else "f_rust_b", p.x, p.y + 0.05)
			elif h < 0.3:
				_add(out, "f_bellows_flat", p.x, p.y, f)
			elif h < 0.55:
				_add(out, "f_tongs", p.x, p.y, f)
			elif h < 0.75:
				_add(out, "f_hammer", p.x, p.y, f)
			else:
				_add(out, "f_slag_b", p.x, p.y, f)
		"fslag":
			if wall:
				if h < 0.45:
					_add(out, "f_rust" if h < 0.25 else "f_rust_b", p.x, p.y + 0.05)
					beside.call("f_rust_b" if h < 0.25 else "f_rust", 6.0 if flip else -6.0, {})
				else:
					_add(out, "f_slag" if h < 0.8 else "f_slag_warm", p.x, p.y + 1.0, {"flip": flip, "light": EMBER_LIGHT} if h >= 0.8 else f)
			elif h < 0.3:
				_add(out, "f_slag_b", p.x, p.y, f)
			elif h < 0.5:
				_add(out, "f_slag_warm", p.x, p.y, {"flip": flip, "light": EMBER_LIGHT})
			elif h < 0.8:
				_add(out, "f_scrap" if h < 0.65 else "f_scrap_b", p.x, p.y, f)
			else:
				_add(out, "f_slag", p.x, p.y, f)
		"fcrack":
			if wall:
				if h < 0.7:
					_add(out, "f_crack" if h < 0.35 else "f_crack_b", p.x, p.y + 0.05, {"flip": flip, "light": CRACK_LIGHT})
				else:
					_add(out, "f_rust", p.x, p.y + 0.05)
			elif h < 0.4 and flat.call(p.x, p.y):
				_add(out, "f_crackf", p.x, p.y, {"flip": flip, "ground": true, "light": CRACKF_LIGHT})
			elif h < 0.7:
				_add(out, "f_coolflow", p.x, p.y, {"flip": flip, "ground": true})
			else:
				_add(out, "f_slag_warm", p.x, p.y, {"flip": flip, "light": EMBER_LIGHT})
		"frigole":
			if wall:
				_add(out, "f_moulds" if h < 0.5 else "f_moulds_stack", p.x, p.y + 1.2, f)
			elif flat.call(p.x, p.y):
				var hot := h < 0.35
				var opt := {"ground": true, "light": EMBER_LIGHT} if hot else {"ground": true}
				_add(out, "f_rigole_hot" if hot else "f_rigole", p.x, p.y, opt)
				# La rigole continue d'un tronçon de chaque côté tant que la galerie reste droite.
				for d: float in [10.0, -10.0]:
					if flat.call(p.x + d, p.y) and not occupied.has(Vector2i(floori((p.x + d) / 4.0), key.y)):
						occupied[Vector2i(floori((p.x + d) / 4.0), key.y)] = true
						_add(out, "f_rigole_hot" if hot and d > 0.0 else "f_rigole", p.x + d, p.y, {"ground": true})
			else:
				_add(out, "f_tongs", p.x, p.y, f)
		"fmoulds":
			if wall:
				if h < 0.6:
					_add(out, "f_moulds_stack" if h < 0.3 else "f_moulds", p.x, p.y + 1.2, f)
				else:
					_add(out, "f_rust", p.x, p.y + 0.05)
			elif h < 0.3:
				_add(out, "f_moulds", p.x, p.y, f)
			elif h < 0.5:
				_add(out, "f_bars", p.x, p.y, f)
			elif h < 0.7:
				_add(out, "f_hammer", p.x, p.y, f)
			else:
				_add(out, "f_tongs", p.x, p.y, f)
		"fhoist":
			if wall and _fwall(state, p.x - 4.5, p.y + 0.5) and _fwall(state, p.x + 4.5, p.y + 0.5):
				_add(out, "f_beam", p.x, p.y + 0.04)
				for i in 3:
					var dx := -3.0 + i * 3.0 + (Rng.hash3(i, key.x, key.y) - 0.5)
					var kk: String = ["f_hoist_hook", "f_hoist_pot", "f_hoist_s"][floori(Rng.hash3(key.x, i, 7) * 3.0)]
					if Rng.hash3(i, key.y, 3) < 0.75:
						_add(out, kk, p.x + dx, p.y + 0.06)
			elif wall:
				# Paroi trop courte pour la poutre : une chaîne seule, pendue à la voûte.
				_add(out, ["f_hoist_hook", "f_hoist_s", "f_hoist_pot"][floori(h * 3.0)], p.x, p.y + 0.06)
			elif h < 0.5:
				_add(out, "f_scrap", p.x, p.y, f)
			else:
				_add(out, "f_slag_b", p.x, p.y, f)


## Lanternes de fondeur (L2) au pied des parois nord des Forges : même cadence que les torches du Temple (une toutes
## les TORCH_SPACING cases d'un tronçon de paroi continu), une sur deux allumée.
static func _forge_lamps(state: TerrainState, out: Dictionary, occupied: Dictionary) -> void:
	var k := Biomes.index_of("forges")
	if k < 0:
		return
	var lim := TerrainState.band_range(k)
	var i0 := floori(CaveShape.WORLD_X0 / 4.0)
	var i1 := floori((CaveShape.WORLD_X0 + TerrainState.GAL_W) / 4.0)
	var placed: Array[Vector2] = []
	var n := 0
	for cj in range(floori(lim.x / 4.0) + 1, floori(lim.y / 4.0)):
		var run := TORCH_SPACING / 2
		for ci in range(i0, i1):
			if not (AmbienceLayout._cell_open(state, ci, cj) and AmbienceLayout._cell_rock(state, ci, cj - 1)):
				run = TORCH_SPACING / 2
				continue
			run += 1
			if run < TORCH_SPACING:
				continue
			var at := Vector2(ci * 4.0 + 2.0, cj * 4.0)
			if not _fok(state, at.x, at.y + 1.0, k):
				continue
			if placed.any(func(o: Vector2) -> bool: return o.distance_to(at) < TORCH_GAP):
				continue
			placed.append(at)
			for o in range(-1, 2):
				occupied[Vector2i(ci + o, cj)] = true
			run = 0
			n += 1
			if n % 2 == 0:
				_add(out, "f_lamp_off", at.x, at.y + 0.05)
			else:
				_add(out, "f_lamp", at.x, at.y + 0.05, {"light": LAMP_LIGHT})
