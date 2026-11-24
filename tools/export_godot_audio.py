"""Render Gullhaven's synthesized sound for the Godot (HD-2D) project.
Usage: python3 tools/export_godot_audio.py   (needs Python playwright and ffmpeg)

The web game makes every sound in code with WebAudio (src/js/m00b_audio.js). This runs the
same code in an OfflineAudioContext inside Chromium, so the Godot build sounds like Gullhaven:
- every effect from sfx() as audio/sfx/<name>.ogg
- the day, night and storm music as seamless loops in audio/music/
- extra ambience and foley made the same way (waves, rain, wind, gulls, crickets, steps)
Re-run after changing m00b_audio.js."""
import os, sys, json, base64, struct, subprocess, tempfile, wave
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot', 'audio')
SR = 32000
AUDIO_JS = open(os.path.join(ROOT, 'src/js/m00b_audio.js')).read()

# effects to export, with how long to render each (seconds)
SFX = {
    'cast': .5, 'splash': .6, 'bite': .4, 'reel': .1, 'catch': .8, 'coin': .4, 'buy': .4,
    'error': .4, 'lvl': 1.0, 'snap': .4, 'whoosh': .6, 'click': .1, 'fanfare1': .8,
    'fanfare2': 1.4, 'jackpot': 2.6, 'cardflip': .8, 'whistle': .6, 'thud': .4, 'purr': .7,
    'quack': .5, 'crank': .1, 'burstsoft': .5, 'perfect': .4, 'good': .3, 'miss': .4,
    'pin': .2, 'horn': 1.4,
}

