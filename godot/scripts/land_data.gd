extends RefCounted
## Everything you can do on land, as data: the items (what they're called, what they sell
## for), the crops in Gran's garden, the rocks you can mine, the animals you can hunt, the
## things you can forage, every recipe at the workbench and the cook pot, the tools and
## the five land skills. land.gd runs it; land_menu.gd shows it.

# Item categories: crop, seed, forage, ore, bar, gem, game, meal, tool, craft
const ITEMS := {
	# Gran's garden
	"turnip": {"n": "Turnip", "cat": "crop", "price": 18, "d": "Quick to grow and hard to kill. Gran's favourite."},
	"carrot": {"n": "Carrot", "cat": "crop", "price": 26, "d": "Sweet and crunchy. The rabbits agree."},
	"potato": {"n": "Potato", "cat": "crop", "price": 32, "d": "Knobbly, filling and good in everything."},
	"wheat": {"n": "Wheat", "cat": "crop", "price": 22, "d": "Bake it, or twist the straw into twine."},
	"strawberry": {"n": "Strawberry", "cat": "crop", "price": 48, "d": "Slow to ripen and worth the wait."},
	"pumpkin": {"n": "Pumpkin", "cat": "crop", "price": 120, "d": "The pride of any garden. Takes an age."},
	"seed_turnip": {"n": "Turnip seeds", "cat": "seed", "price": 4, "buy": 10, "crop": "turnip"},
	"seed_carrot": {"n": "Carrot seeds", "cat": "seed", "price": 6, "buy": 14, "crop": "carrot"},
	"seed_potato": {"n": "Seed potatoes", "cat": "seed", "price": 8, "buy": 18, "crop": "potato"},
	"seed_wheat": {"n": "Wheat seeds", "cat": "seed", "price": 5, "buy": 12, "crop": "wheat"},
	"seed_strawberry": {"n": "Strawberry runners", "cat": "seed", "price": 12, "buy": 30, "crop": "strawberry"},
	"seed_pumpkin": {"n": "Pumpkin seeds", "cat": "seed", "price": 30, "buy": 70, "crop": "pumpkin"},
	# out foraging
	"berries": {"n": "Blackberries", "cat": "forage", "price": 14, "d": "From the bramble bushes. Mind the thorns."},
	"mushroom": {"n": "Field mushroom", "cat": "forage", "price": 16, "d": "Pops up in the woods overnight."},
	"chanterelle": {"n": "Chanterelle", "cat": "forage", "price": 40, "d": "Golden, frilly and prized by cooks."},
	"herbs": {"n": "Wild herbs", "cat": "forage", "price": 12, "d": "Thyme, sorrel and a bit of mint."},
	"wildflowers": {"n": "Wildflowers", "cat": "forage", "price": 10, "d": "A handful of the coast's colours."},
	# mining
	"stone": {"n": "Stone", "cat": "ore", "price": 3, "d": "Good honest rock. Builders always want more."},
	"coal": {"n": "Coal", "cat": "ore", "price": 12, "d": "Feeds a forge. Smelting needs it."},
	"copper_ore": {"n": "Copper ore", "cat": "ore", "price": 14, "d": "Green-flecked rock from the coast."},
	"iron_ore": {"n": "Iron ore", "cat": "ore", "price": 22, "d": "Heavy, rusty and very useful."},
	"silver_ore": {"n": "Silver ore", "cat": "ore", "price": 40, "d": "From the high country past the ranger's gate."},
	"gold_ore": {"n": "Gold ore", "cat": "ore", "price": 80, "d": "Ember Isle's warm rock hides it."},
	"quartz": {"n": "Quartz", "cat": "gem", "price": 45, "d": "Clear as Mirrorlake."},
	"amethyst": {"n": "Amethyst", "cat": "gem", "price": 90, "d": "Gull Rock's purple secret."},
	"ember_crystal": {"n": "Ember crystal", "cat": "gem", "price": 220, "d": "Warm to the touch. The Gull's Eye was cut from one."},
	"copper_bar": {"n": "Copper bar", "cat": "bar", "price": 40, "d": "Smelted at the workbench."},
	"iron_bar": {"n": "Iron bar", "cat": "bar", "price": 65, "d": "Smelted at the workbench."},
	"silver_bar": {"n": "Silver bar", "cat": "bar", "price": 120, "d": "Smelted at the workbench."},
	"gold_bar": {"n": "Gold bar", "cat": "bar", "price": 240, "d": "Smelted at the workbench."},
	# hunting
	"meat": {"n": "Game meat", "cat": "game", "price": 24, "d": "For the pot."},
	"feather": {"n": "Feather", "cat": "game", "price": 6, "d": "Fletching for arrows, or a hat."},
	"hide": {"n": "Hide", "cat": "game", "price": 30, "d": "Ash tans them into leather."},
	"antler": {"n": "Antler", "cat": "game", "price": 70, "d": "Shed by the highland deer."},
	# the cook pot
	"veg_stew": {"n": "Vegetable stew", "cat": "meal", "price": 70, "d": "Warms you to your boots."},
	"mushroom_soup": {"n": "Mushroom soup", "cat": "meal", "price": 75, "d": "Earthy and rich."},
	"pumpkin_soup": {"n": "Pumpkin soup", "cat": "meal", "price": 260, "d": "The colour of a sunset."},
	"berry_pie": {"n": "Blackberry pie", "cat": "meal", "price": 110, "d": "Stains everything purple."},
	"strawberry_tart": {"n": "Strawberry tart", "cat": "meal", "price": 160, "d": "Too pretty to eat. Nearly."},
	"roast_dinner": {"n": "Roast dinner", "cat": "meal", "price": 190, "d": "Meat, potatoes, carrots and gravy."},
	"bread_loaf": {"n": "Farmhouse loaf", "cat": "meal", "price": 60, "d": "Crusty, from your own wheat."},
	# crafted goods
	"twine": {"n": "Twine", "cat": "craft", "price": 20, "d": "Twisted straw. Counts as rope for building."},
	"scrap_bundle": {"n": "Iron scrap", "cat": "craft", "price": 30, "d": "Counts as scrap metal for building."},
	"compost": {"n": "Compost", "cat": "craft", "price": 8, "d": "Dig it into a bed: crops grow half again as fast."},
	"arrows": {"n": "Arrows", "cat": "craft", "price": 2, "d": "Five to a bundle."},
	"ember_lantern": {"n": "Ember lantern", "cat": "craft", "price": 400, "d": "A crystal that glows like a coal and never goes out."},
	"ember_charm": {"n": "Ember charm", "cat": "craft", "price": 300, "d": "Warm in your pocket. Said to bring luck."},
	"old_map": {"n": "Gran's hill map", "cat": "craft", "price": 0, "d": "Gran's own map of the hills, with the old quarries marked."},
}

