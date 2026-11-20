extends "res://tests/test_case.gd"
## Cycle jour/nuit (core/day_night.gd).


func test_game_starts_by_day() -> void:
	check_eq(DayNight.phase(0.0), "jour", "la partie commence de jour")
	check_eq(DayNight.night(0.0), 0.0, "pas d'obscurité de nuit au départ")


func test_full_cycle() -> void:
	var seen := {}
	var t := 0.0
	while t < DayNight.LENGTH:
		seen[DayNight.phase(t)] = true
		t += 2.0
	check_eq(seen.size(), 4, "aube, jour, crépuscule, nuit")
	check(absf(DayNight.fraction(DayNight.LENGTH * 3.0 + 10.0) - DayNight.fraction(10.0)) < 1e-9, "cycle périodique")


func test_night_is_darker() -> void:
	var night_t := (0.85 - DayNight.START) * DayNight.LENGTH
	check_eq(DayNight.night(night_t), 1.0, "pleine nuit")
	check(DayNight.sky(night_t).a > DayNight.sky(0.0).a + 0.3, "le dehors s'assombrit la nuit")
	check(DayNight.sky(night_t).b > DayNight.sky(night_t).r, "nuit bleutée")
	var dusk := (0.64 - DayNight.START) * DayNight.LENGTH
	check(DayNight.sky(dusk).r > DayNight.sky(dusk).b, "crépuscule rosé")


func test_assaults_only_by_day() -> void:
	for w in range(1, 20):
		var t := 37.0 + w * 211.0
		var at := DayNight.next_assault(t, w, 1234)
		var gap := DayNight.day(at) - DayNight.day(t)
		# Un assaut par jour, à 9 h : le jour même s'il reste le répit, sinon le lendemain.
		check(gap == 0 or gap == 1, "assaut le jour même ou le lendemain (%d)" % gap)
		check(at >= t + DayNight.WAVE_REST, "au moins le répit avant l'assaut")
		check(at - t < DayNight.LENGTH + DayNight.WAVE_REST, "pas plus d'un jour d'attente")
		check_eq(DayNight.clock(at), "09:00", "assaut à 9 h")
		check(DayNight.is_day(at), "assaut de jour")
	var night := (0.85 - DayNight.START) * DayNight.LENGTH
	check(DayNight.is_day(DayNight.next_daylight(night)), "la nuit, le premier assaut attend le matin")
	check(DayNight.next_daylight(night) > night, "après la nuit")
	check_eq(DayNight.next_daylight(30.0), 30.0, "de jour : tout de suite")


func test_sky_status() -> void:
	GameState.sim_time = 0.0
	GameState.weather = {}
	var s := HudModel.sky_status()
	check_eq(s["day"], "Jour 1", "premier jour")
	check_eq(s["time"], DayNight.clock(0.0), "heure affichée")
	check_eq(DayNight.clock(0.0), "07:54", "la partie commence vers 8 h")
	GameState.sim_time = (0.85 - DayNight.START) * DayNight.LENGTH
	GameState.weather = {"kind": "pluie", "from": "pluie", "since": 0.0}
	s = HudModel.sky_status()
	check_eq(s["time_icon"], "moon", "lune la nuit")
	GameState.sim_time = 0.0
	GameState.weather = {}
