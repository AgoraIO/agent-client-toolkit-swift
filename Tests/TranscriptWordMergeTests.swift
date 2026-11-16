import Foundation

@discardableResult
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

/// Test-local word. The controller's TurnWordInfo is private, and TranscriptStatus is defined in
/// ConversationalAIAPI.swift, which imports the Agora SDKs. `start_ms` values are relative to the
/// log sessions they come from.
private struct Word: Equatable {
    let text: String
    let startMs: Int64
    var interrupted = false
}

private func w(_ text: String, _ startMs: Int64, interrupted: Bool = false) -> Word {
    Word(text: text, startMs: startMs, interrupted: interrupted)
}

private func sp(_ startMs: Int64, interrupted: Bool = false) -> Word {
    w(" ", startMs, interrupted: interrupted)
}

/// One merge step of TranscriptController.handleWordsMessage: new words are taken against the
/// buffer before the merge and, when there are any, merged, sorted, and every word after the
/// first interrupted word is marked interrupted (bugfix.md 2.5).
private func merge(_ kept: [Word], _ incoming: [Word]) -> [Word] {
    let added = TranscriptWordMerge.newWords(incoming, kept: kept, text: { $0.text }, startMs: { $0.startMs })
    guard !added.isEmpty else { return kept }
    var words = TranscriptWordMerge.merged(kept: kept, newWords: added, startMs: { $0.startMs })
    TranscriptWordMerge.inheritInterrupted(
        &words, isInterrupted: { $0.interrupted }, markInterrupted: { $0.interrupted = true }
    )
    return words
}

// MARK: - Property 1: Bug Condition - a different word with an already kept start_ms is not dropped.
// **Validates: Requirements 1.1, 1.3, 1.4, 2.1, 2.5**

private func testU1CrossMessageWordWithKeptStartIsKept() {
    // Cartesia turn 4, seq 13 -> seq 14: zero-duration 'a' shares start_ms with 'different'.
    let kept = [w("try", 6744), sp(6902), w("a", 6984)]
    let incoming = [w("try", 6744), sp(6902), w("a", 6984), sp(6983), w("different", 6984)]
    expect(isBugCondition([kept, incoming]), "U1 input must satisfy the bug condition")

    expectWords(
        merge(kept, incoming),
        [w("try", 6744), sp(6902), sp(6983), w("a", 6984), w("different", 6984)],
        "U1: different@6984 must be kept after a@6984"
    )
}

private func testU5OverlappingWindowsRestoreSequence() {
    let windows = slidingWindows(u5Sequence, size: 32, step: 3)
    expect(isBugCondition(windows), "U5 input must satisfy the bug condition")
    // Swift merges the first message of a turn too, into an empty buffer.
    let result = windows.reduce([Word]()) { merge($0, $1) }

    expectWords(result, u5Sequence, "U5: overlapping windows must restore the 40-word sequence")
}

private func testU6SameStartWordAfterInterruptIsKeptAndInterrupted() {
    // Interrupt at 6984 with pts 6990. Swift splits at `<`: ␠@6983 (last word before the mark)
    // and a@6984 are interrupted.
    let kept = interruptLikeController(
        [w("try", 6744), sp(6902), sp(6983), w("a", 6984)], interruptMs: 6984, pts: 6990
    )
    expect(format(kept) == "try@6744, ␠@6902, ␠@6983(I), a@6984(I)", "U6 setup: K=\(format(kept))")
    let incoming = [sp(6983), w("a", 6984), w("different", 6984)]
    expect(isBugCondition([kept, incoming]), "U6 input must satisfy the bug condition")

    expectWordsAndStatus(
        merge(kept, incoming),
        [
            w("try", 6744), sp(6902), sp(6983, interrupted: true), w("a", 6984, interrupted: true),
            w("different", 6984, interrupted: true),
        ],
        "U6: different@6984 must be kept right after a@6984 and be interrupted (2.5)"
    )
}

private func testU6bWordsArrivingAfterInterruptAreInterrupted() {
    // Same K as U6. 2.5 also covers later words with a different start_ms (␠@7222).
    let kept = interruptLikeController(
        [w("try", 6744), sp(6902), sp(6983), w("a", 6984)], interruptMs: 6984, pts: 6990
    )
    expect(format(kept) == "try@6744, ␠@6902, ␠@6983(I), a@6984(I)", "U6b setup: K=\(format(kept))")
    let incoming = [w("different", 6984), sp(7222)]
    expect(isBugCondition([kept, incoming]), "U6b input must satisfy the bug condition")

    expectWordsAndStatus(
        merge(kept, incoming),
        [
            w("try", 6744), sp(6902), sp(6983, interrupted: true), w("a", 6984, interrupted: true),
            w("different", 6984, interrupted: true), sp(7222, interrupted: true),
        ],
        "U6b: different@6984 and ␠@7222 must be kept and interrupted (2.5)"
    )
}

