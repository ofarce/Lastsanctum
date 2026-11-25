class_name QuarterMarksLayer
extends Node
## Pose les repères d'entrée de quartier (sim/quarter_marks.gd) dans le tri en profondeur du monde : un
## QuarterMarkView par stèle et par arche, refaits quand la carte change.

var world: World
var _seed := -1
var _views: Array[Node] = []


func _process(_delta: float) -> void:
	if world == null:
		return
	var st := world.terrain_state
	var s := -1 if st == null or st.temple_layout.is_empty() else st.seed
	if s == _seed:
		return
	_seed = s
	for v in _views:
		v.queue_free()
	_views.clear()
	if s < 0:
		return
	# Portes des tunnels de la grotte et ruines des seuils de quartier (sim/cave_doors.gd).
	if CaveDoors.active(st):
		var doors: Array[CaveDoorView] = []
		for i in CaveDoors.MOUTHS.size():
			var v := CaveDoorView.new()
			v.setup_mouth(world, i)
			doors.append(v)
		for r: Dictionary in CaveDoors.ruins(st):
			var v := CaveDoorView.new()
			v.setup_ruin(world, r)
			doors.append(v)
		for v in doors:
			world.ysort.add_child(v)
			world.sanctum_view.ground.add_child(v.ground_node())
			_views.append(v)
	for m: Dictionary in QuarterMarks.marks(st):
		var v := QuarterMarkView.new()
		v.setup(m, world)
		world.ysort.add_child(v)
		_views.append(v)
	# Glyphe sur chaque porte de quartier : au milieu de ses cases.
	var cells := {}
	for c: Vector2i in st.door_cells:
		(cells.get_or_add(st.door_cells[c], []) as Array).append(c)
	for k: String in cells:
		# Porte de l'Orbite : façade aux deux veilleuses et rigoles depuis les arènes (sim/orbit_gate.gd).
		if k == OrbitGate.KEY:
			var gate := OrbitGateView.new()
			gate.setup(world)
			world.ysort.add_child(gate)
			_views.append(gate)
			var rill := OrbitRillView.new()
			rill.setup(world, gate)
			world.add_child(rill)
			world.move_child(rill, world.ysort.get_index())
			_views.append(rill)
			continue
		var sum := Vector2.ZERO
		for c: Vector2i in cells[k]:
			sum += Vector2(c) * 4.0 + Vector2(2.0, 4.0)
		var g := DoorGlyphView.new()
		g.setup(k, sum / float((cells[k] as Array).size()), world)
		world.ysort.add_child(g)
		_views.append(g)
