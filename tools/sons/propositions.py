"""Propositions de bruitages pour la planche d'écoute (planches/sons-propositions.html).

Usage : python3 tools/sons/propositions.py
  → planches/assets/sons/*.wav + planches/assets/sons/sons.js (métadonnées de la planche)

Même moteur que generer.py (32 kHz, timbres triangle / pulsation / bruit). Rien n'est écrit
dans assets/audio : un son validé sera recopié comme fonction dans generer.py puis émis.
Ton commun (cf. « victoire ») : discret, sobre, mineur, pas trop grave.
"""
import json
import pathlib
import sys
import wave

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from generer import SR, echo, env, lowpass, note, place, pulse, triangle, victoire  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "planches/assets/sons"
RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- briques

def n_(dur):
    return int(SR * dur)


def t_(dur):
    return np.arange(n_(dur)) / SR


def noise(dur):
    return RNG.uniform(-1, 1, n_(dur))


def dec(n, tau, attack=0.002):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.exp(-t / tau)


def glide(f0, f1, dur, shape="tri", duty=0.5):
    """Glissando exponentiel f0 → f1 (phase intégrée, sans clic)."""
    t = t_(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    p = np.cumsum(f) / SR
    if shape == "tri":
        return 4 * np.abs(p % 1.0 - 0.5) - 1
    if shape == "sin":
        return np.sin(2 * np.pi * p)
    return np.where((p % 1.0) < duty, 1.0, -1.0)


def sine(freq, dur):
    return np.sin(2 * np.pi * freq * t_(dur))


def hp(x, a):
    return x - lowpass(x, a)


def band(x, lo, hi):
    """Bande grossière : passe-bas a=hi puis retire le passe-bas a=lo."""
    y = lowpass(x, hi)
    return y - lowpass(y, lo)


def metal(freq, dur, tau, ratios=(1.0, 2.76, 5.40, 8.93), amps=(1.0, 0.5, 0.25, 0.12)):
    """Partiels inharmoniques (cloche, enclume, bouclier)."""
    x = np.zeros(n_(dur))
    for r, a in zip(ratios, amps):
        x += a * sine(freq * r, dur) * dec(n_(dur), tau / (0.6 + r * 0.4))
    return x


def mix(dur):
    return np.zeros(n_(dur))


def tone(n, dur, a=0.004, d=0.08, s=0.5, r=0.05, duty=0.5, pul=0.25):
    s_ = triangle(note(n), dur) + pul * pulse(note(n), dur, duty)
    return s_ * env(len(s_), attack=a, decay=d, sustain=s, release=r)


# ---------------------------------------------------------------- interface

def ui_clic():
    x = tone("E6", 0.05, d=0.02, s=0.2, r=0.02, pul=0.4)
    return lowpass(x, 0.4)


def ui_refus():
    b = mix(0.26)
    place(b, tone("E5", 0.09, d=0.05, s=0.4), 0.0)
    place(b, tone("D#5", 0.14, d=0.07, s=0.4, r=0.08), 0.09)
    return lowpass(b, 0.25)


def ui_banniere():
    b = mix(0.7)
    place(b, tone("A5", 0.5, a=0.01, d=0.15, s=0.25, r=0.3, pul=0.1), 0.0)
    place(b, 0.6 * tone("E6", 0.45, a=0.01, d=0.15, s=0.2, r=0.3, pul=0.1), 0.06)
    return echo(lowpass(b, 0.2), delay=0.11, fb=0.25, mix=0.25)


def ui_texte():
    b = mix(0.12)
    for i, n in enumerate(["A5", "C6", "A5"]):
        place(b, 0.7 * tone(n, 0.025, d=0.01, s=0.1, r=0.01, pul=0.6, duty=0.125), i * 0.04)
    return lowpass(b, 0.35)


def ui_inventaire():
    x = noise(0.16) * dec(n_(0.16), 0.03)
    x = band(x, 0.02, 0.3) * 1.6
    t = tone("C5", 0.12, d=0.04, s=0.2, r=0.04)
    b = mix(0.2)
    place(b, x, 0.0)
    place(b, 0.5 * t, 0.03)
    return b


def ui_selection():
    b = mix(0.12)
    place(b, tone("G5", 0.04, d=0.02, s=0.2, r=0.02), 0.0)
    place(b, tone("D6", 0.06, d=0.03, s=0.2, r=0.03), 0.035)
    return lowpass(b, 0.3)


def ui_ordre():
    x = glide(900, 520, 0.07, "pulse", 0.25) * dec(n_(0.07), 0.025)
    return lowpass(x, 0.3) * 0.8


# ---------------------------------------------------------------- base

def bat_pose():
    thud = glide(220, 110, 0.16, "sin") * dec(n_(0.16), 0.05)
    grit = band(noise(0.12), 0.03, 0.25) * dec(n_(0.12), 0.03)
    b = mix(0.2)
    place(b, thud, 0)
    place(b, 1.2 * grit, 0)
    return b


def bat_chantier():
    b = mix(0.95)
    for i, t0 in enumerate([0.0, 0.32, 0.64]):
        hit = metal(1250 + 40 * i, 0.25, 0.05, amps=(0.6, 0.35, 0.2, 0.1))
        tap = band(noise(0.04), 0.05, 0.5) * dec(n_(0.04), 0.008)
        place(b, hit, t0)
        place(b, 0.8 * tap, t0)
    return lowpass(b, 0.45)


def bat_termine():
    b = mix(1.1)
    place(b, tone("E5", 0.18, a=0.01, d=0.1, s=0.4), 0.0)
    place(b, tone("A5", 0.9, a=0.015, d=0.3, s=0.3, r=0.5), 0.14)
    place(b, 0.5 * tone("E5", 0.8, a=0.05, d=0.3, s=0.3, r=0.5), 0.14)
    return echo(lowpass(b, 0.2), delay=0.14, fb=0.25, mix=0.2)


def priere():
    b = mix(0.6)
    for i, n in enumerate(["E6", "B6"]):
        s = triangle(note(n), 0.4) * env(n_(0.4), attack=0.03, decay=0.12, sustain=0.2, release=0.25)
        place(b, 0.6 * s, i * 0.07)
    return echo(lowpass(b, 0.25), delay=0.09, fb=0.3, mix=0.3) * 0.7


def recherche():
    b = mix(1.4)
    for i, n in enumerate(["E5", "G5", "B5"]):
        place(b, tone(n, 0.16, a=0.01, d=0.1, s=0.4), i * 0.12)
    place(b, tone("E6", 0.8, a=0.02, d=0.3, s=0.3, r=0.5, pul=0.1), 0.38)
    return echo(lowpass(b, 0.18), delay=0.16, fb=0.3, mix=0.25)


def forge():
    b = mix(0.7)
    hit = metal(880, 0.6, 0.18)
    tap = band(noise(0.03), 0.05, 0.6) * dec(n_(0.03), 0.006)
    place(b, hit, 0)
    place(b, tap, 0)
    hiss = band(noise(0.4), 0.15, 0.7) * env(n_(0.4), attack=0.05, decay=0.1, sustain=0.3, release=0.2)
    place(b, 0.18 * hiss, 0.2)
    return b * 0.8


def coffre():
    b = mix(0.3)
    wood = glide(320, 180, 0.12, "tri") * dec(n_(0.12), 0.03)
    click = band(noise(0.02), 0.1, 0.7) * dec(n_(0.02), 0.004)
    place(b, click, 0.0)
    place(b, wood, 0.02)
    place(b, 0.6 * click, 0.12)
    return lowpass(b, 0.4)


def minage():
    b = mix(0.8)
    for t0, f in [(0.0, 1900), (0.35, 1750)]:
        place(b, metal(f, 0.2, 0.025, amps=(0.5, 0.3, 0.15, 0.08)), t0)
        place(b, band(noise(0.18), 0.04, 0.35) * dec(n_(0.18), 0.04), t0)
    return b


def objet_pose():
    b = mix(0.25)
    place(b, band(noise(0.15), 0.03, 0.3) * dec(n_(0.15), 0.035), 0)
    place(b, 0.5 * glide(260, 150, 0.1, "sin") * dec(n_(0.1), 0.03), 0)
    return b


def chausse_trapes():
    b = mix(0.3)
    for i in range(5):
        f = 2600 + RNG.uniform(-300, 300)
        place(b, 0.35 * metal(f, 0.08, 0.012, amps=(1, 0.4, 0.2, 0.1)), 0.03 * i + RNG.uniform(0, 0.015))
    return b


def adepte_arrive():
    b = mix(0.9)
    place(b, 0.6 * glide(330, 660, 0.5, "tri") * env(n_(0.5), attack=0.2, decay=0.2, sustain=0.4, release=0.2), 0)
    place(b, tone("A5", 0.4, a=0.02, d=0.15, s=0.25, r=0.25, pul=0.1), 0.42)
    return echo(lowpass(b, 0.2), delay=0.12, fb=0.3, mix=0.25) * 0.8


# ---------------------------------------------------------------- Exilés

def epee():
    sw = band(noise(0.12), 0.08, 0.6) * env(n_(0.12), attack=0.03, decay=0.03, sustain=0.0, release=0.03)
    hit = band(noise(0.06), 0.02, 0.25) * dec(n_(0.06), 0.012)
    b = mix(0.2)
    place(b, 0.8 * sw, 0)
    place(b, 1.3 * hit, 0.07)
    place(b, 0.6 * glide(200, 120, 0.06, "sin") * dec(n_(0.06), 0.02), 0.07)
    return b


def moulinet():
    b = mix(0.75)
    t = t_(0.5)
    sw = band(noise(0.5), 0.06, 0.5) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)) * env(n_(0.5), attack=0.06, decay=0.2, sustain=0.5, release=0.15)
    place(b, 0.9 * sw, 0)
    crack = hp(noise(0.25), 0.3) * dec(n_(0.25), 0.05) * (RNG.uniform(0, 1, n_(0.25)) > 0.7)
    place(b, 0.6 * crack, 0.42)
    place(b, 0.4 * glide(1400, 500, 0.25, "pulse", 0.125) * dec(n_(0.25), 0.07), 0.42)
    return lowpass(b, 0.5)


