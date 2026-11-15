extends "res://tests/test_case.gd"
## Étape 4 (v2) : règles d'apparition des arcs de l'Ancre et scintillement des lumières (73b410f).


func test_orb_arcs_visibility() -> void:
	var arcs := OrbArcs.new()
	GameState.orb_active = false
	GameState.orb_progress = 0.0
	check(not arcs.visible_now(), "Ancre éteinte, sans réactivation : pas d'arcs")
	GameState.orb_active = true
	check(arcs.visible_now(), "Ancre active : arcs")
	GameState.orb_active = false
	# Réactivation à 60 % : visibles quand sin(t·23) > 1 − 0,6·1,4 = 0,16.
	GameState.orb_progress = 4.8
	GameState.sim_time = asin(0.5) / 23.0
	check(arcs.visible_now(), "sin(t·23) = 0,5 > 0,16 : crépitement")
	GameState.sim_time = asin(0.1) / 23.0
	check(not arcs.visible_now(), "sin(t·23) = 0,1 < 0,16 : rien")
	GameState.reset()
	arcs.free()


func test_flick_matches_js_formula() -> void:
	# flick(i, a) = 1 + sin(t·9 + i·1,7)·a + sin(t·23 + i)·a·0,5 (lighting.js)
	for t: float in [0.0, 0.37, 12.5]:
		for i: float in [1.0, -41.0, 7.0]:
			var expected := 1.0 + sin(t * 9.0 + i * 1.7) * 0.06 + sin(t * 23.0 + i) * 0.06 * 0.5
			check_near(Lighting.flick(t, i), expected, 1e-12, "flick(%s, %s)" % [t, i])


func test_jround_is_math_round() -> void:
	check_eq(PixelDraw.jround(2.5), 3.0, "2,5")
	check_eq(PixelDraw.jround(-2.5), -2.0, "−2,5 (Math.round arrondit vers +∞)")
	check_eq(PixelDraw.jround(-2.6), -3.0, "−2,6")
