const S=32,cols=12;const list=CAT.filter(e=>e.cat==='fish'||e.cat==='legend');const rows=Math.ceil(list.length/cols);const Z=1;
const[c,x]=mk(cols*(S+2)+2,rows*(S+8)+2);x.fillStyle='#24344e';x.fillRect(0,0,c.width,c.height);
list.forEach((e,i)=>{const A=parseArt(e.art);let img;try{img=typeof catArt==='function'?catArt(e.id):FISHP[A.shape]?drawFish(A,S).canvas():null}catch(err){console.error(e.id,err.stack);return}
  const gx=2+(i%cols)*(S+2),gy=2+Math.floor(i/cols)*(S+8);x.fillStyle='#2e4466';x.fillRect(gx,gy,S,S);if(img)x.drawImage(img,gx,gy,S,S);drawText(x,String(i+1),gx+1,gy+S+1,'#8aa')});
return c.toDataURL();
