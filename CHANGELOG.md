# Changelog

## Unreleased

- Replace ElevenLabs and the Python/shell runtime with local Kokoro synthesis
  through FluidAudio and Core ML.
- Package Speak11 as a conventional drag-to-Applications macOS app.
- Read selections through Accessibility before using a clipboard fallback.
- Preserve complete clipboard contents during compatibility capture.
- Add sentence-aware lookahead generation, speaking speed, launch at login,
  app packaging, CI, optional Developer ID signing, and notarization support.
- Register the single `⌥A` shortcut through the active keyboard layout.
- Apply speed changes to the reading in progress: the playing audio is
  time-stretched immediately and later chunks are synthesized at the new
  speed.
- Preserve typed failure context so Try Again retries the original request.
- Simplify the menu around read/stop, speed, launch at login, and quit.
- Add a first-run onboarding window with a hard Accessibility gate and
  automatic voice download.
- Show a focused re-download window when the local model cache is missing.
- Warm the voice at launch so the first shortcut press does not stall.
- Move the launch-at-login opt-in into onboarding while keeping it in the menu.
- Speak links as words ("example dot com slash path"), dropping schemes,
  user-info, query parameters, and fragments, which commonly contain
  credentials or tracking values.
