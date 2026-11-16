## Which button prompts to show for the current target (spec 2.8). Pure.
## Rows: [{"button": StringName, "text": String}]. Buttons use GlyphSetDef names
## (face_left = X / Square = interact, face_top = Y / Triangle, trigger_right = RT / R2).
class_name PromptModel
extends RefCounted

const VERBS := {
	&"FORAGE": "Pick", &"CHEST": "Open", &"PICKUP": "Pick up", &"BED": "Sleep",
	&"MAILBOX": "Open mail", &"MINE_ENTRANCE": "Enter", &"TALK": "Talk", &"GIFT": "Gift",
}
const TOOL_TEXT := {
	ToolTypes.PICKAXE: "Dig (pickaxe)", ToolTypes.SHOVEL: "Dig (shovel)", ToolTypes.AXE: "Chop",
	ToolTypes.FRUIT_PICKER: "Pick", ToolTypes.HAMMER: "Hammer", ToolTypes.SCREWDRIVER: "Screw",
}
const BLOCKED_TEXT := {
	&"protected": "Protected", &"bedrock": "Too hard", &"supports_object": "Holds something up",
	&"supports_building": "Holds a building up", &"job_site": "Job site", &"under_player": "Under your feet",
	&"missing_tool": "Need a tool", &"tier_lock": "Need a stronger pickaxe",
}


static func rows(tool_best: Dictionary, blocked: StringName, primary: InteractionSpec, secondary: InteractionSpec, unread: int = 0) -> Array:
	var out: Array = []
	if blocked != &"":
		out.append({"button": &"lock", "text": BLOCKED_TEXT.get(blocked, "Can't dig")})
	elif tool_best.has("tool") and tool_best["tool"] != &"":
		out.append({"button": &"trigger_right", "text": TOOL_TEXT.get(tool_best["tool"], "Use")})
	if primary:
		var t: String = VERBS.get(primary.kind, "Use")
		if primary.kind == &"MAILBOX" and unread > 0:
			t += " (%d)" % unread
		out.append({"button": &"face_left", "text": t})
	if secondary:
		out.append({"button": &"face_top", "text": VERBS.get(secondary.kind, "Use")})
	return out
