#!/usr/bin/env python3
"""IMPERIUM audio generator.

Deterministic, fully original synthesis pipeline (numpy only for DSP, soundfile
for OGG Vorbis output).  No samples, no third-party audio: every sound is built
from oscillators, additive / FM / Karplus-Strong plucks, filtered noise and
synthetic-impulse-response reverb.

Usage:
    python3 tools/assets/gen_audio.py                 # render + analyse everything
    python3 tools/assets/gen_audio.py --only coin ui_click music_menu
    python3 tools/assets/gen_audio.py --analyse-only  # just print the table

Music loops are built *circularly*: notes wrap around the loop end, drones use
frequencies snapped to an integer number of cycles per loop, and the reverb is a
circular convolution, so the seam is continuous by construction.
Output: <repo>/assets/audio/*.ogg (44.1 kHz, Vorbis quality ~0.4).
"""
import argparse
import sys
import time
from functools import lru_cache
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
TAU = 2.0 * np.pi
OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "audio"

PEAK_CEIL_DB = -3.5          # pre-encode ceiling (spec: <= -3 dBFS after Vorbis)
MUSIC_LUFS = -16.0
SFX_LUFS = -12.0
VORBIS_QUALITY = 0.4

# --------------------------------------------------------------------------- #
# basics
# --------------------------------------------------------------------------- #

_NOTES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def nm(name):
    """'F#4' -> midi number."""
    s = _NOTES[name[0]]
    i = 1
    if name[i] == "#":
        s += 1
        i += 1
    elif name[i] == "b":
        s -= 1
        i += 1
    return 12 * (int(name[i:]) + 1) + s


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def ts(dur):
    return np.arange(int(round(dur * SR))) / SR


def noise(n, seed):
    return np.random.default_rng(seed).standard_normal(n)


def smooth_len(n):
    """Smallest 5-smooth integer >= n (fast FFT lengths for loops)."""
    while True:
        m = n
        for p in (2, 3, 5):
            while m % p == 0:
                m //= p
        if m == 1:
            return n
        n += 1


def loop_len(seconds):
    return smooth_len(int(round(seconds * SR)))


def db(x):
    return 20.0 * np.log10(max(x, 1e-12))


# --------------------------------------------------------------------------- #
# zero-phase FFT filters
# --------------------------------------------------------------------------- #

def _filt(x, gain_fn, circular=False):
    n = len(x)
    if circular:
        L = n
    else:
        L = 1
        while L < 2 * n:
            L *= 2
    X = np.fft.rfft(x, L)
    f = np.fft.rfftfreq(L, 1.0 / SR)
    return np.fft.irfft(X * gain_fn(f), L)[:n]


def lowpass(x, fc, order=2, circular=False):
    return _filt(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)), circular)


def highpass(x, fc, order=2, circular=False):
    def g(f):
        r = (f / fc) ** (2 * order)
        return np.sqrt(r / (1.0 + r))
    return _filt(x, g, circular)


def bandpass(x, lo, hi, order=2, circular=False):
    def g(f):
        r1 = (f / lo) ** (2 * order)
        r2 = (f / hi) ** (2 * order)
        return np.sqrt(r1 / (1.0 + r1)) / np.sqrt(1.0 + r2)
    return _filt(x, g, circular)


def fftconv(x, h):
    n = len(x) + len(h) - 1
    L = 1
    while L < n:
        L *= 2
    return np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(h, L), L)[:n]


# --------------------------------------------------------------------------- #
# envelopes / helpers
# --------------------------------------------------------------------------- #

def env_ar(n, a, r):
    """Raised-cosine attack and release over a sustained unity body."""
    e = np.ones(n)
    na = min(n, int(a * SR))
    nr = min(n, int(r * SR))
    if na > 0:
        e[:na] = 0.5 - 0.5 * np.cos(np.pi * np.arange(na) / na)
    if nr > 0:
        e[n - nr:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(nr) / nr)
    return e


def fade_tail(x, secs):
    x = x.copy()
    k = min(len(x), int(secs * SR))
    if k > 0:
        x[-k:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(k) / k)
    return x


def pk(x):
    return x / (np.max(np.abs(x)) + 1e-12)


def put(buf, sig, t=0.0, g=1.0):
    """Add sig into buf at time t (seconds), clipped at the buffer end."""
    i = int(round(t * SR))
    if i >= len(buf) or i < 0:
        return
    e = min(len(buf), i + len(sig))
    buf[i:e] += g * sig[: e - i]


def put_wrap(buf, sig, start, g=1.0):
    """Add sig into a circular buffer starting at sample `start`."""
    n = len(buf)
    if len(sig) > n:
        sig = sig[:n]
    start %= n
    e = start + len(sig)
    if e <= n:
        buf[start:e] += g * sig
    else:
        k = n - start
        buf[start:] += g * sig[:k]
        buf[: len(sig) - k] += g * sig[k:]


# --------------------------------------------------------------------------- #
# reverb (synthetic impulse responses)
# --------------------------------------------------------------------------- #

@lru_cache(maxsize=32)
def make_ir(t60, seed, length=None, predelay=0.015, hf=1.0):
    length = length or t60 * 1.25
    n = int(length * SR)
    base = noise(n, seed)
    t = np.arange(n) / SR
    ir = np.zeros(n)
    for lo, hi, mult in [(50, 400, 1.15), (400, 2500, 1.0),
                         (2500, 8000, 0.55 * hf), (8000, 16000, 0.22 * hf)]:
        ir += bandpass(base, lo, hi) * np.exp(-6.9078 * t / (t60 * mult))
    ir *= 1.0 - np.exp(-t / 0.005)
    pd = int(predelay * SR)
    ir = np.concatenate([np.zeros(pd), ir])[:n]
    rng = np.random.default_rng(seed + 99)
    for k in range(7):                      # a few discrete early reflections
        i = int(rng.uniform(0.008, 0.07) * SR)
        ir[i] += rng.uniform(0.6, 1.2) * (1 if rng.random() > 0.5 else -1) * np.std(ir) * 4
    ir /= np.sqrt(np.sum(ir ** 2))
    return ir


def circ_reverb(x, ir):
    """Circular convolution (seamless for loops)."""
    n = len(x)
    ir = ir[:n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n), n)


def reverb_lin(x, t60, wet, seed=1, hf=1.0):
    ir = make_ir(t60, seed, hf=hf)
    y = fftconv(x, ir)
    out = np.zeros(len(y))
    out[: len(x)] += x
    return out + wet * y


# --------------------------------------------------------------------------- #
# instruments
# --------------------------------------------------------------------------- #

@lru_cache(maxsize=512)
def ks_pluck(freq, dur, decay=0.9975, bright=4000.0, pos=0.18, seed=1):
    """Karplus-Strong plucked string (block-vectorised, fractional tuning)."""
    n = int(dur * SR)
    P = SR / freq
    N = int(P)
    a = P - N                       # 2-tap average -> delay N + a
    exc = noise(N + 1, seed)
    exc = lowpass(exc, bright, order=2)
    k = max(1, int(N * pos))
    exc = exc - np.roll(exc, k)     # pick-position comb
    exc -= np.mean(exc)
    y = np.zeros(n + N + 2)
    y[: N + 1] = exc
    pos_i = N + 1
    while pos_i < n:
        m = min(N, n - pos_i)
        y[pos_i: pos_i + m] = decay * ((1 - a) * y[pos_i - N: pos_i - N + m]
                                       + a * y[pos_i - N - 1: pos_i - N - 1 + m])
        pos_i += m
    y = y[:n]
    y = highpass(y, 40)
    y[: int(0.0015 * SR)] *= np.linspace(0.0, 1.0, int(0.0015 * SR))   # click-free onset
    return fade_tail(pk(y), 0.04)


