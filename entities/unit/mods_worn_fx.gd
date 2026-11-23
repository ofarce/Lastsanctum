extends Node2D
## Dessin porté des douze mods du 2026-11-21 (planches/mods-icones-propositions.html : le motif de l'icône est ce
## qu'on voit sur l'Ingénieur). Deux instances par Ingénieur : derrière le corps (front = false) et devant. Repère en
## pixels natifs depuis les pieds, retourné avec l'Ingénieur (comme iris_fx.gd) ; points du corps relevés sur la
## pose de face (tests/visual/mods_fiche_capture). Les déclenchements viennent de Unit.mods (sim/mods.gd).

const Gear := preload("res://data/gear_items.gd")
var view: UnitView
var front := false
var _vdir := "d"

## Points du corps (pixels natifs, Ingénieur tourné vers +x, pieds en 0, 0).
const SHOULDER := Vector2(6, -19)
const CHEST := Vector2(2, -14)
const BELT := Vector2(3, -10)
const HIP_BACK := Vector2(-6, -11)
const HIP_FRONT := Vector2(6, -10)
const HEAD_BACK := Vector2(-9, -30)
const BACK := Vector2(-4, -22)
const BACK_LOW := Vector2(-5, -15)
## Arbalestrie : bouche, milieu, culasse ; de profil (tenue devant, comme EffectsDrawer.XBOW_MUZZLE), de face (sur
## l'épaule arrière, en diagonale) et de dos.
const XBOW := {"": [Vector2(18, -15), Vector2(13, -16), Vector2(9, -17)],
	"d": [Vector2(-11, -24), Vector2(-9, -18), Vector2(-7, -12)],
	"u": [Vector2(-9, -26), Vector2(-8, -21), Vector2(-6, -16)]}
const SEAL_CENTER := Vector2(-15.5, -17.5)
## Œil avant (profil) et entre les yeux (de face), où se lève la loupe d'Analyse.
const EYE := Vector2(5, -27)
const EYE_FRONT := Vector2(1, -27)
## Loupe d'Analyse levée (0 : à la ceinture, 1 : devant l'œil), lissée d'une image à l'autre (ANALYSE_LIFT s).
const ANALYSE_LIFT := 0.3
var _lift := 0.0
var _lift_t := -INF
## Couche de chaque mod : derrière le corps ou devant (inversé de dos).
const BEHIND := ["wisp", "chant", "echo"]

const STEEL := [Color("#0e2630"), Color("#2a5a70"), Color("#4a90a8"), Color("#8ad0e0"), Color("#e0f8ff")]
const EMBER := [Color("#3a0a04"), Color("#8a2008"), Color("#d84a10"), Color("#f8902a"), Color("#ffe08a")]
const ICHOR := [Color("#1a0608"), Color("#4a1018"), Color("#8a1f2c"), Color("#d85a5a"), Color("#ffc0b8")]
const IRON := [Color("#1a1c20"), Color("#3a3e46"), Color("#5e646e"), Color("#9aa2ac"), Color("#e0e6ec")]
const GLASS := [Color("#0a2a2a"), Color("#1a6a60"), Color("#3ab0a0"), Color("#9ae8d8"), Color("#f0fff8")]
const BRASS := [Color("#3a2810"), Color("#8a6420"), Color("#d0a038"), Color("#f0d070"), Color("#fff4c8")]
const FROST := [Color("#0a1a30"), Color("#2a5080"), Color("#5a9ad0"), Color("#a8dcff"), Color("#f0fbff")]
const SILVER := [Color("#202832"), Color("#465461"), Color("#6d7b88"), Color("#b5c1ca"), Color("#eff4f5")]
const SYLVE := [Color("#0a2a10"), Color("#1a6a2a"), Color("#3ab040"), Color("#9af070"), Color("#f0ffc0")]
const SHADOW := [Color("#100a20"), Color("#2a1a50"), Color("#4a3a8a"), Color("#8a7ad0"), Color("#e0d8ff")]
const GOLD := [Color("#3a2a08"), Color("#7a5a10"), Color("#c89a20"), Color("#f0d050"), Color("#fff8c0")]
const CLOTH := [Color("#2a1a0e"), Color("#7a5a38"), Color("#a8865a"), Color("#c8a676"), Color("#ecd6a4")]
const PYLON := [Color("#0a2020"), Color("#1a4a48"), Color("#2a8a80"), Color("#7ad8c8"), Color("#e0fff8")]
const CYAN := Color("#5ce8ff")
const CARMIN := Color("#d8402a")


