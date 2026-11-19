extends RefCounted

const RaceEvents = preload("res://src/race/race_events.gd")

const STARTER := "brasa_16"
const SECTORS := {
	"garage": {"name": "Oficina Ribeira", "purpose": "Garagem, preparação e pintura"},
	"meet": {"name": "Porto da Vigília", "purpose": "Pilotos, encontros e duelos"},
	"official": {"name": "Paddock Candeia", "purpose": "Inscrições, Copa da Orla e treino livre"},
	"market": {"name": "Revenda do Cais", "purpose": "Carros à venda e ofertas de particulares"},
}
const COLORS := {
	"Marfim": "#E4DBC6",
	"Sal": "#F6F2E9",
	"Asfalto": "#343A48",
	"Chumbo": "#77828B",
	"Terracota": "#CC5A45",
	"Titânio": "#D09A53",
	"Verde-petróleo": "#39A093",
	"Azul-orla": "#416EAD",
	"Violeta": "#7163A0",
	"Rosa-quente": "#C1768D",
}

const VEHICLES := {
	"brasa_16": {
		"name": "Brasa 1.6", "category": "Popular", "category_id": "economico", "kind": "hatch",
		"description": "Leve, honesto e fácil de colocar na curva. É com ele que muita gente aprende a correr.",
		"power": 102, "torque": 148, "weight": 1010, "acceleration": 10.7, "top_speed": 179,
		"drive": "FWD", "grip": 0.97, "braking": 0.98, "handling": 1.08, "lift": 0.94,
		"rating": 105, "potential": 0.92, "value": 5200, "rarity": "Comum", "color": "#C95F4F", "rep": 0,
	},
	"linha_rs": {
		"name": "Linha RS", "category": "Compacto", "category_id": "compacto", "kind": "compact",
		"description": "O turbo pequeno acorda cedo, e a dianteira obedece mesmo com pouco espaço.",
		"power": 147, "torque": 218, "weight": 1130, "acceleration": 8.3, "top_speed": 204,
		"drive": "FWD", "grip": 1.02, "braking": 1.04, "handling": 1.12, "lift": 1.02,
		"rating": 151, "potential": 1.04, "value": 8800, "rarity": "Comum", "color": "#3E7F92", "rep": 0,
	},
	"monte_gt": {
		"name": "Monte GT", "category": "Sedã", "category_id": "seda", "kind": "sedan",
		"description": "Entre-eixos longo e motor cheio. Gosta de retas, frenagens firmes e entradas pacientes.",
		"power": 193, "torque": 276, "weight": 1405, "acceleration": 7.4, "top_speed": 223,
		"drive": "RWD", "grip": 1.01, "braking": 1.05, "handling": 0.94, "lift": 0.92,
		"rating": 194, "potential": 1.08, "value": 13900, "rarity": "Comum", "color": "#778494", "rep": 2,
	},
	"vetra_x": {
		"name": "Vetra X", "category": "Hot hatch", "category_id": "hot_hatch", "kind": "hot_hatch",
		"description": "Curto, nervoso e com tração integral para voltar cedo ao acelerador.",
		"power": 231, "torque": 325, "weight": 1330, "acceleration": 6.0, "top_speed": 241,
		"drive": "AWD", "grip": 1.16, "braking": 1.11, "handling": 1.19, "lift": 1.08,
		"rating": 239, "potential": 1.06, "value": 19300, "rarity": "Incomum", "color": "#E6AA54", "rep": 4,
	},
	"fenda_30": {
		"name": "Fenda 3.0", "category": "Coupé esportivo", "category_id": "coupe", "kind": "coupe",
		"description": "A traseira se move com pouco acelerador. Mantém o ritmo quando você encontra o equilíbrio.",
		"power": 276, "torque": 348, "weight": 1320, "acceleration": 5.4, "top_speed": 256,
		"drive": "RWD", "grip": 1.13, "braking": 1.13, "handling": 1.16, "lift": 1.02,
		"rating": 278, "potential": 1.12, "value": 23500, "rarity": "Incomum", "color": "#3E9E88", "rep": 5,
	},
	"trovao_68": {
		"name": "Trovão 68", "category": "Muscle clássico", "category_id": "muscle", "kind": "muscle",
		"description": "Muito torque nas rodas traseiras. Na reta ele recompensa quem sabe dosar a saída.",
		"power": 347, "torque": 525, "weight": 1640, "acceleration": 5.9, "top_speed": 248,
		"drive": "RWD", "grip": 0.96, "braking": 0.94, "handling": 0.83, "lift": 0.85,
		"rating": 310, "potential": 1.08, "value": 29100, "rarity": "Raro", "color": "#705883", "rep": 6,
	},
	"iris_22": {
		"name": "Íris 22", "category": "Esportivo japonês", "category_id": "jdm", "kind": "jdm",
		"description": "O chassi preciso e a tração integral seguram o ímpeto do turbo nas saídas rápidas.",
		"power": 323, "torque": 429, "weight": 1420, "acceleration": 4.8, "top_speed": 269,
		"drive": "AWD", "grip": 1.23, "braking": 1.18, "handling": 1.23, "lift": 1.11,
		"rating": 340, "potential": 1.21, "value": 37800, "rarity": "Raro", "color": "#557DBB", "rep": 9,
	},
	"alvor_72": {
		"name": "Alvor 72", "category": "Clássico esportivo", "category_id": "classico", "kind": "classic",
		"description": "Um clássico leve de respostas diretas. A traseira avisa antes de escapar.",
		"power": 239, "torque": 300, "weight": 1070, "acceleration": 5.5, "top_speed": 237,
		"drive": "RWD", "grip": 1.09, "braking": 1.06, "handling": 1.19, "lift": 0.97,
		"rating": 301, "potential": 0.93, "value": 41200, "rarity": "Raro", "color": "#D8CEB5", "rep": 8,
	},
	"vektor_v8": {
		"name": "Vektor V8", "category": "Esportivo europeu", "category_id": "europeu", "kind": "euro",
		"description": "Motor aspirado, freio incisivo e capacidade de manter velocidade em curvas longas.",
		"power": 455, "torque": 527, "weight": 1510, "acceleration": 3.9, "top_speed": 303,
		"drive": "RWD", "grip": 1.29, "braking": 1.31, "handling": 1.26, "lift": 1.23,
		"rating": 461, "potential": 1.02, "value": 62000, "rarity": "Raro", "color": "#B34549", "rep": 13,
	},
	"miragem_r": {
		"name": "Miragem R", "category": "Supercarro", "category_id": "supercarro", "kind": "super",
		"description": "Motor central e tração integral em um dos modelos mais raros do litoral.",
		"power": 595, "torque": 670, "weight": 1455, "acceleration": 3.2, "top_speed": 334,
		"drive": "AWD", "grip": 1.36, "braking": 1.38, "handling": 1.29, "lift": 1.30,
		"rating": 575, "potential": 0.92, "value": 88000, "rarity": "Especial", "color": "#79B4AA", "rep": 18,
	},
}

