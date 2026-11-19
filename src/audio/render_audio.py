"""Render the original Asfalto de Troca score and game sounds.

Run with Python 3, NumPy and FFmpeg from any directory. The game runtime uses
only the rendered imports in assets/audio.
"""

from pathlib import Path
from subprocess import run
import wave

import numpy as np


DEST = Path(__file__).resolve().parents[2] / "assets" / "audio"
TAU = np.pi * 2.0
MUSIC_RATE = 32_000
SFX_RATE = 24_000


def times(seconds, rate):
    return np.arange(round(seconds * rate)) / rate


def tone(note, t):
    return TAU * 440.0 * 2.0 ** ((note - 69) / 12.0) * t


def envelope(t, attack, release):
    return np.minimum(1.0, t / attack) * np.minimum(1.0, (t[-1] - t) / release)


def noise(size, rate, lo, hi, rng):
    frequencies = np.fft.rfftfreq(size, 1.0 / rate)
    spectrum = np.fft.rfft(rng.normal(0.0, 1.0, size))
    if lo > 0.0:
        spectrum *= 1.0 - np.exp(-((frequencies / lo) ** 2))
    spectrum *= np.exp(-((frequencies / hi) ** 4))
    filtered = np.fft.irfft(spectrum, n=size)
    return filtered / np.std(filtered)


def circular_mix(buffer, signal, offset, gain, pan=0.0):
    offset %= len(buffer)
    position = (pan + 1.0) * np.pi * 0.25
    sample = signal[:, None] * gain * np.array([np.cos(position), np.sin(position)])
    first = min(len(sample), len(buffer) - offset)
    buffer[offset:offset + first] += sample[:first]
    if len(sample) > first:
        buffer[:len(sample) - first] += sample[first:]


def kick(tempo, dry):
    t = times(0.34 if dry else 0.43, MUSIC_RATE)
    phase = TAU * (43.0 * t + 2.65 * (1.0 - np.exp(-t * 31.0)))
    voice = np.tanh(1.5 * np.sin(phase))
    return voice * np.exp(-t * (7.7 + tempo * 0.021)) * envelope(t, 0.002, 0.025)


def snare(rng):
    t = times(0.25, MUSIC_RATE)
    thud = np.sin(TAU * (177.0 * t + 1.1 * (1.0 - np.exp(-28.0 * t)))) * np.exp(-t * 40.0)
    fizz = noise(len(t), MUSIC_RATE, 850.0, 8200.0, rng) * np.exp(-t * 20.0)
    clap = np.zeros_like(t)
    for delay in (0.001, 0.014, 0.024):
        elapsed = np.maximum(t - delay, 0.0)
        clap += (t >= delay) * np.minimum(1.0, elapsed * 950.0) * np.exp(-elapsed * 80.0)
    return (0.51 * thud + 0.28 * fizz * (0.77 + clap)) * envelope(t, 0.002, 0.018)


def hat(rng, opened):
    t = times(0.24 if opened else 0.082, MUSIC_RATE)
    metal = sum(np.sin(TAU * f * t) for f in (3721.0, 4517.0, 5107.0, 7191.0))
    hiss = noise(len(t), MUSIC_RATE, 3300.0, 12_800.0, rng)
    return (0.12 * metal + 0.38 * hiss) * np.exp(-t * (13.0 if opened else 51.0)) * envelope(t, 0.001, 0.015)


def bass(note, seconds, sharp):
    t = times(seconds, MUSIC_RATE)
    phase = tone(note, t)
    body = np.sin(phase) + 0.34 * np.sin(2.0 * phase) + 0.13 * np.sin(3.0 * phase)
    growl = np.sin(phase + 0.61 * np.sin(2.0 * phase)) * np.exp(-t * 3.4)
    return np.tanh((body + (0.66 if sharp else 0.24) * growl) * 0.91) * envelope(t, 0.012, min(0.09, seconds * 0.33))


