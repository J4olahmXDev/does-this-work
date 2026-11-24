"""Synthesize original loop ideas and nonverbal voices for the v0.5 review."""
import math
import random
import wave
from array import array
from pathlib import Path

root = Path(__file__).resolve().parent.parent / 'Resources' / 'Audio'
rate = 32000
tau = 2 * math.pi
rng = random.Random(5024)

# Tempo and voicings vary by stage. The same beat grid supports both arrangements.
tracks = [
    (112, [(48, 55, 60, 64, 69), (45, 52, 60, 64, 67), (41, 48, 57, 60, 64), (43, 50, 57, 62, 67)],
     [76, 79, 81, 79, 76, 72, 74, 76], "wood"),
    (116, [(50, 57, 62, 65, 69), (43, 50, 58, 62, 65), (48, 55, 60, 64, 67), (45, 52, 57, 60, 64)],
     [77, 74, 72, 74, 76, 79, 77, 76], "keys"),
    (108, [(53, 60, 65, 69, 72), (50, 57, 62, 65, 69), (46, 53, 62, 65, 69), (48, 55, 62, 65, 67)],
     [81, 79, 77, 76, 77, 74, 76, 79], "bell"),
    (118, [(45, 52, 57, 61, 66), (42, 49, 57, 61, 64), (47, 54, 57, 62, 66), (40, 47, 56, 59, 64)],
     [78, 76, 73, 76, 74, 73, 71, 76], "pluck"),
]
profiles = [(146, 280), (121, 315), (128, 370), (155, 420),
            (107, 310), (164, 450), (112, 260), (137, 350)]


def buffer(seconds):
    return array('f', [0]) * int(seconds * rate)


def add_note(left, right, start, duration, midi, level, instrument, pan=0):
    first = round(start * rate)
    count = round(duration * rate)
    freq = 440 * 2 ** ((midi - 69) / 12)
    harmonics, decay = {
        "wood": ((1, 0.32, 0.07, 0.035), 4.4),
        "keys": ((1, 0.25, 0.10, 0.06), 3.9),
        "bell": ((1, 0.10, 0.23, 0.018), 4.7),
        "pluck": ((1, 0.42, 0.12, 0.06), 5.6),
        "bass": ((1, 0.17, 0.03, 0), 3.4),
    }[instrument]
    for i in range(count):
        pos = first + i
        if pos >= len(left):
            break
        t = i / rate
        phase = tau * freq * t
        attack = min(t / 0.013, 1)
        release = min((duration - t) / 0.047, 1)
        amp = level * attack * release * math.exp(-decay * t)
        pure = sum(amount * math.sin(phase * order) for order, amount in enumerate(harmonics, 1))
        left[pos] += pure * amp * (1 - pan)
        right[pos] += pure * amp * (1 + pan)


def percussion(left, right, start, strong=False):
    first = round(start * rate)
    for i in range(int(0.082 * rate)):
        pos = first + i
        if pos >= len(left):
            break
        t = i / rate
        envelope = min(t / .004, 1) * math.exp(-t * (54 if strong else 80))
        thump = math.sin(tau * 74 * t) * 0.051 if strong else 0
        noise = rng.uniform(-1, 1) * (.014 if strong else .023)
        left[pos] += (thump + noise) * envelope
        right[pos] += (thump + noise * .78) * envelope


def music(index, length, layer=False):
    bpm, chords, motif, instrument = tracks[index]
    beat = 60 / bpm
    left, right = buffer(length), buffer(length)
    for bar in range(math.ceil(length / (beat * 4))):
        bar_start = bar * 4 * beat
        chord = chords[bar % 4]
        if layer:
            for offset, pitch in [(1.5, chord[2] + 12), (3.5, chord[3] + 12)]:
                add_note(left, right, bar_start + offset * beat, .39 * beat, pitch, .059, "bell", -.16)
            continue
        for offset in (0, 2):
            add_note(left, right, bar_start + offset * beat, 0.81 * beat, chord[offset // 2], .137, "bass")
        for offset in range(4):
            percussion(left, right, bar_start + offset * beat, offset % 2 == 0)
        for offset, voice in [(0, 2), (1, 3), (2, 4), (3, 3)]:
            add_note(left, right, bar_start + offset * beat, .91 * beat, chord[voice], .083, instrument, -.24)
        for offset, voice in [(0, 2), (2, 4)]:
            add_note(left, right, bar_start + offset * beat, 1.85 * beat, chord[voice], .034, "keys", .28)
        for j, offset in enumerate((0.5, 1.5, 2.5, 3.0) if index % 2 == 0 else (0, 1.5, 2, 3.5)):
            note = motif[(bar * 2 + j) % len(motif)]
            add_note(left, right, bar_start + offset * beat, .59 * beat, note, .10, instrument, .21)
    return left, right


def voice(left, right, start, actor, line, pan=0):
    base, formant = profiles[actor]
    local = random.Random(actor * 101 + line * 7)
    time = start + .18
    gestures = [1.02, 1.1, 0.99, 1.14, 1.02, .91]
    if line == 1:
        gestures = [1.03, .95, 1.07, 1.13, 1.09, .97, .86]
    for j, contour in enumerate(gestures):
        duration = local.uniform(.095, .18)
        at = round(time * rate)
        phase = 0
        level = local.uniform(.10, .145)
        for i in range(round(rate * duration)):
            if at + i >= len(left):
                return
            t = i / rate
            ratio = t / duration
            pitch = base * contour * (1 + .055 * math.sin(ratio * math.pi) - .045 * ratio)
            phase += tau * pitch / rate
            shape = min(t / .020, 1) * (1 - ratio) ** .8
            tone = 0
            for order in range(1, 7):
                frequency = pitch * order
                weight = .87 * math.exp(-((frequency - formant) / 260) ** 2) / order ** .55
                tone += math.sin(phase * order) * weight
            signal = level * shape * (tone + .022 * local.uniform(-1, 1))
            left[at+i] += signal * (1 - pan)
            right[at+i] += signal * (1 + pan)
        time += duration + (.105 if j == 2 else local.uniform(.030, .068))


def write(name, left, right, volume=1, fades=(.025, .14)):
    frames = array('h')
    size = len(left)
    for i, (l, r) in enumerate(zip(left, right)):
        gain = volume * min(1, i / (fades[0] * rate), (size - i) / (fades[1] * rate))
        for sample in [l, r]:
            frames.append(round(32767 * max(-1, min(1, sample * gain))))
    with wave.open(str(root / name), 'wb') as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(rate)
        file.writeframes(frames.tobytes())



if __name__ == '__main__':
    for stage, track in enumerate(tracks, 1):
        length = 32 * 60 / track[0]
        write(f'Stage-{stage}.wav', *music(stage-1, length), fades=(.005, .006))
        write(f'Stage-{stage}-Layer.wav', *music(stage-1, length, layer=True), fades=(.005, .006))
    voice_names = ['cap','scarf','goggles','beanie','earmuffs','bow','visor','pocket',
                   'glasses','badge','star','headband']
    for index, name in enumerate(voice_names):
        left, right = buffer(1.9), buffer(1.9)
        voice(left, right, 0, index % len(profiles), index % 3)
        write(f'Voice-{name}.wav', left, right, volume=1.5)
