extends RefCounted
## The Harbour: the save's "token" ledger and the things you do with it (sell Shells, send
## Fishers to sea, bring them home, spend $GULL). Plain functions on the save dictionary, so
## the unit test can drive them without the game running. See economy.gd for the numbers.

const Economy := preload("res://scripts/token/economy.gd")


static func defaults() -> Dictionary:
	return {
		"gull": 0.0,  # your $GULL balance (local stand-in for a wallet)
		"fishers": 0,  # Fishers you own
		"sea": [],  # Fishers out now: {sent: unix time}; index + 1 is the stacking rank
		"day": "",  # the UTC day the sale count is for
		"sold": 0,  # Shells sold today
		"starter": false,  # the free starter Fisher has been given
		"burned": 0.0,
		"reward_pool": 0.0,
		"treasury": 0.0,
	}


## Fills in any missing keys (older saves, or a save from before this build).
static func ensure(save: Dictionary) -> Dictionary:
	var t: Dictionary = save.get("token", {})
	var base := defaults()
	for k in base:
		if not t.has(k):
			t[k] = base[k]
	save["token"] = t
	return t


static func licence(save: Dictionary) -> bool:
	return int(ensure(save).fishers) >= Economy.LICENCE_FISHERS


static func day_key(now: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(now)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Sell up to `shells` Shells (pass -1 for as many as the cap allows).
static func sell(save: Dictionary, shells: int, now: int) -> Dictionary:
	var t := ensure(save)
	if not licence(save):
		return {"ok": false, "reason": "You need a Harbour Licence first: one Fisher, or a plot."}
	var day := day_key(now)
	if t.day != day:
		t.day = day
		t.sold = 0
	var have := int(save.get("shells", 0))
	if have <= 0:
		return {"ok": false, "reason": "You have no Shells to sell."}
	var room := Economy.SALE_CAP - int(t.sold)
	if room <= 0:
		return {"ok": false, "reason": "You've sold your %d Shells for today. The Exchange resets at midnight UTC." % Economy.SALE_CAP}
	var want := have if shells < 0 else mini(shells, have)
	var n := mini(want, room)
	var gull := snappedf(n * Economy.rate_per_shell(), 0.01)
	save["shells"] = have - n
	t.sold = int(t.sold) + n
	t.gull = snappedf(float(t.gull) + gull, 0.01)
	return {"ok": true, "sold": n, "gull": gull, "capped": n < want}


## Spend $GULL. The split goes to burn, the reward pool and the treasury.
static func spend(save: Dictionary, amount: float, what: String) -> Dictionary:
	var t := ensure(save)
	if amount <= 0.0 or float(t.gull) < amount - 0.0001:
		return {"ok": false, "reason": "You need %.2f $GULL for %s." % [amount, what]}
	var s := Economy.split(amount)
	t.gull = snappedf(float(t.gull) - amount, 0.01)
	t.burned = snappedf(float(t.burned) + float(s.burn), 0.01)
	t.reward_pool = snappedf(float(t.reward_pool) + float(s.reward), 0.01)
	t.treasury = snappedf(float(t.treasury) + float(s.treasury), 0.01)
	return {"ok": true, "split": s}


static func buy_fisher(save: Dictionary) -> Dictionary:
	var r := spend(save, Economy.FISHER_PRICE, "a Fisher")
	if r.ok:
		var t := ensure(save)
		t.fishers = int(t.fishers) + 1
	return r


## The free Fisher a new Harbour gets, so the Licence can be reached without buying one.
## Local test only: on the real chain Fishers are minted, not granted.
static func starter_fisher(save: Dictionary) -> bool:
	var t := ensure(save)
	if t.starter or int(t.fishers) > 0:
		return false
	t.starter = true
	t.fishers = 1
	return true


static func send_out(save: Dictionary, now: int) -> Dictionary:
	var t := ensure(save)
	var at_sea: Array = t.sea
	if at_sea.size() >= Economy.MAX_AT_SEA:
		return {"ok": false, "reason": "No more than %d Fishers can be at sea." % Economy.MAX_AT_SEA}
	if at_sea.size() >= int(t.fishers):
		return {"ok": false, "reason": "All your Fishers are already at sea."}
	at_sea.append({"sent": now})
	return {"ok": true, "rank": at_sea.size()}


## Shells the crew has earned so far (not yet brought home).
static func pending(save: Dictionary, now: int) -> int:
	var total := 0
	var at_sea: Array = ensure(save).sea
	for i in at_sea.size():
		var hours := float(now - int(at_sea[i].sent)) / 3600.0
		total += Economy.expedition_shells(i + 1, hours)
	return total


## Bring every Fisher home. The catch goes into your Shells, and the Fishers can go out again.
## Nothing is paid until you come back for it: the catch is collected in person.
static func bring_home(save: Dictionary, now: int) -> Dictionary:
	var t := ensure(save)
	var crew: int = t.sea.size()
	if crew == 0:
		return {"ok": false, "reason": "No Fishers are at sea."}
	var got := pending(save, now)
	save["shells"] = int(save.get("shells", 0)) + got
	t.sea = []
	return {"ok": true, "shells": got, "crew": crew}