static func any_worn(u: Unit) -> bool:
	if u.role != "engineer" or u.is_enemy() or not u.alive():
		return false
	for slot: String in Gear.MODULE_SLOTS:
		var m := String(Gear.ITEMS.get(u.equipment.get(slot, ""), {}).get("module", ""))
		if m != "" and not ["veil", "iris", "drill"].has(m):
			return true
	return false


func tick(face: int, offset: Vector2, vdir: String, body_shown: bool) -> void:
	var u := view.unit
	visible = body_shown and any_worn(u)
	position = offset
	scale = Vector2(face, 1)
	_vdir = vdir
	if visible:
		queue_redraw()


func _on(effect: String) -> bool:
	if not Gear.has_module(view.unit, effect):
		return false
	var behind := BEHIND.has(effect) != (_vdir == "u")
	return behind != front


func _px(p: Vector2, c: Color, a := 1.0) -> void:
	if a > 0.0:
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(c, minf(1.0, a)))


func _ring(c: Vector2, r: float, col: Color, alpha: float, from := 0.0, to := TAU) -> void:
	var n := maxi(8, roundi(r * 7.0 * (to - from) / TAU))
	var seen := {}
	for i in n + 1:
		var p := (c + Vector2.from_angle(lerpf(from, to, float(i) / n)) * r).round()
		if not seen.has(p):
			seen[p] = true
			_px(p, col, alpha)


func _draw() -> void:
	var u := view.unit
	var t := GameState.sim_time
	if _on("scale"):
		_scale(u, t)
	if _on("ember"):
		_ember(u, t)
	if _on("magnet"):
		_magnet(u, t)
	if _on("lens"):
		_lens(t)
	if _on("barrel"):
		_barrel(t)
	if _on("frost"):
		_frost(t)
	if _on("seal"):
		_seal(u, t)
	if _on("wisp"):
		_wisp(t)
	if _on("anchor"):
		_anchor(u, t)
	if _on("chant"):
		_chant(u, t)
	elif front and Gear.has_module(u, "chant"):
		_chant_wave(u, t)
	if _on("sack"):
		_sack(t)
	if _on("analyse"):
		_analyse(u, t)
	if _on("echo"):
		_echo(u, t)
	elif front and Gear.has_module(u, "echo"):
		_echo_ring(u, t)


## Écaille d'acier sur l'épaule avant ; chargée (frôlement) : cœur cyan qui pulse et étincelle.
func _scale(u: Unit, t: float) -> void:
	var c := SHOULDER
	var charged := Mods.scale_charged(u)
	for p: Vector2 in [Vector2(0, -3), Vector2(-1, -2), Vector2(1, -2), Vector2(-2, -1), Vector2(2, -1), Vector2(-2, 0), Vector2(2, 0), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 2)]:
		_px(c + p, STEEL[0])
	for p: Vector2 in [Vector2(0, -2), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]:
		_px(c + p, STEEL[2])
	_px(c + Vector2(0, -1), STEEL[4])
	_px(c, CYAN if charged else STEEL[2])
	_px(c + Vector2(-1, -1), STEEL[4] if charged else STEEL[3], 0.8)
	if charged:
		var q := 0.5 + 0.5 * sin(t * 6.0)
		_px(c + Vector2(0, -3), CYAN, 0.4 + 0.5 * q)
		_px(c + Vector2(2, -1), CYAN, 0.5 * q)
		_px(c + Vector2(-2, 0), CYAN, 0.5 * (1.0 - q))
		var k := t - Mods.at(u, "graze")
		if k < 0.35:
			_ring(c, 2.0 + k * 18.0, CYAN, 1.0 - k / 0.35)
	var spent := t - Mods.at(u, "scale_spent")
	if spent < 0.3:
		for i in 3:
			_px(c + Vector2(2 + i * 2 + spent * 20.0, -1 + i), STEEL[4], 1.0 - spent / 0.3)


## Cœur de braise incrusté dans la poitrine ; embrasé : il flambe, flammèches qui montent.
func _ember(u: Unit, t: float) -> void:
	var c := CHEST
	var on := Mods.ember_on(u)
	var ready := t >= Mods.at(u, "ember_ready")
	var glow := 0.6 + 0.4 * sin(t * (9.0 if on else 2.5))
	for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]:
		_px(c + p, EMBER[2] if ready or on else EMBER[1])
	_px(c + Vector2(-1, -1), EMBER[4] if on else EMBER[3], glow)
	_px(c, EMBER[3] if ready or on else EMBER[2], glow)
	if on:
		for i in 4:
			var k := fposmod(t * 1.6 + i * 0.25, 1.0)
			_px(c + Vector2(roundf(sin(i * 2.3 + t * 3.0)), -2.0 - k * 9.0), EMBER[4 if k < 0.3 else 3 if k < 0.6 else 2], 1.0 - k)
		_ring(c, 3.0 + 0.6 * sin(t * 9.0), EMBER[3], 0.35)