const NPCS := {
	"lia": {
		"name": "Lia Reis", "role": "Pilota de base", "bio": "Conhece todas as curvas do Cais. Prefere carro leve e aposta baixa.",
		"skill": 0.48, "aggression": 0.22, "preference": "economico", "budget": 8200, "negotiation": 0.65, "risk": 0.30, "car": "brasa_16",
	},
	"beto": {
		"name": "Beto Muniz", "role": "Mecânico e corredor", "bio": "Abre espaço na oficina trocando compactos bem acertados.",
		"skill": 0.51, "aggression": 0.39, "preference": "compacto", "budget": 10500, "negotiation": 0.76, "risk": 0.71, "car": "linha_rs",
	},
	"nia": {
		"name": "Nia Aguiar", "role": "Pilota de provas curtas", "bio": "Freia tarde, vende cedo e guarda o dinheiro para pneus.",
		"skill": 0.58, "aggression": 0.79, "preference": "hot_hatch", "budget": 19000, "negotiation": 0.47, "risk": 0.68, "car": "linha_rs",
	},
	"cida": {
		"name": "Cida Fontes", "role": "Revendedora", "bio": "Prefere sedãs e acordos rápidos. Motor bem cuidado vale conversa.",
		"skill": 0.45, "aggression": 0.24, "preference": "seda", "budget": 22500, "negotiation": 0.82, "risk": 0.32, "car": "monte_gt",
	},
	"gael": {
		"name": "Gael Rosa", "role": "Piloto de serra", "bio": "Sempre procura outro carro compacto para encarar a subida.",
		"skill": 0.65, "aggression": 0.51, "preference": "hot_hatch", "budget": 28000, "negotiation": 0.53, "risk": 0.72, "car": "vetra_x",
	},
	"iris": {
		"name": "Íris Vale", "role": "Pilota e preparadora", "bio": "Só desafia quem consegue acompanhar sua saída de curva.",
		"skill": 0.67, "aggression": 0.58, "preference": "coupe", "budget": 35500, "negotiation": 0.44, "risk": 0.80, "car": "fenda_30",
	},
	"toni": {
		"name": "Toni Paes", "role": "Piloto de arrancada", "bio": "Aprendeu com motores grandes. É o primeiro a topar uma disputa na reta.",
		"skill": 0.62, "aggression": 0.83, "preference": "muscle", "budget": 38000, "negotiation": 0.68, "risk": 0.88, "car": "trovao_68",
	},
	"maya": {
		"name": "Maya Vidal", "role": "Pilota e entusiasta", "bio": "Troca um carro a qualquer hora pelo esportivo japonês certo.",
		"skill": 0.72, "aggression": 0.49, "preference": "jdm", "budget": 47500, "negotiation": 0.67, "risk": 0.74, "car": "iris_22",
	},
	"raul": {
		"name": "Raul Salles", "role": "Colecionador de clássicos", "bio": "Conhece o preço dos clássicos e só aposta quando confia na curva final.",
		"skill": 0.56, "aggression": 0.28, "preference": "classico", "budget": 49000, "negotiation": 0.39, "risk": 0.55, "car": "alvor_72",
	},
	"lara": {
		"name": "Lara Nunes", "role": "Pilota de turismo", "bio": "Prefere traçados técnicos e cobra caro por seus esportivos.",
		"skill": 0.80, "aggression": 0.47, "preference": "europeu", "budget": 73500, "negotiation": 0.46, "risk": 0.69, "car": "vektor_v8",
	},
	"dante": {
		"name": "Dante Cruz", "role": "Colecionador e piloto", "bio": "Poucos já viram seu carro em uma corrida, mas ele aceita uma aposta grande.",
		"skill": 0.86, "aggression": 0.65, "preference": "supercarro", "budget": 106000, "negotiation": 0.31, "risk": 0.86, "car": "miragem_r",
	},
	"sol": {
		"name": "Sol Martim", "role": "Pilota de contrarrelógio", "bio": "Mede cada volta no cronômetro. Compra com calma e dirige com precisão.",
		"skill": 0.75, "aggression": 0.31, "preference": "classico", "budget": 52500, "negotiation": 0.61, "risk": 0.53, "car": "vetra_x",
	},
}

