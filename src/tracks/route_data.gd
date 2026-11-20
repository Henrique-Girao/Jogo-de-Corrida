extends RefCounted
## Authored road centerlines, materials and atmosphere for each racing sector.

const AUTODROMO := {
	"name": "Autódromo Candeia",
	"subtitle": "Pista oficial • Vale da Candeia",
	"practice_mode": "circuit",
	"half_width": 7.2,
	"points": [
		Vector3(0, 0.36, 0), Vector3(0, 0.36, 96), Vector3(16, 0.70, 207),
		Vector3(79, 1.05, 286), Vector3(174, 1.28, 286), Vector3(226, 1.08, 213),
		Vector3(192, 0.77, 127), Vector3(119, 0.52, 76), Vector3(127, 0.48, -4),
		Vector3(196, 0.56, -67), Vector3(164, 0.96, -150), Vector3(76, 0.70, -178),
		Vector3(14, 0.49, -146), Vector3(-5, 0.40, -86),
	],
	"road": Color("#424d53"),
	"shoulder": Color("#676c69"),
	"ground_a": Color("#576f60"),
	"ground_b": Color("#788475"),
	"curb_a": Color("#e39762"),
	"curb_b": Color("#e3dec8"),
	"stripe": Color("#e7e0ce"),
	"sky_top": Color("#5688ab"),
	"sky_horizon": Color("#bacdd4"),
	"sky_bottom": Color("#6b8286"),
	"sun": Color("#fff1d5"),
	"sun_angle": Vector3(-42, -135, 0),
	"fog": Color("#a1bbc1"),
	"ambient": Color("#bacbd7"),
	"sun_energy": 1.07,
	"ambient_energy": 0.64,
	"fog_density": 0.0022,
	"clouds": 0.70,
}

const DOCAS := {
	"name": "Cais Ferrugem",
	"subtitle": "Porto industrial • Setor 06",
	"practice_mode": "sprint",
	"half_width": 6.2,
	"points": [
		Vector3(0, 0.65, 0), Vector3(0, 0.64, 87), Vector3(0, 0.64, 179),
		Vector3(24, 0.65, 240), Vector3(102, 0.65, 247), Vector3(172, 0.65, 306),
		Vector3(267, 0.65, 292), Vector3(296, 0.65, 217), Vector3(258, 0.65, 154),
		Vector3(181, 0.65, 165), Vector3(134, 0.65, 92), Vector3(158, 0.65, 11),
		Vector3(132, 0.66, -68), Vector3(56, 0.66, -102), Vector3(24, 0.65, -57),
	],
	"road": Color("#44515a"),
	"shoulder": Color("#52616a"),
	"ground_a": Color("#46535f"),
	"ground_b": Color("#536168"),
	"curb_a": Color("#a77f54"),
	"curb_b": Color("#838579"),
	"stripe": Color("#d6b583"),
	"sky_top": Color("#2e4e71"),
	"sky_horizon": Color("#a990a1"),
	"sky_bottom": Color("#485b70"),
	"sun": Color("#fbc99c"),
	"sun_angle": Vector3(-15, -49, 0),
	"fog": Color("#7f899e"),
	"ambient": Color("#a7bbd1"),
	"sun_energy": 0.72,
	"ambient_energy": 0.78,
	"fog_density": 0.0026,
	"clouds": 0.56,
}

const SERRA := {
	"name": "Serra da Lua",
	"subtitle": "Rodovia BR-63 • Alto da Lua",
	"practice_mode": "sprint",
	"half_width": 5.6,
	"points": [
		Vector3(0, 1.4, 0), Vector3(0, 1.8, 57), Vector3(-17, 4.0, 130),
		Vector3(-82, 9.0, 184), Vector3(-152, 13.6, 224), Vector3(-132, 19.8, 299),
		Vector3(-62, 26.0, 356), Vector3(7, 28.7, 393), Vector3(90, 25.2, 358),
		Vector3(114, 21.8, 290), Vector3(177, 20.7, 240), Vector3(233, 21.6, 292),
		Vector3(255, 24.1, 388), Vector3(328, 25.4, 433), Vector3(416, 22.3, 402),
		Vector3(494, 17.6, 428), Vector3(532, 13.2, 506), Vector3(582, 11.8, 575),
	],
	"circuit_return": [
		Vector3(585, 10.0, 640), Vector3(517, 10.0, 695), Vector3(418, 11.0, 660),
		Vector3(338, 15.0, 618), Vector3(239, 19.0, 640), Vector3(145, 17.0, 609),
		Vector3(76, 14.0, 544), Vector3(-18, 11.0, 529), Vector3(-105, 8.0, 475),
		Vector3(-213, 6.0, 456), Vector3(-267, 5.0, 369), Vector3(-260, 3.5, 261),
		Vector3(-221, 2.0, 155), Vector3(-167, 1.0, 64), Vector3(-95, 1.0, -25),
		Vector3(-30, 1.1, -69), Vector3(-2, 1.3, -44),
	],
	"road": Color("#4a4c4a"),
	"shoulder": Color("#82796a"),
	"ground_a": Color("#617465"),
	"ground_b": Color("#8a8269"),
	"curb_a": Color("#dad5bd"),
	"curb_b": Color("#685854"),
	"stripe": Color("#edc487"),
	"sky_top": Color("#627f9b"),
	"sky_horizon": Color("#e8be9d"),
	"sky_bottom": Color("#8a8c8b"),
	"sun": Color("#ffe0ad"),
	"sun_angle": Vector3(-20, 41, 0),
	"fog": Color("#aba59e"),
	"ambient": Color("#c1cbd1"),
	"sun_energy": 0.94,
	"ambient_energy": 0.68,
	"fog_density": 0.0020,
	"clouds": 0.55,
}

static func get_route(track_id: String) -> Dictionary:
	match track_id:
		"docas":
			return DOCAS
		"serra":
			return SERRA
		_:
			return AUTODROMO
