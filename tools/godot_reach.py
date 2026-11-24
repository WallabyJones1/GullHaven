"""Walkability check for the Godot map: which places can you walk (or swim) to from the
spawn, which building doors can't you reach on foot, and are there spots you can get into
but never back out of?

    python3 tools/godot_reach.py godot

Mirrors the player's limits in scripts/player.gd (wading depth, slope, step-up, how high
you can haul yourself out of the water) and the dock fix in scripts/town_builder.gd. Needs
numpy (and scipy to group the pits).
"""
import json, sys, math
import numpy as np
from collections import deque
root = sys.argv[1]
m = json.load(open(f'{root}/world/world.json')); W, H = m['size']; sl = m.get('sea_level', 0.0)
h = np.fromfile(f'{root}/world/height.bin', dtype='<f4').reshape(H, W).astype(np.float64)
data = np.fromfile(f'{root}/world/data.bin', dtype=np.uint8)
zones = data[W*H:2*W*H].reshape(H, W); flags = data[3*W*H:4*W*H].reshape(H, W)
zone_names = m['zones']; lake_i = zone_names.index('lake') if 'lake' in zone_names else -1
wl = np.full((H, W), sl); 
if lake_i >= 0: wl[zones == lake_i] = float(m['lakes'][0]['level'])
top = h.copy()          # what you stand on
solid = np.zeros((H, W), bool)  # blocked by a building
WADE, CLIMB, SLOPE, STEP = 0.35, 1.8, math.tan(math.radians(48)), 0.36
ROT = [math.pi*0.5, 0.0, -math.pi*0.5, math.pi]
doors = []
def reach_shore(r, t):
    x0,z0,x1,z1 = r; lx=(x1-x0)>=(z1-z0); cx=(x0+x1)/2; cz=(z0+z1)/2
    def ht(x,z):
        ix,iz=int(math.floor(x)),int(math.floor(z)); fx,fz=x-ix,z-iz
        g=lambda a,b: float(h[max(0,min(H-1,b)),max(0,min(W-1,a))])
        return (g(ix,iz)*(1-fx)+g(ix+1,iz)*fx)*(1-fz)+(g(ix,iz+1)*(1-fx)+g(ix+1,iz+1)*fx)*fz
    glo=ht(x0-0.5,cz) if lx else ht(cx,z0-0.5); ghi=ht(x1+0.5,cz) if lx else ht(cx,z1+0.5)
    d=1 if ghi>=glo else -1
    if max(glo,ghi)>=t-0.3: return r
    e=(x1 if d>0 else x0) if lx else (z1 if d>0 else z0)
    for i in range(32):
        e+=d*0.5
        g=ht(e+d*0.4,cz) if lx else ht(cx,e+d*0.4)
        if g>=t-0.3: return [min(x0,e),z0,max(x1,e),z1] if lx else [x0,min(z0,e),x1,max(z1,e)]
    return r
deck = np.zeros((H, W), bool)
def lay(x0, z0, x1, z1, y):
    for z in range(int(math.floor(z0)), int(math.ceil(z1))):
        for x in range(int(math.floor(x0)), int(math.ceil(x1))):
            if 0 <= x < W and 0 <= z < H:
                top[z, x] = max(top[z, x], y); deck[z, x] = True
for t in m['towns']:
    y = float(t['h'])
    for q in t.get('quays', []): lay(q['x0'], q['z0'], q['x1'], q['z1'], y)
    for dk in t.get('docks', []):
        r = dk['rect'] if t.get('quays') else reach_shore(dk['rect'], y - 0.1)
        lay(r[0], r[1], r[2], r[3], y - 0.1)
    for b in t['buildings']:
        a = ROT[int(b['rot'])]; w, d = float(b['w']), float(b['d']); bx, bz = float(b['x']), float(b['z'])
        ca, sa = math.cos(a), math.sin(a)
        for z in range(int(bz - 8), int(bz + 9)):
            for x in range(int(bx - 8), int(bx + 9)):
                if 0 <= x < W and 0 <= z < H:
                    # into the building's own frame (Godot's Y rotation, inverted)
                    ux = x + 0.5 - bx; uz = z + 0.5 - bz
                    llx = ux * ca - uz * sa; llz = ux * sa + uz * ca
                    if abs(llx) < w / 2 - 0.2 and abs(llz) < d / 2 - 0.2:
                        solid[z, x] = True
        L = d / 2 + 0.9
        dx, dz = L * math.sin(a), L * math.cos(a)
        doors.append((t['id'], b['name'], bx + dx, bz + dz))
br = m['bridge']; bx = float(br['x']); bz = float(br['z']); bl = float(br['length'])
lay(bx - 1.6, bz - bl / 2 - 5, bx + 1.6, bz + bl / 2 + 5, 1.72)
water = (top < wl - WADE) & ~deck
def nb(x, z):
    for dx, dz in ((1,0),(-1,0),(0,1),(0,-1)):
        X, Z = x+dx, z+dz
        if 0 <= X < W and 0 <= Z < H and not solid[Z, X]:
            yield X, Z
def can(a, b, swim=True):
    (x, z), (X, Z) = a, b
    if water[Z, X]:
        return swim
    if water[z, x]:  # climbing out
        return swim and top[Z, X] - wl[z, x] <= CLIMB
    dh = top[Z, X] - top[z, x]
    return dh <= max(SLOPE, STEP)
def bfs(start, swim, reverse=False):
    seen = np.zeros((H, W), bool); q = deque([start]); seen[start[1], start[0]] = True
    while q:
        c = q.popleft()
        for n in nb(*c):
            if seen[n[1], n[0]]: continue
            if (can(n, c, swim) if reverse else can(c, n, swim)):
                seen[n[1], n[0]] = True; q.append(n)
    return seen
sp = (int(m['spawn'][0]), int(m['spawn'][1]))
foot = bfs(sp, False)
swim_f = bfs(sp, True); swim_b = bfs(sp, True, reverse=True)
print('cells reachable on foot', int(foot.sum()), 'with swimming', int(swim_f.sum()))
traps = swim_f & ~swim_b & ~water
print('land cells you can reach but never leave (even swimming):', int(traps.sum()))
if traps.sum():
    from scipy import ndimage
    lab, n = ndimage.label(traps)
    sizes = ndimage.sum(traps, lab, range(1, n + 1))
    for i in np.argsort(-sizes)[:15]:
        zz, xx = np.where(lab == i + 1)
        print(f'  pit {int(sizes[i])} cells around x {xx.mean():.0f} z {zz.mean():.0f}, ground {h[zz, xx].mean():.1f}')
print('doors not reachable on foot from the spawn:')
for tid, name, x, z in doors:
    X, Z = int(x), int(z)
    ok = any(foot[zz, xx] for zz in range(Z-1, Z+2) for xx in range(X-1, X+2) if 0 <= xx < W and 0 <= zz < H)
    oks = any(swim_f[zz, xx] for zz in range(Z-1, Z+2) for xx in range(X-1, X+2) if 0 <= xx < W and 0 <= zz < H)
    if not ok: print(f'  {tid:10s} {name:28s} at {x:.0f},{z:.0f}  ground {h[Z,X]:.2f}  reachable swimming/boat: {oks}')
