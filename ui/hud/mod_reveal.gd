class_name ModReveal
extends Control
## Grand écrin (planches/mod-revelation-propositions.html, piste 4 avec la sortie 4B « L'étoile », choisie le
## 2026-11-21) : le premier ramassage de chaque mod l'annonce en haut au centre de l'écran.
## Apparition (1 s) : voile Sarcelle, icône ×4 qui jaillit avec un éclair blanc et une onde, soleil de rayons.
## Mise en valeur : l'icône se range en haut (×2), la plaque s’ouvre sous elle (nom, effet) dans le même Cartouche que l’icône, reflet,
## étincelles en orbite. Disparition (0,75 s) : la plaque se plie dans l'icône, les rayons se referment, l'icône
## se contracte en un point blanc qui s'ouvre en étoile à quatre branches.
## En combat (Simulation.in_combat), rien ne s'affiche : les mods attendent dans une file (pastille « +N » sur le
## portrait), puis passent un par un, du plus rare au moins rare, après CALM s de calme. Un combat qui reprend
## coupe l'affichage en cours par sa disparition et le remet en file. Un clic sur l'écrin le renvoie.
## Un mod compte comme ramassé dès qu'il est dans le paquetage, la fiche ou le réseau des coffres (_find_new).

const Gear := preload("res://data/gear_items.gd")
const ItemIcon := preload("res://ui/inventory/item_icon.gd")

const IN := 1.0
const OUT := 0.75
const CALM := 1.5
const GAP := 0.4
const VEIL := Color(4 / 255.0, 20 / 255.0, 26 / 255.0, 0.45)
const TEXT := Color("#eeeae0")
const SHADOW := Color("#04141a")
const PLATE_W := 480.0
const TITLE_SIZE := 18
const DESC_SIZE := 13
## Tenue à l'écran selon la rareté (s).
const HOLD := {"normal": 3.0, "uncommon": 3.0, "rare": 4.0, "epic": 4.0, "unique": 5.0, "mythic": 5.0}
const SOUND := {"normal": "niveau", "uncommon": "niveau", "rare": "quete", "epic": "quete", "unique": "victoire", "mythic": "victoire"}

## Bas de la plaque du jour (posé par le HUD) : l'icône rangée se tient 48 px dessous.
var anchor_y := 112.0
## Rect2 du portrait de l'Exilé (pastille « +N ») ; Rect2() s'il est masqué.
var portrait_rect := func() -> Rect2: return Rect2()
## Vrai quand un autre texte occupe le haut de l'écran (dialogue, bannière « Reçu », cinématique).
var busy := func() -> bool: return false

var queue: Array[String] = []
## Affichage en cours : {item, t} ; vide entre deux.
var current: Dictionary = {}
var _calm := 0.0
## Relevé des mods possédés (paquetage, fiche, réseau des coffres) toutes les SCAN s : couvre ce qui n'est pas
## ramassé sur un corps (bouton de debug, butin rapporté au coffre par l'Oublieux).
const SCAN := 0.25
var _scan := 0.0
var _gap := GAP
var _hit := Rect2()
var _bold := FontVariation.new()
var _icon := _IconLayer.new()
var _fx := _FxLayer.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bold.base_font = HudStyle.font()
	_bold.variation_embolden = 0.6
	for c: Control in [_icon, _fx]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.reveal = self
		add_child(c)
	Events.mod_picked.connect(push)
	Events.game_reset.connect(clear)


## Premier ramassage d'un mod : en file ; un mod déjà annoncé ne rejoue rien.
func push(item: String) -> void:
	if GameState.mods_seen.has(item) or not Gear.ITEMS.get(item, {}).has("module"):
		return
	GameState.mods_seen[item] = true
	queue.append(item)


func _find_new() -> void:
	var piles: Array = [GameState.base_inventory]
	for u: Unit in GameState.units:
		if u.role == "engineer":
			piles.append(u.inventory)
			for slot: String in u.equipment:
				push(String(u.equipment[slot]))
	for pile: Array in piles:
		for stack: Dictionary in pile:
			if not stack.is_empty():
				push(String(stack["item"]))


