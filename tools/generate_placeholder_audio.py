#!/usr/bin/env python3
"""Generates the placeholder ambient loops and one-shots in godot/audio/streams.

The sounds are synthesised from noise and sine waves with fixed seeds, so the output is
reproducible and owned by the project (no third-party licence). They are stand-ins for produced
audio (CONTENT_PLAN §4): replace the files, keep the names, and the mix in data/audio.json keeps
working. Run only when a sound changes; the generated .wav files are committed.

    python tools/generate_placeholder_audio.py
"""
from pathlib import Path
import wave

import numpy as np

OUT = Path(__file__).resolve().parents[1] / "godot" / "audio" / "streams"
LOOP_SR = 16000
SHOT_SR = 22050


def _rng(name: str) -> np.random.Generator:
    return np.random.default_rng(abs(hash_str(name)) % (2**32))


def hash_str(text: str) -> int:
    value = 5381
    for char in text:
        value = (value * 33 + ord(char)) & 0xFFFFFFFF
    return value


def noise(rng, seconds: float, sr: int) -> np.ndarray:
    return rng.standard_normal(int(seconds * sr))


def band(x: np.ndarray, sr: int, low: float, high: float) -> np.ndarray:
    """Smooth band-pass via FFT (low=0 for a low-pass, high>=sr/2 for a high-pass)."""
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / sr)
    gain = np.ones_like(freqs)
    if low > 0:
        gain *= 1.0 / (1.0 + (low / np.maximum(freqs, 1e-6)) ** 4)
    if high < sr / 2:
        gain *= 1.0 / (1.0 + (freqs / high) ** 4)
    return np.fft.irfft(spectrum * gain, n=len(x))


def smooth_random(rng, n: int, sr: int, hz: float) -> np.ndarray:
    """Slow random curve in 0..1 changing about `hz` times per second."""
    points = max(4, int(n / sr * hz) + 2)
    anchors = rng.random(points)
    curve = np.interp(np.linspace(0, points - 1, n), np.arange(points), anchors)
    kernel = np.hanning(int(sr / hz / 2) | 1)
    curve = np.convolve(curve, kernel / kernel.sum(), mode="same")
    return (curve - curve.min()) / max(curve.max() - curve.min(), 1e-9)


def make_seamless(x: np.ndarray, fade: int) -> np.ndarray:
    """Cross-fades the tail into the head so the loop has no click."""
    body = x[:-fade].copy()
    ramp = np.linspace(0.0, 1.0, fade)
    body[:fade] = body[:fade] * ramp + x[-fade:] * (1.0 - ramp)
    return body


def normalize(x: np.ndarray, peak: float = 0.8) -> np.ndarray:
    return x / max(np.abs(x).max(), 1e-9) * peak


def envelope(n: int, attack: float, decay: float, sr: int) -> np.ndarray:
    t = np.arange(n) / sr
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / max(decay, 1e-4))


def write(name: str, x: np.ndarray, sr: int) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(OUT / name), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sr)
        handle.writeframes(data.tobytes())
    print(f"{name}: {len(data) / sr:.2f}s, {len(data) * 2 // 1024} KB")


def water_loop():
    rng = _rng("water")
    sr = LOOP_SR
    base = band(noise(rng, 9.0, sr), sr, 60, 900)
    swell = 0.55 + 0.45 * smooth_random(rng, len(base), sr, 0.6)
    laps = band(noise(rng, 9.0, sr), sr, 250, 1400) * smooth_random(rng, len(base), sr, 2.2) ** 3
    return normalize(make_seamless(base * swell + laps * 0.8, sr), 0.7)


def wind_loop():
    rng = _rng("wind")
    sr = LOOP_SR
    x = band(noise(rng, 12.0, sr), sr, 180, 1500)
    gust = 0.25 + 0.75 * smooth_random(rng, len(x), sr, 0.22)
    return normalize(make_seamless(x * gust, sr), 0.7)


def rain_loop():
    rng = _rng("rain")
    sr = LOOP_SR
    x = band(noise(rng, 7.0, sr), sr, 1800, sr / 2)
    drops = np.zeros(len(x))
    for position in rng.integers(0, len(x) - 200, size=int(len(x) / sr * 70)):
        n = 120
        drops[position:position + n] += band(rng.standard_normal(n), sr, 1500, 6500) * envelope(n, 0.001, 0.01, sr) * rng.uniform(0.4, 1.4)
    return normalize(make_seamless(x * 0.55 + drops * 1.2, sr), 0.65)


def chirp(sr, f0, f1, seconds, vibrato=0.0):
    n = int(seconds * sr)
    t = np.arange(n) / sr
    freq = np.linspace(f0, f1, n) * (1.0 + vibrato * np.sin(2 * np.pi * 28 * t))
    phase = 2 * np.pi * np.cumsum(freq) / sr
    return np.sin(phase) * envelope(n, 0.008, seconds / 3.0, sr)


