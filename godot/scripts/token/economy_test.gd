extends SceneTree
## Checks the Harbour rules without starting the game. Run with:
##   godot --headless --path godot -s res://scripts/token/economy_test.gd
## Prints "ECONOMY CHECK ok/FAIL <what>" lines and exits 1 if any check fails.

const Economy := preload("res://scripts/token/economy.gd")
const Harbour := preload("res://scripts/token/harbour.gd")

const T0 := 1800000000  # a fixed unix time, so the tests are repeatable
const DAY := 86400

var _failed := 0
var _checks := 0


func check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("ECONOMY CHECK ok %s" % what)
	else:
		_failed += 1
		print("ECONOMY CHECK FAIL %s" % what)


func _init() -> void:
	_run()
	print("ECONOMY DONE, %d checks failed of %d" % [_failed, _checks])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	# stacking
	check(Economy.stack_multiplier(1) == 1.0 and Economy.stack_multiplier(3) == 1.0, "Fishers 1-3 earn 100%")
	check(Economy.stack_multiplier(4) == 0.75 and Economy.stack_multiplier(10) == 0.75, "Fishers 4-10 earn 75%")
	check(Economy.stack_multiplier(11) == 0.5 and Economy.stack_multiplier(25) == 0.5, "Fishers 11-25 earn 50%")
	check(Economy.stack_multiplier(26) == 0.0 and Economy.stack_multiplier(0) == 0.0, "no pay outside 1-25")

	# expedition yield
	check(Economy.expedition_shells(1, 1.0) == 60, "one hour at sea earns 60 Shells at full stacking")
	check(Economy.expedition_shells(4, 1.0) == 45, "a 4th Fisher earns 75% of that")
	check(Economy.expedition_shells(11, 12.0) == 360, "11th Fisher, 12 hours: 360")
	check(Economy.expedition_shells(1, 50.0) == 720, "yield stops at the 12-hour cap")
	check(Economy.expedition_shells(1, -3.0) == 0, "negative time earns nothing")

	# spend split
	var s := Economy.split(500.0)
	check(is_equal_approx(s.burn, 200.0) and is_equal_approx(s.reward, 200.0) and is_equal_approx(s.treasury, 100.0), "a spend splits 40/40/20")
	var odd := Economy.split(0.07)
	check(is_equal_approx(float(odd.burn) + float(odd.reward) + float(odd.treasury), 0.07), "the split adds back to the amount")

	# sell: licence, rate, daily cap, rollover
	var save := {"shells": 1000}
	check(not Harbour.sell(save, 100, T0).ok, "no sale without a Harbour Licence")
	Harbour.ensure(save).fishers = 1
	var r := Harbour.sell(save, 100, T0)
	check(r.ok and r.sold == 100 and is_equal_approx(r.gull, 10.0), "100 Shells sell for 10 $GULL at 0.1 per Shell")
	check(int(save.shells) == 900, "the sold Shells leave your Shells")
	r = Harbour.sell(save, -1, T0)
	check(r.ok and r.sold == 900 and int(save.shells) == 0, "sell all sells everything you have")
	check(not Harbour.sell(save, 5, T0).ok, "nothing to sell when you have none")

	save = {"shells": 9000}
	Harbour.ensure(save).fishers = 1
	r = Harbour.sell(save, -1, T0)
	check(r.ok and r.sold == Economy.SALE_CAP and r.capped, "a day's sale stops at the cap")
	check(int(save.shells) == 9000 - Economy.SALE_CAP, "Shells above the cap stay in your hands")
	check(not Harbour.sell(save, 1, T0 + 3600).ok, "the cap holds for the rest of the day")
	check(Harbour.sell(save, 10, T0 + DAY).ok, "the cap resets on the next UTC day")

	# spend
	save = {"shells": 0}
	var t := Harbour.ensure(save)
	t.gull = 10.0
	check(not Harbour.spend(save, 50.0, "a thing").ok, "can't spend more $GULL than you have")
	check(Harbour.spend(save, 4.0, "bait").ok and is_equal_approx(float(t.gull), 6.0), "a spend takes its price off your balance")
	check(is_equal_approx(float(t.burned), 1.6) and is_equal_approx(float(t.treasury), 0.8), "the spend is split into burn and treasury")

	# Fishers
	save = {}
	t = Harbour.ensure(save)
	t.gull = 0.0
	check(not Harbour.buy_fisher(save).ok, "a Fisher costs $GULL")
	t.gull = 1000.0
	check(Harbour.buy_fisher(save).ok and int(t.fishers) == 1 and is_equal_approx(float(t.gull), 500.0), "buying a Fisher charges the price and adds one")
	check(Harbour.starter_fisher({}) and not Harbour.starter_fisher({"token": {"starter": true}}), "the starter Fisher is given once")
	var starter := {}
	check(Harbour.starter_fisher(starter) and int(Harbour.ensure(starter).fishers) == 1, "a new save gets one starter Fisher")
	check(not Harbour.starter_fisher(starter), "...and no second one")

	# expeditions
	save = {"shells": 0}
	t = Harbour.ensure(save)
	t.fishers = 2
	check(Harbour.send_out(save, T0).ok and Harbour.send_out(save, T0).rank == 2, "two Fishers go out, ranked in order")
	check(not Harbour.send_out(save, T0).ok, "no more Fishers than you own")
	check(Harbour.pending(save, T0 + 2 * 3600) == 240, "two hours: 120 + 120 Shells, both at full stacking")
	check(Harbour.pending(save, T0 + 2 * 3600) == 240 and Harbour.pending(save, T0 + 100 * 3600) == 720 + 720, "expeditions stop paying at 12 hours")

	var got := Harbour.bring_home(save, T0 + 2 * 3600)
	check(got.ok and got.shells == 240 and int(save.shells) == 240 and (t.sea as Array).is_empty(), "bringing home pays the catch and recalls the crew")
	check(not Harbour.bring_home(save, T0 + 3 * 3600).ok, "nothing to bring home when none are out")

	# Fishers in a connected wallet count too
	save = {"shells": 100}
	t = Harbour.ensure(save)
	t.chain_fishers = 2
	check(Harbour.licence(save) and Harbour.owned(save) == 2, "wallet Fishers give a Harbour Licence")
	check(Harbour.sell(save, 10, T0).ok, "...so Shells can be sold with only wallet Fishers")
	t.fishers = 1
	for i in 3:
		Harbour.send_out(save, T0)
	check((t.sea as Array).size() == 3 and not Harbour.send_out(save, T0).ok, "save + wallet Fishers can all go to sea, and no more")

	# many at sea: the 25th earns half
	save = {}
	t = Harbour.ensure(save)
	t.fishers = 30
	for i in 25:
		Harbour.send_out(save, T0)
	check(not Harbour.send_out(save, T0).ok, "no more than 25 at sea")
	check(Harbour.pending(save, T0 + 3600) == 3 * 60 + 7 * 45 + 15 * 30, "25 at sea after an hour: 3x60 + 7x45 + 15x30")
