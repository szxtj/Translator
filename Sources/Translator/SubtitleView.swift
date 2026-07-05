import SwiftUI
@preconcurrency import Translation
import Combine

struct ResizeHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Parallel diagonal arcs indicating a resizable corner
        path.move(to: CGPoint(x: w - 4, y: h))
        path.addQuadCurve(to: CGPoint(x: w, y: h - 4), control: CGPoint(x: w - 2, y: h - 2))
        
        path.move(to: CGPoint(x: w - 8, y: h))
        path.addQuadCurve(to: CGPoint(x: w, y: h - 8), control: CGPoint(x: w - 4, y: h - 4))
        
        path.move(to: CGPoint(x: w - 12, y: h))
        path.addQuadCurve(to: CGPoint(x: w, y: h - 12), control: CGPoint(x: w - 6, y: h - 6))
        
        return path
    }
}

@available(macOS 26.4, *)
struct SubtitleView: View {
    @ObservedObject var manager: SubtitleManager

    private var cleanChinese: String? {
        if let Chinese = manager.translatedText {
            let trimmed = Chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private var cleanEnglish: String? {
        let trimmed = manager.englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack {
            if manager.finalizedPairs.isEmpty && cleanEnglish == nil {
                Spacer()
                Text("Listening to system audio...")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(manager.finalizedPairs) { pair in
                                VStack(spacing: 4) {
                                    Text(pair.english)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.yellow)
                                        .multilineTextAlignment(.center)
                                    Text(pair.chinese)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            if let English = cleanEnglish {
                                VStack(spacing: 4) {
                                    Text(English)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.yellow.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                    if let Chinese = cleanChinese {
                                        Text(Chinese)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white.opacity(0.85))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .id("active")
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                    }
                    .onChange(of: manager.englishText) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("active", anchor: .bottom)
                        }
                    }
                    .onChange(of: manager.finalizedPairs) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("active", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(manager.isHovered ? 0.75 : 0.25)) // Background fills entire container
        .cornerRadius(12)
        .overlay(
            Group {
                if !(manager.finalizedPairs.isEmpty && cleanEnglish == nil) {
                    ResizeHandleShape()
                        .stroke(Color.white.opacity(manager.isHovered ? 0.5 : 0.15), lineWidth: 1.5)
                        .frame(width: 15, height: 15)
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                        .allowsHitTesting(false)
                }
            },
            alignment: .bottomTrailing
        )
        .padding(8) // Outer margin for window resizing borders
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                manager.isHovered = hovering
            }
        }
        .translationTask(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "zh-Hans")
        ) { session in
            for await text in manager.$englishText.values {
                guard !text.isEmpty else {
                    await MainActor.run {
                        manager.translatedText = ""
                    }
                    continue
                }
                do {
                    let response = try await session.translate(text)
                    await MainActor.run {
                        manager.translatedText = response.targetText
                    }
                } catch {
                    print("[Translation] Error translating text: \(error)")
                }
            }
        }
    }
}
