extends Control
## Local conversations and transactions that open at an object in the world.

signal race_requested(event_id: String, npc_id: String, wager: int, pink: bool)
signal travel_requested(sector: String)
signal practice_requested(track: String)
signal preview_paint(uid: String, color: String)
signal modal_changed(open: bool)
signal ui_cue(cue: String)

const Ui = preload("res://src/ui/ui_kit.gd")
const Catalog = preload("res://src/domain/catalog.gd")
const Track = preload("res://src/tracks/track.gd")
const Routes = preload("res://src/tracks/route_data.gd")
const EVENT_MODES := {
	"circuit": "Circuito", "sprint": "Sprint", "time_trial": "Contrarrelógio", "drag": "Arrancada",
}
const PRACTICE_TRACKS := ["autodromo", "docas", "serra"]

@onready var _state := get_node("/root/GameState")
var _modal: Control
var _return_focus: Control
var _toast: PanelContainer
var _toast_tween: Tween
var _paint_preview_uid := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Ui.skin()


func is_open() -> bool:
	return is_instance_valid(_modal)


func show_notice(message: String) -> void:
	if message.is_empty():
		return
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	if is_instance_valid(_toast):
		_toast.queue_free()
	_toast = Ui.panel(Ui.SHELL, Ui.ACID, 16, 10)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.z_index = 9
	_toast.add_child(Ui.paragraph(message, 17, Ui.PAPER))
	add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast.offset_left = -383
	_toast.offset_right = -26
	_toast.offset_top = 103
	_toast.offset_bottom = 163
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.13)
	_toast_tween.tween_interval(3.1)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.23)
	_toast_tween.finished.connect(_toast.queue_free)


func destinations(current: String) -> void:
	var body := _open_dialog("Para onde?", "SAÍDA · BAÍA DO SAL", 330)
	for key: String in Catalog.SECTORS:
		if key == current:
			continue
		var section: Dictionary = Catalog.SECTORS[key]
		_choice(body, str(section.name), str(section.purpose), "Viajar", func() -> void:
			close_dialog()
			travel_requested.emit(key)
		)


func vehicle(uid: String, in_garage: bool) -> void:
	var car: Dictionary = _state.owned_car(uid)
	if car.is_empty():
		return
	var spec := Catalog.effective(car)
	var active := str(_state.active_uid) == uid
	var loaner := bool(car.get("loaner", false))
	var subtitle := "CARRO DE APOIO" if loaner else ("%s · %s" % [str(spec.category).to_upper(), str(spec.drive)])
	var body := _open_dialog(str(spec.name), subtitle, 332)
	body.add_child(Ui.paragraph(str(spec.description), 17))
	var props := GridContainer.new()
	props.columns = 3
	props.add_theme_constant_override("h_separation", 14)
	body.add_child(props)
	_metric_pair(props, "POTÊNCIA", "%d cv" % int(spec.power))
	_metric_pair(props, "VELOCIDADE FINAL", "%d km/h" % int(spec.top_speed))
	_metric_pair(props, "ÍNDICE", str(spec.rating))
	body.add_child(Ui.line())
	if active:
		body.add_child(Ui.meta("CARRO ATIVO", Ui.ACID, 13))
	elif in_garage:
		var select := Ui.button("Usar este carro", true)
		select.pressed.connect(func() -> void: _apply(_state.select_car(uid)))
		body.add_child(select)
	if loaner:
		body.add_child(Ui.paragraph("O carro de apoio está disponível nas competições oficiais.", 16, Ui.GOLD))
	elif in_garage:
		var action_row := Ui.row(10)
		body.add_child(action_row)
		var prep := Ui.button("Preparar este carro")
		var coat := Ui.button("Pintar este carro")
		for action: Button in [prep, coat]:
			action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_row.add_child(action)
		prep.pressed.connect(func() -> void: tuning(uid))
		coat.pressed.connect(func() -> void: painting(uid))


