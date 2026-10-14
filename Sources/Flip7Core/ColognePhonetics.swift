enum ColognePhonetics {
    static func code(_ text: String) -> String {
        let letters = Array(text.uppercased().filter(\.isLetter))
        var digits: [Character] = []
        for (index, letter) in letters.enumerated() {
            let previous: Character? = index > 0 ? letters[index - 1] : nil
            let next: Character? = index + 1 < letters.count ? letters[index + 1] : nil
            digits.append(contentsOf: Self.digits(for: letter, previous: previous, next: next, isFirst: index == 0))
        }
        var collapsed: [Character] = []
        for digit in digits where collapsed.last != digit {
            collapsed.append(digit)
        }
        guard let first = collapsed.first else { return "" }
        return String(first) + String(collapsed.dropFirst().filter { $0 != "0" })
    }

    private static func digits(for letter: Character, previous: Character?, next: Character?, isFirst: Bool) -> [Character] {
        let nextIn = { (set: String) in next.map(set.contains) ?? false }
        let previousIn = { (set: String) in previous.map(set.contains) ?? false }
        switch letter {
        case "A", "E", "I", "J", "O", "U", "Y", "Ä", "Ö", "Ü": return ["0"]
        case "H": return []
        case "B": return ["1"]
        case "P": return nextIn("H") ? ["3"] : ["1"]
        case "D", "T": return nextIn("CSZß") ? ["8"] : ["2"]
        case "F", "V", "W": return ["3"]
        case "G", "K", "Q": return ["4"]
        case "C":
            if isFirst { return nextIn("AHKLOQRUX") ? ["4"] : ["8"] }
            return nextIn("AHKOQUX") && !previousIn("SZ") ? ["4"] : ["8"]
        case "X": return previousIn("CKQ") ? ["8"] : ["4", "8"]
        case "L": return ["5"]
        case "M", "N": return ["6"]
        case "R": return ["7"]
        case "S", "Z", "ß": return ["8"]
        default: return []
        }
    }
}
