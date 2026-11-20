extends "res://tests/test_case.gd"
## Étape 1 (plan v2) : les graphismes extraits de la version figée (73b410f + charte graphique, D16) sont complets,
## importés par Godot et cohérents avec manifest.json.

const BAKED := "res://assets/baked/"
const REFERENCE_REV := "c1bbe755628c30382547d27561ea12a5a13538d9"


func _json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	check(not text.is_empty(), "fichier lisible : " + path)
	return JSON.parse_string(text)


func _texture(path: String) -> Texture2D:
	check(ResourceLoader.exists(path), "ressource importée : " + path)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _check_sheet(path: String, meta: Dictionary, label: String) -> void:
	var tex := _texture(path)
	if tex:
		check_eq(tex.get_width(), int(meta["cols"]) * int(meta["frame_w"]), label + " largeur")
		check_eq(tex.get_height(), int(meta["rows"]) * int(meta["frame_h"]), label + " hauteur")


func test_report_ok_on_reference_rev() -> void:
	var report: Dictionary = _json(BAKED + "bake_report.json")
	check_eq(report.get("ok"), true, "rapport du baker")
	check_eq(report.get("source_rev"), REFERENCE_REV, "version figée")
	check_eq(report.get("source_unchanged"), true, "dépôt du prototype inchangé")
	check(report["summary"]["errors"].is_empty(), "aucune erreur dans la page")
	check(report["summary"]["roundtrip_failures"].is_empty(), "aller-retour PNG")


func test_every_reported_png_is_importable() -> void:
	var report: Dictionary = _json(BAKED + "bake_report.json")
	var count := 0
	for rel: String in report["files"]:
		if rel.ends_with(".png"):
			check(ResourceLoader.exists((BAKED + rel).simplify_path()), "importé : " + rel)
			count += 1
	check(count >= 330, "au moins 330 PNG (obtenu %d)" % count)


func test_ground_chunks_cover_manifest_size() -> void:
	var g: Dictionary = _json(BAKED + "manifest.json")["world"]["ground"]
	check_eq(Vector2i(int(g["width"]), int(g["height"])), Vector2i(3808, 3360), "taille du sol")
	var width := 0
	for c in int(g["cols"]):
		var tex := _texture(BAKED + "world/ground/ground_r0_c%d.png" % c)
		if tex:
			width += tex.get_width()
	var height := 0
	for r in int(g["rows"]):
		var tex := _texture(BAKED + "world/ground/ground_r%d_c0.png" % r)
		if tex:
			height += tex.get_height()
	check_eq(Vector2i(width, height), Vector2i(int(g["width"]), int(g["height"])), "blocs cumulés")


func test_decor_placements_reference_existing_sprites() -> void:
	var sprites: Dictionary = _json(BAKED + "world/decor_sprites.json")
	var data: Dictionary = _json(BAKED + "world/decor_placements.json")
	check_eq(data["placements"].size(), int(data["count"]), "nombre de placements")
	var missing := 0
	var specials := {"portal": 0, "dportal": 0, "deity_fx": 0, "orb": 0}
	for p: Dictionary in data["placements"]:
		if p.has("s") and not sprites.has(p["s"]):
			missing += 1
		for k: String in specials:
			if p.has(k):
				specials[k] += 1
	check_eq(missing, 0, "placements sans sprite")
	check_eq(specials, {"portal": 1, "dportal": 4, "deity_fx": 4, "orb": 1}, "objets spéciaux")
	for id: String in sprites:
		var tex := _texture(BAKED + "world/sprites/%s.png" % id)
		if tex:
			check_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(int(sprites[id]["w"]), int(sprites[id]["h"])), id)


func test_runtime_decor_and_tiles() -> void:
	for v in 6:
		_texture(BAKED + "world/runtime/face5_%d.png" % v)
		_texture(BAKED + "world/runtime/gallery_spire_%d.png" % v)
	for t in ["cave_base", "rock_base"]:
		var tex := _texture(BAKED + "world/tiles/%s.png" % t)
		if tex:
			check_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(32, 32), t)


func test_units_enemies_adepts() -> void:
	var m: Dictionary = _json(BAKED + "manifest.json")
	check_eq(m["units"]["roles"].size(), 5, "rôles alliés")
	check_eq(m["enemies"].size(), 4, "types d'ennemis (avec beast)")
	for group in ["units", "enemies"]:
		var entries: Dictionary = m["units"]["roles"] if group == "units" else m["enemies"]
		for name: String in entries:
			for anim in ["idle", "walk", "shoot"]:
				if entries[name].has(anim):
					_check_sheet(BAKED + "%s/%s_%s.png" % [group, name, anim], entries[name][anim], "%s %s" % [name, anim])
	check_eq(int(m["units"]["roles"]["engineer"]["walk"]["count"]), 12, "marche de l'Ingénieur (EngineerKit)")
	_check_sheet(BAKED + "units/engineer_kneel.png", m["units"]["roles"]["engineer"]["kneel"], "agenouillement")
	check(m["adepts"]["roles"].size() >= 7, "rôles d'adeptes (les 7 du prototype et ceux ajoutés depuis)")
	for role: String in m["adepts"]["roles"]:
		var modes: Dictionary = m["adepts"]["roles"][role]["modes"]
		if m["adepts"]["roles"][role].get("spirit", false):
			# Esprits mineurs (tools/esprits/serve.py) : six modes de 24 images à 12 i/s.
			check_eq(modes.keys().size(), 6, role + " : six modes d'esprit")
			for mode: String in modes:
				check_eq(int(modes[mode]["count"]), 24, "%s %s : 24 images" % [role, mode])
		else:
			# Refonte 16 bits : le nombre d'images par mode n'est plus fixe ; repos, marche et travail existent.
			for mode: String in ["idle", "walk", "work"]:
				check(int(modes[mode]["count"]) >= 1, "%s : mode %s présent" % [role, mode])
		for mode: String in modes:
			_check_sheet(BAKED + "adepts/%s_%s.png" % [role, mode], modes[mode], "%s %s" % [role, mode])


