#!/usr/bin/env python3
"""Real-time audio spectrum for the bar media visualizer (SpectrumModel.qml).

Captures the default sink's monitor via pw-record (ships with PipeWire)
and computes BANDS log-spaced frequency bands from a real FFT — plain
stdlib, no numpy, no cava. Prints one frame per 1/FPS seconds as
semicolon-separated ints 0-100 on stdout, flushed, bass first.

The band edges tile the full 50 Hz .. 16 kHz range with no gaps: every
FFT bin in that range contributes to exactly one column (~half an
octave each at 15 bands), so the whole spectrum is represented. A mild
treble tilt and square-root compression counteract music's natural 1/f
energy slope so all columns participate.

Latency is one analysis window (~43 ms) plus PipeWire's quantum; there
is no smoothing filter on the attack path — a band rises the same frame
its frequency appears, and falls with DECAY_HALF_LIFE so the dots
don't strobe (fps-independent feel).

Usage: spectrum.py [bands] [fps]   (defaults 8, 20)
"""
import math
import struct
import subprocess
import sys
import time
from array import array

BANDS = int(sys.argv[1]) if len(sys.argv) > 1 else 8
FPS = max(1, int(sys.argv[2])) if len(sys.argv) > 2 else 20

RATE = 48000
WINDOW = 2048                     # FFT size: ~43 ms, 23 Hz bins —
                                  # resolves 15 independent bands at FMIN
HOP = max(1, RATE // FPS)         # samples consumed per displayed frame
AU_HEADER = 24                    # pw-record writes an AU header on stdout
FMIN, FMAX = 50.0, 16000.0
# Treble boost vs. band center. 0.5 exactly compensates a pink (1/f)
# spectrum, so typical music reads near-flat with a natural gentle
# roll-off at the very top.
TILT = 0.5
# Amplitude compression: v = (band/peak)^COMPRESS. 0.4 maps a band at
# -20 dB of the frame peak to ~3 of the 8 dot rows, while leaving
# -40 dB leakage/noise at ~1 dot. (0.25 rendered -40 dB skirts at 2-3
# dots — sensitive, but it flattened real dynamics.)
COMPRESS = 0.4

# fps-independent envelopes: bands fall with DECAY_HALF_LIFE (rise is
# instant), auto-gain releases ~30%/s so quiet passages renormalize
# within a second or two without pumping.
DECAY_HALF_LIFE = 0.25  # seconds for a band to fall halfway
DECAY = 0.5 ** (1.0 / (FPS * DECAY_HALF_LIFE))
GAIN_DECAY = 0.7 ** (1.0 / FPS)

hann = [0.5 - 0.5 * math.cos(2.0 * math.pi * n / (WINDOW - 1)) for n in range(WINDOW)]

# Assign each FFT bin in [FMIN, FMAX) to one band via log-spaced edges.
edges = [FMIN * (FMAX / FMIN) ** (i / BANDS) for i in range(BANDS + 1)]
band_bins = [[] for _ in range(BANDS)]
for b in range(1, WINDOW // 2):
    f = b * RATE / WINDOW
    for k in range(BANDS):
        if edges[k] <= f < edges[k + 1]:
            band_bins[k].append(b)
            break
# At high band counts the lowest bands are narrower than one FFT bin —
# give any empty band the bin nearest its center (neighbors may share).
for k in range(BANDS):
    if not band_bins[k]:
        center = math.sqrt(edges[k] * edges[k + 1])
        band_bins[k] = [max(1, min(WINDOW // 2 - 1, round(center * WINDOW / RATE)))]
tilt = [(math.sqrt(edges[k] * edges[k + 1]) / edges[0]) ** TILT for k in range(BANDS)]

RECORD_CMD = [
    "pw-record", "-P", "{ stream.capture.sink = true }",
    "--format", "s16", "--rate", str(RATE), "--channels", "1", "-",
]


def fft(re, im):
    """In-place iterative radix-2 FFT (len must be a power of two)."""
    n = len(re)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            re[i], re[j] = re[j], re[i]
            im[i], im[j] = im[j], im[i]
    length = 2
    while length <= n:
        ang = -2.0 * math.pi / length
        wr, wi = math.cos(ang), math.sin(ang)
        half = length >> 1
        for start in range(0, n, length):
            cr, ci = 1.0, 0.0
            for k in range(start, start + half):
                h = k + half
                tr = re[h] * cr - im[h] * ci
                ti = re[h] * ci + im[h] * cr
                re[h] = re[k] - tr
                im[h] = im[k] - ti
                re[k] += tr
                im[k] += ti
                cr, ci = cr * wr - ci * wi, cr * wi + ci * wr
        length <<= 1


def run(proc):
    levels = [0.0] * BANDS
    gain = 1e-9  # rolling peak for auto-normalization
    buf = array("h")
    proc.stdout.read(AU_HEADER)
    while True:
        chunk = proc.stdout.read(HOP * 2)
        if not chunk or len(chunk) < HOP * 2:
            return
        buf.frombytes(chunk)
        buf = buf[-WINDOW:]
        if len(buf) < WINDOW:
            continue

        re = [s * w for s, w in zip(buf, hann)]
        im = [0.0] * WINDOW
        fft(re, im)

        # Average power per bin in each band (so wide treble bands don't
        # win just by containing more bins), tilted and compressed.
        frame = []
        for k in range(BANDS):
            power = sum(re[b] * re[b] + im[b] * im[b] for b in band_bins[k])
            frame.append(math.sqrt(power / len(band_bins[k])) * tilt[k])

        gain = max(max(frame), gain * GAIN_DECAY, 1e-9)
        out = []
        for k in range(BANDS):
            v = (frame[k] / gain) ** COMPRESS
            # Instant attack; otherwise decay, floored at the live value
            # so a steady tone holds steady instead of sawtoothing.
            levels[k] = max(v, levels[k] * DECAY)
            out.append(str(min(100, int(levels[k] * 100))))
        sys.stdout.write(";".join(out) + "\n")
        sys.stdout.flush()


# Respawn pw-record if it exits (default sink changed, PipeWire restart)
# so the visualizer recovers without a shell reload.
while True:
    with subprocess.Popen(RECORD_CMD, stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL) as proc:
        try:
            run(proc)
        finally:
            proc.terminate()
    time.sleep(1)
