# Original calm tune for a Reel: python3 tools/tune.py <seed> <seconds> out.wav
# Soft music-box melody (C major pentatonic) over slow pad chords; the seed picks the melody, so each Reel sounds different.
import math, random, struct, sys, wave

seed, secs, out = int(sys.argv[1]), float(sys.argv[2]), sys.argv[3]
R, BPM = 44100, 96
random.seed(seed)
beat = 60 / BPM
hz = lambda m: 440 * 2 ** ((m - 69) / 12)
buf = [0.0] * int(R * secs)

def note(m, start, dur, vol, bell):
    f, s0 = hz(m), int(start * R)
    for i in range(int(min(dur, secs - start) * R)):
        t = i / R
        env = math.exp(-t * (3.5 if bell else 0.6)) * min(1, t * 200)
        tone = math.sin(2 * math.pi * f * t) + (0.3 * math.sin(4 * math.pi * f * t) if bell else 0)
        if s0 + i < len(buf): buf[s0 + i] += vol * env * tone

chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]  # C Am F G
scale = [72, 74, 76, 79, 81, 84]
bar, t, i = 4 * beat, 0.0, 0
while t < secs:
    for m in chords[i % 4]: note(m - 12, t, bar * 1.1, 0.05, False)
    pos = random.randrange(len(scale))
    for k in range(8):
        if random.random() < 0.8:
            pos = max(0, min(len(scale) - 1, pos + random.choice([-1, -1, 0, 1, 1, 2])))
            note(scale[pos], t + k * beat / 2, 1.2, 0.12, True)
    t += bar; i += 1

peak = max(abs(x) for x in buf) or 1
fade = int(R * 1.5)
with wave.open(out, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
    w.writeframes(b''.join(struct.pack('<h', int(32000 * 0.8 * x / peak * min(1, (len(buf) - j) / fade, j / (R * 0.5)))) for j, x in enumerate(buf)))
