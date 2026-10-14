enum GermanNumber {
    private static let words: [String: Int] = [
        "null": 0, "ein": 1, "eins": 1, "eine": 1, "einen": 1, "zwei": 2, "zwo": 2, "drei": 3, "vier": 4,
        "funf": 5, "sechs": 6, "sieben": 7, "acht": 8, "neun": 9, "nein": 9, "zehn": 10, "elf": 11, "zwolf": 12,
        "dreizehn": 13, "vierzehn": 14, "funfzehn": 15, "sechzehn": 16, "siebzehn": 17, "achtzehn": 18,
        "neunzehn": 19, "zwanzig": 20, "dreissig": 30, "vierzig": 40, "funfzig": 50, "sechzig": 60,
        "siebzig": 70, "achtzig": 80, "neunzig": 90,
    ]

    static let spokenForms: [String] = {
        let units = ["ein", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun"]
        let tens = ["zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"]
        let small = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn", "elf", "zwölf",
                     "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn"]
        return small + tens + tens.flatMap { ten in units.map { $0 + "und" + ten } } + ["hundert", "verzockt"]
    }()

    static let bustWords: Set<String> = ["nichts", "nix", "verzockt", "raus", "keine", "kein", "bust", "zero"]

    static func parse(_ token: String) -> Int? {
        if let digits = Int(token) { return digits }
        if bustWords.contains(token) { return 0 }
        return parseWord(token)
    }

    static func isTens(_ value: Int) -> Bool {
        (20...90).contains(value) && value % 10 == 0
    }

    private static func parseWord(_ word: String) -> Int? {
        if let value = words[word] { return value }
        for prefix in ["einhundert", "hundert"] where word.hasPrefix(prefix) {
            let rest = String(word.dropFirst(prefix.count))
            if rest.isEmpty { return 100 }
            let tail = rest.hasPrefix("und") ? String(rest.dropFirst(3)) : rest
            return parseWord(tail).map { 100 + $0 }
        }
        guard let range = word.range(of: "und") else { return nil }
        guard let unit = words[String(word[..<range.lowerBound])], (1...9).contains(unit),
              let tens = words[String(word[range.upperBound...])], isTens(tens)
        else { return nil }
        return tens + unit
    }
}