# Tools: kind -> tiers (the item id for each tier, its name and what it does)
const TOOLS := {
	"hoe": [{"id": "hoe", "n": "Garden hoe"}],
	"can": [{"id": "watering_can", "n": "Watering can"}],
	"axe": [{"id": "axe_stone", "n": "Stone axe", "wood": 2}, {"id": "axe_copper", "n": "Copper axe", "wood": 3},
		{"id": "axe_iron", "n": "Iron axe", "wood": 4}],
	"pick": [{"id": "pick_stone", "n": "Stone pickaxe"}, {"id": "pick_copper", "n": "Copper pickaxe"},
		{"id": "pick_iron", "n": "Iron pickaxe"}, {"id": "pick_silver", "n": "Silver pickaxe"}],
	"bow": [{"id": "bow", "n": "Hunting bow", "aim": 1.0}, {"id": "bow_fine", "n": "Yew longbow", "aim": 1.5}],
}

# minutes of watered growing (one real second is one town minute), how many you get
const CROPS := {
	"turnip": {"grow": 360, "yield": [2, 3], "xp": 8},
	"carrot": {"grow": 600, "yield": [2, 3], "xp": 12},
	"wheat": {"grow": 540, "yield": [3, 4], "xp": 10},
	"potato": {"grow": 840, "yield": [2, 4], "xp": 14},
	"strawberry": {"grow": 1200, "yield": [3, 5], "xp": 22},
	"pumpkin": {"grow": 1800, "yield": [1, 1], "xp": 40},
}
const CROP_ORDER := ["turnip", "carrot", "wheat", "potato", "strawberry", "pumpkin"]
const WATER_MINUTES := 720  # a watering lasts half a town day; rain waters for you

