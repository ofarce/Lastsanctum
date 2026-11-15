extends "res://tests/test_case.gd"
## Étape 6 (v2) : le fond de la minicarte (buildMiniMap) est dessiné comme dans le prototype, avant et
## après le scénario de creusement. Référence : assets/baked/hud/minimap_*.png (tools/baker/hud.js).
## Les rectangles fractionnaires sont lissés par couverture comme le canvas 2D ; les arrondis de mélange
## peuvent différer d'une ou deux unités.

const Fixtures := preload("res://tests/fixtures.gd")
const TOLERANCE := 6
const MIN_MATCH := 99.0


func _minimap() -> Minimap:
	var m := Minimap.new()
	m._meta = JSON.parse_string(FileAccess.get_file_as_string(Minimap.META))
	return m


## Pourcentage de pixels à ±TOLERANCE sur chaque canal.
static func match_pct(a: Image, b: Image) -> float:
	var ok := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absi(p.r8 - q.r8) <= TOLERANCE and absi(p.g8 - q.g8) <= TOLERANCE and absi(p.b8 - q.b8) <= TOLERANCE:
				ok += 1
	return 100.0 * ok / (a.get_width() * a.get_height())


func _reference(name: String) -> Image:
	var img := Image.new()
	img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/baked/hud/%s.png" % name))
	img.convert(Image.FORMAT_RGB8)
	return img


func test_background_matches_js() -> void:
	var f := Fixtures.load_json("dig_scenario")
	var state := TerrainState.new()
	state.generate_galleries(int(f["seed"]))
	var m := _minimap()
	m.build_background(state)
	var pct := match_pct(m.background(), _reference("minimap_initial"))
	print("     (minicarte initiale : %.2f %% à ±%d)" % [pct, TOLERANCE])
	check(pct >= MIN_MATCH, "fond initial : %.2f %% à ±%d" % [pct, TOLERANCE])
	m.free()


func test_background_after_dig_matches_js() -> void:
	var f := Fixtures.load_json("dig_scenario")
	var state := TerrainState.new()
	state.generate_galleries(int(f["seed"]))
	var reg := DecorRegistry.new()
	var ops := TerrainOps.new(state, reg)
	for c: Array in f["cells"]:
		ops.dig_cell(int(c[0]), int(c[1]))
	check(state.found > 0, "galerie découverte")
	var m := _minimap()
	m.build_background(state)
	var pct := match_pct(m.background(), _reference("minimap_dig"))
	print("     (minicarte après creusement : %.2f %% à ±%d)" % [pct, TOLERANCE])
	check(pct >= MIN_MATCH, "fond après creusement : %.2f %% à ±%d" % [pct, TOLERANCE])
	m.free()
