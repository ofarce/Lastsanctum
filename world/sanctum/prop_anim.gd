class_name PropAnim
extends Node2D
## Petite animation d'un objet du décor, enfant de son sprite :
## - "swing" : le sprite se balance autour de son ancre (cordes de cloche, accrochées par le haut), ou autour de
##   `pivot` (pixels depuis l'ancre) quand il est donné : chaînes et cages des Forges, posées au pied du mur et
##   pendues 48 px plus haut ;
## - "pulse" : le sprite s'éclaire par battements (veines et pustules de la Bête, crypte de l'Œil) ;
## - "censer" : encensoir dessiné ici, pendu à une chaîne qui sort du haut de l'écran, qui se balance et fume ;
## Forges mortes (planches/forges-mortes-decor-propositions.html, effets lus dans assets/forges/fx.json) :
## - "glow" : le calque de lueur de la pièce (« <nom>_glow ») bat comme sur la planche (braises, fissures, métal chaud) ;
## - "flow" : la lave glisse le long du calque de la rigole (même onde et mêmes couleurs que la planche) ;
## - "embers" : braises qui montent depuis `at` (pixels depuis l'ancre) ;
## - "steam" : bouffées de vapeur depuis `at`.
## Salles oubliées (planches/salles-oubliees-decor-propositions.html, effets lus dans assets/oubliees/fx.json) :
## - "drip" : une goutte tombe de `at` sur d px (période 1/sp), s'efface (« fade ») ou ride la flaque (« rip ») ;
## - "leak" : jet de gouttelettes qui retombent en parabole (fuite d'un joint de tuyau) ;
## - "spill" : rideau de gouttes sous une vanne, sur w px de large ;
## - "needle" : aiguille du manomètre, centrée en `at`, qui tremble ;
## - "glow" accepte lo, hi, sp : alpha = lo + (hi − lo) × (½ + ½ sin(sp t)), borné à [0, 1] (lueur des glyphes).

const GOLD := [Color8(160, 116, 36), Color8(208, 160, 56), Color8(240, 204, 102)]
const CHAIN := Color8(88, 92, 107)
const SMOKE := Color8(184, 180, 192)
const STEAM := Color8(216, 220, 220)
## Lave de la planche, de la croûte au cœur (LV).
const LAVA := [Color8(74, 16, 6), Color8(138, 36, 12), Color8(216, 84, 30), Color8(240, 154, 58), Color8(255, 210, 122)]
## Hauteur du point d'attache de l'encensoir, en pixels au-dessus du pied.
const CENSER_TOP := 46.0
const CENSER_LEN := 30.0
const FLOW_SHADER := """
shader_type canvas_item;
uniform float t;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float x = floor(UV.x / TEXTURE_PIXEL_SIZE.x) + floor(UV.y / TEXTURE_PIXEL_SIZE.y);
	float w = sin(x * 0.3 - t * 2.4) + sin(x * 0.11 + t * 0.8);
	vec3 col = w > 1.1 ? c4.rgb : (w > 0.1 ? c3.rgb : c2.rgb);
	COLOR = vec4(col, c.a);
}
"""

static var _flow_mat: ShaderMaterial

var mode := ""
var seed := 0.0
## Point d'origine des braises et de la vapeur, pivot du balancement (pixels depuis l'ancre, sprite non retourné).
var at := Vector2.ZERO
var pivot := Vector2.INF
## Braises : nombre, largeur de la source, hauteur de montée (pixels).
var count := 3
var spread := 6.0
var rise := 14.0
## Réglages de l'effet tels que fx.json les donne (d, sp, w, n, col, fade, rip, lo, hi).
var data := {}
var _base := Vector2.INF
var _glow: Sprite2D


## Calque de lueur d'une pièce des Forges (glow, flow), posé exactement sur le sprite parent.
func set_glow(tex: Texture2D, offset: Vector2, flip: bool) -> void:
	_glow = Sprite2D.new()
	_glow.centered = false
	_glow.texture = tex
	_glow.offset = offset
	_glow.flip_h = flip
	if mode == "flow":
		if _flow_mat == null:
			_flow_mat = ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = FLOW_SHADER
			_flow_mat.shader = sh
			_flow_mat.set_shader_parameter("c2", LAVA[2])
			_flow_mat.set_shader_parameter("c3", LAVA[3])
			_flow_mat.set_shader_parameter("c4", LAVA[4])
		_glow.material = _flow_mat
	add_child(_glow)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var t := GameState.sim_time
	match mode:
		"swing":
			var p := get_parent() as Node2D
			var r := sin(t * 1.1 + seed) * 0.07
			if pivot == Vector2.INF:
				p.rotation = r
			else:
				if _base == Vector2.INF:
					_base = p.position
				r *= 0.6
				p.rotation = r
				p.position = _base + pivot - pivot.rotated(r)
		"pulse":
			var k := pow(maxf(0.0, sin(t * 2.4 + seed)), 4.0)
			(get_parent() as CanvasItem).self_modulate = Color(1.0 + 0.7 * k, 1.0 + 0.1 * k, 1.0 + 0.1 * k)
		"glow":
			if _glow != null:
				var lo := float(data.get("lo", 0.4))
				var hi := float(data.get("hi", 1.0))
				_glow.modulate.a = clampf(lo + (hi - lo) * (0.5 + 0.5 * sin(t * float(data.get("sp", 1.7)) + seed)), 0.0, 1.0)
		"flow":
			if _flow_mat != null:
				_flow_mat.set_shader_parameter("t", t)
		"censer", "embers", "steam", "drip", "leak", "spill", "needle":
			queue_redraw()


