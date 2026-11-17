class_name UnitView
extends Node2D
## Rendu d'une unité alliée ou d'un ennemi (drawUnitSprite et drawCharacter, Index.html, 73b410f) :
## ombre et sélection (ellipses), sprite (repos, marche à la distance parcourue, agenouillement, coups
## d'épée et salves d'arbalète), orientation vers l'ennemi visé ou dans le sens de la marche, barre de vie,
## badge de niveau.
## Origine du nœud : point au sol continu ; le sprite est aligné sur la grille native par le shader.

const SPR_FRAMES := 24
const SPR_LOOP := 2.4
## Z()/PX = 8/0,86 : unité de monde en pixels natifs pour les ellipses (circle3).
const ZN := 8.0 / 0.86
const SHADOW := Color("#0b1615a0")
const SEL_FILL := Color("#ead08c55")
const SEL_LINE := Color("#f8df93")
const FOE_FILL := Color("#db505055")
const FOE_LINE := Color("#ff7a6a")
const HP_BG := Color("#191b1d")
const HP_ALLY := Color("#85d6b1")
const HP_GUARD := Color("#9db88f")
const HP_ENEMY := Color("#db7772")
const Gear := preload("res://data/gear_items.gd")

var unit: Unit
var simulation: Simulation
var world: World
var _meta: Dictionary
var _idle: Array[AtlasTexture] = []
var _walk: Array[AtlasTexture] = []
var _enemy_attack: Array[AtlasTexture] = []
var _enemy_death: Array[AtlasTexture] = []
var _corpse_shadow_ready := false
static var _enemy_sheets: Dictionary = {}
var _kneel: Array[AtlasTexture] = []
var _kneel_fps := 12.0
## Ingénieur sans armure (surcharge de l'Ancre), tenue « Le Tyrien » (TyrienArt) : repos, marche, agenouillement à
## bout de souffle, incantation, méditation ; "meta" = cadences des animations.
static var _bare: Dictionary
## Calques des pièces d'équipement portées, enfants de _body (même image, même orientation).
var _gear: Array[Sprite2D] = []
var enemy := false
## Animations d'attaque (ATK.sword[0..4], ATK.xbow) : 12 images, ancre propre.
static var _atk: Dictionary
var _sword: Array = []
var _xbow: Array[AtlasTexture] = []
var _body := Sprite2D.new()
var _mining_seal: Node2D
var _under := _UnitDecal.new()
## Méditation de l'Ingénieur (Meditation) : halo et lueurs derrière le sprite, puis devant.
var _med_back := _MedFx.new()
var _med_front := _MedFx.new()
var _med_on := false
var _over := _UnitBar.new()
## Soin reçu (« + » verts) et rappel par le Puits des Âmes (bulle qui devient l'unité), alliés seulement.
var _heal: HealFx
var _revive: ReviveFx
# État d'animation (u._lx, u._lz, u._wp, u._still, u._face).
var _lx := NAN
var _lz := NAN
var _wp := 0.0
var _still := 0
var _face := 1
var _under_key: Variant = null
var _over_key := Vector4(-1, -1, -1, -1)


