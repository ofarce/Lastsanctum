extends Node
## Capture de la visée, de la pose et du chantier (planches/pose-rendu-propositions.html, piste B ;
## chantier-debut-propositions.html, piste C) : Forge, Temple d'Indra et Bibliothèque en visée impossible,
## en visée possible, puis à 0,05 s, 0,2 s, 0,4 s et 0,7 s du clic, à 40 % et à 95 % du chantier.
## godot --path . res://tests/visual/site_capture.tscn
const OUT := "res://tests/visual/out/chantier.png"
const ARTS := [["da-forge", 8.0], ["da-indra", 4.0], ["da-library", 8.0]]
## Négatif : visée (−2 impossible, −1 possible). Jusqu'à 1 : secondes depuis le clic. Au-delà : 1 + part du chantier.
const KEYS := [-2.0, -1.0, 0.05, 0.2, 0.4, 0.7, 1.4, 1.95]
const VIEW := Rect2(92, 96, 136, 112)

var _vp: SubViewport
var _frames := 0


class Board extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 136 * 8, 112 * 3), Color("#2b342c"))
		for r in ARTS.size():
			var S := BuildingView.site(ARTS[r][0])
			for c in KEYS.size():
				draw_set_transform(Vector2(c * VIEW.size.x, r * VIEW.size.y) - VIEW.position)
				var k: float = KEYS[c]
				if k < 0.0:
					BuildingView.draw_ghost(self, S, k > -1.5)
				else:
					BuildingView.draw_site(self, S, k - 1.0 if k > 1.0 else k / ARTS[r][1], ARTS[r][1])
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(VIEW.size.x) * KEYS.size(), int(VIEW.size.y) * ARTS.size())
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_vp.add_child(Board.new())


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 4:
		return
	var img := _vp.get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("capture : ", OUT)
	get_tree().quit()