private func testGeneratedBugConditionSequencesMatchExpectedMerge() {
    var random = SplitMix64(seed: seed)
    var bugConditionCases = 0
    var failures = 0
    var firstFailure: String?

    for iteration in 0..<iterations {
        let messages = generateMessages(&random)
        guard isBugCondition(messages) else { continue }
        bugConditionCases += 1
        guard let mismatch = firstMismatchWithExpectedMerge(messages) else { continue }
        failures += 1
        if firstFailure == nil {
            firstFailure = "seed=\(seed) iteration=\(iteration) \(mismatch)\nmessages:\n\(formatMessages(messages))"
        }
    }

    print("bug condition: seed=\(seed) \(bugConditionCases) of \(iterations) sequences in the bug condition")
    expect(bugConditionCases > 0, "generator produced no bug-condition sequences")
    expect(
        firstFailure == nil,
        "\(failures) of \(bugConditionCases) bug-condition sequences differ from expectedMerge; first: "
            + (firstFailure ?? "")
    )
}

// MARK: - Property 2: Preservation - inputs outside the bug condition merge as before.
// **Validates: Requirements 3.1, 3.2, 3.3, 3.7, 3.10, 3.11**
// Values observed on the pre-fix merge (start_ms only). Entries missing `word` or `start_ms` are
// dropped by the controller's compactMap before the merge (3.7), and the END reset and stamp stay
// in the controller (3.4); both are covered by code review, not here.

/// U1's expected (post-fix) result, used as the kept words of U3.
private let u1FixedResult = [w("try", 6744), sp(6902), sp(6983), w("a", 6984), w("different", 6984)]

private func testU2aSameStartWordsInOneUpdateMessageAreKept() {
    // a@6984 and different@6984 first arrive in the same message; Swift compares only with the
    // buffer before the merge.
    let kept = [w("try", 6744), sp(6902)]
    let incoming = [sp(6902), w("a", 6984), sp(6983), w("different", 6984)]
    expect(!isBugCondition([kept, incoming]), "U2a input must be outside the bug condition")

    expectWords(merge(kept, incoming), u1FixedResult, "U2a: a@6984 and different@6984 must both be kept")
}

private func testU2bSameStartWordsInFirstMessageAreKept() {
    // Swift merges a turn's first message into the empty buffer.
    let incoming = [w("try", 6744), sp(6902), w("a", 6984), sp(6983), w("different", 6984)]
    expect(!isBugCondition([incoming]), "U2b input must be outside the bug condition")

    expectWords(merge([], incoming), u1FixedResult, "U2b: a@6984 and different@6984 must both be kept")
}

private func testU3OverlappingResendAddsOnlyNewWords() {
    // Cartesia log.1 lines 4128 -> 4130: the resent words are already kept with the same key.
    let incoming = [sp(6902), w("a", 6984), sp(6983), w("different", 6984), sp(7222), w("one.", 7304)]
    expect(!isBugCondition([u1FixedResult, incoming]), "U3 input must be outside the bug condition")

    let result = merge(u1FixedResult, incoming)
    expectWords(result, u1FixedResult + [sp(7222), w("one.", 7304)], "U3: only ␠@7222 and one.@7304 are added")
    expectText(result, "try  adifferent one.", "U3")
}

private func testU4aChineseFirstMessageKeepsSameStartWords() {
    // shengwang log line 275 (turn 2, first message) then line 290: ～@7195 shares start_ms with 团.
    let first = [w("想", 6932), w("～", 7195), w("团", 7195), w("团", 7413), w("昨", 7686)]
    let second = first + [w("天", 7823)]
    expect(!isBugCondition([first, second]), "U4a input must be outside the bug condition")

    let step1 = merge([], first)
    expectWords(step1, first, "U4a step 1: all 5 words must be kept")
    expectText(step1, "想～团团昨", "U4a step 1")
    expectWords(merge(step1, second), first + [w("天", 7823)], "U4a step 2: only 天@7823 is added")
}

private func testU4bChineseUpdateMessageKeepsSameStartWords() {
    // shengwang log lines 725 -> 730 -> 733: 。@1079, 。@1079 and 小@1079 first arrive together.
    let kept = [w("架", 700), w("’", 927), w("？", 927)]
    let first = [w("架", 700), w("’", 927), w("？", 927), w("”", 1061), w("。", 1079), w("。", 1079), w("小", 1079)]
    let second = [w("”", 1061), w("。", 1079), w("。", 1079), w("小", 1079), w("白", 1270)]
    expect(!isBugCondition([kept, first, second]), "U4b input must be outside the bug condition")

    let step1 = merge(kept, first)
    expectWords(
        step1, kept + [w("”", 1061), w("。", 1079), w("。", 1079), w("小", 1079)],
        "U4b step 1: ”, 。, 。 and 小 are added"
    )
    expectText(step1, "架’？”。。小", "U4b step 1")
    expectWords(merge(step1, second), step1 + [w("白", 1270)], "U4b step 2: only 白@1270 is added")
}