PAGE = r"""
let S={sound:1,music:1};const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));const fmt=n=>String(n);
""" + AUDIO_JS + r"""
// a seeded random so renders are repeatable
function seeded(s){return()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
function fresh(sec){const A=new OfflineAudioContext(1,Math.ceil(sec*SRATE),SRATE);SFX.ctx=A;SFX.master=A.createGain();SFX.master.gain.value=.5;SFX.master.connect(A.destination);
  const n=A.sampleRate*.6|0;SFX.noiseBuf=A.createBuffer(1,n,A.sampleRate);const d=SFX.noiseBuf.getChannelData(0);const R=seeded(7);for(let i=0;i<n;i++)d[i]=R()*2-1;return A}
async function pcm(A,peakDb){const buf=await A.startRendering();const d=buf.getChannelData(0);const out=new Int16Array(d.length);
  let mx=1e-6;for(let i=0;i<d.length;i++)mx=Math.max(mx,Math.abs(d[i]));const k=Math.pow(10,(peakDb==null?-6:peakDb)/20)/mx;
  for(let i=0;i<d.length;i++){const v=Math.max(-1,Math.min(1,d[i]*k));out[i]=v*32767}
  let s='';const u=new Uint8Array(out.buffer);for(let i=0;i<u.length;i+=32768)s+=String.fromCharCode.apply(null,u.subarray(i,i+32768));return btoa(s)}
async function renderSfx(k,sec,peak){const A=fresh(sec);sfx(k);return pcm(A,peak)}
// the music sequencer from musTick(), stepped through offline for whole chord cycles
async function renderMusic(mode,cycles,tail,peak){const P=PROGS[mode];const st=60/P.bpm/2;const steps=32*cycles;const A=fresh(steps*st+tail);
  MUS.gain=A.createGain();MUS.gain.gain.value=.5;MUS.gain.connect(SFX.master);MUS.mel=2;const R=seeded(mode.length*97+cycles);const rnd=Math.random;Math.random=R;
  const soft=!!P.soft;
  for(let s=0;s<steps;s++){const beat=s%8,bar=Math.floor(s/8)%4,ch=P.ch[bar],at=s*st;
    if(beat===0||beat===4)mnote(mtof(ch[0]-12),st*3.6,'triangle',soft?.09:.11,at);
    if((mode==='arcade'||mode==='storm')&&beat%2===1)mnote(mtof(ch[0]-12),st*.8,'triangle',.07,at);
    const pat=[0,1,2,1,0,2,1,2];if(!soft||beat%2===0)mnote(mtof(ch[pat[beat]]+12),st*.9,mode==='lake'||mode==='deep'?'sine':'square',mode==='arcade'?.03:.02,at);
    if(!soft&&beat%2===1)mhat(at);
    if((beat===0||beat===3||beat===6)&&Math.random()<(soft?.45:.6)){MUS.mel=clamp(MUS.mel+Math.floor(Math.random()*3)-1,0,P.sc.length-1);const n=P.sc[MUS.mel];if(ch.some(c=>(n-c)%12===0)||Math.random()<.5)mnote(mtof(n),st*(beat===6?2.5:1.6),'triangle',soft?.045:.05,at)}}
  Math.random=rnd;return{pcm:await pcm(A,peak),loop:steps*st}}
// ambience and foley, built from the same noise and tone helpers
function nz(A,at,dur,o){const s=A.createBufferSource();s.buffer=SFX.noiseBuf;s.loop=true;const f=A.createBiquadFilter();f.type=o.type||'lowpass';f.frequency.setValueAtTime(o.f||1000,at);if(o.fto)f.frequency.linearRampToValueAtTime(o.fto,at+dur);f.Q.value=o.q||.7;
  const g=A.createGain();g.gain.setValueAtTime(0,at);g.gain.linearRampToValueAtTime(o.vol||.1,at+(o.att||.01));g.gain.linearRampToValueAtTime(o.mid==null?(o.vol||.1):o.mid,at+dur*(o.hold||.5));g.gain.linearRampToValueAtTime(0,at+dur);
  s.connect(f);f.connect(g);g.connect(SFX.master);s.start(at,Math.random()*.5);s.stop(at+dur+.05)}
function osc(A,at,dur,f,o){const x=A.createOscillator(),g=A.createGain();x.type=o.type||'sine';x.frequency.setValueAtTime(f,at);if(o.to)x.frequency.exponentialRampToValueAtTime(o.to,at+dur);
  g.gain.setValueAtTime(0,at);g.gain.linearRampToValueAtTime(o.vol||.05,at+(o.att||.01));g.gain.exponentialRampToValueAtTime(.0005,at+dur);x.connect(g);g.connect(SFX.master);x.start(at);x.stop(at+dur+.03)}
async function renderAmb(k,peak){const R=seeded(k.length*31+5);const rnd=Math.random;Math.random=R;let A,loop=0;
  if(k==='waves'){loop=24;A=fresh(loop+5);for(let t=0;t<loop;t+=3.2+R()*1.6){const d=3.5+R()*2;nz(A,t,d,{f:380+R()*260,fto:900+R()*500,vol:.32+R()*.12,att:d*.45,hold:.55,mid:.22});nz(A,t+d*.4,d*.8,{type:'highpass',f:2500,vol:.05,att:.3})}nz(A,0,loop+5,{f:240,vol:.1,att:.01,mid:.1,hold:.99})}
  else if(k==='rain'){loop=12;A=fresh(loop+3);nz(A,0,loop+3,{type:'bandpass',f:3200,q:.4,vol:.22,att:.01,mid:.22,hold:.99});for(let t=0;t<loop;t+=.02+R()*.06)nz(A,t,.03,{type:'highpass',f:3000+R()*4000,vol:.04+R()*.06,att:.002,mid:.01,hold:.2})}
  else if(k==='wind'){loop=16;A=fresh(loop+5);for(let t=0;t<loop;t+=4){nz(A,t,6,{type:'bandpass',f:300+R()*300,fto:700+R()*600,q:1.6,vol:.28,att:2.5,hold:.5,mid:.2})}}
  else if(k==='crickets'){loop=8;A=fresh(loop+1);for(let t=0;t<loop;t+=.9+R()*.6){const f=4200+R()*600;for(let i=0;i<3+(R()*3|0);i++)osc(A,t+i*.07,.05,f,{vol:.025,att:.005})}}
  else if(k==='gull'){A=fresh(1.6);for(let i=0;i<2+(R()*2|0);i++){const t=i*.38;osc(A,t,.32,1500+R()*200,{type:'sawtooth',to:850,vol:.035,att:.03});osc(A,t,.32,3000,{type:'sine',to:1700,vol:.012,att:.03})}}
  else if(k==='thunder'){A=fresh(3.5);nz(A,0,.25,{f:2000,vol:.5,att:.005,mid:.2,hold:.3});nz(A,.1,3.2,{f:180,fto:60,vol:.55,att:.2,hold:.3,mid:.35})}
  else if(k==='step_wood'){A=fresh(.2);nz(A,0,.07,{f:700,vol:.35,att:.003,mid:.1,hold:.3});osc(A,0,.08,150,{type:'triangle',to:90,vol:.18,att:.003})}
  else if(k==='step_stone'){A=fresh(.15);nz(A,0,.05,{type:'bandpass',f:1800,q:1.2,vol:.4,att:.002,mid:.1,hold:.3})}
  else if(k==='step_sand'){A=fresh(.2);nz(A,0,.11,{f:1400,fto:600,vol:.22,att:.01,mid:.12,hold:.4})}
  else if(k==='step_grass'){A=fresh(.2);nz(A,0,.09,{type:'bandpass',f:2600,q:.8,vol:.14,att:.01,mid:.06,hold:.4})}
  else if(k==='plop'){A=fresh(.5);nz(A,0,.18,{f:1200,fto:250,vol:.3,att:.003,mid:.1,hold:.3});osc(A,0,.16,420,{type:'sine',to:140,vol:.12,att:.003})}
  else if(k==='jump'){A=fresh(.8);nz(A,0,.5,{f:2600,fto:500,vol:.32,att:.005,mid:.15,hold:.3});osc(A,.02,.2,600,{type:'sine',to:200,vol:.06})}
  else if(k==='bubbles'){loop=6;A=fresh(loop+1);for(let t=0;t<loop;t+=.04+R()*.12)osc(A,t,.06,500+R()*900,{type:'sine',to:900+R()*1200,vol:.03+R()*.03,att:.004})}
  Math.random=rnd;return{pcm:await pcm(A,peak),loop}}
"""

