extends "res://tests/test_case.gd"
## Galeries ouvertes dès le départ (2026-11-22) : aucune paroi vue de face ne reste dessinée sur du sol praticable
## (murs de la grotte de départ qu'on traversait). La roche habillée par une paroi est la case de la grille juste au nord de celle de son pied.


func test_no_wall_face_over_open_floor() -> void:
	var sim: Simulation = shared_main().get_node("Simulation")
	sim.new_game(20261114)
	var st := sim.state()
	var bad: Array[Vector2] = []
	for e: Dictionary in sim.world.decor.entries():
		if e.has("bx") and String(e.get("s", "")).begins_with("face"):
			var rock := Vector2(float(e["bx"]) + 2.0, floorf(float(e["bz"]) / 4.0) * 4.0 - 2.0)
			if st.ground(rock.x, rock.y):
				bad.append(rock)
	check(bad.is_empty(), "parois sur du sol : %s" % str(bad.slice(0, 5)))
