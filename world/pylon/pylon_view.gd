class_name PylonView
extends Node2D
## Obélisque suintant d'un Pylône de Merenor (assets/imported/pylon/, exporté par
## planches/pylone-merenor-v2-propositions.html?export=1 via tools/pylone/serve.py) : boucle corrompue,
## boucle canalisée par-dessus en fondu avec le retrait de la nappe, rainures du socle allumées pour
## chaque culte qui prie. Enfant de l'emplacement du décor (trié avec les objets du monde).

const DIR := "res://assets/imported/pylon/"
static var _meta: Dictionary
static var _sheets: Dictionary

var pylon: Dictionary
var _corrupt := Sprite2D.new()
var _channel := Sprite2D.new()
var _sides: Array[Sprite2D] = []


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "pylon.json"))
		for k: String in ["corrupt", "channel", "sides"]:
			_sheets[k] = load(DIR + "pylon_%s.png" % k)
	return _meta


func setup(p: Dictionary, slot: Node2D) -> void:
	pylon = p
	name = "Pylon_%d" % int(p["id"])
	var m := meta()
	position = Proj.nat(p["x"], 0.0, p["z"]) - slot.position
	use_parent_material = true
	var off := -Vector2(float(m["ax"]), float(m["ay"]))
	for pair: Array in [[_corrupt, "corrupt"], [_channel, "channel"]]:
		var s: Sprite2D = pair[0]
		s.texture = _sheets[pair[1]]
		s.region_enabled = true
		s.centered = false
		s.offset = off
		s.use_parent_material = true
		add_child(s)
	var fw := float(m["frame_w"])
	var fh := float(m["frame_h"])
	for k in (m["sides"] as Array).size():
		var s := Sprite2D.new()
		s.texture = _sheets["sides"]
		s.region_enabled = true
		s.region_rect = Rect2(k * fw, 0, fw, fh)
		s.centered = false
		s.offset = off
		s.use_parent_material = true
		add_child(s)
		_sides.append(s)
	_process(0.0)


func _process(_delta: float) -> void:
	var m := _meta
	var f := floori(GameState.sim_time * float(m["fps"])) % int(m["count"])
	var cols := int(m["cols"])
	var r := Rect2((f % cols) * float(m["frame_w"]), (f / cols) * float(m["frame_h"]), float(m["frame_w"]), float(m["frame_h"]))
	_corrupt.region_rect = r
	_channel.region_rect = r
	var cover := float(pylon.get("cover", 1.0))
	_channel.visible = cover < 1.0
	_channel.modulate.a = 1.0 - cover
	var praying: Array = pylon.get("praying", [])
	var order: Array = m["sides"]
	for k in _sides.size():
		_sides[k].visible = cover > 0.0 and praying.has(order[k])
