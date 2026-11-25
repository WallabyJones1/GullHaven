extends RefCounted
## The Harbour economy as numbers and rules only (no UI, no save file): what a Shell sells
## for, how many Shells a Fisher earns at sea by its place in the stack, and where spent
## $GULL goes. Every number is a starting value to tune (see the token plan doc). This
## build has no blockchain: the Exchange pays into the save file's local ledger.

const DAILY_BUDGET := 50000.0  # $GULL the Exchange pays out a day, shared pro-rata by everyone's Shells
const MARKET_SHELLS := 500000.0  # stand-in for everyone's Shells sold that day (the server would know the real figure)
const SALE_CAP := 5000  # most Shells one account can sell in a day (UTC)
const BURN_SHARE := 0.4  # of every spend: burned...
const REWARD_SHARE := 0.4  # ...back into the player rewards pool...
# ...and the rest (20%) goes to the treasury.
const MAX_AT_SEA := 25  # most Fishers one account can have out at once
const SHELLS_PER_HOUR := 60.0  # one Fisher at full stacking
const MAX_HOURS := 12.0  # an expedition stops paying after this; the crew must come home to earn again
const FISHER_PRICE := 500.0  # $GULL for one Fisher (test price; the plan prices Fishers in SOL)
const LICENCE_FISHERS := 1  # Harbour Licence: at least one Fisher (plots are not in this build)


## $GULL per Shell at the Exchange: the day's budget over everyone's Shells.
static func rate_per_shell() -> float:
	return DAILY_BUDGET / MARKET_SHELLS


## Fishers 1-3 earn 100%, 4-10 earn 75%, 11-25 earn 50%. Rank is the order they went out.
static func stack_multiplier(rank: int) -> float:
	if rank < 1 or rank > MAX_AT_SEA:
		return 0.0
	if rank <= 3:
		return 1.0
	if rank <= 10:
		return 0.75
	return 0.5


## Shells a Fisher of this rank has earned after `hours` at sea (whole Shells, capped at MAX_HOURS).
static func expedition_shells(rank: int, hours: float) -> int:
	return int(floor(clampf(hours, 0.0, MAX_HOURS) * SHELLS_PER_HOUR * stack_multiplier(rank)))


## Splits a spend into burn, reward pool and treasury. The treasury takes what is left over,
## so the three always add back up to the amount.
static func split(amount: float) -> Dictionary:
	var burn := snappedf(amount * BURN_SHARE, 0.01)
	var reward := snappedf(amount * REWARD_SHARE, 0.01)
	var treasury := snappedf(amount - burn - reward, 0.01)
	return {"burn": burn, "reward": reward, "treasury": treasury}
