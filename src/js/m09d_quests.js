/* ================= the "First Season" quest line: learning the harbour ================= */
const QUESTS=[
  {k:'catch',n:'Cast a line',d:'Walk to the end of a jetty, face the water and tap Fish. Strike when the float goes under.',goal:1,reward:{shells:60},at:'pier'},
  {k:'sell',n:'Sell your catch',d:'The Fish Market is up the quay. Sell what you caught for Shells.',goal:1,reward:{shells:40},at:'market'},
  {k:'visit:tackle',n:'Better bait',d:'The Tackle Shop south of the square sells bait and gear. Pick up some prawns.',goal:1,reward:{bait:['prawn',10]},at:'tackle'},
  {k:'decorate',n:'A place of your own',d:'Your cottage is on the south street. Choose a room style or buy your first decoration in Home.',goal:1,reward:{shells:100},at:'home'},
  {k:'coop',n:'Pick a co-op',d:'Five co-ops race for the daily Harbour Cup. Their halls line the north street. Join one.',goal:1,reward:{shells:150},at:'hall_brine'},
  {k:'boat',n:'Buy a boat',d:'The Boatyard sells rowboats. You will need one for the estuary.',goal:1,reward:{bait:['worm',10]},at:'boatyard'},
  {k:'board',n:'Cast off',d:'Your boat is tied up at a jetty. Walk to it and board.',goal:1,reward:{shells:50},at:'berth'},
  {k:'zone:estuary',n:'Up the river',d:'Row north out of the harbour to the Mangrove Estuary and fish there.',goal:1,reward:{bait:['crabbait',8]}},
  {k:'pot',n:'Set a pot',d:'From your boat, drop a crab pot with the small button. Haul it after a couple of town hours.',goal:1,reward:{shells:80}},
  {k:'log',n:'A full page',d:'Fill 10 Logbook entries. Every zone, time and tide has new things.',goal:10,reward:{shells:250}},
  {k:'crew',n:'Send out the crew',d:'Hire a deckhand in the Crew panel and send them on a trip.',goal:1,reward:{shells:200}},
  {k:'character',n:'Make your fisher',d:'Visit the character atelier on the square. Choose one of the original Founding Fishers or build your own look, for free.',goal:1,reward:{shells:100},at:'machine'},
  {k:'island',n:'Beyond the harbour',d:'Sail to Tideglass Cay, south-east of town. Tie up at its pier and read the bounty board.',goal:1,reward:{shells:150},at:'island_tideglass'},
  {k:'bounty',n:'Island favour',d:'Bring the fish requested on any island bounty board to earn Shells and help the settlement.',goal:1,reward:{shells:200}}];
function curQuest(){return QUESTS[S.quest.i]||null}
function bumpQuest(kind,arg){const q=curQuest();if(!q)return;let hit=false;
  if(q.k===kind)hit=true;else if(q.k==='visit:'+arg&&kind==='visit')hit=true;else if(q.k==='zone:'+arg&&kind==='zone')hit=true;
  if(kind==='catch'&&q.k==='zone:estuary'&&arg&&player.boat&&player.boat.zone==='estuary')hit=true;
  if(q.k==='log'){S.quest.prog=logCount();if(S.quest.prog>=q.goal)completeQuest();updQuestHUD();return}
  if(q.k==='zone:estuary'&&kind==='zone')return;if(!hit)return;S.quest.prog++;if(S.quest.prog>=q.goal)completeQuest();updQuestHUD();markDirty()}
function completeQuest(){const q=curQuest();if(!q)return;const R=q.reward;let msg=`Quest done: ${q.n}.`;if(R.shells){addShells(R.shells);msg+=` +${R.shells} Shells`}if(R.bait){S.bait[R.bait[0]]=(S.bait[R.bait[0]]||0)+R.bait[1];msg+=` +${R.bait[1]} ${BAIT[R.bait[0]].n}`}
  toast(msg,'lvl');sfx('lvl');S.quest={i:S.quest.i+1,prog:0};markDirty();const n=curQuest();if(n&&n.k==='log')S.quest.prog=logCount();setTimeout(updQuestHUD,60)}
function updQuestHUD(){let q=curQuest();if(q){const ready=q.k==='boat'?!!S.boat:q.k==='coop'?!!S.coop:q.k==='decorate'?!!(S.home.decor.length||S.home.theme!=='coastal'):q.k==='character'?!!S.character.edited:q.k==='island'?S.visitedIslands.length>0:q.k==='bounty'?Object.values(S.islandBounties).some(b=>b.done):false;if(ready){completeQuest();q=curQuest()}}const b=$('quest');b.hidden=!q;if(!q)return;$('questName').textContent=q.n;$('questProg').textContent=q.goal>1?`${Math.min(S.quest.prog,q.goal)}/${q.goal}`:'Tap for details'}
function questTarget(){const q=curQuest();if(!q||!q.at||scene!==WORLD||player.boat)return null;if(q.at==='pier')return{x:62*16,y:51*16};if(q.at==='berth'){const s=myBoatSpot();return s}return WORLD.spots[q.at]||null}
