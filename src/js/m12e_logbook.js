/* ================= the Logbook: 217 entries, by zone, with stamps, hints and variants ================= */
let bookTab='fish',bookSel=null;
function toggleBook(force){const b=$('book');const show=force===true?true:force===false?false:b.hidden;if(show){closePanel();$('chatBar').hidden=true;if(gachaOpen)closeGacha();if(MG)closeMG()}b.hidden=!show;if(show){$('bookBadge').hidden=true;renderBook()}updDock()}
$('bkX').addEventListener('click',()=>toggleBook(false));
const VIA_TXT={rod:'on a line',pot:'in a pot',beach:'on the beach',rocks:'in a rock pool',salvage:'salvaged',oyster:'in an oyster',chest:'in a chest',gift:'as a gift'};
function hintShown(e){if(logged(e.id))return true;if(e.r<=1)return true;if(S.coop==='reef')return true;return(S.rumours||[]).includes(e.id)}
function renderBook(){const page=$('bkPage');const st=page.scrollTop;page.innerHTML='';$('bkSub').textContent=`${logCount()} of ${CAT.length} entries`;
  const tb=$('bkTabs');tb.innerHTML='';for(const[k,n]of CAT_TABS){const list=catOf(k);const got=list.filter(e=>logged(e.id)).length;const b=el('button',k===bookTab?'on':'',`${n} ${got}/${list.length}`);b.onclick=()=>{bookTab=k;bookSel=null;renderBook();page.scrollTop=0};tb.append(b)}
  const list=catOf(bookTab);const got=list.filter(e=>logged(e.id)).length;
  if(bookSel&&CATI[bookSel])page.append(bookEntry(CATI[bookSel]));
  const prog=el('div','bkProg');const pi=el('i');pi.style.width=(got/list.length*100)+'%';prog.append(pi);page.append(prog);
  const groups=[];if(bookTab==='fish'){for(const z of ZONE_ORDER)groups.push([ZONES[z].n,list.filter(e=>e.z===z)])}else if(bookTab==='set'){for(const k of Object.keys(SETS))groups.push([SETS[k].n,list.filter(e=>e.set===k),SETS[k].reward])}else groups.push([null,list]);
  for(const[name,items,sub]of groups){if(!items.length)continue;if(name){const h=el('div','zoneHead');h.append(document.createTextNode(name));const g2=items.filter(e=>logged(e.id)).length;h.append(el('small',null,` ${g2}/${items.length}${sub?' · '+sub:''}`));if(g2===items.length)h.append(el('span','stampOk','COMPLETE'));page.append(h)}
    const dex=el('div','dex');for(const e of items){const L=S.log[e.id];const have=logged(e.id);const c=el('button','dexc'+(have?' got':'')+(L&&L.vars&&L.vars.g?' gold':'')+(bookSel===e.id?' sel':''));c.style.setProperty('--rc',CRARCOL[e.r]);c.append(cvIcon(catArt(e.id,have?(L.vars&&L.vars.g?'g':''):'s')));c.append(el('em',null,'#'+String(e.no).padStart(3,'0')));c.title=have?e.n:'???';c.onclick=()=>{bookSel=bookSel===e.id?null:e.id;renderBook();if(bookSel)page.scrollTop=0};dex.append(c)}page.append(dex)}
  if(!bookSel)page.scrollTop=st}
function bookEntry(e){const have=logged(e.id);const L=S.log[e.id];const box=el('div','entry');const art=el('div','eart');art.append(cvIcon(catArt(e.id,have?'':'s')));box.append(art);const d=el('div','ed');box.append(d);
  d.append(el('b',null,have?(e.short||e.n):'???'));const tags=[CRAR[e.r]];if(ZONES[e.z])tags.push(ZONES[e.z].short);if(e.cat==='legend')tags.push('Legend');if(e.release)tags.push('Protected');for(const t of tags){const s=el('span','tag',t);if(t===CRAR[e.r])s.style.background=CRARCOL[e.r],s.style.color='#2a1a10';d.append(s)}
  if(have&&e.what)d.append(el('p',null,e.what));if(have&&e.cat==='set'&&e.set==='bottles')d.append(el('p',null,BOTTLE_TEXT[e.id]||'A rolled letter, the ink running. You keep it with the others.'));
  d.append(el('p',null,hintShown(e)?hintFor(e):'Nobody in town has told you about this one. Try the rumours at the Salty Gull.'));
  const dl=document.createElement('dl');const add=(k,v)=>{dl.append(el('dt',null,k),el('dd',null,v))};const by=NET.shared.firsts[e.id];
  if(have){add('Found',`${L.n} time${L.n>1?'s':''}, first ${VIA_TXT[L.via]||''} ${new Date(L.first).toLocaleDateString()}`);if(L.best)add('Best',`${L.best} cm${e.sz?' (record '+e.sz[1]+' cm)':''}`);if(e.price)add('Worth',`about ${fmt(e.price)} Shells`)}else if(e.sz)add('Size',`${e.sz[0]}–${e.sz[1]} cm`);
  if(by)add('First in town',by);if(NET.shared.aquarium[e.id])add('Aquarium','On show, donated by '+NET.shared.aquarium[e.id].n);d.append(dl);
  if(e.cat==='fish'&&!e.release){const vr=el('div','varrow');for(const[k,n]of[['','Normal'],['g','Golden'],['a','Albino']]){const on=have&&(k?L.vars&&L.vars[k]:true);const s=el('span',on?'on':'',n);vr.append(s)}d.append(vr)}
  return box}
const BOTTLE_TEXT={};
