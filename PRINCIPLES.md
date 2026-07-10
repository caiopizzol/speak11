# Speak11 Design Principles

## Product Boundary

Speak11 reads the current text selection aloud — and, when the user opts in,
the clipboard when no selection can be read. It does not manage documents,
store reading history, transcribe speech, rewrite text, or require an account.

## Runtime

- Speech generation is local after model assets have been downloaded.
- The application is a conventional macOS `.app`; installation must not compile
  source code or modify files under the user's home directory.
- The application must not require Python, shell scripts, a daemon, a local
  server, or an API key at runtime.
- Spoken text — selected or, with the opt-in, from the clipboard — is held in
  memory only for the active reading request and, after a failure, so Try
  Again can re-speak the same text. It is never logged or persisted.

## Selection

1. Query the focused Accessibility element and its parents for selected text.
2. Refuse to read secure text fields.
3. Use synthetic Command-C only as a compatibility fallback.
4. Snapshot all pasteboard item types before fallback capture.
5. Restore the snapshot only if the pasteboard still contains Speak11's copy.
6. With the opt-in enabled, speak the snapshot's plain text when both
   extraction methods fail — never the live clipboard, and never contents
   marked concealed or transient.

This order avoids clipboard changes in well-behaved applications and prevents
Speak11 from overwriting a clipboard update made concurrently by the user or
another application.

## Speech

- FluidAudio's Kokoro Core ML engine is the only speech backend.
- Keep the model resident after first use for low repeat latency.
- Chunk with Natural Language sentence boundaries and bound chunk size.
- Generate one chunk ahead while the current chunk plays.
- Apply speed changes immediately by time-stretching the playing chunk, then
  synthesize following chunks at the exact speed.
- A second `⌥A` press cancels pending playback and discards late results.

## Distribution

- Swift Package Manager defines the build and pins dependency versions.
- CI runs on macOS because AppKit, Accessibility, Core ML, and AVFoundation are
  not available on Linux.
- Packaging produces an arm64 app bundle and zip archive.
- Public releases require Developer ID signing and Apple notarization. An ad-hoc
  signature is acceptable only for local development artifacts.