func setup(u: Unit, meta: Dictionary, sim: Simulation, w: World = null) -> void:
	unit = u
	simulation = sim
	world = w
	_meta = meta
	enemy = u.is_enemy()
	var base := (EnemyArt.ROOT + "%s_" if enemy else "res://assets/baked/units/%s_") % u.role
	if not enemy and (u.role == "paladin" or u.role == "shooter"):
		if _atk.is_empty():
			_atk = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["attacks"]
		if u.role == "paladin":
			for i in 5:
				_sword.append(_frames("res://assets/baked/attacks/sword_%d.png" % i, _atk["sword"]["sheet"]))
		else:
			_xbow = _frames("res://assets/baked/attacks/xbow.png", _atk["xbow"]["sheet"])
	if not enemy and u.role == "engineer" and _bare.is_empty():
		TyrienArt.load_all()
		_bare = {"meta": TyrienArt.meta["anims"]}
		for anim: String in ["idle", "walk", "kneel", "pray", "settle", "lotus"]:
			_bare[anim] = TyrienArt.anim(anim)
	if enemy:
		if not _enemy_sheets.has(u.role):
			var sheets := {}
			for action: String in ["idle", "walk", "attack", "death"]:
				sheets[action] = _frames(base + action + ".png", meta[action])
			_enemy_sheets[u.role] = sheets
		_idle = _enemy_sheets[u.role]["idle"]
		_walk = _enemy_sheets[u.role]["walk"]
		_enemy_attack = _enemy_sheets[u.role]["attack"]
		_enemy_death = _enemy_sheets[u.role]["death"]
	else:
		_idle = _frames(base + "idle.png", meta["idle"])
		_walk = _frames(base + "walk.png", meta["walk"])
	if meta.has("kneel"):
		_kneel = _frames(base + "kneel.png", meta["kneel"])
		_kneel_fps = float(meta["kneel"].get("fps", 12.0))
	use_parent_material = true
	_under.view = self
	add_child(_under)
	if not enemy and u.role == "engineer":
		_med_back.view = self
		_med_back.use_parent_material = true
		add_child(_med_back)
		_mining_seal = preload("res://entities/unit/mining_seal_fx.gd").new()
		_mining_seal.view = self
		_mining_seal.use_parent_material = true
		add_child(_mining_seal)
	_body.centered = false
	_body.use_parent_material = true
	add_child(_body)
	if not enemy and u.role == "engineer":
		_med_front.view = self
		_med_front.front = true
		_med_front.use_parent_material = true
		add_child(_med_front)
	if not enemy:
		_revive = ReviveFx.new()
		_revive.view = self
		_revive.use_parent_material = true
		add_child(_revive)
		_heal = HealFx.new()
		_heal.view = self
		_heal.use_parent_material = true
		add_child(_heal)
	_over.view = self
	add_child(_over)
	_update()