private func testU7SameKeyFirstSeenInLaterMessageIsStillDropped() {
    // Known gap 3.10 (Cartesia log.1 lines 4119 -> 4121): the space after me@6663 has the same key
    // as the kept ␠@6662 and is dropped. 3.11: spaces keep their start_ms order.
    let kept = [w("Let", 6380), sp(6662), w("me", 6663)]
    let incoming = [w("Let", 6380), sp(6662), w("me", 6663), sp(6662), w("try", 6744)]
    expect(!isBugCondition([kept, incoming]), "U7 input must be outside the bug condition")

    let result = merge(kept, incoming)
    expectWords(result, [w("Let", 6380), sp(6662), w("me", 6663), w("try", 6744)], "U7: second ␠@6662 is dropped")
    expectText(result, "Let metry", "U7")
}

private func testPlainOverlappingWindowsRestoreSequence() {
    // The U5 words with distinct start_ms, windows of 32 advancing by 3.
    let windows = slidingWindows(plainSequence, size: 32, step: 3)
    expect(!isBugCondition(windows), "plain windows must be outside the bug condition")
    let result = windows.reduce([Word]()) { merge($0, $1) }

    expectWords(result, plainSequence, "plain windows must restore the 40-word sequence")
}

private func testGeneratedNonBugSequencesMatchReferenceMerge() {
    var random = SplitMix64(seed: seed)
    var preservationCases = 0
    var sameStartInMessageCases = 0
    var failures = 0
    var firstFailure: String?

    for iteration in 0..<iterations {
        let messages = generateMessages(&random)
        guard !isBugCondition(messages) else { continue }
        preservationCases += 1
        if messages.contains(where: hasSameStartDifferentWords) { sameStartInMessageCases += 1 }
        guard let mismatch = firstMismatchWithReferenceMerge(messages) else { continue }
        failures += 1
        if firstFailure == nil {
            firstFailure = "seed=\(seed) iteration=\(iteration) \(mismatch)\nmessages:\n\(formatMessages(messages))"
        }
    }

    print(
        "preservation: seed=\(seed) \(preservationCases) of \(iterations) sequences outside the bug condition, "
            + "\(sameStartInMessageCases) with same-start different words in one message"
    )
    expect(preservationCases > 0, "generator produced no sequences outside the bug condition")
    expect(sameStartInMessageCases > 0, "generator produced no same-start different words in one message")
    expect(
        firstFailure == nil,
        "\(failures) of \(preservationCases) non-bug sequences differ from the pre-fix merge; first: "
            + (firstFailure ?? "")
    )
}

// MARK: - Property 3: overlapping windows restore the reference sequence.
// **Validates: Requirements 2.1, 2.2, 2.3, 3.1**

private func testProperty3OverlappingWindowsRestoreReference() {
    var random = SplitMix64(seed: seed)
    var multiWindowCases = 0
    var sameStartInReferenceCases = 0
    var newWordWithKeptStartCases = 0
    var failures = 0
    var firstFailure: String?

    for iteration in 0..<iterations {
        let reference = generateReference(&random)
        let windows = generateWindows(&random, reference)
        if windows.count > 1 { multiWindowCases += 1 }
        if zip(reference, reference.dropFirst()).contains(where: { pair in pair.0.startMs == pair.1.startMs }) {
            sameStartInReferenceCases += 1
        }
        // Swift merges the first window too, into the empty buffer.
        var kept: [Word] = []
        var newWordWithKeptStart = false
        for window in windows {
            if addedWords(kept, window).contains(where: { word in kept.contains { $0.startMs == word.startMs } }) {
                newWordWithKeptStart = true
            }
            kept = merge(kept, window)
        }
        if newWordWithKeptStart { newWordWithKeptStartCases += 1 }
        if kept == reference { continue }
        failures += 1
        if firstFailure == nil {
            firstFailure = "seed=\(seed) iteration=\(iteration)\nL=\(format(reference))\nresult=\(format(kept))\n"
                + "windows:\n\(formatMessages(windows))"
        }
    }

    print(
        "property 3: seed=\(seed) iterations=\(iterations) multiWindow=\(multiWindowCases) "
            + "sameStartInL=\(sameStartInReferenceCases) newWordWithKeptStart=\(newWordWithKeptStartCases)"
    )
    expect(
        firstFailure == nil,
        "property 3: \(failures) of \(iterations) window sequences do not restore L; first: " + (firstFailure ?? "")
    )
    expect(multiWindowCases > 0, "property 3: generator produced no multi-window sequences")
    expect(sameStartInReferenceCases > 0, "property 3: generator produced no same-start words in L")
    expect(
        newWordWithKeptStartCases > 0,
        "property 3: generator produced no window with a new word whose start_ms is already kept"
    )
}

// MARK: - Property 4: dedup key counts.
// Every key that occurs in K keeps its count in K; a key that occurs only in M has its count in M
// (new words are not dropped, M is not deduplicated); no other key appears.
// **Validates: Requirements 2.1, 2.2, 3.1, 3.10**

