"""Gullhaven HD-2D: catalogue additions for the Godot build.
Usage: python3 tools/godot_catalog_extra.py [--preview]

Adds new fish for every fishing ground, new legends (two of them part of the Gull's Eye
mystery), and new things to collect: fossils from the rock pools, more sea glass, and finds
that only wash up on particular islands. Writes godot/data/catalog_extra.json (same format
as catalog.json, which sea.gd merges in) and draws every new entry's art into
godot/art/fish2/: fish with the parametric fish painter from godot_art.py, the rest with
the small icon painters below."""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_art import OUT, PREVIEW, Canvas, draw_fish, ellipse, hashmap, hx, poly, ramp, rect, shift  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZONE_NAMES = {'harbour': 'Harbour and Piers', 'shallows': 'Sandy Shallows', 'estuary': 'Mangrove Estuary', 'reef': 'Coral Reef',
              'kelp': 'Kelp Forest', 'wreck': 'Wreck Graveyard', 'blue': 'Open Blue', 'deep': 'The Deep', 'lake': 'Mirrorlake',
              'seagrass': 'Seagrass Meadows', 'lagoon': 'Turquoise Lagoon'}
FISH_PRICE = [12, 35, 110, 380, 2500]
FIND_PRICE = [10, 40, 150, 600, 1500]
TIMES = {'day', 'night', 'dawn', 'dusk', 'dawn/dusk', 'dusk/night', 'midnight'}
TIDES = {'rising', 'falling', 'high', 'low', 'kingtide'}
SKIES = {'calm', 'windy', 'rain', 'fog', 'storm', 'afterstorm'}
SEASONS = {'spring', 'summer', 'autumn', 'winter'}
MOONS = {'fullmoon', 'newmoon'}