def arc():
    tw = glide(520, 440, 0.18, "tri") * dec(n_(0.18), 0.05)
    air = band(noise(0.14), 0.1, 0.6) * env(n_(0.14), attack=0.01, decay=0.05, sustain=0.0, release=0.05)
    b = mix(0.22)
    place(b, 0.7 * tw, 0)
    place(b, 0.5 * air, 0.02)
    return lowpass(b, 0.45)


def fleche_impact():
    b = mix(0.12)
    place(b, band(noise(0.05), 0.04, 0.4) * dec(n_(0.05), 0.01), 0)
    place(b, 0.6 * glide(600, 300, 0.05, "tri") * dec(n_(0.05), 0.015), 0)
    return b


def arbalestrie():
    """Tir de l'Arbalestrie (cadence 0,25 s) : déclic, corde sèche, scintillement d'énergie spirituelle.

    Bruit tiré d'un générateur propre pour ne pas décaler le hasard des autres sons du catalogue.
    """
    rng = np.random.default_rng(45)
    d = 0.2
    b = mix(d)
    click = band(rng.uniform(-1, 1, n_(0.012)), 0.1, 0.7) * dec(n_(0.012), 0.003)
    place(b, 0.9 * click, 0.0)
    place(b, 0.35 * metal(2900, 0.04, 0.008, amps=(1, 0.4, 0.2, 0.1)), 0.0)
    thwack = glide(760, 400, 0.09, "tri") * dec(n_(0.09), 0.022)
    thwack += 0.3 * glide(760, 400, 0.09, "pulse", 0.125) * dec(n_(0.09), 0.012)
    place(b, 0.8 * lowpass(thwack, 0.4), 0.01)
    t = t_(0.15)
    glint = (np.sin(2 * np.pi * note("B6") * t) + 0.5 * np.sin(2 * np.pi * note("E7") * t)) * dec(n_(0.15), 0.045, attack=0.008)
    place(b, 0.22 * glint, 0.035)
    return lowpass(b, 0.5)


