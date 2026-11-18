extends RefCounted
## Icône de roche partagée entre inventaires et objets au sol.
const Blocks := preload("res://data/mineable_blocks.gd")
const Gear := preload("res://data/gear_items.gd")
## Ordre de la bande assets/ardoise/ui/items.png (tools/objets/objets.py, ORDER) : style A « Objet franc ».
const ITEM_ORDER := ["wood", "rock", "torch", "pickaxe", "arrows", "bow", "sword", "shield", "chest", "wood_fiber",
		"firing_post", "barricade", "fishing_rod", "caltrops", "copper_ingot", "iron_ingot", "gold_ingot"]


static func draw_item(canvas: CanvasItem, item: String, center: Vector2, scale_factor: float) -> void:
	var gear: Dictionary = Gear.ITEMS.get(item, {})
	if not gear.is_empty():
		# Arme du Creuset : son icône 32 × 32 dessinée (planches/armes-creuset.html).
		var wi := TyrienArt.weapon_icon(item)
		if wi:
			var ws := Vector2.ONE * 32 * scale_factor
			canvas.draw_texture_rect(wi, Rect2((center - ws * 0.5).round(), ws), false)
			return
		# Pièce d'équipement : son calque de repos, recadré et agrandi (pixels entiers).
		var tex := TyrienArt.icon(gear["piece"])
		if tex:
			var k := maxf(1.0, floorf(minf(28.0 / tex.region.size.x, 28.0 / tex.region.size.y) * scale_factor / 1.8))
			var size := tex.region.size * k
			canvas.draw_texture_rect(tex, Rect2((center - size * 0.5).round(), size), false)
			return
	var ore := Blocks.ORES.find(item)
	if ore >= 0:
		var size := Vector2.ONE * 32 * scale_factor
		canvas.draw_texture_rect_region(preload("res://assets/ardoise/world/nodules.png"),
				Rect2(center - size * 0.5, size), Rect2(ore * 32, 64, 32, 32))
		return
	var drawn := ITEM_ORDER.find(item)
	if drawn >= 0:
		var size := Vector2.ONE * 32 * scale_factor
		canvas.draw_texture_rect_region(preload("res://assets/ardoise/ui/items.png"),
				Rect2(center - size * 0.5, size), Rect2(drawn * 32, 0, 32, 32))
		return
	var initial :=preload("res://data/recipes.gd").name_of(item).left(1).to_upper()
	var font := ThemeDB.fallback_font
	var font_size := maxi(1, roundi(15 * scale_factor))
	var width := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, center + Vector2(-width / 2, font_size * 0.35), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