@lru_cache(maxsize=512)
def pluck_add(freq, dur, bright=1.0, decay=1.6, inharm=0.0003):
    """Additive harp/lute-like pluck, partial-wise exponential decay."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    H = int(min(24, 0.45 * SR / freq))
    for h in range(1, H + 1):
        f = freq * h * np.sqrt(1 + inharm * h * h)
        amp = h ** -1.15 * (bright ** (h - 1))
        rate = (1.0 / decay) * (1 + 0.55 * (h - 1))
        out += amp * np.sin(TAU * f * t + 0.4 * h) * np.exp(-rate * t)
    out *= np.minimum(1.0, t / 0.002)
    return fade_tail(pk(out), 0.03)


@lru_cache(maxsize=256)
def string_pad(freq, dur, attack=1.0, release=1.5, cutoff=1800.0, voices=3,
               detune=7.0, seed=0):
    """Soft bowed-string pad: detuned band-limited saws with slow vibrato."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    env = env_ar(n, attack, release)
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    for v in range(voices):
        cents = (v - (voices - 1) / 2.0) * detune + rng.uniform(-1, 1)
        f = freq * 2 ** (cents / 1200.0)
        vib = 1 + 0.0015 * np.sin(TAU * rng.uniform(4.2, 5.4) * t + rng.uniform(0, TAU)) \
            * np.minimum(1, t / 1.2)
        ph = TAU * np.cumsum(f * vib) / SR + rng.uniform(0, TAU)
        h = 1
        while f * h < min(3.0 * cutoff, 0.45 * SR):
            amp = (1.0 / h) / (1.0 + (f * h / cutoff) ** 2)
            out += amp * np.sin(h * ph)
            h += 1
    return pk(out * env) * 1.0


@lru_cache(maxsize=256)
def brass(freq, dur, attack=0.12, release=0.2, bright=1.0, vib=0.0,
          breath=0.04, scoop=0.0, seed=1):
    """Brass-like additive tone; upper harmonics bloom as the swell opens."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    env = env_ar(n, attack, release)
    vibr = 1 + vib * 0.004 * np.sin(TAU * 5.3 * t) * np.minimum(1, t / 0.5)
    if scoop:
        vibr = vibr * 2.0 ** (-scoop * np.exp(-t / 0.12) / 12.0)
    base = TAU * np.cumsum(freq * vibr) / SR
    out = np.zeros(n)
    H = int(min(26, 0.45 * SR / freq))
    for cents in (-4.0, 4.0):
        ph = base * 2 ** (cents / 1200.0)
        for h in range(1, H + 1):
            p = 0.9 + 0.55 * (h - 1) / max(bright, 0.1)
            amp = h ** -0.9 * env ** p
            out += amp * np.sin(h * ph + 0.3 * h)
    if breath > 0:
        nz = bandpass(noise(n, seed), 700, 3500)
        out = pk(out) + breath * pk(nz) * env ** 1.5
    return pk(out)


@lru_cache(maxsize=64)
def stab(freq, dur=0.12, bright=1.0):
    """Short staccato string/brass-bow stab for ostinatos."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    H = int(min(18, 0.45 * SR / freq))
    for h in range(1, H + 1):
        out += (1.0 / h) * (bright ** (h - 1)) * np.sin(TAU * freq * h * t + 0.5 * h) \
            * np.exp(-t * (14 + 6 * h) / dur * 0.35)
    out *= np.minimum(1, t / 0.004)
    return fade_tail(pk(out), 0.01)


@lru_cache(maxsize=64)
def bell(freq, dur, decay=1.0, bright=1.0):
    """Inharmonic bell (church-bell partial ratios, slightly detuned pairs)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    ratios = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 3.011, 4.166, 5.433]
    amps = [0.6, 1.0, 0.55, 0.45, 0.6, 0.3, 0.25, 0.15, 0.08]
    out = np.zeros(n)
    for i, (r, a) in enumerate(zip(ratios, amps)):
        f = freq * r
        if f > 0.45 * SR:
            continue
        tau = 1.4 * decay / (r ** 0.85)
        a = a * (bright ** i)
        out += a * np.sin(TAU * f * t) * np.exp(-t / tau)
        out += 0.5 * a * np.sin(TAU * f * 1.0035 * t + 1.0) * np.exp(-t / (tau * 0.8))
    out *= np.minimum(1.0, t / 0.001)
    return fade_tail(pk(out), 0.05)


@lru_cache(maxsize=64)
def fm_ping(freq, dur, ratio=3.5, index=3.0, tau=0.25, itau=0.08):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = index * np.exp(-t / itau) * np.sin(TAU * freq * ratio * t)
    out = np.sin(TAU * freq * t + mod) * np.exp(-t / tau)
    out *= np.minimum(1.0, t / 0.0008)
    return fade_tail(pk(out), 0.03)


def clang(freq, dur, seed=3, tau=0.5):
    """Metallic sword/shield clang: inharmonic partials + noise transient."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    ratios = [1.0, 1.47, 2.09, 2.56, 3.45, 4.71, 6.13, 7.9]
    out = np.zeros(n)
    for i, r in enumerate(ratios):
        r *= rng.uniform(0.985, 1.015)
        f = freq * r
        if f > 0.45 * SR:
            continue
        out += (1.0 / (1 + 0.35 * i)) * np.sin(TAU * f * t + rng.uniform(0, TAU)) \
            * np.exp(-t / (tau / (1 + 0.45 * i)))
    fm = np.sin(TAU * freq * 1.414 * t) * 2.5 * np.exp(-t / 0.04)
    out += 0.5 * np.sin(TAU * freq * 0.5 * t + fm) * np.exp(-t / (tau * 0.5))
    hit = bandpass(noise(n, seed + 1), 2500, 12000) * np.exp(-t / 0.006)
    out = pk(out) + 0.7 * pk(hit)
    return fade_tail(pk(out), 0.05)


