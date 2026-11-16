# P5.15: feeding rules (spec 7.1).
extends GdUnitTestSuite

var m: PetModel
var pet: Dictionary
var dog: PetSpeciesDef


func before_test() -> void:
	m = PetModel.new(Database.pet_config)
	pet = m.new_pet("p", &"pet_dog", 0, "Biscuit")
	pet["happiness"] = 50
	dog = Database.pet_species[&"pet_dog"]


func test_only_pet_food_or_favorite_food() -> void:
	assert_str(m.feed(pet, Database.item(&"item_stone"), dog, 3)["reason"]).is_equal(PetModel.NOT_FOOD)
	assert_str(m.feed(pet, Database.item(&"item_honey_bun"), dog, 3)["reason"]).is_equal(PetModel.NOT_FOOD)   # FOOD, not a favorite
	assert_int(pet["happiness"]).is_equal(50)
	assert_int(pet["fed_day"]).is_equal(0)


func test_favorite_doubles_and_second_feed_halves() -> void:
	var r := m.feed(pet, Database.item(&"item_kibble"), dog, 3)   # meaty: favorite for dogs
	assert_int(r["gain"]).is_equal(20)
	assert_int(pet["fed_day"]).is_equal(3)
	assert_int(m.feed(pet, Database.item(&"item_kibble"), dog, 3)["gain"]).is_equal(10)
	assert_int(m.feed(pet, Database.item(&"item_fish_treat"), dog, 4)["gain"]).is_equal(10)   # not favorite


func test_clamp_and_floor() -> void:
	pet["happiness"] = 95
	m.feed(pet, Database.item(&"item_kibble"), dog, 3)
	assert_int(pet["happiness"]).is_equal(100)
	pet["happiness"] = 40
	m.drift(pet)
	assert_int(pet["happiness"]).is_equal(45)   # drifts up toward 60
	pet["happiness"] = 62
	m.drift(pet)
	assert_int(pet["happiness"]).is_equal(60)   # never past the target
	pet["happiness"] = 10
	m.drift(pet)
	assert_int(pet["happiness"]).is_greater_equal(40)


func test_pat_once_per_day_bonus() -> void:
	assert_int(m.pat(pet, 3)).is_equal(5)
	assert_int(m.pat(pet, 3)).is_equal(1)
	assert_int(m.pat(pet, 4)).is_equal(5)


func test_daily_find_at_80() -> void:
	var rng := RngStreams.new(3)
	pet["happiness"] = 79
	assert_str(m.daily_find(pet, 5, rng)).is_equal(&"")
	pet["happiness"] = 80
	assert_str(m.daily_find(pet, 5, rng)).is_not_equal(&"")
	assert_str(m.daily_find(pet, 5, rng)).is_equal(&"")   # once per day


func test_nothing_removed_on_refusal() -> void:
	var s: GameSession = auto_free(GameSession.create(1))
	add_child(s)
	s.new_game()
	s.pets.pets.append(m.new_pet("p", &"pet_dog", 0, "B"))
	s.inventory.add(&"item_honey_bun", 1)
	assert_bool(s.pets.try_feed(&"item_honey_bun").ok).is_false()
	assert_int(s.inventory.count(&"item_honey_bun")).is_equal(1)
	assert_str(s.pets.try_feed(&"item_kibble").error).is_equal(PetModel.NO_ITEM)
