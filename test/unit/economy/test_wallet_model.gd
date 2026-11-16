# P4.14: integer wallet, never negative, events only on change.
extends GdUnitTestSuite


func test_int_only_and_never_negative() -> void:
	var w := WalletModel.new()
	assert_bool(w.credit(10)).is_true()
	assert_bool(w.debit(11)).is_false()
	assert_int(w.coins).is_equal(10)
	assert_bool(w.credit(-5)).is_false()
	assert_bool(w.debit(-1)).is_false()
	assert_bool(w.debit(10)).is_true()
	assert_int(w.coins).is_equal(0)
	assert_int(typeof(w.coins)).is_equal(TYPE_INT)
	w.from_dict({"coins": -40})
	assert_int(w.coins).is_equal(0)


func test_service_events() -> void:
	var s: WalletService = auto_free(WalletService.new())
	var got: Array = []
	var cb := func(a, b): got.append([a, b])
	EventBus.coins_changed.connect(cb)
	s.credit(25)
	s.debit(30)
	s.debit(5)
	s.credit(0)
	EventBus.coins_changed.disconnect(cb)
	assert_array(got).is_equal([[0, 25], [25, 20]])
