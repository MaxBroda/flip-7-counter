public struct PauseSegmenter: Sendable {
    private let frameLength: Int
    private let minimumPauseFrames = 15
    private let minimumVoicedFrames = 4
    private let paddingFrames = 8
    private let smoothingFrames = 2
    private let voiceToFloorRatio: Float = 4
    private let quietestFloor: Float = 0.0001

    public init(sampleRate: Double) {
        frameLength = max(1, Int(sampleRate * 0.02))
    }

    public func segments(in samples: [Float]) -> [Range<Int>] {
        let levels = smoothed(stride(from: 0, to: samples.count, by: frameLength).map { start in
            let frame = samples[start..<min(start + frameLength, samples.count)]
            return (frame.reduce(0) { $0 + $1 * $1 } / Float(frame.count)).squareRoot()
        })
        guard !levels.isEmpty else { return [] }
        let floor = max(levels.sorted()[levels.count / 10], quietestFloor)
        var voiced: [Range<Int>] = []
        var start: Int?
        var pause = 0
        for (index, level) in levels.enumerated() {
            if level > floor * voiceToFloorRatio {
                if start == nil { start = index }
                pause = 0
            } else if let begin = start {
                pause += 1
                if pause >= minimumPauseFrames {
                    voiced.append(begin..<(index - pause + 1))
                    start = nil
                    pause = 0
                }
            }
        }
        if let start { voiced.append(start..<levels.count) }
        return voiced
            .filter { $0.count >= minimumVoicedFrames }
            .map { max(0, ($0.lowerBound - paddingFrames) * frameLength)..<min(samples.count, ($0.upperBound + paddingFrames) * frameLength) }
    }

    private func smoothed(_ levels: [Float]) -> [Float] {
        levels.indices.map { index in
            let window = levels[max(0, index - smoothingFrames)...min(levels.count - 1, index + smoothingFrames)]
            return window.reduce(0, +) / Float(window.count)
        }
    }
}