private func testProperty4DedupKeyCountsArePreserved() {
    var random = SplitMix64(seed: seed)
    var coverage: [Shape: Int] = [:]
    var failures = 0
    var firstFailure: String?

    for iteration in 0..<iterations {
        let (kept, incoming) = generateKeptAndIncoming(&random)
        count(mergeShapes(kept, incoming), into: &coverage)
        let result = merge(kept, incoming)
        guard let mismatch = keyCountMismatch(kept, incoming, result) else { continue }
        failures += 1
        if firstFailure == nil {
            firstFailure = "seed=\(seed) iteration=\(iteration) \(mismatch)\nK=\(format(kept))\n"
                + "M=\(format(incoming))\nresult=\(format(result))"
        }
    }

    reportRandomRun("property 4", coverage, required: mergeShapesRequired, failures: failures, firstFailure: firstFailure)
}

// MARK: - Property 5: stable order.
// The result is K ++ added stably sorted by start_ms: within one start_ms, kept words come first in K
// order and new words follow in message order. The oracle is expectedMerge, which orders by
// (start_ms, position) and so does not rely on sorted(by:) being stable.
// **Validates: Requirements 2.3, 3.3**

private func testProperty5ResultIsStableSortOfKeptThenAdded() {
    var random = SplitMix64(seed: seed)
    var coverage: [Shape: Int] = [:]
    var failures = 0
    var firstFailure: String?

    for iteration in 0..<iterations {
        let (kept, incoming) = generateKeptAndIncoming(&random)
        count(mergeShapes(kept, incoming), into: &coverage)
        let expected = expectedMerge(kept, incoming)
        let result = merge(kept, incoming)
        if result == expected { continue }
        failures += 1
        if firstFailure == nil {
            firstFailure = "seed=\(seed) iteration=\(iteration)\nK=\(format(kept))\nM=\(format(incoming))\n"
                + "expected=\(format(expected))\nactual=\(format(result))"
        }
    }

    reportRandomRun("property 5", coverage, required: mergeShapesRequired, failures: failures, firstFailure: firstFailure)
}

// MARK: - Property 6: interrupt inheritance.
// K has an interrupted suffix from a random position; after newWords, merged and inheritInterrupted,
// every word after the first interrupted word is interrupted and the words before it keep their state.
// Swift's pure functions do not stamp END; the controller stamps the last word afterwards (3.4).
// **Validates: Requirements 2.5, 3.6**

private func testProperty6WordsAfterFirstInterruptedAreInterrupted() {
    var random = SplitMix64(seed: seed)
    var coverage: [Shape: Int] = [:]
    var failures = 0
    var firstFailure: String?

    for iteration in 0..<iterations {
        let (kept, incoming) = generateInterruptedKeptAndIncoming(&random)
        count(interruptShapes(kept, incoming), into: &coverage)
        let result = merge(kept, incoming)
        guard let mismatch = interruptInheritanceMismatch(kept, incoming, result) else { continue }
        failures += 1
        if firstFailure == nil {
            firstFailure = "seed=\(seed) iteration=\(iteration) \(mismatch)\nK=\(format(kept))\n"
                + "M=\(format(incoming))\nresult=\(format(result))"
        }
    }

    reportRandomRun(
        "property 6", coverage, required: interruptShapesRequired, failures: failures, firstFailure: firstFailure
    )
}

// MARK: - inheritInterrupted unit cases
// **Validates: Requirements 2.5**

private func inheritingInterrupted(_ words: [Word]) -> [Word] {
    var result = words
    TranscriptWordMerge.inheritInterrupted(
        &result, isInterrupted: { $0.interrupted }, markInterrupted: { $0.interrupted = true }
    )
    return result
}

private func testInheritInterruptedWithoutInterruptedWordChangesNothing() {
    let words = [w("try", 6744), sp(6902), w("a", 6984), w("different", 6984)]
    expectWordsAndStatus(
        inheritingInterrupted(words), words, "inheritInterrupted without an interrupted word must change nothing"
    )
}

private func testInheritInterruptedFromFirstWordMarksEveryWord() {
    let words = [w("try", 6744, interrupted: true), sp(6902), w("a", 6984), w("different", 6984)]
    expectWordsAndStatus(
        inheritingInterrupted(words),
        [
            w("try", 6744, interrupted: true), sp(6902, interrupted: true), w("a", 6984, interrupted: true),
            w("different", 6984, interrupted: true),
        ],
        "inheritInterrupted from the first word must mark every word"
    )
}

private func testInheritInterruptedOnLastWordMarksOnlyLastWord() {
    let words = [w("try", 6744), sp(6902), w("a", 6984), w("different", 6984, interrupted: true)]
    expectWordsAndStatus(
        inheritingInterrupted(words), words, "inheritInterrupted on the last word must leave the other words as is"
    )
}

// MARK: - Rule models

/// Swift bug condition: a word whose (word, start_ms) is not kept but whose start_ms is kept with
/// different text. Swift compares only with the buffer before the merge, so words earlier in the
/// same message never count. K accumulates with the pre-fix rule.
private func isBugCondition(_ messages: [[Word]]) -> Bool {
    var kept: [Word] = []
    for incoming in messages {
        for word in incoming {
            let sameKeyKept = kept.contains { $0.text == word.text && $0.startMs == word.startMs }
            let sameStartKept = kept.contains { $0.startMs == word.startMs && $0.text != word.text }
            if !sameKeyKept && sameStartKept { return true }
        }
        kept = referenceMerge(kept, incoming)
    }
    return false
}

