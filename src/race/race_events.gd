extends RefCounted
## Event data shared by the race selector, progression and the race director.

const EVENTS: Array[Dictionary] = [
	{
		"id": "estreia", "name": "Estreia de Boxe",
		"description": "Uma volta no Autódromo Candeia. Vale carro de entrada e preparado.",
		"mode": "circuit", "track": "autodromo", "laps": 1, "opponents": 3,
		"reward": 1450, "entry": 0, "target_ms": 0, "tier": 0, "reputation": 0,
		"max_rating": 245, "categories": [], "underground": false
	},
	{
		"id": "seletiva", "name": "Sprint dos Armazéns",
		"description": "Faça as freadas cedo e dispute a chegada entre os galpões.",
		"mode": "sprint", "track": "docas", "laps": 1, "opponents": 3,
		"reward": 1900, "entry": 0, "target_ms": 0, "tier": 0, "reputation": 0,
		"max_rating": 350, "categories": [], "underground": false
	},
	{
		"id": "volta_limpa", "name": "Relógio da Pedreira",
		"description": "Uma subida contra o cronômetro. Contorne as curvas sem perder o embalo.",
		"mode": "time_trial", "track": "serra", "laps": 1, "opponents": 0,
		"reward": 1600, "entry": 0, "target_ms": 59000, "tier": 0, "reputation": 0,
		"categories": [], "underground": false
	},
	{
		"id": "reta_402", "name": "Quarto de Milha",
		"description": "Acelere nas docas e suba a marcha quando a faixa do giro acender.",
		"mode": "drag", "track": "docas", "laps": 1, "opponents": 1,
		"reward": 1550, "entry": 0, "target_ms": 0, "tier": 0, "reputation": 0,
		"max_rating": 350, "categories": [], "underground": false
	},
	{
		"id": "copa_cais", "name": "Copa da Orla · Cais",
		"description": "Primeira etapa da Copa da Orla, nos corredores do porto.",
		"mode": "sprint", "track": "docas", "laps": 1, "opponents": 4,
		"reward": 2850, "entry": 0, "target_ms": 0, "tier": 1, "reputation": 2,
		"min_rating": 145, "categories": [], "underground": false,
		"series": "copa_orla", "round": 1, "rounds": 3, "series_reward": 8500
	},
	{
		"id": "copa_serra", "name": "Copa da Orla · Serra",
		"description": "Segunda etapa da Copa da Orla. Saia com tração dos cotovelos.",
		"mode": "sprint", "track": "serra", "laps": 1, "opponents": 4,
		"reward": 3850, "entry": 0, "target_ms": 0, "tier": 1, "reputation": 4,
		"min_rating": 145, "categories": [], "underground": false,
		"series": "copa_orla", "round": 2, "rounds": 3, "series_reward": 8500
	},
	{
		"id": "copa_apice", "name": "Copa da Orla · Final",
		"description": "Duas voltas em Candeia. Haverá tráfego nas frenagens.",
		"mode": "circuit", "track": "autodromo", "laps": 2, "opponents": 5,
		"reward": 6200, "entry": 0, "target_ms": 0, "tier": 2, "reputation": 6,
		"min_rating": 190, "categories": [], "underground": false,
		"series": "copa_orla", "round": 3, "rounds": 3, "series_reward": 8500
	},
	{
		"id": "compactos_do_clube", "name": "Clube dos Compactos",
		"description": "Uma prova exclusiva para populares, compactos e hot hatches.",
		"mode": "circuit", "track": "autodromo", "laps": 2, "opponents": 4,
		"reward": 3000, "entry": 0, "target_ms": 0, "tier": 1, "reputation": 2,
		"max_rating": 330, "categories": ["economico", "compacto", "hot_hatch"],
		"underground": false
	},
	{
		"id": "docas_noturnas", "name": "Depois do Expediente",
		"description": "Duelo até o armazém no fim das docas. Escolha o valor da aposta.",
		"mode": "sprint", "track": "docas", "laps": 1, "opponents": 1,
		"reward": 0, "entry": 0, "target_ms": 0, "tier": 0, "reputation": 0,
		"categories": [], "underground": true, "min_wager": 250, "max_wager": 2400, "pink": true
	},
	{
		"id": "descida_secreta", "name": "Linha da Neblina",
		"description": "Um contra um no caminho da pedreira. Dá para apostar as chaves.",
		"mode": "sprint", "track": "serra", "laps": 1, "opponents": 1,
		"reward": 0, "entry": 0, "target_ms": 0, "tier": 1, "reputation": 2,
		"categories": [], "underground": true, "min_wager": 400, "max_wager": 6000, "pink": true
	},
	{
		"id": "sinal_verde", "name": "Sinal Verde",
		"description": "Arrancada lado a lado nas docas. A troca de cada marcha decide o duelo.",
		"mode": "drag", "track": "docas", "laps": 1, "opponents": 1,
		"reward": 0, "entry": 0, "target_ms": 0, "tier": 0, "reputation": 0,
		"categories": [], "underground": true, "min_wager": 250, "max_wager": 4200, "pink": true
	}
]

static func all() -> Array[Dictionary]:
	return EVENTS.duplicate(true)


static func get_event(event_id: String) -> Dictionary:
	for event in EVENTS:
		if event.id == event_id:
			return event.duplicate(true)
	return {}
