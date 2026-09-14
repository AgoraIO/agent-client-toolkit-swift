import Foundation

@discardableResult
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

private func testSpeakDefaults() {
    let payload = MessagePayloadBuilder.speak(SpeakMessage(text: "Hello"))

    expect(payload["message"] as? String == "Hello", "speak should serialize message")
    expect(payload["priority"] as? String == "INTERRUPT", "speak should default priority to INTERRUPT")
    expect(payload["interruptable"] as? Bool == true, "speak should default interruptable to true")
}

private func testEverySpeakPriority() {
    for priority in Priority.allCases {
        let payload = MessagePayloadBuilder.speak(
            SpeakMessage(text: "Test", priority: priority, interruptable: false)
        )

        expect(payload["priority"] as? String == priority.stringValue, "speak should serialize \(priority)")
        expect(payload["interruptable"] as? Bool == false, "speak should serialize interruptable")
    }
}

private func testThinkDefaults() {
    let payload = MessagePayloadBuilder.think(ThinkMessage(text: "Buy clicked"))

    expect(payload["message"] as? String == "Buy clicked", "think should serialize message")
    expect(payload["on_listening_action"] as? String == "interrupt", "listening should default to interrupt")
    expect(payload["on_thinking_action"] as? String == "ignore", "thinking should default to ignore")
    expect(payload["on_speaking_action"] as? String == "ignore", "speaking should default to ignore")
    expect(payload["interruptable"] as? Bool == true, "think should default interruptable to true")
    expect(payload["metadata"] == nil, "think should omit metadata by default")
}

private func testEveryThinkAction() {
    for action in ThinkListeningAction.allCases {
        let payload = MessagePayloadBuilder.think(
            ThinkMessage(text: "Test", onListeningAction: action)
        )
        expect(
            payload["on_listening_action"] as? String == action.stringValue,
            "think should serialize listening action \(action)"
        )
    }

    for action in ThinkThinkingAction.allCases {
        let payload = MessagePayloadBuilder.think(
            ThinkMessage(text: "Test", onThinkingAction: action)
        )
        expect(
            payload["on_thinking_action"] as? String == action.stringValue,
            "think should serialize thinking action \(action)"
        )
    }

    for action in ThinkSpeakingAction.allCases {
        let payload = MessagePayloadBuilder.think(
            ThinkMessage(text: "Test", onSpeakingAction: action)
        )
        expect(
            payload["on_speaking_action"] as? String == action.stringValue,
            "think should serialize speaking action \(action)"
        )
    }
}

private func testThinkMetadataAndInterruptable() {
    let payload = MessagePayloadBuilder.think(
        ThinkMessage(
            text: "Test",
            onListeningAction: .inject,
            onThinkingAction: .append,
            onSpeakingAction: .interrupt,
            interruptable: false,
            metadata: ["source": "swift_test"]
        )
    )

    expect(payload["interruptable"] as? Bool == false, "think should serialize interruptable")
    let metadata = payload["metadata"] as? [String: String]
    expect(metadata?["source"] == "swift_test", "think should serialize metadata")
}

@main
private struct SpeakThinkMessageTests {
    static func main() {
        testSpeakDefaults()
        testEverySpeakPriority()
        testThinkDefaults()
        testEveryThinkAction()
        testThinkMetadataAndInterruptable()
        print("SpeakThinkMessageTests passed")
    }
}
