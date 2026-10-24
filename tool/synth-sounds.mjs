// Yike original procedural sounds: deterministic, mono PCM16 / 44.1 kHz.
// Run with node tool/synth-sounds.mjs; no external samples or dependencies.
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
const directory = fileURLToPath(new URL('../asset/yike/sound/', import.meta.url));
mkdirSync(directory, { recursive: true });
const rate = 44100;
const sine = (t, hz) => Math.sin(2 * Math.PI * hz * t);
const hit = (t, hz, decay, metallic = false) => t < 0 ? 0 :
  (1 - Math.exp(-t * 1600)) * Math.exp(-t * decay) *
  (sine(t, hz) + (metallic ? .35 * sine(t, hz * 2.71) : .2 * sine(t, hz * 2)));
const drop = (t, hz) => t < 0 ? 0 :
  (1 - Math.exp(-t * 900)) * Math.exp(-t * 24) *
  Math.sin(2 * Math.PI * (hz * t + 40 * (1 - Math.exp(-t * 30))));
const sounds = {
  'mechanical-tick': [.025, t => hit(t, 2600, 230, true)],
  'mechanical-chime': [.22, t => hit(t, 1900, 100, true) + hit(t - .085, 2400, 100, true)],
  'mechanical-finish': [.9, t => [0, .15, .3, .45].reduce((v, d) => v + hit(t - d, 1800, 10, true), 0)],
  'water-tick': [.12, t => drop(t, 660)],
  'water-chime': [.38, t => drop(t, 340) + .25 * drop(t - .1, 340)],
  'water-finish': [1.2, t => drop(t, 420) + drop(t - .22, 520) + drop(t - .44, 640) + .13 * hit(t, 850, 4)],
  'sundial-tick': [.055, t => .3 * hit(t, 480, 95)],
  'sundial-chime': [.38, t => .65 * hit(t, 280, 17)],
  'sundial-finish': [1.5, t => .65 * hit(t, 520, 3.5) + .2 * hit(t, 1043, 5)],
};
for (const [name, [duration, sample]] of Object.entries(sounds)) {
  const count = Math.round(duration * rate);
  const wav = Buffer.alloc(44 + count * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36);
  wav.writeUInt32LE(count * 2, 40);
  for (let i = 0; i < count; i++) {
    // Fade the last 10ms to zero so no truncated waveform clicks at the end.
    const fade = Math.min(1, (count - 1 - i) / (rate * .01));
    const value = Math.max(-1, Math.min(1, sample(i / rate) * .4 * fade));
    wav.writeInt16LE(Math.round(value * 32767), 44 + i * 2);
  }
  writeFileSync(join(directory, `${name}.wav`), wav);
  console.log(`${name}.wav ${wav.length} bytes`);
}
