import Foundation
import AgoraAgentClientToolkit

enum ManualTurnDemoUI {
    enum Action {
        case sos
        case eos

        var label: String {
            switch self {
            case .sos:
                return "SOS"
            case .eos:
                return "EOS"
            }
        }
    }

    static func formatPublishLog(action: Action, requestId: String) -> String {
        return "Manual \(action.label) publish requestId=\(requestId)"
    }

    static func formatPublishFailureLog(action: Action, requestId: String, errorMessage: String) -> String {
        return "Manual \(action.label) publish failed requestId=\(requestId) error=\(errorMessage)"
    }

    static func formatUserResultLog(action: Action, payload: UserManualEventPayload) -> String {
        let status = payload.success ? "success" : "failed"
        let turnId = payload.turnId?.stringValue ?? "null"
        let error = payload.errorMessage.map { " error=\($0)" } ?? ""
        return "Manual \(action.label) result \(status) requestId=\(payload.requestId) turnId=\(turnId)\(error)"
    }

    static func formatAgentEosLog(payload: AgentManualEosPayload) -> String {
        return "Agent manual EOS reason=\(payload.reason) turnId=\(payload.turnId) maxDurationMs=\(payload.maxDurationMs)"
    }
}
