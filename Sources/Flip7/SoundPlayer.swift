import AppKit

struct SoundPlayer {
    enum Cue {
        case listenStart
        case listenEnd
        case book
        case undo
        case win
        case tie
    }

    let isEnabled: () -> Bool

    func play(_ cue: Cue) {
        guard isEnabled() else { return }
        sound(for: cue)?.play()
    }

    private func sound(for cue: Cue) -> NSSound? {
        switch cue {
        case .listenStart: NSSound(data: Self.rising)
        case .listenEnd: NSSound(data: Self.falling)
        case .book: NSSound(named: "Pop")
        case .undo: NSSound(named: "Bottle")
        case .win: NSSound(named: "Hero")
        case .tie: NSSound(named: "Purr")
        }
    }

    private static let rising = Tone.chirp([784, 1175])
    private static let falling = Tone.chirp([1175, 784])
}

private enum Tone {
    private static let sampleRate = 44_100.0

    static func chirp(_ frequencies: [Double], noteLength: Double = 0.07, volume: Double = 0.28) -> Data {
        let perNote = Int(sampleRate * noteLength)
        let samples = frequencies.flatMap { frequency in
            (0..<perNote).map { index -> Int16 in
                let t = Double(index) / sampleRate
                let attack = min(1, Double(index) / (sampleRate * 0.004))
                let decay = pow(1 - Double(index) / Double(perNote), 1.6)
                let wave = sin(2 * .pi * frequency * t) + 0.25 * sin(4 * .pi * frequency * t)
                return Int16(wave / 1.25 * attack * decay * volume * Double(Int16.max))
            }
        }
        return wav(samples)
    }

    private static func wav(_ samples: [Int16]) -> Data {
        let payload = samples.count * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + payload))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate) * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(payload))
        samples.forEach(append)
        return data
    }
}
