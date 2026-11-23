class_name EffectsDrawer
extends RefCounted
## Effets de combat dessinés à la résolution de l'écran (drawEffects, drawFireWalls, drawTurretBolts,
## Index.html, adepts.js, turret-game.js, 73b410f) : rivet de l'Ingénieur, flèche de l'archer, carreaux et
## explosions du Tireur (pixels natifs, npx), impacts (sphère dégradée), rayons, zones, murs de feu,
## carreaux des balistes. Les tirages (rng(seed)) reproduisent ceux du prototype.

const ItemIcon := preload("res://ui/inventory/item_icon.gd")

## Rivet de l'Ingénieur en cyan des Exilés (planche « Visibilité des balles », piste 5·B, 2026-11-20) : le jaune est
## laissé aux tirs ennemis. Avant : traînée #4a2206 → #ffe08a, corps laiton #f0cc6a, flanc #6a4a14, pointe #fff0b0.
const RIVET_GLOW: Array[Color] = [Color("#0a2a33"), Color("#12596b"), Color("#1f9fb8"), Color("#5ce8ff"), Color("#c8fbff")]
const RIVET_BRASS := Color("#5ce8ff")
const RIVET_DARK := Color("#12596b")
const RIVET_TIP := Color("#c8fbff")
const ARROW_SHAFT := Color("#6c4c2e")
const ARROW_HEAD := Color("#d6d9dc")
const ARROW_TIP := Color("#bcdcff")
const ARROW_FL := Color("#ac3438")
const ARROW_SPARK: Array[Color] = [Color("#18448e"), Color("#2e6cc8"), Color("#64a2f4"), Color("#bcdcff")]
const FIRE: Array[Color] = [Color("#5a1408"), Color("#a82a10"), Color("#e85a18"), Color("#ff9a30"), Color("#ffd060"), Color("#fff4c0")]
const INK := Color("#0a0a0c")
## Buse du lance-flammes (refonte 16 bits, planches/refonte-16bits-export.html) : pointe de la buse en position
## de tir, en pixels natifs depuis le point au sol, regard à droite (la Caserne est dessinée à l'échelle 1).
const FLAME_NOZZLE := Vector2(13.0, -12.5)
## Pitons d'ancrage de l'Ingénieur (planche « Pitons d'ancrage — Suspension ») : cyan des Exilés et laiton.
const CY: Array[Color] = [Color("#0a2a33"), Color("#12596b"), Color("#1f9fb8"), Color("#5ce8ff"), Color("#c8fbff"), Color("#ffffff")]
const BRASS: Array[Color] = [Color("#3a2808"), Color("#6a4a14"), Color("#a07424"), Color("#d0a03c"), Color("#f0cc6a"), Color("#fff0b0")]
## Tramage ordonné 4 × 4 (BAYER, decor.js).
const BAYER := [[0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16], [12.5 / 16, 4.5 / 16, 14.5 / 16, 6.5 / 16],
	[3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16], [15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16]]

var ci: CanvasItem
var world: World
var px := 1.0
## Préchauffage (étape 12) : pendant les premières images, un exemplaire de chaque effet est dessiné hors
## de l'écran avec le vrai code de dessin, pour que les shaders soient compilés au chargement et non au
## premier tir (jusqu'à 300 ms d'arrêt mesurés au premier rivet). L'état de la partie n'est pas touché.
var warmup_frames := 2


static func jr(v: float) -> float:
	return floorf(v + 0.5)


## natP : position native à l'écran, arrondie.
func nat_p(x: float, z: float) -> Vector2:
	var n := Proj.nat(x, 0.0, z) + world.native_offset
	return Vector2(jr(n.x), jr(n.y))


## npx : un pixel natif (PX × PX pixels d'écran).
func npx(x: float, y: float, c: Color) -> void:
	ci.draw_rect(Rect2(jr(x) * px, jr(y) * px, px, px), c)


## Mages cristallisés (sim/mages.gd) : cercle pointillé orange du rayon de l'aura autour de chaque Chantre, filet
## vert de la Guérisseuse vers celui qu'elle soigne, bouclier fendu violet au-dessus des ennemis envoûtés.
const HEX_GLYPH: Array[Vector2i] = [Vector2i(-3, -3), Vector2i(-2, -3), Vector2i(-1, -3), Vector2i(1, -3), Vector2i(2, -3), Vector2i(3, -3), Vector2i(-3, -2), Vector2i(3, -2),
	Vector2i(-3, -1), Vector2i(3, -1), Vector2i(-3, 0), Vector2i(3, 0), Vector2i(-2, 1), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, 3)]
const HEX_CRACK: Array[Vector2i] = [Vector2i(0, -2), Vector2i(-1, -1), Vector2i(0, 0), Vector2i(1, 1)]


func _mage_marks(now: float) -> void:
	for u: Unit in GameState.units:
		if not u.alive() or u.hidden or not Catalog.is_mage(u.role) or not world.fog.visible_at(u.pos()):
			continue
		if u.role == "chantre":
			var r: float = Catalog.MAGE["chantre"]["radius"]
			var lit := u.working
			for k in 240:
				if (k + (floori(now * 8.0) if lit else 0)) % 4 >= 2:
					continue
				var a := TAU * k / 240.0
				var p := nat_p(u.x + cos(a) * r, u.z + sin(a) * r)
				ci.draw_rect(Rect2(roundf(p.x) * px, roundf(p.y) * px, px, px), Color("#ff9a3a", 0.85 if lit else 0.35))
		elif u.role == "guerisseuse" and u.working and u.memo.has("heal_target"):
			var a := nat_p(u.x, u.z) - Vector2(0, 16)
			var b := nat_p((u.memo["heal_target"] as Vector2).x, (u.memo["heal_target"] as Vector2).y) - Vector2(0, 12)
			var n := maxi(2, int(a.distance_to(b) / 3.0))
			for k in n:
				var t := (float(k) + fmod(now * 3.0, 1.0)) / n
				var p := a.lerp(b, t) + Vector2(0, -sin(t * PI) * 5.0)
				ci.draw_rect(Rect2(roundf(p.x) * px, roundf(p.y) * px, px, px), Color("#5ce8a8", 0.9))
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0 or not Mages.hexed(e) or not world.fog.visible_at(e.pos()):
			continue
		var top := nat_p(e.x, e.z) - Vector2(0, float(e.body()["top"]) * 8.0 + 14.0)
		var o := Vector2(roundf(top.x), roundf(top.y + sin(now * 4.0)))
		for q: Vector2i in HEX_GLYPH:
			ci.draw_rect(Rect2((o + Vector2(q)) * px, Vector2(px, px)), Color("#d6c8ff"))
		for q: Vector2i in HEX_CRACK:
			ci.draw_rect(Rect2((o + Vector2(q)) * px, Vector2(px, px)), Color("#9a7aff"))


## Phare du butin (planches/butin-propositions.html, piste 1 « Le phare », renforcée le 2026-11-21) : disque tramé
## au sol qui pulse, anneau, trait de lumière haut de 60 px natifs (cœur éclairci, gaine large) et éclats qui
## montent le long du trait. Un butin normal garde le petit trait d'avant et scintille toutes les 2 s.
## `ground` = point au sol, `lift` = hauteur du pied du trait au-dessus du sol (pixels natifs).
func _loot_beacon(ground: Vector2, c: Color, now: float, normal: bool, lift := 4.0) -> void:
	var x := roundf(ground.x / px) * px
	var y := roundf(ground.y / px) * px
	var phase := ground.x * 0.05
	if normal:
		_loot_beam(Vector2(x, y - lift * px), c, now)
		var g := fmod(now * 0.5 + phase * 0.2, 1.0)
		if g < 0.18:
			var n := int(g * 22.0) % 4
			var at := Vector2(x, y - (lift + 3.0) * px)
			ci.draw_rect(Rect2(at.x - px, at.y - px, 2 * px, 2 * px), Color.WHITE)
			ci.draw_rect(Rect2(at.x - (n + 1) * px, at.y, (n * 2 + 2) * px, px), Color(1, 1, 1, 0.7))
			ci.draw_rect(Rect2(at.x, at.y - (n + 1) * px, px, (n * 2 + 2) * px), Color(1, 1, 1, 0.7))
		return
	var pulse := 0.5 + 0.5 * sin(now * 3.0 + phase)
	var core := c.lerp(Color.WHITE, 0.55)
	# Disque au sol, tramé une case sur deux sur le pourtour.
	var rx := 9.0 + pulse * 2.0
	var ry := 3.0 + pulse
	for j in range(-int(ry), int(ry) + 1):
		var w := roundf(rx * sqrt(maxf(0.0, 1.0 - float(j * j) / (ry * ry))))
		ci.draw_rect(Rect2(x - w * px, y + j * px, 2 * w * px, px), Color(c, 0.36))
	for i in 48:
		var t := float(i) / 48.0 * TAU
		var q := Vector2(roundf(cos(t) * (rx + 1.5 + pulse)), roundf(sin(t) * (ry + 0.6)))
		ci.draw_rect(Rect2(x + q.x * px, y + q.y * px, px, px), Color(core, 1.0))
	# Trait : cinq paliers de 12 px, gaine de 6 px puis de 4 px, cœur éclairci de 2 px.
	var base := y - lift * px
	var step := (12.0 + roundf(sin(now * 2.5 + phase) * 2.0)) * px
	var fade: Array[float] = [1.0, 0.8, 0.55, 0.32, 0.14]
	for i in 5:
		var top := base - (i + 1) * step
		ci.draw_rect(Rect2(x - 3 * px, top, 6 * px, step), Color(c, 0.2 * fade[i]))
		ci.draw_rect(Rect2(x - 2 * px, top, 4 * px, step), Color(c, 0.55 * fade[i]))
		ci.draw_rect(Rect2(x - px, top, 2 * px, step), Color(core, 0.95 * fade[i]))
	# Éclats qui montent le long du trait.
	for k in 3:
		var u := fmod(now * 0.7 + k / 3.0 + phase, 1.0)
		var side := -2.0 if k % 2 == 0 else 1.0
		ci.draw_rect(Rect2(x + side * px, base - u * 5.0 * step, px, px), Color(core, 1.0 - u))
	ci.draw_rect(Rect2(x - 3 * px, base - px, 6 * px, px), Color(core, 0.95))


## Trait de lumière en quatre paliers au-dessus d'un butin normal, base en `at` (pixels d'écran).
func _loot_beam(at: Vector2, c: Color, now: float) -> void:
	var x := roundf(at.x / px) * px
	var y := roundf(at.y / px) * px
	var step := 6.0 + roundf(sin(now * 2.5 + at.x * 0.05))
	for i in 4:
		ci.draw_rect(Rect2(x - px, y - (i + 1) * step * px, 2 * px, step * px), Color(c, [0.95, 0.7, 0.45, 0.2][i]))
		if i < 2:
			ci.draw_rect(Rect2(x - 2 * px, y - (i + 1) * step * px, 4 * px, step * px), Color(c, 0.18))
	ci.draw_rect(Rect2(x - 3 * px, y - px, 6 * px, px), Color(c, 0.9))


func draw_all(now: float) -> void:
	px = float(world.camera.px)
	if warmup_frames > 0:
		warmup_frames -= 1
		_warmup()
	for drop: Dictionary in GameState.ground_items:
		var position: Vector2 = drop["position"]
		if not world.fog.visible_at(position):
			continue
		var screen := nat_p(position.x, position.y) * px
		var rarity := Loot.rarity_of(drop["item"])
		if rarity != "normal":
			_loot_beacon(screen + Vector2(0, 3 * px), Loot.rarity_color(drop["item"]), now, false, 11.0)
		ci.draw_circle(screen + Vector2(0, 3 * px), 7 * px, Color("#00000066"))
		ItemIcon.draw_item(ci, drop["item"], screen, px)
	# Corps à fouiller (sim/loot.gd) : trait de lumière de la couleur de la meilleure rareté, une fois le corps tombé.
	for corpse: Enemy in GameState.enemy_corpses:
		if corpse.loot.is_empty() or GameState.sim_time - corpse.died_at < 1.0 or not world.fog.visible_at(corpse.pos()):
			continue
		var best := Loot.best_rarity(corpse.loot)
		_loot_beacon(nat_p(corpse.x, corpse.z) * px, Loot.RARITY[best]["color"], now, best == "normal", 5.0)
	# Caches de la jungle encore pleines : même trait de lumière.
	for cache: Dictionary in GameState.caches:
		if (cache["loot"] as Array).is_empty() or not world.fog.visible_at(Vector2(cache["x"], cache["z"])):
			continue
		var cbest := Loot.best_rarity(cache["loot"])
		_loot_beacon(nat_p(cache["x"], cache["z"]) * px, Loot.RARITY[cbest]["color"], now, cbest == "normal", 9.0)
	_mage_marks(now)
	_harvest_marks()
	_fire_walls(now)
	_skel_chains()
	for e in GameState.effects:
		if e.has("x") and e.has("z") and not world.fog.visible_at(Vector2(e["x"], e["z"])):
			continue
		match e["type"]:
			"mining_gain": _mining_gain(e)
			"harvest_hit": _harvest_hit(e)
			"new_resource": _new_resource(e)
			"rivet": _rivet(e)
			"rivethit": _rivet_hit(e)
			"arrow": _arrow(e)
			"arrowhit": _arrow_hit(e)
			"pilum": _pilum(e)
			"orb": _orb(e)
			"orbhit": _orb_hit(e)
			"xbolt": _xbolt(e)
			"xboom": _xboom(e)
			"piton": _piton_flight(e)
			"suspend": _suspend(e, now)
			"slash": _slash(e)
			"cball": _cball(e)
			"xbow_fire": _xbow_fire(e)
			"cballhit": _cball_hit(e)
			"aether_wave": _aether_wave(e)
			"heal_motes": _heal_motes(e)
			"skel_bile", "skel_boom": _skel_wave(e)
			_: _simple(e)
	_planted_pitons(now)
	for e in GameState.damage_numbers:
		if world.fog.visible_at(Vector2(e["x"], e["z"])):
			_damage_number(e)
	_turret_bolts()


