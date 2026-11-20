class_name ActionButton
extends BaseButton
## Bouton du panneau d'ordres (.action, hud.css, et style en ligne d'Index.html, 73b410f) :
## icône de 18 px, libellé de 10 px sur deux lignes au plus, touche (kbd), recharge en haut à droite.
## États : normal, survolé ou actif (laiton éclairé), désactivé (gris).

var action: Dictionary = {}
var _icon := TextureRect.new()
var _label := HudStyle.label(10, HudStyle.IVORY)
## Le libellé est rogné par ce conteneur (overflow: hidden) plutôt que par le Label, qui masquerait
## toute ligne incomplète.
var _label_clip := Control.new()
var _kbd := HudStyle.label(9, HudStyle.IVORY)
var _cd := HudStyle.label(10, Color("#d8bf8d"))
var _icon_name := ""
var _action_sig: Array = []
## Bouton à glyphe (fabrication « craft_item », recherche « research_icon », unité « unit_sprite ») : l'objet ou le
## sprite et, par-dessus, compteur, jauge, cadenas et cachet.
var _glyph := _Glyph.new()
var _over := _Over.new()


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Coupure aux espaces seulement (un mot trop long déborde et est rogné, comme en CSS).
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_constant_override("line_spacing", -3)
	_label_clip.clip_contents = true
	_label_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_clip.add_child(_label)
	add_child(_label_clip)
	_kbd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_kbd)
	_cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_cd)
	for c: Control in [_glyph, _over]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
	_over.button = self
	# La touche passe au-dessus du glyphe (plaque d'émail des commandes) et de son cadre, posé par _Over.
	move_child(_kbd, -1)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func set_action(a: Dictionary) -> void:
	# Le HUD repasse la même action dix fois par seconde : sans changement (hors « run », un Callable recréé à
	# chaque fois), ni mise en page ni redessin.
	var sig: Array = []
	for k: Variant in a:
		var v: Variant = a[k]
		if not v is Callable:
			sig.append(k)
			sig.append(v)
	if sig == _action_sig and not action.is_empty():
		action = a
		return
	_action_sig = sig
	action = a
	disabled = a["disabled"]
	var craft := _glyph_mode(a)
	# Fabrication, recherche, unité : nom et coût dans la bulle du HUD au survol, pas d'info-bulle.
	tooltip_text = "" if craft else (a["title"] if a["title"] else a["label"])
	_glyph.visible = craft
	_over.visible = craft
	_icon.visible = not craft
	_label_clip.visible = not craft
	_cd.visible = not craft
	if craft:
		_glyph.button = self
		_glyph.item = a.get("craft_item", "")
		_glyph.modulate = Color(0.42, 0.42, 0.4) if disabled and a.has("craft_item") else Color.WHITE
		_glyph.queue_redraw()
	_kbd.visible = not a.get("research_done", false) and (a["key"] != "" or not craft)
	if _icon_name != a["icon"]:
		_icon_name = a["icon"]
		_icon.texture = HudStyle.icon(_icon_name, 18, 1.6)
	_label.text = a["label"]
	var k: String = a["key"]
	_kbd.text = ("Espace" if k == " " else k.to_upper()) if craft or not a.get("status", "") else a["status"]
	_cd.text = a.get("cost_text", a["cooldown"])
	_cd.add_theme_font_size_override("font_size", 9 if a.has("cost_text") else 10)
	_relayout()
	queue_redraw()


func _lit() -> bool:
	if _sheet():
		return not _dim() and not action.get("research_done", false) and (action.get("active", false) or is_hovered())
	return not disabled and (action.get("active", false) or is_hovered())


static func _glyph_mode(a: Dictionary) -> bool:
	return a.has("craft_item") or a.has("research_icon") or a.has("unit_sprite") or a.has("command_icon")


## Recherche ou unité : le bouton reste lisible quand il est indisponible pour une raison passagère (mana, en cours,
## achevée) ; seul « locked » (prérequis, objets manquants) l'assombrit.
func _sheet() -> bool:
	return action.has("research_icon") or action.has("unit_sprite") or action.has("command_icon")


func _dim() -> bool:
	return action.get("locked", false) if _sheet() else disabled


