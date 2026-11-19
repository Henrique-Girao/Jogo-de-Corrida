extends RefCounted
## Authored road centerlines, materials and atmosphere for each racing sector.

const AUTODROMO := {
	"name": "Autódromo Candeia",
	"subtitle": "Pista oficial • Vale da Candeia",
	"half_width": 7.2,
	"points": [
		Vector3(0, 0.36, 0), Vector3(0, 0.36, 96), Vector3(16, 0.70, 207),
		Vector3(79, 1.05, 286), Vector3(174, 1.28, 286), Vector3(226, 1.08, 213),
		Vector3(192, 0.77, 127), Vector3(119, 0.52, 76), Vector3(127, 0.48, -4),
		Vector3(196, 0.56, -67), Vector3(164, 0.96, -150), Vector3(76, 0.70, -178),
		Vector3(14, 0.49, -146), Vector3(-5, 0.40, -86),
	],
	"road": Color("#303941"),
	"shoulder": Color("#535c60"),
	"ground_a": Color("#4d5b56"),
	"ground_b": Color("#68716a"),
	"curb_a": Color("#f48a45"),
	"curb_b": Color("#e4e0d1"),
	"stripe": Color("#dedaca"),
	"sky_top": Color("#3d647d"),
	"sky_horizon": Color("#c3b1a0"),
	"sky_bottom": Color("#65716e"),
	"sun": Color("#ffd9af"),
	"fog": Color("#a7a9a0"),
	"ambient": Color("#a6bed3"),
	"sun_energy": 1.15,
	"ambient_energy": 0.52,
	"fog_density": 0.0028,
}

const DOCAS := {
	"name": "Cais Ferrugem",
	"subtitle": "Porto industrial • Setor 06",
	"half_width": 6.2,
	"points": [
		Vector3(0, 0.65, 0), Vector3(0, 0.64, 87), Vector3(0, 0.64, 179),
		Vector3(24, 0.65, 240), Vector3(102, 0.65, 247), Vector3(172, 0.65, 306),
		Vector3(267, 0.65, 292), Vector3(296, 0.65, 217), Vector3(258, 0.65, 154),
		Vector3(181, 0.65, 165), Vector3(134, 0.65, 92), Vector3(158, 0.65, 11),
		Vector3(132, 0.66, -68), Vector3(56, 0.66, -102), Vector3(24, 0.65, -57),
	],
	"road": Color("#343f47"),
	"shoulder": Color("#475258"),
	"ground_a": Color("#2d3944"),
	"ground_b": Color("#394754"),
	"curb_a": Color("#c47143"),
	"curb_b": Color("#56676a"),
	"stripe": Color("#cba978"),
	"sky_top": Color("#182843"),
	"sky_horizon": Color("#61608a"),
	"sky_bottom": Color("#3d475e"),
	"sun": Color("#9fb2e0"),
	"fog": Color("#62647d"),
	"ambient": Color("#aabdde"),
	"sun_energy": 0.7,
	"ambient_energy": 0.70,
	"fog_density": 0.0030,
}

const SERRA := {
	"name": "Serra da Lua",
	"subtitle": "Rodovia BR-63 • Alto da Lua",
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
	"road": Color("#3b3b43"),
	"shoulder": Color("#706059"),
	"ground_a": Color("#62544e"),
	"ground_b": Color("#9c7362"),
	"curb_a": Color("#dad5bd"),
	"curb_b": Color("#685854"),
	"stripe": Color("#edc487"),
	"sky_top": Color("#4c5478"),
	"sky_horizon": Color("#e6a38a"),
	"sky_bottom": Color("#806e7d"),
	"sun": Color("#ffd0a5"),
	"fog": Color("#a78288"),
	"ambient": Color("#b0b7d5"),
	"sun_energy": 1.05,
	"ambient_energy": 0.62,
	"fog_density": 0.0025,
}

static func get_route(track_id: String) -> Dictionary:
	match track_id:
		"docas":
			return DOCAS
		"serra":
			return SERRA
		_:
			return AUTODROMO