# name, zone, rarity, conditions, size cm, look (shape|back|flank|belly|pattern|pattern colour|fin colour|mods), what it's like
FISH = [
    # Harbour and Piers
    ('Mado', 'harbour', 0, 'day', (12, 20), 'deep|#c8a040|#e8d070|#f4ecc0|stripes|#3a2a20|#e0c050|', 'Striped little sweep that hangs round the pylons'),
    ('Silver Biddy', 'harbour', 0, '', (10, 20), 'torp|#a8b8c0|#d8e0e4|#f4f8f8|none|#000|#c8d0d8|slim', 'A flash of silver under the jetty'),
    ('Port Herring', 'harbour', 0, 'dawn', (15, 25), 'torp|#4a7aa0|#a8c8d8|#e8f0f4|lat|#2a4a6a|#8ab0c8|slim', 'Schools in their thousands on still mornings'),
    ('Fanbelly Leatherjacket', 'harbour', 0, '', (15, 30), 'jacket|#8a7a4a|#b8a870|#e0d8b0|spots|#4a3a20|#a89060|', 'Nibbles bait right off the hook'),
    ('Black Bream', 'harbour', 1, 'dusk/night', (22, 45), 'deep|#3a3a34|#7a7a6a|#c8c4b0|scales|#2a2a24|#5a5a4a|', 'Cagey and strong, the harbour regular\'s favourite'),
    ('Eastern Fortescue', 'harbour', 1, 'night', (8, 15), 'lion|#7a5a4a|#a87a5a|#d8c0a0|blotch|#3a2a20|#8a6a4a|', 'Venomous spines. Handle with care'),
    ('Harbour Pipehorse', 'harbour', 2, 'calm', (15, 25), 'seahorse|#c8a060|#e0c080|#f0e0b0|bars|#6a4a2a|#d0b070|', 'Half seahorse, half pipefish, all shy'),
    # Sandy Shallows
    ('Stout Whiting', 'shallows', 0, 'day', (15, 28), 'torp|#c8b890|#e0d8b8|#f8f4e8|none|#000|#d0c8a0|slim', 'Sweet-eating and easy to please'),
    ('Sand Flathead', 'shallows', 0, '', (25, 45), 'flathead|#c8a878|#e0c898|#f4ecd8|spots|#7a5a3a|#c8a070|', 'Lies buried with only its eyes showing'),
    ('Silver Trevally', 'shallows', 1, 'rising', (30, 70), 'deep|#8aa0b0|#c8d8e0|#f0f4f4|none|#000|#e0c040|', 'Runs hard on the rising tide'),
    ('Long-tom', 'shallows', 1, 'day', (50, 90), 'gar|#3a7a6a|#a8d0c0|#e8f4f0|none|#000|#5a9a8a|long', 'Skitters across the surface like a thrown spear'),
    ('Balmain Bug', 'shallows', 1, 'night', (12, 22), 'lobster|#b07a4a|#d09a6a|#e8c8a0|spots|#6a3a20|#c0805a|', 'A flat little lobster that walks the sand at night'),
    ('Blue-spotted Stingray', 'shallows', 2, 'low', (30, 60), 'ray|#c8a060|#e0c080|#f0e8d0|spots|#3a8ad0|#c8a060|', 'Glides over the flats when the tide is out'),
    ('Golden Sand Eel', 'shallows', 2, 'night calm', (20, 40), 'eel|#d8b050|#f0d070|#f8f0c0|none|#000|#e8c060|', 'Pokes its head out of the sand on calm nights'),
    # Mangrove Estuary
    ('Bony Bream', 'estuary', 0, '', (15, 30), 'deep|#a8a090|#c8c4b0|#e8e4d8|none|#000|#b0a890|', 'All bones, all appetite'),
    ('Flathead Gudgeon', 'estuary', 0, '', (8, 15), 'flathead|#7a6a4a|#a8987a|#d8c8a8|blotch|#4a3a20|#8a7a5a|', 'Hides under every snag in the river'),
    ('River Garfish', 'estuary', 0, 'day', (20, 35), 'gar|#6a8a7a|#b8d0c0|#eef4f0|none|#000|#8aa898|slim', 'Needle-nosed and quick'),
    ('Glass Perchlet', 'estuary', 0, 'night', (3, 6), 'deep|#c8e0d8|#e0f0ec|#f8fffc|lines|#8ab0a8|#d0e8e0|bigeye', 'So clear you can see its heart beat'),
    ('Estuary Perch', 'estuary', 1, 'dusk/night', (25, 50), 'deep|#6a6a4a|#a0a07a|#d8d4b8|scales|#4a4a30|#8a8a60|', 'Ambushes from the mangrove roots at dusk'),
    ('Spotted Scat', 'estuary', 1, 'rising', (15, 30), 'disc|#8a9a6a|#b8c890|#e0e8c8|spots|#2a3a20|#a0b080|', 'Follows the salt water up the river'),
    ('Giant Herring', 'estuary', 2, 'dawn', (60, 110), 'torp|#5a7aa0|#b8c8d8|#f0f4f8|none|#000|#8aa0c0|long', 'Leaps clean out of the water when hooked'),
    # Coral Reef
    ('Moon Wrasse', 'reef', 1, 'day', (15, 25), 'parrot|#3aa07a|#7ad0a0|#c0f0d0|lines|#c84a8a|#5ab08a|', 'Painted in every colour of the reef'),
    ('Yellow Boxfish', 'reef', 1, 'calm', (10, 20), 'puffer|#f0c830|#f8e070|#fff8c0|spots|#2a2a40|#e8c030|', 'A swimming yellow box with polka dots'),
    ('Coral Cod', 'reef', 1, '', (25, 40), 'grouper|#c84a3a|#e07a5a|#f0b090|spots|#3a8ad0|#d05a4a|', 'Red as the coral it guards'),
    ('Harlequin Tuskfish', 'reef', 2, 'day', (25, 45), 'parrot|#3a7ad0|#e8803a|#f0c080|bars|#2a4a90|#d06a2a|', 'Bright blue teeth for crunching shellfish'),
    ('Regal Angelfish', 'reef', 2, '', (15, 25), 'disc|#f0a030|#f8c860|#fff0c0|bars|#3a4ab0|#e89030|', 'Striped like a royal banner'),
    ('Great Barracuda', 'reef', 2, 'dusk', (80, 150), 'gar|#5a6a7a|#a8b8c0|#e8f0f4|bars|#2a3a4a|#7a8a9a|', 'All teeth and patience'),
    ('Mandarin Dragonet', 'reef', 3, 'dusk calm', (5, 8), 'clown|#2a6ad0|#f08a2a|#3ac0a0|wavy|#f0a030|#2a6ad0|', 'The most colourful fish in the sea, and the shyest'),
    # Kelp Forest
    ('Weedfish', 'kelp', 0, '', (10, 20), 'wobbe|#7a6a2a|#a89a4a|#d0c890|blotch|#4a3a10|#8a7a3a|', 'Looks exactly like a scrap of kelp'),
    ('Sea Carp', 'kelp', 0, 'day', (20, 35), 'deep|#8a6a3a|#b8986a|#e0d0b0|bars|#4a3a20|#9a7a4a|', 'Grazes the kelp stems'),
    ('Blue Morwong', 'kelp', 1, '', (30, 60), 'deep|#4a7ab0|#8ab0d0|#d8e8f0|none|#000|#6a9ac0|', 'Big rubbery lips for hoovering up worms'),
    ('Kelp Greenling', 'kelp', 1, 'calm', (25, 45), 'torp|#6a7a3a|#9aaa5a|#d0d8a0|blotch|#3a4a20|#7a8a4a|', 'Green on green, hard to spot'),
    ('Western Blue Devil', 'kelp', 2, 'dusk', (20, 30), 'grouper|#2a4a9a|#4a6ac0|#8aa0e0|spots|#c0e0ff|#2a4a9a|', 'Deep blue and spangled with stars'),
    ('Giant Kelpfish', 'kelp', 2, 'fog', (40, 60), 'eel|#5a6a2a|#8a9a4a|#c0c890|lines|#3a4a10|#6a7a3a|', 'Only shows itself when the fog rolls in'),
    # Wreck Graveyard
    ('Silver Sweep', 'wreck', 0, '', (15, 25), 'deep|#9aa8b0|#c8d4d8|#f0f4f4|none|#000|#a8b8c0|', 'Swarms through the portholes'),
    ('Copper Sweeper', 'wreck', 0, 'night', (10, 18), 'deep|#c87a3a|#e0a060|#f0d0a0|none|#000|#d08a4a|bigeye', 'Big eyes for the dark inside the hulls'),
    ('Wreck Frogfish', 'wreck', 1, '', (15, 30), 'angler|#c86a3a|#e08a5a|#f0c0a0|blotch|#6a2a1a|#d07a4a|', 'Walks on its fins across the decks'),
    ('Wreck Fish', 'wreck', 2, '', (80, 140), 'grouper|#5a5a5a|#8a8a8a|#c8c8c8|blotch|#2a2a2a|#6a6a6a|big', 'Lives in the same wreck for fifty years'),
    ('Painted Crayfish', 'wreck', 2, 'night', (25, 45), 'lobster|#3a8a8a|#5ab0a8|#c0e8e0|spots|#f0e0a0|#4a9a9a|', 'Turquoise armour, painted with gold'),
    ('Ghost Pipefish', 'wreck', 3, 'fog', (8, 12), 'seahorse|#e8e0d0|#f8f4ec|#ffffff|spots|#c8a0a0|#f0e8e0|', 'Drifts like a pale leaf in the fog'),
    # Open Blue
    ('Longtail Tuna', 'blue', 1, '', (50, 100), 'tuna|#2a3a6a|#8aa0c0|#e8f0f4|none|#000|#4a5a8a|', 'Built for speed and never stops'),
    ('Blue Shark', 'blue', 2, '', (150, 250), 'shark|#2a5ab0|#5a8ad0|#e8f0f8|none|#000|#3a6ac0|', 'Sleek, blue and curious about boats'),
    ('Flying Gurnard', 'blue', 2, 'calm', (25, 40), 'flying|#7a5a3a|#c09060|#f0d8b0|spots|#3a8ad0|#a07040|', 'Opens fins like painted wings'),
    ('Blue Marlin', 'blue', 3, 'day calm', (250, 400), 'marlin|#1a3a8a|#4a7ad0|#e0e8f0|bars|#8ac0ff|#2a4aa0|big', 'The great prize of the open ocean'),
    ('Ocean Sunfish', 'blue', 3, 'calm day', (150, 250), 'disc|#8a9aa8|#b0bcc8|#e0e8f0|none|#000|#9aa8b8|big', 'Basks on its side at the surface'),
    ('Opah', 'blue', 3, '', (80, 120), 'disc|#c84a5a|#e87a7a|#f0c0b0|spots|#f0f0ff|#d84a4a|', 'A warm-blooded moonfish, red and silver'),
    # The Deep
    ('Fangtooth', 'deep', 1, '', (12, 18), 'angler|#3a2a2a|#5a3a3a|#7a5a5a|none|#000|#4a3a3a|', 'The biggest teeth for its size in the sea'),
    ('Orange Roughy', 'deep', 1, '', (30, 50), 'deep|#d86a3a|#e88a5a|#f0b090|none|#000|#d07040|bigeye', 'Can live past a hundred years'),
    ('Viperfish', 'deep', 2, 'night', (20, 30), 'gulper|#1a2a3a|#2a4a5a|#3a6a7a|glow|#7af0ff|#1a3a4a|bigeye', 'Lights along its belly lure in prey'),
    ('Dragonfish', 'deep', 2, 'night newmoon', (20, 35), 'ribbon|#1a1a2a|#2a2a4a|#4a4a6a|glow|#ff6ad0|#2a2a3a|', 'Glows pink in the darkest water'),
    ('Barreleye', 'deep', 3, 'midnight', (10, 15), 'lantern|#3a3a4a|#5a6a7a|#8a9aa8|glow|#a0ff8a|#4a5a6a|bigeye', 'Its head is see-through. Its eyes look up'),
    ('Frilled Shark', 'deep', 3, 'night', (120, 180), 'eel|#5a4a3a|#7a6a5a|#a8988a|none|#000|#6a5a4a|sixgill', 'A living fossil older than the dinosaurs'),
    # Mirrorlake
    ('Mountain Galaxias', 'lake', 0, '', (6, 12), 'torp|#7a7a5a|#a8a88a|#d8d8c0|blotch|#4a4a30|#8a8a6a|slim', 'A tiny native fish of the high streams'),
    ('Blackfish', 'lake', 0, 'night', (15, 30), 'deep|#3a3a30|#5a5a4a|#8a8a7a|none|#000|#4a4a3a|', 'Comes out from the reeds after dark'),
    ('Spangled Perch', 'lake', 0, 'day', (15, 25), 'deep|#b0a060|#d0c080|#ecdcb0|spots|#c84a3a|#c0a860|', 'Freckled with red'),
    ('Lake Trout', 'lake', 1, 'dawn/dusk', (40, 70), 'torp|#4a6a5a|#8ab098|#e0ece4|spots|#f0e0c0|#6a8a7a|', 'Rises to the evening hatch'),
    ('Golden Carp', 'lake', 1, 'day calm', (30, 55), 'hump|#d8a030|#f0c050|#f8e8a0|scales|#a07020|#e0b040|', 'Glints gold in the shallows on still days'),
    ('Shortfin Eel', 'lake', 1, 'night rain', (50, 90), 'eel|#4a4a2a|#7a7a4a|#b0b080|none|#000|#5a5a3a|', 'Travels overland on rainy nights'),
    # Seagrass Meadows
    ('Pygmy Leatherjacket', 'seagrass', 0, '', (6, 12), 'jacket|#7a8a3a|#a8b860|#d8e0a0|spots|#3a4a10|#8a9a4a|', 'Hides among the grass blades'),
    ('Spinefoot', 'seagrass', 0, 'day', (20, 35), 'disc|#8a8a5a|#b0b07a|#dcdcb0|spots|#5a5a2a|#9a9a6a|', 'Grazes the meadows like a sheep'),
    ('Weedy Whiting', 'seagrass', 1, 'rising', (18, 30), 'torp|#a8a070|#c8c090|#ecead0|lines|#6a6a3a|#b0a878|slim', 'Feeds along the meadow edges on the flood'),
    ('Rainbow Cale', 'seagrass', 1, 'calm', (20, 35), 'parrot|#5aa07a|#8ad0a0|#d0f0d8|wavy|#e8a03a|#6ab08a|', 'Shimmers with every colour'),
    ('Seagrass Pipefish', 'seagrass', 2, 'calm', (15, 25), 'seahorse|#6a9a4a|#9ac07a|#d0e8b0|bars|#3a5a20|#7aa85a|', 'Sways with the grass so you never see it'),
    # Turquoise Lagoon
    ('Bluestripe Snapper', 'lagoon', 1, 'day', (20, 35), 'deep|#f0d040|#f8e070|#fff8c8|stripes|#3a8ad0|#e8c840|snapper', 'Yellow with electric blue stripes'),
    ('Lagoon Triggerfish', 'lagoon', 1, '', (20, 35), 'trigger|#c8b890|#e0d0a8|#f4ecd8|spots|#3a3a6a|#d0c090|', 'Guards its nest fiercely'),
    ('Blacktip Reef Shark', 'lagoon', 2, 'dusk', (100, 160), 'shark|#8a9aa0|#b0c0c8|#eef4f8|none|#000|#5a6a70|', 'Patrols the lagoon at dusk'),
    ('Starry Puffer', 'lagoon', 2, 'night', (30, 60), 'puffer|#5a6a7a|#8a9aa8|#d8e0e8|spots|#f0f0ff|#6a7a8a|', 'Covered in white stars'),
    ('Golden Trevally', 'lagoon', 2, 'rising', (50, 90), 'deep|#d8b030|#f0d060|#f8f0c0|bars|#3a3a2a|#e0c040|', 'Young ones ride alongside sharks'),
]

