import Foundation

@discardableResult
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

private func testDisallowsReentrantStartWhileConnecting() {
    var state = SessionStartupState()
    expect(state.beginPermissionRequest(), "initial start should be allowed")
    state.beginConnecting()
    expect(!state.beginPermissionRequest(), "reentrant start should be blocked while connecting")
}

private func testAgentStartWaitsForRTCAndRTMAndSubscription() {
    var state = SessionStartupState()
    expect(state.beginPermissionRequest(), "initial start should be allowed")
    state.beginConnecting()
    expect(!state.shouldStartAgent, "agent start should wait before dependencies are ready")
    state.markRTMLoggedIn()
    expect(!state.shouldStartAgent, "agent start should still wait for rtc join")
    state.markRTCJoined()
    expect(!state.shouldStartAgent, "agent start should still wait for message subscription")
    state.markMessageSubscribed()
    expect(state.shouldStartAgent, "agent start should proceed after rtc, rtm, and subscription are ready")
}

private func testResetReturnsToIdle() {
    var state = SessionStartupState()
    expect(state.beginPermissionRequest(), "initial start should be allowed")
    state.beginConnecting()
    state.markRTMLoggedIn()
    state.markRTCJoined()
    state.markMessageSubscribed()
    state.reset()
    expect(state.phase == .idle, "reset should return to idle")
    expect(!state.rtcJoined, "reset should clear rtc state")
    expect(!state.rtmLoggedIn, "reset should clear rtm state")
    expect(!state.messageSubscribed, "reset should clear subscription state")
    expect(state.canStartConnection, "start should be allowed after reset")
}

@main
private struct SessionStartupStateTests {
    static func main() {
        testDisallowsReentrantStartWhileConnecting()
        testAgentStartWaitsForRTCAndRTMAndSubscription()
        testResetReturnsToIdle()
        print("SessionStartupStateTests passed")
    }
}