/// Pre-fix rule: copy of TranscriptController.handleWordsMessage at source/v2.10.2 (start_ms only).
private func referenceMerge(_ kept: [Word], _ incoming: [Word]) -> [Word] {
    let uniqueWords = incoming.filter { newWord in
        !kept.contains { $0.startMs == newWord.startMs }
    }
    guard !uniqueWords.isEmpty else { return kept }
    var words = kept
    words.append(contentsOf: uniqueWords)
    words.sort { $0.startMs < $1.startMs }
    return words
}

/// design.md expectedMerge: K ++ added ordered by (start_ms, position), independent of sort stability.
private func expectedMerge(_ kept: [Word], _ incoming: [Word]) -> [Word] {
    let added = incoming.filter { word in
        !kept.contains { $0.text == word.text && $0.startMs == word.startMs }
    }
    return (kept + added).enumerated()
        .sorted { ($0.element.startMs, $0.offset) < ($1.element.startMs, $1.offset) }
        .map { $0.element }
}

/// Fix checking: every merge step equals expectedMerge on the word sequence.
private func firstMismatchWithExpectedMerge(_ messages: [[Word]]) -> String? {
    var kept: [Word] = []
    for (step, incoming) in messages.enumerated() {
        let expected = expectedMerge(kept, incoming)
        let actual = merge(kept, incoming)
        if !sameWords(actual, expected) {
            return "step=\(step)\nK=\(format(kept))\nM=\(format(incoming))\n"
                + "expected=\(format(expected))\nactual=\(format(actual))"
        }
        kept = actual
    }
    return nil
}

/// Preservation checking: every merge step equals the pre-fix rule on the word sequence. Both
/// sides accumulate their own kept words (design.md "Preservation Checking").
private func firstMismatchWithReferenceMerge(_ messages: [[Word]]) -> String? {
    var referenceKept: [Word] = []
    var kept: [Word] = []
    for (step, incoming) in messages.enumerated() {
        let expected = referenceMerge(referenceKept, incoming)
        let actual = merge(kept, incoming)
        if !sameWords(actual, expected) {
            return "step=\(step)\nK=\(format(kept))\nM=\(format(incoming))\n"
                + "expected=\(format(expected))\nactual=\(format(actual))"
        }
        referenceKept = expected
        kept = actual
    }
    return nil
}

private func hasSameStartDifferentWords(_ message: [Word]) -> Bool {
    message.indices.contains { i in
        message[..<i].contains { $0.startMs == message[i].startMs && $0.text != message[i].text }
    }
}

/// Copy of the interrupt branch of TranscriptController.handleWordsMessage at source/v2.10.2:
/// words at or after min(interrupt, pts) and the last word before it are interrupted.
private func interruptLikeController(_ words: [Word], interruptMs: Int64, pts: Int64) -> [Word] {
    var result = words
    let markMs = min(interruptMs, pts)
    var lastIndex = 0
    for index in result.indices {
        if result[index].startMs >= markMs {
            result[index].interrupted = true
        }
        if result[index].startMs < markMs {
            lastIndex = index
        }
    }
    if !result.isEmpty {
        result[lastIndex].interrupted = true
    }
    return result
}

// MARK: - Generators (design.md "Property-Based Tests")

private let seed: UInt64 = 20261113
private let iterations = 500
private let vocabulary = [" ", "a", "the", "different", "。", "～", "团", "小"]
private let increments: [Int64] = [1, 80, 250]

/// SplitMix64 with a fixed seed, so every run sees the same inputs.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Value in 0..<bound.
    mutating func int(_ bound: Int) -> Int {
        Int(next() % UInt64(bound))
    }
}

private func generateMessages(_ random: inout SplitMix64) -> [[Word]] {
    let reference = generateReference(&random)
    var messages: [[Word]] = []
    for window in generateWindows(&random, reference) {
        messages.append(perturb(&random, window))
        if messages.count > 1 && random.int(5) == 0 {
            // Resend a whole earlier message.
            let earlier = messages[random.int(messages.count)]
            messages.append(earlier)
        }
    }
    return messages
}

/// Length 1-120, start_ms from 0, increments 0 (p = 0.3), 1, 80 or 250, (word, start_ms) unique.
private func generateReference(_ random: inout SplitMix64) -> [Word] {
    let length = 1 + random.int(120)
    var result: [Word] = []
    var startMs: Int64 = 0
    for index in 0..<length {
        if index > 0 {
            startMs += random.int(10) < 3 ? 0 : increments[random.int(increments.count)]
        }
        let current = startMs
        var choices = vocabulary.filter { text in
            !result.contains { $0.startMs == current && $0.text == text }
        }
        if choices.isEmpty {
            startMs += 1
            choices = vocabulary
        }
        result.append(w(choices[random.int(choices.count)], startMs))
    }
    return result
}

/// Windows of length 1-32; each start advances 1..window length; the last covers the end.
private func generateWindows(_ random: inout SplitMix64, _ reference: [Word]) -> [[Word]] {
    var windows: [[Word]] = []
    var start = 0
    while true {
        let end = min(start + 1 + random.int(32), reference.count)
        windows.append(Array(reference[start..<end]))
        if end == reference.count { return windows }
        start += 1 + random.int(end - start)
    }
}

