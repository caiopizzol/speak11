# Changelog

## Unreleased

- Replace ElevenLabs and the Python/shell runtime with local Kokoro synthesis
  through FluidAudio and Core ML.
- Package Speak11 as a conventional drag-to-Applications macOS app.
- Read selections through Accessibility before using a clipboard fallback.
- Preserve complete clipboard contents during compatibility capture.
- Add sentence-aware lookahead generation, speaking speed, launch at login,
  app packaging, CI, optional Developer ID signing, and notarization support.
- Register the single `⌥⇧/` shortcut through the active keyboard layout.
- Pick up speaking speed at each chunk and regenerate stale lookahead audio.
- Preserve typed failure context so Try Again retries the original request.
- Simplify the menu around read/stop, speed, launch at login, and quit.
- Add a first-run onboarding window with a hard Accessibility gate and
  automatic voice download.
- Show a focused re-download window when the local model cache is missing.
- Warm the voice at launch so the first shortcut press does not stall.
- Move the launch-at-login opt-in into onboarding while keeping it in the menu.
