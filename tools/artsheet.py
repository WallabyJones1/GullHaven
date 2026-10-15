"""Render art review sheets: python3 tools/artsheet.py <js-expr returning dataURL> out.png [scale]
Loads the engine + art modules into a blank page (no game boot)."""
import sys, os, base64, io, glob
from playwright.sync_api import sync_playwright
from PIL import Image
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODS=[m for m in sorted(glob.glob(ROOT+'/src/js/m*.js')) if os.path.basename(m)[:3] in tuple(os.environ.get('MODS','m00,m01,m02,m03,m04').split(','))]
expr=open(sys.argv[1]).read() if os.path.exists(sys.argv[1]) else sys.argv[1]
out=sys.argv[2]; scale=int(sys.argv[3]) if len(sys.argv)>3 else 3
src="'use strict';\n"+'\n'.join(open(m).read() for m in MODS)
html='<html><body style="background:#222"><script>'+src+'\nwindow.__SHEET=()=>{'+expr+'};</script></body></html>'
with open('/tmp/claude-0/-home-claude/e902963d-2bff-54c9-acec-014774e54237/scratchpad/art.html','w') as f: f.write(html)
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(); errs=[]
    pg.on('pageerror',lambda e:errs.append(str(e))); pg.on('console',lambda m: errs.append('console:'+m.text) if m.type=='error' else None)
    pg.goto('file:///tmp/claude-0/-home-claude/e902963d-2bff-54c9-acec-014774e54237/scratchpad/art.html')
    try:
        url=pg.evaluate('window.__SHEET()')
    except Exception as e:
        print('ERR',e,errs); sys.exit(1)
    im=Image.open(io.BytesIO(base64.b64decode(url.split(',')[1])))
    im=im.resize((im.width*scale,im.height*scale),Image.NEAREST); im.save(out)
    print(errs or 'ok', out, im.size)
    b.close()
