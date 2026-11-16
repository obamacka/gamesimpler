## Mail (spec 4.7, P5.5): InboxList -> Reading (illustration first) -> Claim -> InboxList,
## with Archive and Lost and Found. TTS reads the letter when enabled.
extends MenuBase

var reading := ""
var picture: ColorRect
var body: Label


func build() -> void:
	make_list("Mail", Vector2(720, 520))
	refresh()


func refresh() -> void:
	clear_rows()
	var s := GameSession.current
	reading = ""
	if not s.mail.model.lost_and_found.is_empty():
		add_row("Lost and Found (%d)" % s.mail.model.lost_and_found.size(), Color(0.8, 0.7, 0.4), claim_lost_and_found)
	for m in s.mail.model.inbox:
		if m["archived"]:
			continue
		var id: String = m["id"]
		var badge := "" if m["read"] else "[new] "
		var gift := "" if m["claimed"] or m["attachments"].is_empty() else " (gift)"
		add_row(badge + m["subject_key"] + gift, _color(m), func(): open(id))
	if list.get_child_count() == 0:
		say("No letters right now.")


static func _color(m: Dictionary) -> Color:
	var by_kind := {"CARE_PACKAGE": Color(0.95, 0.7, 0.5), "PACKAGE": Color(0.7, 0.55, 0.35), "JOB_OFFER": Color(0.5, 0.65, 0.9),
		"RECEIPT": Color(0.6, 0.85, 0.6), "REWARD": Color(0.95, 0.85, 0.3), "CATALOG_ORDER": Color(0.7, 0.6, 0.9)}
	return by_kind.get(m["kind"], Color(0.9, 0.9, 0.9))


func initial_focus() -> Control:
	return first_enabled()


func open(id: String) -> void:
	var s := GameSession.current
	var m := s.mail.model.find(id)
	if m.is_empty():
		return
	reading = id
	s.mail.read(id)
	clear_rows()
	picture = ColorRect.new()   # illustration placeholder: picture first for pre-readers
	picture.custom_minimum_size = Vector2(200, 120)
	picture.color = _color(m)
	list.add_child(picture)
	body = Label.new()
	body.text = "%s\n\n%s" % [m["subject_key"], m["body_key"]]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	list.add_child(body)
	Accessibility.speak(body.text)
	if not m["claimed"] and not m["attachments"].is_empty():
		add_row("Take the gift", Color(0.5, 0.8, 0.5), func(): claim(id))
	add_row("Put away", Color(0.7, 0.7, 0.7), func(): archive(id))
	add_row("Back", Color(0.6, 0.6, 0.8), refresh)
	MenuBase.focus_later(first_enabled())


func claim(id: String) -> Result:
	var adopt := [false]
	var cb := func(): adopt[0] = true
	EventBus.pet_adoption_claimed.connect(cb)
	var r := GameSession.current.mail.claim(id)
	EventBus.pet_adoption_claimed.disconnect(cb)
	say("Got it!" if r.ok else ("Make room in your backpack first" if r.error == &"no_space" else String(r.error)))
	if adopt[0]:
		MenuStack.instance.push(&"pet_adoption")
	return r


func archive(id: String) -> void:
	GameSession.current.mail.archive(id)
	refresh()


func claim_lost_and_found() -> Result:
	var r := GameSession.current.mail.claim_lost_and_found()
	say("Got everything back!" if r.ok else "Make room in your backpack first")
	refresh()
	return r


func on_cancel() -> void:
	if reading != "":
		refresh()
	else:
		close()
