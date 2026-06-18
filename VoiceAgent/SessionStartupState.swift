import Foundation

struct SessionStartupState {
    enum Phase: Equatable {
        case idle
        case awaitingPermission
        case connecting
        case connected
        case failed
    }

    private(set) var phase: Phase = .idle
    private(set) var rtcJoined = false
    private(set) var rtmLoggedIn = false

    var canStartConnection: Bool {
        phase == .idle || phase == .failed
    }

    var shouldStartAgent: Bool {
        phase == .connecting && rtcJoined && rtmLoggedIn
    }

    mutating func beginPermissionRequest() -> Bool {
        guard canStartConnection else {
            return false
        }
        phase = .awaitingPermission
        rtcJoined = false
        rtmLoggedIn = false
        return true
    }

    mutating func beginConnecting() {
        phase = .connecting
        rtcJoined = false
        rtmLoggedIn = false
    }

    mutating func markRTCJoined() {
        rtcJoined = true
    }

    mutating func markRTMLoggedIn() {
        rtmLoggedIn = true
    }

    mutating func markConnected() {
        phase = .connected
    }

    mutating func markFailed() {
        phase = .failed
        rtcJoined = false
        rtmLoggedIn = false
    }

    mutating func reset() {
        phase = .idle
        rtcJoined = false
        rtmLoggedIn = false
    }
}
