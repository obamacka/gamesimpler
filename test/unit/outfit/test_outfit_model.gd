# P4.16: outfit slots, swap, dye ids, hidden body regions.
extends GdUnitTestSuite


func test_equip_swap_and_hidden_regions() -> void:
	var m := OutfitModel.new()
	assert_object(m.equip(&"item_outfit_shirt_cotton")).is_null()
	assert_str(m.slots[&"TOP"]["data"]["dye"]).is_equal("dye_snow")   # default dye
	var old = m.equip(&"item_outfit_raincoat")
	assert_str(old["item_id"]).is_equal(&"item_outfit_shirt_cotton")
	m.equip(&"item_outfit_hat_straw")
	assert_array(m.hidden_regions()).is_equal([&"ARMS", &"HAIR", &"TORSO"])
	m.unequip(&"TOP")
	assert_array(m.hidden_regions()).is_equal([&"HAIR"])


func test_dye_is_an_id_and_validated() -> void:
	var m := OutfitModel.new()
	assert_bool(m.set_dye(&"HEAD", &"dye_sky")).is_false()   # nothing worn
	m.equip(&"item_outfit_hat_straw")
	assert_bool(m.set_dye(&"HEAD", &"dye_unknown")).is_false()
	assert_bool(m.set_dye(&"HEAD", &"dye_sky")).is_true()
	assert_str(m.slots[&"HEAD"]["data"]["dye"]).is_equal("dye_sky")
	assert_that(m.color_of(&"HEAD")).is_equal(Database.dyes[&"dye_sky"].color)


func test_round_trip() -> void:
	var m := OutfitModel.new()
	m.equip(&"item_outfit_boots_rain", {"dye": "dye_coal"})
	var b := OutfitModel.new()
	b.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_dict(b.to_dict()).is_equal(m.to_dict())