# ---------------------------------------------------------------- Squelettes de la nuit (sim/skeletons.gd)

const SKEL_BILE: Array[Color] = [Color("#5e6212"), Color("#98a022"), Color("#ccd24a"), Color("#f2f6a0")]
const SKEL_FIRE: Array[Color] = [Color("#c23a08"), Color("#f2800e"), Color("#ffc83a"), Color("#fff6c0")]
const SKEL_CHAIN: Array[Color] = [Color("#7a8496"), Color("#d6dce8")]
## Hauteur du collier au-dessus des pieds, en pixels natifs.
const SKEL_NECK := 20.0


## Chaîne entre les colliers d'un même groupe : pendante tant qu'il y a du mou, blanche et droite à bout de course.
func _skel_chains() -> void:
	for e: Enemy in GameState.enemies:
		if e.kind != Skeletons.COLLAR or e.hp <= 0.0 or not e.memo.has("pack"):
			continue
		for o: Enemy in e.memo["pack"]:
			# Chaque paire une seule fois.
			if o.hp <= 0.0 or o.get_instance_id() <= e.get_instance_id():
				continue
			if not world.fog.visible_at(e.pos()) and not world.fog.visible_at(o.pos()):
				continue
			var d := e.pos().distance_to(o.pos())
			var taut := d > Skeletons.TETHER - 0.5
			var a := nat_p(e.x, e.z) - Vector2(0.0, SKEL_NECK)
			var b := nat_p(o.x, o.z) - Vector2(0.0, SKEL_NECK)
			var sag := minf(10.0, 0.08 * Proj.K * sqrt(maxf(0.0, Skeletons.TETHER * Skeletons.TETHER - d * d)))
			# Maillons de 2 × 2 pixels, un clair, un sombre, cernés de noir pour rester lisibles sur l'herbe et sur les os.
			var n := maxi(2, roundi(a.distance_to(b) / 3.0))
			for pass_i in 2:
				for k in n + 1:
					var t := float(k) / n
					var p := a.lerp(b, t)
					var y := p.y + sag * 4.0 * t * (1.0 - t)
					if pass_i == 0:
						for q: Vector2 in [Vector2(-1, 0), Vector2(2, 0), Vector2(-1, 1), Vector2(2, 1), Vector2(0, -1), Vector2(1, -1), Vector2(0, 2), Vector2(1, 2)]:
							npx(p.x + q.x, y + q.y, INK)
					else:
						var c: Color = Color.WHITE if taut else SKEL_CHAIN[k % 2]
						for q: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
							npx(p.x + q.x, y + q.y, c)


## Onde de bile (bubon) ou souffle (explosif) : anneaux de pixels qui s'ouvrent jusqu'au rayon réel, puis s'effacent.
func _skel_wave(e: Dictionary) -> void:
	var p: float = e["age"] / e["duration"]
	var pal: Array[Color] = SKEL_BILE if e["type"] == "skel_bile" else SKEL_FIRE
	var c := nat_p(e["x"], e["z"])
	var open := minf(1.0, p / 0.45)
	var r: float = float(e["r"]) * Proj.K * (1.0 - (1.0 - open) * (1.0 - open))
	var al := 1.0 - p * p
	if e["type"] == "skel_boom" and p < 0.15:
		ndisc(c.x, c.y - 8.0, 10.0, SKEL_FIRE[3], 1.0)
	for ring: Array in [[1.0, 3, 1], [0.86, 2, 2], [0.66, 1, 3], [0.42, 0, 4]]:
		var rr: float = r * float(ring[0])
		var n := maxi(8, ceili(rr * 3.0))
		for k in n:
			if (k / int(ring[2])) % 2 == 1 and int(ring[2]) > 1:
				continue
			var t := TAU * k / n + p * float(ring[2])
			dpx(c.x + cos(t) * rr, c.y + sin(t) * rr, pal[int(ring[1])], al)
			if int(ring[2]) == 1:
				dpx(c.x + cos(t) * (rr - 1.0), c.y + sin(t) * (rr - 1.0), pal[2], al)


## Point au-dessus de la tête de `u` (barre de vie), ou null si son nœud n'est pas affiché.
func _head(u: Unit) -> Variant:
	var view := world.unit_view(u)
	if not is_instance_valid(view) or not view.is_visible_in_tree():
		return null
	if view is UnitView:
		return world.camera.project(u.x, 0, u.z) - Vector2(0, view.hp_y() * px)
	return world.camera.project(u.x, 3.9, u.z)


## Texte centré, contour noir, `alpha` appliqué au texte et au contour.
func _outlined_c(text: String, at: Vector2, size: int, color: Color, alpha: float) -> void:
	var font := HudStyle.font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := (at - Vector2(width * 0.5, 0)).round()
	ci.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(INK, alpha))
	ci.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))


## Chiffre de dégâts en police bitmap : entier, monte au-dessus de la cible et s'efface dans le dernier tiers.
## Ivoire sur un ennemi, saumon sur un allié, vert pour un soin ; un coup arrondi à zéro ne s'affiche pas, et
## les chiffres simultanés d'une même cible s'écartent en éventail au lieu de s'empiler.
const DAMAGE_FAN: Array[float] = [0.0, 11.0, -11.0, 20.0, -20.0]


func _damage_number(effect: Dictionary) -> void:
	var t: Unit = effect["target"]
	var view := world.unit_view(t)
	var at: Variant = _head(t) if is_instance_valid(view) else world.camera.project(effect["x"], 3.9, effect["z"])
	if at == null:
		return
	var head: Vector2 = at
	if effect["age"] < 0.0:
		return
	var value := roundi(effect["amount"])
	if value <= 0:
		return
	var p: float = effect["age"] / effect["duration"]
	var alpha := clampf((1.0 - p) * 3.0, 0.0, 1.0)
	var rank := 0
	for other in GameState.damage_numbers:
		if is_same(other, effect):
			break
		if other["target"] == t and other["age"] >= 0.0:
			rank += 1
	var heal: bool = effect.get("heal", false)
	var foe: bool = is_instance_valid(view) and view is UnitView and (view as UnitView).enemy
	var color := Color("#6fd36b") if heal else (Color("#f4ecd6") if foe else Color("#f08f86"))
	var fan := DAMAGE_FAN[rank % DAMAGE_FAN.size()]
	PixelText.draw(ci, head - Vector2(-fan * (0.4 + 0.6 * p), 6 + 30 * p), ("+%d" % value) if heal else str(value), color, 2, alpha)


## « Nouvelle ressource : … ! » en jaune au-dessus du récolteur, au-dessus du « +1 ».
func _new_resource(effect: Dictionary) -> void:
	var at: Variant = _head(effect["miner"])
	if at == null:
		return
	var head: Vector2 = at
	var p: float = effect["age"] / effect["duration"]
	var label := "Nouvelle ressource : %s !" % ItemIcon.Blocks.ITEMS[effect["item"]]["name"]
	var alpha := clampf((1.0 - p) * 4.0, 0.0, 1.0)
	PixelText.draw(ci, head - Vector2(0, 58 + 14 * p), label, Color("#f4ecd6"), 2, alpha)


func _mining_gain(effect: Dictionary) -> void:
	var miner: Unit = effect["miner"]
	var at: Variant = _head(miner)
	if at == null:
		return
	if effect.has("from"):
		_harvest_jump(effect, miner)
		return
	var head: Vector2 = at
	var item: String = effect["item"]
	var label := "+1 %s" % ItemIcon.Blocks.ITEMS[item]["name"]
	var font := HudStyle.font()
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var origin := (head - Vector2((26 + width) * 0.5, 24 + 26 * float(effect["age"]))).round()
	ItemIcon.draw_item(ci, item, origin + Vector2(11, -5), 0.75)
	var baseline := origin + Vector2(26, 0)
	ci.draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, INK)
	ci.draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#fff2ce"))


# ---------------------------------------------------------------- Récolte des esprits (sim/harvest_fx.gd)
# Planche « Effets de récolte », choix « 1 + 3 + saut » (2026-11-21) : éclats de matière, fissures du bloc qui se
# referment à chaque objet, feuille du bosquet, paillette du filon, ∞ sur le node travaillé, saut de l'objet. Les
# crans de charge sont dessinés par AdeptView.

const HARVEST_DUST := Color("#b8b0a0")
const HARVEST_LEAF: Array[Color] = [Color("#2f5e2c"), Color("#4f8e3c"), Color("#7cbc52")]
const HARVEST_INF := Color("#e0b04a")
## ∞ (7 × 3 pixels natifs).
const HARVEST_INF_MAP := [".##.##.", "#..#..#", ".##.##."]
## Fissures du bloc, depuis le point frappé : une de plus par coup, effacées au coup qui donne l'objet.
const HARVEST_CRACKS := [[Vector2(0, 0), Vector2(-3, 5), Vector2(-1, 10), Vector2(-4, 16)],
	[Vector2(0, 0), Vector2(4, -4), Vector2(3, -9), Vector2(7, -14)],
	[Vector2(0, 0), Vector2(-7, -2), Vector2(-10, -7), Vector2(-13, -6)],
	[Vector2(0, 0), Vector2(8, 5), Vector2(11, 11), Vector2(13, 17)]]
## Paillettes du filon, depuis l'origine du nœud (milieu du bord bas de l'emprise), pixels natifs.
const HARVEST_GLINTS: Array[Vector2] = [Vector2(-23, -32), Vector2(2, -14), Vector2(22, -50), Vector2(27, -29), Vector2(19, -14), Vector2(4, -29)]


## Point frappé, en pixels natifs.
func _harvest_point(h: Dictionary) -> Vector2:
	return nat_p(h["x"], h["z"]) - Vector2(0, roundf(float(h["h"]) * Proj.KH))


## Origine native d'un filon ou d'un bosquet (milieu du bord bas de son emprise 2 × 2).
func _node_origin(o: Vector2i) -> Vector2:
	return nat_p(o.x * 4.0 + 4.0, o.y * 4.0 + 8.0)


func _harvest_ramp(item: String) -> Array[Color]:
	var base: Color = ItemIcon.Blocks.ITEMS.get(item, {}).get("color", Color("#9da2a9"))
	return [base.darkened(0.55), base.darkened(0.2), base, base.lightened(0.4)]


## Un coup : éclats projetés à l'opposé de l'esprit, poussière au pied, fissures du bloc, feuille du bosquet.
func _harvest_hit(e: Dictionary) -> void:
	var t: float = e["age"]
	var p := _harvest_point(e)
	var ramp := _harvest_ramp(e["item"])
	var sd: int = e["seed"]
	var dir: float = e["dir"]
	var last: bool = int(e["k"]) >= int(e["n"])
	var block: bool = e["node"] == "block"
	if block and not last:
		for L in mini(int(e["k"]), HARVEST_CRACKS.size()):
			var path: Array = HARVEST_CRACKS[L]
			for q in path.size() - 1:
				_px_line(p + path[q] + Vector2.ONE, p + path[q + 1] + Vector2.ONE, ramp[2])
				_px_line(p + path[q], p + path[q + 1], INK)
	# Au coup qui donne l'objet, un morceau du bloc se détache : plus d'éclats, plus gros, partout.
	var burst := block and last
	for i in 14 if burst else 6:
		var life := 0.45 + Rng.hash3(i, sd, 1) * 0.25
		if t > life:
			continue
		var vx := dir * (15.0 + Rng.hash3(i, sd, 2) * 40.0) + (Rng.hash3(i, sd, 3) - 0.5) * 30.0
		var vy := -(25.0 + Rng.hash3(i, sd, 4) * 45.0)
		var o := Vector2.ZERO
		if burst:
			vx = (Rng.hash3(i, sd, 2) - 0.5) * 60.0
			vy = -(10.0 + Rng.hash3(i, sd, 4) * 40.0)
			o = Vector2((Rng.hash3(i, sd, 7) - 0.5) * 20.0, (Rng.hash3(i, sd, 8) - 0.5) * 16.0)
		var q := p + o + Vector2(vx * t, vy * t + 85.0 * t * t)
		var c: Color = ramp[1 + int(Rng.hash3(i, sd, 5) * 3.0) % 3]
		var s := 2.0 if Rng.hash3(i, sd, 6) < (0.5 if burst else 0.35) else 1.0
		ci.draw_rect(Rect2(jr(q.x) * px, jr(q.y) * px, s * px, s * px), Color(c, clampf((1.0 - t / life) * 2.5, 0.0, 1.0)))
	if t < 0.5:
		for i in 3:
			var r := 1.0 + Rng.hash3(i, sd, 9) + t * 6.0
			var at := p + Vector2((Rng.hash3(i, sd, 10) - 0.5) * 8.0, 6.0 + Rng.hash3(i, sd, 11) * 4.0 - t * 6.0)
			ci.draw_rect(Rect2(jr(at.x - r) * px, jr(at.y - r * 0.6) * px, roundf(r * 2.0) * px, maxf(1.0, roundf(r * 1.2)) * px),
				Color(HARVEST_DUST, 0.45 * (1.0 - t / 0.5)))
	# Bosquet : une feuille tombe du houppier un coup sur deux.
	if e["node"] == "grove" and int(e["k"]) % 2 == 1:
		var top := _node_origin(e["origin"])
		var ph := Rng.hash3(1, sd, 12) * TAU
		var lp := Vector2(p.x - 6.0 + Rng.hash3(2, sd, 13) * 14.0 + sin(t * 5.0 + ph) * 2.0, top.y - 66.0 + Rng.hash3(3, sd, 14) * 10.0 + 12.0 * t)
		var la := clampf((1.9 - t) * 3.0, 0.0, 1.0)
		ci.draw_rect(Rect2(jr(lp.x) * px, jr(lp.y) * px, 2 * px, px), Color(HARVEST_LEAF[int(Rng.hash3(4, sd, 15) * 3.0) % 3], la))
		ci.draw_rect(Rect2(jr(lp.x + (1.0 if sin(t * 5.0 + ph) > 0.0 else 0.0)) * px, jr(lp.y + 1.0) * px, px, px), Color(HARVEST_LEAF[0], la))


