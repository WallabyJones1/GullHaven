/* Small additions to the original world, painted with Gullhaven's existing pixel art. */
const ISLAND_TOWNS=[
  {id:'tideglass',n:'Tideglass Cay',x:128,y:125,r:12,shore:'sand',zone:'shallows',shopKind:'bait',shopLabel:'BAIT & TEA',roof:'#3f7a8a',wall:'#f4e4c8',desc:'A quiet sandy cay with a bait shop, beachcombing and harbour errands. Follow the southern shallows in any boat.'},
  {id:'mossbank',n:'Mossbank',x:190,y:58,r:13,shore:'sand',zone:'reef',shopKind:'home',shopLabel:'HOME GOODS',roof:'#3f7a5a',wall:'#e8f0d8',desc:'A little garden village on the coral shelf. Browse home decorations and take on local fishing bounties. Open water out here is rough on small boats.'},
  {id:'lantern',n:'Lantern Key',x:250,y:150,r:14,shore:'rock',zone:'kelp',shopKind:'boatyard',shopLabel:'BOATWORKS',roof:'#5a4a7a',wall:'#d8e8f4',desc:'A rocky fishing outpost among the kelp, with a boat workshop and deep-water stories. Far out past the deep: a skiff or bigger makes the trip safely.'}
  ,{id:'kelpwood',n:'Kelpwood',x:176,y:104,r:12,shore:'sand',zone:'kelp',shopKind:'bait',shopLabel:'KELP TEA',roof:'#2f6a5a',wall:'#d8e8d0',lock:'fog',desc:'A misty island of kelp gardens and tea houses, hidden in a fog bank. Quiet folk, strange bait.'},
  {id:'cove',n:"Wrecker's Cove",x:285,y:30,r:12,shore:'rock',zone:'wreck',shopKind:'boatyard',shopLabel:'SALVAGER',roof:'#4a3a3a',wall:'#c8b090',lock:'breakers',desc:'A cliff-ringed cove of salvagers and old wreckers. Repairs, dive gear and stories of every storm.'},
  {id:'ember',n:'Ember Isle',x:215,y:196,r:13,shore:'rock',zone:'blue',shopKind:'home',shopLabel:'EMBER GOODS',roof:'#8a3a2a',wall:'#e8d0b0',lock:'permit',desc:'A warm volcanic island with hot springs and a forge. Only permit holders may land.'}
];
function islandShoreAt(x,y){if(x<110)return null;for(const I of ISLAND_TOWNS){const dx=x-I.x,dy=(y-I.y)*1.2;if(dx*dx+dy*dy<(I.r+3)*(I.r+3))return I}return null}
function islandSeaZone(x,y){
  // Broad, visible shelves leave the old fishing grounds available and give every dock a safe approach.
  if(x>=74.5&&x<83.5&&y>56&&y<91)return'shallows';
  const wb=(NZ.at(x*.6+11,y*.6+5)-.5)*9;
  if(x>94&&x<148+wb&&y>98&&y<145+wb&&x<y+18+wb)return'shallows';
  if(x<110)return null;
  for(const I of ISLAND_TOWNS){const dx=x-I.x,dy=(y-I.y)*1.2;if(dx*dx+dy*dy<(I.r+6)*(I.r+6))return I.zone}
  return null}
function addIslandSettlements(S,set,pier){
  S.islands=[];S.islandActs=[];const idx=(x,y)=>y*S.w+x;
  const prop=(im,x,y,w=1)=>{if(S.sol[idx(x,y)])return;addProp(S,im,x*16+8-im.width/2,(y+1)*16-im.height,{sy:(y+1)*16-1});solidRect(S,x,y,x+w-1,y);reserve(S,x,y,x+w-1,y)};
  for(const I of ISLAND_TOWNS){const x=I.x,y=I.y;
    // A single shop, two cottages and a compact plaza keep each settlement easy to explore.
    set('p',x-6,y+1,x+5,y+3);set('w',x-2,y-1,x-1,y+4);
    const shop=placeBuilding(S,x-6,y-3,6,3,3,{wall:I.wall,mat:'siding',roof:I.roof,door:3,win:[0,5],label:I.shopLabel,labelBg:'#fff4e0',awning:[I.roof,'#fbf6ea'],doorC:I.roof,lamp:1});
    const cottage=placeBuilding(S,x+3,y-3,4,2,2,{wall:I.wall,mat:'planks',roof:I.roof,door:1,win:[3],flowers:1,chimney:1,doorC:'#e8604a'});
    const hut=placeBuilding(S,x-4,y-8,4,2,2,{wall:I.wall,mat:'siding',roof:I.roof,door:2,win:[0],flowers:1,doorC:I.roof});
    set('w',x,y-6,x+1,y+1);set('w',x+4,y-1,x+4,y+1);
    (S.houses=S.houses||[]).push(cottage.door,hut.door);
    const dockEnd=y+Math.ceil(I.r/1.2)+3;pier(x-1,y+3,x,dockEnd);pier(x-3,dockEnd-1,x+2,dockEnd);
    const dock={x:(x+3)*16+8,y:(dockEnd-1)*16+8};
    prop(artNoticeBoard(),x+4,y+2);const bounty={x:(x+4)*16+8,y:(y+3)*16+12};
    prop(artBench(),x-5,y+3,2);prop(artBarrelC(),x+2,y+5);prop(artFishCrate(1),x-3,dockEnd-1);
    prop(artNetRack(),x-6,y+5,2);prop(artNameSign(I.n),x+3,y+4);
    for(const[dx,dy]of[[-8,-1],[8,1],[-7,6],[7,5],[5,-7]]){
      const tx=x+dx,ty=y+dy;if(S.sol[idx(tx,ty)]||S.res[idx(tx,ty)]||landF(tx+.5,ty+.5)<2.8)continue;
      if(I.id==='mossbank')treeAt(S,tx,ty,1);else prop(artPalmC(dx>0?1:0),tx,ty)}
    for(const dx of[-7,7])prop(artBush(I.id==='mossbank'?'#f08bbf':'#fbf1dc'),x+dx,y+3);
    for(const dx of[-3,2]){const ly=dockEnd;prop(artLamp(),x+dx,ly);S.lights.push({x:(x+dx)*16+8,y:ly*16-12,r:40,c:'rgba(255,200,120,'})}
    const entry=Object.assign({},I,{door:shop.door,shop:shop.door,bounty,dock});S.islands.push(entry);S.spots['island_'+I.id]=bounty;S.spots['dock_'+I.id]=dock;
    S.islandActs.push({kind:'bounty',id:I.id,x:bounty.x,y:bounty.y,label:I.n+' bounties',icon:'talk'});
    S.islandActs.push({kind:'shop',id:I.id,shopKind:I.shopKind,x:shop.door.x,y:shop.door.y,label:I.shopLabel==='HOME GOODS'?'Home goods':I.shopLabel==='BOATWORKS'?'Boat workshop':'Bait & tea',icon:'door'});
  }
  // A few familiar props make the existing square more welcoming without moving its streets.
  for(const x of[36,43]){prop(artBench(),x,60,2);prop(artBush('#fbf1dc'),x,59)}
}