func clear() -> void:
	queue.clear()
	current = {}
	_calm = 0.0


func active() -> bool:
	return not current.is_empty()


static func in_combat() -> bool:
	var u := GameState.incarnated if GameState.incarnated != null else Capsule.engineer()
	return Simulation.in_combat(u)


func _process(delta: float) -> void:
	# Plein écran : on suit la taille du parent (les ancres ne suffisent pas sous le HUD).
	var area := (get_parent() as Control).size if get_parent() is Control else get_viewport_rect().size
	if size != area:
		position = Vector2.ZERO
		size = area
		for c: Control in [_icon, _fx]:
			c.position = Vector2.ZERO
			c.size = area
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN
		_find_new()
	var fight := in_combat()
	var held := fight or bool(busy.call())
	_calm = 0.0 if held else _calm + delta
	if current.is_empty():
		_gap += delta
		if not queue.is_empty() and _calm >= CALM and _gap >= GAP:
			queue.sort_custom(func(a: String, b: String) -> bool: return _rank(a) > _rank(b))
			current = {"item": queue.pop_front(), "t": 0.0}
			Sfx.play(SOUND[Loot.rarity_of(current["item"])])
	else:
		current["t"] += delta
		var out_at := IN + _hold()
		if fight and current["t"] < out_at:
			queue.push_front(current["item"])
			current["t"] = out_at
		if current["t"] >= out_at + OUT:
			current = {}
			_gap = 0.0
	visible = not current.is_empty() or not queue.is_empty()
	queue_redraw()
	_icon.queue_redraw()
	_fx.queue_redraw()


func _input(event: InputEvent) -> void:
	if current.is_empty() or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and current["t"] < IN + _hold() and _hit.has_point(event.position):
		current["t"] = IN + _hold()
		get_viewport().set_input_as_handled()


func _rank(item: String) -> int:
	return Loot.RARITY_ORDER.find(Loot.rarity_of(item))


func _hold() -> float:
	return HOLD[Loot.rarity_of(current["item"])]


static func _seg(k: float, a: float, b: float) -> float:
	return clampf((k - a) / (b - a), 0.0, 1.0)


static func _e_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


static func _e_in(t: float) -> float:
	return t * t * t


static func _e_back(t: float) -> float:
	t -= 1.0
	return t * t * (2.7 * t + 1.7) + 1.0


## État de l'image : {phase, veil, rays, ray_r, rot, ray_w, wave, iy, scale, flash, shine, plate, plate_w, fold,
## plate_dy, orbit, orbit_r, star}. Calculé une fois par image, lu par les trois calques.
func state() -> Dictionary:
	if current.is_empty():
		return {}
	var item: String = current["item"]
	var t: float = current["t"]
	var low := _rank(item) <= Loot.RARITY_ORDER.find("uncommon")
	var top := anchor_y + 48.0
	var big := top + 90.0
	var sun := 0.6 if low else 1.0
	var s := {"item": item, "veil": 1.0, "rays": 1.0, "ray_r": 132.0 * sun, "rot": 0.0, "ray_w": 0.1, "wave": 0.0,
		"iy": top, "scale": 2.0, "flash": 0.0, "shine": -1.0, "plate": 1.0, "plate_w": 1.0, "fold": false, "plate_dy": 0.0,
		"orbit": -1.0, "orbit_r": 1.0, "star": -1.0}
	var hold := _hold()
	if t < IN:
		var u := t / IN
		s.merge({"veil": _seg(u, 0, 0.3), "rays": _e_out(_seg(u, 0.4, 1)), "ray_r": 210.0 * sun, "iy": big,
			"scale": 4.0 * _e_back(_seg(u, 0.15, 0.6)), "plate": 0.0, "wave": _seg(u, 0.45, 1),
			"flash": clampf(1.0 - (u - 0.3) / 0.25, 0, 1) if u > 0.15 else 0.0}, true)
	elif t < IN + hold:
		var h := t - IN
		var settle := _e_out(clampf(h / 0.6, 0, 1))
		var sw := fmod(h, 1.5) / 0.5
		s.merge({"ray_r": lerpf(210.0, 132.0, settle) * sun, "rot": h * 0.4, "iy": lerpf(big, top, settle),
			"scale": lerpf(4.0, 2.0, settle), "plate": _e_out(clampf((h - 0.35) / 0.45, 0, 1)),
			"shine": sw if sw < 1.0 else -1.0, "orbit": -1.0 if low else h}, true)
	else:
		var u := clampf((t - IN - hold) / OUT, 0, 1)
		var fold := _e_in(_seg(u, 0, 0.35))
		var shrink := _e_in(_seg(u, 0.3, 0.6))
		s.merge({"veil": 1.0 - _seg(u, 0.55, 1), "rays": 1.0 - _e_in(_seg(u, 0.15, 0.6)),
			"rot": hold * 0.4 + _e_in(_seg(u, 0, 0.6)) * 2.5, "ray_w": 0.1 + 0.2 * _seg(u, 0.2, 0.6),
			"plate": 1.0 - fold, "plate_w": 1.0 - fold, "fold": true, "plate_dy": -fold * 40.0,
			"scale": 2.0 * (1.0 - shrink), "flash": shrink, "orbit": -1.0 if low or u >= 0.45 else hold + u * 3.0,
			"orbit_r": 1.0 - _seg(u, 0, 0.45), "star": _seg(u, 0.6, 1) if u >= 0.6 else -1.0}, true)
	return s