# Rocks to mine: what's inside, the pickaxe they need (1 = stone), XP.
const ORES := {
	"stone": {"n": "Rock", "tier": 1, "drops": [["stone", 1.0, 2, 4]], "xp": 4},
	"coal": {"n": "Coal seam", "tier": 1, "drops": [["coal", 1.0, 1, 3], ["stone", 0.6, 1, 2]], "xp": 7},
	"copper": {"n": "Copper vein", "tier": 1, "drops": [["copper_ore", 1.0, 1, 3], ["stone", 0.5, 1, 2]], "xp": 9},
	"iron": {"n": "Iron vein", "tier": 2, "drops": [["iron_ore", 1.0, 1, 3], ["coal", 0.3, 1, 1]], "xp": 14},
	"silver": {"n": "Silver vein", "tier": 3, "drops": [["silver_ore", 1.0, 1, 2], ["quartz", 0.25, 1, 1]], "xp": 22},
	"gold": {"n": "Gold vein", "tier": 3, "drops": [["gold_ore", 1.0, 1, 2], ["quartz", 0.2, 1, 1]], "xp": 30},
	"amethyst": {"n": "Amethyst geode", "tier": 2, "drops": [["amethyst", 1.0, 1, 1], ["stone", 1.0, 1, 3]], "xp": 26},
	"crystal": {"n": "Ember crystal", "tier": 3, "drops": [["ember_crystal", 1.0, 1, 1], ["gold_ore", 0.3, 1, 1]], "xp": 45},
}
# Where the rocks are: a centre, a radius, how many, and which kinds (weighted).
const QUARRIES := [
	{"id": "point", "n": "the rocks south of Gran's hut", "x": 430.0, "z": 700.0, "r": 45.0, "count": 7,
		"kinds": {"stone": 5, "coal": 2, "copper": 3}},
	{"id": "willow", "n": "the Willowford hills", "x": 300.0, "z": 205.0, "r": 45.0, "count": 8,
		"kinds": {"stone": 3, "coal": 3, "copper": 2, "iron": 4}},
	{"id": "high", "n": "the highlands", "x": 225.0, "z": 150.0, "r": 55.0, "count": 8,
		"kinds": {"stone": 2, "iron": 3, "silver": 4, "coal": 1}},
	{"id": "gullrock", "n": "Gull Rock", "x": 572.0, "z": 470.0, "r": 10.0, "count": 3,
		"kinds": {"copper": 2, "amethyst": 2}},
	{"id": "cove", "n": "Wrecker's Cove", "x": 1086.0, "z": 214.0, "r": 32.0, "count": 5,
		"kinds": {"iron": 3, "coal": 2, "silver": 1}},
	{"id": "ember", "n": "Ember Isle", "x": 1066.0, "z": 872.0, "r": 38.0, "count": 6,
		"kinds": {"gold": 3, "crystal": 2, "iron": 1}},
]

# Animals: where they live, how hard they are to hit (the aim zone's width, 0-1), drops.
const ANIMALS := {
	"rabbit": {"n": "rabbit", "px": 1.0 / 30.0, "zone": 0.16, "speed": 4.5, "xp": 8,
		"drops": [["meat", 1.0, 1, 1], ["hide", 0.35, 1, 1]], "where": "grass"},
	"pheasant": {"n": "pheasant", "px": 1.0 / 30.0, "zone": 0.15, "speed": 4.0, "xp": 10,
		"drops": [["meat", 1.0, 1, 1], ["feather", 1.0, 2, 4]], "where": "grass"},
	"duck": {"n": "duck", "px": 1.0 / 30.0, "zone": 0.14, "speed": 3.0, "xp": 10,
		"drops": [["meat", 1.0, 1, 1], ["feather", 1.0, 2, 3]], "where": "water"},
	"boar": {"n": "wild boar", "px": 1.0 / 26.0, "zone": 0.13, "speed": 5.0, "xp": 18,
		"drops": [["meat", 1.0, 2, 3], ["hide", 1.0, 1, 1]], "where": "forest"},
	"deer": {"n": "red deer", "px": 1.0 / 24.0, "zone": 0.1, "speed": 6.0, "xp": 28,
		"drops": [["meat", 1.0, 2, 3], ["hide", 1.0, 1, 2], ["antler", 0.6, 1, 1]], "where": "high"},
}

