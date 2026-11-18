extends "res://tests/test_case.gd"
## Monde procédural, étape 6 : déterminisme de toute la carte et coutures (blocs de sol, sol baké / généré,
## chunks de décor, limite de biome).

const SEEDS := [5, 20261114]


static func _snapshot(st: TerrainState) -> Dictionary:
	return {"mask": st.mask_sha1(), "full": TerrainState._sha1(st.mask), "blocks": st.block_types.duplicate(),
		"lodes": st.lodes.duplicate(), "wood": st.wood_left.duplicate(), "water": st.water_cells.duplicate(),
		"portals": st.portals.map(func(p: Dictionary) -> Vector3: return Vector3(p["x"], p["z"], p["threat"]))}


func test_whole_map_deterministic() -> void:
	for map_seed in SEEDS:
		var a := TerrainState.new()
		var t0 := Time.get_ticks_msec()
		a.generate_galleries(map_seed)
		var ms := Time.get_ticks_msec() - t0
		check(ms < 3000, "génération en moins de 3 s (%d ms)" % ms)
		var b := TerrainState.new()
		b.generate_galleries(map_seed)
		check_eq(_snapshot(a), _snapshot(b), "graine %d : même carte, même contenu" % map_seed)
		# Une instance réutilisée (nouvelle partie) donne la même carte qu'une neuve.
		b.generate_galleries(map_seed + 1)
		b.generate_galleries(map_seed)
		check_eq(_snapshot(a), _snapshot(b), "graine %d : carte régénérée identique" % map_seed)
	var x := TerrainState.new()
	x.generate_galleries(SEEDS[0])
	var y := TerrainState.new()
	y.generate_galleries(SEEDS[1])
	check(_snapshot(x)["full"] != _snapshot(y)["full"], "graines différentes, cartes différentes")


## Hors de la zone d'origine et des passages, les galeries de l'extension ne modifient pas la zone d'origine.
func test_start_zone_unchanged_by_extension() -> void:
	var with := TerrainState.new()
	with.generate_galleries(SEEDS[1])
	var parity := TerrainState.new()
	parity.groves = false
	parity.generate_galleries(SEEDS[1])
	var w := TerrainState.GAL_W
	var differ := 0
	for k in with.mask.size():
		var px := k % w + CaveShape.WORLD_X0 + 0.5
		var pz := k / w + CaveShape.WORLD_Z0 + 0.5
		# Marge des passages (bords ouest, est, nord) : seuls endroits où l'extension entre dans la zone.
		if not CaveShape.in_start(px, pz) or px < CaveShape.START_X0 + 60.0 or px > CaveShape.START_X1 - 60.0 or pz < CaveShape.START_Z0 + 60.0:
			continue
		# Clairières et bassins de la zone d'origine existent seulement hors parité : on compare là où
		# la parité a déjà une galerie, qui doit rester galerie.
		if parity.mask[k] == 1 and with.mask[k] == 0:
			differ += 1
	check_eq(differ, 0, "aucune galerie d'origine refermée")


func test_galleries_cross_biome_border() -> void:
	var st := TerrainState.new()
	st.generate_galleries(SEEDS[1])
	var border := Biomes.north_z(0)
	var crossing := 0
	var x := CaveShape.WORLD_X0 + 12.0
	while x < CaveShape.WORLD_X1 - 12.0:
		if st.is_gallery(x, border + 1.0) and st.is_gallery(x, border - 1.0):
			crossing += 1
		x += 1.0
	check(crossing > 0, "des galeries franchissent la limite Temple / biome 2 (%d colonnes)" % crossing)


## Sol vierge généré : roche = rock.png et herbe = grass.png en coordonnées absolues, y compris de part et
## d'autre des bords de blocs ; même résultat avant et après matérialisation.
func test_ground_seams() -> void:
	var t := Terrain.new()
	t.build()
	var rock := Terrain._rgba(load(ArtStyle.TILES + "rock.png"))
	var grass := Terrain._rgba(load(ArtStyle.TILES + "grass.png"))
	var bad := 0
	var checked := 0
	# Bords de blocs dans la roche (nord-ouest) et dans l'herbe (sud-est), plus la marge du sol baké.
	for p: Vector2 in [Vector2(-380, -600), Vector2(-260, -300), Vector2(0, -340), Vector2(400, 40), Vector2(-240, 30), Vector2(240, -200)]:
		var g := t._px(p.x, p.y)
		var edge := Vector2i(roundi(g.x / 1024.0) * 1024, roundi(g.y / 1024.0) * 1024)
		var grass_here := Terrain.grass_cell(p.x, p.y)
		for d in range(-40, 40, 3):
			for q: Vector2i in [Vector2i(edge.x + d, g.y), Vector2i(g.x, edge.y + d)]:
				var w := Vector2(q - t.origin) / 8.0
				if CaveShape.in_start(w.x, w.y) and absf(w.x) < CaveShape.START_X1 - 10.0 and w.y > CaveShape.START_Z0 + 10.0:
					continue
				if Terrain.grass_cell(w.x, w.y) != grass_here or _near_edge(w):
					continue
				var want := grass.get_pixel(posmod(q.x, 512), posmod(q.y, 512)) if grass_here else rock.get_pixel(posmod(q.x, 504), posmod(q.y, 504))
				checked += 1
				if not t.get_ground_pixel(q.x, q.y).is_equal_approx(want):
					bad += 1
	check(checked > 100, "pixels contrôlés aux coutures (%d)" % checked)
	check_eq(bad, 0, "sol vierge continu aux coutures")
	# Une case peinte à cheval sur deux blocs vierges : les deux sont matérialisés, la case est entière.
	var p := t._px(-388.0, -592.0)
	var key := Vector2i(floori(p.x / 1024.0), floori(p.y / 1024.0))
	var corner := (key + Vector2i.ONE) * 1024 - Vector2i(16, 16)
	var red := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	red.fill(Color.RED)
	t.blit(red, corner.x, corner.y)
	for o: Vector2i in [Vector2i(0, 0), Vector2i(31, 0), Vector2i(0, 31), Vector2i(31, 31)]:
		check_eq(t.get_ground_pixel(corner.x + o.x, corner.y + o.y), Color.RED, "case à cheval sur 4 blocs, coin %s" % o)
	t.free()


## Lisière : 3 u de part et d'autre du flanc (liseré), ignorée par la comparaison texture pure.
static func _near_edge(w: Vector2) -> bool:
	return absf(w.y - CaveShape.mountain_edge(w.x)) < 8.0


## Faces du flanc : exactement une par colonne de 4 u hors zone d'origine, quel que soit le découpage en chunks.
func test_cliff_faces_one_per_column() -> void:
	var cols := {}
	var cr := DecorGen.chunk_range()
	for cz in range(cr.position.y, cr.end.y):
		for cx in range(cr.position.x, cr.end.x):
			for e in DecorGen.chunk(SEEDS[0], Vector2i(cx, cz)):
				if String(e["s"]).begins_with("face"):
					var k := int(e["x"])
					check(not cols.has(k), "une seule face en x = %d" % k)
					cols[k] = true
					check(is_equal_approx(e["z"], CaveShape.mountain_edge(e["x"])), "face sur le flanc")
	var expected := 0
	var x := CaveShape.WORLD_X0
	while x < CaveShape.WORLD_X1:
		var z := CaveShape.mountain_edge(x)
		if DecorGen.allowed(x, z) and DecorGen.allowed(x + 4.0, z):
			expected += 1
		x += 4.0
	check_eq(cols.size(), expected, "toutes les colonnes")
