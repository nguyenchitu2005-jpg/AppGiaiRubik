"""Synthesizes the app's cube sounds (no recorded samples, so no licensing).

    python tool/sounds/generate_sounds.py

writes assets/sounds/turn.wav (one layer turn) and assets/sounds/scramble.wav
(a quick run of turns). A turn is a short plastic "shh" of the layer sliding,
ending in the "clack" of it locking into place.
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / 'assets' / 'sounds'


def resonator(signal, freq, q):
    """Two-pole band-pass filter: gives noise a plastic, hollow pitch."""
    w = 2 * math.pi * freq / RATE
    r = math.exp(-w / (2 * q))
    a1, a2 = -2 * r * math.cos(w), r * r
    gain = 1 - r
    y1 = y2 = 0.0
    out = []
    for x in signal:
        y = gain * x - a1 * y1 - a2 * y2
        out.append(y)
        y1, y2 = y, y1
    return out


def high_pass(signal, cutoff):
    alpha = 1 / (1 + 2 * math.pi * cutoff / RATE)
    out, prev_x, prev_y = [], 0.0, 0.0
    for x in signal:
        y = alpha * (prev_y + x - prev_x)
        out.append(y)
        prev_x, prev_y = x, y
    return out


def turn(rng, pitch=1.0, slide=0.075):
    """One layer turn: [slide] seconds of friction, then the click."""
    n_slide = int(slide * RATE)
    n_click = int(0.07 * RATE)
    noise = [rng.uniform(-1, 1) for _ in range(n_slide + n_click)]

    # Friction: swells and fades while the layer slides.
    friction = [0.0] * len(noise)
    body = [
        a + b
        for a, b in zip(
            resonator(noise, 2300 * pitch, 3.0),
            resonator(noise, 4200 * pitch, 4.0),
        )
    ]
    for i in range(n_slide):
        t = i / n_slide
        friction[i] = body[i] * 0.55 * math.sin(math.pi * t) ** 1.5

    # Click: a sharp transient ringing at a couple of plastic modes.
    impulse = [0.0] * len(noise)
    for i in range(n_click):
        env = math.exp(-i / (0.0045 * RATE))
        impulse[n_slide + i] = noise[n_slide + i] * env
    click = [
        a * 1.6 + b * 1.1 + c * 0.5
        for a, b, c in zip(
            resonator(impulse, 1900 * pitch, 9.0),
            resonator(impulse, 3300 * pitch, 11.0),
            resonator(impulse, 5600 * pitch, 7.0),
        )
    ]
    return high_pass([f + c for f, c in zip(friction, click)], 250)


def mix(length, parts):
    out = [0.0] * length
    for start, samples, gain in parts:
        for i, s in enumerate(samples):
            if start + i < length:
                out[start + i] += s * gain
    return out


def normalize(signal, peak=0.85):
    top = max(abs(s) for s in signal) or 1.0
    fade = int(0.004 * RATE)  # no click at the very start or end
    out = [s * peak / top for s in signal]
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


def write(name, signal):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(
            b''.join(
                struct.pack('<h', int(max(-1, min(1, s)) * 32767))
                for s in signal
            )
        )
    print(f'{name}: {len(signal) / RATE:.2f} s')


def main():
    rng = random.Random(7)

    one = turn(rng)
    write('turn.wav', normalize(one + [0.0] * int(0.02 * RATE)))

    # Scramble: 24 fast, slightly different turns, then a last firm one;
    # about as long as the scramble animation (25 moves at 70 ms a quarter).
    parts, t = [], 0.0
    for k in range(24):
        pitch = rng.uniform(0.9, 1.12)
        slide = rng.uniform(0.035, 0.06)
        parts.append((int(t * RATE), turn(rng, pitch, slide), rng.uniform(0.6, 1.0)))
        t += rng.uniform(0.07, 0.095)
    parts.append((int(t * RATE), turn(rng, 1.0, 0.07), 1.0))
    length = int((t + 0.2) * RATE)
    write('scramble.wav', normalize(mix(length, parts)))


if __name__ == '__main__':
    main()
