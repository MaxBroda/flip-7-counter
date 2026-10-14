import AppKit

final class HotkeyMonitor {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    var capture: ((NSEvent) -> Void)?

    private let hotkey: () -> Hotkey
    private var monitor: Any?
    private var isHeld = false

    init(hotkey: @escaping () -> Hotkey) {
        self.hotkey = hotkey
    }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if let capture, event.type == .keyDown {
            self.capture = nil
            capture(event)
            return nil
        }
        guard event.keyCode == hotkey().keyCode, !isEditingText(in: event.window) else { return event }
        switch event.type {
        case .keyDown where !event.isARepeat && !isHeld:
            isHeld = true
            onPress()
        case .keyUp where isHeld:
            isHeld = false
            onRelease()
        default:
            break
        }
        return nil
    }

    private func isEditingText(in window: NSWindow?) -> Bool {
        (window?.firstResponder as? NSTextView)?.isEditable ?? false
    }
}