def bird_a():
    sr = SHOT_SR
    parts = []
    for f0, f1 in [(3600, 4600), (3300, 4900), (4200, 3200), (3800, 4800)]:
        parts.append(chirp(sr, f0, f1, 0.09, 0.02))
        parts.append(np.zeros(int(0.06 * sr)))
    return normalize(np.concatenate(parts), 0.55)


def bird_b():
    sr = SHOT_SR
    return normalize(np.concatenate([
        chirp(sr, 2200, 2500, 0.28), np.zeros(int(0.05 * sr)), chirp(sr, 2900, 2500, 0.34)]), 0.5)


def frog():
    sr = SHOT_SR
    n = int(0.4 * sr)
    t = np.arange(n) / sr
    body = np.sin(2 * np.pi * 170 * t) + 0.5 * np.sin(2 * np.pi * 340 * t)
    pulses = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 26 * t))
    return normalize(body * pulses * envelope(n, 0.02, 0.25, sr), 0.5)


def cricket():
    sr = SHOT_SR
    parts = []
    for _ in range(4):
        n = int(0.07 * sr)
        t = np.arange(n) / sr
        parts.append(np.sin(2 * np.pi * 4600 * t) * envelope(n, 0.004, 0.03, sr))
        parts.append(np.zeros(int(0.05 * sr)))
    return normalize(np.concatenate(parts + [np.zeros(int(0.3 * sr))] + parts), 0.35)


def splash(seconds=0.45, low=200, high=2600, gain=1.0):
    rng = _rng(f"splash{seconds}{low}")
    sr = SHOT_SR
    n = int(seconds * sr)
    return normalize(band(rng.standard_normal(n), sr, low, high) * envelope(n, 0.004, seconds / 4.0, sr), 0.6 * gain)


def cast():
    rng = _rng("cast")
    sr = SHOT_SR
    n = int(0.5 * sr)
    t = np.arange(n) / sr
    rise = np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 2
    return normalize(band(rng.standard_normal(n), sr, 600, 3500) * rise, 0.45)


def plop():
    sr = SHOT_SR
    n = int(0.28 * sr)
    t = np.arange(n) / sr
    sweep = np.sin(2 * np.pi * np.cumsum(np.linspace(520, 170, n)) / sr)
    return normalize(sweep * envelope(n, 0.002, 0.07, sr) + splash(0.28, 300, 2200, 0.4)[:n] * 0.4, 0.6)


def bite():
    sr = SHOT_SR
    tick = np.sin(2 * np.pi * 700 * np.arange(int(0.05 * sr)) / sr) * envelope(int(0.05 * sr), 0.002, 0.015, sr)
    gap = np.zeros(int(0.08 * sr))
    return normalize(np.concatenate([tick, gap, tick * 0.7]), 0.4)


def hooked():
    sr = SHOT_SR
    n = int(0.2 * sr)
    t = np.arange(n) / sr
    return normalize(np.sin(2 * np.pi * 140 * t) * envelope(n, 0.002, 0.05, sr), 0.6)


def caught():
    sr = SHOT_SR
    parts = []
    for freq in (523.25, 659.25, 783.99):
        n = int(0.22 * sr)
        t = np.arange(n) / sr
        parts.append((np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)) * envelope(n, 0.006, 0.12, sr))
    return normalize(np.concatenate(parts), 0.5)


def released():
    rng = _rng("release")
    sr = SHOT_SR
    n = int(0.7 * sr)
    swish = splash(0.7, 150, 2200, 0.8)[:n]
    bubbles = np.zeros(n)
    for position in rng.integers(int(0.1 * sr), n - 2000, size=5):
        m = 1800
        t = np.arange(m) / sr
        f = rng.uniform(500, 900)
        bubbles[position:position + m] += np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.6, m)) / sr) * envelope(m, 0.002, 0.03, sr) * 0.4
    return normalize(swish + bubbles, 0.55)


SOUNDS = {
    "water_loop.wav": (water_loop, LOOP_SR),
    "wind_loop.wav": (wind_loop, LOOP_SR),
    "rain_loop.wav": (rain_loop, LOOP_SR),
    "bird_a.wav": (bird_a, SHOT_SR),
    "bird_b.wav": (bird_b, SHOT_SR),
    "frog.wav": (frog, SHOT_SR),
    "cricket.wav": (cricket, SHOT_SR),
    "fish_jump.wav": (lambda: splash(0.5, 180, 2800, 0.9), SHOT_SR),
    "cast.wav": (cast, SHOT_SR),
    "plop.wav": (plop, SHOT_SR),
    "bite.wav": (bite, SHOT_SR),
    "hooked.wav": (hooked, SHOT_SR),
    "caught.wav": (caught, SHOT_SR),
    "released.wav": (released, SHOT_SR),
    "escaped.wav": (lambda: splash(0.4, 250, 1800, 0.45), SHOT_SR),
}

if __name__ == "__main__":
    total = 0
    for file_name, (factory, sample_rate) in SOUNDS.items():
        write(file_name, factory(), sample_rate)
        total += (OUT / file_name).stat().st_size
    print(f"total {total // 1024} KB")