## Fer à cheval à la ceinture ; à chaque ennemi abattu, une goutte d'ichor file vers lui.
func _magnet(u: Unit, t: float) -> void:
	var c := BELT
	_px(c + Vector2(-1, -1), ICHOR[2])
	_px(c + Vector2(1, -1), ICHOR[2])
	_px(c + Vector2(-1, 0), ICHOR[3])
	_px(c + Vector2(1, 0), ICHOR[2])
	_px(c + Vector2(0, 1), ICHOR[1])
	_px(c + Vector2(-1, 1), ICHOR[1])
	_px(c + Vector2(1, 1), ICHOR[1])
	_px(c + Vector2(-1, -2), IRON[4])
	_px(c + Vector2(1, -2), IRON[3])
	var k := (t - Mods.at(u, "kill")) / 0.5
	if k >= 0.0 and k < 1.0:
		var d: Vector2 = u.mods.get("kill_from", Vector2.RIGHT)
		var dir := Vector2(d.x * scale.x, d.y * 0.5).normalized() if d.length_squared() > 0.0001 else Vector2.RIGHT
		var p := c + dir * 24.0 * (1.0 - k * k)
		_px(p, ICHOR[3])
		_px(p + Vector2(0, -1), ICHOR[2])
		_px(p - dir * 2.0, ICHOR[2], 0.6)
		_px(p - dir * 4.0, ICHOR[1], 0.3)
		if k > 0.8:
			_ring(c, 2.5, ICHOR[4], (1.0 - k) * 5.0)


## Lentille vert d'eau vissée à la bouche de l'Arbalestrie, reflet qui passe.
func _lens(t: float) -> void:
	var c: Vector2 = XBOW.get(_vdir, XBOW[""])[0]
	_px(c, GLASS[2])
	_px(c + Vector2(1, 0), GLASS[2])
	_px(c + Vector2(0, 1), GLASS[1])
	_px(c + Vector2(1, 1), GLASS[2])
	_px(c + Vector2(-1, 0), BRASS[1])
	_px(c + Vector2(2, 1), BRASS[1])
	_px(c, GLASS[4], 0.4 + 0.6 * maxf(0.0, sin(t * 1.7)))


## Second barillet à deux chambres sur l'Arbalestrie : cyan et carmin ; la chambre du prochain tir luit.
func _barrel(t: float) -> void:
	var c: Vector2 = XBOW.get(_vdir, XBOW[""])[1]
	_px(c + Vector2(-1, -1), BRASS[1])
	_px(c + Vector2(0, -1), BRASS[2])
	_px(c + Vector2(1, -1), BRASS[1])
	var next_prev := not GameState.barrel_flip
	_px(c + Vector2(-1, 0), CYAN, 1.0 if not next_prev else 0.55)
	_px(c + Vector2(1, 0), CARMIN, 1.0 if next_prev else 0.55)
	_px(c, BRASS[0])
	_px(c + Vector2(0, 1), BRASS[1])


## Culasse givrée ; au changement de munition, petite fumée froide qui monte.
func _frost(t: float) -> void:
	var c: Vector2 = XBOW.get(_vdir, XBOW[""])[2]
	_px(c, FROST[3])
	_px(c + Vector2(1, 0), FROST[4], 0.8)
	_px(c + Vector2(-1, 1), FROST[2])
	_px(c + Vector2(0, -1), FROST[4], 0.5 + 0.4 * sin(t * 2.0))
	var k := (t - GameState.ammo_changed_at) / 0.9
	if k >= 0.0 and k < 1.0:
		for i in 4:
			var p := c + Vector2(-1 + i - 1.5 * k * (i % 2), -2.0 - k * (6.0 + i * 2.0))
			_px(p, FROST[4 if i % 2 == 0 else 3], (1.0 - k) * 0.9)
	if t - GameState.ammo_changed_at < Mods.FROST_TIME:
		_px(c + Vector2(2, -1), FROST[4], 0.7)


