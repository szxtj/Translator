import Foundation

enum TranslationMode: String, CaseIterable, Identifiable, Sendable {
    case auto
    case zhToEn
    case enToZh
    case detail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .zhToEn:
            return "中→英"
        case .enToZh:
            return "英→中"
        case .detail:
            return "详解"
        }
    }
}
