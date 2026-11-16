## Pet adoption (spec 7.1, D11): species (dog or cat), 3 color variants, a name from the
## preset list. Pressing Adopt creates the pet next to the player.
extends MenuBase

var species: StringName = &"pet_dog"
var variant := 0
var pet_name := ""


func build() -> void:
	make_list("Choose your new friend", Vector2(600, 480))
	if not Database.pet_names.is_empty():
		pet_name = Database.pet_names[0]
	refresh()


func refresh() -> void:
	clear_rows()
	for sp in Database.pet_species:
		var id: StringName = sp
		add_row(("> " if id == species else "") + String(id).trim_prefix("pet_"), Color(0.8, 0.7, 0.5), func(): species = id; refresh())
	var sp_def: PetSpeciesDef = Database.pet_species[species]
	for i in sp_def.variants.size():
		var v := i
		add_row(("> " if v == variant else "") + "Color %d" % (v + 1), sp_def.variants[v], func(): variant = v; refresh())
	for n in Database.pet_names:
		var nn: String = n
		add_row(("> " if nn == pet_name else "") + nn, Color(0.7, 0.8, 0.9), func(): pet_name = nn; refresh())
	add_row("Adopt!", Color(0.5, 0.85, 0.5), func(): adopt())


func initial_focus() -> Control:
	return first_enabled()


func choose(p_species: StringName, p_variant: int, p_name: String) -> Result:
	species = p_species
	variant = p_variant
	pet_name = p_name
	return adopt()


func adopt() -> Result:
	var r := GameSession.current.pets.adopt(species, variant, pet_name)
	if r.ok:
		close(&"adopted")
	else:
		say(String(r.error))
	return r


func on_cancel() -> void:
	pass   # the adoption ticket is used; finish choosing