func rival(npc_id: String) -> void:
	var who := Catalog.npc(npc_id)
	var car: Dictionary = _state.rival_garage().get(npc_id, {})
	var body := _open_dialog(str(who.name), str(who.role).to_upper(), 360)
	body.add_child(Ui.paragraph(str(who.bio), 19, Ui.PAPER))
	body.add_child(Ui.meta("NO PORTO COM %s" % str(car.get("name", "seu carro")).to_upper(), Ui.GOLD, 12))
	body.add_child(Ui.line())
	var events_found := 0
	for event in Catalog.events():
		if not bool(event.get("underground", false)):
			continue
		for opponent: Dictionary in _state.street_rivals(str(event.id)):
			if opponent.id != npc_id:
				continue
			var status: Dictionary = _state.event_status(str(event.id))
			var detail := "%s · %s" % [_track_name(event), _mode_name(event)] if status.ok else str(status.message)
			var challenge := _choice(body, str(event.name), detail, "Propor duelo", func() -> void: _open_wager(event, opponent))
			challenge.disabled = not bool(status.ok)
			events_found += 1
	if events_found == 0:
		body.add_child(Ui.paragraph("Por enquanto, este piloto está apenas no encontro.", 17))


func selling() -> void:
	var body := _open_dialog("Balcão de avaliação", "REVENDA DO CAIS", 385)
	for car: Dictionary in _state.cars:
		var quote: Dictionary = _state.sell_quote(str(car.uid))
		var spec := Catalog.effective(car)
		var summary := "%s oferece %s" % [str(quote.get("buyer", "")), Ui.money(int(quote.get("asking", 0)))] if quote.ok else str(quote.message)
		var sell := _choice(body, str(spec.name), summary, "Negociar", func() -> void: _open_sale(car))
		sell.disabled = not bool(quote.ok)


func painting(uid: String = "") -> void:
	var car: Dictionary = _state.active_car() if uid.is_empty() else _state.owned_car(uid)
	if not _can_customize(car):
		return
	var spec := Catalog.effective(car)
	var body := _open_dialog("Pintura", str(spec.name).to_upper(), 353)
	body.add_child(Ui.paragraph("A prévia aparece na carroceria do seu carro estacionado.", 17))
	_paint_preview_uid = str(car.uid)
	var palette := ButtonGroup.new()
	var selected := [str(car.color).to_upper()]
	var owned_uid := str(car.uid)
	var colors := GridContainer.new()
	colors.columns = 2
	colors.add_theme_constant_override("h_separation", 8)
	colors.add_theme_constant_override("v_separation", 7)
	body.add_child(colors)
	var price := int(_state.PAINT_PRICE)
	var confirm := Ui.button("Aplicar pintura · %s" % Ui.money(price), true)
	confirm.disabled = true
	for name: String in Catalog.COLORS:
		var swatch: String = Catalog.COLORS[name]
		var tint := Color(swatch)
		var button := Ui.button(name, false, 39)
		button.add_theme_stylebox_override("normal", Ui.box(tint.darkened(0.70), tint, 1, 4, 12, 4))
		button.add_theme_stylebox_override("pressed", Ui.box(tint.darkened(0.52), Ui.PAPER, 2, 4, 12, 4))
		button.toggle_mode = true
		button.button_group = palette
		button.button_pressed = swatch == selected[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			selected[0] = swatch
			preview_paint.emit(owned_uid, swatch)
			confirm.disabled = swatch == str(car.color).to_upper() or int(_state.money) < price
		)
		colors.add_child(button)
	body.add_child(confirm)
	confirm.pressed.connect(func() -> void: _apply(_state.paint(str(selected[0]), owned_uid)))


func goals() -> void:
	var body := _open_dialog("Quadro de metas", "OFICINA RIBEIRA", 425)
	for goal: Dictionary in _state.goals():
		var target := maxi(1, int(goal.target))
		var progress := mini(target, int(goal.progress))
		var panel := Ui.panel()
		var stack := Ui.column(5)
		body.add_child(panel)
		panel.add_child(stack)
		stack.add_child(Ui.label(str(goal.title), 19, Ui.PAPER, Ui.DISPLAY))
		stack.add_child(Ui.paragraph(str(goal.description), 16))
		var bar := ProgressBar.new()
		bar.max_value = target
		bar.value = progress
		bar.show_percentage = false
		bar.custom_minimum_size.y = 5
		bar.add_theme_stylebox_override("background", Ui.box(Ui.EDGE))
		bar.add_theme_stylebox_override("fill", Ui.box(Ui.ACID))
		stack.add_child(bar)
		stack.add_child(Ui.meta("CONCLUÍDA" if goal.done else "%d / %d" % [progress, target], Ui.ACID if goal.done else Ui.MUTE))


