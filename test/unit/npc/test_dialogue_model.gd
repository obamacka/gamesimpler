# P5.17: dialogue flow (spec 4.7).
extends GdUnitTestSuite


func test_flow_and_choices() -> void:
	var d := DialogueModel.new()
	d.start(Database.npcs[&"npc_foreman"], 0, 1)
	assert_str(d.node).is_equal(DialogueModel.GREETING)
	assert_str(d.text).is_equal("Ready to build?")
	assert_str(d.advance()).is_equal(DialogueModel.CHOICES)
	assert_array(d.choices()).is_equal([DialogueModel.CHAT, DialogueModel.JOB, DialogueModel.SHOP, DialogueModel.END])
	assert_str(d.choose(DialogueModel.CHAT)).is_equal(DialogueModel.CHAT)
	assert_str(d.text).is_not_empty()
	assert_str(d.advance()).is_equal(DialogueModel.CHOICES)
	assert_str(d.choose(DialogueModel.END)).is_equal(DialogueModel.END)


func test_greeting_warms_with_friendship_and_options_follow_role() -> void:
	var d := DialogueModel.new()
	d.start(Database.npcs[&"npc_hilde"], 450, 1)
	assert_str(d.text).is_equal("There you are, my favorite customer!")
	d.advance()
	assert_array(d.choices()).is_equal([DialogueModel.CHAT, DialogueModel.SHOP, DialogueModel.END])
	assert_str(d.choose(DialogueModel.JOB)).is_equal(DialogueModel.CHOICES)   # not offered: ignored
	var n := DialogueModel.new()
	n.start(Database.npcs[&"npc_neighbor"], 0, 1)
	n.advance()
	assert_array(n.choices()).is_equal([DialogueModel.CHAT, DialogueModel.END])
