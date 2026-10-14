import AppKit

struct SoundPlayer {
    enum Cue: String {
        case listen = "Tink"
        case book = "Pop"
        case undo = "Bottle"
        case win = "Hero"
        case tie = "Purr"
    }

    let isEnabled: () -> Bool

    func play(_ cue: Cue) {
        guard isEnabled() else { return }
        NSSound(named: NSSound.Name(cue.rawValue))?.play()
    }
}