def arbalestrie_indra():
    """Balles d'Indra : le tir de base une quarte plus bas, coup d'enclume et queue de souffle."""
    rng = np.random.default_rng(46)
    d = 0.2
    b = mix(d)
    place(b, 0.9 * band(rng.uniform(-1, 1, n_(0.014)), 0.06, 0.5) * dec(n_(0.014), 0.004), 0.0)
    place(b, 0.5 * metal(1250, 0.07, 0.016, amps=(1, 0.5, 0.25, 0.1)), 0.0)
    thwack = glide(520, 230, 0.11, "tri") * dec(n_(0.11), 0.03)
    thwack += 0.35 * glide(520, 230, 0.11, "pulse", 0.125) * dec(n_(0.11), 0.014)
    place(b, 0.9 * lowpass(thwack, 0.35), 0.008)
    tail = band(rng.uniform(-1, 1, n_(0.15)), 0.02, 0.22) * env(n_(0.15), attack=0.01, decay=0.06, sustain=0.0, release=0.06)
    place(b, 0.45 * tail, 0.03)
    return lowpass(b, 0.45)


def arbalestrie_medeina():
    """Balles de Medeina : tir feutré, presque un souffle, deux notes douces qui montent."""
    rng = np.random.default_rng(47)
    d = 0.2
    b = mix(d)
    puff = band(rng.uniform(-1, 1, n_(0.1)), 0.05, 0.3) * env(n_(0.1), attack=0.012, decay=0.05, sustain=0.0, release=0.03)
    place(b, 0.8 * puff, 0.0)
    place(b, 0.35 * lowpass(glide(500, 380, 0.07, "tri") * dec(n_(0.07), 0.02), 0.3), 0.005)
    t = t_(0.13)
    leaf = (np.sin(2 * np.pi * note("E6") * t) + 0.6 * np.sin(2 * np.pi * note("A6") * t)) * dec(n_(0.13), 0.04, attack=0.015)
    place(b, 0.2 * leaf, 0.04)
    return lowpass(b, 0.35)


def arbalestrie_sigil():
    """Balles de Sigil : double clic sec (deux balles), timbre de pierre, sans scintillement."""
    rng = np.random.default_rng(48)
    d = 0.2
    b = mix(d)
    for at, gain in ((0.0, 1.0), (0.055, 0.8)):
        place(b, gain * 0.9 * band(rng.uniform(-1, 1, n_(0.01)), 0.15, 0.8) * dec(n_(0.01), 0.0025), at)
        place(b, gain * 0.4 * metal(3400, 0.03, 0.006, amps=(1, 0.3, 0.15, 0.05)), at)
        place(b, gain * 0.6 * lowpass(glide(820, 520, 0.05, "tri") * dec(n_(0.05), 0.012), 0.45), at + 0.006)
    return lowpass(b, 0.55)


def arbalestrie_aether():
    """Balles d'Aether : aspiration brève puis déclic, note tenue qui monte."""
    rng = np.random.default_rng(49)
    d = 0.2
    b = mix(d)
    suck = band(rng.uniform(-1, 1, n_(0.04)), 0.05, 0.4) * np.linspace(0.0, 1.0, n_(0.04)) ** 2
    place(b, 0.5 * suck, 0.0)
    place(b, 0.9 * band(rng.uniform(-1, 1, n_(0.012)), 0.1, 0.7) * dec(n_(0.012), 0.003), 0.04)
    place(b, 0.6 * lowpass(glide(700, 420, 0.07, "tri") * dec(n_(0.07), 0.02), 0.4), 0.045)
    rise = glide(note("E6"), note("B6"), 0.14, "tri") * env(n_(0.14), attack=0.02, decay=0.05, sustain=0.5, release=0.06)
    place(b, 0.3 * rise, 0.05)
    return lowpass(b, 0.5)


def flammes():
    d = 1.0
    t = t_(d)
    x = band(noise(d), 0.02, 0.18) * (0.75 + 0.25 * np.sin(2 * np.pi * 11 * t + 2 * np.sin(2 * np.pi * 3 * t)))
    x *= env(n_(d), attack=0.06, decay=0.2, sustain=0.7, release=0.25)
    crack = (RNG.uniform(0, 1, n_(d)) > 0.997) * RNG.uniform(-1, 1, n_(d))
    return 1.8 * x + 0.4 * lowpass(crack, 0.5)


def flammes_mort():
    d = 1.0
    b = mix(d)
    place(b, 0.9 * glide(160, 60, 0.5, "sin") * dec(n_(0.5), 0.12, attack=0.004), 0)
    place(b, 1.6 * band(noise(d), 0.01, 0.2) * dec(n_(d), 0.22, attack=0.004), 0)
    place(b, 0.3 * hp(noise(0.4), 0.4) * dec(n_(0.4), 0.06), 0)
    return lowpass(b, 0.35)


def charge():
    d = 0.5
    x = band(noise(d), 0.02, 0.3) * env(n_(d), attack=0.25, decay=0.05, sustain=0.6, release=0.08)
    hit = band(noise(0.1), 0.02, 0.2) * dec(n_(0.1), 0.02)
    b = mix(0.65)
    place(b, 1.3 * x, 0)
    place(b, 1.4 * hit, 0.46)
    place(b, 0.7 * glide(180, 90, 0.12, "sin") * dec(n_(0.12), 0.03), 0.46)
    return b


