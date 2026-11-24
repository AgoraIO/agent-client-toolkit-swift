import Foundation

/// Word-mode merge rule for one agent turn. Foundation-only so scripts/test_swift.sh can
/// compile it without the Agora SDKs.
enum TranscriptWordMerge {
    /// Incoming words, in message order, that no kept word matches by text and start time.
    /// Incoming words are not compared with each other.
    static func newWords<W>(_ incoming: [W], kept: [W], text: (W) -> String, startMs: (W) -> Int64) -> [W] {
        incoming.filter { word in !kept.contains { startMs($0) == startMs(word) && text($0) == text(word) } }
    }

    /// Kept words followed by new words, stably sorted by start time (SE-0372).
    static func merged<W>(kept: [W], newWords: [W], startMs: (W) -> Int64) -> [W] {
        (kept + newWords).sorted { startMs($0) < startMs($1) }
    }

    /// Marks every word after the first interrupted word as interrupted (same rule as Kotlin).
    static func inheritInterrupted<W>(_ words: inout [W], isInterrupted: (W) -> Bool,
                                      markInterrupted: (inout W) -> Void) {
        guard let first = words.firstIndex(where: isInterrupted) else { return }
        for index in words.indices where index > first { markInterrupted(&words[index]) }
    }
}
