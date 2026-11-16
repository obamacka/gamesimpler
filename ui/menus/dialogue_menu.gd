## Dialogue (spec 4.7): Greeting -> Choices -> {Chat, JobTalk, Shop} -> Choices -> End.
## The A glyph advances. Shop and JobTalk open their menus on top. args: {"npc_id"}.
extends MenuBase

var model := DialogueModel.new()
var npc_id: StringName
var line: Label
var glyph: Control


func build() -> void:
	npc_id = StringName(args.get("npc_id", ""))
	var def: NpcDef = Database.npcs[npc_id]
	var s := GameSession.current
	model.start(def, int(s.npcs.model.of(npc_id)["friendship"]), s.day())
	make_list(def.name_key, Vector2(640, 300))
	line = Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD
	list.add_child(line)
	refresh()


func refresh() -> void:
	for c in list.get_children():
		if c != line:
			list.remove_child(c)
			c.queue_free()
	line.text = model.text
	Accessibility.speak(model.text)
	if model.node == DialogueModel.CHOICES:
		for opt in model.choices():
			var o: StringName = opt
			var labels := {DialogueModel.CHAT: "Chat", DialogueModel.JOB: "Work", DialogueModel.SHOP: "Shop", DialogueModel.END: "Bye"}
			add_row(labels[o], Color(0.6, 0.75, 0.9), func(): choose(o))
	else:
		add_row("(A) Next", Color(0.5, 0.8, 0.5), advance)
	var f := first_enabled()
	if f and is_inside_tree():
		MenuBase.focus_later(f)


func initial_focus() -> Control:
	return first_enabled()


func advance() -> void:
	model.advance()
	refresh()


func choose(option: StringName) -> void:
	model.choose(option)
	var def: NpcDef = Database.npcs[npc_id]
	match option:
		DialogueModel.END:
			close(&"end")
			return
		DialogueModel.SHOP:
			MenuStack.instance.push(&"shop", {"shop_id": def.shop_id})
		DialogueModel.JOB:
			MenuStack.instance.push(&"job_board", {"job_id": def.job_id})
	refresh()