func _relayout() -> void:
	if _glyph_mode(action):
		_relayout_craft()
		return
	# Colonne flexible centrée (bordure 1, marge 2) : icône 18, écart 1, libellé, écart 1, touche 13.
	# Le libellé (11 px par ligne, 2 lignes au plus) se rétrécit quand la place manque : dans la grille
	# de 2 rangées du prototype, il ne reste qu'environ 9,5 px, soit une ligne un peu rognée.
	var lines := clampi(_label.get_line_count(), 1, 2) if _label.text else 1
	var avail := size.y - 6.0 - 18.0 - 13.0 - 2.0
	# Jamais de libellé rogné : il s'affiche par lignes entières, ou pas du tout (l'icône et la touche restent,
	# le nom est dans l'infobulle) quand la hauteur manque ou qu'un mot dépasse la largeur du bouton.
	var widest := 0.0
	for word in _label.text.split(" ", false):
		widest = maxf(widest, HudStyle.text_width(word, 10))
	var shown := mini(lines, int(avail / 10.0))
	if widest > size.x - 2.0:
		shown = 0
	var label_h := 11.0 * shown
	_label.max_lines_visible = maxi(shown, 1)
	var kbd_w := maxf(19.0, HudStyle.text_width(_kbd.text, 9) + 8.0)
	var total := 18.0 + 1.0 + label_h + 1.0 + 13.0
	var top := (size.y - total) / 2.0
	_icon.position = Vector2((size.x - 18.0) / 2.0, top)
	_icon.size = Vector2(18, 18)
	_label_clip.position = Vector2(1.0, top + 19.0)
	_label_clip.size = Vector2(size.x - 2.0, label_h)
	_label.position = Vector2(0.0, -2.0)
	_label.size = Vector2(size.x - 2.0, 26.0)
	_kbd.position = Vector2((size.x - kbd_w) / 2.0, top + 19.0 + label_h + 1.0)
	_kbd.size = Vector2(kbd_w, 13.0)
	_cd.position = Vector2(size.x - 44.0, 2.0)
	_cd.size = Vector2(40.0, 12.0)
	if action.has("cost_text"):
		_icon.position.x = 3.0
		_cd.position = Vector2(size.x - 43.0, top + 2.0)
		_cd.size = Vector2(41.0, 14.0)
	var fg := Color("#7c7c6c") if disabled else (Color("#ffe5ac") if _lit() else HudStyle.IVORY)
	_label.add_theme_color_override("font_color", fg)
	_kbd.add_theme_color_override("font_color", Color("#7ae070") if action.get("completed", false) else fg)
	_icon.modulate = Color("#727263") if disabled else (Color("#ffe1a3") if _lit() else Color("#e9ce9e"))
	if _icon_name == "mining_seal":
		_icon.modulate = Color("#727263") if disabled else Color.WHITE
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE


