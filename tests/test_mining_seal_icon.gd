extends "res://tests/test_case.gd"


func test_icon_respects_requested_size_and_remains_cached() -> void:
	for px: int in [18, 32, 64]:
		var texture := HudStyle.icon("mining_seal", px)
		check_eq(texture.get_size(), Vector2(px, px), "dimensions du sceau")
		var weak: WeakRef = weakref(texture)
		texture = null
		check(weak.get_ref() != null, "texture conservée après le dessin")
		check_eq(HudStyle.icon("mining_seal", px), weak.get_ref(), "texture partagée et stable")
