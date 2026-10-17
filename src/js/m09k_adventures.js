/* ================= adventures: three locked islands and the quest chains that open them =================
   Kelpwood hides in a fog bank (the lighthouse keeper's chart), Wrecker's Cove behind breakers (a password from three
   townsfolk), Ember Isle needs a Harbourmaster permit (three island bounties and a trawler or bigger). */
const ADV={kelpwood:{n:'Kelpwood',lock:'fog'},cove:{n:"Wrecker's Cove",lock:'breakers'},ember:{n:'Ember Isle',lock:'permit'}};
const COVE_WORDS={'Captain Moe':'SALT','Sully':'ROPE','Wren':'LANTERN'};
const KEEPER_FISH=3;
function islandOpen(id){return!ADV[id]||!!(S.story&&S.story[id])}
function applyLocks(){if(!WORLD||!WORLD.locks)return;for(const[id,tiles]of Object.entries(WORLD.locks)){const open=islandOpen(id);for(const i of tiles)WORLD.nav[i]=open?1:0}}
function unlockIsland(id,msg){S.story[id]=1;markDirty();applyLocks();miniBase=null;mapBase=null;drawMini();sfx('fanfare2');addShells(750);if(!S.titles.includes(ADV[id].n+' finder'))S.titles.push(ADV[id].n+' finder');toast(msg+' +750 Shells','rare')}
// the lighthouse keeper outside at the point: kelp fish for the fog chart
function keeperTalk(){if(islandOpen('kelpwood')){toast('Keeper Odile: "Mind the fog on the way back. It remembers boats."');return}
  const kelp=S.hold.filter(c=>{const e=CATI[c.id];return e&&e.cat==='fish'&&e.z==='kelp'});S.story.keeper=1;markDirty();
  if(kelp.length<KEEPER_FISH){toast(`Keeper Odile: "There's an island in the fog north-east of Tideglass. My chart will see you through, but I'm hungry. Bring me ${KEEPER_FISH} fish from the Kelp Forest." (${kelp.length}/${KEEPER_FISH})`);return}
  let left=KEEPER_FISH;S.hold=S.hold.filter(c=>{const e=CATI[c.id];if(left&&e&&e.cat==='fish'&&e.z==='kelp'){left--;return false}return true});
  unlockIsland('kelpwood','Keeper Odile hands you her fog chart. The fog around Kelpwood thins!')}
function coveLine(f){const w=COVE_WORDS[f.n];if(!w||!islandOpen('kelpwood')||islandOpen('cove'))return null;S.story.words=S.story.words||{};const fresh=!S.story.words[w];S.story.words[w]=1;markDirty();
  const n=Object.keys(S.story.words).length;if(fresh)setTimeout(()=>toast(`Password word ${n}/3: ${w}${n===3?'. Sail to the breakers off Wrecker\'s Cove and call it out!':''}`,'lvl'),600);return`The wreckers' word? ...${w}. You didn't hear it from me.`}
function permitReady(){return(S.story.bounties||0)>=3&&S.boats.some(k=>BOATI[k].tier>=4)}
function claimPermit(){if(!permitReady()){toast('The Harbourmaster needs 3 island bounties done and a trawler or bigger.');return}if(!scene||scene.in!=='harbourmaster'){toast('Collect the permit from the Harbourmaster.');return}unlockIsland('ember','The Harbourmaster stamps your Ember Isle permit. The harbour patrol will let you through!')}
// sailing up to a locked island
function lockAct(){const b=player.boat;if(!b)return null;for(const I of WORLD.islands||[]){if(!I.lock||islandOpen(I.id))continue;const d=Math.hypot(b.x/16-I.x,(b.y/16-I.y)*1.2);if(d>I.r+12)continue;
    if(I.lock==='breakers')return{label:'Call out',icon:'talk',act:()=>{const w=Object.keys((S.story.words)||{});if(w.length<3){toast(`Nobody answers. You need the wreckers' three-word password (${w.length}/3). Townsfolk in Gullhaven know it.`);return}unlockIsland('cove','You shout "SALT, ROPE, LANTERN!" A lantern swings on the cliff and the breakers ease. Wrecker\'s Cove is open!')}};
    if(I.lock==='fog')return{label:'Fog bank',icon:'fog',act:()=>toast('A wall of fog. Without a chart you would only sail in circles. The lighthouse keeper might have one.')};
    return{label:'Patrol',icon:'anchor',act:()=>toast('A patrol skiff waves you off: "Permit holders only. See the Harbourmaster."')}}return null}