def sillon():
    d = 0.7
    t = t_(d)
    x = band(noise(d), 0.03, 0.25) * env(n_(d), attack=0.02, decay=0.25, sustain=0.2, release=0.2)
    lead = glide(700, 260, d, "pulse", 0.25) * dec(n_(d), 0.15)
    return 1.3 * x + 0.25 * lowpass(lead, 0.3) * (0.8 + 0.2 * np.sin(2 * np.pi * 20 * t))


def soin():
    b = mix(0.9)
    for i, n in enumerate(["A5", "C6", "E6", "A6"]):
        s = triangle(note(n), 0.35) * env(n_(0.35), attack=0.02, decay=0.1, sustain=0.2, release=0.2)
        place(b, 0.5 * s, i * 0.06)
    return echo(lowpass(b, 0.25), delay=0.1, fb=0.35, mix=0.35) * 0.7


def tourelle():
    b = mix(0.35)
    place(b, 0.6 * glide(1600, 420, 0.18, "pulse", 0.25) * dec(n_(0.18), 0.06), 0)
    place(b, 0.6 * band(noise(0.08), 0.05, 0.4) * dec(n_(0.08), 0.015), 0)
    return lowpass(b, 0.35)


def exile_blesse():
    b = mix(0.2)
    place(b, 0.7 * glide(420, 300, 0.12, "pulse", 0.5) * dec(n_(0.12), 0.05), 0)
    place(b, band(noise(0.05), 0.03, 0.3) * dec(n_(0.05), 0.01), 0)
    return lowpass(b, 0.25)


def exile_mort():
    b = mix(1.3)
    for i, n in enumerate(["E5", "C5", "A4"]):
        place(b, tone(n, 0.3, a=0.02, d=0.15, s=0.4, r=0.15, pul=0.1), i * 0.22)
    return echo(lowpass(b, 0.15), delay=0.18, fb=0.3, mix=0.3) * 0.8


def niveau():
    b = mix(1.0)
    for i, n in enumerate(["A5", "E6"]):
        place(b, tone(n, 0.5, a=0.01, d=0.2, s=0.3, r=0.3, pul=0.15), i * 0.1)
    place(b, 0.3 * hp(noise(0.5), 0.5) * dec(n_(0.5), 0.12), 0.1)
    return echo(lowpass(b, 0.22), delay=0.13, fb=0.3, mix=0.25)


# ---------------------------------------------------------------- Credo / Byrsa

def pilum():
    d = 0.3
    air = band(noise(d), 0.05, 0.35) * env(n_(d), attack=0.1, decay=0.05, sustain=0.4, release=0.1)
    b = mix(0.4)
    place(b, 0.9 * air, 0)
    place(b, 0.5 * metal(1500, 0.12, 0.02), 0.28)
    return b


def sort_lumiere():
    d = 0.45
    t = t_(d)
    x = glide(1800, 900, d, "tri") * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t)) * dec(n_(d), 0.14, attack=0.01)
    y = 0.4 * glide(1810, 905, d, "pulse", 0.125) * dec(n_(d), 0.1, attack=0.01)
    return lowpass(x + 0.5 * y, 0.35) * 0.6


def automate():
    b = mix(0.6)
    place(b, metal(420, 0.55, 0.12, ratios=(1.0, 1.51, 2.3, 3.7), amps=(0.8, 0.5, 0.3, 0.2)), 0)
    place(b, 1.2 * band(noise(0.1), 0.02, 0.25) * dec(n_(0.1), 0.02), 0)
    return lowpass(b, 0.4)


def bouclier_dore():
    b = mix(0.5)
    place(b, 0.7 * metal(1320, 0.45, 0.12), 0)
    place(b, 0.5 * band(noise(0.03), 0.1, 0.6) * dec(n_(0.03), 0.005), 0)
    return b


def fanatique():
    d = 0.35
    t = t_(d)
    v = glide(300, 230, d, "pulse", 0.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 26 * t))
    return lowpass(v, 0.12) * env(n_(d), attack=0.03, decay=0.1, sustain=0.5, release=0.1) * 0.8


def aberration():
    d = 0.5
    t = t_(d)
    g = band(noise(d), 0.01, 0.12) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 18 * t + 3 * np.sin(2 * np.pi * 4 * t))))
    v = 0.4 * lowpass(glide(240, 170, d, "pulse", 0.4), 0.1)
    return (2.0 * g + v) * env(n_(d), attack=0.04, decay=0.15, sustain=0.5, release=0.15)


def ennemi_mort():
    b = mix(0.4)
    place(b, 0.9 * band(noise(0.3), 0.02, 0.2) * dec(n_(0.3), 0.07), 0)
    place(b, 0.5 * glide(500, 200, 0.2, "tri") * dec(n_(0.2), 0.06), 0)
    return b


def strazhar():
    d = 1.6
    b = mix(d)
    # Cor de Byrsa : quarte descendante, timbre pulsation étroite très filtré, puis grondement de la course.
    for i, (n, l) in enumerate([("D5", 0.35), ("A4", 0.8)]):
        s = pulse(note(n), l, 0.2, vib=0.004 * note(n)) * env(n_(l), attack=0.04, decay=0.3, sustain=0.6, release=0.25)
        place(b, 0.5 * lowpass(s, 0.08), i * 0.36)
    t = t_(0.9)
    gallop = band(noise(0.9), 0.01, 0.12) * (np.sin(2 * np.pi * 7.5 * t) > 0.6) * env(n_(0.9), attack=0.2, decay=0.3, sustain=0.6, release=0.3)
    place(b, 1.4 * gallop, 0.6)
    return echo(b, delay=0.2, fb=0.25, mix=0.25)