func test_buildings_portals() -> void:
	var m: Dictionary = _json(BAKED + "manifest.json")
	check_eq(m["buildings"]["catalogue"].size(), 10, "catalogue de bâtiments")
	for art: String in m["buildings"]["arts"]:
		_texture(BAKED + "buildings/%s_base.png" % art)
		_check_sheet(BAKED + "buildings/%s_anim.png" % art, m["buildings"]["arts"][art]["anim"], art)
	var weapon := _texture(BAKED + "buildings/ballista_weapon.png")
	if weapon:
		check(weapon.get_width() <= 8192 and weapon.get_height() <= 8192, "planche de baliste ≤ 8192 px (WebGL 2)")
	_texture(BAKED + "portals/deity_off.png")
	for d in ["indra", "sigil", "medeina", "aether"]:
		_check_sheet(BAKED + "portals/deity_%s.png" % d, m["portals"]["deity"][d], "portail " + d)
	_check_sheet(BAKED + "portals/evil.png", m["portals"]["evil"]["sheet"], "portail maléfique")
	_texture("res://assets/imported/portal/portal_atlas.png")


func test_fixtures_present() -> void:
	const Fixtures := preload("res://tests/fixtures.gd")
	check_eq(Fixtures.load_json("projection")["points"].size(), 20, "projection")
	check_eq(Fixtures.load_json("galleries")["results"].size(), 5, "galeries (5 graines)")
	check_eq(Fixtures.load_json("walkable")["samples"].size(), 4000, "praticabilité")
	check_eq(Fixtures.load_json("paths")["paths"].size(), 30, "chemins A*")
	var dig: Dictionary = Fixtures.load_json("dig_scenario")
	check(dig["cells"].size() > 0 and int(dig["found"]) >= 1, "scénario de creusement qui révèle une galerie")
	for f in ["wind", "noise", "rng"]:
		check(not Fixtures.load_json(f).is_empty(), "fixture " + f)


## Étape 12 : planche commune du décor (tools/baker/decor_atlas.py) identique aux sprites extraits, et
## métadonnées du feuillage (ancre, type d'arbre) cohérentes avec le décor et Wind.TREES.
func test_decor_atlas_matches_sprites() -> void:
	var meta: Dictionary = _json(BAKED + "world/decor_atlas.json")
	check_eq(meta["kinds"], Wind.TREES.keys(), "ordre des types d'arbres = Wind.TREES")
	# Fichiers PNG bruts : l'import de Godot recolore les pixels transparents (« fix alpha border »)
	# différemment selon l'image, sans effet visible (vérifié par les scénarios visuels).
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(BAKED + "world/decor_atlas.png"))
	var marks := Image.load_from_file(ProjectSettings.globalize_path(BAKED + "world/decor_atlas_meta.png"))
	atlas.convert(Image.FORMAT_RGBA8)
	var sprites: Dictionary = _json(BAKED + "world/decor_sprites.json")
	var bad := 0
	var n := 0
	for id: String in meta["sprites"]:
		var r: Array = meta["sprites"][id]
		var path := BAKED + ("world/sprites/%s.png" % id if sprites.has(id) else "world/runtime/%s.png" % id)
		var src := Image.load_from_file(ProjectSettings.globalize_path(path))
		src.convert(Image.FORMAT_RGBA8)
		var part := atlas.get_region(Rect2i(r[0], r[1], r[2], r[3]))
		part.convert(Image.FORMAT_RGBA8)
		if part.get_data() != src.get_data():
			bad += 1
		n += 1
	check_eq(bad, 0, "%d sprites de la planche identiques aux sprites extraits" % n)
	var runtime := Array(DirAccess.get_files_at(BAKED + "world/runtime")).filter(func(f: String) -> bool: return f.ends_with(".png"))
	check_eq(n, sprites.size() + runtime.size(),
		"tous les sprites du décor sont dans la planche")
	# Un repère par feuillage, à son point d'ancrage : (255, ay, type, 255).
	var leaves := 0
	for id: String in sprites:
		if sprites[id].has("foliage"):
			var fid: String = sprites[id]["foliage"]
			var r: Array = meta["sprites"][fid]
			var c := marks.get_pixel(int(r[0]) + int(sprites[fid]["ax"]), int(r[1]) + int(sprites[fid]["ay"]))
			if roundi(c.r * 255) != 255 or roundi(c.g * 255) != int(sprites[fid]["ay"]):
				leaves = -9999
			leaves += 1
	check(leaves > 0, "repères de feuillage présents et exacts (%d)" % leaves)
