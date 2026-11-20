extends RefCounted
## Icône de roche partagée entre inventaires et objets au sol.
const Blocks := preload("res://data/mineable_blocks.gd")
const Gear := preload("res://data/gear_items.gd")
## Ordre de la bande assets/ardoise/ui/items.png (tools/objets/objets.py, ORDER) : style A « Objet franc ».
const ITEM_ORDER := ["wood", "rock", "torch", "pickaxe", "arrows", "bow", "sword", "shield", "chest", "wood_fiber",
		"firing_post", "barricade", "fishing_rod", "caltrops", "copper_ingot", "iron_ingot", "gold_ingot"]


## Butins courants (sim/loot.gd), dessinés en aplats sur une grille 16 × 16 : [x, y, largeur, hauteur, couleur].
const LOOT_ICONS := {
	"ichor": [[6, 2, 4, 2, "#1a0608"], [5, 4, 6, 2, "#1a0608"], [4, 6, 8, 6, "#1a0608"], [5, 12, 6, 1, "#1a0608"],
		[7, 3, 2, 2, "#8a1f2c"], [6, 5, 4, 2, "#8a1f2c"], [5, 7, 6, 4, "#8a1f2c"], [6, 11, 4, 1, "#4a1018"], [8, 9, 3, 2, "#4a1018"], [6, 7, 1, 2, "#d85a5a"]],
	"acid_gland": [[4, 4, 8, 9, "#16240a"], [7, 1, 3, 3, "#16240a"], [8, 2, 1, 2, "#6a8a2a"], [5, 5, 6, 7, "#9ac83a"], [6, 4, 4, 1, "#9ac83a"],
		[9, 9, 2, 3, "#5a7a22"], [5, 11, 6, 1, "#5a7a22"], [6, 6, 2, 2, "#e0f49a"]],
	"focus_staff": [[10, 1, 5, 5, "#0a3a2a"], [11, 2, 3, 3, "#5ce8a8"], [11, 2, 1, 1, "#eafff4"], [9, 5, 3, 2, "#1c1008"], [8, 6, 3, 3, "#1c1008"], [6, 8, 3, 3, "#1c1008"],
		[4, 10, 3, 3, "#1c1008"], [2, 12, 3, 3, "#1c1008"], [10, 5, 1, 1, "#a8743a"], [9, 6, 1, 1, "#a8743a"], [8, 7, 1, 1, "#7a4c24"], [7, 8, 1, 1, "#a8743a"],
		[6, 9, 1, 1, "#7a4c24"], [5, 10, 1, 1, "#a8743a"], [4, 11, 1, 1, "#7a4c24"], [3, 12, 1, 1, "#a8743a"], [3, 13, 1, 1, "#7a4c24"]],
	"volt_organ": [[4, 3, 8, 11, "#0a1440"], [5, 4, 6, 9, "#2a4ac0"], [6, 5, 4, 7, "#6a9aff"], [7, 6, 2, 3, "#c0dcff"], [7, 6, 1, 1, "#ffffff"], [3, 6, 1, 2, "#c0dcff"],
		[12, 8, 1, 2, "#c0dcff"], [7, 1, 2, 2, "#061014"], [7, 14, 2, 1, "#061014"]],
	"guano": [[3, 9, 11, 5, "#2a2620"], [5, 5, 7, 5, "#2a2620"], [7, 2, 4, 4, "#2a2620"], [4, 10, 9, 3, "#c8c2ac"], [6, 6, 5, 4, "#c8c2ac"], [8, 3, 2, 3, "#eee8d4"],
		[6, 6, 2, 1, "#eee8d4"], [5, 10, 3, 1, "#eee8d4"], [9, 12, 4, 1, "#8a8474"]],
	"module_veil": [[2, 2, 12, 12, "#0a3a48"], [3, 3, 10, 10, "#12596b"], [5, 4, 6, 1, "#c8fbff"], [4, 5, 8, 1, "#5ce8ff"], [4, 6, 8, 5, "#1f9fb8"],
		[5, 6, 1, 6, "#c8fbff"], [8, 6, 1, 7, "#5ce8ff"], [11, 6, 1, 5, "#c8fbff"], [6, 11, 2, 2, "#1f9fb8"], [9, 11, 2, 1, "#1f9fb8"]],
	"module_drill": [[2, 2, 12, 12, "#0a3a48"], [3, 3, 10, 10, "#12596b"], [5, 4, 6, 2, "#c8fbff"], [5, 6, 6, 2, "#5ce8ff"], [6, 8, 4, 2, "#c8fbff"], [6, 10, 4, 1, "#5ce8ff"],
		[7, 11, 2, 2, "#c8fbff"], [5, 5, 6, 1, "#1f9fb8"], [6, 7, 4, 1, "#1f9fb8"], [7, 9, 2, 1, "#1f9fb8"]],
	"module_iris": [[2, 2, 12, 12, "#0a3a48"], [3, 3, 10, 10, "#12596b"], [4, 6, 8, 4, "#c8fbff"], [5, 5, 6, 6, "#c8fbff"], [6, 6, 4, 4, "#1f9fb8"],
		[7, 7, 2, 2, "#0a1a20"], [7, 6, 1, 1, "#ffffff"], [3, 7, 1, 2, "#5ce8ff"], [12, 7, 1, 2, "#5ce8ff"]],
	"ration": [[2, 5, 12, 9, "#2a1a0e"], [3, 7, 10, 5, "#c8a676"], [4, 6, 8, 1, "#ecd6a4"], [4, 12, 8, 1, "#7a5a38"],
		[5, 8, 1, 3, "#8a6a48"], [8, 8, 1, 3, "#8a6a48"], [11, 8, 1, 3, "#8a6a48"]],
}


static func draw_item(canvas: CanvasItem, item: String, center: Vector2, scale_factor: float) -> void:
	var gear: Dictionary = Gear.ITEMS.get(item, {})
	if not gear.is_empty() and not LOOT_ICONS.has(item):
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
	if LOOT_ICONS.has(item):
		var u := 2.0 * scale_factor
		var o := (center - Vector2.ONE * 16.0 * scale_factor).round()
		for r: Array in LOOT_ICONS[item]:
			canvas.draw_rect(Rect2(o + Vector2(r[0], r[1]) * u, Vector2(r[2], r[3]) * u), Color(r[4]))
		return
	var initial :=preload("res://data/recipes.gd").name_of(item).left(1).to_upper()
	var font := ThemeDB.fallback_font
	var font_size := maxi(1, roundi(15 * scale_factor))
	var width := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, center + Vector2(-width / 2, font_size * 0.35), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