function lockWarnTick(){const b=player.boat;if(!b||scene!==WORLD)return;for(const I of WORLD.islands||[]){if(!I.lock||islandOpen(I.id))continue;const d=Math.hypot(b.x/16-I.x,(b.y/16-I.y)*1.2);if(d<I.r+13&&lockWarnTick.last!==I.id){lockWarnTick.last=I.id;toast(I.lock==='fog'?'Thick fog ahead. Kelpwood is in there somewhere.':I.lock==='breakers'?"Breakers boom around Wrecker's Cove. Someone is watching from the cliff.":'A harbour patrol skiff circles Ember Isle.','warn')}}}
// fog and breakers around the locked islands
function drawLocks(t){if(scene!==WORLD)return;for(const I of WORLD.islands||[]){if(!I.lock||islandOpen(I.id))continue;const cx=I.x*16,cy=I.y*16,R=(I.r+8)*16;if(!inView(cx-R-40,cy-R-40,R*2+80,R*2+80))continue;
    if(I.lock==='fog'){for(let k=0;k<26;k++){const a=k/26*6.283+t*.03,rr=R*(.55+((k*37)%10)/22);const x=cx+Math.cos(a)*rr-camX,y=cy+Math.sin(a)*rr/1.2-camY;const s=34+(k%5)*10;ctx.globalAlpha=.42;ctx.fillStyle='#e8eef4';ctx.beginPath();ctx.ellipse(x,y,s,s*.55,0,0,6.283);ctx.fill()}
      ctx.globalAlpha=.55;ctx.fillStyle='#dfe8ee';ctx.beginPath();ctx.ellipse(cx-camX,cy-camY,(I.r+5)*16,(I.r+5)*16/1.2,0,0,6.283);ctx.fill();ctx.globalAlpha=1}
    else if(I.lock==='breakers'){ctx.strokeStyle='rgba(255,255,255,.8)';ctx.lineWidth=2;for(let k=0;k<3;k++){const ph=(t*.6+k/3)%1;const rr=R*(.85+ph*.2);ctx.globalAlpha=1-ph;ctx.beginPath();for(let a=0;a<=64;a++){const an=a/64*6.283;const w=Math.sin(an*9+t*3)*4;ctx[a?'lineTo':'moveTo'](cx+Math.cos(an)*(rr+w)-camX,cy+Math.sin(an)*(rr+w)/1.2-camY)}ctx.stroke()}ctx.globalAlpha=1;ctx.lineWidth=1}
    else{const a=t*.25;const x=cx+Math.cos(a)*R*.95-camX,y=cy+Math.sin(a)*R*.95/1.2-camY;const im=boatImg('dinghy',Math.round(((a+Math.PI/2)/(Math.PI*2))*16)&15,'#c8443a');ctx.drawImage(im,Math.round(x-im.width/2),Math.round(y-im.height/2))}}}
// the island locals of the new islands
const NEW_NPC={kelpwood:['Sage Wynn',4422,['"The fog keeps Kelpwood quiet. We like quiet."','"Wreckers? They open their cove to anyone who knows three words. Ask Moe, Sully and Wren back in Gullhaven."']],
  cove:['Captain Rook',4466,['"Every chest in this cove came off a wreck. Every wreck came off a storm."','"Ember Isle? The Harbourmaster guards it. Do three island bounties and bring a trawler, and he might sign."']],
  ember:['Smith Ada',4499,['"The mountain keeps the forge hot and the water warmer. Take a dip in the springs."','"You came through the patrol? Then you are a real captain now."']]};
/* ---------- the adventures panel ---------- */
function panelAdventures(body,H){head('Adventures','Secrets around the sea',uiIcon('map'));tabs(null);const l=el('div','list');const st=S.story||{};
  const clues=Object.keys(st.clues||{}).length;
  l.append(itemRow(uiIcon('fish'),'Mirrorlake',lakeOpen()?'Opened. Freshwater fish wait behind the old gate.':`Find the four riddles (${clues}/4) and open the old gate in the south wood.`,lakeOpen()?el('b',null,'Done'):null));
  const kelp=S.hold.filter(c=>{const e=CATI[c.id];return e&&e.cat==='fish'&&e.z==='kelp'}).length;
  l.append(itemRow(uiIcon('fog'),'Kelpwood',islandOpen('kelpwood')?'The fog has cleared. Sail north-east of Tideglass.':st.keeper?`Bring ${KEEPER_FISH} Kelp Forest fish to Keeper Odile at Lighthouse Point (${kelp}/${KEEPER_FISH} in your hold).`:'An island lost in fog. The lighthouse keeper at Lighthouse Point knows the way.',islandOpen('kelpwood')?el('b',null,'Done'):null));
  const w=Object.keys(st.words||{}).length;
  l.append(itemRow(uiIcon('talk'),"Wrecker's Cove",islandOpen('cove')?'The breakers let you through. Far north-east.':!islandOpen('kelpwood')?'Locked. Someone on Kelpwood knows more.':`Learn the wreckers' password from Captain Moe, Sully and Wren in town (${w}/3), then call it out at the breakers.`,islandOpen('cove')?el('b',null,'Done'):null));
  const bn=Math.min(3,st.bounties||0),tr=S.boats.some(k=>BOATI[k].tier>=4);
  l.append(itemRow(uiIcon('storm'),'Ember Isle',islandOpen('ember')?'Permit stamped. South-west of Lantern Key.':`A Harbourmaster permit: island bounties ${bn}/3, trawler or bigger ${tr?'yes':'no'}.`,islandOpen('ember')?el('b',null,'Done'):permitReady()?btn('Claim',claimPermit,'sm gold'):null));
  body.append(l);H('p','Unlocking an island pays 750 Shells and gives you a title. Each new island has a shop, a bounty board, a dive flag and a local with stories.')}
function advInit(){S.story=S.story||{};applyLocks();const W=WORLD;for(const I of W.islands||[]){const n=NEW_NPC[I.id];if(!n)continue;const nx=(I.x-3)*16+8,ny=(I.y+2)*16+12;W.keepers.push({id:n[1],x:nx,y:ny,dir:'down'});let k=0;act(W,nx,ny,20,'Talk to '+n[0],'talk',()=>{toast(n[0]+': '+n[2][k%n[2].length]);k++})}
  const c=W.spots.carving;if(c){const kx=c.x+22,ky=c.y+4;W.keepers.push({id:3907,x:kx,y:ky,dir:'left'});act(W,kx,ky,18,'Talk to Keeper Odile','talk',keeperTalk)}}