def martyre():
    b = mix(2.6)
    for t0 in (0.0, 0.9):
        place(b, 0.7 * metal(660, 1.6, 0.6, ratios=(1.0, 2.0, 2.4, 3.0, 4.2), amps=(1, 0.6, 0.45, 0.3, 0.2)), t0)
    pad = triangle(note("A3"), 2.4) + triangle(note("E4"), 2.4)
    place(b, 0.25 * pad * env(n_(2.4), attack=0.4, decay=0.8, sustain=0.5, release=0.8), 0.1)
    return echo(lowpass(b, 0.3), delay=0.24, fb=0.3, mix=0.3) * 0.7


# ---------------------------------------------------------------- faune

def croc():
    b = mix(0.4)
    snap = band(noise(0.05), 0.05, 0.6) * dec(n_(0.05), 0.008)
    place(b, 1.4 * snap, 0.0)
    place(b, 0.7 * glide(150, 90, 0.15, "sin") * dec(n_(0.15), 0.05), 0.0)
    splash = band(noise(0.3), 0.06, 0.5) * env(n_(0.3), attack=0.02, decay=0.08, sustain=0.2, release=0.15)
    place(b, 0.5 * splash, 0.06)
    return b


def felin():
    d = 0.55
    t = t_(d)
    hiss = band(noise(d), 0.15, 0.7) * env(n_(d), attack=0.05, decay=0.2, sustain=0.4, release=0.15)
    growl = lowpass(glide(180, 140, d, "pulse", 0.3), 0.08) * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t))
    return hiss * 0.8 + 0.5 * growl * env(n_(d), attack=0.08, decay=0.2, sustain=0.5, release=0.15)


# ---------------------------------------------------------------- monde et ouverture

def portail():
    d = 1.8
    t = t_(d)
    b = mix(d)
    for f, ph in [(note("E5"), 0), (note("B5"), 1.3), (note("E6"), 2.1)]:
        s = np.sin(2 * np.pi * f * t + 0.8 * np.sin(2 * np.pi * 0.7 * t + ph))
        place(b, 0.25 * s, 0)
    sh = hp(noise(d), 0.5) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t))
    place(b, 0.15 * sh, 0)
    b *= env(n_(d), attack=0.6, decay=0.5, sustain=0.6, release=0.5)
    return echo(b, delay=0.15, fb=0.35, mix=0.3)


def expulsion():
    b = mix(0.9)
    place(b, 0.5 * glide(900, 250, 0.3, "tri") * dec(n_(0.3), 0.1), 0)
    place(b, 1.0 * band(noise(0.25), 0.02, 0.2) * dec(n_(0.25), 0.05), 0.3)
    place(b, 0.7 * glide(160, 90, 0.15, "sin") * dec(n_(0.15), 0.05), 0.3)
    return b


def ancre_trait():
    d = 2.2
    t = t_(d)
    hum = glide(220, 440, d, "tri") * 0.4 + 0.2 * glide(330, 660, d, "tri")
    zz = hp(noise(d), 0.4) * (RNG.uniform(0, 1, n_(d)) > 0.85) * 0.2
    x = (hum + zz) * env(n_(d), attack=0.3, decay=0.5, sustain=0.8, release=0.15)
    x *= 0.85 + 0.15 * np.sin(2 * np.pi * 12 * t)
    return lowpass(x, 0.25)


def capsule():
    b = mix(1.2)
    place(b, 0.5 * band(noise(0.06), 0.05, 0.5) * dec(n_(0.06), 0.01), 0)
    hum = (triangle(note("A4"), 1.0) + 0.5 * triangle(note("E5"), 1.0)) * env(n_(1.0), attack=0.25, decay=0.3, sustain=0.5, release=0.4)
    place(b, 0.4 * hum, 0.05)
    place(b, 0.4 * tone("A5", 0.5, a=0.02, d=0.2, s=0.3, r=0.3, pul=0.1), 0.35)
    return echo(lowpass(b, 0.22), delay=0.14, fb=0.3, mix=0.25)


def porte_barree():
    b = mix(0.5)
    for i in range(3):
        place(b, 0.9 * band(noise(0.07), 0.015, 0.15) * dec(n_(0.07), 0.018), 0.11 * i)
        place(b, 0.5 * glide(150, 110, 0.07, "sin") * dec(n_(0.07), 0.02), 0.11 * i)
    place(b, 0.4 * metal(700, 0.2, 0.05), 0.24)
    return b


def bouclier_forme():
    d = 2.0
    t = t_(d)
    b = mix(d)
    s = glide(300, 900, 1.4, "sin") * 0.35 + glide(452, 1356, 1.4, "sin") * 0.2
    place(b, s * env(n_(1.4), attack=0.3, decay=0.4, sustain=0.6, release=0.3), 0)
    tone_ = (np.sin(2 * np.pi * 880 * t_(0.8)) + 0.5 * np.sin(2 * np.pi * 1320 * t_(0.8))) * dec(n_(0.8), 0.3, attack=0.02)
    place(b, 0.4 * tone_, 1.2)
    b *= 0.85 + 0.15 * np.sin(2 * np.pi * 6 * t)
    return echo(b, delay=0.12, fb=0.3, mix=0.3)


def canon():
    b = mix(1.1)
    place(b, 1.4 * band(noise(0.3), 0.01, 0.15) * dec(n_(0.3), 0.06), 0)
    place(b, 0.8 * glide(140, 70, 0.25, "sin") * dec(n_(0.25), 0.07), 0)
    place(b, 0.4 * glide(1200, 600, 0.4, "tri") * env(n_(0.4), attack=0.05, decay=0.1, sustain=0.5, release=0.1) * 0.5, 0.15)
    # impact sur le bouclier : onde de verre
    place(b, 0.5 * metal(990, 0.5, 0.12, ratios=(1.0, 1.5, 2.7), amps=(1, 0.6, 0.3)), 0.58)
    place(b, 0.7 * band(noise(0.15), 0.03, 0.3) * dec(n_(0.15), 0.03), 0.58)
    return b