## Prisme d'argent au centre de l'orbite du Sceau ; il pulse vers le filon le plus proche.
func _seal(u: Unit, t: float) -> void:
	var c := (SEAL_CENTER + Vector2(0, roundf(sin(t * 1.5)))).round()
	_px(c + Vector2(0, -2), SILVER[4])
	_px(c + Vector2(-1, -1), SILVER[3])
	_px(c + Vector2(0, -1), SILVER[4])
	_px(c + Vector2(1, -1), SILVER[2])
	_px(c + Vector2(-1, 0), SILVER[2])
	_px(c, SILVER[3])
	_px(c + Vector2(1, 0), SILVER[1])
	_px(c + Vector2(0, 1), SILVER[1])
	var d: Vector2 = u.mods.get("seal_dir", Vector2.ZERO)
	if d.length_squared() > 0.0001:
		var dir := Vector2(d.x * scale.x, d.y * 0.6).normalized()
		var k := fposmod(t, 1.2) / 1.2
		for i in 3:
			_px(c + dir * (3.0 + i + k * 5.0), Color("#f0d050"), (1.0 - k) * (1.0 - i * 0.3))


## Feu follet vert de Medeina, derrière la tête, qui flotte et laisse une traîne.
func _wisp(t: float) -> void:
	var c := HEAD_BACK + Vector2(roundf(sin(t * 1.3) * 1.5), roundf(sin(t * 2.1) * 1.5))
	for i in range(4, 0, -1):
		var p := HEAD_BACK + Vector2(sin((t - i * 0.12) * 1.3) * 1.5 - i * 1.2, sin((t - i * 0.12) * 2.1) * 1.5 + i * 0.6)
		_px(p, SYLVE[2], 0.5 - i * 0.1)
	_px(c + Vector2(0, -2), SYLVE[3], 0.7)
	_px(c + Vector2(-1, -1), SYLVE[2])
	_px(c + Vector2(0, -1), SYLVE[3])
	_px(c + Vector2(1, -1), SYLVE[2])
	_px(c + Vector2(-1, 0), SYLVE[2])
	_px(c, SYLVE[4])
	_px(c + Vector2(1, 0), SYLVE[3])
	_px(c + Vector2(0, 1), SYLVE[1])
	_px(c + Vector2(0, -3), SYLVE[4], 0.3 + 0.4 * sin(t * 5.0))


## Petite sphère enchaînée à la hanche ; prête : lueur violette ; au rappel, anneaux qui se resserrent.
func _anchor(u: Unit, t: float) -> void:
	var c := HIP_BACK + Vector2(0, roundf(sin(t * 2.0) * 0.6))
	for i in 3:
		_px(BELT + (c - BELT) * (float(i + 1) / 4.0), IRON[2 + i % 2])
	_px(c + Vector2(0, -1), SHADOW[3])
	_px(c + Vector2(-1, 0), SHADOW[2])
	_px(c, SHADOW[1])
	_px(c + Vector2(1, 0), SHADOW[2])
	_px(c + Vector2(0, 1), SHADOW[0])
	if Mods.recall_ready(u):
		_px(c + Vector2(-1, -1), SHADOW[4], 0.4 + 0.5 * sin(t * 3.0))
	var k := (t - Mods.at(u, "recall")) / 0.7
	if k >= 0.0 and k < 1.0:
		_ring(Vector2(0, -14), 4.0 + (1.0 - k) * 16.0, SHADOW[3], 1.0 - k)
		_ring(Vector2(0, -14), 2.0 + (1.0 - k) * 10.0, SHADOW[4], (1.0 - k) * 0.6)


## Diapason d'or dans le dos ; une onde dorée part toutes les 2 s quand des adeptes travaillent à portée.
func _chant(u: Unit, t: float) -> void:
	var c := BACK
	for y in range(-4, 1):
		_px(c + Vector2(-1, y), GOLD[2 if y > -4 else 3])
		_px(c + Vector2(1, y), GOLD[2 if y > -4 else 3])
	_px(c + Vector2(0, 1), GOLD[2])
	_px(c + Vector2(0, 2), GOLD[1])
	_px(c + Vector2(0, 3), GOLD[1])
	_px(c + Vector2(-1, -4), GOLD[4], 0.6)
	_chant_wave(u, t)


## Onde du diapason, aussi dessinée devant le corps : elle doit se voir quel que soit le côté où il est tourné.
func _chant_wave(u: Unit, t: float) -> void:
	var k := fposmod(t, 2.0) / 2.0
	if _adepts_near(u):
		_ring(BACK + Vector2(0, -2), 2.0 + k * 22.0, GOLD[3], (1.0 - k) * 0.7, -PI * 0.75, -PI * 0.25)


func _adepts_near(u: Unit) -> bool:
	for o: Unit in GameState.units:
		if o != u and o.alive() and o.working and o.pos().distance_squared_to(u.pos()) <= Mods.CHANT_RANGE * Mods.CHANT_RANGE:
			return true
	return false