def drum(tone, tau, dur, slap=0.3, rumble=0.3, seed=5, sweep=0.55):
    """Frame drum / taiko: pitch-dropping sine body + slap + skin noise."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = tone * (1 + sweep * np.exp(-t / 0.035))
    ph = TAU * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / tau) + 0.35 * np.sin(1.62 * ph) * np.exp(-t / (tau * 0.45))
    sl = bandpass(noise(n, seed), 700, 3500) * np.exp(-t / 0.018)
    rum = lowpass(noise(n, seed + 1), 500) * np.exp(-t / (tau * 0.8))
    out = pk(body) + slap * pk(sl) + rumble * pk(rum)
    out *= np.minimum(1, t / 0.0015)
    return fade_tail(pk(out), 0.03)


def swept_noise(dur, f0, f1, bw=1.3, seed=0, nb=26):
    """Noise through a band whose centre glides f0->f1 (whoosh / page swish)."""
    n = int(dur * SR)
    X = np.fft.rfft(noise(n, seed))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    centres = np.geomspace(80, 14000, nb)
    fc_t = f0 * (f1 / f0) ** np.linspace(0, 1, n)
    out = np.zeros(n)
    for c in centres:
        g = np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / c) / 0.18) ** 2)
        band = np.fft.irfft(X * g, n)
        w = np.exp(-0.5 * (np.log2(fc_t / c) / (bw / 2)) ** 2)
        out += band * w
    return pk(out)


def rustle(dur, seed=0, density=60.0, lo=2500, hi=9000):
    """Paper crinkle: sparse random micro-bursts of band-limited noise."""
    n = int(dur * SR)
    rng = np.random.default_rng(seed)
    imp = (rng.random(n) < density / SR) * rng.uniform(0.3, 1.0, n)
    k = np.exp(-np.arange(int(0.012 * SR)) / (0.003 * SR))
    env = np.convolve(imp, k)[:n]
    sig = bandpass(rng.standard_normal(n), lo, hi) * env
    return pk(sig)


# --------------------------------------------------------------------------- #
# loudness (ITU-R BS.1770 K-weighting) and finalisation
# --------------------------------------------------------------------------- #

def _k_response(f):
    z = np.exp(-1j * TAU * f / SR)
    # stage 1: high shelf
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = np.tan(np.pi * f0 / SR)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a = [1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    H1 = (b[0] + b[1] * z + b[2] * z ** 2) / (a[0] + a[1] * z + a[2] * z ** 2)
    # stage 2: RLB high-pass
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / SR)
    a0 = 1 + K / Q + K * K
    a = [1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    H2 = (1 - 2 * z + z ** 2) / (a[0] + a[1] * z + a[2] * z ** 2)
    return H1 * H2


def k_weight(x):
    n = len(x)
    L = 1
    while L < 2 * n:
        L *= 2
    f = np.fft.rfftfreq(L, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x, L) * _k_response(f), L)[:n]


def lufs_gated(chs):
    """Integrated loudness with the BS.1770-4 two-stage gate (for music)."""
    ys = [k_weight(c) for c in chs]
    blk, hop = int(0.4 * SR), int(0.1 * SR)
    cs = [np.concatenate([[0.0], np.cumsum(y * y)]) for y in ys]
    starts = np.arange(0, len(ys[0]) - blk + 1, hop)
    ms = sum((c[starts + blk] - c[starts]) / blk for c in cs)
    l = -0.691 + 10 * np.log10(ms + 1e-20)
    keep = ms[l > -70]
    if len(keep) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(keep)) - 10
    keep = ms[l > max(rel, -70)]
    return -0.691 + 10 * np.log10(np.mean(keep) + 1e-20)


def lufs_sfx(chs):
    """Active-region loudness (energy over the audible region, min 400 ms window)."""
    ys = [k_weight(c) for c in chs]
    p = sum(y * y for y in ys)
    w = int(0.02 * SR)
    env = np.convolve(p, np.ones(w) / w, "same")
    idx = np.where(env > env.max() * 10 ** -3.5)[0]
    s, e = idx[0], idx[-1]
    win = max((e - s) / SR, 0.4)
    ms = p[s:e].sum() / (win * SR)
    return -0.691 + 10 * np.log10(ms + 1e-20)


def soft_limit(x, ceil, knee=0.6):
    a = np.abs(x) / ceil
    y = np.where(a < knee, a, knee + (1 - knee) * np.tanh((a - knee) / (1 - knee)))
    return np.sign(x) * y * ceil


def finalise(chs, target, sfx):
    """Scale to target LUFS, soft-limit toward the -3.5 dBFS ceiling."""
    chs = [np.nan_to_num(c) for c in chs]
    ceil = 10 ** (PEAK_CEIL_DB / 20)
    loud = lufs_sfx(chs) if sfx else lufs_gated(chs)
    g = 10 ** ((target - loud) / 20)
    peak = max(np.max(np.abs(c)) for c in chs)
    g = min(g, 2.0 * ceil / (peak + 1e-12))        # allow <= ~6 dB of limiting
    out = [soft_limit(c * g, ceil) for c in chs]
    peak = max(np.max(np.abs(c)) for c in out)
    if peak > ceil:
        out = [c * ceil / peak for c in out]
    return out


# --------------------------------------------------------------------------- #
# music infrastructure
# --------------------------------------------------------------------------- #

class Mix:
    """Stereo circular mix bus with a reverb send."""

    def __init__(self, n):
        self.n = n
        self.L = np.zeros(n)
        self.R = np.zeros(n)
        self.V = np.zeros(n)

    def add(self, sig, start, g=1.0, pan=0.0, send=0.3):
        a = (pan + 1) * np.pi / 4
        put_wrap(self.L, sig, start, g * np.cos(a))
        put_wrap(self.R, sig, start, g * np.sin(a))
        if send > 0:
            put_wrap(self.V, sig, start, g * send)

    def add_stereo(self, sl, sr_, start, g=1.0, send=0.3):
        put_wrap(self.L, sl, start, g)
        put_wrap(self.R, sr_, start, g)
        if send > 0:
            put_wrap(self.V, 0.5 * (sl + sr_), start, g * send)

    def render(self, t60, wet, seed, hf=1.0, lp=14000.0):
        irL = make_ir(t60, seed, hf=hf)
        irR = make_ir(t60, seed + 17, hf=hf)
        L = self.L + wet * circ_reverb(self.V, irL)
        R = self.R + wet * circ_reverb(self.V, irR)
        out = []
        for c in (L, R):
            c = highpass(c, 30, circular=True)
            c = lowpass(c, lp, order=2, circular=True)
            out.append(c)
        return out


def pool_chord(m0, steps):
    return [m0 + s for s in steps]


# --------------------------------------------------------------------------- #
# MUSIC
# --------------------------------------------------------------------------- #

def render_music_menu():
    """Stately D-Dorian processional: lute melody, harp arpeggio, string pad, frame drum."""
    bars, nbeats = 16, 64
    N = loop_len(71.0)
    beat = N / nbeats
    B = lambda b: int(round(b * beat))
    mix = Mix(N)
    CH = {
        "Dm": dict(pad=[57, 62, 65, 69], root=38, arp=[50, 57, 62, 65, 69, 74]),
        "C": dict(pad=[55, 60, 64, 67], root=36, arp=[48, 55, 60, 64, 67, 72]),
        "Am": dict(pad=[57, 60, 64, 69], root=33, arp=[45, 52, 57, 60, 64, 69]),
        "G": dict(pad=[55, 59, 62, 67], root=43 - 12, arp=[43, 50, 55, 59, 62, 67]),
    }
    prog = ["Dm", "C", "Dm", "Am", "G", "C", "Dm", "Am",
            "Dm", "C", "Dm", "Am", "G", "C", "Dm", "Dm"]
    bar_sec = 4 * beat / SR

    for bi, ch in enumerate(prog):
        c = CH[ch]
        t0 = B(bi * 4)
        # string pad (stereo via two seeds)
        for k, m in enumerate(c["pad"]):
            f = mtof(m)
            d = round(bar_sec + 1.2, 2)
            pl = string_pad(f, d, 1.1, 1.6, 1500.0, 3, 7.0, 10 + k)
            pr = string_pad(f, d, 1.1, 1.6, 1500.0, 3, 9.0, 40 + k)
            mix.add_stereo(pl, pr, t0 - B(0.5), g=0.085, send=0.5)
        # bass pluck
        root = mtof(c["root"] + 12)
        mix.add(pluck_add(root, 3.4, 0.9, 2.2), t0, g=0.6, pan=-0.05, send=0.15)
        mix.add(pluck_add(root * 1.5, 2.0, 0.9, 1.2), t0 + B(2.5), g=0.22, pan=0.1, send=0.2)
        # harp arpeggio
        pool = c["arp"]
        if bi < 8:
            pat = [(0, 1), (1, 3), (2, 4), (3, 3)]
            for bt, idx in pat:
                if bi < 2 and bt % 2:      # sparse intro
                    continue
                mix.add(pluck_add(mtof(pool[idx]), 2.4, 0.9, 1.3), t0 + B(bt), g=0.22,
                        pan=0.35, send=0.45)
        else:
            idxs = [1, 2, 3, 4, 5, 4, 3, 2]
            for i, idx in enumerate(idxs):
                mix.add(pluck_add(mtof(pool[idx]), 2.0, 0.9, 1.2), t0 + B(i * 0.5),
                        g=0.19 if i % 2 == 0 else 0.13, pan=0.35 + 0.1 * (i % 3 - 1), send=0.45)
        # frame drum
        if bi >= 1:
            mix.add(drum(92, 0.16, 0.5, 0.3, 0.3, seed=bi), t0, g=0.85, pan=-0.1, send=0.35)
            mix.add(drum(96, 0.14, 0.45, 0.3, 0.3, seed=bi + 50), t0 + B(2), g=0.5, pan=-0.1, send=0.35)
            if bi >= 8:
                mix.add(drum(130, 0.07, 0.3, 0.7, 0.1, seed=bi + 80), t0 + B(1.5), g=0.28, pan=0.15, send=0.3)
                mix.add(drum(120, 0.08, 0.3, 0.7, 0.1, seed=bi + 90), t0 + B(3.5), g=0.34, pan=0.15, send=0.3)
            else:
                mix.add(drum(130, 0.07, 0.3, 0.7, 0.1, seed=bi + 80), t0 + B(3.5), g=0.22, pan=0.15, send=0.3)

    # lute melody  (beat offset in bar, note, length in beats)
    D4, E4, F4, G4, A4, B4, C5, D5, E5, F5, G5 = (nm(x) for x in
        ["D4", "E4", "F4", "G4", "A4", "B4", "C5", "D5", "E5", "F5", "G5"])
    mel = [
        [(0, D4, 2), (2, F4, 1), (3, A4, 1)],
        [(0, G4, 1.5), (1.5, F4, .5), (2, E4, 2)],
        [(0, D4, 1), (1, F4, 1), (2, A4, 1), (3, B4, 1)],
        [(0, C5, 3), (3, B4, 1)],
        [(0, A4, 1.5), (1.5, G4, .5), (2, B4, 2)],
        [(0, G4, 1), (1, E4, 1), (2, G4, 2)],
        [(0, F4, 1), (1, E4, 1), (2, D4, 2)],
        [(0, E4, 4)],
        [(0, A4, 2), (2, D5, 1), (3, C5, 1)],
        [(0, E5, 1.5), (1.5, D5, .5), (2, C5, 2)],
        [(0, D5, 1), (1, F5, 1), (2, E5, 1), (3, D5, 1)],
        [(0, C5, 2), (2, E5, 2)],
        [(0, B4, 1), (1, D5, 1), (2, G5, 2)],
        [(0, E5, 1.5), (1.5, D5, .5), (2, C5, 1), (3, G4, 1)],
        [(0, A4, 1), (1, F4, 1), (2, E4, 1), (3, D4, 1)],
        [(0, D4, 4)],
    ]
    for bi, notes in enumerate(mel):
        for off, m, ln in notes:
            d = ln * beat / SR + 1.6
            mix.add(ks_pluck(round(mtof(m), 3), round(d, 2), 0.9985, 3800.0, 0.16, seed=bi * 7 + int(off * 2) + 1),
                    B(bi * 4 + off), g=0.8, pan=-0.2, send=0.4)
    return mix.render(3.4, 0.42, 101, hf=1.0, lp=13000.0)


def render_music_campaign():
    """Calm A-Dorian ambience: drones, wind, slow pulse, sparse harp, soft pad."""
    N = loop_len(88.0)
    T = N / SR
    nbeats = 80
    beat = N / nbeats
    B = lambda b: int(round(b * beat))
    t = np.arange(N) / SR
    snap = lambda f: round(f * T) / T
    mix = Mix(N)
    rng = np.random.default_rng(2024)

    # drones: every frequency snapped to an integer cycle count -> seamless
    drones = [(55.0, 1.0, 5, 0.0), (82.41, 0.8, 7, 1.0), (110.0, 0.5, 3, 2.0), (164.81, 0.22, 4, 0.5)]
    dl = np.zeros(N)
    dr = np.zeros(N)
    for f, a, cyc, ph in drones:
        f = snap(f)
        for twin, (sig_out, k) in enumerate([(dl, 0), (dr, 13 + 2 * int(f) % 5)]):
            ff = f + k / T
            s = np.zeros(N)
            for h in range(1, 6):
                s += (1.0 / h ** 1.3) * np.sin(TAU * h * ff * t + 0.7 * h + ph)
            s *= 0.72 + 0.28 * np.sin(TAU * cyc * t / T + ph + twin)
            sig_out += a * s
    # wind bed (circular filters, integer-cycle modulation)
    w1 = bandpass(noise(N, 7), 180, 900, circular=True)
    w1 *= 0.45 + 0.55 * np.sin(TAU * 3 * t / T + 0.3) ** 2
    w2 = bandpass(noise(N, 8), 1500, 4200, circular=True)
    w2 *= (0.5 + 0.5 * np.sin(TAU * 6 * t / T + 1.1)) ** 3
    w3 = lowpass(noise(N, 9), 220, circular=True) * (0.6 + 0.4 * np.sin(TAU * 2 * t / T))
    mix.L += 0.0145 * dl + 0.12 * pk(w1) * 0.5 + 0.045 * pk(w2) + 0.25 * pk(w3) * 0.5
    mix.R += 0.0145 * dr + 0.12 * pk(np.roll(w1, 3000)) * 0.5 + 0.045 * pk(np.roll(w2, 5000)) + 0.25 * pk(w3) * 0.5
    mix.V += 0.5 * (mix.L + mix.R) * 0.5

    # glassy shimmer (sparse, integer-cycle swells)
    for f, cyc, ph, pan in [(880.0, 4, 0.0, -0.5), (1318.5, 3, 1.3, 0.5), (1760.0, 5, 2.4, 0.0), (659.3, 2, 0.7, 0.3)]:
        f = snap(f)
        s = np.sin(TAU * f * t) + 0.3 * np.sin(TAU * 2 * f * t + 1)
        swell = np.maximum(0.0, np.sin(TAU * cyc * t / T + ph)) ** 3
        a = (pan + 1) * np.pi / 4
        sig = 0.016 * s * swell
        mix.L += sig * np.cos(a)
        mix.R += sig * np.sin(a)
        mix.V += sig * 0.6

    # pad chords, one per two bars
    pads = {
        "Am": [57, 60, 64, 69], "G": [55, 59, 62, 67], "D": [57, 62, 66, 69], "Em": [55, 59, 64, 67],
    }
    prog = ["Am", "G", "Am", "D", "Am", "Em", "G", "D", "Am", "G"]
    seg = 8 * beat / SR
    for ci, ch in enumerate(prog):
        for k, m in enumerate(pads[ch]):
            f = mtof(m)
            d = round(seg + 1.5, 2)
            pl = string_pad(f, d, 3.0, 3.8, 1000.0, 3, 6.0, 200 + k)
            pr = string_pad(f, d, 3.0, 3.8, 1000.0, 3, 8.0, 240 + k)
            mix.add_stereo(pl, pr, B(ci * 8) - int(1.5 * SR), g=0.07, send=0.6)

    # slow pulse (soft sub thump), omitted every 4th bar
    for b in range(0, nbeats, 2):
        bar = b // 4
        if bar % 4 == 3:
            continue
        g = 0.55 if b % 4 == 0 else 0.32
        g *= 0.85 + 0.15 * np.sin(b * 0.37)
        dr_ = drum(58, 0.22, 0.9, 0.0, 0.05, seed=300 + b, sweep=0.35)
        dr_ = lowpass(dr_, 220)
        mix.add(dr_, B(b), g=0.5 * g, pan=0.0, send=0.25)

    # sparse melody on harp, echoed
    pool = [57, 60, 62, 64, 67, 69, 72, 74, 76]
    idx = 4
    for ci in range(10):
        if rng.random() < 0.72:
            nnotes = int(rng.integers(2, 5))
            tb = ci * 8 + float(rng.choice([1.0, 2.0, 3.0]))
            for _ in range(nnotes):
                idx = int(np.clip(idx + rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(pool) - 1))
                m = pool[idx]
                d = 5.0
                n_ = pluck_add(mtof(m), d, 0.85, 1.7)
                mix.add(n_, B(tb), g=0.30, pan=-0.3, send=0.6)
                mix.add(n_, B(tb + 1.5), g=0.12, pan=0.5, send=0.6)
                mix.add(n_, B(tb + 3.0), g=0.06, pan=-0.4, send=0.6)
                tb += float(rng.choice([1.0, 1.5, 2.0, 2.5]))
    # one soft lute counter-line per half loop
    for k, (bt, m) in enumerate([(14, 'A3'), (30, 'E3'), (54, 'D3'), (70, 'A3')]):
        mix.add(ks_pluck(round(mtof(nm(m)), 3), 5.0, 0.9990, 2600.0, 0.2, seed=400 + k),
                B(bt), g=0.35, pan=0.15, send=0.5)

    return mix.render(5.2, 0.5, 202, hf=0.8, lp=9000.0)


def render_music_battle():
    """Tense E-Phrygian war music: taiko ostinato, brass swells, urgent strings."""
    bars = 20
    nbeats = bars * 4
    N = loop_len(46.0)
    beat = N / nbeats
    B = lambda b: int(round(b * beat))
    t = np.arange(N) / SR
    T = N / SR
    mix = Mix(N)
    rng = np.random.default_rng(77)
    E1, E2, F2, G2, A2, B2, C3, D3, E3, F3 = (nm(x) for x in
        ["E1", "E2", "F2", "G2", "A2", "B2", "C3", "D3", "E3", "F3"])
    # intensity per bar (0..1)
    inten = [0.35, 0.4, 0.5, 0.55] + [0.7] * 4 + [0.8] * 4 + [1.0] * 4 + [0.75, 0.7, 0.6, 0.55]

    # sub rumble (circular, seamless)
    rum = lowpass(noise(N, 11), 90, circular=True) * (0.6 + 0.4 * np.sin(TAU * 5 * t / T))
    mix.L += 0.5 * pk(rum) * 0.22
    mix.R += 0.5 * pk(np.roll(rum, 999)) * 0.22
    drone = np.zeros(N)
    for f, a in [(snap_f := round(41.2 * T) / T, 1.0), (round(61.74 * T) / T, 0.5)]:
        drone += a * (np.sin(TAU * f * t) + 0.4 * np.sin(TAU * 2 * f * t + 0.5) + 0.2 * np.sin(TAU * 3 * f * t))
    drone *= 0.8 + 0.2 * np.sin(TAU * 4 * t / T)
    mix.L += 0.05 * drone
    mix.R += 0.05 * drone

    # low brass swells over two-bar spans
    brass_prog = [
        ((E2, B2, E3), 0), ((F2, C3, F3), 2), ((E2, B2, E3), 4), ((G2, D3), 6),
        ((E2, B2, E3), 8), ((F2, C3, F3), 10), ((A2, E3), 12), ((F2, C3, F3), 14),
        ((E2, B2, E3), 16), ((E2, B2, E3), 18),
    ]
    for notes, bar in brass_prog:
        span = 8 * beat / SR
        for k, m in enumerate(notes):
            n_ = brass(round(mtof(m), 3), round(span * 0.85, 2), attack=round(span * 0.5, 2),
                       release=round(span * 0.3, 2), bright=1.6, vib=0.3, breath=0.05, seed=20 + k)
            g = (0.5 if k == 0 else 0.34) * (0.55 + 0.45 * inten[bar])
            mix.add(n_, B(bar * 4) - int(0.2 * beat), g=g, pan=(-0.25 if k % 2 else 0.25), send=0.4)

    # high brass melody (bars 12-15 zero-based)
    E4, F4, G4, B4, C5, A4 = (nm(x) for x in ["E4", "F4", "G4", "B4", "C5", "A4"])
    hm = [
        (12, [(0, E4, 2), (2, F4, 1), (3, E4, 1)]),
        (13, [(0, G4, 2), (2, F4, 1), (3, E4, 1)]),
        (14, [(0, B4, 2), (2, C5, 1), (3, B4, 1)]),
        (15, [(0, A4, 2), (2, F4, 1), (3, E4, 1)]),
    ]
    for bar, notes in hm:
        for off, m, ln in notes:
            n_ = brass(round(mtof(m), 3), round(ln * beat / SR * 0.95, 2), attack=0.05, release=0.12,
                       bright=1.4, vib=0.6, breath=0.04, scoop=0.6 if off == 0 else 0.0, seed=60 + int(off))
            mix.add(n_, B(bar * 4 + off), g=0.45, pan=0.15, send=0.45)

    # ostinato (16 steps per bar) - urgent staccato strings
    base = [E2, None, E2, E2, None, E2, F2, None, E2, None, E2, E2, G2, F2, E2, None]
    alt = [E2, None, E2, E2, None, E2, F2, None, E2, E2, None, E2, B2, G2, F2, E2]
    for bar in range(4, 19):
        pat = alt if bar % 4 == 3 else base
        g0 = 0.30 * (0.5 + 0.5 * inten[bar])
        for s_, m in enumerate(pat):
            if m is None:
                continue
            acc = 1.0 if s_ % 4 == 0 else (0.8 if s_ % 2 == 0 else 0.62)
            tt = B(bar * 4 + s_ * 0.25)
            mix.add(stab(round(mtof(m), 3), 0.13, 1.0), tt, g=g0 * acc, pan=-0.3, send=0.18)
            if bar >= 8:
                mix.add(stab(round(mtof(m + 12), 3), 0.11, 0.9), tt, g=g0 * acc * 0.5, pan=0.3, send=0.18)

    # drums
    taiko_pat = [3, 0, 1, 1, 3, 0, 1, 2]                      # eighth-note pattern
    for bar in range(bars):
        t0 = bar * 4
        it = inten[bar]
        if bar < 4:
            hits = [(0, 1.0), (2.5, 0.55)] if bar % 2 == 0 else [(0, 0.9), (1.5, 0.4), (3, 0.5)]
        else:
            hits = [(i * 0.5, {3: 1.0, 2: 0.7, 1: 0.45}[v]) for i, v in enumerate(taiko_pat) if v]
            if bar >= 12 and bar < 16:
                hits += [(i * 0.5 + 0.25, 0.3) for i in (1, 3, 5, 7)]
        for off, a in hits:
            big = a > 0.9
            d = drum(52 if big else 66, 0.38 if big else 0.2, 1.0 if big else 0.6, 0.35, 0.4,
                     seed=bar * 13 + int(off * 4))
            mix.add(d, B(t0 + off), g=0.95 * a * (0.6 + 0.4 * it), pan=0.0, send=0.35)
        # snare-ish field drum on 2 and 4 from bar 8
        if bar >= 8 and bar < 16:
            for off in (1, 3):
                sn = bandpass(noise(int(0.2 * SR), bar * 5 + off), 1200, 6500) * np.exp(-np.arange(int(0.2 * SR)) / SR / 0.045)
                sn = pk(sn) * 0.5 + 0.5 * pk(drum(190, 0.05, 0.2, 0.0, 0.0, seed=bar + off))
                mix.add(sn, B(t0 + off), g=0.35, pan=0.2, send=0.3)
        # metal clack ticks on offbeats (bars 5-16)
        if 4 <= bar < 16:
            for i in range(8):
                if i % 2 == 1:
                    tk = highpass(noise(int(0.05 * SR), bar * 17 + i), 5500) * np.exp(-np.arange(int(0.05 * SR)) / SR / 0.008)
                    mix.add(pk(tk), B(t0 + i * 0.5), g=0.07 + 0.03 * (i % 4 == 3), pan=0.4 if i % 4 == 1 else -0.4, send=0.2)
        # snare roll build in the last bar before the loop restarts and before bar 12
        if bar in (11, 19):
            nr = 16
            for i in range(nr):
                cr = i / nr
                sn = bandpass(noise(int(0.12 * SR), 900 + i + bar), 1500, 7000) * np.exp(-np.arange(int(0.12 * SR)) / SR / 0.03)
                mix.add(pk(sn), B(t0 + i * 0.25), g=0.12 + 0.35 * cr, pan=0.0, send=0.3)
    return mix.render(2.6, 0.30, 303, hf=0.9, lp=12000.0)


# --------------------------------------------------------------------------- #
# SFX (mono)
# --------------------------------------------------------------------------- #

def cv(dur):
    return np.zeros(int(dur * SR))


def knock(f=190.0, seed=1):
    t = ts(0.14)
    body = np.sin(TAU * f * (1 + 0.3 * np.exp(-t / 0.01)) * t) * np.exp(-t / 0.03)
    nz = bandpass(noise(len(t), seed), 900, 3500) * np.exp(-t / 0.006)
    return pk(body) * 0.8 + 0.7 * pk(nz)


def sfx_ui_click():
    x = cv(0.14)
    t = ts(0.06)
    tick = np.sin(TAU * 2600 * t) * np.exp(-t / 0.005)
    nz = bandpass(noise(len(t), 1), 2000, 7000) * np.exp(-t / 0.0015)
    body = np.sin(TAU * 420 * t) * np.exp(-t / 0.012)
    put(x, 0.6 * tick + 0.5 * pk(nz) + 0.5 * body)
    return x


def sfx_ui_back():
    x = cv(0.18)
    t = ts(0.1)
    f = 1900 * np.exp(-t / 0.05) + 700
    tick = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.022)
    nz = bandpass(noise(len(t), 2), 1200, 4500) * np.exp(-t / 0.002)
    body = np.sin(TAU * 260 * t) * np.exp(-t / 0.02)
    put(x, 0.55 * tick + 0.4 * pk(nz) + 0.6 * body)
    return x


def sfx_ui_open():
    x = cv(0.5)
    sw = swept_noise(0.3, 500, 3600, seed=3) * np.sin(np.linspace(0, np.pi, int(0.3 * SR))) ** 1.5
    put(x, sw, 0.0, 0.35)
    put(x, pluck_add(mtof(nm("D5")), 0.35, 0.9, 0.25), 0.05, 0.5)
    put(x, pluck_add(mtof(nm("A5")), 0.4, 0.9, 0.3), 0.13, 0.5)
    return reverb_lin(x, 0.5, 0.15, 5)


def sfx_ui_close():
    x = cv(0.5)
    sw = swept_noise(0.26, 3600, 500, seed=4) * np.sin(np.linspace(0, np.pi, int(0.26 * SR))) ** 1.5
    put(x, sw, 0.0, 0.35)
    put(x, pluck_add(mtof(nm("A5")), 0.3, 0.9, 0.22), 0.02, 0.45)
    put(x, pluck_add(mtof(nm("D5")), 0.4, 0.9, 0.3), 0.1, 0.5)
    return reverb_lin(x, 0.5, 0.15, 6)


def _buzz(freq, dur):
    t = ts(dur)
    out = np.zeros(len(t))
    for h in range(1, 12, 2):
        out += (1.0 / h) * np.sin(TAU * freq * h * t)
    return pk(out) * env_ar(len(t), 0.004, 0.03)


def sfx_ui_error():
    x = cv(0.5)
    for k, t0 in enumerate((0.0, 0.17)):
        b = 0.6 * _buzz(150, 0.13) + 0.5 * _buzz(150 * 1.4142, 0.13)
        b = lowpass(b, 1800)
        put(x, b, t0, 0.8)
        put(x, drum(110, 0.05, 0.12, 0.2, 0.0, seed=k), t0, 0.5)
    return reverb_lin(x, 0.3, 0.1, 7)


def sfx_ui_confirm():
    x = cv(0.8)
    put(x, pluck_add(mtof(nm("D5")), 0.5, 0.95, 0.35), 0.0, 0.7)
    put(x, pluck_add(mtof(nm("A5")), 0.6, 0.95, 0.45), 0.09, 0.7)
    put(x, bell(mtof(nm("D6")), 0.6, 0.35, 0.6), 0.09, 0.18)
    return reverb_lin(x, 0.6, 0.18, 8)


def sfx_coin():
    x = cv(0.9)
    put(x, fm_ping(1975.5, 0.6, 3.5, 2.5, 0.16, 0.05), 0.0, 0.7)
    put(x, fm_ping(2637.0, 0.8, 3.5, 2.5, 0.28, 0.06), 0.065, 0.8)
    tk = highpass(noise(int(0.02 * SR), 9), 5000) * np.exp(-ts(0.02) / 0.004)
    put(x, pk(tk), 0.0, 0.25)
    return reverb_lin(x, 0.4, 0.12, 9)


def sfx_build_complete():
    x = cv(2.2)
    for i, t0 in enumerate((0.0, 0.2, 0.4)):
        put(x, knock(170 + 20 * i, 10 + i), t0, 0.8 if i < 2 else 1.0)
    for k, m in enumerate(["D4", "A4", "D5", "F#5"]):
        put(x, pluck_add(mtof(nm(m)), 1.3, 0.95, 0.9), 0.62 + 0.04 * k, 0.5)
    put(x, bell(mtof(nm("D5")), 1.4, 0.5, 0.6), 0.62, 0.2)
    return reverb_lin(x, 1.0, 0.25, 11)


def sfx_recruit():
    x = cv(1.6)
    put(x, drum(100, 0.14, 0.4, 0.5, 0.3, seed=1), 0.0, 1.0)
    put(x, drum(100, 0.14, 0.4, 0.5, 0.3, seed=2), 0.22, 0.8)
    put(x, brass(mtof(nm("A3")), 0.22, 0.04, 0.1, 1.2, 0.2, seed=2), 0.42, 0.55)
    put(x, brass(mtof(nm("D4")), 0.55, 0.04, 0.3, 1.2, 0.4, seed=3), 0.66, 0.6)
    put(x, brass(mtof(nm("A4")), 0.55, 0.04, 0.3, 1.2, 0.4, seed=4), 0.66, 0.3)
    return reverb_lin(x, 0.8, 0.2, 12)


def sfx_march():
    x = cv(2.0)
    rng = np.random.default_rng(14)
    for i in range(4):
        t0 = 0.05 + i * 0.42 + rng.uniform(-0.008, 0.008)
        n = int(0.2 * SR)
        t = np.arange(n) / SR
        thud = np.sin(TAU * 85 * (1 + 0.4 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.05)
        scuff = lowpass(noise(n, 20 + i), 1400) * np.exp(-t / 0.045)
        put(x, 0.8 * pk(thud) + 0.5 * pk(scuff), t0, 0.9 if i % 2 == 0 else 0.7)
        for j in range(3):                       # buckles / mail jingle
            put(x, fm_ping(rng.uniform(3000, 5200), 0.12, 2.9, 1.5, 0.03, 0.02),
                t0 + rng.uniform(0.0, 0.1), 0.06)
        put(x, drum(120, 0.07, 0.2, 0.5, 0.0, seed=30 + i), t0 + 0.21, 0.28)
    return reverb_lin(x, 0.7, 0.15, 15)


def sfx_clash():
    x = cv(1.6)
    put(x, clang(1180, 1.2, 3, 0.55), 0.0, 1.0)
    put(x, clang(1560, 0.9, 5, 0.45), 0.11, 0.75)
    put(x, clang(820, 0.8, 7, 0.4), 0.2, 0.55)
    put(x, drum(80, 0.2, 0.5, 0.5, 0.4, seed=3), 0.0, 0.6)
    return reverb_lin(x, 1.0, 0.22, 16)


def _fanfare_note(m, t, d, g, x, attack=0.03, bright=1.5, vib=0.5, seed=1):
    put(x, brass(round(mtof(nm(m)), 3), d, attack, 0.12, bright, vib, 0.04, seed=seed), t, g)


def sfx_battle_win():
    x = cv(3.2)
    for i, (m, t0, d) in enumerate([("D4", 0.0, 0.2), ("A4", 0.24, 0.2), ("D5", 0.48, 0.45)]):
        _fanfare_note(m, t0, d, 0.7, x, seed=i + 1)
    for k, m in enumerate(["D4", "A4", "D5", "F#5"]):
        _fanfare_note(m, 1.05, 1.5, 0.45 if k else 0.6, x, attack=0.05, seed=10 + k)
    put(x, drum(70, 0.3, 0.8, 0.4, 0.4, seed=1), 0.0, 0.8)
    put(x, drum(70, 0.3, 0.8, 0.4, 0.4, seed=2), 1.05, 1.0)
    put(x, bell(mtof(nm("D5")), 1.8, 0.6, 0.6), 1.05, 0.15)
    return reverb_lin(x, 1.4, 0.25, 17)


def sfx_battle_lose():
    x = cv(4.0)
    for i, (m, t0, d) in enumerate([("D4", 0.0, 0.5), ("C4", 0.55, 0.5), ("A3", 1.1, 0.5), ("D3", 1.7, 1.6)]):
        _fanfare_note(m, t0, d, 0.65, x, attack=0.08, bright=0.9, vib=0.3, seed=20 + i)
        _fanfare_note(m.replace("4", "3") if m != "D3" else "A2", t0, d, 0.35, x, attack=0.08, bright=0.9, vib=0.3, seed=30 + i)
    for t0 in (0.0, 0.55, 1.1, 1.7):
        put(x, drum(60, 0.25, 0.7, 0.2, 0.4, seed=int(t0 * 10)), t0, 0.7)
    return reverb_lin(x, 1.8, 0.3, 18, hf=0.7)


def sfx_cannon():
    x = cv(2.6)
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    f = 38 + 110 * np.exp(-t / 0.045)
    boom = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.28)
    blast = lowpass(noise(n, 21), 1800) * np.exp(-t / 0.09)
    crack = highpass(noise(n, 22), 1500) * np.exp(-t / 0.008)
    rumble = lowpass(noise(n, 23), 140) * np.exp(-t / 0.5)
    put(x, 0.9 * pk(boom) + 0.7 * pk(blast) + 0.5 * pk(crack) + 0.6 * pk(rumble))
    return reverb_lin(x, 1.5, 0.35, 19, hf=0.6)


def sfx_notification():
    x = cv(1.2)
    put(x, bell(mtof(nm("E6")), 0.7, 0.18, 0.5), 0.0, 0.6)
    put(x, bell(mtof(nm("A6")), 0.9, 0.22, 0.5), 0.16, 0.6)
    return reverb_lin(x, 0.5, 0.12, 21)


def sfx_diplomacy_notify():
    x = cv(2.0)
    for i, m in enumerate(["A4", "D5", "E5", "A5"]):
        put(x, pluck_add(mtof(nm(m)), 1.1, 0.95, 0.6), 0.1 * i, 0.55)
    for k, m in enumerate(["A3", "E4"]):
        put(x, string_pad(round(mtof(nm(m)), 3), 0.7, 0.25, 0.6, 1400.0, 3, 6.0, 5 + k), 0.1, 0.14)
    return reverb_lin(x, 1.0, 0.25, 22)


def sfx_event_pop():
    x = cv(0.6)
    t = ts(0.12)
    f = 350 * np.exp(t / 0.12 * 1.2)
    pop = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.05)
    put(x, pk(pop), 0.0, 0.8)
    put(x, bandpass(noise(int(0.02 * SR), 4), 1500, 6000) * np.exp(-ts(0.02) / 0.004) * 0.4, 0.0, 1.0)
    put(x, pluck_add(mtof(nm("E6")), 0.4, 0.9, 0.18), 0.06, 0.45)
    put(x, pluck_add(mtof(nm("B6")), 0.3, 0.9, 0.14), 0.11, 0.3)
    return reverb_lin(x, 0.4, 0.12, 24)


def sfx_research_done():
    x = cv(2.2)
    for i, m in enumerate(["D5", "F5", "A5", "D6"]):
        put(x, pluck_add(mtof(nm(m)), 1.0, 0.95, 0.5), 0.09 * i, 0.55)
        put(x, bell(mtof(nm(m)) * 2, 0.8, 0.2, 0.4), 0.09 * i, 0.08)
    put(x, bell(mtof(nm("D6")), 1.4, 0.6, 0.5), 0.4, 0.3)
    sp = highpass(noise(int(0.9 * SR), 25), 6000) * ts(0.9) * np.exp(-ts(0.9) / 0.2)
    put(x, pk(sp), 0.35, 0.05)
    return reverb_lin(x, 1.1, 0.25, 25)


def sfx_war_declared():
    x = cv(3.6)
    for k, m in enumerate(["D2", "A2", "D3"]):
        put(x, brass(round(mtof(nm(m)), 3), 1.7, 0.5, 0.5, 1.5, 0.6, 0.08, 0.5, seed=40 + k), 0.0, 0.6 if k == 0 else 0.4)
    put(x, brass(round(mtof(nm("A3")), 3), 1.0, 0.35, 0.4, 1.7, 0.6, 0.06, 0.0, seed=45), 0.9, 0.3)
    for t0, g in [(0.0, 0.9), (1.0, 0.7), (1.3, 0.7), (1.9, 1.0)]:
        put(x, drum(55, 0.3, 0.9, 0.35, 0.4, seed=int(t0 * 10)), t0, g)
    return reverb_lin(x, 1.8, 0.3, 26, hf=0.7)


def sfx_peace_bell():
    x = cv(5.0)
    put(x, bell(mtof(nm("D4")), 4.2, 1.5, 0.9), 0.0, 0.9)
    put(x, bell(mtof(nm("D4")), 3.4, 1.4, 0.9), 1.7, 0.55)
    put(x, bell(mtof(nm("A4")), 2.0, 1.0, 0.6), 1.7, 0.15)
    return reverb_lin(x, 2.0, 0.25, 27)


def sfx_victory():
    x = cv(5.0)
    mel = [("D4", 0.0, 0.22), ("D4", 0.26, 0.22), ("D4", 0.52, 0.22), ("F#4", 0.78, 0.4),
           ("D4", 1.24, 0.2), ("F#4", 1.5, 0.2), ("A4", 1.74, 0.6),
           ("D5", 2.4, 1.8)]
    for i, (m, t0, d) in enumerate(mel):
        _fanfare_note(m, t0, d, 0.7, x, seed=50 + i)
    for k, m in enumerate(["D3", "A3", "D4", "F#4", "A4"]):
        _fanfare_note(m, 2.4, 1.8, 0.35, x, attack=0.06, bright=1.3, seed=60 + k)
    for t0, g in [(0.0, 0.7), (0.78, 0.7), (1.74, 0.8), (2.4, 1.0)]:
        put(x, drum(68, 0.3, 0.8, 0.4, 0.4, seed=int(t0 * 10) + 3), t0, g)
    cym = highpass(noise(int(2.2 * SR), 28), 4500) * np.exp(-ts(2.2) / 0.5)
    put(x, pk(cym), 2.4, 0.18)
    put(x, bell(mtof(nm("D5")), 2.2, 0.7, 0.6), 2.4, 0.15)
    return reverb_lin(x, 1.6, 0.25, 28)


def sfx_defeat():
    x = cv(5.0)
    mel = [("A3", 0.0, 0.7), ("G3", 0.8, 0.7), ("F3", 1.6, 0.7), ("D3", 2.4, 2.0)]
    for i, (m, t0, d) in enumerate(mel):
        _fanfare_note(m, t0, d, 0.65, x, attack=0.12, bright=0.8, vib=0.3, seed=70 + i)
        _fanfare_note(m[0] + "2", t0, d, 0.4, x, attack=0.12, bright=0.8, vib=0.3, seed=80 + i)
    for t0, g in [(0.0, 0.7), (0.8, 0.55), (1.6, 0.55), (2.4, 0.9)]:
        put(x, drum(52, 0.35, 1.0, 0.2, 0.4, seed=int(t0 * 10) + 7), t0, g)
    put(x, bell(mtof(nm("D3")), 3.0, 1.4, 0.5), 2.4, 0.4)
    return reverb_lin(x, 2.2, 0.32, 29, hf=0.6)


def sfx_turn_end():
    x = cv(0.9)
    sw = swept_noise(0.35, 1200, 5200, bw=1.6, seed=31) * np.sin(np.linspace(0, np.pi, int(0.35 * SR))) ** 1.2
    put(x, sw, 0.0, 0.5)
    put(x, rustle(0.5, 32, 90), 0.15, 0.7)
    put(x, rustle(0.25, 33, 60, 1500, 5000), 0.0, 0.35)
    put(x, drum(150, 0.04, 0.15, 0.4, 0.0, seed=2), 0.48, 0.25)
    return reverb_lin(x, 0.35, 0.1, 33)


def sfx_sword():
    x = cv(1.0)
    sw = swept_noise(0.2, 700, 7000, bw=1.2, seed=34) * np.sin(np.linspace(0, np.pi, int(0.2 * SR))) ** 1.0
    put(x, sw, 0.0, 0.9)
    put(x, clang(2100, 0.7, 9, 0.35), 0.17, 0.7)
    put(x, fm_ping(3400, 0.6, 2.76, 1.2, 0.3, 0.05), 0.17, 0.2)
    return reverb_lin(x, 0.5, 0.12, 34)


SFX = {
    "ui_click": sfx_ui_click, "ui_back": sfx_ui_back, "ui_open": sfx_ui_open, "ui_close": sfx_ui_close,
    "ui_error": sfx_ui_error, "ui_confirm": sfx_ui_confirm, "coin": sfx_coin,
    "build_complete": sfx_build_complete, "recruit": sfx_recruit, "march": sfx_march, "clash": sfx_clash,
    "battle_win": sfx_battle_win, "battle_lose": sfx_battle_lose, "cannon": sfx_cannon,
    "notification": sfx_notification, "diplomacy_notify": sfx_diplomacy_notify, "event_pop": sfx_event_pop,
    "research_done": sfx_research_done, "war_declared": sfx_war_declared, "peace_bell": sfx_peace_bell,
    "victory": sfx_victory, "defeat": sfx_defeat, "turn_end": sfx_turn_end, "sword": sfx_sword,
}
MUSIC = {
    "music_menu": render_music_menu, "music_campaign": render_music_campaign, "music_battle": render_music_battle,
}
LOOPS = set(MUSIC)


# --------------------------------------------------------------------------- #
# output
# --------------------------------------------------------------------------- #

def _ogg_crc_table():
    tab = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if r & 0x80000000 else (r << 1) & 0xFFFFFFFF
        tab.append(r)
    return tab


_CRC = _ogg_crc_table()


def normalise_ogg_serial(path, serial=0x494D5052):
    """libsndfile picks a random Ogg stream serial; pin it so output is byte-reproducible."""
    data = bytearray(Path(path).read_bytes())
    pos = 0
    while pos < len(data):
        assert data[pos:pos + 4] == b"OggS"
        nseg = data[pos + 26]
        body = sum(data[pos + 27: pos + 27 + nseg])
        end = pos + 27 + nseg + body
        data[pos + 14: pos + 18] = serial.to_bytes(4, "little")
        data[pos + 22: pos + 26] = b"\0\0\0\0"
        crc = 0
        for b in data[pos:end]:
            crc = ((crc << 8) & 0xFFFFFFFF) ^ _CRC[((crc >> 24) & 0xFF) ^ b]
        data[pos + 22: pos + 26] = crc.to_bytes(4, "little")
        pos = end
    Path(path).write_bytes(bytes(data))


def _write_ogg_once(path, chs):
    data = np.stack(chs, axis=1).astype(np.float32)
    fmt, sub = ("OGG", "VORBIS")
    if sub not in sf.available_subtypes(fmt):
        raise RuntimeError("OGG Vorbis not available in this libsndfile build")
    # libsndfile maps compression_level -> vorbis quality = 1 - level
    # (written in chunks: a single huge sf.write() segfaults in some libsndfile builds)
    with sf.SoundFile(str(path), "w", SR, data.shape[1], format=fmt, subtype=sub,
                      compression_level=1.0 - VORBIS_QUALITY) as f:
        for i in range(0, len(data), 32768):
            f.write(data[i:i + 32768])
    normalise_ogg_serial(path)


def write_ogg(path, chs, limit_db=-3.2):
    """Encode, decode, and trim gain until the *decoded* peak respects the ceiling
    (Vorbis can overshoot the source peak by a few dB on pure tones)."""
    for _ in range(6):
        _write_ogg_once(path, chs)
        dec, _sr = sf.read(str(path), always_2d=True)
        peak = np.max(np.abs(dec))
        if db(peak) <= limit_db:
            return
        k = 10 ** ((limit_db - 0.15 - db(peak)) / 20)
        chs = [c * k for c in chs]


def trim_sfx(x):
    p = np.max(np.abs(x))
    idx = np.where(np.abs(x) > p * 10 ** (-60 / 20))[0]
    e = min(len(x), idx[-1] + int(0.05 * SR))
    x = x[:e]
    x = highpass(x, 30)
    x = x.copy()
    k = int(0.0005 * SR)
    x[:k] *= np.linspace(0, 1, k)
    return fade_tail(x, min(0.03, 0.2 * len(x) / SR))


def render(name):
    t0 = time.time()
    if name in MUSIC:
        L, R = MUSIC[name]()
        L, R = finalise([L, R], MUSIC_LUFS, sfx=False)
        write_ogg(OUT_DIR / f"{name}.ogg", [L, R])
    else:
        x = trim_sfx(SFX[name]())
        (x,) = finalise([x], SFX_LUFS, sfx=True)
        write_ogg(OUT_DIR / f"{name}.ogg", [x])
    return time.time() - t0


# --------------------------------------------------------------------------- #
# analysis
# --------------------------------------------------------------------------- #

def seam_ratio(x):
    """Max |diff| within +-32 samples of the loop seam vs the 99.9th percentile elsewhere."""
    worst = 0.0
    for c in x.T:
        d = np.abs(np.diff(np.concatenate([c[-32:], c[:32]])))
        base = np.percentile(np.abs(np.diff(c)), 99.9) + 1e-9
        worst = max(worst, d.max() / base)
    return worst


def analyse(names):
    rows = []
    for name in names:
        p = OUT_DIR / f"{name}.ogg"
        if not p.exists():
            rows.append((name, "MISSING"))
            continue
        x, sr = sf.read(str(p), always_2d=True)
        size = p.stat().st_size / 1024
        peak = np.max(np.abs(x))
        rms = np.sqrt(np.mean(x ** 2))
        chs = [x[:, i] for i in range(x.shape[1])]
        loud = lufs_gated(chs) if name in LOOPS else lufs_sfx(chs)
        nan = bool(np.isnan(x).any())
        clip = bool(peak >= 0.999)
        seam = seam_ratio(x) if name in LOOPS else float("nan")
        # first/last 50 ms window RMS (loops)
        w = int(0.05 * SR)
        edge = (db(np.sqrt(np.mean(x[:w] ** 2))), db(np.sqrt(np.mean(x[-w:] ** 2)))) if name in LOOPS else None
        limit = 2500 if name in LOOPS else 150
        problems = []
        if nan:
            problems.append("NaN")
        if clip:
            problems.append("CLIP")
        if db(peak) > -3.0:
            problems.append("PEAK>-3")
        if size > limit:
            problems.append("SIZE")
        if sr != SR:
            problems.append("SR")
        if name in LOOPS and seam > 2.0:
            problems.append("SEAM")
        rows.append((name, len(x) / sr, x.shape[1], size, db(peak), db(rms), loud, seam, edge,
                     "OK" if not problems else ",".join(problems)))
    print(f"{'file':18s} {'dur(s)':>7s} {'ch':>2s} {'KB':>7s} {'peak':>7s} {'rms':>7s} {'LUFS':>7s} {'seam':>6s} {'edge50ms dB':>14s}  status")
    for r in rows:
        if len(r) == 2:
            print(f"{r[0]:18s} {r[1]}")
            continue
        name, dur, ch, size, pkdb, rmsdb, loud, seam, edge, st = r
        sm = f"{seam:6.2f}" if seam == seam else "     -"
        eg = f"{edge[0]:6.1f}/{edge[1]:6.1f}" if edge else "             -"
        print(f"{name:18s} {dur:7.2f} {ch:2d} {size:7.1f} {pkdb:7.2f} {rmsdb:7.2f} {loud:7.2f} {sm} {eg:>14s}  {st}")
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="render only these names")
    ap.add_argument("--analyse-only", action="store_true")
    args = ap.parse_args()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    names = list(MUSIC) + list(SFX)
    if args.only:
        bad = [n for n in args.only if n not in names]
        if bad:
            sys.exit(f"unknown names: {bad}")
        names = args.only
    if not args.analyse_only:
        for n in names:
            dt = render(n)
            print(f"rendered {n:18s} {dt:6.1f}s", flush=True)
    analyse(names)


if __name__ == "__main__":
    main()