# Forage that pops up near you, by ground. (Bushes give berries and ferns herbs too.)
const FORAGE := {
	"forest": [["mushroom", 5], ["chanterelle", 1], ["herbs", 2]],
	"grass": [["wildflowers", 4], ["herbs", 3], ["mushroom", 1]],
}

const SKILLS := {
	"farming": {"n": "Farming", "d": "Better harvests: one more crop per bed every three levels"},
	"foraging": {"n": "Foraging", "d": "More from every tree, bush and patch of herbs"},
	"mining": {"n": "Mining", "d": "Every swing turns up a little more ore"},
	"hunting": {"n": "Hunting", "d": "A steadier aim: the bow's sweet spot grows"},
	"crafting": {"n": "Crafting", "d": "New recipes as you get better"},
}
const SKILL_ORDER := ["farming", "foraging", "mining", "hunting", "crafting"]
const SKILL_MAX := 10

# Recipes. at: bench (Gran's workbench), pot (the cook pot). needs: items, plus
# "mat:wood" etc. for building materials. gives: items, "tool:<kind>" (sets that tool's
# tier) or "furniture:<id>". lv: the Crafting level it needs.
const RECIPES := [
	# tools
	{"id": "axe_stone", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 3, "stone": 3}, "gives": {"tool:axe": 1}, "lv": 1},
	{"id": "pick_stone", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 3, "stone": 4}, "gives": {"tool:pick": 1}, "lv": 1},
	{"id": "bow", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 5, "twine": 2}, "gives": {"tool:bow": 1}, "lv": 1},
	{"id": "arrows", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 1, "stone": 1}, "gives": {"arrows": 5}, "lv": 1},
	{"id": "axe_copper", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 2, "copper_bar": 2}, "gives": {"tool:axe": 2}, "lv": 2},
	{"id": "pick_copper", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 2, "copper_bar": 3}, "gives": {"tool:pick": 2}, "lv": 2},
	{"id": "axe_iron", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 2, "iron_bar": 2}, "gives": {"tool:axe": 3}, "lv": 3},
	{"id": "pick_iron", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 2, "iron_bar": 3}, "gives": {"tool:pick": 3}, "lv": 2},
	{"id": "bow_fine", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 6, "twine": 3, "feather": 6, "iron_bar": 1}, "gives": {"tool:bow": 2}, "lv": 3},
	{"id": "pick_silver", "at": "bench", "tab": "Tools", "needs": {"mat:wood": 2, "silver_bar": 3}, "gives": {"tool:pick": 4}, "lv": 4},
	# smelting and materials
	{"id": "copper_bar", "at": "bench", "tab": "Smelting", "needs": {"copper_ore": 3, "coal": 1}, "gives": {"copper_bar": 1}, "lv": 1},
	{"id": "iron_bar", "at": "bench", "tab": "Smelting", "needs": {"iron_ore": 3, "coal": 1}, "gives": {"iron_bar": 1}, "lv": 1},
	{"id": "silver_bar", "at": "bench", "tab": "Smelting", "needs": {"silver_ore": 3, "coal": 2}, "gives": {"silver_bar": 1}, "lv": 2},
	{"id": "gold_bar", "at": "bench", "tab": "Smelting", "needs": {"gold_ore": 3, "coal": 2}, "gives": {"gold_bar": 1}, "lv": 3},
	{"id": "twine", "at": "bench", "tab": "Materials", "needs": {"wheat": 3}, "gives": {"twine": 2}, "lv": 1},
	{"id": "rope_from_twine", "n": "Rope (from twine)", "at": "bench", "tab": "Materials", "needs": {"twine": 2}, "gives": {"mat:rope": 1}, "lv": 1},
	{"id": "scrap_bundle", "at": "bench", "tab": "Materials", "needs": {"iron_ore": 2}, "gives": {"mat:scrap": 1}, "lv": 1},
	{"id": "compost", "at": "bench", "tab": "Materials", "needs": {"herbs": 1, "mushroom": 1}, "gives": {"compost": 2}, "lv": 1},
	{"id": "ember_lantern", "at": "bench", "tab": "Materials", "needs": {"ember_crystal": 1, "iron_bar": 2, "quartz": 1}, "gives": {"ember_lantern": 1}, "lv": 2},
	{"id": "ember_charm", "at": "bench", "tab": "Materials", "needs": {"ember_crystal": 1, "gold_bar": 1}, "gives": {"ember_charm": 1}, "lv": 4},
	# furniture for your hut
	{"id": "chair", "at": "bench", "tab": "Furniture", "needs": {"mat:wood": 5}, "gives": {"furniture:chair": 1}, "lv": 1},
	{"id": "hay_bale", "at": "bench", "tab": "Furniture", "needs": {"wheat": 6, "twine": 1}, "gives": {"furniture:hay_bale": 1}, "lv": 1},
	{"id": "planter", "at": "bench", "tab": "Furniture", "needs": {"mat:wood": 6, "herbs": 4}, "gives": {"furniture:planter": 1}, "lv": 1},
	{"id": "flower_vase", "at": "bench", "tab": "Furniture", "needs": {"stone": 4, "wildflowers": 5}, "gives": {"furniture:flower_vase": 1}, "lv": 1},
	{"id": "rocking_chair", "at": "bench", "tab": "Furniture", "needs": {"mat:wood": 12, "hide": 1}, "gives": {"furniture:rocking_chair": 1}, "lv": 2},
	{"id": "scarecrow", "at": "bench", "tab": "Furniture", "needs": {"mat:wood": 4, "wheat": 6, "twine": 2}, "gives": {"furniture:scarecrow": 1}, "lv": 2},
	{"id": "wheat_sheaf", "at": "bench", "tab": "Furniture", "needs": {"wheat": 10, "twine": 1}, "gives": {"furniture:wheat_sheaf": 1}, "lv": 2},
	{"id": "pumpkin_lantern", "at": "bench", "tab": "Furniture", "needs": {"pumpkin": 1}, "gives": {"furniture:pumpkin_lantern": 1}, "lv": 2},
	{"id": "mushroom_lamp", "at": "bench", "tab": "Furniture", "needs": {"chanterelle": 2, "mushroom": 4, "quartz": 1}, "gives": {"furniture:mushroom_lamp": 1}, "lv": 3},
	{"id": "rug_hide", "at": "bench", "tab": "Furniture", "needs": {"hide": 4, "twine": 2}, "gives": {"furniture:rug_hide": 1}, "lv": 3},
	{"id": "copper_pots", "at": "bench", "tab": "Furniture", "needs": {"copper_bar": 3, "mat:wood": 2}, "gives": {"furniture:copper_pots": 1}, "lv": 3},
	{"id": "antler_mount", "at": "bench", "tab": "Furniture", "needs": {"antler": 2, "mat:wood": 4}, "gives": {"furniture:antler_mount": 1}, "lv": 4},
	{"id": "stone_hearth", "at": "bench", "tab": "Furniture", "needs": {"stone": 30, "iron_bar": 2}, "gives": {"furniture:stone_hearth": 1}, "lv": 4},
	{"id": "ore_shelf", "at": "bench", "tab": "Furniture", "needs": {"mat:wood": 8, "quartz": 1, "amethyst": 1, "copper_bar": 1, "silver_bar": 1}, "gives": {"furniture:ore_shelf": 1}, "lv": 4},
	{"id": "crystal_lamp", "at": "bench", "tab": "Furniture", "needs": {"ember_crystal": 1, "iron_bar": 1}, "gives": {"furniture:crystal_lamp": 1}, "lv": 4},
	# the cook pot
	{"id": "veg_stew", "at": "pot", "tab": "Cooking", "needs": {"turnip": 2, "herbs": 1}, "gives": {"veg_stew": 1}, "lv": 1},
	{"id": "mushroom_soup", "at": "pot", "tab": "Cooking", "needs": {"mushroom": 3, "herbs": 1}, "gives": {"mushroom_soup": 1}, "lv": 1},
	{"id": "bread_loaf", "at": "pot", "tab": "Cooking", "needs": {"wheat": 3}, "gives": {"bread_loaf": 1}, "lv": 1},
	{"id": "berry_pie", "at": "pot", "tab": "Cooking", "needs": {"berries": 4, "wheat": 2}, "gives": {"berry_pie": 1}, "lv": 1},
	{"id": "roast_dinner", "at": "pot", "tab": "Cooking", "needs": {"meat": 2, "potato": 2, "carrot": 2}, "gives": {"roast_dinner": 1}, "lv": 2},
	{"id": "strawberry_tart", "at": "pot", "tab": "Cooking", "needs": {"strawberry": 4, "wheat": 2}, "gives": {"strawberry_tart": 1}, "lv": 2},
	{"id": "pumpkin_soup", "at": "pot", "tab": "Cooking", "needs": {"pumpkin": 1, "herbs": 2}, "gives": {"pumpkin_soup": 1}, "lv": 3},
]