/// Randomly adds a same-start different word and an in-message duplicate key, keeping order.
private func perturb(_ random: inout SplitMix64, _ window: [Word]) -> [Word] {
    var message = window
    if random.int(5) == 0 {
        let index = random.int(message.count)
        let anchor = message[index]
        let others = vocabulary.filter { $0 != anchor.text }
        message.insert(w(others[random.int(others.count)], anchor.startMs), at: index + 1)
    }
    if random.int(5) == 0 {
        let index = random.int(message.count)
        message.insert(message[index], at: index + 1)
    }
    return message
}

private func slidingWindows(_ sequence: [Word], size: Int, step: Int) -> [[Word]] {
    var windows: [[Word]] = []
    var start = 0
    while true {
        let end = min(start + size, sequence.count)
        windows.append(Array(sequence[start..<end]))
        if end == sequence.count { return windows }
        start += step
    }
}

// MARK: - Random K and M (Properties 4-6)

/// Random K and M for Properties 4 and 5, drawn from a design.md reference sequence L so words and
/// start_ms follow its rules. K: 0-40 draws from L with repetition, sorted by start_ms like the Swift
/// buffer (every message of a turn, including the first, is merged and sorted). Kotlin also tests an
/// unsorted K because its first message is stored as is (D3); Swift has no such K.
private func generateKeptAndIncoming(_ random: inout SplitMix64) -> (kept: [Word], incoming: [Word]) {
    let reference = generateReference(&random)
    let keptCount = random.int(41)
    let kept = drawSortedKept(&random, reference, count: keptCount)
    return (kept, generateIncoming(&random, reference, kept))
}

/// Random K and M for Property 6. K: 1-40 draws as above; the words from a random index on are
/// interrupted, the shape the Swift interrupt branch leaves on the sorted buffer (words at or after
/// the mark plus the last word before it).
private func generateInterruptedKeptAndIncoming(_ random: inout SplitMix64) -> (kept: [Word], incoming: [Word]) {
    let reference = generateReference(&random)
    let keptCount = 1 + random.int(40)
    var kept = drawSortedKept(&random, reference, count: keptCount)
    let suffixStart = random.int(kept.count)
    for index in kept.indices where index >= suffixStart {
        kept[index].interrupted = true
    }
    return (kept, generateIncoming(&random, reference, kept))
}

private func drawSortedKept(_ random: inout SplitMix64, _ reference: [Word], count: Int) -> [Word] {
    var kept: [Word] = []
    for _ in 0..<count {
        kept.append(reference[random.int(reference.count)])
    }
    return kept.sorted { $0.startMs < $1.startMs }
}

/// M: 0-32 words in message order, each a resend of a K word (p = 0.5) or a draw from L. Incoming
/// words are parsed in progress, so a resent interrupted word arrives not interrupted.
private func generateIncoming(_ random: inout SplitMix64, _ reference: [Word], _ kept: [Word]) -> [Word] {
    var incoming: [Word] = []
    for _ in 0..<random.int(33) {
        var word = !kept.isEmpty && random.int(2) == 0
            ? kept[random.int(kept.count)]
            : reference[random.int(reference.count)]
        word.interrupted = false
        incoming.append(word)
    }
    return incoming
}

/// Input shapes that the random K/M properties must exercise at least once.
private enum Shape: String {
    case emptyKept
    case emptyIncoming
    case keptKeyResent
    case newWordWithKeptStart
    case newWordsSameStartInMessage
    case newKeyRepeatedInMessage
    case keptWordBeforeFirstInterrupted
    case addedBeforeFirstInterrupted
    case addedWithFirstInterruptedStart
    case addedAfterFirstInterrupted
}

private let mergeShapesRequired: [Shape] = [
    .emptyKept, .emptyIncoming, .keptKeyResent, .newWordWithKeptStart, .newWordsSameStartInMessage,
    .newKeyRepeatedInMessage,
]

private let interruptShapesRequired: [Shape] = [
    .emptyIncoming, .keptKeyResent, .keptWordBeforeFirstInterrupted, .addedBeforeFirstInterrupted,
    .addedWithFirstInterruptedStart, .addedAfterFirstInterrupted,
]

private func mergeShapes(_ kept: [Word], _ incoming: [Word]) -> [Shape] {
    let added = addedWords(kept, incoming)
    var shapes: [Shape] = []
    if kept.isEmpty { shapes.append(.emptyKept) }
    if incoming.isEmpty { shapes.append(.emptyIncoming) }
    if incoming.contains(where: { word in kept.contains { sameKey($0, word) } }) { shapes.append(.keptKeyResent) }
    if added.contains(where: { word in kept.contains { $0.startMs == word.startMs } }) {
        shapes.append(.newWordWithKeptStart)
    }
    if hasSameStartDifferentWords(added) { shapes.append(.newWordsSameStartInMessage) }
    if added.indices.contains(where: { i in added[..<i].contains { sameKey($0, added[i]) } }) {
        shapes.append(.newKeyRepeatedInMessage)
    }
    return shapes
}

