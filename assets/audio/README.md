# Sound Effects (SFX)

Sound assets used by `AppAudioService` (`.wav` or `.mp3`; update the mapping in
`lib/core/services/audio_service.dart` if you change a file name):
- `shoot.wav`: Shot release tap sound
- `hit.wav`: Ball impact / clear sound
- `hazard.wav`: Spike / hazard crash sound
- `win.wav`: Level completed victory fanfare
- `lose.wav`: Game over sound
- `button.wav`: UI button click
- `coin.wav`: Coin award / shop purchase sound

`AppAudioService` will automatically play these with low-latency and triggers corresponding haptic feedback!