const UPGRADES := {
	"engine": {"name": "Motor", "description": "Mais potência em alta e melhor retomada.", "cost": 1050, "power": 0.052, "torque": 0.031, "speed": 0.016, "rating": 0.026},
	"turbo": {"name": "Sobrealimentação", "description": "Mais torque nas saídas e mais velocidade final.", "cost": 1450, "power": 0.064, "torque": 0.068, "speed": 0.018, "rating": 0.030},
	"transmission": {"name": "Transmissão", "description": "Reduz perdas na aceleração e melhora a velocidade final.", "cost": 920, "accel": 0.034, "speed": 0.008, "rating": 0.016},
	"suspension": {"name": "Suspensão", "description": "Mantém o carro estável durante mudanças de direção.", "cost": 700, "handling": 0.072, "grip": 0.017, "lift": 0.018, "rating": 0.012},
	"tires": {"name": "Pneus", "description": "Aumenta a aderência nas curvas e durante a frenagem.", "cost": 820, "grip": 0.066, "braking": 0.025, "rating": 0.016},
	"brakes": {"name": "Freios", "description": "Reduz a distância de frenagem.", "cost": 690, "braking": 0.085, "rating": 0.010},
	"weight": {"name": "Redução de peso", "description": "Melhora aceleração e agilidade com menos massa.", "cost": 860, "weight": 0.037, "accel": 0.018, "handling": 0.022, "rating": 0.014},
	"ecu": {"name": "ECU", "description": "Ajusta a entrega de torque e aceleração.", "cost": 720, "power": 0.029, "torque": 0.029, "accel": 0.010, "rating": 0.012},
	"exhaust": {"name": "Escape", "description": "Libera potência em alta e aumenta a velocidade final.", "cost": 590, "power": 0.025, "speed": 0.006, "rating": 0.010},
	"differential": {"name": "Diferencial", "description": "Aplica a potência ao chão com mais controle.", "cost": 780, "grip": 0.021, "handling": 0.028, "accel": 0.018, "rating": 0.013},
}

