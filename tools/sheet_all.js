const S=32,cols=16;const cat=window.CATF||null;const list=CAT.filter(e=>!cat||cat.includes(e.cat));const rows=Math.ceil(list.length/cols);
const[c,x]=mk(cols*(S+2)+2,rows*(S+2)+2);x.fillStyle='#24344e';x.fillRect(0,0,c.width,c.height);
list.forEach((e,i)=>{let img;try{img=catArt(e.id,window.VAR||'')}catch(err){console.error(e.id,err.stack);return}
  const gx=2+(i%cols)*(S+2),gy=2+Math.floor(i/cols)*(S+2);x.fillStyle='#2e4466';x.fillRect(gx,gy,S,S);if(img)x.drawImage(img,gx,gy,S,S)});
return c.toDataURL();
