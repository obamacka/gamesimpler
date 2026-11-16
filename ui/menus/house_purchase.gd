## Plot purchase (spec 5.8, D5 upfront coins). args: {"plot_id"}.
extends MenuBase

var plot_id: StringName
var buy_btn: Button


func build() -> void:
	plot_id = StringName(args.get("plot_id", ""))
	var p: PlotDef = Database.plots.get(plot_id)
	make_list("Land for sale", Vector2(480, 260))
	var owned := GameSession.current.housing.owns(plot_id)
	buy_btn = add_row("Buy for %d coins" % (p.price_coins if p else 0), Color(0.5, 0.8, 0.5), buy, not owned)
	add_row("Not now", Color(0.7, 0.7, 0.7), func(): close())
	if owned:
		say("This land is yours!")


func initial_focus() -> Control:
	return buy_btn if not buy_btn.disabled else list.get_child(1)


func buy() -> Result:
	var r := GameSession.current.economy.tx.try_buy_plot(plot_id)
	if r.ok:
		close(&"bought")
	else:
		say("Not enough coins" if r.error == &"not_enough_coins" else String(r.error))
	return r