func _px_line(a: Vector2, b: Vector2, c: Color) -> void:
	var n := maxi(1, roundi(a.distance_to(b)))
	for i in n + 1:
		npx(lerpf(a.x, b.x, float(i) / n), lerpf(a.y, b.y, float(i) / n), c)


## L'objet gagné jaillit du point frappé, décrit un arc et tombe dans la charge de l'esprit ; « +1 » à l'arrivée.
## Sur un filon, une paillette s'y rallume (il ne s'épuise pas).
func _harvest_jump(effect: Dictionary, miner: Unit) -> void:
	var t: float = effect["age"]
	var from: Dictionary = effect["from"]
	var a := _harvest_point(from)
	var b := nat_p(miner.x, miner.z) - Vector2(0, 30)
	var item: String = effect["item"]
	var s := px * 0.35
	if from["node"] == "lode" and t < 0.9:
		var g: Vector2 = _node_origin(from["origin"]) + HARVEST_GLINTS[int(Rng.hash3(int(float(from["x"]) * 7.0), int(float(from["z"]) * 7.0), 3) * 6.0) % 6]
		var r := roundi(t / 0.3 * 3.0) if t < 0.3 else roundi((1.0 - (t - 0.3) / 0.6) * 3.0)
		for i in range(-r, r + 1):
			npx(g.x + i, g.y, Color.WHITE if i == 0 else Color("#ffd9a0"))
			npx(g.x, g.y + i, Color.WHITE if i == 0 else Color("#ffd9a0"))
	if t < 0.6:
		var e := t / 0.6
		var q := a.lerp(b, e) - Vector2(0, sin(e * PI) * 20.0)
		ItemIcon.draw_item(ci, item, q * px, s)
		return
	var u := (t - 0.6) / 0.4
	var font := HudStyle.font()
	var at := (b * px - Vector2(0, (8.0 + u * 10.0) * px)).round()
	var col := Color("#fff2ce", 1.0 - u)
	ci.draw_string_outline(font, at, "+1", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, 4, Color(INK, 1.0 - u))
	ci.draw_string(font, at, "+1", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, col)


## ∞ au-dessus de chaque bloc, filon ou bosquet qu'un esprit travaille en ce moment.
func _harvest_marks() -> void:
	var seen := {}
	var st: TerrainState = world.terrain_state
	for u: Unit in GameState.units:
		if not u.working or u.hidden or not Catalog.is_adept(u) or not (u.job is Dictionary):
			continue
		var j: Dictionary = u.job
		if not (j.get("type") == "dig" or (j.get("type") == "staff" and j.get("step") == "mine")) or not (j.get("cell") is Dictionary):
			continue
		var key := Vector2i(j["cell"]["i"], j["cell"]["j"])
		var at: Vector2
		if st.lode_cells.has(key) or st.grove_cells.has(key):
			var o: Vector2i = st.lode_cells[key] if st.lode_cells.has(key) else st.grove_cells[key]
			if seen.has(o):
				continue
			seen[o] = true
			at = _node_origin(o) + Vector2(-3, -78 if st.lode_cells.has(key) else -100)
		else:
			if seen.has(key):
				continue
			seen[key] = true
			at = nat_p(key.x * 4.0 + 2.0, key.y * 4.0) + Vector2(-3, -10)
		if not world.fog.visible_at(u.pos()):
			continue
		ci.draw_rect(Rect2((at.x - 1) * px, (at.y - 1) * px, 9 * px, 5 * px), Color(INK, 0.85))
		for r in 3:
			for q in 7:
				if HARVEST_INF_MAP[r][q] == "#":
					npx(at.x + q, at.y + r, HARVEST_INF)


func _z() -> float:
	return 8.0 * px / 0.86


# ---------------------------------------------------------------- Rivet

func _rivet_path(e: Dictionary, p: float) -> Vector2:
	var s := nat_p(e["x"], e["z"])
	var t := nat_p(e["tx"], e["tz"])
	var a := Vector2(s.x + e["face"] * 10.0, s.y - 22.0)
	var b := Vector2(t.x, t.y - 14.0)
	return a + (b - a) * p


func _rivet(e: Dictionary) -> void:
	var p := minf(1.0, e["age"] / e["duration"])
	var q := _rivet_path(e, p)
	var q0 := _rivet_path(e, maxf(0.0, p - 0.05))
	var l := q.distance_to(q0)
	if l == 0.0:
		l = 1.0
	var ux := (q.x - q0.x) / l
	var uy := (q.y - q0.y) / l
	var R := Rng.new(e["seed"])
	for i in range(1, 11):
		if R.next() < 1.0 - i / 11.0:
			npx(q.x - ux * i * 1.6, q.y - uy * i * 1.6, RIVET_GLOW[maxi(1, 4 - (i >> 1))])
	for i in range(-1, 5):
		npx(q.x - ux * i + uy, q.y - uy * i - ux, INK)
		npx(q.x - ux * i - uy * 2.0, q.y - uy * i + ux * 2.0, INK)
	for i in 4:
		npx(q.x - ux * i, q.y - uy * i, RIVET_TIP if i < 1 else RIVET_BRASS)
		npx(q.x - ux * i - uy, q.y - uy * i + ux, RIVET_DARK)
	npx(q.x + ux, q.y + uy, Color.WHITE)