# id, name, zone, conditions, size, look, what, quest flag
# Only turn up in crab pots (Kit tab at Hale's Tackle, from fisher level 2).
POTS = [
    ('Harbour Spider Crab', 'harbour', 0, '', (6, 12), 'crab|#8a5a4a|#b07a5a|#e0c0a0|spots|#4a2a20|#a06a4a|', 'Long-legged and grumpy. Lives under the pier'),
    ('Sand Crab', 'shallows', 0, '', (5, 10), 'crab|#d8c098|#e8d8b8|#f8f0e0|spots|#a08060|#d0b890|', 'Pale as the sand it digs into'),
    ('Moreton Bay Bug', 'shallows', 2, 'night', (12, 25), 'lobster|#a8784a|#c89a6a|#e8d0a8|spots|#5a3a20|#b88a5a|', 'A flat-headed lobster, the finest eating on the coast'),
    ('Soldier Crab', 'estuary', 0, 'low', (2, 4), 'crab|#6a8ad0|#9ab0e0|#e0e8f8|none|#000|#5a7ac0|', 'Marches the mudflats in blue armies at low tide'),
    ('Coral Crab', 'reef', 1, 'night', (8, 15), 'crab|#d04a3a|#e8805a|#f8d0b0|spots|#8a2a20|#d0603a|', 'Bright red, and as tough as the reef'),
    ('Painted Rock Lobster', 'reef', 2, 'night', (25, 45), 'lobster|#3a7a9a|#6ab0c0|#e8e0c8|bars|#e0d0a0|#5a9ab0|', 'Blue and gold and every colour between'),
    ('Giant Spider Crab', 'kelp', 1, 'winter', (20, 40), 'crab|#b0604a|#d0886a|#f0c8a8|spots|#6a3020|#c07050|', 'Gathers in the kelp in its thousands each winter'),
    ('Slipper Lobster', 'wreck', 1, '', (15, 30), 'lobster|#8a6a4a|#b08a60|#d8c0a0|spots|#4a3020|#9a7a5a|', 'Flat as a shoe, it hides in the wreck\'s ribs'),
    ('Velvet Swimmer Crab', 'seagrass', 0, '', (6, 12), 'crab|#5a6a4a|#8a9a6a|#d0d8b8|none|#000|#6a8a5a|', 'Soft-shelled and quick in the seagrass'),
    ('Coconut Crab', 'lagoon', 3, 'night', (30, 45), 'crab|#6a3a8a|#9a5aba|#e0c0e0|spots|#3a1a4a|#8a4aaa|', 'The biggest crab of all, and it climbs trees'),
    ('Yabby', 'lake', 0, '', (8, 15), 'lobster|#4a5a6a|#7a8a9a|#c8d0d8|none|#000|#5a6a8a|', 'The freshwater crayfish every kid in the hills has caught'),
    ('Marron', 'lake', 2, 'night', (20, 35), 'lobster|#2a3a5a|#4a6a8a|#a8b8c8|none|#000|#3a5a7a|', 'A giant crayfish, blue-black and very old'),
]