func practice() -> void:
	var body := _open_dialog("Treino livre", "PADDOCK CANDEIA", 314)
	body.add_child(Ui.paragraph("Use seu carro ativo para explorar a pista sem classificação, apostas ou premiação.", 17))
	for track_id: String in PRACTICE_TRACKS:
		var route := Routes.get_route(track_id)
		var course_type := "Circuito" if route.practice_mode == "circuit" else "Percurso aberto"
		_choice(body, str(route.name), course_type, "Treinar", func() -> void:
			close_dialog()
			practice_requested.emit(track_id)
		)


func _can_customize(car: Dictionary) -> bool:
	if not car.is_empty() and not bool(car.get("loaner", false)):
		return true
	show_notice("A oficina trabalha com os seus carros próprios.")
	return false


func _choice(body: Control, title: String, description: String, action: String, callback: Callable) -> Button:
	var card := Ui.panel(Ui.PANEL, Ui.EDGE, 12, 9)
	body.add_child(card)
	var row := Ui.row(10)
	card.add_child(row)
	var text := Ui.column(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var heading := Ui.paragraph(title, 20, Ui.PAPER)
	heading.add_theme_font_override("font", Ui.DISPLAY)
	text.add_child(heading)
	text.add_child(Ui.paragraph(description, 15))
	var go := Ui.button(action, false, 42)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(callback)
	row.add_child(go)
	return go


func _open_dialog(title: String, context: String, height: int = 382) -> VBoxContainer:
	close_dialog(false)
	_return_focus = get_viewport().gui_get_focus_owner()
	_modal = Control.new()
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.026, 0.042, 0.057, 0.41)
	_modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border := Ui.margin(26, 26, 26, 26)
	_modal.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var align := Ui.row(0)
	border.add_child(align)
	align.add_child(Ui.stretch())
	var frame := Ui.panel(Ui.SHELL, Ui.EDGE, 18, 15)
	frame.custom_minimum_size.x = minf(556.0, size.x - 52.0)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	align.add_child(frame)
	var sheet := Ui.column(12)
	frame.add_child(sheet)
	var heading := Ui.row(14)
	sheet.add_child(heading)
	var words := Ui.column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(words)
	words.add_child(Ui.meta(context, Ui.ACID, 12))
	var name := Ui.paragraph(title, 32, Ui.PAPER)
	name.add_theme_font_override("font", Ui.DISPLAY)
	words.add_child(name)
	var close := _icon_button("close", "Fechar")
	close.custom_minimum_size = Vector2(48, 43)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_dialog)
	heading.add_child(close)
	close.grab_focus()
	sheet.add_child(Ui.line())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var height_limit := minf(float(height), maxf(180.0, size.y - 184.0))
	scroll.custom_minimum_size.y = minf(160.0, height_limit)
	scroll.follow_focus = true
	sheet.add_child(scroll)
	var pad := Ui.margin(0, 0, 11, 5)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var body := Ui.column(10)
	pad.add_child(body)
	var fit := func() -> void:
		if is_instance_valid(scroll):
			scroll.custom_minimum_size.y = clampf(body.get_combined_minimum_size().y + 6.0, 117.0, height_limit)
	body.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
	fit.call_deferred()
	modal_changed.emit(true)
	ui_cue.emit("select")
	return body


func close_dialog(notify: bool = true) -> bool:
	if not is_open():
		return false
	if not _paint_preview_uid.is_empty():
		var car: Dictionary = _state.owned_car(_paint_preview_uid)
		if not car.is_empty():
			preview_paint.emit(_paint_preview_uid, str(car.color))
		_paint_preview_uid = ""
	_modal.hide()
	_modal.queue_free()
	_modal = null
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	if notify:
		modal_changed.emit(false)
	return true