func _desc(item: String) -> String:
	return String(Gear.ITEMS[item].get("desc", "")).replace("Module d’exo. ", "")


func _wrap(text: String, width: float) -> PackedStringArray:
	var f := HudStyle.font()
	var out := PackedStringArray()
	var line := ""
	for w in text.split(" "):
		var t := w if line == "" else line + " " + w
		if line != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, DESC_SIZE).x > width:
			out.append(line)
			line = w
		else:
			line = t
	if line != "":
		out.append(line)
	return out


func _text(f: Font, pos: Vector2, s: String, px: int, col: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := (pos - Vector2(w / 2.0, 0)).round()
	draw_string(f, p + Vector2.ONE, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, SHADOW)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw() -> void:
	var s := state()
	if s.is_empty():
		return
	var item: String = s["item"]
	var rc := Loot.rarity_color(item)
	var cx := roundf(size.x / 2.0)
	var iy: float = s["iy"]
	if s["veil"] > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(VEIL, VEIL.a * s["veil"]))
	# Soleil : seize rayons à la rareté, un sur deux éclairci.
	var r: float = s["ray_r"] * s["rays"]
	if r > 1.0:
		var w: float = s["ray_w"]
		for i in 16:
			var a: float = s["rot"] + i * PI / 8.0
			var col := rc.lerp(Color.WHITE, 0.5) if i % 2 else rc
			draw_colored_polygon(PackedVector2Array([Vector2(cx, iy), Vector2(cx, iy) + Vector2.from_angle(a - w) * r,
				Vector2(cx, iy) + Vector2.from_angle(a + w) * r]), Color(col, 0.3))
	var wave: float = s["wave"]
	if wave > 0.0 and wave < 1.0:
		draw_set_transform(Vector2(cx, iy), 0.0, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, 30.0 + wave * 210.0, 0.0, TAU, 64, Color(1, 1, 1, 1.0 - wave), 5.0)
		draw_set_transform(Vector2.ZERO)
	# Plaque dans le style Cartouche de l'icône (ItemIcon.draw_mod), au même grain (×2) : fond plein à la couleur de
	# la plaque du mod, bord à la rareté, coins cassés, reflet éclairci en haut et à gauche, ombre en bas à droite.
	var lines := _wrap(_desc(item), PLATE_W - 40.0)
	var ph := maxf(24.0, 56.0 + lines.size() * 17.0 + 14.0) - 6.0
	var py: float = anchor_y + 90.0 + s["plate_dy"]
	_hit = Rect2(cx - PLATE_W / 2.0, anchor_y + 10.0, PLATE_W, py - anchor_y + ph)
	if s["plate"] > 0.0:
		var pw := maxf(6.0, roundf(PLATE_W * s["plate_w"] / 2.0) * 2.0)
		var h := maxf(4.0, roundf(ph * s["plate"] / 2.0) * 2.0)
		var y: float = py + ((ph - h) / 2.0 if s["fold"] else 0.0)
		cartouche(self, Rect2(cx - pw / 2.0, roundf(y / 2.0) * 2.0, pw, h), item)
		if s["plate"] > 0.95 and s["plate_w"] > 0.95:
			_text(_bold, Vector2(cx, py + 26.0), Gear.name_of(item), TITLE_SIZE, rc)
			for i in lines.size():
				_text(HudStyle.font(), Vector2(cx, py + 46.0 + i * 17.0), lines[i], DESC_SIZE, TEXT)


