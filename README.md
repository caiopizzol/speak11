<p align="center">
  <img src="icon.svg" width="96" height="96" alt="Speak11 icon">
</p>

<h1 align="center">Speak11</h1>

<p align="center">
  Select text in any app, press <kbd>⌥</kbd><kbd>A</kbd>, and hear it read aloud.<br>
  Private, local text-to-speech for Apple Silicon Macs.
</p>

## Requirements

- An Apple Silicon Mac
- macOS Sonoma 14 or later
- Internet access on first use to download about 200 MB of Kokoro
  model assets

Selected text is never sent to a server. After the first model download,
speech generation works offline.

## Install

1. Download `Speak11.zip` from the latest release.
2. Drag `Speak11.app` into Applications.
3. Open Speak11. A setup window asks for Accessibility access and downloads
   the voice automatically.
4. Select text in any app and press `Option-A`.

Press the shortcut again to stop. While Speak11 is running, `Option-A` is
reserved system-wide, so typing "å" with the Option key is unavailable. Use
the waveform menu-bar icon to change speaking speed or launch Speak11 at
login.

Development artifacts use an ad-hoc signature and may require right-clicking
the app and choosing Open. Tagged releases are frictionless only when the
repository has Developer ID and notarization secrets configured.

## How It Works

Speak11 is a native Swift menu-bar app:

- Accessibility APIs retrieve selected text without changing the clipboard.
- Apps that do not expose selection through Accessibility use a guarded
  Command-C fallback. Speak11 snapshots every clipboard item and restores it
  only if no other process changed the clipboard in the meantime.
- [FluidAudio](https://github.com/FluidInference/FluidAudio) runs Kokoro 82M
  locally through Core ML and the Apple Neural Engine.
- The next text chunk is generated while the current chunk plays, keeping
  longer selections moving without a Python daemon or background server.

The setup window downloads the models once, and each launch warms the voice in
the background so the first reading starts quickly.

## Build

Xcode 16 and the macOS 14 SDK are required.

```bash
swift test
./scripts/package-app.sh
```

The packaged app and zip archive are written to `dist/`.

To produce a publicly downloadable build without Gatekeeper friction, sign
with a Developer ID Application certificate and notarize it:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./scripts/package-app.sh

APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_SPECIFIC_PASSWORD="..." \
  ./scripts/notarize-app.sh
```

## Privacy

Speak11 does not contain analytics, accounts, API keys, cloud speech providers,
or reading history. Network access is used only by FluidAudio to download model
assets from Hugging Face when they are not already cached.

## License

[Unlicense](LICENSE). FluidAudio and downloaded model assets retain their own
licenses.
