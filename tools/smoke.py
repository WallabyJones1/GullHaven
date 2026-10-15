"""Smoke test the free RPG build at iPhone size: panels, character builder, cottages,
island bounties, boats, mini-games and buildings. Collect browser errors and exit nonzero
on failure. Screenshots go to $OUT (default: /tmp/gullhaven-smoke).
Usage: URL=http://localhost:8080 CHROMIUM=/usr/bin/chromium python3 tools/smoke.py [shots...]
"""
import os, sys, json, time
from playwright.sync_api import sync_playwright
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.environ.get('OUT', '/tmp/gullhaven-smoke')
os.makedirs(OUT, exist_ok=True)
WANT = set(sys.argv[1:])
errs = []
def shot(pg, name):
    if not WANT or name in WANT or 'all' in WANT:
        pg.screenshot(path=f'{OUT}/{name}.png')
def step(pg, name, js, wait=250, snap=False):
    n0 = len(errs)
    try:
        pg.evaluate(js)
    except Exception as e:
        errs.append(f'[{name}] eval: {str(e)[:300]}')
    pg.wait_for_timeout(wait)
    for e in errs[n0:]:
        if not e.startswith('['):
            errs[errs.index(e)] = f'[{name}] {e}'
    if snap:
        shot(pg, name)