def onde():
    d = 2.6
    b = mix(d)
    t = t_(1.2)
    rise = glide(200, 1200, 1.2, "tri") * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t))
    place(b, 0.3 * rise * env(n_(1.2), attack=0.8, decay=0.3, sustain=0.6, release=0.05), 0)
    place(b, 1.6 * band(noise(1.4), 0.008, 0.15) * dec(n_(1.4), 0.35, attack=0.005), 1.2)
    place(b, 0.9 * glide(150, 50, 0.6, "sin") * dec(n_(0.6), 0.18), 1.2)
    place(b, 0.3 * hp(noise(0.8), 0.5) * dec(n_(0.8), 0.15), 1.2)
    return lowpass(b, 0.35)


def vague():
    b = mix(2.0)
    for i, (n, l) in enumerate([("A4", 0.3), ("A4", 0.15), ("E5", 1.1)]):
        s = pulse(note(n), l, 0.25, vib=0.004 * note(n)) * env(n_(l), attack=0.03, decay=0.2, sustain=0.6, release=0.2)
        place(b, 0.4 * lowpass(s, 0.07), [0, 0.32, 0.5][i])
    drum = band(noise(0.2), 0.01, 0.1) * dec(n_(0.2), 0.05)
    for t0 in (0.0, 0.5):
        place(b, 1.0 * drum, t0)
    return echo(b, delay=0.22, fb=0.3, mix=0.3)


def aube():
    d = 1.8
    b = mix(d)
    for i, n in enumerate(["E5", "A5", "B5", "E6"]):
        s = triangle(note(n), 1.0) * env(n_(1.0), attack=0.2, decay=0.4, sustain=0.3, release=0.4)
        place(b, 0.3 * s, i * 0.2)
    return echo(lowpass(b, 0.15), delay=0.2, fb=0.35, mix=0.35) * 0.8


def crepuscule():
    d = 2.0
    b = mix(d)
    for i, n in enumerate(["E5", "C5", "A4"]):
        s = triangle(note(n), 1.2) * env(n_(1.2), attack=0.25, decay=0.5, sustain=0.3, release=0.4)
        place(b, 0.3 * s, i * 0.3)
    t = t_(d)
    crick = hp(noise(d), 0.6) * (np.sin(2 * np.pi * 18 * t) > 0.8) * (np.sin(2 * np.pi * 0.8 * t) > 0) * 0.08
    return echo(lowpass(b, 0.13), delay=0.22, fb=0.35, mix=0.35) * 0.8 + crick


def quete():
    b = mix(1.1)
    place(b, tone("A5", 0.14, a=0.01, d=0.08, s=0.4), 0.0)
    place(b, tone("E5", 0.14, a=0.01, d=0.08, s=0.4), 0.12)
    place(b, tone("A5", 0.7, a=0.01, d=0.25, s=0.3, r=0.4, pul=0.1), 0.24)
    return echo(lowpass(b, 0.18), delay=0.15, fb=0.28, mix=0.25)


def defaite():
    b = mix(3.0)
    for i, n in enumerate(["E5", "D5", "C5"]):
        place(b, tone(n, 0.35, a=0.02, d=0.2, s=0.4, r=0.15, pul=0.1), i * 0.3)
    s = triangle(note("A4"), 1.8) + 0.4 * triangle(note("C5"), 1.8)
    place(b, 0.7 * s * env(n_(1.8), attack=0.05, decay=0.6, sustain=0.35, release=1.0), 0.9)
    place(b, 0.4 * triangle(note("A3"), 2.6) * env(n_(2.6), attack=0.05, decay=0.8, sustain=0.4, release=1.0), 0.0)
    return echo(lowpass(b, 0.14), delay=0.2, fb=0.3, mix=0.3) * 0.75


# ---------------------------------------------------------------- catalogue

