import Foundation

enum TurnDetectionMode: String, CaseIterable, Equatable {
    case vad
    case semantic
    case manual

    var displayName: String {
        switch self {
        case .vad:
            return "VAD"
        case .semantic:
            return "Semantic"
        case .manual:
            return "Manual"
        }
    }
}