const MAX_UPGRADE_LEVEL := 2

static func vehicle(id: String) -> Dictionary:
	if not VEHICLES.has(id):
		return {}
	var spec: Dictionary = VEHICLES[id].duplicate()
	spec["id"] = id
	spec["model"] = id
	return spec

static func npc(id: String) -> Dictionary:
	if not NPCS.has(id):
		return {}
	var person: Dictionary = NPCS[id].duplicate()
	person["id"] = id
	return person

static func event(id: String) -> Dictionary:
	return RaceEvents.get_event(id)

static func events() -> Array[Dictionary]:
	return RaceEvents.all()

static func effective(car: Dictionary) -> Dictionary:
	var model: String = str(car.get("model", car.get("id", "")))
	var spec := vehicle(model)
	if spec.is_empty():
		return spec
	spec["color"] = str(car.get("color", spec.color))
	var levels: Dictionary = car.get("upgrades", {})
	var power_gain := 0.0
	var torque_gain := 0.0
	var speed_gain := 0.0
	var accel_gain := 0.0
	var weight_loss := 0.0
	var rating_gain := 0.0
	var potential: float = spec.potential
	for key in UPGRADES:
		var level := clampi(int(levels.get(key, 0)), 0, MAX_UPGRADE_LEVEL)
		var amount := float(level) * potential
		var part: Dictionary = UPGRADES[key]
		power_gain += float(part.get("power", 0.0)) * amount
		torque_gain += float(part.get("torque", 0.0)) * amount
		speed_gain += float(part.get("speed", 0.0)) * amount
		accel_gain += float(part.get("accel", 0.0)) * amount
		weight_loss += float(part.get("weight", 0.0)) * amount
		rating_gain += float(part.get("rating", 0.0)) * amount
		spec["handling"] += float(part.get("handling", 0.0)) * amount
		spec["grip"] += float(part.get("grip", 0.0)) * amount
		spec["braking"] += float(part.get("braking", 0.0)) * amount
		spec["lift"] += float(part.get("lift", 0.0)) * amount
	spec["power"] = roundi(float(spec.power) * (1.0 + power_gain))
	spec["torque"] = roundi(float(spec.torque) * (1.0 + torque_gain))
	spec["top_speed"] = roundi(float(spec.top_speed) * (1.0 + speed_gain))
	spec["weight"] = roundi(float(spec.weight) * (1.0 - weight_loss))
	spec["acceleration"] = snappedf(float(spec.acceleration) / (1.0 + power_gain * 0.55 + torque_gain * 0.25 + accel_gain), 0.1)
	spec["rating"] = roundi(float(spec.rating) * (1.0 + rating_gain))
	return spec

static func upgrade_cost(model: String, key: String, next_level: int) -> int:
	var spec := vehicle(model)
	if spec.is_empty() or not UPGRADES.has(key) or next_level < 1 or next_level > MAX_UPGRADE_LEVEL:
		return 0
	var base_cost: int = UPGRADES[key].cost
	var vehicle_factor := 0.82 + sqrt(float(spec.value) / 88000.0) * 0.96
	return roundi(float(base_cost) * vehicle_factor * pow(1.78, next_level - 1) / 10.0) * 10

static func car_value(car: Dictionary) -> int:
	var spec := vehicle(str(car.get("model", "")))
	if spec.is_empty() or bool(car.get("loaner", false)):
		return 0
	var levels: Dictionary = car.get("upgrades", {})
	var added_value := 0.0
	for key in UPGRADES:
		for level in range(1, clampi(int(levels.get(key, 0)), 0, MAX_UPGRADE_LEVEL) + 1):
			added_value += float(upgrade_cost(spec.id, key, level)) * 0.48
	return roundi((float(spec.value) + added_value) / 10.0) * 10