LEGENDS = [
    ('silverjaw', 'Silverjaw', 'lake', 'dawn calm', (110, 140), 'gar|#c8d0d8|#e8eef4|#ffffff|lines|#8a9aa8|#d0d8e0|long',
     'The old pike of Mirrorlake, who never takes a hook twice', 'quest'),
    ('the_warden', 'The Warden', 'deep', 'night', (600, 900), 'oar|#c8a040|#f0d070|#fff4c0|glow|#fff0a0|#e0b040|',
     'A colossal oarfish whose scales burn like the old lens', 'quest'),
    ('the_ember_eel', 'The Ember Eel', 'blue', 'night', (180, 240), 'eel|#c83a1a|#f06a2a|#ffb060|glow|#ffd060|#e04a20|',
     'Glows like a coal in the warm water off Ember Isle', ''),
    ('the_glass_ray', 'The Glass Ray', 'lagoon', 'night calm', (90, 120), 'ray|#d8f0f4|#eef8fc|#ffffff|none|#000|#d8f0f4|',
     'A ray so clear you see the sand through it', ''),
    ('the_kelp_king', 'The Kelp King', 'kelp', 'storm', (150, 200), 'grouper|#3a5a2a|#5a7a3a|#9ab070|blotch|#1a2a10|#4a6a2a|big',
     'A groper wearing a crown of kelp, seen only in storms', ''),
    ('old_mother_bream', 'Old Mother Bream', 'harbour', 'night newmoon', (60, 70), 'deep|#4a4a3a|#8a8a6a|#d0ccb0|scales|#3a3a2a|#6a6a4a|big',
     'Every bream in the harbour is one of her grandchildren', ''),
]

