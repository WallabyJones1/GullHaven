extends RefCounted
## Everything you can put in your hut, what it costs and where it's sold, the materials
## (driftwood, rope, scrap metal) and the hut's upgrades.
## kind: "floor" stands on the floor (cells are 0.5 m), "rug" lies under things, "wall"
## hangs on a wall (y is the height of its bottom edge).

const Homes := preload("res://scripts/token/homes.gd")

const CELL := 0.5
const MATERIALS := {
	"wood": {"n": "Driftwood", "price": 25, "d": "Planks and beach timber. Gather it on sandy shores."},
	"rope": {"n": "Rope", "price": 30, "d": "Old line and net cord. Tangled line turns up when fishing."},
	"scrap": {"n": "Scrap metal", "price": 35, "d": "Tins, tyres and trolleys. Fish up junk to collect it."},
}
const ITEMS := {
	"table": {"n": "Table and stools", "kind": "floor", "cells": Vector2i(3, 2), "shop": "carpenter", "price": 60, "mats": {"wood": 6}},
	"bed": {"n": "Spare bed", "kind": "floor", "cells": Vector2i(3, 4), "shop": "carpenter", "price": 120, "mats": {"wood": 10, "rope": 2}},
	"bookshelf": {"n": "Bookshelf", "kind": "floor", "cells": Vector2i(3, 1), "shop": "carpenter", "price": 80, "mats": {"wood": 12}},
	"crates": {"n": "Crates", "kind": "floor", "cells": Vector2i(2, 2), "shop": "carpenter", "price": 20, "mats": {"wood": 4}},
	"barrels": {"n": "Barrels", "kind": "floor", "cells": Vector2i(2, 3), "shop": "carpenter", "price": 40, "mats": {"wood": 6, "scrap": 1}},
	"rod_rack": {"n": "Rod rack", "kind": "wall", "y": 0.0, "shop": "carpenter", "price": 60, "mats": {"wood": 8, "rope": 2}},
	"window": {"n": "Window", "kind": "wall", "y": 0.9, "shop": "carpenter", "price": 100, "mats": {"wood": 4}},
	"fireplace": {"n": "Fireplace", "kind": "wall", "y": 0.0, "shop": "carpenter", "price": 400, "mats": {"wood": 10, "scrap": 6}},
	"stove": {"n": "Iron stove", "kind": "floor", "cells": Vector2i(2, 2), "shop": "home", "price": 300, "mats": {"scrap": 4}},
	"clock": {"n": "Grandfather clock", "kind": "floor", "cells": Vector2i(1, 1), "shop": "home", "price": 450, "mats": {}},
	"plant_fern": {"n": "Potted fern", "kind": "floor", "cells": Vector2i(1, 1), "shop": "home", "price": 60, "mats": {}},
	"plant_flower": {"n": "Flowering plant", "kind": "floor", "cells": Vector2i(1, 1), "shop": "home", "price": 80, "mats": {}},
	"rug_red": {"n": "Red rug", "kind": "rug", "cells": Vector2i(5, 4), "shop": "home", "price": 150, "mats": {}},
	"rug_blue": {"n": "Blue rug", "kind": "rug", "cells": Vector2i(5, 4), "shop": "home", "price": 150, "mats": {}},
	"rug_green": {"n": "Green rug", "kind": "rug", "cells": Vector2i(5, 4), "shop": "home", "price": 150, "mats": {}},
	"painting_sea": {"n": "Seascape painting", "kind": "wall", "y": 1.5, "shop": "home", "price": 200, "mats": {}},
	"painting_boat": {"n": "Boat painting", "kind": "wall", "y": 1.5, "shop": "home", "price": 200, "mats": {}},
	"portrait": {"n": "Founder's portrait", "kind": "wall", "y": 1.5, "shop": "home", "price": 260, "mats": {}},
	"chart": {"n": "Sea chart", "kind": "wall", "y": 1.3, "shop": "home", "price": 120, "mats": {}},
	"lantern": {"n": "Wall lantern", "kind": "wall", "y": 1.9, "shop": "home", "price": 90, "mats": {}},
	"tank": {"n": "Fish tank", "kind": "floor", "cells": Vector2i(3, 2), "shop": "home", "price": 900, "mats": {"scrap": 4}},
	"boat_model": {"n": "Model boat", "kind": "floor", "cells": Vector2i(2, 2), "shop": "home", "price": 600, "mats": {}},
	"ship_wheel": {"n": "Ship's wheel", "kind": "wall", "y": 1.4, "shop": "salvager", "price": 250, "mats": {}},
	"anchor": {"n": "Old anchor", "kind": "wall", "y": 1.2, "shop": "salvager", "price": 300, "mats": {}},
	"life_ring": {"n": "Life ring", "kind": "wall", "y": 1.6, "shop": "salvager", "price": 80, "mats": {}},
	"net_wall": {"n": "Fishing net", "kind": "wall", "y": 1.0, "shop": "salvager", "price": 100, "mats": {"rope": 2}},
	"telescope": {"n": "Telescope", "kind": "floor", "cells": Vector2i(1, 1), "shop": "salvager", "price": 500, "mats": {}},
}
# The hut's upgrades, built by Tess the carpenter. Each comes with a housewarming gift.
const HUT := [
	{"n": "Beach shack", "price": 0, "mats": {}, "gift": [], "d": "Four walls and a leaky roof. Home."},
	{"n": "Snug cabin", "price": 800, "mats": {"wood": 20, "rope": 5}, "gift": ["table", "crates"],
		"d": "A proper cabin with room for a table. Comes with a table and some crates."},
	{"n": "Fisher's cottage", "price": 4000, "mats": {"wood": 50, "rope": 12, "scrap": 10}, "gift": ["bookshelf", "rug_blue"],
		"d": "Plastered walls and twice the room. Comes with a bookshelf and a rug."},
	{"n": "Harbour lodge", "price": 15000, "mats": {"wood": 120, "rope": 25, "scrap": 30}, "gift": ["fireplace", "clock"],
		"d": "Stone walls and space to spare. Comes with a fireplace and a clock."},
]