# Who buys and sells what.
const MERCHANTS := {
	"bramble": {"n": "Bramble's Garden Stall", "buys": ["crop", "forage", "meal", "seed"],
		"sells": ["seed_turnip", "seed_carrot", "seed_wheat", "seed_potato", "seed_strawberry", "seed_pumpkin", "compost"],
		"tools": {"hoe": 40, "can": 60, "axe": 90}, "beds": true},
	"delve": {"n": "Delve's Forge", "buys": ["ore", "bar", "gem", "craft"], "sells": ["coal", "stone"],
		"tools": {"pick": 150, "axe": 90}},
	"ash": {"n": "Ash's Hunting Camp", "buys": ["game", "meal"], "sells": ["arrows", "feather"],
		"tools": {"bow": 250}},
}
const BED_PRICE := [0, 0, 0, 0, 0, 0, 120, 160, 220, 300, 400, 520]  # beds 7 to 12
const START_BEDS := 6
const MAX_BEDS := 12
# The new folk: name, character sheet, where they stand (x, z), their role.
const FOLK := [
	{"name": "Farmer Bramble", "sheet": "villager_c", "x": 424.5, "z": 690.0, "role": "land:bramble", "town": "gullhaven"},
	{"name": "Delve", "sheet": "salvager", "x": 316.0, "z": 233.0, "role": "land:delve", "town": "willowford"},
	{"name": "Ash", "sheet": "ranger", "x": 334.0, "z": 250.5, "role": "land:ash", "town": "willowford"},
]
# Gran's garden and yard, beside the hut on the point.
const GARDEN := {"x0": 415.0, "z0": 682.0, "cols": 4, "rows": 3, "cell": 2.0}
const BENCH := Vector2(427.0, 683.0)
const POT := Vector2(427.5, 687.0)


static func item_name(id: String) -> String:
	if id.begins_with("mat:"):
		var m := id.substr(4)
		return {"wood": "Wood", "rope": "Rope", "scrap": "Scrap metal"}.get(m, m)
	var it: Dictionary = ITEMS.get(id, {})
	if not it.is_empty():
		return str(it.n)
	for kind in TOOLS:
		for t: Dictionary in TOOLS[kind]:
			if str(t.id) == id:
				return str(t.n)
	return id.capitalize()


static func recipe_name(r: Dictionary) -> String:
	if r.has("n"):
		return str(r.n)
	var id := str(r.id)
	for k in r.gives:
		var key := str(k)
		if key.begins_with("furniture:"):
			var Furniture := load("res://scripts/furniture.gd")
			var fi: Dictionary = Furniture.ITEMS.get(key.substr(10), {})
			return str(fi.get("n", id))
	return item_name(id)


static func icon(id: String) -> Texture2D:
	var path := "res://art/land/icons/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null


## XP to go from one skill level to the next.
static func skill_need(lv: int) -> int:
	return int(round(30.0 * pow(float(lv), 1.35) + 20.0))