# collectables: name, category, rarity, zone (beach/rocks), island (or ''), conditions, icon (kind, colour), hint
FINDS = [
    ('Crinoid Stem', 'fossil', 0, 'rocks', '', '', ('fossil_stem', '#b8a890'), 'A stone stalk of a sea lily, millions of years old.'),
    ('Belemnite', 'fossil', 0, 'rocks', '', '', ('fossil_bullet', '#a89070'), 'A fossil squid shell, shaped like a bullet.'),
    ('Fern Fossil', 'fossil', 1, 'rocks', '', 'low', ('fossil_fern', '#a8a088'), 'A leaf pressed into the rock. Best at low tide.'),
    ('Trilobite', 'fossil', 1, 'rocks', '', 'low', ('fossil_trilobite', '#9a8a78'), 'An armoured sea bug from before the fish.'),
    ('Fossil Shark Tooth', 'fossil', 1, 'beach', '', '', ('fossil_tooth', '#5a5a5a'), 'Black and shiny. Washes up after the tide.'),
    ('Urchin Fossil', 'fossil', 2, 'rocks', '', '', ('fossil_urchin', '#c8b890'), 'A sea urchin turned to stone, star and all.'),
    ('Fossil Fish', 'fossil', 2, 'rocks', '', 'afterstorm', ('fossil_fish', '#a89a88'), 'A whole fish in the stone. Storms break them loose.'),
    ('Fossil Turtle Shell', 'fossil', 3, 'rocks', '', 'afterstorm', ('fossil_turtle', '#9a8a70'), 'Very rare: a sea turtle\'s shell in stone.'),
    ('Sea Dragon Skull', 'fossil', 3, 'rocks', 'gullrock', 'fog', ('fossil_skull', '#c8c0a8'), 'The skull of an ancient sea reptile. Only on Gull Rock, in fog.'),
    ('Frosted Sea Glass', 'curio', 0, 'beach', '', '', ('glass', '#e8f0f0'), 'Worn soft and white by the waves.'),
    ('Amber Sea Glass', 'curio', 1, 'beach', '', '', ('glass', '#e0a040'), 'Once a medicine bottle.'),
    ('Lavender Sea Glass', 'curio', 2, 'beach', '', '', ('glass', '#b090d8'), 'Old glass turned purple by the sun.'),
    ('Cobalt Bottle Stopper', 'curio', 2, 'beach', '', '', ('stopper', '#3a5ad0'), 'A stopper from an old poison bottle.'),
    ('Mermaid\'s Tear', 'curio', 3, 'beach', '', 'afterstorm', ('glass', '#7af0e0'), 'The rarest sea glass, clear and green. After storms.'),
    ('Lava Glass', 'curio', 1, 'beach', 'ember', '', ('glass', '#3a2020'), 'Black volcanic glass. Only on Ember Isle.'),
    ('Obsidian Arrowhead', 'treasure', 2, 'beach', 'ember', '', ('arrowhead', '#2a2028'), 'Chipped by hand, long ago. Only on Ember Isle.'),
    ('Coral Sand Dollar', 'shell', 1, 'beach', 'atoll', '', ('sanddollar', '#f0c8b0'), 'Pink as the atoll\'s sand. Only on the Turquoise Atoll.'),
    ('Turquoise Cowrie', 'shell', 2, 'beach', 'atoll', '', ('cowrie', '#5ad0c8'), 'Only the atoll has these.'),
    ('Tideglass Pebble', 'curio', 0, 'beach', 'tideglass', '', ('pebble', '#a8d8e8'), 'A see-through pebble. Tideglass Cay is named for them.'),
    ('Glass Fishing Float', 'treasure', 2, 'beach', 'tideglass', '', ('float', '#5ab0a0'), 'A float from some far-off fleet. Only on Tideglass Cay.'),
    ('Moss Agate', 'curio', 1, 'beach', 'mossbank', '', ('pebble', '#6a9a6a'), 'Green ferns trapped inside a stone. Only on Mossbank.'),
    ('Kelp Pearl', 'pearl', 2, 'beach', 'kelpwood', '', ('pearl', '#a8c8a0'), 'A green pearl. Only on Kelpwood.'),
    ('Ship\'s Lantern Lens', 'treasure', 2, 'beach', 'lantern', '', ('lens', '#e0c060'), 'A thick glass lens. Only on Lantern Key.'),
    ('Wrecker\'s Spike', 'treasure', 1, 'beach', 'cove', '', ('spike', '#7a6a5a'), 'An iron spike from a wrecker\'s lantern pole. Only at Wrecker\'s Cove.'),
    ('Gold Wedding Ring', 'treasure', 3, 'beach', 'cove', '', ('ring', '#f0c040'), 'Lost to the sea and given back. Only at Wrecker\'s Cove.'),
    ('Gull Feather Quill', 'curio', 0, 'rocks', 'gullrock', '', ('quill', '#f0f0f0'), 'A gull feather cut for writing. Only on Gull Rock.'),
    ('Keeper\'s Brass Button', 'treasure', 2, 'rocks', 'gullrock', '', ('button', '#d8a840'), 'Stamped with a lighthouse. Only on Gull Rock.'),
]


