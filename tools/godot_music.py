"""Gullhaven HD-2D: original music, composed here and synthesized in numpy.
Usage: python3 tools/godot_music.py [track ...]   (needs scipy and ffmpeg with libvorbis)

Every track is written out below as chords and a melody in note names, played by a small
band of synthesized instruments: plucked strings (Karplus-Strong), accordion, fiddle,
flute and whistle, steel drum and bells (FM), music box, marimba, warm pads, bass and a
few drums, then a touch of stereo reverb. Each one loops seamlessly (the reverb tail and
any ringing notes wrap round to the start). Writes godot/audio/music/<track>.ogg.

  title     the Gullhaven theme, a shanty waltz         (title screen)
  town      Gullhaven by day                             (in town)
  river     Willowford and the estuary, a 6/8 pastoral
  islands   steel drums for the island villages
  lake      Mirrorlake, glassy and still
  sailing   out on the open water
  mystery   the keeper's secret
  tavern    a jig for the Gull & Anchor and the inns
  fight     a tough fish on the line
  dive      under the water with the speargun
  home      Gran's hut, and making your fisher
"""
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy.signal import lfilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot', 'audio', 'music')
SR = 32000
NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
QUAL = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'maj7': [0, 4, 7, 11],
        'sus2': [0, 2, 7], 'sus4': [0, 5, 7], 'dim': [0, 3, 6], 'm9': [0, 3, 7, 10, 14], '7sus4': [0, 5, 7, 10],
        'add9': [0, 4, 7, 14]}


def midi(name):
    """'F#4' -> 66."""
    n = NOTE[name[0]]
    i = 1
    while i < len(name) and name[i] in '#b':
        n += 1 if name[i] == '#' else -1
        i += 1
    return n + 12 * (int(name[i:]) + 1)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def chord(sym, octave=4):
    """'Bm7' -> midi notes from the root in the given octave."""
    root = NOTE[sym[0]]
    i = 1
    while i < len(sym) and sym[i] in '#b':
        root += 1 if sym[i] == '#' else -1
        i += 1
    q = sym[i:]
    return [12 * (octave + 1) + root + x for x in QUAL[q]]


def melody(text):
    """'A4:1 D5:0.5 r:1' -> [(beat, dur, midi or None)]."""
    out = []
    t = 0.0
    for tok in text.replace('|', ' ').split():
        n, d = tok.split(':')
        d = float(d)
        out.append((t, d, None if n == 'r' else midi(n)))
        t += d
    return out, t


# ----------------------------------------------------------------------- instruments

def env(n, a, d, s, r, sus_len):
    """ADSR over n samples: attack a, decay d, sustain level s, release r (seconds)."""
    e = np.zeros(n)
    A = max(1, int(a * SR))
    D = max(1, int(d * SR))
    S = max(0, int(sus_len * SR) - A - D)
    R = max(1, int(r * SR))
    seg = np.concatenate([np.linspace(0, 1, A, endpoint=False), np.linspace(1, s, D, endpoint=False), np.full(S, s),
                          np.linspace(s, 0, R)])
    m = min(n, len(seg))
    e[:m] = seg[:m]
    return e


def t_axis(n):
    return np.arange(n) / SR


def saw(ph):
    """A band-limited (polyBLEP) sawtooth from a running phase in cycles, so high notes
    don't alias into a harsh fizz."""
    t = ph % 1.0
    dt = np.abs(np.diff(ph, prepend=ph[0] - (ph[1] - ph[0] if len(ph) > 1 else 0.01)))
    dt = np.clip(dt, 1e-6, 0.5)
    y = 2.0 * t - 1.0
    m = t < dt
    x = t[m] / dt[m]
    y[m] -= x + x - x * x - 1.0
    m = t > 1.0 - dt
    x = (t[m] - 1.0) / dt[m]
    y[m] -= x * x + x + x + 1.0
    return y


