class_name ItemBanner
extends Control
## Bannières « Reçu : OBJET » (bannière 16 bits, SnesBanner) : titre centré, gros visuel à gauche, texte à droite.
## Plusieurs objets s'enchaînent, un seul à la fois : chaque action (clic, touche) remplace la bannière
## par la suivante, la dernière action referme le tout. Chaque bannière joue le son « victoire ».

const ICON_BOX := 96.0
const TITLE_SIZE := 19
const TITLE_H := 30.0
const GAP := 18.0
## Délai avant qu'une action puisse faire avancer (évite que l'action qui a ouvert ne referme aussitôt).
const ARM_DELAY := 0.25
const SOUND := "victoire"
const SOUND_DB := -8.0

## Texte de chaque objet remis (titre en capitales, visuel tiré des sprites de l'Ingénieur).
## Nom des objets absents de data/gear_items.gd.
const NAMES := {"mining_seal": "Sceau de minage", "plan_analyse": "Plan de mod « Analyse »"}
## Plans remis comme objets de bannière : l'icône du mod qu'ils apprennent sert de visuel (Recipes.PLAN_ITEMS).
const TEXTS := {
	"cannon": "L'arme de base de tous les Exilés, la vôtre n'ayant pas survécu au voyage temporel. Consomme de l'énergie spirituelle à chaque tir. Faites-en bon usage.",
	"mining_seal": "Un sceau commun qui vous permet de miner la roche et certains minéraux basiques.",
	"plan_analyse": "Le plan d'un module d'exo tyrien. Une fois fabriqué à l'Établi d'exo (5 fibres de bois noir, 5 planches, 1 ichor), il affiche les PV des ennemis à l'écran.",
	"combinaison": "Une combinaison sommaire commune à tous les Exilés, votre armure n'ayant pas supporté le voyage temporel. Il existe peut-être des moyens de la renforcer ?",
}

var _queue: Array[String] = []
var _cards: Array[_Card] = []
var _armed_at := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	get_viewport().size_changed.connect(_layout)


func active() -> bool:
	return not _cards.is_empty()


## Affiche les objets un par un (le premier tout de suite).
func show_items(items: Array) -> void:
	for it: String in items:
		_queue.append(it)
	if _cards.is_empty():
		_next()


## Action du joueur : bannière suivante à la place de l'actuelle, ou fermeture après la dernière.
func advance() -> void:
	if not active() or Time.get_ticks_msec() / 1000.0 < _armed_at:
		return
	if _queue.is_empty():
		close()
	else:
		_next()


func close() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_queue.clear()
	visible = false


func _next() -> void:
	var item: String = _queue.pop_front()
	for old in _cards:
		old.queue_free()
	_cards.clear()
	var c := _Card.new()
	c.setup(item, TEXTS.get(item, ""))
	add_child(c)
	_cards.append(c)
	visible = true
	_armed_at = Time.get_ticks_msec() / 1000.0 + ARM_DELAY
	_layout()
	Events.sfx.emit(SOUND, SOUND_DB)


func _layout() -> void:
	var view := get_viewport_rect().size
	var w := SnesBanner.width(view)
	for c in _cards:
		c.layout(w)
		c.position = Vector2(roundf((view.x - w) / 2.0), BossBar.top())


static func visual(item: String) -> Texture2D:
	if item == "mining_seal":
		return HudStyle.MINING_SEAL
	var plans: Dictionary = preload("res://data/recipes.gd").PLAN_ITEMS
	if plans.has(item):
		return preload("res://ui/inventory/item_icon.gd").mod_texture(plans[item])
	var wi := TyrienArt.weapon_icon(item)
	if wi:
		return wi
	var gear: Dictionary = preload("res://data/gear_items.gd").ITEMS.get(item, {})
	# La combinaison n'est pas un calque : c'est le corps de base de l'Ingénieur (image de repos recadrée).
	if item == "combinaison":
		return TyrienArt.icon("base")
	return TyrienArt.icon(String(gear.get("piece", item)))


class _Card extends Control:
	var _title := SnesBanner.label()
	var _text := SnesBanner.label()
	var _icon := TextureRect.new()

	func setup(item: String, text: String) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_ := String(preload("res://data/gear_items.gd").ITEMS.get(item, {}).get("name", ItemBanner.NAMES.get(item, item)))
		_title.text = "Reçu : " + name_.to_upper()
		_title.add_theme_font_size_override("font_size", TITLE_SIZE)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text.text = text
		_icon.texture = ItemBanner.visual(item)
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_title)
		add_child(_icon)
		add_child(_text)

	func layout(w: float) -> void:
		var pad := SnesBanner.PAD
		var text_x := pad.x + ItemBanner.ICON_BOX + ItemBanner.GAP
		var text_w := w - text_x - pad.x
		var text_h := SnesBanner.height(_text.text, text_w + 2.0 * pad.x) - 2.0 * pad.y
		var body_h := maxf(ItemBanner.ICON_BOX, text_h)
		size = Vector2(w, pad.y * 2.0 + ItemBanner.TITLE_H + body_h)
		_title.position = Vector2(pad.x, pad.y)
		_title.size = Vector2(w - 2.0 * pad.x, ItemBanner.TITLE_H)
		# Visuel agrandi en pixels entiers dans sa boîte.
		var ts := _icon.texture.get_size() if _icon.texture else Vector2.ONE
		var k := maxf(1.0, floorf(ItemBanner.ICON_BOX / maxf(ts.x, ts.y)))
		var isz := ts * k
		var box := Vector2(pad.x, pad.y + ItemBanner.TITLE_H)
		_icon.position = (box + (Vector2.ONE * ItemBanner.ICON_BOX - isz) / 2.0 + Vector2(0, (body_h - ItemBanner.ICON_BOX) / 2.0)).round()
		_icon.size = isz
		_text.position = Vector2(text_x, pad.y + ItemBanner.TITLE_H + maxf(0.0, (body_h - text_h) / 2.0))
		_text.size = Vector2(text_w, text_h)
		queue_redraw()

	func _draw() -> void:
		SnesBanner.paint(self, Rect2(Vector2.ZERO, size))
