extends Control

signal race_requested(event_id: String, npc_id: String, wager: int, pink: bool)
signal sector_changed(sector: String)
signal ui_cue(cue: String)

const Ui = preload("res://src/ui/ui_kit.gd")
const Catalog = preload("res://src/domain/catalog.gd")
const Routes = preload("res://src/tracks/route_data.gd")
const Track = preload("res://src/tracks/track.gd")
const Showroom = preload("res://src/art/showroom.gd")
const SECTORS := [
	["garage", "Garagem", "COLEÇÃO E OFICINA", "garage"],
	["official", "Competições", "CALENDÁRIO OFICIAL", "flag"],
	["meet", "Encontro", "PORTO DA VIGÍLIA", "meet"],
	["market", "Comércio", "REVENDA E PARTICULARES", "market"],
]
const EVENT_MODES := {
	"circuit": "Circuito", "sprint": "Sprint", "time_trial": "Contrarrelógio",
	"drag": "Arrancada", "championship": "Campeonato",
}
const TIERS := {
	0: "Entrada", 1: "Clube", 2: "Avançado",
	"rookie": "Iniciante", "club": "Clube", "pro": "Avançado",
}

@onready var _state = get_node("/root/GameState")
var _page := "garage"
var _market_filter := "dealer"
var _scroll: ScrollContainer
var _shell: VBoxContainer
var _return_focus: Control
var _nav: VBoxContainer
var _funds: Label
var _reputation: Label
var _deck: VBoxContainer
var _modal: Control
var _toast: PanelContainer
var _toast_tween: Tween
var _grids: Array[GridContainer] = []
var _course_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Ui.skin()
	_build_shell()
	refresh()
	resized.connect(_adapt_layout)


func refresh() -> void:
	if not is_node_ready():
		return
	_funds.text = Ui.money(int(_state.money))
	_reputation.text = "%03d" % int(_state.reputation)
	_render_nav()
	var previous_scroll := _scroll.scroll_vertical
	for child in _scroll.get_children():
		_scroll.remove_child(child)
		child.queue_free()
	_grids.clear()
	_deck = Ui.column(17)
	_deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_deck)
	match _page:
		"garage":
			_build_garage()
		"official":
			_build_official()
		"meet":
			_build_meet()
		"market":
			_build_market()
		"goals":
			_build_goals()
	_adapt_layout()
	_scroll.set_deferred("scroll_vertical", previous_scroll)


func active_sector() -> String:
	return "meet" if _page == "meet" else "garage"


func show_notice(message: String) -> void:
	if message.is_empty() or not is_node_ready():
		return
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	if is_instance_valid(_toast):
		_toast.queue_free()
	_toast = Ui.panel(Ui.SOFT_ACID, Ui.ACID, 17, 11)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.z_index = 9
	var caption := Ui.paragraph(message, 17, Ui.PAPER)
	caption.custom_minimum_size.x = 320
	_toast.add_child(caption)
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 23)
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.14)
	_toast_tween.tween_interval(3.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.24)
	_toast_tween.finished.connect(_toast.queue_free)


func back() -> bool:
	if is_instance_valid(_modal):
		_close_modal()
		return true
	if _page != "garage":
		_switch_page("garage")
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and back():
		get_viewport().set_input_as_handled()


func _build_shell() -> void:
	var base := ColorRect.new()
	base.color = Ui.INK
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_shell = Ui.column(0)
	add_child(_shell)
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := Ui.panel(Ui.SHELL, Ui.EDGE, 25, 11)
	header.custom_minimum_size.y = 69
	_shell.add_child(header)
	var header_row := Ui.row(12)
	header.add_child(header_row)
	header_row.add_child(Ui.glyph("logo", 33, Ui.ACID))
	var brand := Ui.column(0)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(brand)
	brand.add_child(Ui.label("ASFALTO DE TROCA", 26, Ui.PAPER, Ui.DISPLAY))
	header_row.add_child(Ui.stretch())
	var metrics := Ui.row(24)
	metrics.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(metrics)
	_funds = _metric(metrics, "CAIXA DISPONÍVEL", Ui.ACID)
	metrics.add_child(Ui.line(Ui.EDGE, true))
	_reputation = _metric(metrics, "RESPEITO", Ui.PAPER)
	var settings := _icon_button("gear", "Configurações")
	settings.custom_minimum_size = Vector2(46, 43)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(settings)
	settings.pressed.connect(_open_settings)

	var outer := Ui.margin(22, 19, 22, 19)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(outer)
	var body := Ui.row(21)
	outer.add_child(body)
	var nav := Ui.panel(Ui.SHELL, Ui.EDGE, 12, 16)
	nav.custom_minimum_size.x = 229
	body.add_child(nav)
	_nav = Ui.column(8)
	nav.add_child(_nav)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	body.add_child(_scroll)


func _metric(parent: Control, title: String, tint: Color) -> Label:
	var column := Ui.column(0)
	column.custom_minimum_size.x = 72
	column.add_child(Ui.meta(title, Ui.MUTE, 10))
	var value := Ui.label("", 22, tint, Ui.DISPLAY)
	column.add_child(value)
	parent.add_child(column)
	return value


func _render_nav() -> void:
	for child in _nav.get_children():
		_nav.remove_child(child)
		child.queue_free()
	var caption := Ui.margin(9, 2, 2, 4)
	caption.add_child(Ui.meta("SETORES", Ui.MUTE, 11))
	_nav.add_child(caption)
	for item in SECTORS:
		var button := _nav_button(item[0], item[1], item[2], item[3])
		_nav.add_child(button)
	_nav.add_child(Ui.stretch(true))
	_nav.add_child(Ui.line())
	_nav.add_child(_nav_button("goals", "Desafios", "", "trophy"))