## Piste 1 « Laiton et objet franc » : objet centré à 32 px (pixels entiers), touche en cartouche en haut à gauche.
func _relayout_craft() -> void:
	var kbd_w := maxf(13.0, HudStyle.text_width(_kbd.text, 9) + 6.0)
	_kbd.position = Vector2(3.0, 3.0)
	_kbd.size = Vector2(kbd_w, 12.0)
	var kc := Color("#7c7c6c") if _dim() else (Color("#ffe5ac") if _lit() else HudStyle.IVORY)
	if action.get("poor", false):
		kc = Color("#f0a090")
	_kbd.add_theme_color_override("font_color", kc)
	if action.has("unit_sprite") or action.has("command_icon"):
		_glyph.position = Vector2(2, 2)
		_glyph.size = size - Vector2(4, 4)
	else:
		_glyph.position = Vector2(floorf((size.x - 32.0) / 2.0), floorf((size.y - 32.0) / 2.0) - 1.0)
		_glyph.size = Vector2(32, 32)
	_over.position = Vector2.ZERO
	_over.size = size
	_over.queue_redraw()
	_glyph.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _draw() -> void:
	_relayout()
	var r := Rect2(Vector2.ZERO, size)
	var dim := _dim()
	if action.get("research_done", false):
		# Recherche achevée : fond vert sombre, filet olive ; le cachet vert est posé par _Over.
		HudStyle.linear_gradient(self, r, 145.0, [[0.0, Color("#1e2618")], [0.65, Color("#141b12")], [1.0, Color("#121810")]])
		HudStyle.ring(self, r.grow(-1.0), 3.0, Color("#131710"))
		HudStyle.ring(self, r, 1.0, Color("#7c8a58"))
		return
	if _lit():
		# radial-gradient(ellipse at 50% 30%, #77521999, #201e12 85%) ; anneau intérieur #c29148 ; halo.
		draw_rect(r, Color("#201e12"))
		var c := Vector2(size.x * 0.5, size.y * 0.3)
		for i in range(12, 0, -1):
			var t := float(i) / 12.0
			var rad := Vector2(size.x, size.y) * 0.85 * t
			var col := Color("#775219").lerp(Color("#201e12"), t)
			var pts := PackedVector2Array()
			for k in 32:
				var ang := TAU * k / 32.0
				var p := c + Vector2(cos(ang) * rad.x, sin(ang) * rad.y)
				pts.append(p.clamp(Vector2.ZERO, size))
			draw_colored_polygon(pts, Color(col, 0.6))
		HudStyle.ring(self, r.grow(-1.0), 2.0, Color("#c29148"))
		HudStyle.ring(self, r, 1.0, Color("#ffe0a0"))
		if action.has("command_icon") and action.get("active", false):
			# Ordre armé : second filet clair.
			HudStyle.ring(self, r.grow(-3.0), 1.0, Color("#ffe0a0"))
	else:
		var a := Color("#24261f") if dim else Color("#2d2b21")
		var b := Color("#101510") if dim else Color("#121712")
		HudStyle.linear_gradient(self, r, 145.0, [[0.0, a], [0.65, b], [1.0, b]])
		HudStyle.ring(self, r.grow(-1.0), 3.0, Color("#131710"))
		HudStyle.ring(self, r, 1.0, Color("#565443") if dim else Color("#aa8851"))
	# Cadre de la touche (grenat quand le mana manque).
	if not _kbd.visible:
		return
	var kr := Rect2(_kbd.position, _kbd.size)
	draw_rect(kr, Color("#10140d"))
	var kc := Color("#4d4f40") if dim else Color("#8c744b")
	if action.get("poor", false):
		kc = Color("#c0584c")
	draw_rect(kr.grow(-0.5), kc, false, 1.0)


func _pressed() -> void:
	if not disabled and action.has("run"):
		Sfx.play("ui_clic")
		(action["run"] as Callable).call()