def pad(note, seconds, side):
    t = times(seconds, MUSIC_RATE)
    phase = tone(note, t)
    slow = 0.19 * np.sin(TAU * 0.51 * t + side)
    voice = np.sin(phase + slow) + 0.25 * np.sin(2.0 * phase + 0.48 * np.sin(TAU * 0.37 * t + side))
    voice += 0.46 * np.sin(phase * (1.0 + 0.0013 * side)) + 0.09 * np.sin(3.0 * phase)
    return voice * envelope(t, 0.3, 0.72) * (0.85 + 0.15 * np.sin(TAU * 0.83 * t + side))


def lead(note, seconds, bright):
    t = times(seconds, MUSIC_RATE)
    phase = tone(note, t)
    modulation = (0.73 if bright else 1.24) * np.exp(-t * 4.9) * np.sin(phase * (2.0 if bright else 3.0))
    voice = np.sin(phase + modulation) + 0.24 * np.sin(2.0 * phase + modulation * 0.2)
    return voice * np.exp(-t * (4.0 if bright else 5.0)) * envelope(t, 0.005, 0.11)


SCORE_PROFILES = {
    "garage": {
        "kick": ((0.0, 2.0, 2.75), (0.0, 1.5, 2.75), (0.0, 1.75, 3.0), (0.0, 2.0, 3.5)),
        "bass": ((0.0, 1.24, 0), (1.5, 0.45, 0), (2.0, 0.68, 0), (3.0, 0.73, 7)),
    },
    "meet": {
        "kick": ((0.0, 1.75, 2.5), (0.0, 0.75, 2.75), (0.0, 1.5, 2.5), (0.0, 2.0, 3.5)),
        "bass": ((0.0, 0.7, 0), (0.75, 0.44, 0), (1.75, 0.55, 0), (2.5, 0.71, 7), (3.5, 0.43, 12)),
    },
    "race": {
        "kick": ((0.0, 0.75, 2.5), (0.0, 1.75, 2.5), (0.0, 0.75, 2.0, 2.75), (0.0, 1.5, 3.5)),
        "bass": ((0.0, 0.62, 0), (0.75, 0.66, 0), (1.5, 0.43, 12), (2.0, 0.65, 0), (2.75, 0.42, 0), (3.25, 0.62, 7)),
    },
}


