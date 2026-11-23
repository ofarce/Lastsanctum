extends Node
## Vérifie que les images de la jungle calculées sur un fil de travail sont celles du calcul sur place.
func _ready() -> void:
	var st := TerrainState.new()
	st.generate_galleries(20261114)
	var t0 := Time.get_ticks_msec()
	var direct := GroundZones.zone_map(st.flora)
	var rv := RiverView.new()
	rv.river = st.river
	var rdirect := rv._segment_images_all()
	var t1 := Time.get_ticks_msec()
	GroundZones.prepare(st.flora)
	RiverView.prepare(st.river)
	var slot: Array = GroundZones._pending[st.flora.seed]
	WorkerThreadPool.wait_for_group_task_completion(slot[0])
	var p: Array = RiverView._pending[st.river.seed]
	WorkerThreadPool.wait_for_group_task_completion(p[0][0])
	var t2 := Time.get_ticks_msec()
	var parts := []
	for sp: Array in slot[1]:
		parts.append(sp[0])
	var same: bool = GroundZones._join(parts, GroundZones.rect().size.y).get_data() == direct.get_data()
	var rsame := true
	for n in rdirect.size():
		for c in [2, 3]:
			rsame = rsame and (p[0][1][n][c] as Image).get_data() == (rdirect[n][c] as Image).get_data()
	print("zones identiques ", same, " · rivière identique ", rsame, " (", rdirect.size(), " bandes) · sur place ", t1 - t0, " ms · en parallèle ", t2 - t1, " ms")
	rv.free()
	(p[1] as Node).free()
	get_tree().quit()