func _rivet_hit(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p: float = e["age"] / e["duration"]
	var o: Variant = e["tgt"] if e["tgt"] and e["tgt"].hp > 0.0 else null
	var at := nat_p(o.x, o.z) if o else nat_p(e["x"], e["z"])
	var cy := at.y - 14.0
	var face: float = e["face"]
	var hx := at.x - face * 3.0
	var R := Rng.new(e["seed"])
	if p < 0.25:
		var q := p / 0.25
		for k in 8:
			var a := k / 8.0 * 6.283 + R.next() * 0.5
			var d := 1.0 + q * 6.0
			if R.next() > q * 0.7:
				npx(hx + cos(a) * d, cy + sin(a) * d * 0.7, RIVET_GLOW[4 if q < 0.5 else 3])
	var c := RIVET_TIP if p < 0.3 else (RIVET_GLOW[3] if p < 0.6 else (RIVET_GLOW[2] if p < 0.85 else RIVET_GLOW[1]))
	npx(hx, cy, c)
	npx(hx - face, cy, c)
	npx(hx - face * 2.0, cy, RIVET_DARK)


# ---------------------------------------------------------------- Flèche

func _arrow_path(e: Dictionary, p: float) -> Vector2:
	var s := nat_p(e["x"], e["z"])
	var t := nat_p(e["tx"], e["tz"])
	var x0: float = s.x + e["face"] * float(e.get("ox", 12.0))
	var y0: float = s.y - float(e.get("oy", 24.0))
	var x1 := t.x
	var y1 := t.y - 14.0
	var h := 1.0 + Vector2(x1 - x0, y1 - y0).length() * 0.025
	return Vector2(x0 + (x1 - x0) * p, y0 + (y1 - y0) * p - h * 4.0 * p * (1.0 - p))


## Taille d'épée du Creuset (planches/armes-attaques.html) : arc blanc courbé à la portée du coup (3 blocs),
## balayé de la droite vers la gauche du personnage (à deux mains : de l'épaule gauche, en haut, à la taille côté
## droit, en bas) ; épais et opaque à la tête, fin et transparent à la queue, puis s'efface.
func _slash(e: Dictionary) -> void:
	var age: float = e["age"]
	if age < 0.0:
		return
	var p := age / float(e["duration"])
	var base := atan2(float(e["dz"]), float(e["dx"]))
	var two: bool = e["two"]
	var a0 := base - PI * 0.5 if two else base + PI * 0.5
	var a1 := base + PI * 0.5 if two else base - PI * 0.5
	var head := clampf(p / 0.55, 0.0, 1.0)
	var fade := 1.0 - clampf((p - 0.55) / 0.45, 0.0, 1.0)
	var span := 0.6
	var r: float = e["r"]
	var steps := 48
	for i in steps + 1:
		var u := float(i) / steps
		var t := head - span + span * u
		if t < 0.0:
			continue
		var ang := lerpf(a0, a1, t)
		var y := lerpf(2.6, 0.5, t) if two else 1.2
		var n := Proj.nat(float(e["x"]) + cos(ang) * r, y, float(e["z"]) + sin(ang) * r) + world.native_offset
		var w := 2 if u > 0.75 else (1 if u > 0.35 else 0)
		var c := Color(1, 1, 1, (0.25 + 0.75 * u) * fade)
		for dy in range(-w, w + 1):
			npx(n.x, n.y + dy, c)
		if u > 0.6:
			npx(n.x, n.y - w - 1, Color(0.8, 0.94, 1.0, 0.7 * fade))


## Munitions de l'Arbalestrie modulaire (planches/arbalestrie-modulaire-planche.html, data/ammo.gd) :
## Indra orange, Medeina vert, Sigil marbre gris veiné, Aether bleu-violet (le pourpre reste à l'Ancre).
const AMMO_PAL := {
	"indra": [Color("#2a1204"), Color("#7a3208"), Color("#d0680e"), Color("#ff9a2a"), Color("#ffd08a"), Color("#fff4e0")],
	"medeina": [Color("#0c2410"), Color("#1f5a26"), Color("#3c9a3e"), Color("#6fd36b"), Color("#c4f5b0"), Color("#f4fff0")],
	"sigil": [Color("#1e1f24"), Color("#4a4c54"), Color("#8a8c94"), Color("#c4c3bf"), Color("#e8e4da"), Color("#ffffff")],
	"aether": [Color("#0e1030"), Color("#2a2e7a"), Color("#4f55c8"), Color("#8a8cf0"), Color("#c8c8ff"), Color("#ffffff")],
}
const RING8: Array[Vector2] = [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]
## Liseré clair autour du cerne d'encre 3 × 3 des balles (5 × 5 aux coins rognés) : détache la balle du sol sombre.
const RIM12: Array[Vector2] = [Vector2(-1, -2), Vector2(0, -2), Vector2(1, -2), Vector2(-1, 2), Vector2(0, 2), Vector2(1, 2),
		Vector2(-2, -1), Vector2(-2, 0), Vector2(-2, 1), Vector2(2, -1), Vector2(2, 0), Vector2(2, 1)]
const CROSS5: Array[Vector2] = [Vector2(0, 0), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]


# ---------------------------------------------------------------- Tir de l'Arbalestrie

## Bouche et culasse de l'Arbalestrie sur les images de tir (c_shoot), en pixels natifs depuis le point au sol,
## Ingénieur tourné vers la droite.
const XBOW_MUZZLE := Vector2(19.0, -15.0)
const XBOW_BREECH := Vector2(8.0, -18.0)
## Tir vers le sud (c_shoot_d, canon à la hanche) et vers le nord (c_shoot_u, canon levé) : bouche et culasse.
const XBOW_MUZZLE_D := Vector2(7.0, -4.0)
const XBOW_BREECH_D := Vector2(7.0, -14.0)
const XBOW_MUZZLE_U := Vector2(6.0, -28.0)
const XBOW_BREECH_U := Vector2(6.0, -17.0)


## Bouche (ou culasse) de l'Arbalestrie par rapport aux pieds, pour un tir dans la direction `d` (x, z du monde) :
## même règle que la pose de UnitView (surtout vers le sud ou le nord : de face ou de dos, sinon de profil).
static func xbow_point(face: float, d: Vector2, breech := false) -> Vector2:
	var m := XBOW_BREECH if breech else XBOW_MUZZLE
	if absf(d.y) > absf(d.x) * 1.2:
		if d.y > 0.0:
			m = XBOW_BREECH_D if breech else XBOW_MUZZLE_D
		else:
			m = XBOW_BREECH_U if breech else XBOW_MUZZLE_U
	return Vector2(m.x * face, m.y)
const XBOW_SMOKE: Array[Color] = [Color("#c9cdd6"), Color("#9aa1b0"), Color("#6d7482")]
## Vitesse de la balle à l'écran, en pixels natifs par seconde (Combat.BALL_SPEED × 8).
const XBOW_BALL_PX := 320.0


## Ellipse en pointillé (un pixel sur `step`).
func _ell(x: float, y: float, rx: float, ry: float, c: Color, step := 1) -> void:
	var n := maxi(8, roundi((rx + ry) * 3.2))
	for k in range(0, n, step):
		var a := TAU * k / n
		npx(x + cos(a) * rx, y + sin(a) * ry, c)


## Particule lancée de `from` à la vitesse `v`, qui rebondit au sol (`gy`).
func _bounce(from: Vector2, v: Vector2, g: float, t: float, gy: float) -> Vector2:
	var p := from + v * t + Vector2(0, g * t * t * 0.5)
	if p.y > gy:
		p.y = gy - absf(sin(t * 16.0)) * 2.0 * maxf(0.0, 1.0 - t * 1.6)
	return p


## Arc de choc de 2·`half` + 1 pixels, bombé vers `d`.
func _shock_arc(at: Vector2, d: Vector2, half: int, c: Color) -> void:
	var side := Vector2(-d.y, d.x)
	for j in range(-half, half + 1):
		var k := float(j) / half
		var q := at + side * j + d * (1.6 * (1.0 - k * k))
		npx(q.x, q.y, c)


## Tir de l'Arbalestrie (planches/arbalestrie-tir-planche.html, second bilan du 2026-11-20). Pour toute munition :
## Culasse (douille éjectée, vapeur) et Souffle (anneau de poussière, arc de choc, poussière aux bottes). Puis la
## signature de la munition : Arc de rupture (spirituelles), Gueule de feu (Indra), Feu follet (Medeina), Prisme
## (Sigil), Rond d'orbite (Aether).
func _xbow_fire(e: Dictionary) -> void:
	var t := float(e["age"])
	if t < 0.0:
		return
	var face := float(e["face"]) if float(e["face"]) != 0.0 else 1.0
	var feet := nat_p(e["x"], e["z"])
	var d := Vector2(e["dx"], e["dz"]).normalized()
	var M := feet + xbow_point(face, d)
	var B := feet + xbow_point(face, d, true)
	var side := Vector2(-d.y, d.x)
	var ammo := String(e["ammo"])
	var C: Array = AMMO_PAL.get(ammo, CY)
	var sd := int(e["seed"])
	var gy := feet.y + 1.0
	# --- Souffle
	if t < 0.28:
		var q := t / 0.28
		var k := 1.0 - (1.0 - q) * (1.0 - q)
		_ell(M.x + 3.0 * face, gy, 3.0 + k * 13.0, 1.0 + k * 3.5, Color(Color("#8d8f98"), 0.55 * (1.0 - q)), 2)
		_ell(M.x + 3.0 * face, gy, 2.0 + k * 8.0, 0.6 + k * 2.2, Color(XBOW_SMOKE[2], 0.35 * (1.0 - q)))
	if t < 0.3:
		var q := t / 0.3
		for k in 3:
			npx(feet.x - face * (7.0 + q * (5.0 + k * 2.0)), feet.y - k - q * 2.0, Color(XBOW_SMOKE[k], 0.6 * (1.0 - q)))
	if t >= 0.02 and t < 0.1:
		var q := (t - 0.02) / 0.08
		_shock_arc(M + d * (3.0 + q * 6.0), d, 4, Color(Color("#e9fbff"), 0.7 * (1.0 - q)))
	# --- Culasse
	var R := Rng.new(sd)
	var shell_v := Vector2(-face * (22.0 + R.next() * 14.0), -58.0 - R.next() * 12.0)
	if t < 0.75:
		var q := _bounce(B, shell_v, 300.0, t, gy)
		var a := 1.0 if t < 0.5 else 1.0 - (t - 0.5) / 0.25
		npx(q.x, q.y, Color(C[4] if t < 0.12 else (C[2] if t < 0.3 else XBOW_SMOKE[2]), a))
		npx(q.x + 1.0, q.y, Color(C[3] if t < 0.12 else Color("#3e434d"), a))
	if t < 0.4:
		var q := t / 0.4
		for k in 3:
			npx(B.x + face * (1.0 - k) + sin(t * 14.0 + k) * 1.2, B.y - 2.0 - q * (6.0 + k * 2.0), Color(XBOW_SMOKE[k], 0.6 * (1.0 - q)))
	# --- Signature de la munition
	match ammo:
		"spirit":
			# Arc de rupture : filament d'éclair entre la bouche et la balle, retracé à chaque image, puis deux étincelles.
			if t < 0.09:
				var Z := Rng.new(sd + int(t * 60.0) * 13)
				var o := 0.0
				for i in range(1, int(t * XBOW_BALL_PX) - 1):
					if Z.next() < 0.45:
						o = clampf(o + (-1.0 if Z.next() < 0.5 else 1.0), -2.0, 2.0)
					var q := M + d * i + side * o
					npx(q.x, q.y, Color(CY[5] if i % 2 else CY[3], 0.95 - t * 4.0))
			elif t < 0.3:
				for k in 2:
					var q := _bounce(M, Vector2(d.x * (10.0 + R.next() * 20.0), -20.0 - R.next() * 20.0), 260.0, t - 0.09, gy)
					npx(q.x, q.y, Color(CY[3 + k], 1.0 - (t - 0.09) / 0.21))
		"indra":
			# Gueule de feu : flamme de 12 px blanche au cœur, qui se gonfle puis se résorbe, et quatre braises.
			if t < 0.14:
				var p := t / 0.14
				var reach := 12.0 * minf(1.0, p / 0.25)
				var i := 0.0
				while i <= reach:
					var hw := sin((i + 1.0) / (reach + 2.0) * PI) * 3.4 * (1.0 - p * 0.5)
					var j := -hw
					while j <= hw:
						var heat := 1.0 - i / 14.0 - p * 0.55 - absf(j) / (hw + 1.0) * 0.45
						if heat > 0.0:
							var q := M + d * (1.0 + i) + side * j
							npx(q.x, q.y, C[5] if heat > 0.6 else (C[4] if heat > 0.42 else (C[3] if heat > 0.22 else C[2])))
						j += 0.75
					i += 0.75
			for k in 4:
				var v := Vector2(d.x * (18.0 + R.next() * 45.0), -55.0 + R.next() * 40.0 + d.y * 20.0)
				var life := 0.45 + R.next() * 0.25
				if t < life:
					var q := _bounce(M + d * 3.0, v, 230.0, t, gy)
					npx(q.x, q.y, Color(C[4] if t < life * 0.5 else C[3], 1.0 - t / life))
		"medeina":
			# Feu follet : une petite flamme verte se détache de la bouche, flotte en vacillant, monte et s'éteint.
			if t < 0.55:
				var p := t / 0.55
				var a := 1.0 if p < 0.6 else 1.0 - (p - 0.6) / 0.4
				var q := M + d * (3.0 + 10.0 * (1.0 - exp(-5.0 * t))) + Vector2(sin(t * 16.0) * 1.2, -p * p * 14.0)
				for o: Vector2 in RING8:
					npx(q.x + o.x, q.y + o.y, Color(C[2], 0.55 * a))
				npx(q.x, q.y, Color(C[5], a))
				npx(q.x, q.y - 1.0, Color(C[4], a))
				npx(q.x + (1.0 if int(t * 20.0) % 2 else -1.0), q.y - 2.0, Color(C[3], a))
				npx(q.x, q.y + 1.0, Color(C[3], a))
		"sigil":
			# Prisme : un trait blanc traverse le canon, frappe un losange et en ressort en deux rayons.
			var c0 := M + d * 6.0
			if t < 0.03:
				for i in range(1, 12):
					npx(M.x - face * i, M.y, Color(C[5], 0.8))
			if t < 0.1:
				var a := 1.0 if t < 0.05 else 1.0 - (t - 0.05) / 0.05
				for k in 5:
					for sg: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
						var q := c0 + d * (sg.x * k) + side * (sg.y * (4 - k))
						npx(q.x, q.y, Color(C[5] if t < 0.05 else C[4], a))
			if t > 0.03 and t < 0.22:
				var p := (t - 0.03) / 0.19
				for sg: float in [-1.0, 1.0]:
					for i in int(minf(24.0, p * 60.0)):
						var q := c0 + d * (4.0 + i) + side * (sg * (i * 0.25 + 1.0))
						npx(q.x, q.y, Color(C[5] if i % 2 else C[4], (1.0 - p) * (1.0 - i / 30.0)))
		"aether":
			# Rond d'orbite : anneau soufflé par la bouche, qui avance en s'élargissant, une étoile sur son bord.
			if t < 0.34:
				var p := t / 0.34
				var k := 1.0 - (1.0 - p) * (1.0 - p)
				var c0 := M + d * (2.0 + k * 13.0)
				var rx := 1.0 + k * 2.2
				var ry := 3.0 + k * 7.0
				var n := maxi(8, roundi((rx + ry) * 3.2))
				for i in n:
					var a := TAU * i / n
					var q := c0 + d * (cos(a) * rx) + side * (sin(a) * ry)
					npx(q.x, q.y, Color(C[3], 0.9 * (1.0 - p)))
					var q2 := c0 - d + d * (cos(a) * rx * 0.6) + side * (sin(a) * ry * 0.7)
					npx(q2.x, q2.y, Color(C[2], 0.45 * (1.0 - p)))
				var star := c0 + d * (cos(t * 34.0) * rx) + side * (sin(t * 34.0) * ry)
				npx(star.x, star.y, Color(C[5], 1.0 - p))


## Taille des balles de l'Arbalestrie en vol (×1,5 le 2026-11-20).
const BALL_SCALE := 1.5


## Balle de l'Arbalestrie en vol, selon sa munition (balles spirituelles : bille noire et micro-éclairs cyan).
func _cball(e: Dictionary) -> void:
	var p := clampf(float(e["age"]) / float(e["duration"]), 0.0, 1.0)
	var n := Proj.nat(lerpf(e["x"], e["tx"], p), 1.3, lerpf(e["z"], e["tz"], p)) + world.native_offset
	# Arbalestrie : départ à la bouche du canon, puis la balle rejoint sa ligne de tir.
	if e.has("muz"):
		var wd := Vector2(float(e["tx"]) - float(e["x"]), float(e["tz"]) - float(e["z"]))
		n += (xbow_point(float(e["muz"]), wd) + Vector2(0.0, 1.3 * Proj.KH)) * (1.0 - p)
	var x := jr(n.x)
	var y := jr(n.y)
	var age := float(e["age"])
	var sd := int(e["seed"])
	# Sens du vol à l'écran (traînées vers l'arrière).
	var d := Proj.nat(e["tx"], 0.0, e["tz"]) - Proj.nat(e["x"], 0.0, e["z"])
	d = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	# Balle agrandie de BALL_SCALE autour de son centre (pixels du dessin compris, traînée et halo du duel aussi).
	var c := Vector2(x + 0.5, y + 0.5) * px
	ci.draw_set_transform(c * (1.0 - BALL_SCALE), 0.0, Vector2(BALL_SCALE, BALL_SCALE))
	# Duel contre la Martyre : traînée cyan et halo clair, pour lire ses propres tirs parmi les éclats d'or.
	if Martyre.active():
		_duel_trail(x, y, d, age)
	match String(e.get("ammo", "spirit")):
		"indra": _ball_indra(x, y, d, age, sd)
		"medeina": _ball_medeina(x, y, d, age)
		"sigil": _ball_sigil(x, y, d, age)
		"aether": _ball_aether(x, y, d, age)
		_: _ball_spirit(x, y, age, sd)
	ci.draw_set_transform(Vector2.ZERO)


## Traînée d'une balle de l'Ingénieur pendant le duel : 10 pixels cyan qui s'effacent vers l'arrière (raccourcie
## au départ), doublée d'un liseré, et halo blanc-cyan autour de la balle.
func _duel_trail(x: float, y: float, d: Vector2, age: float) -> void:
	var side := Vector2(-d.y, d.x)
	var n := mini(10, 2 + int(age * 60.0))
	for i in range(1, n + 1):
		var a := 1.0 - float(i) / (n + 1)
		var t := Vector2(x, y) - d * (1.5 + i)
		npx(t.x, t.y, Color(CY[4] if i < 3 else CY[3], a))
		if i < 6:
			npx(t.x + side.x, t.y + side.y, Color(CY[2], a * 0.7))
			npx(t.x - side.x, t.y - side.y, Color(CY[2], a * 0.7))
	for q: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		npx(x + q.x, y + q.y, Color(CY[4], 0.85))
	for q: Vector2 in [Vector2(-1, -2), Vector2(1, -2), Vector2(-2, -1), Vector2(2, -1), Vector2(-2, 1), Vector2(2, 1), Vector2(-1, 2), Vector2(1, 2)]:
		npx(x + q.x, y + q.y, Color(CY[3], 0.5))


## Liseré clair (RIM12) d'une balle, sous ses autres pixels.
func _ball_rim(x: float, y: float, c: Color) -> void:
	for q: Vector2 in RIM12:
		npx(x + q.x, y + q.y, Color(c, 0.9))


func _ball_spirit(x: float, y: float, age: float, sd: int) -> void:
	# Balle réduite (2026-11-19) : 3 × 3 pixels, cœur sombre cerné d'encre, liseré cyan clair.
	_ball_rim(x, y, CY[4])
	for q: Vector2 in RING8:
		npx(x + q.x, y + q.y, INK)
	npx(x, y, Color("#5b6068"))
	var R := Rng.new(sd + int(age * 30.0) * 7)
	for k in 3:
		if R.next() < 0.25:
			continue
		var a := R.next() * TAU
		var sx := x + roundf(cos(a) * 2.0)
		var sy := y + roundf(sin(a) * 2.0)
		for s in 2:
			npx(sx, sy, Color("#e9fbff") if s == 0 else CY[3])
			var b := a + (0.9 if s & 1 else -0.9)
			sx += roundf(cos(b))
			sy += roundf(sin(b))


## Indra : braise grossie (cœur 3 × 3 dans un cerne 5 × 5 aux coins rognés), traînée de flamme, escarbilles.
func _ball_indra(x: float, y: float, d: Vector2, age: float, sd: int) -> void:
	var C: Array = AMMO_PAL["indra"]
	var R := Rng.new(sd + int(age * 30.0) * 7)
	var side := Vector2(-d.y, d.x)
	for i in range(1, 7):
		var a := 1.0 - i / 7.0
		var t := Vector2(x, y) - d * (2 + i)
		npx(t.x, t.y, Color(C[3] if i < 3 else C[2], a))
		var t2 := t + side * (1.0 if i % 2 else -1.0)
		npx(t2.x, t2.y, Color(C[2], a * 0.6))
	for b in range(-2, 3):
		for a in range(-2, 3):
			if absi(a) == 2 and absi(b) == 2:
				continue
			npx(x + a, y + b, C[3] if absi(a) < 2 and absi(b) < 2 else INK)
	npx(x, y, C[5])
	npx(x + 1, y, C[4])
	npx(x - 1, y - 1, C[4])
	npx(x, y - 1, Color(C[5], 0.8))
	npx(x + 1, y + 1, C[2])
	npx(x - 1, y + 1, C[2])
	if R.next() < 0.4:
		var sp := Vector2(x, y) - d * (4 + floorf(R.next() * 3.0)) + Vector2(0, -2 - floorf(R.next() * 2.0))
		npx(sp.x, sp.y, C[4])


## Medeina : graine verte, deux feuilles qui tournent autour, poussière verte derrière.
func _ball_medeina(x: float, y: float, d: Vector2, age: float) -> void:
	var C: Array = AMMO_PAL["medeina"]
	_ball_rim(x, y, C[4])
	for q: Vector2 in RING8:
		npx(x + q.x, y + q.y, INK)
	npx(x, y, C[3])
	npx(x - 1, y - 1, Color(C[4], 0.8))
	for k in 2:
		var a := age * 18.0 + k * PI
		npx(x + roundf(cos(a) * 3.0), y + roundf(sin(a) * 2.0), C[4] if k else C[3])
	for i in range(1, 4):
		var t := Vector2(x, y) - d * (2 + i * 2) + Vector2(0, roundf(i * 0.6 + sin(age * 20.0 + i)))
		npx(t.x, t.y, Color(C[2], 0.6 - i * 0.15))


## Sigil : bille de marbre clair (encre en bas à droite), éclat qui parcourt la veine, tirets de glyphe.
func _ball_sigil(x: float, y: float, d: Vector2, age: float) -> void:
	var C: Array = AMMO_PAL["sigil"]
	_ball_rim(x, y, C[5])
	for q: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(-1, 0)]:
		npx(x + q.x, y + q.y, C[3])
	for q: Vector2 in [Vector2(1, -1), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
		npx(x + q.x, y + q.y, INK)
	npx(x, y, C[4])
	var ph := int(age * 24.0) % 3
	npx(x - 1 + ph, y - 1 + mini(ph, 1), C[5])
	for k: Array in [[4, 0.8], [5, 0.5], [8, 0.5]]:
		var t := Vector2(x, y) - d * float(k[0])
		npx(t.x, t.y, Color(C[4] if k[0] < 8 else C[3], k[1]))


## Aether : astre bleu-violet, anneau d'orbite incliné et étoile qui le parcourt.
func _ball_aether(x: float, y: float, d: Vector2, age: float) -> void:
	var C: Array = AMMO_PAL["aether"]
	for a in 12:
		var t := a / 12.0 * TAU
		var o := Vector2(roundf(cos(t) * 3.5), roundf(sin(t) * 1.5))
		if absf(o.x) > 1 or absf(o.y) > 1:
			npx(x + o.x, y + o.y, Color(C[2], 0.55))
	_ball_rim(x, y, C[4])
	for q: Vector2 in RING8:
		npx(x + q.x, y + q.y, INK)
	npx(x, y, C[4])
	npx(x + roundf(cos(age * 14.0) * 3.5), y + roundf(sin(age * 14.0) * 1.5), C[5])
	var tr := Vector2(x, y) - d * 4.0
	npx(tr.x, tr.y, Color(C[2], 0.4))


## Impact de la balle (ennemi ou roche), selon la munition.
func _cball_hit(e: Dictionary) -> void:
	var age: float = e["age"]
	if age < 0.0:
		return
	var p := age / float(e["duration"])
	var n := Proj.nat(e["x"], 1.3, e["z"]) + world.native_offset
	var x := jr(n.x)
	var y := jr(n.y)
	match String(e.get("ammo", "spirit")):
		"indra": _hit_indra(x, y, age, p)
		"medeina": _hit_medeina(x, y, p)
		"sigil": _hit_sigil(x, y, p)
		"aether": _hit_small(x, y, p, AMMO_PAL["aether"])
		"aether_spark": _hit_small(x, y, p, AMMO_PAL["aether"])
		_: _hit_spirit(x, y, p)


## Balles spirituelles : éclat blanc, étincelles cyan, puis poussière.
func _hit_spirit(x: float, y: float, p: float) -> void:
	if p < 0.4:
		for q: Vector2 in CROSS5:
			npx(x + q.x, y + q.y, CY[5])
		for q: Vector2 in [Vector2(-3, -2), Vector2(2, -3), Vector2(3, 2), Vector2(-2, 3), Vector2(0, -4)]:
			npx(x + q.x, y + q.y, CY[3])
	else:
		var c := Color(0.78, 0.78, 0.74, 0.6 * (1.0 - p))
		for q: Vector2 in [Vector2(-2, -2), Vector2(-1, -2), Vector2(1, -1), Vector2(2, -1), Vector2(0, -3)]:
			npx(x + q.x, y + q.y - roundf(p * 3.0), c)


## Indra : étoile de 7 px, anneau de chaleur, trois braises qui retombent en rebondissant.
func _hit_indra(x: float, y: float, age: float, p: float) -> void:
	var C: Array = AMMO_PAL["indra"]
	if p < 0.3:
		for i in range(-3, 4):
			var c: Color = C[5] if absi(i) < 2 else C[3]
			npx(x + i, y, c)
			npx(x, y + i, c)
		for q: Vector2 in [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]:
			npx(x + q.x, y + q.y, C[4])
	var r := roundf(3.0 + p * 5.0)
	for k in 16:
		var a := k / 16.0 * TAU
		npx(x + roundf(cos(a) * r), y + roundf(sin(a) * r * 0.6), Color(C[2], 0.7 * (1.0 - p)))
	for v: Vector3 in [Vector3(-9, -22, 1), Vector3(7, -26, 2), Vector3(12, -16, 3)]:
		var yy := y + v.y * age + 60.0 * age * age
		if yy > y + 8.0:
			yy = y + 8.0 - absf(sin(age * 12.0)) * 2.0
		npx(x + v.x * age * 1.6, yy, Color(C[4] if int(v.z) % 2 else C[3], 1.0 - p))


func _hit_medeina(x: float, y: float, p: float) -> void:
	var C: Array = AMMO_PAL["medeina"]
	if p < 0.5:
		for q: Vector2 in CROSS5:
			npx(x + q.x, y + q.y, C[5])
		for q: Vector2 in [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]:
			npx(x + q.x, y + q.y, C[3])
	else:
		for q: Vector2 in [Vector2(-1, -2), Vector2(1, -3), Vector2(0, -4)]:
			npx(x + q.x, y + q.y - roundf(p * 3.0), Color(C[3], 1.0 - p))


## Sigil : éclat gris-blanc et glyphe en croix qui s'écarte en s'effaçant.
func _hit_sigil(x: float, y: float, p: float) -> void:
	var C: Array = AMMO_PAL["sigil"]
	if p < 0.4:
		for q: Vector2 in CROSS5:
			npx(x + q.x, y + q.y, C[5])
	var dd := roundf(2.0 + p * 3.0)
	for q: Vector2 in [Vector2(-dd, 0), Vector2(dd, 0), Vector2(0, -dd), Vector2(0, dd)]:
		npx(x + q.x, y + q.y, Color(C[4], 1.0 - p))


## Petit éclat d'Aether : cible au centre de l'onde, ou voisin que l'onde atteint.
func _hit_small(x: float, y: float, p: float, C: Array) -> void:
	if p < 0.5:
		for q: Vector2 in CROSS5:
			npx(x + q.x, y + q.y, C[5] if q == Vector2.ZERO else C[4])
	for q: Vector2 in [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]:
		npx(x + q.x, y + q.y - roundf(p * 2.0), Color(C[3], 1.0 - p))


## Onde d'Aether : cercle au sol d'un bloc de rayon qui s'ouvre en 0,3 s, étoiles sur son bord, puis s'efface.
func _aether_wave(e: Dictionary) -> void:
	var age: float = e["age"]
	if age < 0.0:
		return
	var C: Array = AMMO_PAL["aether"]
	var c := Proj.nat(e["x"], 0.0, e["z"]) + world.native_offset
	var full := float(e["r"]) * Proj.K
	var p := clampf(age / 0.3, 0.0, 1.0)
	var f := 1.0 if age < 0.3 else maxf(0.0, 1.0 - (age - 0.3) / 0.25)
	var r := 2.0 + p * (full - 2.0)
	var n := maxi(12, roundi(r * 5.0))
	for k in n:
		var a := k / float(n) * TAU
		npx(c.x + cos(a) * r, c.y + sin(a) * r, Color(C[4] if k % 3 == 0 else C[3], 0.85 * f))
	if p > 0.2:
		for k in range(0, n, 2):
			var a := k / float(n) * TAU
			npx(c.x + cos(a) * r * 0.8, c.y + sin(a) * r * 0.8, Color(C[2], 0.4 * f))
	for k in 8:
		var a := k / 8.0 * TAU + 0.3
		npx(c.x + cos(a) * r, c.y + sin(a) * r - roundf(p * 4.0), Color(C[5], f))


## Medeina : lucioles vertes qui remontent en arc de l'impact jusqu'à la poitrine de l'Ingénieur, puis un éclat.
func _heal_motes(e: Dictionary) -> void:
	var age: float = e["age"]
	if age < 0.0:
		return
	var u: Unit = e["unit"]
	var C: Array = AMMO_PAL["medeina"]
	var from := Proj.nat(e["x"], 1.3, e["z"]) + world.native_offset
	var to := Proj.nat(u.x, 1.8, u.z) + world.native_offset
	var q := age / 0.5
	for k in 6:
		var qq := q - k * 0.05
		if qq < 0.0 or qq > 1.0:
			continue
		var s := qq * qq * (3.0 - 2.0 * qq)
		var p := from.lerp(to, s) - Vector2(0, sin(s * PI) * (14.0 + k * 2.0))
		for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			npx(p.x + o.x, p.y + o.y, Color(C[2], 0.75))
		npx(p.x, p.y, C[5] if k % 2 else C[4])
	if q >= 0.95:
		var a := 1.0 - clampf((q - 0.95) / 0.25, 0.0, 1.0)
		for o: Vector2 in [Vector2(-4, -2), Vector2(4, -4), Vector2(0, -8), Vector2(-3, 4), Vector2(5, 2)]:
			npx(to.x + o.x, to.y + o.y, Color(C[5], a))


func _arrow(e: Dictionary) -> void:
	var p := minf(1.0, e["age"] / e["duration"])
	var q := _arrow_path(e, p)
	var q0 := _arrow_path(e, maxf(0.0, p - 0.06))
	var l := q.distance_to(q0)
	if l == 0.0:
		l = 1.0
	var ux := (q.x - q0.x) / l
	var uy := (q.y - q0.y) / l
	var R := Rng.new(e["seed"])
	for i in range(1, 10):
		var qq := p - i * 0.03
		if qq < 0.0:
			break
		var s := _arrow_path(e, qq)
		for k in 3:
			if R.next() < 1.0 - i / 10.0:
				var ox := (R.next() - 0.5) * 3.0
				var oy := (R.next() - 0.5) * 3.0
				npx(s.x + ox, s.y + oy, ARROW_SPARK[maxi(0, 3 - (i >> 1) - (k >> 1))])
	_arrow_at(q, ux, uy)


## Flèche dessinée pointe en q, dirigée selon (ux, uy).
func _arrow_at(q: Vector2, ux: float, uy: float) -> void:
	for i in range(-1, 12):
		npx(q.x - ux * i + uy, q.y - uy * i - ux, INK)
		npx(q.x - ux * i - uy * 2.0, q.y - uy * i + ux * 2.0, INK)
	for i in 11:
		npx(q.x - ux * i, q.y - uy * i, ARROW_HEAD if i < 3 else ARROW_SHAFT)
		npx(q.x - ux * i - uy, q.y - uy * i + ux, Color("#a2a6ab") if i < 3 else Color("#3e2a18"))
	npx(q.x + ux, q.y + uy, ARROW_TIP)
	npx(q.x + ux * 2.0, q.y + uy * 2.0, Color.WHITE)
	for sg in [-1.0, 1.0]:
		npx(q.x - ux - uy * sg * 1.5, q.y - uy + ux * sg * 1.5, ARROW_HEAD)
	for sg in [-1.0, 1.0]:
		for i in range(8, 12):
			npx(q.x - ux * i - uy * sg * 2.0, q.y - uy * i + ux * sg * 2.0, ARROW_FL)


func _arrow_hit(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p: float = e["age"] / e["duration"]
	var at := nat_p(e["x"], e["z"])
	var cy := at.y - 14.0
	var r := 1.0 + p * 6.0
	var R := Rng.new(e["seed"])
	for k in 10:
		var a := k / 10.0 * 6.283 + R.next() * 0.4
		var d := r * (0.6 + R.next() * 0.5)
		if R.next() > p * 0.8:
			npx(at.x + cos(a) * d, cy + sin(a) * d * 0.7, ARROW_SPARK[3 if p < 0.4 else 2 - (k & 1)])
	if p < 0.35:
		npx(at.x, cy, Color.WHITE)
		npx(at.x + 1.0, cy, ARROW_SPARK[3])
		npx(at.x - 1.0, cy, ARROW_SPARK[3])
		npx(at.x, cy - 1.0, ARROW_SPARK[3])
		npx(at.x, cy + 1.0, ARROW_SPARK[3])


# ---------------------------------------------------------------- Pilum et sort des ennemis (refonte 16 bits)

const PILUM_WOOD: Array[Color] = [Color("#4a2c14"), Color("#a8743a")]
const PILUM_IRON: Array[Color] = [Color("#3a4250"), Color("#d6dce8")]
## Or de Laetan et carmin souillé (charte : or réservé aux forces de Laetan).
const ORB: Array[Color] = [Color("#58101e"), Color("#c2384a"), Color("#e2b83a"), Color("#fff0a0")]


## Pilum : hampe de bois de 9 px et pointe de fer de 3 px, en cloche plus haute que la flèche, sans traînée.
func _pilum(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p := minf(1.0, e["age"] / e["duration"])
	var p0 := maxf(0.0, p - 0.05)
	# Cloche supplémentaire de 6 px au sommet : le pilum monte plus haut qu'une flèche.
	var q := _arrow_path(e, p) - Vector2(0, 24.0 * p * (1.0 - p))
	var q0 := _arrow_path(e, p0) - Vector2(0, 24.0 * p0 * (1.0 - p0))
	var d: Vector2 = (q - q0).normalized() if q.distance_to(q0) > 0.01 else Vector2(float(e["face"]), 0.0)
	_pilum_at(q, d)


## Pilum dessiné pointe en q, dirigé selon d.
func _pilum_at(q: Vector2, d: Vector2) -> void:
	var n := Vector2(-d.y, d.x)
	for i in range(-1, 13):
		npx(q.x - d.x * i + n.x, q.y - d.y * i + n.y, INK)
		npx(q.x - d.x * i - n.x, q.y - d.y * i - n.y, INK)
	for i in 12:
		var c: Color = (PILUM_IRON[1] if i == 0 else PILUM_IRON[0]) if i < 3 else (PILUM_WOOD[1] if i % 3 != 0 else PILUM_WOOD[0])
		npx(q.x - d.x * i, q.y - d.y * i, c)
	npx(q.x + d.x, q.y + d.y, Color.WHITE)


## Orbe : noyau or pâle, halo carmin, quatre points de traînée qui s'éteignent.
func _orb(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p := minf(1.0, e["age"] / e["duration"])
	var R := Rng.new(e["seed"])
	for i in range(4, 0, -1):
		var s := _orb_path(e, maxf(0.0, p - i * 0.06))
		npx(s.x + (R.next() - 0.5) * 2.0, s.y + (R.next() - 0.5) * 2.0, ORB[1 if i > 2 else 2])
	_orb_at(_orb_path(e, p))


func _orb_at(q: Vector2) -> void:
	# Doublé le 2026-11-20 (demande) : 9 px de large au lieu de 5, liseré noir d'un pixel pour ressortir du décor.
	_disc(q.x, q.y, 5.5, Color.BLACK)
	_disc(q.x, q.y, 4.5, ORB[0])
	_disc(q.x, q.y, 3.5, ORB[1])
	_disc(q.x, q.y, 2.2, ORB[2])
	_disc(q.x - 0.5, q.y - 0.5, 1.0, ORB[3])


## Trajet presque droit (légère cloche) du haut du bâton vers la poitrine de la cible.
func _orb_path(e: Dictionary, p: float) -> Vector2:
	var s := nat_p(e["x"], e["z"])
	var t := nat_p(e["tx"], e["tz"])
	var a := Vector2(s.x + float(e["face"]) * float(e["ox"]), s.y - float(e["oy"]))
	var b := Vector2(t.x, t.y - 14.0)
	return a.lerp(b, p) - Vector2(0, 3.0 * 4.0 * p * (1.0 - p))


## Éclatement : anneau de 8 éclats or et carmin qui s'élargit, éclair blanc au début.
func _orb_hit(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p: float = e["age"] / e["duration"]
	var at := nat_p(e["x"], e["z"])
	var cy := at.y - 14.0
	var r := 1.0 + p * 7.0
	for k in 8:
		var a := k / 8.0 * TAU + p
		if p < 0.85 or k % 2 == 0:
			npx(at.x + cos(a) * r, cy + sin(a) * r * 0.7, ORB[2 if p < 0.5 else 1])
			npx(at.x + cos(a) * (r - 1.5), cy + sin(a) * (r - 1.5) * 0.7, ORB[1 if p < 0.5 else 0])
	if p < 0.3:
		npx(at.x, cy, Color.WHITE)
		for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			npx(at.x + o.x, cy + o.y, ORB[3])


# ---------------------------------------------------------------- Tirs esquivables (sim/enemy_shots.gd)

## Hauteur de vol des balles (pixels natifs) : la poitrine, comme les tirs à coup sûr.
const SHOT_LIFT := 14.0
const SHOT_SHADOW := Color(0.0, 0.0, 0.0, 0.4)
## Annonces des tirs (ligne de visée, cercle du pilum) : pointillé carmin (piste 5·B ; avant : jaune #f0cc66 plein).
const SHOT_WARN := Color("#e2382e")
## Halo pâle sous chaque balle (piste 1·C) : rayon en pixels natifs et opacité au centre.
const SHOT_HALO_R := 6.0
const SHOT_HALO := Color(1.0, 0.94, 0.86, 0.35)
## Crachat annoncé des chiens (EnemyShots.SPIT.warn) : longueur du trait au sol en pixels natifs.
const SPIT_LINE := 18.0
static var _halo_tex: GradientTexture2D
## Boule de feu des chiens de la Bête : braise, orange, jaune, cœur pâle.
## Boule de feu (chiens de la Bête, squelettes explosifs) : braise rouge à cœur blanc cerclée de sombre (planche
## « Visibilité des balles », piste 4·B, 2026-11-20). Rangs : traînée sombre, traînée, corps, nez, cœur, cœur pâle, anneau.
## Avant : #8a1c0c, #e8641c, #ffc23a, #fff3c0, sans anneau.
const FIREBALL: Array[Color] = [Color("#5a0a14"), Color("#a8182a"), Color("#d42a3a"), Color("#ff8a7a"), Color.WHITE, Color("#ffd8d0"), Color("#2a040c")]
## Goutte d'ichor du Fanatique (planche « Motifs statiques », 2·V) : bord, corps, intérieur, cœur.
const ICHOR_DROP: Array[Color] = [Color("#0e0614"), Color("#4a1e66"), Color("#9a62d0"), Color("#f4eaff")]
## Éclat d'os-chair du Strazhar (3·C) : liseré, chair, os sombre, os, pointe.
const BONE_SHARD: Array[Color] = [Color("#140808"), Color("#a02838"), Color("#b8a888"), Color("#e4d8bc"), Color.WHITE]
## Annonce de l'anneau d'ichor : rayon du cercle carmin (u) ; montée des gouttes et des éclats à leur départ (s).
const ICHOR_WARN_R := 1.6
const ICHOR_RISE := 0.15
const BONE_RISE := 0.12


## Calque des tirs ennemis (EnemyShotsView, au-dessus de l'obscurité et de la pluie : piste 1·C de la planche
## « Visibilité des balles », 2026-11-20). ci : nœud du calque, repère de l'écran.
func draw_enemy_layer(now: float) -> void:
	px = float(world.camera.px)
	_enemy_shots(now)


## Halo pâle sous une balle, centré sur q (pixels natifs à l'écran).
func _shot_halo(q: Vector2) -> void:
	if _halo_tex == null:
		var g := Gradient.new()
		g.set_color(0, SHOT_HALO)
		g.set_color(1, Color(SHOT_HALO, 0.0))
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 32
		_halo_tex.height = 32
	ci.draw_texture_rect(_halo_tex, Rect2((q - Vector2(SHOT_HALO_R, SHOT_HALO_R)) * px, Vector2.ONE * SHOT_HALO_R * 2.0 * px), false)


## Ligne pixel en pointillés (4 pixels, 2 vides), tramée selon al.
func _dash_line(a: Vector2, b: Vector2, c: Color, al: float) -> void:
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for k in n + 1:
		if k % 6 < 4:
			var p := a.lerp(b, float(k) / n)
			dpx(p.x, p.y, c, al)


## Annonces (ligne de visée de l'archer, point de chute du pilum, braise dans la gueule des chiens), balles en vol
## avec leur halo et leur ombre au sol, et zone touchée de l'Exilé incarné (point blanc) quand une balle approche.
func _enemy_shots(now: float) -> void:
	for en: Enemy in GameState.enemies:
		if en.kind == "beast" and en.spit_fire_at != INF and en.hp > 0.0:
			_spit_warn(en, now)
			continue
		if en.shot_aim == null or en.strike_at == INF or en.kind != "archer" or not world.fog.visible_at(en.pos()):
			continue
		var aim: Vector2 = en.shot_aim
		var dir := (aim - en.pos()).normalized()
		var a := nat_p(en.x, en.z)
		var b := nat_p(en.x + dir.x * EnemyShots.ARROW["range"], en.z + dir.y * EnemyShots.ARROW["range"])
		var left: float = clampf((en.strike_at - now) / maxf(en.windup, 0.01), 0.0, 1.0)
		_dash_line(a, b, SHOT_WARN, 0.35 + 0.45 * (1.0 - left))
	if GameState.enemy_shots.is_empty():
		return
	var u := GameState.incarnated
	var near := false
	for s: Dictionary in GameState.enemy_shots:
		var kind: String = s["kind"]
		if kind == "pilum":
			_shot_pilum(s, now)
			continue
		if not world.fog.visible_at(Vector2(s["x"], s["z"])):
			continue
		if kind == "ichor_warn":
			_ichor_warn(s, now)
			continue
		if kind == "spike":
			_spike(s, now)
			continue
		if u != null and absf(s["x"] - u.x) < 3.0 and absf(s["z"] - u.z) < 3.0:
			near = true
		var g := nat_p(s["x"], s["z"])
		# Gouttes et éclats partent du sol (corps, éclat fiché) et montent à hauteur de poitrine.
		var lift := SHOT_LIFT
		if kind == "ichor":
			lift = minf(SHOT_LIFT, 4.0 + (now - s["born"]) / ICHOR_RISE * (SHOT_LIFT - 4.0))
		elif kind == "bone":
			lift = minf(SHOT_LIFT, 2.0 + (now - s["born"]) / BONE_RISE * (SHOT_LIFT - 2.0))
		var q := g - Vector2(0.0, lift)
		var d := (nat_p(s["x"] + s["vx"], s["z"] + s["vz"]) - g).normalized()
		_shot_halo(q)
		for i in range(-1, 2):
			npx(g.x + i, g.y, SHOT_SHADOW)
		match kind:
			"arrow":
				for i in range(3, 9):
					npx(g.x - d.x * i, g.y - d.y * i, SHOT_SHADOW)
				_arrow_at(q, d.x, d.y)
			"orb":
				var R := Rng.new(s["seed"])
				for i in range(3, 0, -1):
					_disc(q.x - d.x * (3.0 + i * 3.0) + (R.next() - 0.5) * 2.0, q.y - d.y * (3.0 + i * 3.0) + sin(now * 14.0 + i) * 1.2, 1.5, ORB[1 if i > 1 else 2])
				_orb_at(q)
			"fire":
				# Braise : traînée, anneau sombre, corps rouge, cœur blanc qui vacille.
				var F := Rng.new(s["seed"])
				var S: float = s.get("scale", 1.0)
				for i in range(6, 2, -1):
					dpx(q.x - d.x * i * 3.3 * S + (F.next() - 0.5) * 4.5 * S, q.y - d.y * i * 3.3 * S + sin(now * 22.0 + i * 1.7) * 2.2,
						FIREBALL[0 if i > 4 else 1], 1.15 - i * 0.15)
				# Grossie deux fois le 2026-11-20 : 13 px de large (5 puis 9 avant), queue de flamme de 9 px.
				for i in range(6, 2, -1):
					_disc(q.x - d.x * i * 1.5 * S, q.y - d.y * i * 1.5 * S, (3.9 - (i - 3) * 0.9) * S, FIREBALL[1])
				_disc(q.x, q.y, 6.3 * S, FIREBALL[6])
				_disc(q.x, q.y, 4.8 * S, FIREBALL[2])
				_disc(q.x + d.x * 1.5, q.y + d.y * 1.5, 3.0 * S, FIREBALL[3])
				_disc(q.x + d.x * 1.5, q.y + d.y * 1.5, 1.5 * S, FIREBALL[4] if fmod(now * 16.0 + F.next(), 2.0) < 1.0 else FIREBALL[5])
				ci.draw_rect(Rect2((g.x - 5.0) * px, g.y * px, 11.0 * px, px), SHOT_SHADOW)
				ci.draw_rect(Rect2((g.x - 3.0) * px, (g.y + 1.0) * px, 7.0 * px, px), SHOT_SHADOW)
			"ichor":
				_ichor_at(q, d, 1.0)
			"bone":
				_bone_at(q, d)
			_:
				# Éclat du pilum : losange de fer, pointe blanche.
				for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
					npx(q.x + o.x, q.y + o.y, PILUM_IRON[0])
				npx(q.x - d.x * 2.0, q.y - d.y * 2.0, PILUM_IRON[0])
				npx(q.x, q.y, PILUM_IRON[1])
				npx(q.x + d.x, q.y + d.y, Color.WHITE)
	if near and u != null and u.alive() and not u.hidden and Martyre.duelist() == null:
		var c := nat_p(u.x, u.z) - Vector2(0.0, SHOT_LIFT)
		for y in range(-2, 3):
			for x in range(-2, 3):
				npx(c.x + x, c.y + y, Color.WHITE if absi(x) < 2 and absi(y) < 2 else Color("#10123a"))


## Crachat annoncé d'un chien (piste 6·B) : braise qui grossit dans la gueule pendant SPIT.warn s et trait pointillé
## au sol dans l'axe du tir.
func _spit_warn(en: Enemy, now: float) -> void:
	var m := EnemyShots.mouth(en)
	if not world.fog.visible_at(m):
		return
	var w: float = clampf(1.0 - (en.spit_fire_at - now) / float(EnemyShots.SPIT["warn"]), 0.0, 1.0)
	var g := nat_p(m.x, m.y)
	var q := g - Vector2(0.0, SHOT_LIFT)
	var tg: Variant = en.spit_target
	if tg != null and tg.alive():
		var d: Vector2 = (tg.pos() - m).normalized()
		var g0 := g + d * 4.0
		_dash_line(g0, g0 + d * SPIT_LINE * w, FIREBALL[2], 0.6)
	ci.draw_circle(q * px, (2.0 + 3.0 * w) * px, Color(FIREBALL[3], 0.25 + 0.45 * w))
	npx(q.x, q.y, FIREBALL[4] if int(now * 30.0) % 2 == 0 else FIREBALL[5])


## Goutte d'ichor : disque de 7 px un peu étiré dans le sens du vol d, cœur décalé vers la lumière (haut gauche).
func _ichor_at(q: Vector2, d: Vector2, a: float) -> void:
	for y in range(-3, 4):
		for x in range(-3, 4):
			var u := (x * d.x + y * d.y) / 1.2
			var v := -x * d.y + y * d.x
			var r := sqrt(u * u + v * v)
			if r > 3.1:
				continue
			var ri := Vector2(x + 0.5, y + 0.5).length()
			var c: Color = ICHOR_DROP[0] if r > 2.3 else ICHOR_DROP[3] if ri < 0.9 else ICHOR_DROP[2] if ri < 1.7 else ICHOR_DROP[1]
			if a >= 1.0:
				npx(q.x + x, q.y + y, c)
			else:
				dpx(q.x + x, q.y + y, c, a)


## Anneau d'ichor annoncé sur le corps du Fanatique : cercle pointillé carmin, la brèche laissée vide, et les gouttes
## qui gonflent à leur place de départ.
func _ichor_warn(s: Dictionary, now: float) -> void:
	var k: float = clampf((now - s["born"]) / maxf(s["until"] - s["born"], 0.01), 0.0, 1.0)
	var g := nat_p(s["x"], s["z"])
	var back: float = s["back"]
	var gap: float = EnemyShots.ICHOR["gap"] / 2.0 * TAU / float(EnemyShots.ICHOR["n"])
	var r := ICHOR_WARN_R * Proj.K
	for i in 48:
		if i % 3 == 2:
			continue
		var a := TAU * i / 48.0
		if absf(wrapf(a - back, -PI, PI)) < gap:
			continue
		dpx(g.x + cos(a) * r, g.y + sin(a) * r * 0.9, SHOT_WARN, 0.35 + 0.45 * k)
	for a: float in EnemyShots.ichor_angles(back):
		var d := Vector2(cos(a), sin(a))
		var q: Vector2 = g + d * float(EnemyShots.ICHOR["r0"]) * Proj.K - Vector2(0.0, 4.0)
		if k < 0.5:
			dpx(q.x, q.y, ICHOR_DROP[1], 0.4 + k)
			dpx(q.x, q.y - 1.0, ICHOR_DROP[3], k * 1.6)
		else:
			_ichor_at(q, d, 0.3 + 0.7 * k)


## Éclat d'os-chair en vol : 3 px de large, liseré sombre, pointe blanche, os puis chair vers l'arrière.
func _bone_at(q: Vector2, d: Vector2) -> void:
	var n := Vector2(-d.y, d.x)
	for i in range(-1, 7):
		npx(q.x - d.x * i + n.x, q.y - d.y * i + n.y, BONE_SHARD[0])
		npx(q.x - d.x * i - n.x, q.y - d.y * i - n.y, BONE_SHARD[0])
	npx(q.x + d.x * 2.0, q.y + d.y * 2.0, BONE_SHARD[0])
	for i in 6:
		npx(q.x - d.x * i, q.y - d.y * i, BONE_SHARD[4] if i < 1 else BONE_SHARD[3] if i < 3 else BONE_SHARD[2] if i < 4 else BONE_SHARD[1])
	npx(q.x + d.x, q.y + d.y, BONE_SHARD[4])


## Éclat fiché dans le sillage du Strazhar (inoffensif : c'est l'annonce) : pique penchée, chair à la base, trait
## carmin pointillé au sol dans chacun des deux axes de départ, qui s'allonge ; scintille juste avant de partir.
func _spike(s: Dictionary, now: float) -> void:
	var w: float = clampf((now - s["born"]) / maxf(s["until"] - s["born"], 0.01), 0.0, 1.0)
	var g := nat_p(s["x"], s["z"])
	for a: float in [s["a1"], s["a2"]]:
		var d := Vector2(cos(a), sin(a))
		_dash_line(g + d * 3.0, g + d * (5.0 + 10.0 * w), SHOT_WARN, 0.45 + 0.45 * w)
	var top := g + Vector2(float(s["lean"]), -7.0)
	for i in 8:
		var p := g.lerp(top, i / 7.0)
		npx(p.x - 1.0, p.y, BONE_SHARD[0])
		npx(p.x + 2.0, p.y, BONE_SHARD[0])
	npx(top.x, top.y - 1.0, BONE_SHARD[0])
	npx(top.x + 1.0, top.y - 1.0, BONE_SHARD[0])
	for i in 8:
		var p := g.lerp(top, i / 7.0)
		npx(p.x, p.y, BONE_SHARD[1] if i < 2 else BONE_SHARD[2] if i < 4 else BONE_SHARD[3])
		npx(p.x + 1.0, p.y, BONE_SHARD[1] if i < 2 else BONE_SHARD[2])
	var glint := w > 0.8 and int(now * 30.0) % 2 == 0
	npx(top.x, top.y, Color.WHITE if glint else BONE_SHARD[3])
	npx(top.x + 1.0, top.y, Color.WHITE if glint else BONE_SHARD[2])
	for i in range(-2, 4):
		npx(g.x + i, g.y + 1.0, SHOT_SHADOW)


## Pilum en cloche vers son point de chute, marqué au sol par un cercle qui se remplit.
func _shot_pilum(s: Dictionary, now: float) -> void:
	var to := Vector2(s["tx"], s["tz"])
	if not world.fog.visible_at(to):
		return
	var p: float = clampf((now - s["born"]) / maxf(s["until"] - s["born"], 0.01), 0.0, 1.0)
	var t := nat_p(to.x, to.y)
	var r: float = EnemyShots.PILUM["radius"] * Proj.K
	for k in 40:
		if k % 3 != 2:
			dpx(t.x + cos(TAU * k / 40.0) * r, t.y + sin(TAU * k / 40.0) * r, SHOT_WARN, 0.45 + 0.4 * p)
	ndisc(t.x, t.y, r * p * 0.75, SHOT_WARN, 0.12 + 0.2 * p)
	# Éclats à venir : quatre traits de fer pâle dans le cercle, dans l'axe où ils partiront (EnemyShots.tick).
	if p > PILUM_TICKS_FROM:
		var a0 := (to - Vector2(s["x"], s["z"])).angle()
		var al := 0.35 + 0.5 * (p - PILUM_TICKS_FROM) / (1.0 - PILUM_TICKS_FROM)
		for i in EnemyShots.PILUM["shards"]:
			var c := a0 + i * TAU / float(EnemyShots.PILUM["shards"])
			for j in range(3, 8):
				dpx(t.x + cos(c) * j, t.y + sin(c) * j, PILUM_IRON[1], al)
	var from := nat_p(s["x"], s["z"]) + Vector2(float(s["face"]) * ENEMY_PILUM_FROM.x, -ENEMY_PILUM_FROM.y)
	var p0 := maxf(0.0, p - 0.05)
	var q := from.lerp(t, p) - Vector2(0.0, 120.0 * p * (1.0 - p))
	var q0 := from.lerp(t, p0) - Vector2(0.0, 120.0 * p0 * (1.0 - p0))
	var d: Vector2 = (q - q0).normalized() if q.distance_to(q0) > 0.01 else Vector2(float(s["face"]), -1.0).normalized()
	_shot_halo(q)
	_pilum_at(q, d)


## Part du vol du pilum à partir de laquelle ses éclats sont annoncés.
const PILUM_TICKS_FROM := 0.35
## Départ du pilum (devant, hauteur) en pixels natifs : Combat.ENEMY_PILUM.
const ENEMY_PILUM_FROM := Vector2(3.0, 21.0)


# ---------------------------------------------------------------- Carreaux et explosions du Tireur

func _xbolt(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p := minf(1.0, e["age"] / e["duration"])
	var s := nat_p(e["x"], e["z"])
	var t := nat_p(e["tx"], e["tz"])
	var x0: float = s.x + e["face"] * 14.0
	var y0 := s.y - 22.0
	var x := x0 + (t.x - x0) * p
	var y := y0 + (t.y - 14.0 - y0) * p
	var l := Vector2(t.x - x0, t.y - 14.0 - y0).length()
	if l == 0.0:
		l = 1.0
	var ux := (t.x - x0) / l
	var uy := (t.y - 14.0 - y0) / l
	for i in 14:
		if BAYER[(int(jr(y)) + i) & 3][i & 3] < 1.0 - i / 14.0:
			npx(x - ux * (i + 6), y - uy * (i + 6), Color("#ffe08a") if i < 5 else Color("#d0781a"))
	for i in range(-1, 8):
		npx(x - ux * i + uy, y - uy * i - ux, INK)
		npx(x - ux * i - uy, y - uy * i + ux, INK)
	for i in 7:
		npx(x - ux * i, y - uy * i, Color("#d6d9dc") if i < 2 else Color("#4e4e56"))
	npx(x + ux, y + uy, Color("#ffb03c"))
	npx(x + ux * 2.0, y + uy * 2.0, Color("#fff0a0"))


func _xboom(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p: float = e["age"] / e["duration"]
	var at := nat_p(e["x"], e["z"])
	var x := at.x
	var cy := at.y - 10.0
	var r := 2.0 + sqrt(p) * 9.0
	var R := Rng.new(e["seed"])
	var j := -r
	while j <= r:
		var i := -r
		while i <= r:
			var d := Vector2(i, j * 1.2).length() / r
			if d <= 1.0 and not (p > 0.5 and BAYER[floori(cy + j) & 3][floori(x + i) & 3] < (p - 0.5) * 2.0):
				var h := (1.0 - p) * (1.0 - d * 0.7)
				var c := Color.WHITE if h > 0.7 else (Color("#ffe08a") if h > 0.5 else (Color("#ffb03c") if h > 0.32 else
					(Color("#d0781a") if h > 0.16 else (Color("#4a4440") if p > 0.55 else Color("#8a222c")))))
				npx(x + i, cy + j, c)
			i += 1.0
		j += 1.0
	for k in 12:
		var a := R.next() * 6.283
		var d := r * (1.1 + p) * (0.7 + R.next() * 0.5)
		if p < 0.75:
			npx(x + cos(a) * d, cy + sin(a) * d * 0.8, Color("#ffe08a") if p < 0.35 else Color("#d0781a"))


# ---------------------------------------------------------------- Rayons, impacts, zones

func _simple(e: Dictionary) -> void:
	var a: float = 1.0 - e["age"] / e["duration"]
	var cam := world.camera
	var col: Color = e["color"]
	match e["type"]:
		"bolt":
			# Foudre : ligne brisée qui tombe du ciel sur le point d'impact, épaisse puis fine.
			var pts := PackedVector2Array()
			var x: float = e["x"]
			for k in 9:
				pts.append(cam.project(x, k * 5.0, e["z"]))
				x += (Rng.hash3(int(e["seed"]), k, 0xb017) - 0.5) * 3.0
			ci.draw_polyline(pts, Color(col, a * 0.5), 6.0)
			ci.draw_polyline(pts, Color(1, 1, 1, a), 2.0)
		"laser":
			var from := cam.project(e["x"], 1.35, e["z"])
			if e.has("nozzle"):
				from = cam.project(e["x"], 0.0, e["z"]) + FLAME_NOZZLE * Vector2(float(e["nozzle"]), 1.0) * cam.px
			ci.draw_line(from, cam.project(e["tx"], 1.2, e["tz"]), Color(col, col.a * a), 3.0, true)
		"hit":
			# sphere3 : disque à dégradé radial (#f2f3eb, couleur à 15 %, #090c14), centre décalé vers le haut à gauche.
			var c := cam.project(e["x"], 1.4, e["z"])
			var sz := 0.4 * a * _z() * float(e.get("size", 1.0))
			if sz < 0.5:
				return
			var steps := 10
			for k in range(steps, 0, -1):
				var t := float(k) / steps
				var focus := c + Vector2(-0.3, -0.35) * sz * (1.0 - t)
				var cc := Color("#f2f3eb").lerp(col, clampf(t / 0.15, 0.0, 1.0)) if t < 0.15 else col.lerp(Color("#090c14"), (t - 0.15) / 0.85)
				ci.draw_circle(focus, sz * t, Color(cc, a))
		"zone":
			var c := cam.project(e["x"], 0.0, e["z"])
			var pts := PackedVector2Array()
			for k in 49:
				var ang := TAU * k / 48.0
				pts.append(c + Vector2(cos(ang) * e["r"] * _z() * 0.85, sin(ang) * e["r"] * _z() * 0.4))
			ci.draw_polyline(pts, Color(col, col.a * a), 3.0, true)


# ---------------------------------------------------------------- Murs de feu, carreaux des balistes

func _fire_walls(now: float) -> void:
	var cam := world.camera
	var z := _z()
	var s := maxf(2.0, z * 0.12)
	for w in GameState.fire_walls:
		var age: float = now - w["t0"]
		var head: float = minf(1.0, age / 0.4) * w["len"]
		var fade := minf(1.0, (w["until"] - now) / 0.5)
		var d := 0.0
		while d < head:
			var p := cam.project(w["x"] + w["dx"] * d, 0.0, w["z"] + w["dz"] * d)
			var fl := sin(now * 23.0 + d * 7.0) * 0.5 + 0.5
			var hgt := (1.6 if head - d < 1.0 else 0.9) * fade
			for k in 3:
				var y := p.y - (k * 0.35 + fl * 0.3) * hgt * z
				var ci_ := clampi(int(jr(5.0 - k * 1.5 - fl - (1.0 - fade) * 3.0)), 0, 5)
				ci.draw_rect(Rect2(p.x - s / 2.0 + sin(d * 13.0 + k) * s, y, s, s), FIRE[ci_])
			d += 0.22


func _turret_bolts() -> void:
	var cam := world.camera
	for b in GameState.turret_bolts:
		var t := minf(1.0, b["age"] / b["duration"])
		var tg: Enemy = b["target"]
		var target := Vector2(tg.x, tg.z) if tg.hp > 0.0 else Vector2(b["tx"], b["tz"])
		var p := cam.project(b["x"], 6.5, b["z"])
		var q := cam.project(target.x, 1.3, target.y)
		var dv := q - p
		var length := dv.length()
		if length == 0.0:
			length = 1.0
		var u := dv / length
		var at := p + dv * t
		ci.draw_line(at - u * 16.0, at, Color("#dec79b"), maxf(2.0, _z() * 0.09), true)
		ci.draw_colored_polygon(PackedVector2Array([at + u * 5.0, at - u * 3.0 + Vector2(u.y, -u.x) * 3.0, at - u * 3.0 - Vector2(u.y, -u.x) * 3.0]), Color("#c8d0c5"))


## Un effet de chaque type, à mi-course, loin hors de l'écran (x = 5000 unités).
func _warmup() -> void:
	var x := 5000.0
	var z := 0.0
	var c := Color("#f0dba4")
	for e: Dictionary in [
		{"type": "hit", "x": x, "z": z, "age": 0.05, "duration": 0.22, "color": c},
		{"type": "zone", "x": x, "z": z, "r": 2.0, "age": 0.3, "duration": 1.0, "color": c},
		{"type": "laser", "x": x, "z": z, "tx": x + 6.0, "tz": z, "age": 0.03, "duration": 0.13, "color": c},
		{"type": "rivet", "x": x, "z": z, "tx": x + 8.0, "tz": z, "face": 1, "age": 0.05, "duration": 0.12, "seed": 1},
		{"type": "rivethit", "x": x, "z": z, "face": 1, "tgt": null, "age": 0.1, "duration": 1.0, "seed": 1},
		{"type": "arrow", "x": x, "z": z, "tx": x + 8.0, "tz": z, "face": 1, "age": 0.08, "duration": 0.16, "seed": 1},
		{"type": "arrowhit", "x": x, "z": z, "age": 0.08, "duration": 0.24, "seed": 1},
		{"type": "xbolt", "x": x, "z": z, "tx": x + 8.0, "tz": z, "face": 1, "age": 0.05, "duration": 0.11, "seed": 1},
		{"type": "xboom", "x": x, "z": z, "age": 0.15, "duration": 0.45, "seed": 1},
		{"type": "pilum", "x": x, "z": z, "tx": x + 5.0, "tz": z, "face": 1, "ox": 3.0, "oy": 21.0, "age": 0.1, "duration": 0.25, "seed": 1},
		{"type": "orb", "x": x, "z": z, "tx": x + 8.0, "tz": z, "face": 1, "ox": 2.0, "oy": 31.0, "age": 0.1, "duration": 0.28, "seed": 1},
		{"type": "orbhit", "x": x, "z": z, "age": 0.1, "duration": 0.32, "seed": 1}]:
		match e["type"]:
			"rivet": _rivet(e)
			"rivethit": _rivet_hit(e)
			"arrow": _arrow(e)
			"arrowhit": _arrow_hit(e)
			"pilum": _pilum(e)
			"orb": _orb(e)
			"orbhit": _orb_hit(e)
			"xbolt": _xbolt(e)
			"xboom": _xboom(e)
			_: _simple(e)


# ---------------------------------------------------------------- Pitons d'ancrage de l'Ingénieur

## Pixel natif tramé : visible si l'opacité dépasse le seuil de Bayer du pixel.
func dpx(x: float, y: float, c: Color, a: float) -> void:
	var ix := int(jr(x))
	var iy := int(jr(y))
	if BAYER[iy & 3][ix & 3] < a:
		npx(ix, iy, c)


static func _sm(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _eio(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


static func _ein(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t


static func _eout(t: float) -> float:
	t = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - t * t * t


## Ligne de pixels natifs (pleine si a ≥ 1, tramée sinon).
func nline(a: Vector2, b: Vector2, c: Color, al: float = 1.0) -> void:
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		if al >= 1.0:
			npx(p.x, p.y, c)
		else:
			dpx(p.x, p.y, c, al)


## Disque plein en pixels natifs, un rectangle par ligne (bien moins d'appels que ndisc pour un grand rayon).
func _disc(cx: float, cy: float, r: float, c: Color) -> void:
	var x0 := jr(cx)
	var y0 := jr(cy)
	for y in range(-floori(r), floori(r) + 1):
		var h := floorf(sqrt(r * r - y * y))
		ci.draw_rect(Rect2((x0 - h) * px, (y0 + y) * px, (2.0 * h + 1.0) * px, px), c)


func ndisc(cx: float, cy: float, r: float, c: Color, a: float) -> void:
	for y in range(floori(cy - r), ceili(cy + r) + 1):
		for x in range(floori(cx - r), ceili(cx + r) + 1):
			if Vector2(x - cx, y - cy).length() <= r:
				dpx(x, y, c, a)


func nring(cx: float, cy: float, r: float, c: Color, a: float) -> void:
	var n := maxi(8, ceili(r * 7.0))
	for k in n:
		var t := TAU * k / n
		dpx(cx + cos(t) * r, cy + sin(t) * r * 0.75, c, a)


## Bouche du lance-pitons de l'Ingénieur u visant `target`, en pixels natifs.
func _muzzle(x: float, z: float, target: Vector2, u: Unit) -> Vector2:
	var face := EngineerAim.face_to(x, target, u.face if u and u.face != 0 else 1)
	var bare := u != null and u.unarmored
	return nat_p(x, z) + EngineerAim.muzzle(EngineerAim.angle_to(x, z, target, face, bare), face, bare)


## Piton planté : halo cyan pulsé, tête de laiton cernée.
func _pin(p: Vector2, k: int, now: float) -> void:
	var gl := 0.55 + 0.45 * sin(now * 8.0 + k * 1.7)
	ndisc(p.x + 0.5, p.y + 0.5, 2.6, CY[1], 0.45 * gl)
	for o: Vector2 in [Vector2(-1, 0), Vector2(2, 0), Vector2(0, -1), Vector2(1, -1), Vector2(0, 2), Vector2(1, 2), Vector2(-1, 1), Vector2(2, 1)]:
		npx(p.x + o.x, p.y + o.y, INK)
	npx(p.x, p.y, BRASS[5])
	npx(p.x + 1, p.y, BRASS[3])
	npx(p.x, p.y + 1, BRASS[3])
	npx(p.x + 1, p.y + 1, BRASS[1])
	dpx(p.x, p.y, CY[4], gl * 0.6)


func _piton_flight(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var key := Vector2i(e["i"], e["j"])
	var corner := Combat.piton_corner(key, e["k"])
	var a := _muzzle(e["x"], e["z"], corner, e["unit"])
	var b := nat_p(corner.x, corner.y)
	var p := minf(1.0, e["age"] / e["duration"])
	var dd := (b - a).normalized()
	var pos := a.lerp(b, p) - Vector2(0, sin(PI * p) * 2.0)
	if p < 0.6:
		ndisc(a.x, a.y, 2.2, CY[4], 1.0 - p / 0.6)
		npx(a.x, a.y, Color.WHITE)
	for j in range(1, 9):
		dpx(pos.x - dd.x * j, pos.y - dd.y * j, CY[4] if j < 3 else CY[2], 1.0 - j / 9.0)
	nline(pos - dd * 1.5, pos + dd * 1.5, BRASS[4])
	npx(pos.x + dd.x * 2.0, pos.y + dd.y * 2.0, Color.WHITE)


## Pitons fichés dans les cases en cours de creusement (coups déjà portés), avec l'onde d'impact.
func _planted_pitons(now: float) -> void:
	var st := world.terrain_state
	for key: Vector2i in st.dig_hits:
		var h: int = st.dig_hits[key]
		var since: float = now - float(st.dig_hit_at.get(key, -100.0)) - Combat.PITON_FLIGHT
		for k in mini(h, 4):
			if k == h - 1 and since < 0.0:
				continue
			var c := Combat.piton_corner(key, k)
			var p := nat_p(c.x, c.y)
			if k == h - 1 and since < 0.3:
				var q := since / 0.3
				nring(p.x, p.y, 0.8 + _eout(q) * 5.0, CY[3], 1.0 - q)
				for m in 5:
					var R := Rng.new(key.x * 131 + key.y * 17 + k * 7 + m)
					var ang := -PI * (0.1 + R.next() * 0.8)
					var sp := 10.0 + R.next() * 18.0
					npx(p.x + cos(ang) * sp * since, p.y + sin(ang) * sp * since + 60.0 * since * since, Color("#6b6250") if m & 1 else Color("#a89c86"))
			_pin(p, k, now)


## Suspension de la case : cadre cyan entre les pitons, cubes de roche figés en l'air avec la poussière
## arrêtée, compression en un point lumineux, éclair, retour des pitons au poignet de l'Ingénieur.
func _suspend(e: Dictionary, now: float) -> void:
	if e["age"] < 0.0:
		return
	var q: float = e["age"] / e["duration"]
	var key := Vector2i(e["i"], e["j"])
	var o := nat_p(key.x * 4.0, key.y * 4.0)
	var cc := o + Vector2(15.5, 15.5)
	var T: Array[Vector2] = []
	for k in 4:
		var c := Combat.piton_corner(key, k)
		T.append(nat_p(c.x, c.y))
	var img: Image = e["img"]
	# Roche de la case : intacte et teintée de cyan, puis fendue en cubes de 8 px, puis comprimée.
	if img and q < 0.8:
		var e1 := _eio((q - 0.12) / 0.33)
		var e2 := _ein((q - 0.45) / 0.35)
		for ly in 32:
			for lx in 32:
				var col := img.get_pixel(lx, ly)
				if col.a < 0.5:
					continue
				var tint: bool = BAYER[ly & 3][lx & 3] < 0.28 * _sm(q / 0.12)
				if q < 0.12:
					npx(o.x + lx, o.y + ly, CY[2] if tint else col)
					continue
				var pc := Vector2(floorf(lx / 8.0) * 8.0 + 4.0, floorf(ly / 8.0) * 8.0 + 4.0)
				var off := (pc - Vector2(15.5, 15.5)) * 0.25 * e1 - Vector2(0, 3.0 * e1)
				var rim: bool = (lx % 8 == 7 or ly % 8 == 7) and BAYER[ly & 3][lx & 3] < 0.6
				var cr := CY[2] if rim and e1 > 0.1 else col
				if q < 0.45:
					npx(o.x + lx + off.x, o.y + ly + off.y, cr)
				else:
					var s := 1.0 - e2
					var pp := cc + (Vector2(lx, ly) + off - Vector2(15.5, 15.5)) * s
					npx(pp.x, pp.y, CY[5] if e2 > 0.8 else (CY[4] if e2 > 0.5 else (CY[3] if e2 > 0.2 else cr)))
	# Cadre cyan entre les pitons, puis filins vers le centre pendant la compression.
	if q < 0.45:
		var w := _sm(q / 0.12) * 4.0
		for k in 4:
			var f := clampf(w - k, 0.0, 1.0)
			if f <= 0.0:
				break
			var flick := Rng.new(k * 97 + int(now * 20.0)).next() > 0.8
			nline(T[k], T[k].lerp(T[(k + 1) % 4], f), CY[4] if flick else CY[3], 1.0 if q < 0.12 else 0.8)
	elif q < 0.8:
		var e2 := _ein((q - 0.45) / 0.35)
		for k in 4:
			nline(T[k], T[k].lerp(cc, e2), CY[3], 0.7)
	# Éclair final.
	if q > 0.8 and q < 0.92:
		var f := (q - 0.8) / 0.12
		nring(cc.x, cc.y, 2.0 + f * 9.0, CY[4], 1.0 - f)
		for r in int(6.0 * (1.0 - f)) + 1:
			for d: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
				npx(cc.x + d.x, cc.y + d.y, Color.WHITE)
	# Poussière figée en l'air, qui retombe après l'éclair.
	if q > 0.12:
		for j in 16:
			var R := Rng.new(j * 29 + 3)
			var x := o.x - 4.0 + R.next() * 40.0
			var y := o.y - 6.0 + R.next() * 40.0
			var c := Color("#6b6250") if R.next() < 0.5 else Color("#c9b98f")
			if q > 0.8:
				var t: float = (q - 0.8) * e["duration"]
				y += 100.0 * t * t
				if y > o.y + 36.0:
					continue
			dpx(x, y, c, (q - 0.12) / 0.08 if q < 0.2 else 1.0)
	# Pitons : fichés aux angles, puis rappelés vers le lance-pitons.
	var u: Unit = e["unit"]
	for k in 4:
		var p := T[k]
		if q > 0.85:
			if q > 0.98:
				continue
			var hand := _muzzle(u.x, u.z, Vector2(e["x"], e["z"]), u) if u else cc
			p = T[k].lerp(hand, _ein((q - 0.85) / 0.15))
		_pin(p, k, now)


## Sceau sensible (sim/mods.gd) : chaque case de filon à moins de 12 cases du porteur luit à travers la roche et le
## brouillard, d'un losange de sa couleur qui pulse ; le plus proche pulse plus fort.
const SEAL_ORE := {"copper": Color("#e09450"), "iron": Color("#c8d0da"), "quartz": Color("#e6f0ff"), "gold": Color("#f0d050"),
	"silver": Color("#eef2f8"), "tear": Color("#d8f0e6"), "amber": Color("#f0a84a"), "orichalcum": Color("#f0b898")}
var _seal_cache: Array = []
var _seal_at := -INF


## Calque au-dessus du brouillard (world/overlay/seal_glints_view.gd).
func draw_seal_layer(now: float) -> void:
	px = float(world.camera.px)
	_seal_glints(now)


func _seal_glints(now: float) -> void:
	var u := Mods.wearer("seal")
	if u == null or world.terrain_state == null:
		return
	if now - _seal_at > 0.5:
		_seal_at = now
		_seal_cache = Mods.ores_near(u, world.terrain_state)
		u.mods["seal_dir"] = (_seal_cache[0][0] - u.pos()) if not _seal_cache.is_empty() else Vector2.ZERO
	for k in _seal_cache.size():
		var o: Array = _seal_cache[k]
		var c: Vector2 = o[0]
		var col: Color = SEAL_ORE.get(o[1], Color.WHITE)
		var q := 0.5 + 0.5 * sin(now * 3.0 - float(o[2]) * 0.15)
		var a := (0.55 + 0.45 * q) * (1.0 if k == 0 else 0.7) * clampf(1.2 - float(o[2]) / (Mods.SEAL_CELLS * 4.0), 0.25, 1.0)
		var s := nat_p(c.x, c.y) * px - Vector2(0, 6 * px)
		var r := (2.0 + roundf(q)) * px
		ci.draw_colored_polygon(PackedVector2Array([s + Vector2(0, -r - px), s + Vector2(r, 0), s + Vector2(0, r + px), s + Vector2(-r, 0)]), Color(col, a * 0.85))
		ci.draw_rect(Rect2(s - Vector2(px, 2 * px), Vector2(px, px)), Color(Color.WHITE, a))
		if k == 0:
			ci.draw_rect(Rect2(s - Vector2(r + 3 * px, 0), Vector2(px, px)), Color(col, a * q))
			ci.draw_rect(Rect2(s + Vector2(r + 2 * px, 0), Vector2(px, px)), Color(col, a * q))