static func _frames(path: String, m: Dictionary) -> Array[AtlasTexture]:
	var tex: Texture2D = load(path)
	var out: Array[AtlasTexture] = []
	for i in int(m["count"]):
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2((i % int(m["cols"])) * int(m["frame_w"]), (i / int(m["cols"])) * int(m["frame_h"]), int(m["frame_w"]), int(m["frame_h"]))
		out.append(a)
	return out


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var u := unit
	visible = not u.hidden and (u.alive() or (enemy and u.dead)) and not Overload.hidden_in_blast(u)
	if enemy and world and not world.fog.visible_at(u.pos()):
		visible = false
	position = Proj.nat(u.x, 0.0, u.z)
	if enemy and u.dead:
		var age := maxf(0.0, GameState.sim_time - (u as Enemy).died_at)
		_body.texture = _enemy_death[mini(_enemy_death.size() - 1, floori(age * float(_meta["death"]["fps"])))]
		_body.offset = Vector2(-float(_meta["ax"]), -float(_meta["ay"]))
		_body.position = Vector2.ZERO
		_body.scale = Vector2(-1 if u.face < 0 else 1, 1)
		var progress := clampf(age / EnemyArt.DEATH_DURATION, 0.0, 1.0)
		_under.position = Vector2(8.0 * progress, -3.0 * progress)
		_under.scale = Vector2(1.0 + progress, 1.0)
		if not _corpse_shadow_ready:
			_corpse_shadow_ready = true
			_under.queue_redraw()
		_over.visible = false
		modulate.a = clampf(EnemyArt.CORPSE_LIFETIME - age, 0.0, 1.0)
		return
	if is_nan(_lx):
		_lx = u.x
		_lz = u.z
	var dist := Vector2(u.x - _lx, u.z - _lz).length()
	var moved := dist > 0.001
	if moved:
		_wp = fmod(_wp + dist / float(_meta["stride"]), 1.0)
		_still = 0
	else:
		_still += 1
	var walking := _still < 4
	# Orientation : alliés vers l'ennemi le plus proche (20 pour le Tireur, 10 sinon), sinon sens de la marche.
	var foe: Variant = null if enemy else Combat.target_closest(u, GameState.enemies, 20.0 if u.role == "shooter" else 10.0, world)
	var dxs: float = foe.x - u.x if foe else u.x - _lx
	# u._face est partagé avec les frappes (swordStrike, volley) : une orientation imposée tient tant
	# qu'aucun ennemi n'est visé et que l'unité ne bouge pas.
	if absf(dxs) > 0.001:
		u.face = -1 if dxs < 0.0 else 1
	_face = u.face if u.face != 0 else 1
	_lx = u.x
	_lz = u.z
	var bare := u.unarmored and not _bare.is_empty()
	var walk_frames: Array[AtlasTexture] = _bare["walk"] if bare else _walk
	var wn := walk_frames.size()
	var wi := floori(_wp * wn) % wn
	var bob_i := floori(_wp * 6.0) if enemy else wi
	var bob := 1 if not _meta.get("self_bob", false) and walking and (bob_i == 1 or bob_i == 4) else 0
	var kick := 1 if not enemy and u.attack > (0.7 if u.role == "paladin" else 0.62) else 0
	var t := GameState.sim_time
	var frame: AtlasTexture
	var key: int = (u as Enemy).anim_key() if enemy else u.id
	if walking:
		frame = walk_frames[wi]
	else:
		frame = (_bare["idle"] if bare else _idle)[(floori(t * SPR_FRAMES / SPR_LOOP) + (key & 7) * 3) % SPR_FRAMES]
	var ax := float(_meta["ax"])
	var ay := float(_meta["ay"])
	# Marche ennemie dans un cadre propre (Strazhar à quatre pattes) : ancre de la marche.
	if enemy and walking and _meta["walk"].has("ax"):
		ax = float(_meta["walk"]["ax"])
		ay = float(_meta["walk"]["ay"])
	# attackFrame : coup d'épée (0,8 s) ou salve d'arbalète (0,7 s), sur 12 images.
	var atk: Array = []
	var atk_meta: Dictionary = {}
	var e := -1.0
	if not _sword.is_empty() and u.sw >= 0:
		e = (t - u.sw_t0) / float(_atk["sword"]["swing_s"])
		atk = _sword[u.sw]
		atk_meta = _atk["sword"]
	elif not _xbow.is_empty():
		e = (t - u.sh_t0) / float(_atk["xbow"]["volley_s"])
		atk = _xbow
		atk_meta = _atk["xbow"]
	if e >= 0.0 and e < 1.0:
		frame = atk[mini(atk.size() - 1, floori(e * atk.size()))]
		ax = atk_meta["ax"]
		ay = atk_meta["ay"]
		kick = 0
	if enemy:
		var age := t - (u as Enemy).attack_started
		# Durée propre de l'animation si elle est plus courte que la recharge (Martyre de Byrsa).
		if age >= 0.0 and age < float(_meta["attack"].get("duration", Catalog.ENEMY[u.role]["cd"])):
			frame = _enemy_attack[mini(_enemy_attack.size() - 1, floori(age * float(_meta["attack"]["fps"])))]
			ax = float(_meta["ax"])
			ay = float(_meta["ay"])
			bob = 0
	if not _kneel.is_empty() and simulation and simulation.kneeling(u):
		if bare:
			var pr: Array = _bare["pray"]
			frame = pr[floori(t * float(_bare["meta"]["pray"]["fps"])) % pr.size()]
		else:
			frame = _kneel[floori(t * _kneel_fps) % _kneel.size()]
	# Surcharge de l'Ancre : retombe à genoux, puis souffle court jusqu'au prochain ordre.
	var drop := 0.0
	var winded := bare and Overload.winded(u)
	if winded:
		var age := t - u.winded_at
		var kn: Array = _bare["kneel"]
		frame = kn[floori(age * float(_bare["meta"]["kneel"]["fps"])) % kn.size()]
		drop = -10.0 * (1.0 - pow(clampf(age / Overload.FALL, 0.0, 1.0), 3.0))
		kick = 0
		bob = 0
		_face = 1 if CaveShape.CORE.x >= u.x else -1
	# Creusement : l'Ingénieur vise et tire ses pitons d'ancrage (EngineerAim).
	if u.role == "engineer" and not walking and world and not winded:
		var aim: Variant = EngineerAim.pose(u, world.terrain_state)
		if aim != null:
			frame = aim["frame"]
			ax = aim["ax"]
			ay = aim["ay"]
			kick = 0
			_face = aim["face"]
	# Méditation en lévitation : assise en tailleur, puis lotus flottant tourné vers le temple.
	var med := Meditation.state(u) if u.role == "engineer" and not enemy else {}
	if not med.is_empty():
		var age: float = med["age"]
		var tb: Building = med["temple"]
		_face = 1 if (tb.x if tb else CaveShape.CORE.x) >= u.x else -1
		kick = 0
		bob = 0
		if bare:
			if age < Meditation.SETTLE:
				var se: Array = _bare["settle"]
				frame = se[mini(se.size() - 1, floori(age * float(_bare["meta"]["settle"]["fps"])))]
			else:
				var lo: Array = _bare["lotus"]
				frame = lo[floori((age - Meditation.SETTLE) * float(_bare["meta"]["lotus"]["fps"])) % lo.size()]
		elif not _kneel.is_empty():
			frame = _kneel[floori(t * _kneel_fps) % _kneel.size()]
		ax = float(_meta["ax"])
		ay = float(_meta["ay"])
		drop = -roundf(Meditation.lift(age))
	if not med.is_empty() or _med_on:
		_med_on = not med.is_empty()
		_med_back.queue_redraw()
		_med_front.queue_redraw()
	# Tyrien : planches au gabarit propre (cadre plus large pour l'équipement).
	var tyrien := bare and TyrienArt.is_tyrien(frame)
	if tyrien:
		ax = float(TyrienArt.meta["ax"])
		ay = float(TyrienArt.meta["ay"])
	_body.texture = frame
	_body.offset = Vector2(-ax - kick, -ay)
	_sync_gear(frame if tyrien else null)
	_body.position = Vector2(0, -bob + roundf(drop))
	_body.scale = Vector2(-1 if _face < 0 else 1, 1)
	if _mining_seal:
		_mining_seal.tick(_face, _body.position, ReviveFx.body_shown(u))
	if _revive:
		# Rappel : sprite, ombre et barre de vie masqués tant que la bulle n'a pas pris la forme de l'unité.
		var shown := ReviveFx.body_shown(u)
		_body.visible = shown
		_under.visible = shown
		_over.visible = shown
		_revive.tick()
		_heal.tick()
	# Ombre, sélection, barre de vie et badge : redessinés seulement quand leur état change.
	var under_key := selected()
	if under_key != _under_key:
		_under_key = under_key
		_under.queue_redraw()
	var over_key := Vector4(u.hp, u.max_hp, Catalog.lvl(u) * 100 + u.squad + (100000 if preload("res://sim/placeables.gd").posted(u) else 0), world.camera.px if world else 1)
	if over_key != _over_key:
		_over_key = over_key
		_over.queue_redraw()


