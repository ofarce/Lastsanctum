"""Générateur de bruitages 16 bits (synthèse pure, reproductible).

Usage : python3 tools/sons/generer.py   → écrit assets/audio/sfx/*.wav

« victoire » est défini ici ; les autres sons viennent du catalogue de propositions.py
(planche planches/sons-propositions.html), normalisés puis joués au dB de ui/audio/sfx_player.gd.
"""
import pathlib
import wave

import numpy as np

SR = 32000  # fréquence de la puce son SNES
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/audio/sfx"


def note(n: str) -> float:
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semi = names[n[0]] + (1 if "#" in n else 0)
    octave = int(n[-1])
    return 440.0 * 2 ** ((semi + 12 * (octave + 1) - 69) / 12)


def pulse(freq, dur, duty=0.25, vib=0.0):
    t = np.arange(int(SR * dur)) / SR
    phase = freq * t + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t - 0.08, 0, None)
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def triangle(freq, dur):
    t = np.arange(int(SR * dur)) / SR
    p = (freq * t) % 1.0
    return 4 * np.abs(p - 0.5) - 1


def env(n, attack=0.004, decay=0.08, sustain=0.6, release=0.05):
    t = np.arange(n) / SR
    d = n / SR
    e = np.minimum(1.0, t / attack)
    e *= sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / decay)
    e *= np.clip((d - t) / release, 0, 1)
    return e


def place(buf, sig, start):
    i = int(start * SR)
    buf[i:i + len(sig)] += sig[: len(buf) - i]


def echo(x, delay=0.12, fb=0.35, mix=0.3):
    d = int(delay * SR)
    y = x.copy()
    for i in range(d, len(y)):
        y[i] += fb * y[i - d]
    return (1 - mix) * x + mix * y


def lowpass(x, a=0.35):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def victoire():
    """Obtention sobre : trois notes en la mineur, puis une quinte à vide qui s'éteint.

    Timbre doux (triangle + pulsation large très filtrée), pas d'arpège brillant ni de tierce majeure.
    """
    total = 2.2
    lead = np.zeros(int(SR * total))
    pad = np.zeros_like(lead)
    bass = np.zeros_like(lead)
    step = 0.16
    for i, n in enumerate(["A4", "C5", "E5"]):
        s = triangle(note(n), step * 1.1)
        s = s + 0.25 * pulse(note(n), step * 1.1, 0.5)
        place(lead, s * env(len(s), attack=0.012, decay=0.12, sustain=0.5, release=0.05), i * step)
    t0 = 3 * step + 0.02
    # Note tenue sur la quinte (ni victoire franche, ni défaite) : mi, vibrato discret.
    s = triangle(note("E5"), 1.5) + 0.2 * pulse(note("E5"), 1.5, 0.5, vib=0.006 * note("E5"))
    place(lead, s * env(len(s), attack=0.02, decay=0.4, sustain=0.35, release=0.8), t0)
    for n in ["A4", "E4"]:
        s = triangle(note(n), 1.5)
        place(pad, s * env(len(s), attack=0.08, decay=0.5, sustain=0.4, release=0.8), t0)
    s = triangle(note("A3"), 1.6)
    place(bass, s * env(len(s), attack=0.01, decay=0.6, sustain=0.5, release=0.8), 0.0)
    mix = 0.45 * lead + 0.25 * pad + 0.35 * bass
    mix = echo(lowpass(mix, 0.18), delay=0.16, fb=0.3, mix=0.25)
    return mix * 0.75  # crête plus basse que les autres sons


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(OUT / f"{name}.wav", f"{len(x) / SR:.2f}s")


if __name__ == "__main__":
    write("victoire", victoire())
    import propositions  # importé ici : propositions.py importe lui-même ce module

    for name, fn, *_ in propositions.CATALOGUE:
        if name != "victoire":
            write(name, propositions.normalize(fn()))