def score(name, bpm, tonic, progression, melody, profile):
    rng = np.random.default_rng({"garage": 6103, "meet": 8021, "race": 9007}[profile])
    beat = 60.0 / bpm
    bars = 16
    mix = np.zeros((round(bars * beat * 4.0 * MUSIC_RATE), 2))
    pulse = kick(bpm, profile == "race")
    clap = snare(rng)
    closed = hat(rng, False)
    opened = hat(rng, True)
    pattern = SCORE_PROFILES[profile]

    def add(sample, when, gain, pan=0.0):
        circular_mix(mix, sample, round(when * beat * MUSIC_RATE), gain, pan)

    for bar in range(bars):
        start = bar * 4
        root, chord = progression[(bar // 2) % len(progression)]
        for i, step in enumerate(pattern["kick"][bar % 4]):
            add(pulse, start + step, 0.31 if i == 0 else 0.24)
        for step in (1.0, 3.0):
            add(clap, start + step, 0.18 if profile == "race" else 0.11, -0.07)
        if bar % 4 == 3:
            add(clap, start + 3.75, 0.058, 0.17)
        for i in range(8):
            offset = (0.02 if profile == "race" else 0.04) if i % 2 else 0.0
            cymbal = opened if i in (3, 7) and bar % 2 == 0 else closed
            add(cymbal, start + i * 0.5 + offset, (0.065 if i % 2 else 0.035), 0.33 if i % 2 else -0.23)
        if profile != "garage" and bar % 2 == 1:
            for step in (2.25, 3.25, 3.5, 3.75):
                add(closed, start + step, 0.045, float(rng.uniform(-0.5, 0.5)))

        for step, length, interval in pattern["bass"]:
            add(bass(tonic + root + interval, length * beat, profile != "garage"), start + step, 0.18)

        if bar % 2 == 0:
            for index, degree in enumerate(chord):
                pan = (-0.64, 0.52, -0.28, 0.31)[index]
                note = tonic + 24 + root + degree
                add(pad(note, beat * 8.8, 1.0 + index), start - 0.16, 0.047, pan)
                add(pad(note, beat * 8.8, -1.0 - index), start - 0.25, 0.034, -pan)

        if bar % 4 in (1, 3) or (bar >= 8 and profile != "garage"):
            for index, (step, degree) in enumerate(melody):
                note = tonic + 36 + degree + (12 if bar in (11, 15) and index == 2 else 0)
                voice = lead(note, beat * 1.35, profile != "garage")
                add(voice, start + step, 0.077 if bar >= 8 else 0.057, -0.18)
                add(voice, start + step + 0.75, 0.033, 0.53)
                add(voice, start + step + 1.5, 0.015, -0.54)

    # The closed-loop ambience is made from filtered noise and periodic motor hum.
    t = np.arange(len(mix)) / MUSIC_RATE
    duration = len(mix) / MUSIC_RATE
    crest = 0.006 * noise(len(mix), MUSIC_RATE, 65.0, 420.0, rng)
    hum = 0.011 * np.sin(TAU * round(60.0 * duration) / duration * t)
    mix[:, 0] += crest + hum
    mix[:, 1] += np.roll(crest, 443) + 0.9 * hum
    mix = np.tanh(mix * 1.37)
    write_ogg(name, mix)


def write_wav(path, signal, rate):
    samples = np.round(np.clip(signal, -0.999, 0.999) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as track:
        track.setnchannels(1 if signal.ndim == 1 else signal.shape[1])
        track.setsampwidth(2)
        track.setframerate(rate)
        track.writeframes(samples.tobytes())


def write_ogg(name, signal):
    wav = DEST / (name + ".wav")
    write_wav(wav, signal, MUSIC_RATE)
    try:
        run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
             "-codec:a", "libvorbis", "-q:a", "4", str(DEST / (name + ".ogg"))],
            check=True,
        )
    finally:
        wav.unlink()


def engine_loops():
    rng = np.random.default_rng(2174)
    t = times(1.0, SFX_RATE)
    phase = TAU * 84.0 * t + 0.032 * np.sin(TAU * 7.0 * t)
    fundamental = np.sin(phase)
    combustion = np.sin(2.0 * phase + 0.35) + 0.31 * np.sin(3.0 * phase + 1.25)
    overtones = np.sin(4.0 * phase + 2.1) + 0.60 * np.sin(6.0 * phase + 0.5)
    turbulence = noise(len(t), SFX_RATE, 170.0, 1100.0, rng)
    periodic_load = 0.9 + 0.07 * np.sin(TAU * 7.0 * t) + 0.03 * np.sin(TAU * 11.0 * t)
    idle = np.tanh(fundamental * 0.61 + combustion * 0.36 + overtones * 0.13 + turbulence * 0.10)
    loaded = np.tanh(fundamental * 0.40 + combustion * 0.43 + overtones * 0.28 + turbulence * 0.20)
    whistle = 0.12 * np.sin(9.0 * phase + 0.65 * np.sin(phase)) + 0.085 * np.sin(11.0 * phase)
    write_wav(DEST / "motor_baixo.wav", idle * periodic_load * 0.69, SFX_RATE)
    write_wav(DEST / "motor_carga.wav", (loaded * periodic_load + whistle) * 0.65, SFX_RATE)

    rotor = noise(len(t), SFX_RATE, 450.0, 5600.0, rng) * (0.92 + 0.08 * np.sin(TAU * 8.0 * t))
    squeal = np.sin(TAU * 1029.0 * t + 0.6 * np.sin(TAU * 13.0 * t) + 0.42 * np.sin(TAU * 23.0 * t))
    squeal += 0.6 * np.sin(TAU * 1412.0 * t + 0.8 * np.sin(TAU * 17.0 * t))
    tires = np.tanh(rotor * 0.23 + squeal * 0.21) * 0.73
    wind = np.tanh(noise(len(t), SFX_RATE, 170.0, 3300.0, rng) * 0.26) * 0.65
    write_wav(DEST / "pneu.wav", tires, SFX_RATE)
    write_wav(DEST / "vento.wav", wind, SFX_RATE)


def cue(notes, duration, spacing, brightness):
    track = np.zeros(round((duration + spacing * (len(notes) - 1)) * SFX_RATE))
    for i, note in enumerate(notes):
        t = times(duration, SFX_RATE)
        phase = tone(note, t)
        body = np.sin(phase) + 0.38 * brightness * np.sin(2.0 * phase + 0.19 * np.sin(phase))
        body += 0.19 * np.sin(3.0 * phase) * np.exp(-t * 47.0)
        env = envelope(t, 0.004, duration * 0.63) * np.exp(-t * 3.0)
        offset = round(i * spacing * SFX_RATE)
        track[offset:offset + len(t)] += body * env * 0.40
    return track


def effects():
    for name, notes, duration, spacing, bright in (
        ("selecao", (77,), 0.09, 0, 0.40),
        ("confirma", (65, 72), 0.19, 0.065, 0.70),
        ("erro", (54, 48), 0.18, 0.070, 0.30),
        ("preparar", (69,), 0.20, 0, 0.90),
        ("largada", (81, 88), 0.22, 0.055, 1.00),
        ("vitoria", (60, 67, 72, 76), 0.46, 0.125, 0.70),
        ("derrota", (65, 62, 57), 0.36, 0.115, 0.50),
    ):
        write_wav(DEST / (name + ".wav"), cue(notes, duration, spacing, bright), SFX_RATE)

    rng = np.random.default_rng(7991)
    t = times(0.32, SFX_RATE)
    boom = np.sin(TAU * (60.0 * t + 2.9 * (1.0 - np.exp(-34.0 * t)))) * np.exp(-t * 15.0)
    crunch = noise(len(t), SFX_RATE, 120.0, 3300.0, rng) * np.exp(-t * 28.0)
    strike = np.sin(TAU * 541.0 * t) * np.exp(-t * 42.0)
    impact = np.tanh(0.54 * boom + 0.55 * crunch + 0.17 * strike) * envelope(t, 0.002, 0.045)
    write_wav(DEST / "impacto.wav", impact, SFX_RATE)

    t = times(0.12, SFX_RATE)
    snap = noise(len(t), SFX_RATE, 210.0, 4200.0, rng) * np.exp(-t * 43.0)
    click = np.sin(TAU * 179.0 * t) * np.exp(-t * 29.0)
    write_wav(DEST / "marcha.wav", (0.41 * click + 0.28 * snap) * envelope(t, 0.002, 0.031), SFX_RATE)


def render():
    DEST.mkdir(parents=True, exist_ok=True)
    minor = (0, 3, 7, 14)
    major = (0, 4, 7, 11)
    score("oficina_0613", 79, 36, ((0, minor), (-5, major), (-4, major), (2, minor)),
          ((0.5, 7), (1.75, 10), (2.5, 14), (3.25, 12)), "garage")
    score("sob_o_viaduto", 103, 34, ((0, minor), (3, major), (1, major), (0, (0, 3, 7, 10))),
          ((0.0, 7), (0.75, 8), (1.75, 10), (3.0, 3)), "meet")
    score("faixa_de_corte", 136, 33, ((0, minor), (0, (0, 3, 10, 14)), (-2, major), (-4, major)),
          ((0.5, 12), (1.5, 7), (2.25, 10), (3.25, 14)), "race")
    engine_loops()
    effects()


if __name__ == "__main__":
    render()