func event_details(event: Dictionary) -> void:
	var id := str(event.get("id", ""))
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
	_metric_pair(fact_grid, "PRÊMIO", Ui.money(int(event.get("reward", 0))))

	var course := CourseMap.new()
	course.outline = Track.map_preview(str(event.track), str(event.get("course_mode", event.mode)))
	course.custom_minimum_size.y = 85
	body.add_child(course)
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
	var join := Ui.button("Inscrever e correr   ›", true)
	join.pressed.connect(func() -> void: _request_race(id, "", 0, false))
	body.add_child(join)


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


func _metric_pair(parent: Control, title: String, value: String) -> void:
	var stack := Ui.column(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(Ui.meta(title, Ui.MUTE, 10))
	stack.add_child(Ui.label(value, 18, Ui.PAPER, Ui.DISPLAY))
	parent.add_child(stack)


func _mode_name(event: Dictionary) -> String:
	return str(EVENT_MODES.get(str(event.get("mode", "")), "Corrida"))


func _track_name(event: Dictionary) -> String:
	return str(Routes.get_route(str(event.get("track", ""))).get("name", "Pista"))


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
	close_dialog()
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


func offer_details(offer: Dictionary) -> void:
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


func tuning(uid: String = "") -> void:
	var car: Dictionary = _state.active_car() if uid.is_empty() else _state.owned_car(uid)
	if not _can_customize(car):
		return
	var spec := Catalog.effective(car)
	var body := _open_dialog("Oficina", str(spec.get("name", "")).to_upper(), 435)
	var levels: Dictionary = car.get("upgrades", {})
	for key: String in Catalog.UPGRADES:
		var part: Dictionary = Catalog.UPGRADES[key]
		var level := int(levels.get(key, 0))
		var quote: Dictionary = _state.upgrade_quote(key, uid)
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
		view.pressed.connect(func() -> void: _open_part(key, uid))
		row.add_child(view)


func _open_part(key: String, uid: String) -> void:
	var car: Dictionary = _state.active_car() if uid.is_empty() else _state.owned_car(uid)
	var current := Catalog.effective(car)
	var part: Dictionary = Catalog.UPGRADES[key]
	var quote: Dictionary = _state.upgrade_quote(key, uid)
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
	back.pressed.connect(func() -> void: tuning(uid))
	var actions := Ui.row(9)
	actions.add_child(back)
	actions.add_child(Ui.stretch())
	var install := Ui.button("Instalar nível %d · %s" % [current_level + 1, Ui.money(price)], true)
	install.disabled = not bool(quote.get("ok", false))
	install.pressed.connect(func() -> void:
		var result: Dictionary = _state.upgrade(key, uid)
		_apply(result, false)
		if result.get("ok", false):
			tuning(uid)
	)
	actions.add_child(install)
	body.add_child(actions)
	if install.disabled:
		body.add_child(Ui.paragraph(str(quote.get("message", "")), 16, Ui.GOLD))


func settings() -> void:
	var body := _open_dialog("Configurações", "EXPERIÊNCIA DE JOGO", 425)
	body.add_child(Ui.paragraph("Use WASD ou as setas para andar, o botão direito do mouse para girar a câmera e E para interagir. No toque, use o direcional e arraste o lado direito.", 16))
	body.add_child(Ui.line())
	body.add_child(Ui.label("Controles", 22, Ui.PAPER, Ui.DISPLAY))
	_settings_slider(body, "Sensibilidade da câmera a pé", "walk_sensitivity", 0.55, 1.55)
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
	body.add_child(Ui.line())
	var leave := Ui.button("Fechar jogo")
	leave.pressed.connect(func() -> void: get_tree().quit())
	body.add_child(leave)


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


func _apply(result: Dictionary, close_modal: bool = true) -> void:
	var ok := bool(result.get("ok", false))
	if ok:
		if close_modal:
			close_dialog()
	ui_cue.emit("confirm" if ok else "error")
	show_notice(str(result.get("message", "")))


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
