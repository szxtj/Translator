// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Translator",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "Translator", targets: ["Translator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "Translator",
            dependencies: [
                "KeyboardShortcuts",
            ],
            exclude: [
                "Resources/Info.plist",
            ],
            resources: [
                .copy("Resources/AppIcon.icns"),
            ]
        ),
        .testTarget(
            name: "TranslatorTests",
            dependencies: ["Translator"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
