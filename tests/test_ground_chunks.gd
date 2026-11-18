extends "res://tests/test_case.gd"
## Monde procédural, étape 3 : sol en blocs sur toute la carte, blocs vierges matérialisés à la demande.


func test_lazy_blocks_cover_map_and_materialize_on_paint() -> void:
	var t := Terrain.new()
	t.build()
	var corner := t._px(CaveShape.WORLD_X0, CaveShape.WORLD_Z0)
	check(t.get_ground_pixel(corner.x, corner.y).a > 0.0, "coin nord-ouest couvert")
	var p := t._px(-400.0, -600.0)
	var before := t.get_ground_pixel(p.x, p.y)
	var key := Vector2i(floori(p.x / 1024.0), floori(p.y / 1024.0))
	check(t._plain.get(key) == "rock", "bloc de roche vierge non matérialisé")
	var n := t.materialized
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	t.blit(img, p.x + 100, p.y)
	check_eq(t.materialized, n + 1, "un seul bloc matérialisé au premier coup de pinceau")
	check_eq(t.get_ground_pixel(p.x, p.y), before, "sol vierge identique une fois matérialisé")
	check_eq(t.get_ground_pixel(p.x + 100, p.y), Color.RED, "peinture appliquée")
	var g := t._px(-400.0, 40.0)
	check(t.get_ground_pixel(g.x, g.y).g > t.get_ground_pixel(g.x, g.y).b, "jungle élargie en herbe")
	t.free()