func _nav_button(id: String, title: String, subtitle: String, glyph: String) -> Button:
	var current := id == _page
	var button := Ui.button("", false, 57 if not subtitle.is_empty() else 45)
	button.tooltip_text = title
	var fill := Ui.SOFT_ACID if current else Ui.SHELL
	var edge := Ui.ACID if current else Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", Ui.box(fill, edge, 1, 5))
	button.add_theme_stylebox_override("hover", Ui.box(Ui.PANEL_HIGH, Ui.EDGE, 1, 5))
	button.add_theme_stylebox_override("pressed", Ui.box(Ui.SOFT_ACID, Ui.ACID, 1, 5))
	var inset := Ui.margin(11, 4, 8, 4)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := Ui.row(11)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(row)
	row.add_child(Ui.glyph(glyph, 22, Ui.ACID if current else Ui.MUTE))
	var names := Ui.column(1)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(Ui.label(title, 18, Ui.ACID if current else Ui.PAPER, Ui.DISPLAY))
	if not subtitle.is_empty():
		names.add_child(Ui.meta(subtitle, Ui.MUTE, 9))
	row.add_child(names)
	if current:
		row.add_child(Ui.glyph("chevron", 12, Ui.ACID))
	button.pressed.connect(func() -> void: _switch_page(id))
	return button


func _switch_page(id: String) -> void:
	if id != _page:
		_page = id
		_scroll.scroll_vertical = 0
		ui_cue.emit("select")
		sector_changed.emit(active_sector())
		refresh()


func _adapt_layout() -> void:
	var usable := size.x - 305.0
	for grid in _grids:
		if is_instance_valid(grid):
			grid.columns = 3 if usable >= 975 else (2 if usable >= 490 else 1)


func _heading(title: String, subtitle: String, note: String = "") -> void:
	var row := Ui.row(16)
	var stack := Ui.column(1)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(Ui.label(title, 49, Ui.PAPER, Ui.DISPLAY))
	stack.add_child(Ui.paragraph(subtitle, 17))
	row.add_child(stack)
	if not note.is_empty():
		var tag := _tag(note, Ui.ACID)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	_deck.add_child(row)
	_deck.add_child(Ui.line())


func _section(title: String, detail: String = "") -> void:
	var row := Ui.row(10)
	row.add_child(Ui.label(title, 23, Ui.PAPER, Ui.DISPLAY))
	row.add_child(Ui.stretch())
	if not detail.is_empty():
		var meta := Ui.meta(detail)
		meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(meta)
	_deck.add_child(row)


func _tag(content: String, tint: Color = Ui.MUTE) -> PanelContainer:
	var bit := Ui.panel(Ui.SHELL, Ui.EDGE, 9, 5)
	bit.add_child(Ui.meta(content, tint, 11))
	return bit


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_grids.append(grid)
	_deck.add_child(grid)
	return grid


func _icon_button(glyph: String, tooltip: String) -> Button:
	var button := Ui.button("")
	button.tooltip_text = tooltip
	var icon := Ui.glyph(glyph, 20)
	button.add_child(icon)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -11
	icon.offset_top = -11
	icon.offset_right = 11
	icon.offset_bottom = 11
	return button


func _showcase(parent: Control, spec: Dictionary, sector: String, min_height: int = 285) -> Control:
	var stage := Panel.new()
	stage.add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.EDGE, 1, 6))
	stage.clip_contents = true
	stage.custom_minimum_size.y = min_height
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stage)
	var showroom := Showroom.new()
	showroom.stretch = true
	showroom.set_sector(sector)
	showroom.set_vehicle(spec)
	stage.add_child(showroom)
	showroom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return stage


func _corner_note(stage: Control, message: String, tint: Color = Ui.ACID, bottom: bool = false) -> void:
	var tag := _tag(message, tint)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(tag)
	if bottom:
		tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		tag.position = Vector2(13, stage.size.y - tag.size.y - 13)
	else:
		tag.position = Vector2(13, 13)


func _build_garage() -> void:
	var cars: Array = _state.cars
	_heading("Garagem", "Escolha seu carro e trabalhe nele entre corridas.", "%02d NA COLEÇÃO" % cars.size())
	var owned: Dictionary = _state.active_car()
	if owned.is_empty():
		_deck.add_child(Ui.paragraph("A garagem está vazia. Consulte as ofertas de comércio para encontrar um carro."))
		return
	var spec: Dictionary = Catalog.effective(owned)
	var loaner := bool(owned.get("loaner", false))
	var row := Ui.row(12)
	_deck.add_child(row)
	var stage := _showcase(row, spec, "garage", 314)
	_corner_note(stage, "CARRO DE APOIO" if loaner else "CARRO ATIVO", Ui.GOLD if loaner else Ui.ACID)
	_corner_note(stage, "ARRASTE PARA GIRAR", Ui.MUTE, true)

	var detail := Ui.panel(Ui.PANEL, Ui.EDGE, 16, 13)
	detail.custom_minimum_size.x = 281
	row.add_child(detail)
	var info := Ui.column(8)
	detail.add_child(info)
	info.add_child(Ui.meta("%s  /  %s" % [str(spec.get("category", "")).to_upper(), str(spec.get("rarity", "")).to_upper()], Ui.ACID))
	info.add_child(Ui.label(str(spec.get("name", spec.get("model", ""))), 27, Ui.PAPER, Ui.DISPLAY))
	info.add_child(Ui.line())
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 17)
	stats.add_theme_constant_override("v_separation", 6)
	info.add_child(stats)
	_metric_pair(stats, "POTÊNCIA", "%d cv" % int(spec.get("power", 0)))
	_metric_pair(stats, "FINAL", "%d km/h" % int(spec.get("top_speed", 0)))
	_metric_pair(stats, "PESO", "%d kg" % int(spec.get("weight", 0)))
	_metric_pair(stats, "TRAÇÃO", str(spec.get("drive", "—")).to_upper())
	info.add_child(Ui.stretch(true))
	if loaner:
		info.add_child(Ui.paragraph("Use o carro de apoio nas provas oficiais para recuperar seu caixa.", 16, Ui.GOLD))
	else:
		var tune := Ui.button("Preparar carro   ›", true)
		tune.pressed.connect(_open_tuning)
		info.add_child(tune)
		var paint := Ui.button("Pintura e cor", false, 37)
		paint.pressed.connect(_open_paint)
		info.add_child(paint)

	_section("Minha coleção", "SELECIONE UM CARRO")
	var collection := ScrollContainer.new()
	collection.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	collection.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	collection.custom_minimum_size.y = 79
	_deck.add_child(collection)
	var slots := Ui.row(9)
	collection.add_child(slots)
	for car in cars:
		_make_car_slot(slots, car, str(owned.get("uid", "")))
	var market := Ui.button("Explorar ofertas   ›", false, 56)
	market.pressed.connect(func() -> void: _switch_page("market"))
	slots.add_child(market)


