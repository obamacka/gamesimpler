# P5.17: X/Y interaction specs for NPCs, the curator and the pet (feed vs dress up).
extends GdUnitTestSuite

var s: GameSession


func before_test() -> void:
	s = GameSession.create(2)
	add_child(s)
	s.new_game()


func after_test() -> void:
	s.queue_free()


func test_npc_specs() -> void:
	for id in [&"npc_hilde", &"npc_curator"]:
		var n: Npc = auto_free(Npc.new())
		n.npc_id = id
		var x := n.interaction_spec(null, false, false)
		assert_str(x.kind).is_equal(&"TALK")
		assert_str(x.handoff_state).is_equal(&"talk")
		var y := n.interaction_spec(null, false, true)
		assert_str(y.kind).is_equal(&"GIFT")
		assert_str(y.opens_menu).is_equal(&"gift_picker")
		assert_dict(y.menu_args).is_equal({"npc_id": id})


func test_pet_specs_feed_vs_dress_up() -> void:
	s.pets.pets.append(s.pets.model.new_pet("p", &"pet_dog", 0, "B"))
	var p: Pet = auto_free(Pet.create(s, s.pets.pet()))
	assert_str(p.interaction_spec(null, false, false).kind).is_equal(&"PET_PAT")
	assert_str(p.interaction_spec(null, false, true).kind).is_equal(&"PET_DRESS")   # no food
	s.inventory.add(&"item_kibble", 1)
	assert_str(p.interaction_spec(null, false, true).kind).is_equal(&"PET_FEED")
	s.pets.pet()["fed_day"] = s.day()
	var dress := p.interaction_spec(null, false, true)
	assert_str(dress.kind).is_equal(&"PET_DRESS")   # already fed today
	assert_str(dress.opens_menu).is_equal(&"pet_wardrobe")


func test_resolver_ranks_pet_and_npc_above_generic() -> void:
	var best := InteractionResolver.best([
		{"key": "lamp", "kind": &"TOGGLE", "distance": 1.0, "facing_dot": 1.0, "aimed": false},
		{"key": "pet", "kind": &"PET", "distance": 1.0, "facing_dot": 1.0, "aimed": false}])
	assert_str(best["key"]).is_equal("pet")
