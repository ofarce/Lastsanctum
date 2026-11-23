extends SceneTree
## Aperçu des biomes en salles (world/terrain/room_layout.gd), aux couleurs de planches/biomes-salles-structure.html :
##   godot --headless --path . -s res://tools/worldgen/rooms_preview.gd -- <graine> <sortie.png> [échelle]
## Une bande par biome, des Veines (2) aux Cryptes (8), du sud en bas au nord en haut. Le Temple aura sa variante.

const COL := {
	"L": Color("#c98a7a"), "M": Color("#d0584a"), "D": Color("#a01e2a"), "resource": Color("#c0703f"),
	"calm": Color("#6fc27a"), "secret": Color("#1e1530"), "miniboss": Color("#e8923a"), "boss": Color("#e0303a"),
	"transit": Color("#6b7a96"),
}
const ROCK := Color("#141922")
const CORRIDOR := Color("#3a3f52")
const WALL := Color("#000000")
const DOOR := Color("#ddb457")
const PORTAL := Color("#5fd8e8")
const PYLON := Color("#c2202a")
const GAP := 6


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 20261114
	var out := args[1] if args.size() > 1 else "user://rooms_preview.png"
	var s := int(args[2]) if args.size() > 2 else 3
	# Du nord (Cryptes) en haut au sud (Temple) en bas, comme sur la carte.
	var lays: Array[Dictionary] = []
	for k in range(Biomes.LIST.size() - 1, 0, -1):
		lays.append(RoomLayout.build(RoomLayout.band_rect(k), map_seed ^ k * 7919, 0.0))
	lays.append(RoomLayout.build_temple(map_seed))
	var w := 0
	var h := 0
	for lay in lays:
		var band: Rect2i = lay["band"]
		w = maxi(w, band.size.x * s)
		h += band.size.y * s + GAP
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color("#0b0a0f"))
	var y := 0
	for lay in lays:
		var band: Rect2i = lay["band"]
		_draw(img, lay, Vector2i(-band.position.x, -band.position.y), y, s)
		y += band.size.y * s + GAP
	img.save_png(out)
	print("Aperçu : ", out, " (", w, " × ", h, ")")
	quit()


func _draw(img: Image, lay: Dictionary, off: Vector2i, y0: int, s: int) -> void:
	var band: Rect2i = lay["band"]
	var cell := func(c: Vector2i, col: Color) -> void:
		var p := (c + off) * s
		if p.x >= 0 and p.y >= 0 and p.x < band.size.x * s and p.y < band.size.y * s:
			img.fill_rect(Rect2i(p.x, p.y + y0, s, s), col)
	img.fill_rect(Rect2i(0, y0, band.size.x * s, band.size.y * s), ROCK)
	for l: Dictionary in lay["links"]:
		var col := Color("#6a4f8a") if l["kind"] == "secret" else CORRIDOR
		for c in RoomLayout.corridor_cells(l["path"]):
			cell.call(c, col)
	for c in RoomLayout.corridor_cells(lay["arrival"]):
		cell.call(c, CORRIDOR)
	for c: Vector2i in lay["walls"]:
		cell.call(c, WALL)
	for key: String in lay["doors"]:
		for c: Vector2i in lay["doors"][key]:
			cell.call(c, DOOR)
	for r: Dictionary in lay["rooms"]:
		var rect: Rect2i = r["rect"]
		var col: Color = COL[r["tier"]] if r["kind"] == "combat" else COL[r["kind"]]
		# Grotte et salle de l'Œil du Temple : elles existent déjà, dessinées en clair.
		if r.get("fixed", false):
			col = col.lightened(0.45)
		for i in range(rect.position.x, rect.end.x):
			for j in range(rect.position.y, rect.end.y):
				var edge := i == rect.position.x or j == rect.position.y or i == rect.end.x - 1 or j == rect.end.y - 1
				cell.call(Vector2i(i, j), Color("#b07ae0") if r["kind"] == "secret" and edge else col.darkened(0.25) if edge else col)
		if r["quarter"] == "C" and r["kind"] == "combat":
			cell.call(rect.position + Vector2i(1, 1), Color("#ffffff"))
		if r["portal"]:
			cell.call(Vector2i(rect.end.x - 2, rect.position.y + 1), PORTAL)
		if r["pylon"]:
			cell.call(rect.position + Vector2i(1, rect.size.y - 2), PYLON)