## L'objet fabriqué, depuis la bande d'icônes de l'inventaire ; « collect » = coffre rouge et flèche montante.
## Recherche : l'objet au trait d'or, la couleur qui monte de bas en haut pendant la recherche, en couleur une fois
## achevée. Unité : le sprite du portrait (assets/baked/hud/portraits), réduit au pixel près.
class _Glyph extends Control:
	const Icon := preload("res://ui/inventory/item_icon.gd")
	const STRIP := preload("res://assets/ardoise/ui/items.png")
	const PORTRAITS := "res://assets/baked/hud/portraits/%s.png"
	const RESEARCH_ICONS := {"minimap": preload("res://assets/ui/research/minimap.png"),
		"modular_crossbow": preload("res://assets/ui/research/barillet.png"),
		# Biomes 1 et 2 (tools/biomes-persos/icones_recherche.py).
		"gallery_props": preload("res://assets/ui/research/gallery_props.png"), "sylviculture": preload("res://assets/ui/research/sylviculture.png"),
		"fletching": preload("res://assets/ui/research/fletching.png"), "palisades": preload("res://assets/ui/research/palisades.png"),
		"limbo_mastery": preload("res://assets/ui/research/limbo_mastery.png"), "copper_seal": preload("res://assets/ui/research/copper_seal.png"),
		"copper_tips": preload("res://assets/ui/research/copper_tips.png"), "verdigris_balm": preload("res://assets/ui/research/verdigris_balm.png")}
	const GOLD := Color("#e8c060")
	const GOLD_LIT := Color("#fff0a8")
	const ASH := Color("#6a6a58")
	static var _full := {}
	static var _sketch := {}
	static var _units := {}
	static var _commands := {}
	const ENAMEL := {"c": [Color("#5a3a10"), Color("#a06a1c"), Color("#e8a840")],
		"a": [Color("#14404a"), Color("#2a7a88"), Color("#5fc8d8")],
		"f": [Color("#4a1414"), Color("#8a2a24"), Color("#d0584a")],
		"n": [Color("#2a2e36"), Color("#4e5866"), Color("#8a94a2")]}
	const ENAMEL_LOCKED := [Color("#1a1c17"), Color("#2a2c24"), Color("#3a3c32")]
	var button: ActionButton
	var item := "":
		set(v):
			if v != item:
				item = v
				queue_redraw()

	func _draw() -> void:
		var a: Dictionary = button.action if button else {}
		if a.has("research_icon"):
			_draw_research(a)
			return
		if a.has("unit_sprite"):
			_draw_unit(a)
			return
		if a.has("command_icon"):
			_draw_command(a)
			return
		if item == "collect":
			var chest := Icon.ITEM_ORDER.find("chest")
			draw_texture_rect_region(STRIP, Rect2(0, 3, 32, 32), Rect2(chest * 32, 0, 32, 32), Color("#e27a66"))
			var arrow := PackedVector2Array([Vector2(16, 0), Vector2(23, 7), Vector2(19, 7), Vector2(19, 12),
				Vector2(13, 12), Vector2(13, 7), Vector2(9, 7)])
			draw_colored_polygon(arrow, HudStyle.IVORY)
			draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color("#0b090b"), 1.0)
			return
		Icon.draw_item(self, item, Vector2(16, 16), 1.0)

	func _draw_research(a: Dictionary) -> void:
		var id: String = a["research_icon"]
		var full := _full_tex(id)
		var r := Rect2(0, 0, 32, 32)
		if a.get("research_done", false):
			draw_texture_rect(full, r, false)
			return
		var ink := ASH if a.get("locked", false) else (GOLD_LIT if button.is_hovered() else GOLD)
		draw_texture_rect(_sketch_tex(id), r, false, ink)
		if a.get("active", false):
			var h := roundf(32.0 * clampf(a.get("craft_progress", 0.0), 0.0, 1.0))
			if h > 0.0:
				draw_texture_rect_region(full, Rect2(0, 32.0 - h, 32, h), Rect2(0, 32.0 - h, 32, h))

	## Plaque d'émail de la famille, filet d'or, pictogramme ivoire (ombre teintée de l'émail).
	func _draw_command(a: Dictionary) -> void:
		var locked: bool = a.get("locked", false)
		var E: Array = ENAMEL_LOCKED if locked else ENAMEL[a.get("family", "n")]
		var lit: bool = button.is_hovered() or a.get("active", false)
		var pw := minf(40.0, size.x - 10.0)
		var ph := minf(36.0, size.y - 4.0)
		var pr := Rect2(floorf((size.x - pw) / 2.0) + 3.0, floorf((size.y - ph) / 2.0), pw, ph)
		draw_rect(pr.grow(1.0), Color("#4d4f40") if locked else Color("#c29148"))
		draw_rect(pr, Color("#0b090b"))
		var inner := pr.grow(-1.0)
		draw_rect(inner, E[1] if lit else E[0])
		# Reflet central de l'émail (dégradé radial grossier, au pixel).
		for i in 3:
			var k := 0.62 - i * 0.18
			var rr := Rect2(inner.get_center() - inner.size * k * Vector2(0.5, 0.45), inner.size * k * Vector2(1.0, 0.9))
			draw_rect(rr.abs(), Color(E[2] if lit else E[1], 0.35))
		var tex := _command_tex(a["command_icon"], a.get("family", "n"), locked)
		draw_texture_rect(tex, Rect2((pr.get_center() - Vector2(16, 16)).floor(), Vector2(32, 32)), false)

	func _draw_unit(a: Dictionary) -> void:
		var h := mini(34, int(size.y) - 4)
		var tex := _unit_tex(a["unit_sprite"], h, int(size.x) - 8)
		if tex == null:
			return
		var s := Vector2(tex.get_size())
		var pos := Vector2(floorf((size.x - s.x) / 2.0), size.y - s.y - 1.0)
		draw_texture_rect(tex, Rect2(pos, s), false, Color(0.45, 0.45, 0.42) if a.get("locked", false) else Color.WHITE)

	static func _source(id: String) -> Image:
		var img: Image
		# Recherche sans dessin propre : l'icône de l'objet qu'elle désigne (« glyph » du catalogue).
		var glyph := String(Catalog.RESEARCH.get(id, {}).get("glyph", ""))
		if RESEARCH_ICONS.has(id):
			img = (RESEARCH_ICONS[id] as Texture2D).get_image()
		elif Icon.ITEM_ORDER.has(glyph):
			img = STRIP.get_image().get_region(Rect2i(Icon.ITEM_ORDER.find(glyph) * 32, 0, 32, 32))
		elif Icon.ITEM_ORDER.has(id):
			img = STRIP.get_image().get_region(Rect2i(Icon.ITEM_ORDER.find(id) * 32, 0, 32, 32))
		else:
			img = HudStyle.MINING_SEAL.get_image()
			img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		img.convert(Image.FORMAT_RGBA8)
		return img

	static func _full_tex(id: String) -> Texture2D:
		if not _full.has(id):
			_full[id] = ImageTexture.create_from_image(_source(id))
		return _full[id]

	## Trait seul : contour et ombres profondes en blanc (teinté à l'or au dessin), le reste transparent.
	static func _sketch_tex(id: String) -> Texture2D:
		if _sketch.has(id):
			return _sketch[id]
		var src := _source(id)
		var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var c := src.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var edge := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(x, y) + d
					if q.x < 0 or q.y < 0 or q.x > 31 or q.y > 31 or src.get_pixelv(q).a < 0.5:
						edge = true
				var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				if edge or lum < 0.12:
					out.set_pixel(x, y, Color.WHITE)
				elif lum < 0.3:
					out.set_pixel(x, y, Color(0.5, 0.48, 0.44))
		_sketch[id] = ImageTexture.create_from_image(out)
		return _sketch[id]

	## Pictogramme de commande (assets/ui/commands) teinté en camaïeu ivoire : contour noir, ombre de la couleur de
	## l'émail, trois tons ivoire selon la luminance ; cendre quand l'ordre est indisponible.
	static func _command_tex(icon: String, family: String, locked: bool) -> Texture2D:
		var k := "%s|%s|%s" % [icon, family, locked]
		if _commands.has(k):
			return _commands[k]
		var src := (load("res://assets/ui/commands/%s.png" % icon) as Texture2D).get_image()
		src.convert(Image.FORMAT_RGBA8)
		var ramp: Array = [Color("#3a3a30"), Color("#5a5a4c"), Color("#7c7c6c"), Color("#8a8a7a")] if locked else \
			[(ENAMEL[family][0] as Color) * Color(0.6, 0.6, 0.6, 1.0), Color("#cdb894"), Color("#ecdcb0"), Color("#fff6dc")]
		for y in src.get_height():
			for x in src.get_width():
				var c := src.get_pixel(x, y)
				if c.a < 0.5:
					continue
				if c.r8 == 0x0b and c.g8 == 0x09 and c.b8 == 0x0b:
					src.set_pixel(x, y, Color("#0b090b"))
					continue
				var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				src.set_pixel(x, y, ramp[mini(3, floori(lum * 4.0 * 1.05))])
		_commands[k] = ImageTexture.create_from_image(src)
		return _commands[k]

	## Portrait recadré sur sa silhouette, réduit au plus proche voisin à `h` px de haut (largeur bornée à `max_w`).
	static func _unit_tex(key: String, h: int, max_w: int) -> Texture2D:
		var k := "%s|%d|%d" % [key, h, max_w]
		if _units.has(k):
			return _units[k]
		var path := PORTRAITS % key
		if not ResourceLoader.exists(path) or h < 4:
			return null
		var img := (load(path) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(img.get_used_rect())
		var w := maxi(1, roundi(img.get_width() * float(h) / img.get_height()))
		if w > max_w and max_w > 4:
			h = maxi(1, roundi(h * float(max_w) / w))
			w = max_w
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
		_units[k] = ImageTexture.create_from_image(img)
		return _units[k]


## Par-dessus l'objet : jauge de fabrication, cadenas (recherche manquante), compteur grenat du coffre rouge.
class _Over extends Control:
	var button: ActionButton

	func _draw() -> void:
		var a := button.action
		var w := size.x
		var h := size.y
		var p: float = a.get("craft_progress", 0.0)
		if a.get("active", false) and p > 0.0:
			draw_rect(Rect2(3, h - 4, w - 6, 1), Color("#2a2414"))
			draw_rect(Rect2(3, h - 4, roundf((w - 6) * clampf(p, 0.0, 1.0)), 1), Color("#ffe0a0"))
		if a.get("locked", false):
			var c := Color("#8a8a7a")
			var o := Vector2(4, h - 11)
			draw_rect(Rect2(o + Vector2(1, 0), Vector2(4, 4)), c, false, 1.0)
			draw_rect(Rect2(o + Vector2(0, 3), Vector2(6, 5)), c)
			draw_rect(Rect2(o + Vector2(2.5, 4.5), Vector2(1, 2)), Color("#24261f"))
		if a.has("command_icon") and button._kbd.visible:
			var kr := Rect2(button._kbd.position, button._kbd.size)
			draw_rect(kr, Color("#10140d"))
			draw_rect(kr.grow(-0.5), Color("#c0584c") if a.get("poor", false) else (Color("#4d4f40") if a.get("locked", false) else Color("#8c744b")), false, 1.0)
		var cd: float = a.get("cd_frac", 0.0)
		if cd > 0.0:
			# Recharge : voile tramé qui se retire de bas en haut, secondes en grand au centre.
			var vh := roundf((h - 4.0) * cd)
			for j in int(vh):
				for i in range(int(j) % 2, int(w) - 4, 2):
					draw_rect(Rect2(2 + i, 2 + j, 1, 1), Color("#0a0c08"))
			draw_rect(Rect2(2, 2 + vh, w - 4, 1), Color("#ffe5ac"))
			var ct: String = a.get("cd_text", "")
			var ff := HudStyle.font()
			var tw := HudStyle.text_width(ct, 16)
			draw_string(ff, Vector2((w - tw) / 2.0 + 1.0, h / 2.0 + 7.0), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#0a0c08"))
			draw_string(ff, Vector2((w - tw) / 2.0, h / 2.0 + 6.0), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffe5ac"))
		if a.get("research_done", false):
			# Cachet de cire vert et coche (remplace « Déjà achevée »).
			var c := Vector2(w - 10.0, h - 10.0)
			draw_circle(c + Vector2(0.5, 1.0), 6.5, Color("#0e1a0c"))
			draw_circle(c, 6.5, Color("#2e5a2a"))
			draw_circle(c - Vector2(0.5, 0.5), 5.0, Color("#3e7a36"))
			draw_polyline(PackedVector2Array([c + Vector2(-3, 0), c + Vector2(-1, 2), c + Vector2(3, -2)]), Color("#d4f4b0"), 1.5)
		var n: int = a.get("craft_count", 0)
		if n <= 0:
			return
		var t := str(n)
		var cw := HudStyle.text_width(t, 9) + 14.0
		var r := Rect2(w - 3.0 - cw, h - 15.0, cw, 11.0)
		draw_rect(r, Color("#5a1e22"))
		HudStyle.ring(self, r, 1.0, Color("#c0584c"))
		var g := r.position + Vector2(3, 3)
		if a.has("unit_sprite"):
			# Pictogramme d'unité en file : tête, épaules.
			draw_rect(Rect2(g + Vector2(1.5, 0), Vector2(3, 2)), Color("#e8a090"))
			draw_rect(Rect2(g + Vector2(0, 3), Vector2(6, 2)), Color("#e8a090"))
		else:
			# Pictogramme de coffre : couvercle clair, caisse, serrure.
			draw_rect(Rect2(g, Vector2(6, 1)), Color("#ffd6c8"))
			draw_rect(Rect2(g + Vector2(0, 2), Vector2(6, 3)), Color("#e8a090"))
			draw_rect(Rect2(g + Vector2(2.5, 3), Vector2(1, 1)), Color("#5a1e22"))
		var f := HudStyle.font()
		draw_string(f, Vector2(r.position.x + 11.0, r.position.y + 8.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ffe0d4"))
