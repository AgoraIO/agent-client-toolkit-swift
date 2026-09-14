import Foundation

/// Message priority levels for chat and direct speech requests.
@objc public enum Priority: Int, CaseIterable {
    case interrupt = 0
    case append = 1
    case ignore = 2

    public var stringValue: String {
        switch self {
        case .interrupt: return "INTERRUPT"
        case .append: return "APPEND"
        case .ignore: return "IGNORE"
        }
    }

    public init?(stringValue: String) {
        switch stringValue.uppercased() {
        case "INTERRUPT": self = .interrupt
        case "APPEND": self = .append
        case "IGNORE": self = .ignore
        default: return nil
        }
    }
}

/// Action to take when a think instruction arrives while the agent is listening.
@objc public enum ThinkListeningAction: Int, CaseIterable {
    case inject = 0
    case interrupt = 1
    case ignore = 2
    case append = 3

    public var stringValue: String {
        switch self {
        case .inject: return "inject"
        case .interrupt: return "interrupt"
        case .ignore: return "ignore"
        case .append: return "append"
        }
    }
}

/// Action to take when a think instruction arrives while the agent is thinking.
@objc public enum ThinkThinkingAction: Int, CaseIterable {
    case interrupt = 0
    case ignore = 1
    case append = 2

    public var stringValue: String {
        switch self {
        case .interrupt: return "interrupt"
        case .ignore: return "ignore"
        case .append: return "append"
        }
    }
}

/// Action to take when a think instruction arrives while the agent is speaking.
@objc public enum ThinkSpeakingAction: Int, CaseIterable {
    case interrupt = 0
    case ignore = 1
    case append = 2

    public var stringValue: String {
        switch self {
        case .interrupt: return "interrupt"
        case .ignore: return "ignore"
        case .append: return "append"
        }
    }
}

/// A message that the agent broadcasts directly without LLM processing.
///
/// - Parameters:
///   - text: Text to synthesize and broadcast through the agent's TTS pipeline.
///   - priority: How the agent handles this request relative to the current interaction.
///     Defaults to `.interrupt`.
///   - interruptable: Whether user speech can interrupt the synthesized speech generated
///     for this request. Defaults to `true`.
@objc public final class SpeakMessage: NSObject {
    /// Text to synthesize and broadcast through the agent's TTS pipeline.
    @objc public let text: String

    /// How the agent handles this request relative to the current interaction.
    @objc public let priority: Priority

    /// Whether user speech can interrupt the synthesized speech generated for this request.
    @objc public let interruptable: Bool

    @objc public init(
        text: String,
        priority: Priority = .interrupt,
        interruptable: Bool = true
    ) {
        self.text = text
        self.priority = priority
        self.interruptable = interruptable
        super.init()
    }
}

/// An instruction that the agent processes as input to the LLM.
///
/// - Parameters:
///   - text: Instruction text injected into the conversation as user input.
///   - onListeningAction: Action taken while the agent is listening. Defaults to `.interrupt`.
///   - onThinkingAction: Action taken while the agent is thinking. Defaults to `.ignore`.
///   - onSpeakingAction: Action taken while the agent is speaking. Defaults to `.ignore`.
///   - interruptable: Whether user speech can interrupt the generated response. Defaults to `true`.
///   - metadata: Optional caller-supplied business identifiers or other string key-value data.
///     `nil` omits the field from the RTM payload.
@objc public final class ThinkMessage: NSObject {
    /// Instruction text injected into the conversation as user input.
    @objc public let text: String

    /// Action taken if the instruction arrives while the agent is listening.
    @objc public let onListeningAction: ThinkListeningAction

    /// Action taken if the instruction arrives while the agent is thinking.
    @objc public let onThinkingAction: ThinkThinkingAction

    /// Action taken if the instruction arrives while the agent is speaking.
    @objc public let onSpeakingAction: ThinkSpeakingAction

    /// Whether user speech can interrupt the response generated for this instruction.
    @objc public let interruptable: Bool

    /// Optional caller-supplied business identifiers or other string key-value data.
    @objc public let metadata: [String: String]?

    @objc public init(
        text: String,
        onListeningAction: ThinkListeningAction = .interrupt,
        onThinkingAction: ThinkThinkingAction = .ignore,
        onSpeakingAction: ThinkSpeakingAction = .ignore,
        interruptable: Bool = true,
        metadata: [String: String]? = nil
    ) {
        self.text = text
        self.onListeningAction = onListeningAction
        self.onThinkingAction = onThinkingAction
        self.onSpeakingAction = onSpeakingAction
        self.interruptable = interruptable
        self.metadata = metadata
        super.init()
    }
}