/// Where new words land relative to the first interrupted word of the sorted K. A new word with the
/// same start_ms lands after it, because kept words come first within one start_ms (the U6 shape).
private func interruptShapes(_ kept: [Word], _ incoming: [Word]) -> [Shape] {
    var shapes: [Shape] = []
    if incoming.isEmpty { shapes.append(.emptyIncoming) }
    if incoming.contains(where: { word in kept.contains { sameKey($0, word) } }) { shapes.append(.keptKeyResent) }
    guard let first = kept.first(where: { $0.interrupted }) else { return shapes }
    if kept.first?.interrupted == false { shapes.append(.keptWordBeforeFirstInterrupted) }
    let added = addedWords(kept, incoming)
    if added.contains(where: { $0.startMs < first.startMs }) { shapes.append(.addedBeforeFirstInterrupted) }
    if added.contains(where: { $0.startMs == first.startMs }) { shapes.append(.addedWithFirstInterruptedStart) }
    if added.contains(where: { $0.startMs > first.startMs }) { shapes.append(.addedAfterFirstInterrupted) }
    return shapes
}

private func count(_ shapes: [Shape], into coverage: inout [Shape: Int]) {
    for shape in shapes {
        coverage[shape, default: 0] += 1
    }
}

/// Prints the coverage, then fails on the first failing input or on a required shape that never occurred.
private func reportRandomRun(
    _ name: String, _ coverage: [Shape: Int], required: [Shape], failures: Int, firstFailure: String?
) {
    let counts = required.map { "\($0.rawValue)=\(coverage[$0] ?? 0)" }.joined(separator: " ")
    print("\(name): seed=\(seed) iterations=\(iterations) \(counts)")
    expect(firstFailure == nil, "\(name): \(failures) of \(iterations) inputs failed; first: " + (firstFailure ?? ""))
    for shape in required {
        expect((coverage[shape] ?? 0) > 0, "\(name): generator produced no \(shape.rawValue) input")
    }
}

/// Dedup key (word, start_ms), compared field by field.
private struct Key: Hashable {
    let text: String
    let startMs: Int64
}

private func key(_ word: Word) -> Key {
    Key(text: word.text, startMs: word.startMs)
}

private func sameKey(_ lhs: Word, _ rhs: Word) -> Bool {
    lhs.text == rhs.text && lhs.startMs == rhs.startMs
}

/// Test-local copy of the dedup rule: words of M whose key is not in K, in message order.
private func addedWords(_ kept: [Word], _ incoming: [Word]) -> [Word] {
    incoming.filter { word in !kept.contains { sameKey($0, word) } }
}

private func keyCounts(_ words: [Word]) -> [Key: Int] {
    words.reduce(into: [:]) { counts, word in counts[key(word), default: 0] += 1 }
}

/// Keys in first-occurrence order, so the reported mismatch does not depend on hash order.
private func orderedKeys(_ words: [Word]) -> [Key] {
    var seen = Set<Key>()
    return words.map(key).filter { seen.insert($0).inserted }
}

private func formatKey(_ key: Key) -> String {
    "\(key.text == " " ? "␠" : key.text)@\(key.startMs)"
}

/// Property 4 check; returns a description of the first key whose count is wrong.
private func keyCountMismatch(_ kept: [Word], _ incoming: [Word], _ result: [Word]) -> String? {
    let keptCounts = keyCounts(kept)
    let incomingCounts = keyCounts(incoming)
    let resultCounts = keyCounts(result)
    for dedupKey in orderedKeys(kept) {
        let expected = keptCounts[dedupKey] ?? 0
        let actual = resultCounts[dedupKey] ?? 0
        if actual != expected { return "key \(formatKey(dedupKey)) in K: K=\(expected) result=\(actual)" }
    }
    for dedupKey in orderedKeys(incoming) where keptCounts[dedupKey] == nil {
        let expected = incomingCounts[dedupKey] ?? 0
        let actual = resultCounts[dedupKey] ?? 0
        if actual != expected { return "key \(formatKey(dedupKey)) only in M: M=\(expected) result=\(actual)" }
    }
    for dedupKey in orderedKeys(result) where keptCounts[dedupKey] == nil && incomingCounts[dedupKey] == nil {
        return "key \(formatKey(dedupKey)) in neither K nor M"
    }
    return nil
}

/// Property 6 check. The word sequence must equal expectedMerge (K keeps its states, new words are
/// in progress). Every word after the first interrupted word must be interrupted; the words up to
/// it keep their state.
private func interruptInheritanceMismatch(_ kept: [Word], _ incoming: [Word], _ result: [Word]) -> String? {
    let base = expectedMerge(kept, incoming)
    guard sameWords(result, base) else { return "word sequence differs from expectedMerge=\(format(base))" }
    guard let first = base.firstIndex(where: { $0.interrupted }) else {
        return "K has no interrupted word (generator error)"
    }
    for index in result.indices {
        let expected = index > first || base[index].interrupted
        if result[index].interrupted != expected {
            return "index \(index) \(format([result[index]])): expected interrupted=\(expected), "
                + "first interrupted index=\(first)"
        }
    }
    return nil
}