## Couleur de la plaque d'un mod (rangée 0 de l'atlas des icônes), mise en cache.
static var _fills: Dictionary = {}


static func plate_fill(item: String) -> Color:
	if not _fills.has(item):
		var col := ItemIcon.MOD_ORDER.find(String(Gear.ITEMS.get(item, {}).get("module", "")))
		_fills[item] = ItemIcon.MODS_TEX.get_image().get_pixel(maxi(col, 0) * 32 + 16, 16) if col >= 0 else Color("#0a1d24")
	return _fills[item]


## Cartouche agrandi (grain k = 2 px, comme l'icône ×2) : bord 1 grain à la rareté, coins cassés de 4 grains,
## reflet 1 grain éclairci en haut et à gauche (en retrait des coins), ombre 1 grain en bas et à droite.
static func cartouche(ci: CanvasItem, r: Rect2, item: String, k := 2.0) -> void:
	var edge := Loot.rarity_color(item) if Loot.rarity_of(item) != "normal" else ItemIcon.MOD_NORMAL_EDGE
	var fill := plate_fill(item)
	if r.size.x < 12.0 * k or r.size.y < 12.0 * k:
		ci.draw_rect(r, edge)
		if r.size.x > 2.0 * k and r.size.y > 2.0 * k:
			ci.draw_rect(r.grow(-k), fill)
		return
	var c := 4.0 * k
	ci.draw_colored_polygon(_octagon(r, c), edge)
	ci.draw_colored_polygon(_octagon(r.grow(-k), c - k * 0.5), fill)
	var hi := edge.lerp(Color.WHITE, 0.45)
	var p := r.position
	var sz := r.size
	ci.draw_rect(Rect2(p + Vector2(c + k, k), Vector2(sz.x - 2.0 * c - 2.0 * k, k)), hi)
	ci.draw_rect(Rect2(p + Vector2(k, c + k), Vector2(k, sz.y - 2.0 * c - 2.0 * k)), hi)
	var lo := Color(fill.darkened(0.45), 0.8)
	ci.draw_rect(Rect2(p + Vector2(c, sz.y - 2.0 * k), Vector2(sz.x - 2.0 * c, k)), lo)
	ci.draw_rect(Rect2(p + Vector2(sz.x - 2.0 * k, c), Vector2(k, sz.y - 2.0 * c)), lo)


static func _octagon(r: Rect2, c: float) -> PackedVector2Array:
	var p := r.position
	var s := r.size
	return PackedVector2Array([p + Vector2(c, 0), p + Vector2(s.x - c, 0), p + Vector2(s.x, c), p + Vector2(s.x, s.y - c),
		p + Vector2(s.x - c, s.y), p + Vector2(c, s.y), p + Vector2(0, s.y - c), p + Vector2(0, c)])


## Icône du mod, avec un shader pour l'éclair blanc et le reflet qui la balaie.
class _IconLayer extends Control:
	var reveal: ModReveal
	var _mat := ShaderMaterial.new()

	func _init() -> void:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float flash = 0.0;