def onepole(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def vib(n, rate, depth, delay=0.25):
    t = t_axis(n)
    ramp_in = np.clip((t - delay) / 0.3, 0, 1)
    return 1.0 + depth * ramp_in * np.sin(2 * math.pi * rate * t)


def phase(f, n, mod=None):
    inc = f / SR * (mod if mod is not None else 1.0)
    return np.cumsum(np.full(n, inc) if mod is None else inc)


def pluck(f, dur, bright=0.5, decay=0.996):
    n = int((dur + 1.2) * SR)
    N = max(2, int(SR / f))
    rng = np.random.default_rng(int(f * 100) % 9973)
    burst = rng.uniform(-1, 1, N)
    burst = onepole(burst, 1500 + 6000 * bright)
    x = np.zeros(n)
    x[:N] = burst
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -decay * 0.5
    a[N + 1] = -decay * 0.5
    y = lfilter([1.0], a, x)
    rel = env(n, 0.002, 0.01, 1.0, 0.08, dur + 0.6)
    return y * rel * 0.9


def flute(f, dur, breath=0.06):
    n = int((dur + 0.3) * SR)
    ph = phase(f, n, vib(n, 5.2, 0.006))
    x = np.sin(2 * math.pi * ph) + 0.18 * np.sin(4 * math.pi * ph) + 0.06 * np.sin(6 * math.pi * ph)
    rng = np.random.default_rng(int(f) + n)
    x += breath * onepole(rng.uniform(-1, 1, n), 3000)
    return x * env(n, 0.06, 0.1, 0.85, 0.18, dur) * 0.6


def whistle(f, dur):
    n = int((dur + 0.25) * SR)
    ph = phase(f, n, vib(n, 6.0, 0.008, 0.18))
    x = np.sin(2 * math.pi * ph) + 0.05 * np.sin(4 * math.pi * ph)
    rng = np.random.default_rng(int(f) * 3 + n)
    x += 0.035 * onepole(rng.uniform(-1, 1, n), 5000)
    return x * env(n, 0.03, 0.08, 0.8, 0.12, dur) * 0.55


def accordion(f, dur):
    n = int((dur + 0.2) * SR)
    t = t_axis(n)
    x = saw(phase(f * 1.0035, n)) + saw(phase(f * 0.9965, n)) + 0.5 * saw(phase(f * 2.0, n))
    x = onepole(onepole(x, 2200), 3000)
    x *= 1.0 + 0.08 * np.sin(2 * math.pi * 5.5 * t)
    return x * env(n, 0.03, 0.08, 0.8, 0.1, dur) * 0.22


def fiddle(f, dur):
    n = int((dur + 0.2) * SR)
    ph = phase(f, n, vib(n, 5.8, 0.01, 0.12))
    x = saw(ph) + 0.3 * saw(ph * 2.0)
    x = onepole(onepole(x, 3200), 4200)
    return x * env(n, 0.04, 0.1, 0.75, 0.12, dur) * 0.3


def fm_bell(f, dur, ratio=2.0, index=3.0, decay=1.4, amp=0.45):
    n = int((dur + decay * 1.5) * SR)
    t = t_axis(n)
    e = np.exp(-t / decay)
    mod = index * np.exp(-t / (decay * 0.4)) * np.sin(2 * math.pi * f * ratio * t)
    x = np.sin(2 * math.pi * f * t + mod)
    attack = np.clip(t / 0.004, 0, 1)
    return x * e * attack * amp


def mix(*parts):
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[:len(p)] += p
    return out


def steel(f, dur):
    return mix(fm_bell(f, dur, ratio=1.0, index=2.2, decay=0.55, amp=0.5),
               fm_bell(f * 2.0, dur, ratio=3.0, index=0.8, decay=0.25, amp=0.12))


def musicbox(f, dur):
    return mix(fm_bell(f, dur, ratio=3.0, index=1.2, decay=0.9, amp=0.4),
               fm_bell(f * 4.0, dur, ratio=1.0, index=0.0, decay=0.25, amp=0.08))


def marimba(f, dur):
    n = int((dur + 0.6) * SR)
    t = t_axis(n)
    x = np.sin(2 * math.pi * f * t) * np.exp(-t / 0.35) + 0.25 * np.sin(2 * math.pi * f * 4.0 * t) * np.exp(-t / 0.06)
    return x * np.clip(t / 0.003, 0, 1) * 0.5


def pad(f, dur):
    n = int((dur + 1.0) * SR)
    x = sum(saw(phase(f * d, n)) for d in (1.0, 1.006, 0.994)) + 0.4 * np.sin(2 * math.pi * phase(f * 0.5, n))
    x = onepole(onepole(x, 900), 1400)
    return x * env(n, 0.6, 0.4, 0.8, 0.9, dur) * 0.12


def bass(f, dur):
    n = int((dur + 0.15) * SR)
    t = t_axis(n)
    ph = phase(f, n)
    x = np.sin(2 * math.pi * ph) + 0.35 * np.abs(saw(ph)) - 0.17
    x = np.tanh(1.6 * x)
    return x * env(n, 0.005, 0.15, 0.7, 0.08, dur) * 0.5 * (1.0 + 0.0 * t)


def chip(f, dur):
    n = int((dur + 0.08) * SR)
    ph = phase(f, n)
    x = 0.5 * (saw(ph) - saw(ph + 0.25))  # a quarter-duty pulse from two saws
    x = onepole(x, 4000) * 2.0
    return x * env(n, 0.005, 0.05, 0.6, 0.06, dur) * 0.12


def kick(_f, _dur):
    n = int(0.35 * SR)
    t = t_axis(n)
    fr = 50 + 90 * np.exp(-t / 0.04)
    x = np.sin(2 * math.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.12)
    return x * 0.9


def snare(_f, _dur):
    n = int(0.25 * SR)
    t = t_axis(n)
    rng = np.random.default_rng(11)
    x = rng.uniform(-1, 1, n)
    x = x - onepole(x, 1200)
    x = x * np.exp(-t / 0.08) * 0.5 + np.sin(2 * math.pi * 190 * t) * np.exp(-t / 0.05) * 0.4
    return x * 0.6


def hat(_f, _dur):
    n = int(0.08 * SR)
    t = t_axis(n)
    rng = np.random.default_rng(5)
    x = rng.uniform(-1, 1, n)
    x = x - onepole(x, 7000)
    return x * np.exp(-t / 0.02) * 0.35


def shaker(_f, _dur):
    n = int(0.12 * SR)
    t = t_axis(n)
    rng = np.random.default_rng(9)
    x = rng.uniform(-1, 1, n)
    x = onepole(x - onepole(x, 4000), 9000)
    e = np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.04)
    return x * e * 0.35