// MARK: - U5 data

private let u5Texts = [
    "So", "let", "me", "tell", "you", "about", "the", "plan", "for", "today",
    "a", "classic", "walk", "in", "the", "park", "then", "lunch", "at", "noon",
    "and", "after", "that", "we", "can", "visit", "the", "museum", "or", "try",
    "something", "a", "different", "like", "the", "river", "a", "bit", "later", "tonight",
]

/// Words that share start_ms with the zero-duration word before them. With windows of 32
/// advancing by 3: 10/11 are inside the first window, 31/32 straddle its end (32 first arrives in
/// the second window), 36/37 first arrive together in the third window.
private let u5SameStartAsPrevious: Set<Int> = [11, 32, 37]

private let u5Sequence: [Word] = {
    var startMs: Int64 = 1000
    var result: [Word] = []
    for (index, text) in u5Texts.enumerated() {
        if index > 0 && !u5SameStartAsPrevious.contains(index) { startMs += 80 }
        result.append(w(text, startMs))
    }
    return result
}()

/// The U5 words with distinct start_ms (+80 each): no two words share a start time.
private let plainSequence: [Word] = u5Texts.enumerated().map { w($0.element, 1000 + Int64($0.offset) * 80) }

// MARK: - Assertions and formatting

private func sameWords(_ lhs: [Word], _ rhs: [Word]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.text == $1.text && $0.startMs == $1.startMs }
}

private func expectWords(_ actual: [Word], _ expected: [Word], _ message: String) {
    expect(
        sameWords(actual, expected),
        "\(message)\n  expected: \(format(expected))\n  actual:   \(format(actual))"
    )
}

private func expectText(_ actual: [Word], _ expected: String, _ message: String) {
    let text = actual.map { $0.text }.joined()
    expect(text == expected, "\(message): expected text \"\(expected)\", actual \"\(text)\"")
}

private func expectWordsAndStatus(_ actual: [Word], _ expected: [Word], _ message: String) {
    expect(
        actual == expected,
        "\(message)\n  expected: \(format(expected))\n  actual:   \(format(actual))"
    )
}

/// `␠` is a space word; `(I)` marks an interrupted word.
private func format(_ words: [Word]) -> String {
    words.map { "\($0.text == " " ? "␠" : $0.text)@\($0.startMs)\($0.interrupted ? "(I)" : "")" }
        .joined(separator: ", ")
}

private func formatMessages(_ messages: [[Word]]) -> String {
    messages.enumerated().map { "  M\($0.offset): \(format($0.element))" }.joined(separator: "\n")
}

@main
private struct TranscriptWordMergeTests {
    /// Runs every case by default; pass case names to run only those.
    static func main() {
        let cases: [(name: String, run: () -> Void)] = [
            ("u1", testU1CrossMessageWordWithKeptStartIsKept),
            ("u5", testU5OverlappingWindowsRestoreSequence),
            ("u6", testU6SameStartWordAfterInterruptIsKeptAndInterrupted),
            ("u6b", testU6bWordsArrivingAfterInterruptAreInterrupted),
            ("generated-bug-condition", testGeneratedBugConditionSequencesMatchExpectedMerge),
            ("u2a", testU2aSameStartWordsInOneUpdateMessageAreKept),
            ("u2b", testU2bSameStartWordsInFirstMessageAreKept),
            ("u3", testU3OverlappingResendAddsOnlyNewWords),
            ("u4a", testU4aChineseFirstMessageKeepsSameStartWords),
            ("u4b", testU4bChineseUpdateMessageKeepsSameStartWords),
            ("u7", testU7SameKeyFirstSeenInLaterMessageIsStillDropped),
            ("plain-windows", testPlainOverlappingWindowsRestoreSequence),
            ("generated-preservation", testGeneratedNonBugSequencesMatchReferenceMerge),
            ("property3-overlapping-windows", testProperty3OverlappingWindowsRestoreReference),
            ("property4-key-counts", testProperty4DedupKeyCountsArePreserved),
            ("property5-stable-order", testProperty5ResultIsStableSortOfKeptThenAdded),
            ("property6-interrupt-inheritance", testProperty6WordsAfterFirstInterruptedAreInterrupted),
            ("inherit-none", testInheritInterruptedWithoutInterruptedWordChangesNothing),
            ("inherit-first", testInheritInterruptedFromFirstWordMarksEveryWord),
            ("inherit-last", testInheritInterruptedOnLastWordMarksOnlyLastWord),
        ]
        let names = cases.map { $0.name }
        let selected = Array(CommandLine.arguments.dropFirst())
        let unknown = selected.filter { !names.contains($0) }
        expect(unknown.isEmpty, "unknown case(s) \(unknown); available: \(names.joined(separator: ", "))")

        let toRun = cases.filter { selected.isEmpty || selected.contains($0.name) }
        for testCase in toRun {
            testCase.run()
        }
        print("TranscriptWordMergeTests passed: \(toRun.map { $0.name }.joined(separator: ", "))")
    }
}
