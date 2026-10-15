const ids=(window.ZIDS||'gummy_shark,shortfin_mako,port_jackson_shark,striped_marlin,sailfish,yellowtail_scad,bronze_whaler,bluntnose_sixgill_shark').split(',');const S=32;
const[c,x]=mk(ids.length*(S+2)+2,S+4);x.fillStyle='#2e4466';x.fillRect(0,0,c.width,c.height);
ids.forEach((id,i)=>{const e=CATI[id];const A=parseArt(e.art);const img=typeof catArt==='function'?catArt(id,window.ZV||''):drawFish(A,S).canvas();x.drawImage(img,2+i*(S+2),2)});return c.toDataURL();