with sync_playwright() as p:
    chromium = os.environ.get('CHROMIUM') or ('/usr/bin/chromium' if os.path.isfile('/usr/bin/chromium') else None)
    b = p.chromium.launch(**({'executable_path': chromium} if chromium else {}))
    ctx = b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=3, is_mobile=True, has_touch=True)
    pg = ctx.new_page()
    pg.on('pageerror', lambda e: errs.append('pageerror: ' + str(e)[:400]))
    pg.on('console', lambda m: errs.append('console: ' + m.text[:300]) if m.type == 'error' else None)
    pg.goto(os.environ.get('URL') or ('file://' + ROOT + '/public/index.html'))
    pg.wait_for_function('!document.getElementById("introGo").disabled', timeout=20000)
    pg.wait_for_function('typeof RT!=="undefined" && RT.world() && RT.world().w>0', timeout=60000)
    pg.wait_for_timeout(600)
    shot(pg, '00_intro')
    pg.fill('#nameIn', 'test_fisher')
    pg.click('#introGo')
    pg.wait_for_timeout(1500)
    shot(pg, '01_town')
    panels = {'hold': ['catch', 'bait', 'gear'], 'map': ['map', 'zones'], 'coop': ['cup', 'results', 'mine', 'join'], 'crew': [None],
              'menu': ['me', 'character', 'trophies', 'settings'], 'shop': ['market', 'prices', 'tackle', 'bait', 'boatyard', 'gearb', 'paint'],
              'exchange': [None], 'character': ['originals', 'custom'], 'home': ['decorate', 'visit'], 'boatDecor': [None], 'island': [None],
              'aquarium': ['donate', 'tanks'], 'tavern': ['rumours', 'requests'], 'licence': ['licence', 'handle', 'derby'],
              'weather': ['now', 'tides', 'forecast', 'legends'], 'notice': [None], 'quest': [None]}
    for pn, tabs in panels.items():
        for t in tabs:
            nm = f'p_{pn}_{t}'
            step(pg, nm, f'RT.panel({json.dumps(pn)},{json.dumps(t)})', 200, snap=True)
    island_ids = pg.evaluate('(WORLD.islands||[]).map(i=>i.id)')
    if len(island_ids) < 3:
        errs.append('[islands] Expected at least three island settlements.')
    for island_id in island_ids:
        step(pg, f'p_island_{island_id}', f'RT.panel("island",{json.dumps(island_id)})', 200, snap=True)
    step(pg, 'close', 'closeAll()')
    # Give the player Shells, a co-op, a boat and catch to exercise progression screens.
    step(pg, 'rich', '''RT.setState(S=>{S.shells=200000;S.reel=0;S.licence={no:'FREE',at:Date.now()};S.coop='reef';S.boats=['row','skiff'];S.boat='skiff';S.gear.engine=2;S.fuel=100;
      const ids=['bream','whiting','flathead','snapper','driftwood_crate'];for(const id of ids)if(CATI[id])S.hold.push({id,cm:30,v:'',kg:1,t:Date.now()});S.hold.push({id:'oyster',cm:0,v:'',t:Date.now()})})''')
    for pn, t in [('hold', 'catch'), ('coop', 'cup'), ('coop', 'mine'), ('crew', None), ('character', 'custom'), ('home', 'decorate'), ('boatDecor', None), ('aquarium', 'donate')]:
        step(pg, f'r_{pn}_{t}', f'RT.panel({json.dumps(pn)},{json.dumps(t)})', 250, snap=True)
    step(pg, 'crew_hire', 'syncCrew();if(!S.crew.length)hireHand();if(!S.crew.length)throw new Error("No deckhand after hiring")', 250)
    step(pg, 'crew_send', 'sendTrip(S.crew[0],"harbour",0)', 300)
    step(pg, 'crew_collect', 'if(!S.crew[0].trip)throw new Error("Crew trip did not start");S.crew[0].trip.end=Date.now()-1;collectTrip(S.crew[0])', 400, snap=True)
    step(pg, 'chest', 'closeAll();const i=S.hold.findIndex(c=>c.id==="driftwood_crate");if(i>=0)openChest(i)', 3500)
    step(pg, 'book', 'closeAll();RT.book()', 400, snap=True)
    step(pg, 'book_sel', 'S.log[CAT[3].id]={n:2,best:20,first:Date.now(),vars:{},via:"rod"};bookSel=CAT[3].id;renderBook()', 300, snap=True)
    step(pg, 'book_legends', 'bookTab="legend";bookSel=null;renderBook()', 300, snap=True)
    step(pg, 'book_close', 'toggleBook(false)')
    # Free original looks and a custom look built from the original pixel parts.
    step(pg, 'character_original', 'RT.panel("character","originals");S.character={template:500,mode:"template",look:null};characterChanged();renderPanel();if(ACTIVE()!==500)throw new Error("Original Fisher was not selected")', 350, snap=True)
    step(pg, 'character_custom', 'S.character={template:500,mode:"custom",look:lookFromTemplate(500)};S.character.look.hs=2;characterChanged();RT.panel("character","custom");if(!publicLook())throw new Error("Custom appearance was not registered")', 350, snap=True)
    # Decorate and enter the owner's cottage, then preview a neighbour's shared snapshot.
    step(pg, 'home_decorate', 'const h=ownHome();h.theme="woodland";h.decor=["plant","table","books"];markDirty();refreshHomeScene();RT.panel("home","decorate")', 350, snap=True)
    step(pg, 'home_visit_list', 'RT.panel("home","visit")', 250, snap=True)
    step(pg, 'home_visit', 'closeAll();visitHome({ht:"smokeneighbour",n:"Smoke neighbour",home:{theme:"sunset",decor:["model","net"]}});if(scene.homeOwner!=="smokeneighbour")throw new Error("Cottage visit did not open")', 400, snap=True)
    step(pg, 'home_visit_return', 'RT.go("world")', 300)
    step(pg, 'boat_decor', 'S.boatDecor[S.boat]={selected:"lifebuoy",owned:["none","lifebuoy"]};markDirty();RT.panel("boatDecor")', 300, snap=True)
    # Open each bounty while standing at its own board, which also records discovery.
    for island_id in island_ids:
        step(pg, f'island_board_{island_id}', f'''closeAll();RT.go("world");const I=WORLD.islands.find(i=>i.id==={json.dumps(island_id)});RT.tp(I.bounty.x,I.bounty.y,"up");RT.panel("island",I.id);if(!S.visitedIslands.includes(I.id))throw new Error("Island discovery was not recorded")''', 350, snap=True)
    step(pg, 'rpg_close', 'closeAll();RT.go("world")', 200)
    # buildings
    for k in ['market', 'tackle', 'boatyard', 'exchange', 'aquarium', 'tavern', 'harbourmaster', 'lighthouse', 'home', 'hall_reef', 'hall_deep']:
        step(pg, f'in_{k}', f'RT.go({json.dumps(k)})', 500, snap=True)
    step(pg, 'out', 'RT.go("world")', 500)
    # fishing from the shore: stand on the quay facing the harbour
    step(pg, 'tp_quay', 'RT.tp(55*16+8,60*16+10,"right")', 300, snap=True)
    step(pg, 'fish', 'RT.fish()', 300)
    step(pg, 'cast_down', 'MG&&MG.down()', 900)
    step(pg, 'cast_up', 'MG&&MG.up()', 1200, snap=True)
    step(pg, 'bite_wait', 'if(MG&&MG.hook){MG.biteAt=MG.e+.2}', 600, snap=True)
    step(pg, 'strike', 'MG&&MG.state==="bite"&&MG.down()', 200)
    step(pg, 'fight', 'MG&&(MG.hold=true)', 2000, snap=True)
    step(pg, 'fight_up', 'MG&&MG.up()', 300)
    step(pg, 'fight_end', 'if(MG&&MG.state==="fight"){MG.dist=.02;MG.hold=true}', 600, snap=True)
    step(pg, 'land', 'if(MG&&MG.state==="land"){MG.lp=MG.lc;MG.down()}', 2500, snap=True)
    step(pg, 'mg_close', 'closeMG()', 200)
    # dig
    step(pg, 'dig', 'const c={i:999,x:player.x,y:player.y+10,where:"beach"};startDig(c)', 500, snap=True)
    step(pg, 'dig_hits', 'for(let k=0;k<3;k++){MG.pos=MG.tgt;MG.cool=0;MG.down()}', 1500)
    step(pg, 'mg_close2', 'closeMG()', 200)
    # boat: board, sail, pot, salvage
    step(pg, 'board', 'RT.board()', 600, snap=True)
    step(pg, 'sail', 'const b=player.boat;sailTo(b.x+20,b.y+200)', 2500, snap=True)
    step(pg, 'drop_pot', 'dropPot()', 300)
    step(pg, 'haul_pot', 'S.pots[0].at=Date.now()-1e7;haulPot(S.pots[0])', 400, snap=True)
    step(pg, 'haul_hold', 'MG&&MG.down();MG&&(MG.surge=false);', 3000)
    step(pg, 'mg_close3', 'closeMG()', 200)
    step(pg, 'salvage', 'const s=WORLD.salvage.find(s=>ZONES[s.zone].need<=boatTier());if(s)startSalvage(s)', 400, snap=True)
    step(pg, 'salv_drop', 'if(MG){MG.d=MG.band;MG.hold=false}', 1200)
    step(pg, 'mg_close4', 'closeMG()', 200)
    step(pg, 'boat_fish', 'const a=boatAct();if(a&&a.label==="Cast")a.act()', 300)
    step(pg, 'boat_cast', 'MG&&MG.down()', 700)
    step(pg, 'boat_cast2', 'MG&&MG.up()', 1500, snap=True)
    step(pg, 'mg_close5', 'closeMG()', 200)
    step(pg, 'map2', 'RT.panel("map","map")', 500, snap=True)
    step(pg, 'final', 'closeAll()', 800, snap=True)
    b.close()
print(json.dumps(errs, indent=1) if errs else 'NO ERRORS')
sys.exit(1 if errs else 0)
