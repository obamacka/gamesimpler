# P2.20: prompt rows (spec 2.8): blocked lock, tool prompt, X primary, Y secondary, mail badge.
extends GdUnitTestSuite


func test_tool_and_primary() -> void:
	var rows := PromptModel.rows({"tool": ToolTypes.PICKAXE}, &"", InteractionSpec.new(&"CHEST"), null)
	assert_array(rows.map(func(r): return r["button"])).contains_exactly([&"trigger_right", &"face_left"])
	assert_str(rows[1]["text"]).is_equal("Open")


func test_blocked_replaces_tool() -> void:
	var rows := PromptModel.rows({"tool": ToolTypes.SHOVEL}, &"protected", null, null)
	assert_int(rows.size()).is_equal(1)
	assert_str(rows[0]["button"]).is_equal(&"lock")
	assert_str(rows[0]["text"]).is_equal("Protected")


func test_mail_badge_and_secondary() -> void:
	var rows := PromptModel.rows({}, &"", InteractionSpec.new(&"MAILBOX"), InteractionSpec.new(&"GIFT"), 2)
	assert_str(rows[0]["text"]).is_equal("Open mail (2)")
	assert_str(rows[1]["button"]).is_equal(&"face_top")


func test_empty() -> void:
	assert_array(PromptModel.rows({}, &"", null, null)).is_empty()
