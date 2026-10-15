"""Behavioral checks for the small RPG update. Requires playwright and Chromium.
Run with a server on URL (default http://127.0.0.1:8080).
"""
import os, json, time
from playwright.sync_api import sync_playwright
URL=os.environ.get('URL','http://127.0.0.1:8080')
errors=[]
with sync_playwright() as p:
    exe=os.environ.get('CHROMIUM') or ('/usr/bin/chromium' if os.path.exists('/usr/bin/chromium') else None)
    b=p.chromium.launch(executable_path=exe,args=['--no-sandbox'])
    ctx=b.new_context(viewport={'width':390,'height':844},is_mobile=True,has_touch=True)
    page=ctx.new_page();page.on('pageerror',lambda e: errors.append(str(e)))
    page.goto(URL);page.wait_for_function('window.RT && RT.world()',timeout=45000)
    page.fill('#nameIn','IslandFisher');page.click('#introGo')
    assert page.evaluate('S.v===7 && S.shells===1200 && !CHAIN.live && !!S.licence')
    assert page.evaluate('WORLD.w*WORLD.h>160*120 && WORLD.islands.length===3')
    # Legacy gacha/exchange functions never charge money or award characters.
    old=page.evaluate('({shells:S.shells,owned:S.owned.length})')
    page.evaluate('pull(0);doSwap("s2r",100)')
    assert page.evaluate('({shells:S.shells,owned:S.owned.length})')==old
    # Migration retains the existing fisher, inventory and Shells; retires the token balance.
    migrated=page.evaluate('''()=>{const old=DEF();old.v=6;old.shells=345;old.reel=999999;old.active=77;old.owned=[77];old.boats=['row'];old.boat='row';old.gear.rod=2;delete old.home;delete old.character;delete old.boatDecor;const n=migrate(old);return {v:n.v,shells:n.shells,reel:n.reel,boat:n.boat,rod:n.gear.rod,mode:n.character.mode,owned:n.owned}}''')
    assert migrated=={'v':7,'shells':345,'reel':0,'boat':'row','rod':2,'mode':'legacy','owned':[77]}
    # Open water is crossable in any boat (rough water wears the hull); each island has a boat route and walkable connection from dock to board/shop.
    routes=page.evaluate('''()=>WORLD.islands.map(I=>{const pass=(x,y)=>{if(x<0||y<0||x>=WORLD.w||y>=WORLD.h)return false;return !!WORLD.nav[y*WORLD.w+x]};const sp=WORLD.berths[0];const path=findPathP(pass,WORLD.w,WORLD.h,sp.tx,sp.ty,Math.floor(I.dock.x/16),Math.floor(I.dock.y/16),40000);return [I.id,!!path,!!findPath(WORLD,Math.floor((I.dock.x-24)/16),Math.floor(I.dock.y/16),Math.floor(I.bounty.x/16),Math.floor(I.bounty.y/16))]})''')
    assert all(r[1] and r[2] for r in routes),routes
    # Bounty requires the island board and requested fish, pays once, and consumes only those fish.
    page.evaluate("RT.panel('island','tideglass')")
    assert not page.evaluate("S.visitedIslands.includes('tideglass')")
    page.evaluate("const I=WORLD.islands[0];RT.tp(I.bounty.x,I.bounty.y);RT.panel('island',I.id)")
    assert page.evaluate("S.visitedIslands.includes('tideglass') && S.shells===1300")
    pay=page.evaluate("islandQuest(WORLD.islands[0]).pay")
    page.evaluate("const q=islandQuest(WORLD.islands[0]);S.hold=[{id:'oyster',t:Date.now()},...Array.from({length:q.n},()=>({id:q.id,cm:20,t:Date.now()}))];renderPanel()")
    page.get_by_role('button',name='Deliver ·',exact=False).click()
    assert page.evaluate('S.shells')==1300+pay
    assert page.evaluate("S.hold.length===1 && S.hold[0].id==='oyster' && islandQuest(WORLD.islands[0]).done")
    page.evaluate('renderPanel()');assert page.get_by_role('button',name='Deliver ·',exact=False).count()==0
    # Boat purchase and Shells paint upgrade use one balance, and persist through reload.
    page.evaluate("RT.setState(S=>{S.shells=2000});RT.panel('shop','boatyard')")
    page.locator('#panelBody .item').filter(has_text='Rowboat').get_by_role('button',name='600',exact=True).click()
    assert page.evaluate("S.boat==='row' && S.shells===1400")
    page.evaluate("RT.panel('shop','paint');buyCosmetic('paint','#5fae6a')")
    assert page.evaluate("S.paint.row==='#5fae6a' && S.shells===1400-CFG.COSMETIC.paint")
    saved=page.evaluate('saveLocal();({shells:S.shells,boat:S.boat,paint:S.paint.row,visited:S.visitedIslands})')
    page.reload();page.wait_for_function('window.RT && RT.world()',timeout=45000)
    assert page.evaluate('({shells:S.shells,boat:S.boat,paint:S.paint.row,visited:S.visitedIslands})')==saved
    # Exercise a new player fishing cast and a personal quest reward.
    page.click('#introGo');page.evaluate('closeAll();RT.tp(55*16+8,60*16+10,"right");RT.fish()')
    assert page.evaluate('!!MG && MG.type==="fish"')
    page.evaluate('closeMG();S.quest={i:0,prog:0};bumpQuest("catch")')
    assert page.evaluate('S.quest.i===1')
    assert not errors,errors
    b.close()
print('RPG browser checks passed: migration, routes, bounty, economy, persistence, fishing.')
