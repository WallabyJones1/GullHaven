"""Two-player checks for cottage visits, custom looks and boats. Requires Playwright/Chromium."""
import os
from playwright.sync_api import sync_playwright
URL=os.environ.get('URL','http://127.0.0.1:8080')
errors=[]
with sync_playwright() as p:
 exe=os.environ.get('CHROMIUM') or ('/usr/bin/chromium' if os.path.exists('/usr/bin/chromium') else None)
 b=p.chromium.launch(executable_path=exe,args=['--no-sandbox'])
 def join(name):
  c=b.new_context(viewport={'width':390,'height':844},is_mobile=True,has_touch=True);pg=c.new_page();pg.on('pageerror',lambda e:errors.append(str(e)));pg.goto(URL);pg.wait_for_function('window.RT && RT.world() && NET.mode==="ws"',timeout=45000);pg.fill('#nameIn',name);pg.click('#introGo');return pg
 host=join('HostFisher');guest=join('GuestFisher')
 guest.wait_for_function('NET.peers.size>=1')
 # Real UI home purchases, followed by persistence and free rearrangement.
 host.evaluate("RT.panel('home','decorate')")
 host.locator('#panelBody .item').filter(has_text='Warm sunset').get_by_role('button',name='Buy',exact=True).click()
 host.locator('#panelBody .item').filter(has_text='Fern pot').get_by_role('button',name='Buy & place',exact=True).click()
 assert host.evaluate("S.shells===1105 && S.home.theme==='sunset' && S.home.decor.includes('plant')")
 host.locator('#panelBody .item').filter(has_text='Fern pot').get_by_role('button',name='Store',exact=True).click()
 host.locator('#panelBody .item').filter(has_text='Fern pot').get_by_role('button',name='Place',exact=True).click()
 assert host.evaluate('S.shells===1105')
 # Select a free original through Menu, then build a separate custom fisher.
 host.evaluate("RT.panel('menu','character')")
 host.get_by_role('button',name='Wear Founding Fisher #003',exact=True).click()
 assert host.evaluate("ACTIVE()===3 && panelName==='character'")
 host.evaluate("RT.panel('character','custom')")
 host.locator('#panelBody select').first.select_option('2')
 host.get_by_role('button',name='Wear this look · Free',exact=True).click()
 custom=host.evaluate('ACTIVE()');assert host.evaluate("S.shells===1105 && S.character.mode==='custom'")
 guest.wait_for_function('id=>[...NET.peers.values()].some(p=>p.id===id)',arg=custom)
 # A neighbour visits the owner's public room and sees the same scene as the owner.
 host.evaluate("closeAll();RT.go('home');sendPresence(true)")
 guest.wait_for_function("[...NET.peers.values()].some(p=>p.home.theme==='sunset' && p.home.decor.includes('plant'))")
 guest.evaluate("RT.panel('home','visit')")
 guest.locator('#panelBody .item').filter(has_text="HostFisher's cottage").get_by_role('button',name='Visit',exact=True).click()
 assert guest.evaluate("scene.homeGuest && scene.homeDesign===JSON.stringify({theme:'sunset',decor:['plant']}) && !scene.acts.some(a=>a.label==='Decorate your cottage')")
 assert host.evaluate('scene.name')==guest.evaluate('scene.name')
 guest.wait_for_function("[...NET.peers.values()].some(p=>p.sc===scene.name && p.n==='HostFisher')")
 # Editing a guest's own room leaves the host's design untouched.
 guest.evaluate("RT.panel('home','decorate')")
 guest.locator('#panelBody .item').filter(has_text='Woodland').get_by_role('button',name='Buy',exact=True).click()
 assert host.evaluate("S.home.theme==='sunset'")
 # A host design change refreshes the guest snapshot safely.
 host.evaluate("RT.panel('home','decorate')")
 host.locator('#panelBody .item').filter(has_text='Woodland').get_by_role('button',name='Buy',exact=True).click()
 guest.wait_for_function("scene.homeDesign===JSON.stringify({theme:'woodland',decor:['plant']})")
 guest.evaluate('closeAll();scene.exitFn()');assert guest.evaluate("scene===WORLD")
 # Boat name, decoration, paint and fishing activity are relayed to neighbours.
 host.evaluate("closeAll();RT.go('world');S.boats=['row'];S.boat='row';S.boatName='Sea Fern';S.paint.row='#5fae6a';S.boatDecor={row:{selected:'flowers',owned:['flowers']}};RT.board();sendPresence(true)")
 guest.wait_for_function("[...NET.peers.values()].some(p=>p.b && p.b.n==='Sea Fern' && p.b.de==='flowers' && p.b.p==='#5fae6a')")
 host.evaluate("const boat=player.boat;startFishing({x:boat.x+30,y:boat.y,zone:'harbour',boat:true});sendPresence(true)")
 guest.wait_for_function("[...NET.peers.values()].some(p=>p.n==='HostFisher' && p.fish && p.b)")
 # Return to a changed own room after visiting a neighbour uses its latest cached design.
 guest.evaluate("RT.go('home');visitHome({ht:[...NET.peers.values()].find(p=>p.n==='HostFisher').ht,home:{theme:'woodland',decor:['plant']},n:'HostFisher'})")
 guest.evaluate("S.home.theme='sunset';refreshHomeScene();scene.exitFn()")
 assert guest.evaluate("!scene.homeGuest && scene.homeDesign===JSON.stringify(homeProfile(S.home))")
 host.evaluate('closeMG();saveLocal()')
 assert not errors,errors
 b.close()
print('Social browser checks passed: free looks, furniture, shared visits, live decor, boats and fishing.')