# (fichier, fonction, catégorie, élément, déclencheur, description, volume conseillé en dB)
CATALOGUE = [
    ("victoire", victoire, "Référence", "Obtention (Arbalestrie, Combinaison)", "sim/capsule.gd · déjà en jeu",
     "Le son validé : la mineur, quinte à vide tenue. Sert d'étalon de ton pour tout le reste.", -8),

    ("ui_clic", ui_clic, "Interface", "Clic sur un bouton du HUD", "ui/hud · bouton pressé",
     "Une seule note aiguë très courte, filtrée. Doit disparaître sous le jeu.", -16),
    ("ui_selection", ui_selection, "Interface", "Sélection d'une unité ou d'un bâtiment", "ui/input · sélection",
     "Deux notes montantes en quinte, plus douces que le clic.", -14),
    ("ui_ordre", ui_ordre, "Interface", "Ordre de déplacement / d'attaque", "ui/input · clic droit",
     "Petit glissement descendant, comme un pointeur qui se pose.", -16),
    ("ui_refus", ui_refus, "Interface", "Action refusée (ressources, emplacement)", "placeables.gd / building.gd · « why »",
     "Seconde mineure descendante : on comprend « non » sans buzzer.", -12),
    ("ui_banniere", ui_banniere, "Interface", "Ouverture de la bannière bleue", "ui/banner · SnesBanner",
     "Carillon de quinte qui s'éteint en écho. Annonce sans interrompre.", -14),
    ("ui_texte", ui_texte, "Interface", "Défilement du texte de dialogue", "ui/dialogue · par mot ou groupe",
     "Trois blips à pulsation étroite. À jouer tous les 3 ou 4 caractères, pas à chaque lettre.", -22),
    ("ui_inventaire", ui_inventaire, "Interface", "Ouverture de l'inventaire / d'un coffre", "Events.inventory_requested",
     "Froissement de tissu court et une note sourde.", -14),

    ("bat_pose", bat_pose, "Base", "Pose d'un bâtiment (chantier)", "building.gd · placement validé",
     "Bruit sourd de pierre posée, sans basse lourde.", -10),
    ("bat_chantier", bat_chantier, "Base", "Construction en cours", "building.gd · boucle pendant « time »",
     "Trois coups de marteau métalliques. Se joue en boucle espacée, à faible volume.", -18),
    ("bat_termine", bat_termine, "Base", "Bâtiment terminé", "building.gd · fin de construction",
     "Quarte montante mi–la, la tenue. Plus courte et plus discrète que « victoire ».", -10),
    ("priere", priere, "Base", "Prière d'un adepte (ressource gagnée)", "production.gd · gain de ressource",
     "Deux tintements très aigus et feutrés. Fréquent : il doit rester presque inaudible.", -24),
    ("recherche", recherche, "Base", "Recherche terminée (Bibliothèque…)", "Catalog.RESEARCH · achèvement",
     "Arpège mi mineur mi–sol–si puis mi aigu. Cousin de « victoire ».", -9),
    ("forge", forge, "Base", "Fabrication à la Forge / au Creuset", "production.gd · recette terminée",
     "Un coup d'enclume suivi d'un souffle de trempe.", -12),
    ("coffre", coffre, "Base", "Dépôt / retrait dans un coffre", "item_storage.gd · transfert",
     "Loquet, couvercle de bois, loquet.", -14),
    ("minage", minage, "Base", "Mineur au filon", "production.gd · coup de pioche",
     "Deux coups de pioche sur roche, éclats de gravier.", -18),
    ("objet_pose", objet_pose, "Base", "Pose d'une barricade / poste de tir", "placeables.gd · place()",
     "Bois et terre tassés, bref.", -12),
    ("chausse_trapes", chausse_trapes, "Base", "Chausse-trapes posées ou piétinées", "placeables.gd · caltrops",
     "Petits cliquetis de fer éparpillés.", -14),
    ("adepte_arrive", adepte_arrive, "Base", "Nouvel adepte / unité formée", "Caserne, Puits des Âmes · formation",
     "Glissando doux puis une note : quelqu'un rejoint les Exilés.", -12),

    ("epee", epee, "Exilés", "Frappe d'épée (Lame, Ingénieur, Templier)", "combat.gd · coup de mêlée",
     "Fouet d'air puis impact mat. Pas de « clang » : sinon trop chargé en mêlée.", -14),
    ("moulinet", moulinet, "Exilés", "Moulinet d'orage (Lame, 3e frappe)", "combat.gd · MOULINET",
     "Tourbillon d'air pulsé terminé par une crépitation électrique.", -11),
    ("arc", arc, "Exilés", "Tir à l'arc (archer, garde, Indra)", "combat.gd · ARROW_ROLES",
     "Corde qui vibre et souffle de la flèche.", -15),
    ("fleche_impact", fleche_impact, "Exilés", "Flèche qui touche", "combat.gd · impact projectile",
     "Toc sec et court. Partagé avec les flèches ennemies.", -18),
    ("flammes", flammes, "Exilés", "Lance-flammes (en continu)", "combat.gd · flammes « continuous »",
     "Souffle grave modulé, quelques crépitements. Boucle tant que l'adepte tire.", -16),
    ("flammes_mort", flammes_mort, "Exilés", "Explosion à la mort du lance-flammes", "Catalog.FLAME_DEATH",
     "Détonation étouffée et bouffée de feu.", -9),
    ("charge", charge, "Exilés", "Charge (du Lac, au contact)", "Catalog.CHARGE",
     "Ruée qui monte puis heurt.", -11),
    ("sillon", sillon, "Exilés", "Sillon de feu", "Catalog.SILLON",
     "Trait de feu qui se dépose au sol en descendant.", -12),
    ("soin", soin, "Exilés", "Soin (guérisseur)", "combat.gd · healer",
     "Arpège la mineur aigu, très doux, en écho.", -15),
    ("tourelle", tourelle, "Exilés", "Tir de tourelle", "Catalog.TURRET · bolt",
     "Zap descendant à pulsation, plus mécanique que magique.", -14),
    ("exile_blesse", exile_blesse, "Exilés", "Un Exilé est touché", "combat.gd · dégâts sur unité alliée",
     "Petit son descendant étouffé. Limité à un toutes les 0,3 s.", -18),
    ("exile_mort", exile_mort, "Exilés", "Mort d'un Exilé", "unit.gd · mort",
     "Trois notes descendantes mi–do–la : sobre, sans drame.", -10),
    ("niveau", niveau, "Exilés", "Montée de niveau (XP)", "Catalog.KILL_XP · palier",
     "Quinte la–mi et poussière brillante.", -11),

    ("pilum", pilum, "Credo et Byrsa", "Pilum lancé (soldat du Credo)", "combat.gd · ENEMY_PILUM",
     "Sifflement d'air lourd puis pointe métallique.", -14),
    ("sort_lumiere", sort_lumiere, "Credo et Byrsa", "Sort de lumière (Thuriféraire)", "combat.gd · ENEMY_STAFF",
     "Note vitreuse qui tremble et descend : lumière souillée.", -14),
    ("automate", automate, "Credo et Byrsa", "Coup de l'automate doré", "combat.gd · brute",
     "Clang lourd d'or fêlé (partiels inharmoniques), pas de sub-basse.", -12),
    ("bouclier_dore", bouclier_dore, "Credo et Byrsa", "Coup bloqué par le bouclier doré", "combat.gd · armure absorbe",
     "« Ting » métallique clair. Signale que l'attaque est inefficace.", -14),
    ("fanatique", fanatique, "Credo et Byrsa", "Fanatique / soldat qui attaque", "combat.gd · creep, scout",
     "Râle bref, voix filtrée à pulsation.", -18),
    ("aberration", aberration, "Credo et Byrsa", "Cri d'aberration du Dévoreur", "simulation.gd · apparition de portail",
     "Gargouillis humide haché. Rare, pour qu'il reste dérangeant.", -14),
    ("ennemi_mort", ennemi_mort, "Credo et Byrsa", "Mort d'un ennemi", "enemy.gd · mort",
     "Bouffée sourde et petite chute. Très fréquent : volume bas.", -18),
    ("strazhar", strazhar, "Credo et Byrsa", "Arrivée du Strazhar", "enemy_tactics.gd · champion entre en jeu",
     "Cor de Byrsa ré–la puis galop de la ruée.", -8),
    ("martyre", martyre, "Credo et Byrsa", "Apparition de la Martyre", "martyre.gd · entrée en combat singulier",
     "Deux coups de cloche d'or sur une quinte à vide.", -8),

    ("croc", croc, "Faune", "Crocodile qui happe", "wildlife.gd · croc",
     "Claquement de mâchoire et éclaboussure.", -13),
    ("felin", felin, "Faune", "Félin qui feule", "wildlife.gd · feline (aggro)",
     "Feulement soufflé sur un grondement grave modéré.", -14),

    ("portail", portail, "Monde et ouverture", "Portail d'argent (arrivée J1)", "opening.gd · ARR_OPEN",
     "Nappe de trois sinus qui ondulent et scintillent.", -10),
    ("expulsion", expulsion, "Monde et ouverture", "L'Ingénieur expulsé, tombe à genoux", "opening.gd · ARR_EJECT",
     "Chute en glissando puis impact au sol.", -10),
    ("porte_barree", porte_barree, "Monde et ouverture", "Porte sud barrée", "opening.gd · DOOR_LINE",
     "Trois coups sourds contre le bois, verrou qui cliquette.", -10),
    ("ancre_trait", ancre_trait, "Monde et ouverture", "Réveil de l'Ancre : le trait court vers la capsule", "opening.gd · « link » (LINK_LEN 2,2 s)",
     "Bourdonnement qui monte d'une octave sur la durée exacte du trait.", -12),
    ("capsule", capsule, "Monde et ouverture", "La capsule s'allume", "opening.gd · « awake »",
     "Déclic, ronronnement la–mi, une note de confirmation.", -11),
    ("bouclier_forme", bouclier_forme, "Monde et ouverture", "Formation du bouclier d'énergie", "opening.gd · « shield_form » (ANCHOR_SEQUENCE)",
     "Double glissando montant puis tenue cristalline. Pour la suite mise de côté.", -11),
    ("canon", canon, "Monde et ouverture", "Canon de Byrsa et impact sur le bouclier", "opening.gd · « siege » (ANCHOR_SEQUENCE)",
     "Détonation, sifflement, puis onde de verre à l'impact.", -10),
    ("onde", onde, "Monde et ouverture", "Explosion : onde rose qui souffle le mur", "opening.gd · « blast » (ANCHOR_SEQUENCE)",
     "Montée tremblée puis souffle long. Seul son vraiment ample de la liste.", -7),
    ("vague", vague, "Monde et ouverture", "Début d'un assaut", "simulation.gd · lancement de vague",
     "Cor la–la–mi et deux coups de tambour.", -9),
    ("aube", aube, "Monde et ouverture", "Lever du jour", "jour/nuit · aube",
     "Accord suspendu qui s'ouvre, très lent.", -14),
    ("crepuscule", crepuscule, "Monde et ouverture", "Tombée de la nuit (félins plus agressifs)", "jour/nuit · crépuscule",
     "Descente mi–do–la, quelques insectes.", -14),
    ("quete", quete, "Monde et ouverture", "Quête accomplie", "sim/quests.gd · condition remplie",
     "La–mi–la : retour à la tonique. Plus bref que « victoire ».", -10),
    ("defaite", defaite, "Monde et ouverture", "Défaite (Ancre détruite)", "Events.game_over(false)",
     "Mi–ré–do vers un la mineur tenu. Grave modéré, pas de glas.", -6),
    ("arbalestrie", arbalestrie, "Exilés", "Tir de l'Arbalestrie (Ingénieur)", "combat.gd · gear_attack, arme à mana",
     "Déclic, corde sèche, petit scintillement d'énergie. 0,2 s : fini avant le tir suivant (cadence 0,25 s).", -15),
    ("arbalestrie_indra", arbalestrie_indra, "Exilés", "Tir de l'Arbalestrie, balles d'Indra", "combat.gd · gear_attack, data/ammo.gd « sfx »",
     "Le tir de base plus grave, coup d'enclume et queue de souffle.", -13),
    ("arbalestrie_medeina", arbalestrie_medeina, "Exilés", "Tir de l'Arbalestrie, balles de Medeina", "combat.gd · gear_attack, data/ammo.gd « sfx »",
     "Tir feutré, presque un souffle, deux notes douces.", -17),
    ("arbalestrie_sigil", arbalestrie_sigil, "Exilés", "Tir de l'Arbalestrie, balles de Sigil", "combat.gd · gear_attack, data/ammo.gd « sfx »",
     "Double clic sec, timbre de pierre.", -15),
    ("arbalestrie_aether", arbalestrie_aether, "Exilés", "Tir de l'Arbalestrie, balles d'Aether", "combat.gd · gear_attack, data/ammo.gd « sfx »",
     "Aspiration brève, déclic, note tenue qui monte.", -15),
]


def normalize(x):
    """Crête à 0,7 : le volume en jeu se règle par le dB du catalogue (ui/audio/sfx_player.gd)."""
    peak = np.max(np.abs(x)) or 1.0
    return np.clip(x / peak * 0.7, -1.0, 1.0)


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    x = normalize(x)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    return len(x) / SR


if __name__ == "__main__":
    meta = []
    for name, fn, cat, elem, hook, desc, db in CATALOGUE:
        dur = write(name, fn())
        meta.append({"id": name, "cat": cat, "elem": elem, "hook": hook, "desc": desc, "db": db, "dur": round(dur, 2)})
        print(f"{name:16s} {dur:.2f}s")
    (OUT / "sons.js").write_text("window.SONS = " + json.dumps(meta, ensure_ascii=False, indent=1) + ";\n", encoding="utf-8")
    print(len(meta), "sons →", OUT)
