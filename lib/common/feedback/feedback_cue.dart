/// Application feedback channels; visual presentation has its own event gates.
enum FeedbackCue {
  tick,
  lastSecondsTick,
  chime,
  interval,
  finish,
  light,
  select,
  preview,
}

enum SoundCue { tick, chime, finish }

enum HapticCue { light, medium, heavy, selection }