def stomp(_f, _dur):
    n = int(0.3 * SR)
    t = t_axis(n)
    fr = 70 + 40 * np.exp(-t / 0.03)
    rng = np.random.default_rng(3)
    x = np.sin(2 * math.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.09) + 0.25 * onepole(rng.uniform(-1, 1, n), 900) * np.exp(-t / 0.03)
    return x * 0.7


def bongo(f, _dur):
    n = int(0.25 * SR)
    t = t_axis(n)
    fr = f * (1 + 0.3 * np.exp(-t / 0.01))
    return np.sin(2 * math.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.07) * 0.45


INST = {'pluck': pluck, 'flute': flute, 'whistle': whistle, 'accordion': accordion, 'fiddle': fiddle, 'steel': steel,
        'musicbox': musicbox, 'marimba': marimba, 'pad': pad, 'bass': bass, 'chip': chip, 'kick': kick, 'snare': snare,
        'hat': hat, 'shaker': shaker, 'stomp': stomp, 'bongo': bongo, 'bell': fm_bell}


# ----------------------------------------------------------------------- the band

class Song:
    def __init__(self, bpm, beats_per_bar, chords, key_scale):
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.chords = chords  # one per bar ('Am D' splits the bar)
        self.scale = key_scale  # pitch classes, for harmonies
        self.events = []  # (beat, dur, midi, inst, vel, pan)
        self.bars = len(chords)

    @property
    def beats(self):
        return self.bars * self.bpb

    def chord_at(self, beat):
        bar = int(beat // self.bpb) % self.bars
        parts = self.chords[bar].split()
        k = int((beat % self.bpb) / (self.bpb / len(parts)))
        return parts[min(k, len(parts) - 1)]

    def note(self, beat, dur, m, inst, vel=1.0, pan=0.0):
        self.events.append((beat, dur, m, inst, vel, pan))

    def tune(self, text, inst, vel=1.0, pan=0.0, offset=0.0, transpose=0, harmony=0):
        notes, length = melody(text)
        if abs(length / self.bpb - round(length / self.bpb)) > 1e-6:
            raise SystemExit('a tune for %s is %.2f beats, not whole bars of %d' % (inst, length, self.bpb))
        # check each bar adds up too
        t = 0.0
        for tok in text.split('|'):
            if not tok.strip():
                continue
            bar_len = sum(float(x.split(':')[1]) for x in tok.split())
            if abs(bar_len - self.bpb) > 1e-6:
                raise SystemExit('bar "%s" is %.2f beats, not %d' % (tok.strip(), bar_len, self.bpb))
            t += bar_len
        for b, d, m in notes:
            if m is not None:
                if harmony:
                    m = self.diatonic(m, harmony)
                self.note(offset + b, d, m + transpose, inst, vel, pan)
        return length

    def diatonic(self, m, steps):
        """Move a note up or down the key's scale (for harmonies a third or sixth away)."""
        pcs = sorted(self.scale)
        octave, pc = divmod(m, 12)
        if pc not in pcs:
            pc = min(pcs, key=lambda p: abs(p - pc))
        i = pcs.index(pc) + steps
        o, i = divmod(i, len(pcs))
        return (octave + o) * 12 + pcs[i]

    # accompaniment patterns, bar by bar
    def bassline(self, inst='bass', pattern=((0, 1.0, 0), (2, 1.0, 7)), octave=2, vel=1.0, bars=None):
        for bar in range(self.bars if bars is None else bars):
            for off, dur, iv in pattern:
                b = bar * self.bpb + off
                root = chord(self.chord_at(b), octave)[0]
                self.note(b, dur, root + iv, inst, vel)

    def arp(self, inst, pattern, step, octave=4, vel=0.6, pan=0.0, bars=None):
        n = int(self.bpb / step)
        for bar in range(self.bars if bars is None else bars):
            for i in range(n):
                b = bar * self.bpb + i * step
                tones = chord(self.chord_at(b), octave)
                k = pattern[i % len(pattern)]
                m = tones[k % len(tones)] + 12 * (k // len(tones))
                self.note(b, step * 1.6, m, inst, vel, pan)

    def stabs(self, inst, beats, dur, octave=4, vel=0.5, pan=0.0, spread=0.0):
        for bar in range(self.bars):
            for off in beats:
                b = bar * self.bpb + off
                for j, m in enumerate(chord(self.chord_at(b), octave)[:4]):
                    self.note(b + j * spread, dur, m, inst, vel, pan)

    def held(self, inst, octave=3, vel=0.6):
        for bar in range(self.bars):
            parts = self.chords[bar].split()
            seg = self.bpb / len(parts)
            for k, sym in enumerate(parts):
                for m in chord(sym, octave):
                    self.note(bar * self.bpb + k * seg, seg, m, inst, vel)

    def drums(self, inst, beats, vel=0.6, pan=0.0, every_bar=True, pitch=0):
        for bar in range(self.bars):
            for off in beats:
                self.note(bar * self.bpb + off, 0.1, pitch, inst, vel, pan)

    def render(self, reverb=0.25):
        spb = 60.0 / self.bpm
        length = int(self.beats * spb * SR)
        tail = int(6.0 * SR)
        L = np.zeros(length + tail)
        R = np.zeros(length + tail)
        cache = {}
        for beat, dur, m, inst, vel, pan in self.events:
            f = hz(m) if m else 0.0
            key = (inst, round(f, 3), round(dur * spb, 3))
            if key not in cache:
                cache[key] = INST[inst](f if f else 200.0, dur * spb)
            x = cache[key] * vel
            s = int(beat * spb * SR)
            e = min(len(L), s + len(x))
            if s >= len(L):
                continue
            gl = math.cos((pan + 1) * math.pi / 4)
            gr = math.sin((pan + 1) * math.pi / 4)
            L[s:e] += x[:e - s] * gl
            R[s:e] += x[:e - s] * gr
        # anything still ringing at the end comes round to the start
        for ch in (L, R):
            ch[:tail] += ch[length:length + tail]
        L, R = L[:length], R[:length]
        if reverb > 0:
            wl, wr = stereo_reverb(L, R)
            L = L + reverb * wl
            R = R + reverb * wr
        return L, R


def _rows(x, d):
    n = len(x)
    rows = -(-n // d)
    xp = np.zeros(rows * d)
    xp[:n] = x
    return xp.reshape(rows, d), n


def comb(x, d, g):
    """Feedback comb y[n] = x[n] + g y[n - d], worked a delay-length block at a time."""
    X, n = _rows(x, d)
    Y = np.empty_like(X)
    Y[0] = X[0]
    for r in range(1, len(X)):
        Y[r] = X[r] + g * Y[r - 1]
    return Y.reshape(-1)[:n]


def allpass(x, d, g=0.5):
    """Schroeder allpass y[n] = -g x[n] + x[n - d] + g y[n - d]."""
    X, n = _rows(x, d)
    Y = np.empty_like(X)
    Y[0] = -g * X[0]
    for r in range(1, len(X)):
        Y[r] = -g * X[r] + X[r - 1] + g * Y[r - 1]
    return Y.reshape(-1)[:n]


def stereo_reverb(L, R):
    out = []
    for x, extra in ((L, 0), (R, 23)):
        twice = onepole(np.concatenate([x, x]), 5000)  # run it round twice so the tail wraps seamlessly
        y = sum(comb(twice, d + extra, g) for d, g in ((810, 0.80), (862, 0.79), (927, 0.78), (984, 0.77), (1060, 0.76)))
        y = onepole(y, 4200)  # darker tail
        y = allpass(allpass(y, 403 + extra), 320 + extra)
        y = y - onepole(y, 180)  # keep the low end clean
        out.append(y[len(x):] * 0.18)
    return out[0], out[1]


def master(L, R, target_db=-25.0):
    """Even loudness from track to track (a little above the web game's day and night loops,
    which are sparser), with a soft limit on the odd peak."""
    st = np.stack([L, R], 1)
    rms = math.sqrt(float(np.mean(st ** 2))) + 1e-9
    st *= 10 ** (target_db / 20) / rms
    over = np.abs(st) > 0.6
    st[over] = np.sign(st[over]) * (0.6 + 0.4 * np.tanh((np.abs(st[over]) - 0.6) / 0.4))
    peak = float(np.max(np.abs(st)))
    if peak > 0.97:
        st *= 0.97 / peak
    return st


def write_ogg(st, name):
    os.makedirs(OUT, exist_ok=True)
    pcm = (st * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        path = tmp.name
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-c:a', 'libvorbis', '-q:a', '4', out], check=True)
    os.unlink(path)
    return out


MAJOR = [0, 2, 4, 5, 7, 9, 11]


def scale(root, kind=MAJOR):
    r = NOTE[root[0]] + (1 if '#' in root else -1 if 'b' in root[1:] else 0)
    return [(r + x) % 12 for x in kind]


# ----------------------------------------------------------------------- the songs

def title():
    a = 'D D G D Bm G A A'.split()
    a2 = 'D D G D G A D D'.split()
    b = 'G D Em A G D A D'.split()
    s = Song(100, 3, a + a2 + b, scale('D'))
    mel_a = ('A4:1 D5:1 E5:1 | F#5:2 E5:0.5 D5:0.5 | B4:1 D5:1 G5:1 | F#5:3 | F#5:1 E5:1 D5:1 | B4:1.5 C#5:0.5 D5:1 |'
             ' E5:1 C#5:1 A4:1 | E5:3')
    mel_a2 = ('A4:1 D5:1 E5:1 | F#5:2 A5:1 | B5:1.5 A5:0.5 G5:1 | F#5:2 D5:1 | G5:1 F#5:1 E5:1 | E5:1 D5:1 C#5:1 |'
              ' D5:3 | A4:1 B4:1 C#5:1')
    mel_b = ('D5:1 B4:1 D5:1 | F#5:1.5 E5:0.5 D5:1 | E5:1 G5:1 B5:1 | A5:2 G5:0.5 F#5:0.5 | G5:1 E5:1 D5:1 |'
             ' F#5:1 A5:1 F#5:1 | E5:1.5 F#5:0.5 E5:1 | D5:2 r:1')
    s.tune(mel_a, 'accordion', 0.9, 0.1)
    s.tune(mel_a2, 'whistle', 0.85, -0.1, offset=24)
    s.tune(mel_a2, 'accordion', 0.45, 0.2, offset=24, harmony=-2)
    s.tune(mel_b, 'fiddle', 0.85, 0.15, offset=48)
    s.tune(mel_b, 'flute', 0.5, -0.25, offset=48, harmony=2)
    s.bassline('pluck', ((0, 1.0, 0), (2, 0.9, 7)), octave=2, vel=0.9)
    s.bassline('bass', ((0, 2.5, 0),), octave=2, vel=0.5)
    s.stabs('pluck', (1, 2), 0.8, octave=4, vel=0.45, pan=-0.3, spread=0.02)
    s.held('pad', 3, 0.35)
    s.drums('stomp', (0,), 0.35)
    return s


def town():
    chords = ['G', 'Em', 'C', 'D', 'G', 'Em', 'Am D', 'G', 'C', 'D', 'Bm', 'Em', 'C', 'D', 'G', 'G']
    s = Song(108, 4, chords * 2, scale('G'))
    mel = ('D5:1 B4:0.5 D5:0.5 G5:1 F#5:0.5 E5:0.5 | D5:1.5 B4:0.5 E5:2 | E5:1 G5:0.5 E5:0.5 C5:1 E5:1 | D5:3 r:1 |'
           ' D5:1 B4:0.5 D5:0.5 G5:1 A5:0.5 B5:0.5 | B5:1 A5:0.5 G5:0.5 E5:2 | C5:1 E5:1 F#5:1 A5:1 | G5:3 r:1 |'
           ' E5:1 E5:0.5 F#5:0.5 G5:1 E5:1 | F#5:1 D5:1 A4:2 | B4:1 D5:0.5 F#5:0.5 B5:1.5 A5:0.5 | G5:1 F#5:1 E5:2 |'
           ' C5:1 E5:1 G5:1 E5:0.5 G5:0.5 | A5:2 F#5:1 D5:1 | B4:0.5 D5:0.5 G5:1 F#5:0.5 A5:0.5 G5:1 | G5:2 r:2')
    s.tune(mel, 'whistle', 0.9, 0.1)
    s.tune(mel, 'pluck', 0.7, 0.2, offset=64)
    s.tune(mel, 'flute', 0.55, -0.2, offset=64, harmony=-2)
    s.arp('pluck', [0, 1, 2, 1, 3, 2, 1, 2], 0.5, octave=4, vel=0.32, pan=-0.35)
    s.bassline('bass', ((0, 1.0, 0), (1.5, 0.5, 0), (2, 1.0, 7), (3.5, 0.5, 12)), octave=2, vel=0.8)
    s.drums('kick', (0, 2), 0.6)
    s.drums('snare', (1, 3), 0.25)
    s.drums('shaker', (0.5, 1.5, 2.5, 3.5), 0.3, pan=0.3)
    s.held('pad', 3, 0.25)
    return s


def river():
    chords = 'F C Dm Bb F C Bb_C F Bb F Gm C Dm Bb C F'.split()
    chords = [c.replace('_', ' ') for c in chords]
    s = Song(200, 6, chords * 2, scale('F'))  # beats are quavers in 6/8
    mel = ('C5:2 F5:1 A5:2 G5:1 | G5:3 E5:2 C5:1 | D5:2 F5:1 A5:2 F5:1 | F5:3 D5:3 | C5:2 F5:1 A5:2 C6:1 |'
           ' Bb5:2 A5:1 G5:3 | F5:2 D5:1 E5:2 G5:1 | F5:6 | D5:2 F5:1 Bb5:2 A5:1 | A5:3 F5:3 | G5:2 Bb5:1 D6:2 C6:1 |'
           ' Bb5:2 A5:1 G5:3 | A5:2 F5:1 D5:2 F5:1 | Bb5:2 A5:1 F5:3 | E5:2 F5:1 G5:2 E5:1 | F5:3 r:3')
    s.tune(mel, 'flute', 0.9, 0.1)
    s.tune(mel, 'fiddle', 0.6, -0.15, offset=96)
    s.tune(mel, 'flute', 0.4, 0.25, offset=96, harmony=-2)
    s.arp('pluck', [0, 2, 3, 1, 2, 3], 1, octave=3, vel=0.42, pan=-0.3)
    s.bassline('bass', ((0, 2.5, 0), (3, 2.5, 7)), octave=2, vel=0.6)
    s.held('pad', 3, 0.3)
    s.drums('shaker', (0, 3), 0.15, pan=0.4)
    return s


def islands():
    chords = 'C F G C Am F G C F G Em Am F G C C'.split()
    s = Song(116, 4, chords * 2, scale('C'))
    mel = ('E5:0.5 G5:0.5 r:0.5 G5:0.5 A5:1 G5:1 | F5:0.5 A5:0.5 r:0.5 A5:0.5 C6:1 A5:1 |'
           ' G5:0.5 B5:0.5 D6:1 B5:0.5 G5:0.5 D5:1 | E5:2 C5:1 r:1 | E5:0.5 A5:0.5 r:0.5 A5:0.5 C6:1 B5:1 |'
           ' A5:1 F5:0.5 A5:0.5 C6:2 | B5:1 A5:0.5 G5:0.5 F5:1 D5:1 | C5:2 r:2 |'
           ' A5:0.5 C6:0.5 A5:0.5 F5:0.5 A5:1 C6:1 | B5:0.5 D6:0.5 B5:0.5 G5:0.5 B5:2 | G5:1 E5:0.5 G5:0.5 B5:1 G5:1 |'
           ' A5:2 E5:1 C5:1 | F5:0.5 A5:0.5 C6:0.5 A5:0.5 F5:1 A5:1 | G5:0.5 B5:0.5 D6:0.5 B5:0.5 G5:1 F5:1 |'
           ' E5:1 G5:1 C6:1 G5:1 | C6:2 r:2')
    s.tune(mel, 'steel', 0.95, 0.15)
    s.tune(mel, 'marimba', 0.7, -0.2, offset=64)
    s.tune(mel, 'steel', 0.5, 0.3, offset=64, harmony=-2)
    s.arp('marimba', [0, 1, 2, 1], 0.5, octave=4, vel=0.35, pan=-0.35)
    s.bassline('bass', ((0, 0.75, 0), (1.5, 0.5, 0), (2, 0.75, 7), (3.5, 0.5, 5)), octave=2, vel=0.8)
    s.drums('shaker', (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5), 0.22, pan=0.35)
    s.drums('bongo', (0.75, 2.75), 0.4, pan=-0.4, pitch=67)
    s.drums('bongo', (1.5, 3.5), 0.35, pan=-0.3, pitch=60)
    s.drums('kick', (0, 2.5), 0.45)
    return s


def lake():
    chords = 'Em Cmaj7 Gmaj7 Dsus2 Em Am7 Cmaj7 Bm7'.split()
    s = Song(64, 4, chords * 2, scale('G'))
    mel = 'B5:2 G5:1 F#5:1 | E5:3 r:1 | D5:1 F#5:1 B5:2 | A5:3 r:1 | G5:2 F#5:1 E5:1 | C6:2 B5:1 A5:1 | G5:2 E5:2 | F#5:3 r:1'
    s.tune(mel, 'musicbox', 0.8, 0.2)
    s.tune(mel, 'flute', 0.6, -0.15, offset=32, transpose=-12)
    s.tune(mel, 'bell', 0.35, 0.35, offset=32, harmony=2)
    s.held('pad', 3, 0.55)
    s.arp('pluck', [0, 1, 2, 3, 2, 1, 0, 2], 0.5, octave=4, vel=0.2, pan=-0.4)
    s.bassline('bass', ((0, 3.5, 0),), octave=2, vel=0.4)
    return s


def sailing():
    chords = ['D', 'C', 'G', 'D', 'D', 'C', 'G A', 'D', 'Bm', 'G', 'D', 'A', 'Bm', 'G', 'A', 'D']
    s = Song(126, 4, chords * 2, scale('D', [0, 2, 4, 5, 7, 9, 10]))  # D mixolydian
    mel = ('A4:0.5 D5:0.5 F#5:0.5 A5:0.5 D6:1 A5:1 | G5:1 E5:0.5 G5:0.5 C6:1 G5:1 | B5:0.5 A5:0.5 G5:0.5 F#5:0.5 G5:1 D5:1 |'
           ' F#5:2 D5:1 r:1 | A5:0.5 A5:0.5 F#5:0.5 A5:0.5 D6:1 C6:1 | C6:0.5 B5:0.5 A5:0.5 G5:0.5 E5:2 |'
           ' D5:1 G5:1 E5:1 C#5:1 | D5:3 r:1 | F#5:1 B5:1 A5:0.5 F#5:0.5 D5:1 | G5:1.5 A5:0.5 B5:2 |'
           ' A5:1 F#5:1 D5:1 F#5:1 | E5:3 r:1 | D5:0.5 F#5:0.5 B5:1 A5:1 F#5:1 | G5:1 B5:1 D6:2 |'
           ' C#6:1 B5:0.5 A5:0.5 E5:1 C#5:1 | D5:3 r:1')
    s.tune(mel, 'whistle', 0.9, 0.1, transpose=-12)
    s.tune(mel, 'fiddle', 0.75, 0.15, offset=64, transpose=-12)
    s.tune(mel, 'whistle', 0.45, -0.25, offset=64, transpose=-12, harmony=-2)
    s.bassline('bass', tuple((i * 0.5, 0.45, 0) for i in range(8)), octave=2, vel=0.6)
    s.stabs('accordion', (0, 1.5, 3), 0.9, octave=3, vel=0.35, pan=-0.3)
    s.held('pad', 3, 0.3)
    s.drums('kick', (0, 2), 0.65)
    s.drums('snare', (1, 3), 0.35)
    s.drums('hat', tuple(i * 0.5 for i in range(8)), 0.2, pan=0.3)
    return s


def mystery():
    chords = 'Am F Dm E Am F Bdim E'.split()
    s = Song(70, 4, chords * 2, [9, 11, 0, 2, 4, 5, 8])
    mel = 'E5:1 A5:1 C6:1 B5:1 | A5:2 F5:2 | D5:1 F5:1 A5:1 G#5:1 | B5:3 r:1 | C6:1 B5:1 A5:1 E5:1 | F5:2 A5:1 C6:1 | D6:1 B5:1 F5:1 G#5:1 | E5:3 r:1'
    s.tune(mel, 'musicbox', 0.75, 0.25)
    s.tune(mel, 'flute', 0.4, -0.2, offset=32, transpose=-12)
    s.tune(mel, 'musicbox', 0.4, 0.3, offset=32, harmony=-2)
    s.held('pad', 2, 0.6)
    s.bassline('bass', ((0, 0.4, 0), (0.75, 0.4, 0)), octave=1, vel=0.5)
    s.drums('stomp', (0, 0.75), 0.25)
    s.arp('bell', [4, 2, 0, 3], 2, octave=5, vel=0.08, pan=0.5)
    return s


def tavern():
    a = 'D G D A D G A D'.split()
    b = 'G D G A G D A D'.split()
    s = Song(330, 6, a + a + b + b, scale('D'))  # beats are quavers
    mel_a = ('A4:1 D5:1 D5:1 F#5:1 E5:1 D5:1 | B4:1 G5:1 G5:1 B5:1 A5:1 G5:1 | F#5:1 A5:1 F#5:1 D5:1 F#5:1 A5:1 |'
             ' A4:1 C#5:1 E5:1 A5:2 G5:1 | F#5:1 D5:1 D5:1 A5:1 D5:1 D5:1 | B5:1 G5:1 B5:1 D6:1 B5:1 G5:1 |'
             ' A5:1 F#5:1 D5:1 E5:1 C#5:1 A4:1 | D5:2 F#5:1 D5:3')
    mel_b = ('B5:1 D6:1 B5:1 A5:1 B5:1 G5:1 | A5:1 F#5:1 D5:1 F#5:1 A5:1 D6:1 | B5:1 A5:1 G5:1 B5:1 D6:1 B5:1 |'
             ' C#6:1 A5:1 E5:1 A5:1 C#6:1 E6:1 | D6:1 B5:1 G5:1 B5:1 A5:1 G5:1 | F#5:1 A5:1 D6:1 A5:1 F#5:1 D5:1 |'
             ' E5:1 F#5:1 G5:1 A5:1 G5:1 E5:1 | D5:3 r:3')
    s.tune(mel_a, 'fiddle', 0.9, 0.15)
    s.tune(mel_a, 'whistle', 0.7, -0.15, offset=48)
    s.tune(mel_b, 'fiddle', 0.9, 0.15, offset=96)
    s.tune(mel_b, 'whistle', 0.6, -0.2, offset=144)
    s.tune(mel_b, 'fiddle', 0.5, 0.25, offset=144, harmony=-2)
    s.bassline('bass', ((0, 2.5, 0), (3, 2.5, 7)), octave=2, vel=0.7)
    s.stabs('accordion', (1, 4), 1.6, octave=3, vel=0.4, pan=-0.3)
    s.drums('stomp', (0, 3), 0.5)
    s.drums('hat', (2, 5), 0.18, pan=0.3)
    return s


def fight():
    chords = 'Am Am F G Am Am F E'.split()
    s = Song(144, 4, chords * 2, [9, 11, 0, 2, 4, 5, 8])
    mel = ('A5:0.5 r:0.5 A5:0.5 C6:0.5 B5:0.5 A5:0.5 E5:1 | A5:0.5 r:0.5 A5:0.5 C6:0.5 D6:1 C6:1 |'
           ' C6:0.5 r:0.5 A5:0.5 F5:0.5 A5:1 C6:1 | B5:1 D6:1 G5:2 | E6:0.5 r:0.5 E6:0.5 D6:0.5 C6:0.5 B5:0.5 A5:1 |'
           ' C6:0.5 r:0.5 C6:0.5 B5:0.5 A5:1 E5:1 | F5:0.5 A5:0.5 C6:0.5 F6:0.5 E6:1 C6:1 | B5:1 G#5:1 E5:2')
    s.tune(mel, 'fiddle', 0.8, 0.1, transpose=-12)
    s.tune(mel, 'chip', 0.9, -0.2, offset=32, transpose=-12)
    s.tune(mel, 'fiddle', 0.6, 0.2, offset=32, transpose=-12, harmony=-2)
    s.bassline('bass', tuple((i * 0.5, 0.4, 0 if i % 4 != 3 else 12) for i in range(8)), octave=2, vel=0.75)
    s.stabs('accordion', (0, 0.75, 2, 2.75), 0.4, octave=3, vel=0.3, pan=-0.3)
    s.drums('kick', (0, 1.5, 2), 0.75)
    s.drums('snare', (1, 3), 0.45)
    s.drums('hat', tuple(i * 0.5 for i in range(8)), 0.22, pan=0.3)
    return s


def dive():
    chords = 'Dm9 Bbmaj7 Gm7 A7sus4 Dm9 Bbmaj7 Gm7 A7sus4'.split()
    s = Song(58, 4, chords, scale('F'))
    mel = 'A5:2 F5:2 | D6:3 r:1 | C6:2 Bb5:1 G5:1 | A5:4 | F5:1 A5:1 D6:2 | F6:2 E6:1 D6:1 | C6:2 A5:2 | A5:3 r:1'
    s.tune(mel, 'bell', 0.45, 0.25)
    s.tune(mel, 'flute', 0.35, -0.2, transpose=-12)
    s.held('pad', 3, 0.6)
    s.arp('musicbox', [0, 2, 4, 3, 1, 4, 2, 3], 0.5, octave=5, vel=0.18, pan=-0.35)
    s.bassline('bass', ((0, 3.5, 0),), octave=2, vel=0.45)
    return s


def home():
    chords = ['C', 'Am', 'F', 'G', 'C', 'Am', 'Dm G', 'C']
    s = Song(84, 4, chords * 2, scale('C'))
    mel = 'E5:1 G5:1 C6:1 G5:1 | A5:2 E5:2 | F5:1 A5:1 C6:1 A5:1 | G5:3 r:1 | E5:1 G5:1 C6:1 D6:1 | E6:2 C6:2 | D6:1 C6:1 B5:1 G5:1 | C6:3 r:1'
    s.tune(mel, 'musicbox', 0.8, 0.2)
    s.tune(mel, 'flute', 0.6, -0.15, offset=32, transpose=-12)
    s.tune(mel, 'musicbox', 0.4, 0.3, offset=32, harmony=-2)
    s.arp('pluck', [0, 1, 2, 1], 1, octave=3, vel=0.35, pan=-0.3)
    s.bassline('bass', ((0, 1.5, 0), (2, 1.5, 7)), octave=2, vel=0.5)
    s.held('pad', 3, 0.3)
    return s


SONGS = {'title': (title, 0.3), 'town': (town, 0.22), 'river': (river, 0.3), 'islands': (islands, 0.22),
         'lake': (lake, 0.45), 'sailing': (sailing, 0.2), 'mystery': (mystery, 0.45), 'tavern': (tavern, 0.15),
         'fight': (fight, 0.15), 'dive': (dive, 0.5), 'home': (home, 0.3)}


def main():
    names = [a for a in sys.argv[1:] if not a.startswith('-')] or list(SONGS)
    for name in names:
        fn, rv = SONGS[name]
        song = fn()
        L, R = song.render(rv)
        st = master(L, R)
        out = write_ogg(st, name)
        print('%-8s %5.1f s  %d notes  %s (%d KB)' % (name, len(L) / SR, len(song.events), os.path.relpath(out, ROOT),
                                                   os.path.getsize(out) // 1024))


if __name__ == '__main__':
    main()