## Sac de toile à la ceinture, ouverture sur un tourbillon violet.
func _sack(t: float) -> void:
	var c := HIP_FRONT
	for y in range(-1, 3):
		for x in range(-1, 2):
			_px(c + Vector2(x, y), CLOTH[1 if x == 1 or y == 2 else 2])
	_px(c + Vector2(-1, -1), CLOTH[3])
	_px(c + Vector2(0, -2), CLOTH[0])
	_px(c + Vector2(-1, -2), CLOTH[1])
	_px(c + Vector2(1, -2), CLOTH[1])
	var a := t * 4.0
	_px(c + Vector2(0, -1), SHADOW[3])
	_px(c + Vector2(roundf(cos(a)), -1), SHADOW[4], 0.8)
	_px(c + Vector2(roundf(cos(a + PI)), -1), SHADOW[2])


## Analyse (planches/etabli-propositions.html, piste B « Barre sous la loupe ») : petite loupe cerclée d'argent pendue
## à la ceinture ; un ennemi à l'écran (Mods.analysis_seen), elle se lève devant l'œil et sa lentille cyan balaie.
func _analyse(u: Unit, t: float) -> void:
	var dt := clampf(t - _lift_t, 0.0, 0.1) if not is_inf(_lift_t) else 0.0
	_lift_t = t
	var target := 1.0 if Mods.analysis_seen(u) else 0.0
	_lift = move_toward(_lift, target, dt / ANALYSE_LIFT)
	var k := _lift * _lift * (3.0 - 2.0 * _lift)
	var rest := BELT + Vector2(-1, 2)
	var eye := EYE_FRONT if _vdir == "d" else EYE
	var c := rest.lerp(eye + Vector2(1, 0), k).round()
	if k < 0.5:
		# Cordon de la ceinture à la loupe.
		_px(BELT + Vector2(-1, 0), SILVER[1])
		_px(BELT + Vector2(-1, 1), SILVER[2])
	for p: Vector2 in [Vector2(-1, -2), Vector2(0, -2), Vector2(1, -2), Vector2(-2, -1), Vector2(2, -1), Vector2(-2, 0), Vector2(2, 0), Vector2(-2, 1), Vector2(2, 1), Vector2(-1, 2), Vector2(0, 2), Vector2(1, 2)]:
		_px(c + p, SILVER[3] if p.y < 0 or p.x < 0 else SILVER[1])
	var lit := k > 0.9
	for p: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
		_px(c + p, CYAN if lit and p == Vector2(-1, -1) else Color("#1f9fb8") if lit else Color("#12596b"))
	_px(c + Vector2(-1, -1), Color.WHITE if lit else Color("#5ce8ff"), 0.9)
	# Manche, en bas à droite (vers la ceinture quand la loupe est levée).
	_px(c + Vector2(3, 3), SILVER[2])
	_px(c + Vector2(4, 4), SILVER[1])
	if lit:
		var q := fposmod(t, 1.2) / 1.2
		_px(c + Vector2(roundf(lerpf(-1.0, 1.0, q)), 0), Color("#c8fbff"), 0.8)


## Éclat de pylône en pendentif dorsal ; il bourdonne (tremble et lance des ondes) quand il annonce une vague.
func _echo(u: Unit, t: float) -> void:
	var k := t - Mods.at(u, "echo")
	var buzz := k >= 0.0 and k < Mods.ECHO_LEAD
	var c := BACK_LOW + (Vector2(roundf(sin(t * 40.0)), 0) if buzz else Vector2.ZERO)
	_px(c + Vector2(0, -3), PYLON[4])
	_px(c + Vector2(0, -2), PYLON[3])
	_px(c + Vector2(-1, -1), PYLON[2])
	_px(c + Vector2(0, -1), PYLON[3])
	_px(c + Vector2(1, -1), PYLON[1])
	_px(c, PYLON[2])
	_px(c + Vector2(0, 1), PYLON[1])
	_px(c + Vector2(0, -1), PYLON[4], 0.3 + 0.4 * sin(t * (12.0 if buzz else 2.0)))
	_echo_ring(u, t)


## Ondes de l'éclat pendant l'annonce, aussi dessinées devant le corps.
func _echo_ring(u: Unit, t: float) -> void:
	var k := t - Mods.at(u, "echo")
	if k >= 0.0 and k < Mods.ECHO_LEAD:
		var q := fposmod(t, 0.8) / 0.8
		_ring(BACK_LOW + Vector2(0, -1), 2.0 + q * 12.0, PYLON[3], (1.0 - q) * 0.8)