func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), c)


func _draw() -> void:
	var t := GameState.sim_time
	var o := at
	if (get_parent() as Sprite2D).flip_h:
		o.x = -o.x
	match mode:
		"embers":
			for k in count:
				var h := Rng.hash3(k, 11, int(seed * 10.0))
				var u := fmod(t * 0.7 + h, 1.0)
				var x := o.x + (Rng.hash3(k, 17, int(seed * 10.0)) - 0.5) * spread + sin(t * 3.0 + k) * 1.5
				_px(x, o.y - u * rise, Color(LAVA[4] if u < 0.5 else LAVA[3], 1.0 - u))
			return
		"steam":
			for k in 9:
				var u := fmod(t * 0.8 + k / 9.0, 1.0)
				var c := o + Vector2(u * 5.0 + sin(k * 2.1 + t) * 1.5, -u * 16.0)
				draw_circle(c, 1.0 + u * 3.0, Color(STEAM, (1.0 - u) * 0.4))
			return
		"drip":
			var col := Color(String(data.get("col", "#8ec8b0")))
			var d := float(data.get("d", 20.0))
			var u := fmod(t * float(data.get("sp", 0.55)) + Rng.hash3(int(seed * 10.0), 3, 1), 1.0)
			var cut := float(data.get("cut", 1.0))
			if u < cut:
				_px(o.x, o.y + u * d, Color(col, 1.0 - u if data.get("fade", false) else 1.0))
			if data.get("rip", false) and u > 0.93:
				var k := (u - 0.93) / 0.07
				draw_arc(o + Vector2(1.0, d), 1.0 + k * 2.0, 0.0, TAU, 10, Color(col, 0.7 * (1.0 - k)), 1.0)
			return
		"leak":
			var col := Color(String(data.get("col", "#4a8088")))
			var n := int(data.get("n", 7))
			var d := float(data.get("d", 30.0))
			var w := float(data.get("w", 5.0))
			for k in n:
				var u := fmod(t * float(data.get("sp", 1.3)) + float(k) / n, 1.0)
				var dir := -1.0 if (get_parent() as Sprite2D).flip_h else 1.0
				_px(o.x + dir * (u * w + Rng.hash3(k, 5, 2) * 2.0), o.y + u * u * d, Color(col, 1.0 - u * 0.4))
			return
		"spill":
			var col := Color(String(data.get("col", "#4a8088")))
			var n := int(data.get("n", 7))
			for k in n:
				var u := fmod(t * float(data.get("sp", 0.9)) + float(k) / n, 1.0)
				_px(o.x + k * float(data.get("w", 9.6)) / n, o.y + u * float(data.get("d", 6.0)), Color(col, 1.0 - u))
			return
		"needle":
			var a := -2.3 + sin(t * 2.6) * 0.35 + (Rng.hash3(floori(t * 5.0), 9, 4) - 0.5) * 0.25
			var ink := Color8(10, 11, 16)
			_px(o.x, o.y, ink)
			_px(o.x + cos(a) * 1.7, o.y + sin(a) * 1.7, ink)
			return
		"censer":
			pass
		_:
			return
	var sw := sin(t * 1.2 + seed) * 4.0
	var top := Vector2(0.0, -CENSER_TOP)
	var c := Vector2(sw, -CENSER_TOP + CENSER_LEN)
	for i in int(CENSER_LEN):
		var p := top.lerp(c, i / CENSER_LEN)
		_px(p.x, p.y, CHAIN.lightened(0.2) if i % 3 == 0 else CHAIN)
	for y in range(-2, 3):
		for x in range(-3, 4):
			if x * x / 9.0 + y * y / 5.0 <= 1.0:
				_px(c.x + x, c.y + 2.0 + y, GOLD[2] if x < 0 and y < 0 else (GOLD[1] if x < 1 else GOLD[0]))
	for x in range(-2, 3):
		_px(c.x + x, c.y, GOLD[2])
	for k in 5:
		var u := fmod(t * 0.35 + k / 5.0, 1.0)
		var r := 1.0 + u * 2.2
		var sx := c.x + sin(t + k * 1.7) * 2.0 + u * 3.0
		var sy := c.y - 1.0 - u * 16.0
		draw_circle(Vector2(sx, sy), r, Color(SMOKE, (1.0 - u) * 0.28))
