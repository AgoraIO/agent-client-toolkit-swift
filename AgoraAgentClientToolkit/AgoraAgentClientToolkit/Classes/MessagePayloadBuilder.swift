import Foundation

enum MessagePayloadBuilder {
    static func speak(_ message: SpeakMessage) -> [String: Any] {
        [
            "priority": message.priority.stringValue,
            "interruptable": message.interruptable,
            "message": message.text
        ]
    }

    static func think(_ message: ThinkMessage) -> [String: Any] {
        var payload: [String: Any] = [
            "message": message.text,
            "on_listening_action": message.onListeningAction.stringValue,
            "on_thinking_action": message.onThinkingAction.stringValue,
            "on_speaking_action": message.onSpeakingAction.stringValue,
            "interruptable": message.interruptable
        ]
        if let metadata = message.metadata {
            payload["metadata"] = metadata
        }
        return payload
    }
}