uniform float shine = -1.0;
uniform vec4 box = vec4(0.0, 0.0, 1.0, 1.0);
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec4 c = COLOR;
	float band = 0.0;
	if (shine >= 0.0) {
		vec2 p = (lp - box.xy) / box.zw;
		float d = p.x + p.y - mix(-0.4, 2.4, shine);
		band = abs(d) < 0.16 ? 0.75 : (abs(d - 0.3) < 0.05 ? 0.35 : 0.0);
	}
	c.rgb = mix(c.rgb, vec3(1.0), max(flash, band));
	COLOR = c;
}"""
		_mat.shader = sh
		material = _mat

	func _draw() -> void:
		var s := reveal.state()
		if s.is_empty() or s["scale"] <= 0.02:
			return
		var c := Vector2(roundf(size.x / 2.0), s["iy"])
		var d: float = 32.0 * s["scale"]
		_mat.set_shader_parameter("flash", s["flash"])
		_mat.set_shader_parameter("shine", s["shine"])
		_mat.set_shader_parameter("box", Vector4(roundf(c.x - d / 2.0), roundf(c.y - d / 2.0), d, d))
		ItemIcon.draw_mod(self, s["item"], c, s["scale"])


## Étincelles en orbite, étoile finale et pastille « +N » des mods en attente.
class _FxLayer extends Control:
	var reveal: ModReveal

	func _px(p: Vector2, z: float, col: Color) -> void:
		draw_rect(Rect2(p.round(), Vector2(z, z)), col)

	func _spark(p: Vector2, r: int, col: Color) -> void:
		_px(p - Vector2.ONE, 2, Color.WHITE)
		for i in range(1, r + 1):
			var c := col if i == r else col.lerp(Color.WHITE, 0.5)
			for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
				_px(p - Vector2.ONE + dir * i * 2.0, 2, c)

	func _draw() -> void:
		var s := reveal.state()
		_badge()
		if s.is_empty():
			return
		var rc := Loot.rarity_color(s["item"])
		var c := Vector2(roundf(size.x / 2.0), s["iy"])
		if s["orbit"] >= 0.0:
			for i in 3:
				var a: float = s["orbit"] * 2.2 + i * TAU / 3.0
				var big := i == int(floorf(s["orbit"] * 3.0)) % 3
				_spark(c + Vector2(cos(a) * 46.0, sin(a) * 30.0) * s["orbit_r"], 3 if big else 2, rc)
		var st: float = s["star"]
		if st > 0.0 and st < 1.0:
			var arms := roundi(sin(st * PI) * 11.0)
			_px(c - Vector2(4, 4), 8, Color.WHITE)
			for i in range(1, arms + 1):
				var col := rc if i > arms - 3 else rc.lerp(Color.WHITE, 0.6)
				var z := 4.0 if i < 3 else 3.0
				var o := Vector2.ONE * -floorf(z / 2.0)
				for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
					_px(c + o + dir * i * 4.0, z, col)
			for i in range(1, arms / 3 + 1):
				for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					_px(c - Vector2.ONE + dir * i * 4.0, 2, rc)
			if st < 0.35:
				var w := st / 0.35
				var h := 6.0 + w * 30.0
				draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0).abs(), Color(1, 1, 1, 1.0 - w), false, 2.0)

	func _badge() -> void:
		if reveal.queue.is_empty():
			return
		var best := 0
		for it: String in reveal.queue:
			best = maxi(best, reveal._rank(it))
		var col: Color = Loot.RARITY[Loot.RARITY_ORDER[best]]["color"]
		var pr: Rect2 = reveal.portrait_rect.call()
		var p := Vector2(pr.end.x - 4.0, pr.position.y + 4.0) if pr.size != Vector2.ZERO \
			else Vector2(roundf(size.x / 2.0) + 130.0, reveal.anchor_y - 18.0)
		draw_circle(p, 11.0, SHADOW)
		draw_circle(p, 9.0, col)
		var f := reveal._bold
		var t := "+%d" % reveal.queue.size()
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f, (p + Vector2(-w / 2.0, 4.5)).round(), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SHADOW)
