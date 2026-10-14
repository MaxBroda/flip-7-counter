import Testing
@testable import Flip7Core

@Suite struct PauseSegmenterTests {
    private let rate = 1000.0

    private func audio(_ parts: [(seconds: Double, loud: Bool)]) -> [Float] {
        parts.flatMap { part in
            (0..<Int(part.seconds * rate)).map { index in
                part.loud ? (index % 2 == 0 ? 0.3 : -0.3) : (index % 2 == 0 ? 0.001 : -0.001)
            }
        }
    }

    @Test func splitsAtPauses() {
        let samples = audio([(0.5, false), (0.4, true), (0.6, false), (0.3, true), (0.5, false)])
        let segments = PauseSegmenter(sampleRate: rate).segments(in: samples)
        #expect(segments.count == 2)
        #expect(segments[0].contains(700))
        #expect(segments[1].contains(1650))
    }

    @Test func keepsShortGapsTogether() {
        let samples = audio([(0.5, false), (0.4, true), (0.1, false), (0.4, true), (0.5, false)])
        #expect(PauseSegmenter(sampleRate: rate).segments(in: samples).count == 1)
    }

    @Test func ignoresSilence() {
        #expect(PauseSegmenter(sampleRate: rate).segments(in: audio([(2, false)])).isEmpty)
    }
}