def slug(s):
    out = ''.join(ch.lower() if ch.isalnum() else '_' for ch in s)
    while '__' in out:
        out = out.replace('__', '_')
    return out.strip('_')


def parse_cond(c):
    p = dict(time=None, tide=None, sky=None, season=None, moon=None, method=[], bait=None, where=None, flags=[])
    for tok in c.split():
        if tok in TIMES:
            p['time'] = tok
        elif tok in TIDES:
            p['tide'] = tok
        elif tok in SKIES:
            p['sky'] = tok
        elif tok in SEASONS:
            p['season'] = tok
        elif tok in MOONS:
            p['moon'] = tok
        else:
            p['flags'].append(tok)
    return p


def fish_hint(z, c):
    words = {'day': 'by day', 'night': 'at night', 'dawn': 'at dawn', 'dusk': 'at dusk', 'dawn/dusk': 'at dawn or dusk',
             'dusk/night': 'from dusk', 'midnight': 'around midnight', 'rising': 'on a rising tide', 'falling': 'on a falling tide',
             'high': 'at high tide', 'low': 'at low tide', 'calm': 'in calm weather', 'windy': 'when it\'s windy', 'rain': 'in the rain',
             'fog': 'in fog', 'storm': 'in a storm', 'afterstorm': 'after a storm', 'fullmoon': 'under a full moon',
             'newmoon': 'on a new moon'}
    parts = [words.get(t, 'in ' + t) for t in c.split()]
    return ('Bites ' + ', '.join(parts) + ' in the ' if parts else 'Bites any time in the ') + ZONE_NAMES[z] + '.'


