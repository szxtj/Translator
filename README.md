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

## Notes

- The app hides its Dock icon at launch by setting the activation policy to `.accessory`.
- `Sources/Translator/Resources/Info.plist` is included as a support file for a future full Xcode app target if you want to convert this package into a standard `.xcodeproj`.
- Press `Shift + Enter` in the input box to insert a newline without submitting.