## Empile sur _body les calques des pièces portées par l'Ingénieur (aucun hors tenue tyrienne).
func _sync_gear(frame: Texture2D) -> void:
	var layers: Array[AtlasTexture] = []
	if frame != null and not unit.equipment.is_empty():
		layers = TyrienArt.overlays(frame, Gear.pieces(unit))
	while _gear.size() < layers.size():
		var s := Sprite2D.new()
		s.centered = false
		s.use_parent_material = true
		_body.add_child(s)
		_gear.append(s)
	for i in _gear.size():
		var s := _gear[i]
		s.visible = i < layers.size()
		if s.visible:
			s.texture = layers[i]
			s.offset = _body.offset


func selected() -> bool:
	if enemy:
		return GameState.hud_enemy == unit and unit.alive()
	return GameState.selected.has(unit) and unit.alive()


func radius() -> float:
	if enemy:
		return 0.85 if unit.role == "brute" or unit.role == "strazhar" else 0.6
	return 0.75 if unit.role == "paladin" else 0.54


## hpY : hauteur visible du sprite + 4 px.
func hp_y() -> float:
	return float(_meta["h"]) + 4.0


## Ombre et sélection, sous le sprite (circle3 et ellipse de contour).
class _UnitDecal extends Node2D:
	var view: UnitView

	func _draw() -> void:
		var r := view.radius()
		_ellipse(r * 1.3 * ZN * 0.9, r * 1.3 * ZN * 0.42, SHADOW)
		if view.selected():
			_ellipse(r * 2.3 * ZN * 0.9, r * 2.3 * ZN * 0.42, FOE_FILL if view.enemy else SEL_FILL)
			# ctx.lineWidth = PX pixels d'écran, soit 1 pixel natif.
			draw_polyline(_ellipse_points(r * 1.75 * ZN * 0.9, r * 1.75 * ZN * 0.42, true), FOE_LINE if view.enemy else SEL_LINE, 1.0, true)

	func _ellipse(rx: float, ry: float, c: Color) -> void:
		draw_colored_polygon(_ellipse_points(rx, ry, false), c)

	static func _ellipse_points(rx: float, ry: float, closed: bool) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 48
		for i in n + (1 if closed else 0):
			var a := TAU * i / n
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		return pts