func _metric_pair(parent: Control, title: String, value: String) -> void:
	var stack := Ui.column(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(Ui.meta(title, Ui.MUTE, 10))
	stack.add_child(Ui.label(value, 18, Ui.PAPER, Ui.DISPLAY))
	parent.add_child(stack)


func _make_car_slot(parent: Control, car: Dictionary, active: String) -> void:
	var spec: Dictionary = Catalog.effective(car)
	var uid := str(car.get("uid", ""))
	var current := uid == active
	var button := Ui.button(str(spec.get("name", "Carro")), current, 56)
	button.custom_minimum_size.x = 172
	button.pressed.connect(func() -> void:
		if not current:
			_apply(_state.select_car(uid), false)
	)
	parent.add_child(button)


func _build_official() -> void:
	_heading("Competições", "Inscreva-se em provas oficiais e ganhe dinheiro e respeito.", "CENTRO OFICIAL")
	var ordinary := _grid()
	for event in Catalog.events():
		if not bool(event.get("underground", false)) and not event.has("series"):
			_event_card(ordinary, event)
	var cup: Dictionary = _state.championship.get("copa_orla", {})
	var standing := "CONQUISTADA" if bool(cup.get("completed", false)) else "%d / 27 PONTOS" % int(cup.get("points", 0))
	_section("Copa da Orla", "3 ETAPAS  ·  %s" % standing)
	var series := _grid()
	for event in Catalog.events():
		if event.has("series"):
			_event_card(series, event)


func _build_meet() -> void:
	_heading("Encontro", "Combine o desafio, confira os riscos e aceite quando estiver pronto.", "PONTO DE ENCONTRO")
	var row := Ui.row(12)
	_deck.add_child(row)
	var meetup_car: Dictionary = Catalog.vehicle("linha_rs")
	var stage := _showcase(row, meetup_car, "meet", 215)
	_corner_note(stage, "CAIS FERRUGEM", Ui.GOLD)
	var club := Ui.panel(Ui.PANEL, Ui.EDGE, 16, 14)
	club.custom_minimum_size.x = 280
	row.add_child(club)
	var body := Ui.column(9)
	club.add_child(body)
	body.add_child(Ui.meta("PILOTOS E ENTUSIASTAS", Ui.GOLD))
	body.add_child(Ui.label("Negócios no cais", 24, Ui.PAPER, Ui.DISPLAY))
	var note := Ui.paragraph("Propostas particulares também aparecem no comércio. Cada piloto valoriza um tipo de carro.", 16)
	note.custom_minimum_size.x = 238
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(note)
	body.add_child(Ui.stretch(true))
	var private_market := Ui.button("Ver ofertas particulares   ›", false, 40)
	private_market.pressed.connect(func() -> void:
		_market_filter = "private"
		_switch_page("market")
	)
	body.add_child(private_market)

	_section("Duelos clandestinos", "DINHEIRO OU CHAVES")
	var grid := _grid()
	for event in Catalog.events():
		if bool(event.get("underground", false)):
			_event_card(grid, event)


func _event_card(parent: Control, event: Dictionary) -> void:
	var id := str(event.get("id", ""))
	var status: Dictionary = _state.event_status(id)
	var street := bool(event.get("underground", false))
	var main_color := Ui.GOLD if street else Ui.ACID
	var card := Ui.panel(Ui.PANEL, Ui.EDGE, 15, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var stack := Ui.column(7)
	card.add_child(stack)

	var facts := Ui.row(9)
	facts.add_child(Ui.meta(_mode_name(event).to_upper(), main_color, 11))
	facts.add_child(Ui.stretch())
	facts.add_child(Ui.meta(_event_tier(event).to_upper(), Ui.MUTE, 10))
	stack.add_child(facts)

	var course := CourseMap.new()
	var mode := str(event.get("course_mode", event.get("mode", "")))
	var track := str(event.get("track", ""))
	var route_key := "%s:%s" % [track, mode]
	if not _course_cache.has(route_key):
		_course_cache[route_key] = Track.map_preview(track, mode)
	course.outline = _course_cache[route_key]
	course.tint = main_color
	course.custom_minimum_size.y = 57
	stack.add_child(course)

	var title := Ui.paragraph(str(event.get("name", "Prova")), 22, Ui.PAPER)
	title.add_theme_font_override("font", Ui.DISPLAY)
	stack.add_child(title)
	stack.add_child(Ui.meta(_track_name(event).to_upper(), Ui.MUTE, 11))
	stack.add_child(Ui.stretch(true))

	var reward := Ui.row(7)
	reward.add_child(Ui.meta("APOSTA" if street else "1º LUGAR", Ui.MUTE, 10))
	reward.add_child(Ui.stretch())
	var prize := "A partir de %s" % Ui.money(int(event.get("min_wager", 0))) if street else Ui.money(int(event.get("reward", 0)))
	reward.add_child(Ui.label(prize, 17, main_color, Ui.DISPLAY))
	stack.add_child(reward)

	var open := Ui.button("Ver condições   ›" if not status.get("ok", false) else ("Escolher adversário   ›" if street else "Ver prova   ›"), false, 41)
	open.pressed.connect(func() -> void: _open_event(event))
	stack.add_child(open)


func _mode_name(event: Dictionary) -> String:
	return str(EVENT_MODES.get(str(event.get("mode", "")), "Corrida"))


func _track_name(event: Dictionary) -> String:
	return str(Routes.get_route(str(event.get("track", ""))).get("name", "Pista"))


func _event_tier(event: Dictionary) -> String:
	return str(TIERS.get(event.get("tier", 0), "Livre"))


func _open_event(event: Dictionary) -> void:
	var id := str(event.get("id", ""))
	var street := bool(event.get("underground", false))
	var body := _open_dialog(str(event.get("name", "Corrida")), _track_name(event).to_upper())
	body.add_child(Ui.paragraph(str(event.get("description", "")), 18))
	var fact_grid := GridContainer.new()
	fact_grid.columns = 3
	fact_grid.add_theme_constant_override("h_separation", 19)
	body.add_child(fact_grid)
	_metric_pair(fact_grid, "MODALIDADE", _mode_name(event))
	if event.get("mode") == "time_trial":
		_metric_pair(fact_grid, "TEMPO-ALVO", "%.1f s" % (float(event.get("target_ms", 0)) / 1000.0))
	elif event.has("series"):
		_metric_pair(fact_grid, "ETAPA", "%d de %d" % [int(event.get("round", 1)), int(event.get("rounds", 1))])
	else:
		_metric_pair(fact_grid, "VOLTAS" if event.get("mode") == "circuit" else "ADVERSÁRIOS", str(event.get("laps", 1) if event.get("mode") == "circuit" else event.get("opponents", 1)))
	_metric_pair(fact_grid, "APOSTA MÍNIMA" if street else "PRÊMIO", Ui.money(int(event.get("min_wager", 0) if street else event.get("reward", 0))))
	body.add_child(Ui.line())
	var record: Dictionary = _state.records.get(id, {})
	var best := int(record.get("best_ms", 0))
	if best > 0:
		body.add_child(Ui.meta("SEU MELHOR TEMPO  %d:%05.2f" % [floori(float(best) / 60000.0), fmod(float(best) / 1000.0, 60.0)], Ui.ACID))
	var fee := int(event.get("entry", 0))
	if fee > 0:
		body.add_child(Ui.paragraph("Taxa de inscrição: %s." % Ui.money(fee), 17))
	var status: Dictionary = _state.event_status(id)
	if not status.get("ok", false):
		body.add_child(Ui.paragraph(str(status.get("message", "Prova indisponível.")), 18, Ui.GOLD))
		return
	if not street:
		var join := Ui.button("Inscrever e correr   ›", true)
		join.pressed.connect(func() -> void: _request_race(id, "", 0, false))
		body.add_child(join)
		return

	var rivals: Array = _state.street_rivals(id)
	if rivals.is_empty():
		body.add_child(Ui.paragraph("Nenhum piloto aceitou um desafio nas condições atuais."))
	for rival in rivals:
		var card := Ui.panel(Ui.PANEL, Ui.EDGE, 12, 9)
		var row := Ui.row(10)
		card.add_child(row)
		var who := Ui.column(2)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_child(Ui.label(str(rival.get("name", "")), 19, Ui.PAPER, Ui.DISPLAY))
		who.add_child(Ui.paragraph(str(rival.get("car_name", "")), 15))
		row.add_child(who)
		var choose := Ui.button("Propor duelo   ›", false, 40)
		choose.pressed.connect(func() -> void: _open_wager(event, rival))
		row.add_child(choose)
		body.add_child(card)


func _open_wager(event: Dictionary, rival: Dictionary) -> void:
	var event_id := str(event.get("id", ""))
	var npc_id := str(rival.get("id", ""))
	var car: Dictionary = _state.active_car()
	var spec: Dictionary = Catalog.effective(car)
	var your_car := str(spec.get("name", "carro ativo"))
	var rival_car := str(rival.get("car_name", "carro do adversário"))
	var body := _open_dialog("Duelo com %s" % str(rival.get("name", "piloto")), str(event.get("name", "")).to_upper())
	body.add_child(Ui.paragraph(str(rival.get("bio", "")), 17))
	var opponents := GridContainer.new()
	opponents.columns = 2
	body.add_child(opponents)
	_metric_pair(opponents, "SEU CARRO", your_car)
	_metric_pair(opponents, "CARRO ADVERSÁRIO", rival_car)

	var money_wager := CheckButton.new()
	money_wager.text = "Apostar dinheiro do jogo"
	money_wager.button_pressed = true
	money_wager.custom_minimum_size.y = 42
	body.add_child(money_wager)
	var pink := CheckButton.new()
	pink.text = "Apostar os carros (Pink Slip)"
	pink.disabled = not bool(rival.get("pink", false))
	pink.custom_minimum_size.y = 42
	body.add_child(pink)
	if pink.disabled and not str(rival.get("pink_reason", "")).is_empty():
		body.add_child(Ui.paragraph(str(rival.get("pink_reason")), 15, Ui.GOLD))
	var group := ButtonGroup.new()
	money_wager.button_group = group
	pink.button_group = group

	var low := int(rival.get("min_wager", 0))
	var high := int(rival.get("max_wager", 0))
	var amount_row := Ui.row(12)
	var amount := _amount(low, maxi(low, high), clampi(int(rival.get("suggestion", low)), low, maxi(low, high)), 50)
	amount_row.add_child(Ui.label("Valor da aposta", 17))
	amount_row.add_child(Ui.stretch())
	amount_row.add_child(amount)
	body.add_child(amount_row)
	var terms := Ui.paragraph("", 17, Ui.GOLD)
	body.add_child(terms)
	var confirm := Ui.button("Confirmar e correr   ›", true)
	body.add_child(confirm)

	var update := func() -> void:
		amount_row.visible = not pink.button_pressed
		if pink.button_pressed:
			terms.text = "Vitória: você ganha %s. Derrota ou abandono: você perde %s." % [rival_car, your_car]
			confirm.disabled = false
		else:
			terms.text = "Vitória: você ganha %s e recupera a sua aposta. Derrota ou abandono: você perde %s." % [Ui.money(int(amount.value)), Ui.money(int(amount.value))]
			confirm.disabled = high < low or int(_state.money) < int(amount.value)
	money_wager.toggled.connect(func(_pressed: bool) -> void: update.call())
	pink.toggled.connect(func(_pressed: bool) -> void: update.call())
	amount.value_changed.connect(func(_value: float) -> void: update.call())
	update.call()
	confirm.pressed.connect(func() -> void:
		_request_race(event_id, npc_id, 0 if pink.button_pressed else int(amount.value), pink.button_pressed)
	)


func _request_race(id: String, npc_id: String, wager: int, pink: bool) -> void:
	_close_modal()
	ui_cue.emit("confirm")
	race_requested.emit(id, npc_id, wager, pink)


func _amount(low: int, high: int, starting: int, step_size: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step_size
	spin.value = starting
	spin.prefix = "Cr "
	spin.custom_minimum_size = Vector2(174, 43)
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spin.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	return spin


class CourseMap extends Control:
	var outline: PackedVector2Array
	var tint := Ui.ACID

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var background := Rect2(Vector2.ZERO, size)
		draw_rect(background, Ui.SHELL)
		for x in range(12, int(size.x), 12):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Ui.EDGE.darkened(0.39), 1.0)
		for y in range(12, int(size.y), 12):
			draw_line(Vector2(0, y), Vector2(size.x, y), Ui.EDGE.darkened(0.39), 1.0)
		if outline.size() < 2:
			return
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for point in outline:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		var span := maximum - minimum
		var rotated := span.x < span.y
		if rotated:
			span = Vector2(span.y, span.x)
		var scale := minf((size.x * 0.72) / maxf(0.02, span.x), (size.y - 13.0) / maxf(0.02, span.y))
		var center := (size - span * scale) * 0.5
		var points := PackedVector2Array()
		for raw in outline:
			var point := raw - minimum
			var display := Vector2(span.x - point.y, point.x) if rotated else point
			points.append(display * scale + center)
		draw_polyline(points, tint.darkened(0.65), 6.0, true)
		draw_polyline(points, tint, 2.0, true)
		draw_circle(points[0], 3.0, Ui.PAPER, true, -1, true)


func _build_market() -> void:
	_heading("Comércio", "Compare os anúncios e escolha a proposta que cabe no seu caixa.", "MERCADO AUTOMOTIVO")
	var tabs := Ui.row(8)
	_deck.add_child(tabs)
	for tab in [["dealer", "Revenda"], ["private", "Particulares"], ["sell", "Vender da garagem"]]:
		var id: String = tab[0]
		var button := Ui.button(tab[1], _market_filter == id, 42)
		button.pressed.connect(func() -> void:
			if _market_filter != id:
				_market_filter = id
				_scroll.scroll_vertical = 0
				ui_cue.emit("select")
				refresh()
		)
		tabs.add_child(button)
	var listing := _grid()
	if _market_filter == "sell":
		for car: Dictionary in _state.cars:
			_sale_card(listing, car)
		return
	for offer: Dictionary in _state.market_list():
		if offer.get("source") == _market_filter:
			_offer_card(listing, offer)
	if listing.get_child_count() == 0:
		_deck.add_child(Ui.paragraph("Sem anúncios neste setor por enquanto. Novas ofertas surgem conforme você corre e negocia."))


func _offer_card(listing: Control, offer: Dictionary) -> void:
	var spec := Catalog.vehicle(str(offer.get("model", "")))
	var seller := Catalog.npc(str(offer.get("npc_id", "")))
	var price := int(offer.get("asking", 0))
	var reference := int(offer.get("value", 0))
	var card := _vehicle_card(listing, spec, str(offer.get("color", "")), price)
	var vendor := "Revenda do Cais" if seller.is_empty() else str(seller.get("name", "Particular"))
	card.add_child(Ui.paragraph("Anunciante: %s" % vendor, 16))
	if price < reference:
		card.add_child(Ui.meta("%d%% ABAIXO DA REFERÊNCIA" % roundi(float(reference - price) * 100.0 / maxf(1.0, float(reference))), Ui.ACID, 10))
	card.add_child(Ui.stretch(true))
	var view := Ui.button("Ver anúncio   ›", false, 42)
	view.pressed.connect(func() -> void: _open_offer(offer))
	card.add_child(view)


func _sale_card(listing: Control, car: Dictionary) -> void:
	var quote: Dictionary = _state.sell_quote(str(car.get("uid", "")))
	var spec := Catalog.effective(car)
	var card := _vehicle_card(listing, spec, str(car.get("color", "")), int(quote.get("asking", 0)))
	if bool(quote.get("ok", false)):
		card.add_child(Ui.paragraph("Interessado: %s" % str(quote.get("buyer", "")), 16))
	else:
		card.add_child(Ui.paragraph(str(quote.get("message", "")), 16, Ui.GOLD))
	card.add_child(Ui.stretch(true))
	var sell := Ui.button("Negociar venda   ›", false, 42)
	sell.disabled = not bool(quote.get("ok", false))
	sell.pressed.connect(func() -> void: _open_sale(car))
	card.add_child(sell)


func _vehicle_card(listing: Control, spec: Dictionary, paint_hex: String, price: int) -> VBoxContainer:
	var panel := Ui.panel(Ui.PANEL, Ui.EDGE, 14, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.add_child(panel)
	var body := Ui.column(7)
	panel.add_child(body)
	var top := Ui.row(9)
	var ink := Color.from_string(paint_hex, Ui.ACID)
	top.add_child(Ui.glyph("car", 26, ink.lightened(0.33)))
	top.add_child(Ui.meta(str(spec.get("category", "")).to_upper(), Ui.MUTE, 11))
	top.add_child(Ui.stretch())
	body.add_child(top)
	var vehicle_name := Ui.paragraph(str(spec.get("name", "Veículo")), 26, Ui.PAPER)
	vehicle_name.add_theme_font_override("font", Ui.DISPLAY)
	body.add_child(vehicle_name)
	body.add_child(Ui.meta("%d CV  •  %s  •  %s" % [int(spec.get("power", 0)), str(spec.get("drive", "")), str(spec.get("rarity", "")).to_upper()], Ui.MUTE, 11))
	body.add_child(Ui.line())
	if price > 0:
		body.add_child(Ui.label(Ui.money(price), 23, Ui.ACID, Ui.DISPLAY))
	return body


func _open_offer(offer: Dictionary) -> void:
	var spec := Catalog.vehicle(str(offer.get("model", "")))
	var private := str(offer.get("source", "")) == "private"
	var seller := Catalog.npc(str(offer.get("npc_id", "")))
	var offer_id := str(offer.get("id", ""))
	var asking := int(offer.get("asking", 0))
	var body := _open_dialog(str(spec.get("name", "Anúncio")), "PROPOSTA PARTICULAR" if private else "REVENDA DO CAIS")
	body.add_child(Ui.paragraph(str(spec.get("description", "")), 17))
	if not seller.is_empty():
		body.add_child(Ui.paragraph("%s · %s" % [str(seller.get("name", "")), str(seller.get("bio", ""))], 15))
	var comparables := GridContainer.new()
	comparables.columns = 3
	body.add_child(comparables)
	_metric_pair(comparables, "ANUNCIADO", Ui.money(asking))
	_metric_pair(comparables, "VALOR DE MERCADO", Ui.money(int(offer.get("value", 0))))
	_metric_pair(comparables, "POTÊNCIA", "%d cv" % int(spec.get("power", 0)))
	body.add_child(Ui.line())

	var offer_value := _amount(10, maxi(10, asking), asking, 10)
	if private:
		_form_row(body, "Sua proposta", offer_value)
	else:
		offer_value.hide()
		body.add_child(offer_value)
	var trade := OptionButton.new()
	trade.custom_minimum_size = Vector2(202, 43)
	trade.add_item("Sem carro na troca")
	trade.set_item_metadata(0, "")
	if private and bool(offer.get("trade_allowed", false)):
		for car: Dictionary in _state.cars:
			if bool(car.get("loaner", false)):
				continue
			var car_spec := Catalog.effective(car)
			trade.add_item("%s · %s" % [str(car_spec.get("name", "")), Ui.money(Catalog.car_value(car))])
			trade.set_item_metadata(trade.item_count - 1, str(car.get("uid", "")))
		_form_row(body, "Veículo na troca", trade)
	else:
		trade.hide()
		body.add_child(trade)
	trade.select(0)

	var summary := Ui.paragraph("", 17, Ui.PAPER)
	body.add_child(summary)
	var buy := Ui.button("Confirmar compra   ›", true)
	body.add_child(buy)
	var check_offer := func() -> void:
		var trade_uid := str(trade.get_item_metadata(trade.selected))
		var quote: Dictionary = _state.market_quote(offer_id, int(offer_value.value), trade_uid)
		buy.disabled = not bool(quote.get("ok", false))
		buy.text = "Confirmar troca   ›" if not trade_uid.is_empty() else "Confirmar compra   ›"
		if buy.disabled:
			summary.text = str(quote.get("message", "Proposta recusada."))
			summary.add_theme_color_override("font_color", Ui.GOLD)
		else:
			var net := int(quote.get("net", asking))
			var verb := "Você recebe" if net < 0 else "Você paga"
			summary.text = "%s %s." % [verb, Ui.money(absi(net))]
			if not trade_uid.is_empty():
				summary.text += " Seu carro entra por %s." % Ui.money(int(quote.get("trade_value", 0)))
			summary.add_theme_color_override("font_color", Ui.ACID)
	trade.item_selected.connect(func(_index: int) -> void: check_offer.call())
	offer_value.value_changed.connect(func(_value: float) -> void: check_offer.call())
	buy.pressed.connect(func() -> void:
		_apply(_state.purchase(offer_id, int(offer_value.value), str(trade.get_item_metadata(trade.selected))))
	)
	check_offer.call()


func _open_sale(car: Dictionary) -> void:
	var uid := str(car.get("uid", ""))
	var spec := Catalog.effective(car)
	var quote: Dictionary = _state.sell_quote(uid)
	if not bool(quote.get("ok", false)):
		show_notice(str(quote.get("message", "")))
		return
	var body := _open_dialog("Vender %s" % str(spec.get("name", "")), "NEGOCIAÇÃO DE VENDA")
	var stats := GridContainer.new()
	stats.columns = 2
	body.add_child(stats)
	_metric_pair(stats, "INTERESSADO", str(quote.get("buyer", "")))
	_metric_pair(stats, "OFERTA INICIAL", Ui.money(int(quote.get("asking", 0))))
	body.add_child(Ui.paragraph("O valor de referência do seu carro é %s." % Ui.money(int(quote.get("value", 0)))))
	var price := _amount(10, int(quote.get("value", 10)) * 2, int(quote.get("asking", 10)), 10)
	_form_row(body, "Preço pedido", price)
	var status := Ui.paragraph("", 17, Ui.GOLD)
	body.add_child(status)
	var confirm := Ui.button("Confirmar venda   ›", true)
	body.add_child(confirm)
	var update := func() -> void:
		var current: Dictionary = _state.sell_quote(uid, int(price.value))
		confirm.disabled = not bool(current.get("ok", false))
		status.text = str(current.get("message", ""))
		status.add_theme_color_override("font_color", Ui.GOLD if confirm.disabled else Ui.ACID)
	price.value_changed.connect(func(_value: float) -> void: update.call())
	update.call()
	confirm.pressed.connect(func() -> void: _apply(_state.sell(uid, int(price.value))))


func _open_tuning() -> void:
	var car: Dictionary = _state.active_car()
	var spec := Catalog.effective(car)
	var body := _open_dialog("Oficina", str(spec.get("name", "")).to_upper(), 435)
	var levels: Dictionary = car.get("upgrades", {})
	for key: String in Catalog.UPGRADES:
		var part: Dictionary = Catalog.UPGRADES[key]
		var level := int(levels.get(key, 0))
		var quote: Dictionary = _state.upgrade_quote(key)
		var panel := Ui.panel(Ui.PANEL, Ui.EDGE, 12, 8)
		body.add_child(panel)
		var row := Ui.row(12)
		panel.add_child(row)
		var info := Ui.column(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(Ui.label(str(part.get("name", "")), 19, Ui.PAPER, Ui.DISPLAY))
		info.add_child(Ui.paragraph(str(part.get("description", "")), 15))
		info.add_child(Ui.meta("NÍVEL %d / %d" % [level, Catalog.MAX_UPGRADE_LEVEL], Ui.ACID, 10))
		row.add_child(info)
		var cost := int(quote.get("cost", 0))
		var view := Ui.button("Preparar   ›" if cost > 0 else "Nível máximo", false, 41)
		view.disabled = cost == 0
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		view.pressed.connect(func() -> void: _open_part(key))
		row.add_child(view)


func _open_part(key: String) -> void:
	var car: Dictionary = _state.active_car()
	var current := Catalog.effective(car)
	var part: Dictionary = Catalog.UPGRADES[key]
	var quote: Dictionary = _state.upgrade_quote(key)
	var body := _open_dialog(str(part.get("name", "")), "PREPARAÇÃO MECÂNICA")
	body.add_child(Ui.paragraph(str(part.get("description", "")), 18))
	var current_level := int(quote.get("level", 0))
	var price := int(quote.get("cost", 0))
	var next: Dictionary = quote.get("spec", {})
	if not next.is_empty():
		var table := GridContainer.new()
		table.columns = 3
		table.add_theme_constant_override("h_separation", 17)
		table.add_child(Ui.meta("CARACTERÍSTICA", Ui.MUTE))
		table.add_child(Ui.meta("ATUAL", Ui.MUTE))
		table.add_child(Ui.meta("APÓS INSTALAÇÃO", Ui.ACID))
		for metric in [
			["power", "Potência", "%d cv"], ["torque", "Torque", "%d Nm"],
			["weight", "Peso", "%d kg"], ["acceleration", "0–100 km/h", "%.1f s"],
			["top_speed", "Velocidade final", "%d km/h"], ["grip", "Aderência", "%.2f"],
			["braking", "Força dos freios", "%.2f"], ["handling", "Agilidade", "%.2f"],
		]:
			if not is_equal_approx(float(current.get(metric[0], 0)), float(next.get(metric[0], 0))):
				table.add_child(Ui.label(metric[1], 16))
				table.add_child(Ui.label(metric[2] % current.get(metric[0], 0), 16))
				table.add_child(Ui.label(metric[2] % next.get(metric[0], 0), 16, Ui.ACID))
		body.add_child(table)
		body.add_child(Ui.line())
	var back := Ui.button("Voltar às peças", false, 40)
	back.pressed.connect(_open_tuning)
	var actions := Ui.row(9)
	actions.add_child(back)
	actions.add_child(Ui.stretch())
	var install := Ui.button("Instalar nível %d · %s" % [current_level + 1, Ui.money(price)], true)
	install.disabled = not bool(quote.get("ok", false))
	install.pressed.connect(func() -> void:
		var result: Dictionary = _state.upgrade(key)
		_apply(result, false)
		if result.get("ok", false):
			_open_tuning()
	)
	actions.add_child(install)
	body.add_child(actions)
	if install.disabled:
		body.add_child(Ui.paragraph(str(quote.get("message", "")), 16, Ui.GOLD))


func _open_paint() -> void:
	var car: Dictionary = _state.active_car()
	var spec := Catalog.effective(car)
	var body := _open_dialog("Pintura", str(spec.get("name", "")).to_upper())
	var width := Ui.row(9)
	body.add_child(width)
	var stage := _showcase(width, spec, "garage", 167)
	var preview = stage.get_child(0)
	var colors := GridContainer.new()
	colors.columns = 2
	colors.add_theme_constant_override("h_separation", 8)
	colors.add_theme_constant_override("v_separation", 8)
	body.add_child(colors)
	var current := str(car.get("color", "")).to_upper()
	var selected := [current]
	var price := int(_state.PAINT_PRICE)
	var confirm := Ui.button("Aplicar pintura · %s" % Ui.money(price), true)
	confirm.disabled = true
	var palette := ButtonGroup.new()
	for name: String in Catalog.COLORS:
		var hex_code: String = Catalog.COLORS[name]
		var button := Ui.button(name, false, 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_stylebox_override("normal", Ui.box(Color(hex_code).darkened(0.68), Color(hex_code), 1, 4, 12, 4))
		button.add_theme_stylebox_override("pressed", Ui.box(Color(hex_code).darkened(0.54), Ui.PAPER, 2, 4, 12, 4))
		button.toggle_mode = true
		button.button_group = palette
		button.button_pressed = hex_code == current
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			selected[0] = hex_code
			if is_instance_valid(preview):
				var demo := spec.duplicate()
				demo["color"] = hex_code
				preview.set_vehicle(demo)
			confirm.disabled = hex_code == current or int(_state.money) < price
		)
		colors.add_child(button)
	body.add_child(confirm)
	confirm.pressed.connect(func() -> void: _apply(_state.paint(str(selected[0]))))
	if int(_state.money) < price:
		body.add_child(Ui.paragraph("Saldo insuficiente para aplicar a cor.", 16, Ui.GOLD))


func _build_goals() -> void:
	_heading("Desafios", "Metas opcionais para acompanhar a sua trajetória.", "SEU PROGRESSO")
	var listing := _grid()
	for goal: Dictionary in _state.goals():
		var complete := bool(goal.get("done", false))
		var card := Ui.panel(Ui.PANEL, Ui.ACID if complete else Ui.EDGE, 14, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		listing.add_child(card)
		var body := Ui.column(8)
		card.add_child(body)
		var label := Ui.paragraph(str(goal.get("title", "")), 22, Ui.PAPER)
		label.add_theme_font_override("font", Ui.DISPLAY)
		body.add_child(label)
		body.add_child(Ui.paragraph(str(goal.get("description", "")), 15))
		body.add_child(Ui.stretch(true))
		var target := maxi(1, int(goal.get("target", 1)))
		var progress := mini(target, int(goal.get("progress", 0)))
		var bar := ProgressBar.new()
		bar.max_value = target
		bar.value = progress
		bar.show_percentage = false
		bar.custom_minimum_size.y = 5
		bar.add_theme_stylebox_override("background", Ui.box(Ui.EDGE, Color.TRANSPARENT, 0, 2))
		bar.add_theme_stylebox_override("fill", Ui.box(Ui.ACID, Color.TRANSPARENT, 0, 2))
		body.add_child(bar)
		body.add_child(Ui.meta("CONCLUÍDO" if complete else "%d / %d" % [progress, target], Ui.ACID if complete else Ui.MUTE, 11))


func _open_settings() -> void:
	var body := _open_dialog("Configurações", "EXPERIÊNCIA DE JOGO", 425)
	body.add_child(Ui.label("Controles", 22, Ui.PAPER, Ui.DISPLAY))
	_settings_slider(body, "Sensibilidade da direção", "sensitivity", 0.55, 1.55)
	_settings_toggle(body, "Assistências de condução", "assists")
	body.add_child(Ui.line())
	body.add_child(Ui.label("Desempenho", 22, Ui.PAPER, Ui.DISPLAY))
	_settings_picker(body, "Qualidade", "quality", [["Automática", "auto"], ["Baixa", "low"], ["Alta", "high"]])
	_settings_picker(body, "Limite de quadros", "fps", [["30 FPS", 30], ["60 FPS", 60]])
	body.add_child(Ui.line())
	body.add_child(Ui.label("Áudio", 22, Ui.PAPER, Ui.DISPLAY))
	_settings_toggle(body, "Som ligado", "sound")
	_settings_slider(body, "Volume geral", "master_volume", 0.0, 1.0)
	_settings_slider(body, "Música", "music_volume", 0.0, 1.0)
	_settings_slider(body, "Efeitos", "effects_volume", 0.0, 1.0)


func _settings_toggle(body: Control, title: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.custom_minimum_size.y = 42
	toggle.button_pressed = bool(_state.settings.get(key, true))
	toggle.toggled.connect(func(enabled: bool) -> void: _change_setting(key, enabled))
	body.add_child(toggle)


func _settings_picker(body: Control, title: String, key: String, choices: Array) -> void:
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(178, 43)
	for option in choices:
		select.add_item(str(option[0]))
		var index := select.item_count - 1
		select.set_item_metadata(index, option[1])
		if _state.settings.get(key, null) == option[1]:
			select.select(index)
	select.item_selected.connect(func(index: int) -> void: _change_setting(key, select.get_item_metadata(index)))
	_form_row(body, title, select)


func _settings_slider(body: Control, title: String, key: String, low: float, high: float) -> void:
	var item := Ui.row(10)
	var value := Ui.meta("", Ui.ACID, 12)
	value.custom_minimum_size.x = 47
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.add_child(value)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.025
	slider.value = float(_state.settings.get(key, 1.0))
	slider.custom_minimum_size = Vector2(132, 41)
	item.add_child(slider)
	value.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(level: float) -> void: value.text = "%d%%" % roundi(level * 100.0))
	var save := func() -> void:
		if not is_equal_approx(float(_state.settings.get(key, 1.0)), slider.value):
			_change_setting(key, slider.value)
	slider.drag_ended.connect(func(_changed: bool) -> void: save.call())
	slider.focus_exited.connect(save)
	_form_row(body, title, item)


func _change_setting(key: String, value: Variant) -> void:
	var response: Dictionary = _state.set_setting(key, value)
	var success := bool(response.get("ok", false))
	ui_cue.emit("select" if success else "error")
	if not success:
		show_notice(str(response.get("message", "Configuração indisponível.")))


func _form_row(body: Control, title: String, input: Control) -> void:
	var row := Ui.row(10)
	var label := Ui.label(title, 17)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	row.add_child(Ui.stretch())
	row.add_child(input)
	body.add_child(row)


func _open_dialog(title: String, kicker: String, height: int = 382) -> VBoxContainer:
	_close_modal()
	ui_cue.emit("select")
	_return_focus = get_viewport().gui_get_focus_owner()
	_shell.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_modal = Control.new()
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.z_index = 5
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.055, 0.82)
	_modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Ui.panel(Ui.SHELL, Ui.ACID, 19, 15)
	frame.custom_minimum_size.x = minf(620.0, size.x - 40.0)
	center.add_child(frame)
	var modal_column := Ui.column(12)
	frame.add_child(modal_column)
	var masthead := Ui.row(12)
	modal_column.add_child(masthead)
	var words := Ui.column(1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(Ui.meta(kicker, Ui.ACID, 11))
	var heading := Ui.paragraph(title, 31, Ui.PAPER)
	heading.add_theme_font_override("font", Ui.DISPLAY)
	words.add_child(heading)
	masthead.add_child(words)
	var close := _icon_button("close", "Fechar")
	close.custom_minimum_size = Vector2(44, 44)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_modal)
	masthead.add_child(close)
	close.grab_focus()
	modal_column.add_child(Ui.line())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(float(height), maxf(180.0, size.y - 166.0))
	scroll.follow_focus = true
	modal_column.add_child(scroll)
	var border := Ui.margin(0, 0, 9, 6)
	border.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(border)
	var content := Ui.column(10)
	border.add_child(content)
	return content


func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.hide()
		_modal.queue_free()
		_modal = null
		_shell.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
			_return_focus.grab_focus()
		_return_focus = null


func _apply(result: Dictionary, close_modal: bool = true) -> void:
	var ok := bool(result.get("ok", false))
	if ok:
		if close_modal:
			_close_modal()
		refresh()
	ui_cue.emit("confirm" if ok else "error")
	show_notice(str(result.get("message", "")))
