"""The home catalogue for the Harbour economy build: every piece of furniture in every
colour, the wallpapers and floors, and the plot districts. Writes godot/data/home_catalog.json,
which the game reads (scripts/token/homes.gd) and tools/godot_home_art.py draws from.

Usage: python3 tools/godot_home_catalog.py

Sprites are named "<base>_<colour>" and live in godot/art/decor/home/; textures are
"wall_<pattern>_<colour>" / "floor_<kind>_<colour>" in godot/art/tex/home/.
Cells are 0.5 m (16 px at 32 px to the metre). Prices are in Shells unless "gull" is given.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "data", "home_catalog.json")

# base colour for each colour key (the art tool builds lit ramps from these)
COLOURS = {
    "red": "#c8423c", "orange": "#e07a2e", "yellow": "#e8c03a", "green": "#5a9e48", "teal": "#2f9e94",
    "blue": "#3f6fc8", "purple": "#7b4fc0", "pink": "#e07aa8", "cream": "#e8dcc0", "charcoal": "#3c3f48",
    "oak": "#b8864a", "walnut": "#6e4426", "pale": "#d8bc8c", "white": "#ecebe6", "black": "#2a2a30",
    "steel": "#9aa4ae", "brass": "#c8a040", "terracotta": "#c0623a",
    "gold": "#d8b040", "silver": "#c0c8d0", "bronze": "#b07040",
    "gradient": "#9945ff",  # purple-to-mint, the crypto colours (never the Solana logo)
}
NAMES = {"gradient": "Gradient", "terracotta": "Terracotta"}

FABRIC = ["red", "orange", "yellow", "green", "teal", "blue", "purple", "pink", "cream", "charcoal"]
WOOD = ["oak", "walnut", "pale", "white", "black"]
KITCHEN = ["white", "cream", "teal", "red", "charcoal", "pink"]
BATH = ["white", "cream", "pink", "teal", "charcoal"]
NEON = ["pink", "blue", "green", "orange", "purple", "gradient"]
POTS = ["terracotta", "white", "teal", "charcoal", "yellow"]
POSTER = ["red", "blue", "teal", "yellow", "purple", "gradient"]

# id, name, category, kind, cells (floor/rug) or y (wall), price, colours, description
F, R, W = "floor", "rug", "wall"
ITEMS = [
    # living room
    ("sofa", "Sofa", "Living room", F, (4, 2), 300, FABRIC, "A deep three-seater for long evenings."),
    ("armchair", "Armchair", "Living room", F, (2, 2), 180, FABRIC, "The comfy chair by the fire."),
    ("beanbag", "Beanbag", "Living room", F, (2, 2), 90, FABRIC, "Squashy and impossible to get out of."),
    ("coffee_table", "Coffee table", "Living room", F, (3, 2), 120, WOOD, "Room for a mug and a tide table."),
    ("side_table", "Side table", "Living room", F, (1, 1), 60, WOOD, "A little table for a lamp."),
    ("tv_retro", "Retro TV", "Living room", F, (2, 1), 400, ["walnut", "cream", "charcoal", "red"], "Two channels: weather and more weather."),
    ("radio", "Valve radio", "Living room", F, (1, 1), 150, ["walnut", "cream", "red", "teal"], "Plays the shipping forecast."),
    ("bookcase_tall", "Tall bookcase", "Living room", F, (3, 1), 160, WOOD, "Floor-to-ceiling books."),
    ("rug_round", "Round rug", "Living room", R, (4, 4), 120, FABRIC, "A soft round rug."),
    ("rug_stripe", "Striped rug", "Living room", R, (5, 3), 140, FABRIC, "A woven rug with stripes."),
    # bedroom
    ("double_bed", "Double bed", "Bedroom", F, (4, 5), 450, FABRIC, "A big bed with a patchwork quilt."),
    ("bunk_bed", "Bunk beds", "Bedroom", F, (2, 4), 380, WOOD, "For sleepovers."),
    ("wardrobe", "Wardrobe", "Bedroom", F, (3, 1), 260, WOOD, "Holds every outfit you own."),
    ("dresser", "Dresser", "Bedroom", F, (3, 1), 200, WOOD, "Drawers with brass handles."),
    ("nightstand", "Nightstand", "Bedroom", F, (1, 1), 70, WOOD, "For your alarm clock and a glass of water."),
    # kitchen and dining
    ("kitchen_counter", "Kitchen counter", "Kitchen", F, (2, 1), 160, KITCHEN, "Cupboards below, worktop above."),
    ("kitchen_sink", "Kitchen sink", "Kitchen", F, (2, 1), 180, KITCHEN, "With a window-shaped view of the sea."),
    ("fridge", "Fridge", "Kitchen", F, (2, 1), 350, KITCHEN, "Keeps the catch fresh."),
    ("oven_retro", "Retro oven", "Kitchen", F, (2, 1), 320, KITCHEN, "Four rings and a grill."),
    ("dining_table", "Dining table", "Kitchen", F, (4, 3), 220, WOOD, "Seats six, or four fishers and a cat."),
    ("dining_chair", "Dining chair", "Kitchen", F, (1, 1), 50, WOOD, "A sturdy chair."),
    ("round_table", "Round table", "Kitchen", F, (3, 3), 180, WOOD, "For card games and chowder."),
    ("bar_stool", "Bar stool", "Kitchen", F, (1, 1), 60, ["red", "teal", "charcoal", "yellow", "steel"], "Spins round."),
    # bathroom
    ("bathtub", "Bathtub", "Bathroom", F, (4, 2), 420, BATH, "A claw-foot tub."),
    ("toilet", "Toilet", "Bathroom", F, (1, 2), 150, BATH, "Every home needs one."),
    ("shower", "Shower", "Bathroom", F, (2, 2), 300, BATH, "Hot water after a cold morning at sea."),
    ("basin", "Basin", "Bathroom", F, (1, 1), 140, BATH, "A pedestal basin."),
    # lights
    ("floor_lamp", "Floor lamp", "Lights", F, (1, 1), 90, FABRIC, "A tall lamp with a fabric shade."),
    ("table_lamp", "Table lamp", "Lights", F, (1, 1), 60, FABRIC, "A small lamp."),
    ("lava_lamp", "Lava lamp", "Lights", F, (1, 1), 120, ["red", "orange", "green", "blue", "purple", "pink", "gradient"], "Blobs go up, blobs come down."),
    ("string_lights", "String lights", "Lights", W, 2.4, 80, ["yellow", "pink", "blue", "green", "gradient"], "Fairy lights along the wall."),
    ("neon_fish", "Neon fish", "Lights", W, 1.5, 300, NEON, "A glowing fish sign."),
    ("neon_gm", "Neon GM", "Lights", W, 1.5, 300, NEON, "Good morning, harbour."),
    ("neon_heart", "Neon heart", "Lights", W, 1.5, 260, NEON, "A glowing heart."),
    # fun
    ("jukebox", "Jukebox", "Fun", F, (2, 1), 900, ["red", "teal", "purple", "yellow", "gradient"], "Sea shanties, mostly."),
    ("arcade", "Arcade cabinet", "Fun", F, (2, 2), 1200, ["red", "blue", "purple", "green", "gradient"], "High score: GULL."),
    ("piano", "Upright piano", "Fun", F, (3, 2), 1500, ["black", "white", "walnut", "red"], "Slightly out of tune."),
    ("guitar_stand", "Guitar", "Fun", F, (1, 1), 350, ["red", "blue", "yellow", "black", "cream"], "An acoustic on a stand."),
    ("pool_table", "Pool table", "Fun", F, (5, 3), 1100, ["green", "blue", "red", "purple"], "Eight-ball by the sea."),
    ("fish_bowl", "Fish bowl", "Fun", F, (1, 1), 120, ["blue", "teal", "green", "pink"], "One goldfish, named Admiral."),
    ("cat_bed", "Cat bed", "Fun", F, (2, 2), 80, FABRIC, "Your cat might even use it."),
    ("gaming_desk", "Desk and computer", "Fun", F, (3, 2), 500, ["charcoal", "white", "pink", "gradient"], "Two screens: one chart, one game."),
    # plants
    ("potted_palm", "Potted palm", "Plants", F, (1, 1), 110, POTS, "A little bit of the tropics."),
    ("cactus", "Cactus", "Plants", F, (1, 1), 70, POTS, "Needs almost no looking after."),
    ("flower_vase", "Flowers in a vase", "Plants", F, (1, 1), 60, ["red", "yellow", "pink", "purple", "blue", "white"], "Fresh from the market."),
    ("bonsai", "Bonsai", "Plants", F, (1, 1), 220, POTS, "A tiny, very old tree."),
    ("monstera", "Monstera", "Plants", F, (2, 2), 150, POTS, "Big leaves with holes in."),
    # wall decor
    ("curtains", "Curtains", "Wall decor", W, 0.6, 90, FABRIC, "A pair of curtains with a pelmet."),
    ("poster_wave", "Wave poster", "Wall decor", W, 1.3, 60, POSTER, "The big wave."),
    ("poster_gull", "Gull poster", "Wall decor", W, 1.3, 60, POSTER, "Gullhaven's finest."),
    ("poster_moon", "To the Moon poster", "Wall decor", W, 1.3, 80, POSTER, "A rocket and a full moon."),
    ("poster_candles", "Green candles poster", "Wall decor", W, 1.3, 80, POSTER, "A chart that only goes up."),
    ("wall_shelf", "Wall shelf", "Wall decor", W, 1.4, 70, WOOD, "For trinkets and shells."),
    ("wall_clock", "Wall clock", "Wall decor", W, 1.9, 90, ["red", "blue", "yellow", "cream", "black", "brass"], "Tick, tock."),
    ("surfboard", "Surfboard", "Wall decor", W, 0.3, 250, ["red", "orange", "yellow", "teal", "pink", "gradient"], "For the one good wave a year."),
    ("trophy_fish", "Trophy fish", "Wall decor", W, 1.4, 400, ["gold", "silver", "bronze"], "The one that didn't get away."),
    ("mirror_round", "Round mirror", "Wall decor", W, 1.1, 160, ["brass", "black", "white", "oak"], "Looking good, fisher."),
]

WALL_PATTERNS = [
    ("plain", "Plain", 80), ("stripes", "Stripes", 100), ("flowers", "Flowers", 120), ("checks", "Checks", 100),
    ("dots", "Polka dots", 100), ("waves", "Waves", 120), ("brick", "Brick", 140), ("panels", "Wood panels", 140),
]
WALL_COLOURS = ["cream", "red", "yellow", "green", "teal", "blue", "purple", "pink", "charcoal"]
FLOORS = [
    ("planks", "Planks", 150, WOOD),
    ("tiles", "Tiles", 160, ["red", "blue", "teal", "green", "charcoal", "cream"]),
    ("carpet", "Carpet", 140, FABRIC),
    ("stone", "Stone", 180, ["steel", "cream", "terracotta"]),
    ("marble", "Marble", 260, ["white", "black", "pink"]),
    ("chequer", "Chequerboard", 200, ["black", "red", "blue", "green"]),
]

# Season 1 plots (the token plan): district, prefix, how many, room size (m), price in $GULL
DISTRICTS = [
    {"id": "harbourfront", "n": "Harbourfront", "prefix": "H", "count": 60, "room": [13, 10], "gull": 12000,
     "d": "On the water, by the harbour lights. The biggest homes in town."},
    {"id": "village", "n": "Village", "prefix": "V", "count": 240, "room": [10, 8], "gull": 4000,
     "d": "In the lanes behind the square, near the bakery and the tavern."},
    {"id": "hillside", "n": "Hillside", "prefix": "L", "count": 300, "room": [8, 7], "gull": 1500,
     "d": "Up the hill with a view of the bay. Cosy, and the cheapest way in."},
]


def colour_name(c):
    return NAMES.get(c, c.capitalize())


def main():
    items = []
    for base, name, cat, kind, size, price, colours, desc in ITEMS:
        it = {"base": base, "n": name, "cat": cat, "kind": kind, "price": price, "colours": colours, "d": desc}
        if kind == W:
            it["y"] = size
        else:
            it["cells"] = list(size)
        items.append(it)
    walls = [{"pattern": p, "n": n, "price": price, "colours": WALL_COLOURS} for p, n, price in WALL_PATTERNS]
    floors = [{"kind": k, "n": n, "price": price, "colours": cs} for k, n, price, cs in FLOORS]
    data = {
        "colours": COLOURS,
        "colour_names": {c: colour_name(c) for c in COLOURS},
        "categories": sorted({i["cat"] for i in items}, key=[i[2] for i in ITEMS].index),
        "items": items,
        "walls": walls,
        "floors": floors,
        "districts": DISTRICTS,
    }
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
    sprites = sum(len(i["colours"]) for i in items)
    textures = sum(len(w["colours"]) for w in walls) + sum(len(fl["colours"]) for fl in floors)
    print(f"{len(items)} pieces in {sprites} colourways, {textures} wallpapers and floors, "
          f"{sum(d['count'] for d in DISTRICTS)} plots -> {OUT}")


if __name__ == "__main__":
    main()