def build_items():
    items = []
    for name, z, r, c, sz, look, what in FISH:
        items.append(dict(id=slug(name), n=name, cat='fish', z=z, r=r, c=c or 'any', cp=parse_cond(c), sz=list(sz),
                          price=FISH_PRICE[r], how='fish', art=look.split('|')[0], look=look, release=False,
                          hint=fish_hint(z, c), what=what, extra=True))
    for name, z, r, c, sz, look, what in POTS:
        hint = fish_hint(z, c).replace('Bites', 'Crawls into crab pots', 1)
        items.append(dict(id=slug(name), n=name, cat='fish', z=z, r=r, c=c or 'any', cp=parse_cond(c), sz=list(sz),
                          price=FISH_PRICE[r], how='pot', art=look.split('|')[0], look=look, release=False,
                          hint=hint, what=what, extra=True))
    for id_, name, z, c, sz, look, what, flag in LEGENDS:
        cp = parse_cond(c)
        if flag:
            cp['flags'].append(flag)
        items.append(dict(id=id_, n=name, cat='legend', z=z, r=4, c=c, cp=cp, sz=list(sz), price=FISH_PRICE[4], how='fish',
                          art=look.split('|')[0], look=look, release=False, hint=fish_hint(z, c), what=what, extra=True))
    for name, cat, r, z, isle, c, icon, hint in FINDS:
        items.append(dict(id=slug(name), n=name, cat=cat, z=z, r=r, c=c or 'any', cp=parse_cond(c), sz=None,
                          price=FIND_PRICE[r], how='comb', art=icon[0], look='%s|%s' % icon, release=False, hint=hint,
                          what='', isle=isle, extra=True))
    return items


# ----------------------------------------------------------------------------- icons

