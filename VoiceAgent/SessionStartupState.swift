import Foundation

struct SessionStartupState {
    enum Phase: Equatable {
        case idle
        case awaitingPermission
        case connecting
        case connected
    }

    private(set) var phase: Phase = .idle
    private(set) var rtcJoined = false
    private(set) var rtmLoggedIn = false
    private(set) var messageSubscribed = false

    var canStartConnection: Bool {
        phase == .idle
    }

    var shouldStartAgent: Bool {
        phase == .connecting && rtcJoined && rtmLoggedIn && messageSubscribed
    }

    mutating func beginPermissionRequest() -> Bool {
        guard canStartConnection else {
            return false
        }
        phase = .awaitingPermission
        rtcJoined = false
        rtmLoggedIn = false
        messageSubscribed = false
        return true
    }

    mutating func beginConnecting() {
        phase = .connecting
        rtcJoined = false
        rtmLoggedIn = false
        messageSubscribed = false
    }

    mutating func markRTCJoined() {
        rtcJoined = true
    }

    mutating func markRTMLoggedIn() {
        rtmLoggedIn = true
    }

    mutating func markMessageSubscribed() {
        messageSubscribed = true
    }

    mutating func markConnected() {
        phase = .connected
    }

    mutating func reset() {
        phase = .idle
        rtcJoined = false
        rtmLoggedIn = false
        messageSubscribed = false
    }
}
