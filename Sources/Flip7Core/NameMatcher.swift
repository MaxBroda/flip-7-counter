struct NameMatcher<Candidate> {
    private let candidates: [(candidate: Candidate, key: String)]
    private let name: (Candidate) -> String

    init(_ candidates: [Candidate], name: @escaping (Candidate) -> PlayerName) {
        self.candidates = candidates.map { ($0, name($0).key) }
        self.name = { name($0).key }
    }

    var hasMultiWordNames: Bool { candidates.contains { $0.key.contains(" ") } }

    func match(_ spoken: String) -> Candidate? {
        let token = PlayerName.normalize(spoken)
        guard token.count >= 2 else { return nil }
        let scored = candidates.compactMap { entry in score(token, against: entry.key).map { (entry.candidate, $0) } }
        guard let best = scored.map(\.1).min() else { return nil }
        let winners = scored.filter { $0.1 == best }
        let distinctKeys = Set(winners.map { name($0.0) })
        return distinctKeys.count == 1 ? winners[0].0 : nil
    }

    private func score(_ token: String, against key: String) -> Int? {
        if token == key { return 0 }
        if !Set(soundAlikes(token).map(ColognePhonetics.code)).isDisjoint(with: soundAlikes(key).map(ColognePhonetics.code)) { return 1 }
        let distance = levenshtein(token, key)
        if distance <= (min(token.count, key.count) <= 4 ? 1 : 2) { return 1 + distance }
        if min(token.count, key.count) >= 3, key.hasPrefix(token) || token.hasPrefix(key) { return 4 }
        return nil
    }

    // German speakers vocalize a final "-er" as "-a" ("Leser" ≈ "Lisa").
    private func soundAlikes(_ word: String) -> [String] {
        word.hasSuffix("er") ? [word, String(word.dropLast(2)) + "a"] : [word]
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var diagonal = row[0]
            row[0] = i
            for j in 1...b.count {
                let above = row[j]
                row[j] = a[i - 1] == b[j - 1] ? diagonal : min(diagonal, above, row[j - 1]) + 1
                diagonal = above
            }
        }
        return row[b.count]
    }
}
