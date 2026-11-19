extends RefCounted

const Catalog = preload("res://src/domain/catalog.gd")

static func listing(reputation: int, epoch: int) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for model: String in Catalog.VEHICLES:
		var spec := Catalog.vehicle(model)
		if reputation >= int(spec.rep):
			var dealer_price := _round_price(float(spec.value) * 1.04)
			offers.append(_offer("dealer:" + model, model, str(spec.color), "dealer", "", dealer_price))

	var private_sellers: Array[Dictionary] = []
	for id: String in Catalog.NPCS:
		var seller := Catalog.npc(id)
		var spec := Catalog.vehicle(str(seller.car))
		if reputation + 2 >= int(spec.rep):
			private_sellers.append(seller)
	for offset in mini(4, private_sellers.size()):
		var index := (epoch + offset) % private_sellers.size()
		var seller := private_sellers[index]
		var model: String = seller.car
		var spec := Catalog.vehicle(model)
		var modifier := float((epoch * 3 + index * 7) % 11) * 0.014
		var price := _round_price(float(spec.value) * (0.87 + modifier))
		var color_names := Catalog.COLORS.values()
		var color := str(color_names[(index + epoch) % color_names.size()])
		offers.append(_offer("private:%s:%d" % [seller.id, epoch], model, color, "private", str(seller.id), price))
	return offers

static func buy_quote(offer: Dictionary, offer_price: int, trade: Dictionary, balance: int) -> Dictionary:
	var spec := Catalog.vehicle(str(offer.model))
	var seller := Catalog.npc(str(offer.npc_id))
	var asking: int = offer.asking
	var price := asking if offer_price < 0 else offer_price
	var lowest_price := asking
	if not seller.is_empty():
		lowest_price = _round_price(float(asking) * (0.94 - float(seller.negotiation) * 0.12))
	var quote := {
		"ok": false, "message": "", "price": price, "asking": asking, "minimum": lowest_price,
		"trade_value": 0, "net": price, "offer": offer,
	}
	if price < lowest_price:
		quote.message = "A loja trabalha com preço fixo." if seller.is_empty() else "%s quer pelo menos Cr %d." % [seller.name, lowest_price]
		return quote
	if price > asking:
		quote.message = "O preço do anúncio é Cr %d." % asking
		return quote

	if not trade.is_empty():
		if seller.is_empty():
			quote.message = "Trocas diretas são feitas com vendedores particulares."
			return quote
		var trade_spec := Catalog.vehicle(str(trade.model))
		var preference_bonus := 0.12 if trade_spec.category_id == seller.preference else 0.0
		var trade_value := _round_price(float(Catalog.car_value(trade)) * (0.72 + float(seller.negotiation) * 0.11 + preference_bonus))
		if trade_value > price + int(seller.budget):
			quote.message = "%s não tem caixa para cobrir essa diferença." % seller.name
			return quote
		quote.trade_value = trade_value
		quote.net = price - trade_value

	if balance < int(quote.net):
		quote.message = "Faltam Cr %d para fechar o acordo." % (int(quote.net) - balance)
		return quote
	quote.ok = true
	quote.message = "Proposta aceita para %s." % spec.name
	return quote

static func sell_quote(car: Dictionary, offer_price: int, epoch: int) -> Dictionary:
	var spec := Catalog.vehicle(str(car.model))
	var value := Catalog.car_value(car)
	var dealer_price := _round_price(float(value) * 0.75)
	var best_price := dealer_price
	var ceiling := dealer_price
	var buyer_name := "Revenda do Cais"
	var rotation := epoch % Catalog.NPCS.size()
	var ids := Catalog.NPCS.keys()
	for offset in 4:
		var buyer := Catalog.npc(str(ids[(rotation + offset) % ids.size()]))
		var preference_bonus := 0.13 if buyer.preference == spec.category_id else 0.0
		var price := mini(int(buyer.budget), _round_price(float(value) * (0.77 + preference_bonus)))
		if price > best_price:
			best_price = price
			ceiling = mini(int(buyer.budget), _round_price(float(price) * (1.03 + float(buyer.negotiation) * 0.06)))
			buyer_name = str(buyer.name)
	var price := best_price if offer_price < 0 else offer_price
	var quote := {"ok": false, "message": "", "price": price, "asking": best_price, "maximum": ceiling, "buyer": buyer_name, "value": value}
	if price > ceiling:
		quote.message = "%s pode pagar até Cr %d." % [buyer_name, ceiling]
		return quote
	if price < 1:
		quote.message = "Digite um preço válido."
		return quote
	quote.ok = true
	quote.message = "%s aceita comprar por Cr %d." % [buyer_name, price]
	return quote

static func _offer(id: String, model: String, color: String, source: String, npc_id: String, asking: int) -> Dictionary:
	var spec := Catalog.vehicle(model)
	return {
		"id": id, "model": model, "color": color, "source": source, "npc_id": npc_id,
		"asking": asking, "value": int(spec.value), "trade_allowed": source == "private",
	}

static func _round_price(value: float) -> int:
	return roundi(value / 10.0) * 10
