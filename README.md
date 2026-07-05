# Translator

Minimal local macOS translator using SwiftUI, AppKit, `NSPanel`, and LM Studio, featuring offline Text-to-Speech (TTS).

## Features

- **Local Translation:** Translates text offline using LM Studio as the LLM backend.
- **Offline Text-to-Speech (TTS):** Reads translation results aloud using macOS native speech synthesis.
- **Automatic Language Detection:** Uses the `NaturalLanguage` framework to automatically identify target language (English/Chinese) and select corresponding voices.
- **Overlay Window (Spotlight-like):** Activates via a global shortcut and stays anchored at the top-left, expanding downwards naturally during typing.
- **Customizable Shortcut:** Uses `KeyboardShortcuts` to customize global activator keys.
- **Real-Time Bilingual Subtitles:** Captures system-wide loopback audio output, transcribes speech offline locally, and translates it to Chinese in real-time inside an interactive, resizable, and draggable translucent overlay.

## License

MIT. See [LICENSE](LICENSE).

## Open In Xcode

1. Open Xcode.
2. Choose `File > Open...`.
3. Select this folder or `Package.swift`.
4. Wait for Swift Package dependencies to resolve.
5. In the top toolbar, choose the `Translator` scheme and `My Mac`.
6. Press `Run`.

The app runs as a menu bar utility. Use `Control + Space` (default) to toggle the translator panel.

## Keyboard Shortcuts

- `Enter`: Submit translation.
- `Shift + Enter`: Insert a newline inside the input box without submitting.
- `Escape`: Close/hide the translator panel (automatically silences any active reading).

## LM Studio Configuration

- Endpoint: `http://localhost:1234/v1/responses`
- Model: `local-model`

Make sure LM Studio is running and that the server endpoint is enabled before testing translation.

## Command Line Development

```bash
swift build
swift test
```

## Release DMG Packaging

Project version is tracked in [`VERSION`](VERSION). The release build script supports versions in standard `VERSION+BUILD_NUMBER` formatting (e.g., `1.2.0+3`).

Create a local release build and DMG:

```bash
chmod +x scripts/release_dmg.sh
./scripts/release_dmg.sh
```

With explicit version and build number overrides:

```bash
./scripts/release_dmg.sh 1.2.0 3
```

Recommended release flow:

1. Update the version in `VERSION` (e.g. `1.2.0+3`).
2. Run the packaging script without arguments:
   ```bash
   ./scripts/release_dmg.sh
   ```

The generated files will be placed in `dist/`:

- `dist/Translator.app`
- `dist/Translator.dmg`

Optional signing for local distribution:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release_dmg.sh
```

## Notes

- The app hides its Dock icon at launch by setting the activation policy to `.accessory`.
- `Sources/Translator/Resources/Info.plist` is included as a support file for a future full Xcode app target if you want to convert this package into a standard `.xcodeproj`.