# name: target peak in dBFS (loops get headroom because their tails fold back onto the start)
AMB = {'waves': -9, 'rain': -12, 'wind': -12, 'crickets': -14, 'gull': -8, 'thunder': -2,
       'step_wood': -8, 'step_stone': -8, 'step_sand': -8, 'step_grass': -8, 'plop': -5,
       'jump': -4, 'bubbles': -12}
MUSIC = {'day': 8, 'night': 6, 'storm': 8}


def samples(b64):
    raw = base64.b64decode(b64)
    return list(struct.unpack('<%dh' % (len(raw) // 2), raw))


def trim(x, floor=60):
    end = len(x)
    while end > 1 and abs(x[end - 1]) < floor:
        end -= 1
    return x[:min(len(x), end + int(SR * .02))]


def wrap(x, loop_sec):
    """Fold the tail past the loop point back onto the start, so the file loops seamlessly."""
    n = int(round(loop_sec * SR))
    body, tail = x[:n], x[n:]
    for i, v in enumerate(tail[:n]):
        body[i] = max(-32768, min(32767, body[i] + v))
    return body


def write_ogg(x, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        w = wave.open(tmp.name, 'wb')
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(struct.pack('<%dh' % len(x), *x)); w.close()
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', tmp.name, '-c:a', 'libvorbis',
                        '-q:a', '4', path], check=True)
    os.unlink(tmp.name)


html = '<html><body><script>const SRATE=%d;\n%s</script></body></html>' % (SR, PAGE)
page_path = os.path.join(tempfile.gettempdir(), 'gullhaven_audio_export.html')
open(page_path, 'w').write(html)
count = 0
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + page_path)
    if errs:
        print('page errors:', errs); sys.exit(1)
    for k, sec in SFX.items():
        write_ogg(trim(samples(pg.evaluate('([k,s])=>renderSfx(k,s,-4)', [k, sec]))), 'sfx/%s.ogg' % k); count += 1
    for k, peak in AMB.items():
        r = pg.evaluate('([k,p])=>renderAmb(k,p)', [k, peak])
        x = samples(r['pcm'])
        x = wrap(x, r['loop']) if r['loop'] else trim(x)
        write_ogg(x, ('amb/%s.ogg' if r['loop'] else 'sfx/%s.ogg') % k); count += 1
    for k, cycles in MUSIC.items():
        r = pg.evaluate('([k,c])=>renderMusic(k,c,4,-8)', [k, cycles])
        write_ogg(wrap(samples(r['pcm']), r['loop']), 'music/%s.ogg' % k); count += 1
    b.close()
    if errs:
        print('page errors:', errs); sys.exit(1)
print('wrote', count, 'sounds into', OUT)