static func cost_text(price: int, mats: Dictionary) -> String:
	var parts: Array[String] = []
	if price > 0:
		parts.append("%d Shells" % price)
	for k in ["wood", "rope", "scrap"]:
		if int(mats.get(k, 0)) > 0:
			parts.append("%d %s" % [int(mats[k]), str(MATERIALS[k].n).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "Free"


## Can you pay this? Returns "" if so, or what you're short of.
static func short_of(save: Dictionary, price: int, mats: Dictionary) -> String:
	var need: Array[String] = []
	if int(save.shells) < price:
		need.append("%d Shells" % (price - int(save.shells)))
	var have: Dictionary = save.materials
	for k in mats:
		var gap := int(mats[k]) - int(have.get(k, 0))
		if gap > 0:
			need.append("%d %s" % [gap, str(MATERIALS[k].n).to_lower()])
	return "" if need.is_empty() else "You need %s more." % " and ".join(need)


static func pay(save: Dictionary, price: int, mats: Dictionary) -> void:
	save.shells = int(save.shells) - price
	var have: Dictionary = save.materials
	for k in mats:
		have[k] = int(have.get(k, 0)) - int(mats[k])


static func give(save: Dictionary, id: String, n := 1) -> void:
	var inv: Dictionary = save.furniture_inv
	inv[id] = int(inv.get(id, 0)) + n


## A floor item's footprint in metres (turned a quarter for odd rotations).
static func footprint(id: String, rot: int) -> Vector2:
	var it := data(id)
	var c: Vector2i = it.get("cells", Vector2i(2, 2))
	if rot % 2 == 1:
		return Vector2(c.y, c.x) * CELL
	return Vector2(c.x, c.y) * CELL


## How wide a wall item is along its wall, in metres (from its sprite).
static func wall_width(id: String) -> float:
	var path := "res://art/decor/%s.png" % sprite(id)
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		return t.get_width() / 32.0
	return 1.0


## Any piece you can own and place: the hut's own (ITEMS) or one from the Home Catalogue
## ("sofa@red", Harbour economy build). {} if it's neither.
static func data(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	return Homes.data(id)


## The decor sprite for a piece (art/decor/<sprite>.png).
static func sprite(id: String) -> String:
	if ITEMS.has(id):
		return id
	return str(Homes.data(id).get("sprite", id))