## Barre de vie au-dessus du sprite (drawCharacter) : 4 px d'écran de haut.
class _UnitBar extends Node2D:
	var view: UnitView
	var _bold: FontVariation

	func _draw() -> void:
		var px := float(view.world.camera.px) if view.world else 1.0
		var w := maxf(12.0 / px, 2.8 * ZN)
		var y := -view.hp_y()
		var u := view.unit
		draw_rect(Rect2(-w / 2.0, y, w, 4.0 / px), HP_BG)
		var fill := HP_ENEMY if view.enemy else (HP_GUARD if u.role == "guard" else HP_ALLY)
		draw_rect(Rect2(-w / 2.0, y, w * maxf(0.0, u.hp / u.max_hp), 4.0 / px), fill)
		if view.enemy:
			return
		# drawLevelBadge : ★niveau au-dessus de la barre (16 px plus haut pour une escouade), gras 10 px d'écran.
		var lvl := Catalog.lvl(u)
		var by := y - (16.0 if u.squad else 5.0) / px
		draw_set_transform(Vector2(0, by), 0.0, Vector2(1.0 / px, 1.0 / px))
		if u.squad:
			_text("I%d" % u.squad, Vector2(0, 10.0), Color("#f5ecca"))
		if lvl >= 2:
			var text := "★%d" % lvl
			_text(text, Vector2(1, 1), Color("#0b0a09cc"))
			_text(text, Vector2.ZERO, Color("#ffe08a"))
		# Bonus de poste de tir : pastille du créneau de rondins au-dessus de l'unité.
		if preload("res://sim/placeables.gd").posted(u):
			var at := Vector2(0, (-10.0 if lvl >= 2 or u.squad else -2.0) - 9.0)
			draw_circle(at, 9.0, Color("#0b0a09b0"))
			draw_arc(at, 9.0, 0.0, TAU, 20, Color("#ffe08a"), 1.0, true)
			preload("res://ui/inventory/item_icon.gd").draw_item(self, "firing_post", at, 0.5)
		draw_set_transform(Vector2.ZERO)

	func _text(text: String, at: Vector2, c: Color) -> void:
		if _bold == null:
			_bold = FontVariation.new()
			_bold.base_font = load("res://assets/fonts/DejaVuSans.ttf")
			_bold.variation_embolden = 0.7
		var w := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_bold, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c)


## Calques de la méditation (Meditation.draw_back / draw_front), aux pieds de l'unité.
class _MedFx extends Node2D:
	var view: UnitView
	var front := false

	func _draw() -> void:
		if front:
			Meditation.draw_front(self, view.unit, view._face, view.position)
		else:
			Meditation.draw_back(self, view.unit, view._face)
