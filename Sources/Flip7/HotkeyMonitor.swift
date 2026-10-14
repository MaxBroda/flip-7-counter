import AppKit

final class HotkeyMonitor {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    var yieldsToTextInput: () -> Bool = { true }
    var capture: ((NSEvent) -> Void)?

    private let hotkey: () -> Hotkey
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var isHeld = false

    init(hotkey: @escaping () -> Hotkey) {
        self.hotkey = hotkey
    }

    func install() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.endEditingIfClickedOutside(event)
            return event
        }
    }

    deinit {
        [keyMonitor, clickMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        if let capture, event.type == .keyDown {
            self.capture = nil
            capture(event)
            return nil
        }
        guard event.keyCode == hotkey().keyCode else { return event }
        if event.type == .keyUp {
            guard isHeld else { return event }
            isHeld = false
            onRelease()
            return nil
        }
        if editor(in: event.window) != nil {
            guard !yieldsToTextInput() else { return event }
            event.window?.makeFirstResponder(nil)
        }
        if !event.isARepeat && !isHeld {
            isHeld = true
            onPress()
        }
        return nil
    }

    private func endEditingIfClickedOutside(_ event: NSEvent) {
        guard let window = event.window, let editor = editor(in: window) else { return }
        let field = (editor.delegate as? NSView) ?? editor
        if !field.convert(field.bounds, to: nil).contains(event.locationInWindow) {
            window.makeFirstResponder(nil)
        }
    }

    private func editor(in window: NSWindow?) -> NSTextView? {
        guard let editor = window?.firstResponder as? NSTextView, editor.isEditable else { return nil }
        return editor
    }
}