def icon(kind, colour, seed):
    """A 64x64 pixel icon for a find, lit from the top left with a dark outline."""
    W = 64
    c = Canvas(W, W)
    col = hx(colour)
    stone = shift(col, 0.0)
    if kind == 'glass' or kind == 'pebble':
        m = ellipse(W, W, 32, 34, 15 + (seed % 4), 12)
        c.paint(m, stone, light=(-1, -1))
        hi = ellipse(W, W, 26, 29, 4, 2.5)
        c.rgb[hi & m] = shift(col, 0.45, -0.4)
        if kind == 'glass':
            c.rgb[ellipse(W, W, 36, 38, 7, 4) & m] = shift(col, 0.15, -0.1)
    elif kind.startswith('fossil'):
        base = '#b8b0a0' if kind not in ('fossil_tooth',) else colour
        m = ellipse(W, W, 32, 34, 20, 16) if kind != 'fossil_bullet' else poly(W, W, [(16, 40), (44, 18), (50, 22), (22, 46)])
        if kind == 'fossil_tooth':
            m = poly(W, W, [(20, 46), (32, 14), (44, 46)])
        c.paint(m, base, light=(-1, -1))
        relief = shift(hx(base), -0.25)
        yy, xx = np.mgrid[0:W, 0:W]
        if kind == 'fossil_stem':
            for k in range(6):
                c.rgb[rect(W, W, 20 + k * 5, 28, 21 + k * 5, 40) & m] = relief
        elif kind == 'fossil_fern':
            for k in range(7):
                y = 22 + k * 3
                c.rgb[rect(W, W, 22 + k, y, 42 - k, y) & m] = relief
            c.rgb[rect(W, W, 31, 20, 32, 46) & m] = relief
        elif kind == 'fossil_trilobite':
            c.rgb[(np.abs(xx - 32) < 2) & m] = relief
            for k in range(6):
                c.rgb[rect(W, W, 20, 24 + k * 4, 44, 24 + k * 4) & m] = relief
        elif kind == 'fossil_urchin':
            for k in range(5):
                a = k * 2 * math.pi / 5 - math.pi / 2
                for t in range(3, 14):
                    x, y = int(32 + math.cos(a) * t), int(34 + math.sin(a) * t)
                    c.rgb[y, x] = relief
        elif kind == 'fossil_fish':
            c.rgb[(((xx - 30) / 12.0) ** 2 + ((yy - 34) / 6.0) ** 2 < 1) & m & ((xx + yy) % 3 == 0)] = relief
            c.rgb[rect(W, W, 18, 33, 44, 34) & m] = relief
        elif kind == 'fossil_turtle':
            for k in range(3):
                c.rgb[(np.abs(np.hypot(xx - 32, yy - 34) - (5 + k * 5)) < 0.8) & m] = relief
        elif kind == 'fossil_skull':
            c.rgb[ellipse(W, W, 26, 32, 4, 4) & m] = shift(hx(base), -0.5)
            c.rgb[rect(W, W, 34, 36, 48, 38) & m] = relief
            for k in range(5):
                c.rgb[rect(W, W, 36 + k * 3, 39, 36 + k * 3, 41) & m] = (240, 236, 220)
        elif kind == 'fossil_tooth':
            c.rgb[rect(W, W, 22, 40, 42, 46) & m] = shift(col, 0.3)
    elif kind == 'stopper':
        c.paint(ellipse(W, W, 32, 22, 12, 9), col)
        c.paint(rect(W, W, 26, 26, 38, 48), shift(col, -0.1))
    elif kind == 'arrowhead':
        c.paint(poly(W, W, [(32, 12), (46, 44), (32, 38), (18, 44)]), col)
        c.rgb[rect(W, W, 31, 18, 32, 34)] = shift(col, 0.5)
    elif kind == 'sanddollar':
        m = ellipse(W, W, 32, 32, 18, 18)
        c.paint(m, col)
        for k in range(5):
            a = k * 2 * math.pi / 5 - math.pi / 2
            c.rgb[ellipse(W, W, 32 + math.cos(a) * 8, 32 + math.sin(a) * 8, 2, 4) & m] = shift(col, -0.2)
    elif kind == 'cowrie':
        c.paint(ellipse(W, W, 32, 32, 16, 20), col)
        c.rgb[rect(W, W, 31, 16, 33, 48)] = shift(col, -0.45)
    elif kind == 'float':
        m = ellipse(W, W, 32, 32, 17, 17)
        c.paint(m, col)
        c.rgb[ellipse(W, W, 26, 26, 5, 4) & m] = shift(col, 0.5, -0.4)
        for y in range(16, 49, 8):
            c.rgb[rect(W, W, 15, y, 49, y) & m] = (150, 120, 80)
    elif kind == 'pearl':
        c.paint(ellipse(W, W, 32, 32, 14, 14), col)
        c.rgb[ellipse(W, W, 27, 27, 4, 3)] = shift(col, 0.5, -0.5)
    elif kind == 'lens':
        c.paint(ellipse(W, W, 32, 32, 18, 18), '#c8a040')
        c.paint(ellipse(W, W, 32, 32, 14, 14), col)
        c.rgb[ellipse(W, W, 27, 27, 5, 4)] = (255, 250, 230)
    elif kind == 'spike':
        c.paint(poly(W, W, [(20, 46), (44, 18), (48, 22), (24, 50)]), col)
        c.paint(rect(W, W, 40, 14, 50, 22), shift(col, -0.1))
    elif kind == 'ring':
        yy, xx = np.mgrid[0:W, 0:W]
        d = np.hypot(xx - 32, yy - 34)
        c.paint((d < 14) & (d > 9), col)
        c.paint(ellipse(W, W, 32, 21, 5, 4), '#e8f8ff')
    elif kind == 'quill':
        c.paint(poly(W, W, [(20, 50), (40, 12), (46, 16), (24, 52)]), col)
        c.rgb[rect(W, W, 20, 44, 24, 52)] = (90, 70, 50)
    elif kind == 'button':
        m = ellipse(W, W, 32, 32, 13, 13)
        c.paint(m, col)
        c.rgb[rect(W, W, 31, 24, 33, 40) & m] = shift(col, -0.35)
        c.rgb[rect(W, W, 28, 22, 36, 25) & m] = shift(col, -0.35)
    else:
        c.paint(ellipse(W, W, 32, 32, 14, 14), col)
    return c.finish()


def main():
    preview = '--preview' in sys.argv
    items = build_items()
    base = json.load(open(os.path.join(ROOT, 'godot', 'data', 'catalog.json')))
    have = {e['id'] for e in base['items']}
    clash = [e['id'] for e in items if e['id'] in have]
    assert not clash, 'already in the catalogue: %s' % clash
    out = os.path.join(ROOT, 'godot', 'data', 'catalog_extra.json')
    json.dump({'items': items}, open(out, 'w'), indent=1)
    imgs = []
    for i, e in enumerate(items):
        if e['cat'] in ('fish', 'legend'):
            img = draw_fish(e['look'], 5000 + i, e['cat'] == 'legend')
        else:
            kind, colour = e['look'].split('|')
            img = icon(kind, colour, i)
        path = os.path.join(OUT, 'fish2', e['id'] + '.png')
        Image.fromarray(img, 'RGBA').save(path)
        imgs.append(img)
    nf = sum(1 for e in items if e['cat'] == 'fish')
    nl = sum(1 for e in items if e['cat'] == 'legend')
    print('catalogue extras: %d fish, %d legends, %d finds' % (nf, nl, len(items) - nf - nl))
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        cell = 84
        cols = 10
        rows = (len(imgs) + cols - 1) // cols
        sheet = Image.new('RGBA', (cols * cell, rows * cell), (40, 70, 100, 255))
        for k, img in enumerate(imgs):
            im = Image.fromarray(img, 'RGBA')
            sheet.alpha_composite(im, ((k % cols) * cell + (cell - im.width) // 2, (k // cols) * cell + (cell - im.height) // 2))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(PREVIEW, 'catalog_extra.png'))


if __name__ == '__main__':
    main()
