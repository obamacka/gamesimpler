## Dialogue flow (spec 4.7): Greeting -> Choices -> {Chat, JobTalk, Shop} -> Choices -> End.
## Pure. Lines are picked by friendship tier so returning friends hear warmer greetings.
class_name DialogueModel
extends RefCounted

const GREETING := &"greeting"
const CHOICES := &"choices"
const CHAT := &"chat"
const JOB := &"job"
const SHOP := &"shop"
const END := &"end"

var npc: NpcDef
var friendship := 0
var node: StringName = END
var text := ""
var _chat_i := 0


func start(def: NpcDef, friendship_points: int, day: int) -> void:
	npc = def
	friendship = friendship_points
	node = GREETING
	var g: Array = def.dialogue.get("greeting", ["Hello!"])
	text = g[clampi(friendship / 200, 0, g.size() - 1)]
	_chat_i = day % maxi(1, (def.dialogue.get("chat", [""]) as Array).size())


## Options on the Choices node, in display order.
func choices() -> Array[StringName]:
	var out: Array[StringName] = [CHAT]
	if npc.job_id != &"":
		out.append(JOB)
	if npc.shop_id != &"":
		out.append(SHOP)
	out.append(END)
	return out


## A on Greeting or Chat goes back to Choices.
func advance() -> StringName:
	if node in [GREETING, CHAT, JOB, SHOP]:
		node = CHOICES
		text = ""
	return node


func choose(option: StringName) -> StringName:
	if node != CHOICES or not (option in choices()):
		return node
	node = option
	match option:
		CHAT:
			var c: Array = npc.dialogue.get("chat", ["..."])
			text = c[_chat_i % c.size()]
			_chat_i += 1
		JOB:
			text = "Here is the work I have."
		SHOP:
			text = "Have a look!"
		END:
			text = ""
	return node
