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

private func testAgentStartWaitsForBothRTCAndRTM() {
    var state = SessionStartupState()
    expect(state.beginPermissionRequest(), "initial start should be allowed")
    state.beginConnecting()
    expect(!state.shouldStartAgent, "agent start should wait before rtc/rtm are ready")
    state.markRTMLoggedIn()
    expect(!state.shouldStartAgent, "agent start should still wait for rtc join")
    state.markRTCJoined()
    expect(state.shouldStartAgent, "agent start should proceed after rtc/rtm are both ready")
}

private func testResetReturnsToIdle() {
    var state = SessionStartupState()
    expect(state.beginPermissionRequest(), "initial start should be allowed")
    state.beginConnecting()
    state.markRTMLoggedIn()
    state.markRTCJoined()
    state.reset()
    expect(state.phase == .idle, "reset should return to idle")
    expect(!state.rtcJoined, "reset should clear rtc state")
    expect(!state.rtmLoggedIn, "reset should clear rtm state")
    expect(state.canStartConnection, "start should be allowed after reset")
}

func main() {
    testDisallowsReentrantStartWhileConnecting()
    testAgentStartWaitsForBothRTCAndRTM()
    testResetReturnsToIdle()
    print("SessionStartupStateTests passed")
}

main()
