# Translator

Minimal local macOS translator using SwiftUI, AppKit, `NSPanel`, and LM Studio.

## Open In Xcode

1. Open Xcode.
2. Choose `File > Open...`.
3. Select this folder or `Package.swift`.
4. Wait for Swift Package dependencies to resolve.
5. In the top toolbar, choose the `Translator` scheme and `My Mac`.
6. Press `Run`.

The app runs as a menu bar utility. Use `Control + Space` to toggle the translator panel.

## LM Studio

- Endpoint: `http://localhost:1234/v1/responses`
- Model: `local-model`

Make sure LM Studio is running and that the endpoint is enabled before testing translation.

## Command Line

```bash
swift build
swift test
```

## Release DMG

Create a local release build and DMG:

```bash
chmod +x scripts/release_dmg.sh
./scripts/release_dmg.sh
```

With explicit version and build number:

```bash
./scripts/release_dmg.sh 1.0.0 1
```

The generated files will be placed in `dist/`:

- `dist/Translator.app`
- `dist/Translator.dmg`

Optional signing for local distribution:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release_dmg.sh 1.0.0 1
```

## Notes

- The app hides its Dock icon at launch by setting the activation policy to `.accessory`.
- `Sources/Translator/Resources/Info.plist` is included as a support file for a future full Xcode app target if you want to convert this package into a standard `.xcodeproj`.
- Press `Shift + Enter` in the input box to insert a newline without submitting.
