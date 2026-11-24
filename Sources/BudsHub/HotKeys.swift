import AppKit
import BudsKit
import Carbon.HIToolbox
import SwiftUI

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    var display: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + Self.keyName(keyCode)
    }

    static func keyName(_ code: UInt32) -> String {
        let special: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
            kVK_F19: "F19", kVK_F20: "F20"
        ]
        if let name = special[Int(code)] { return name }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return "?" }
            var deadKey: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                           OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKey, 4, &length, &chars)
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }

    static func isFunctionKey(_ code: UInt16) -> Bool {
        [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
         kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
            .contains(Int(code))
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable, Codable {
    case cycle, anc, ambient, off, adaptive, find, takeAudio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cycle: return "Cycle noise control"
        case .anc: return "Noise cancellation"
        case .ambient: return "Ambient sound"
        case .off: return "Noise control off"
        case .adaptive: return "Adaptive"
        case .find: return "Find my earbuds"
        case .takeAudio: return "Use this Mac for audio"
        }
    }

    var symbol: String {
        switch self {
        case .cycle: return "arrow.triangle.2.circlepath"
        case .anc: return NoiseMode.anc.symbol
        case .ambient: return NoiseMode.ambient.symbol
        case .off: return NoiseMode.off.symbol
        case .adaptive: return NoiseMode.adaptive.symbol
        case .find: return "dot.radiowaves.left.and.right"
        case .takeAudio: return "hifispeaker.2"
        }
    }

    var defaultShortcut: Shortcut? {
        let controlOption = NSEvent.ModifierFlags([.control, .option]).rawValue
        switch self {
        case .cycle: return Shortcut(keyCode: UInt32(kVK_ANSI_N), modifiers: controlOption)
        case .anc: return Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: controlOption)
        case .ambient: return Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: controlOption)
        case .off: return Shortcut(keyCode: UInt32(kVK_ANSI_O), modifiers: controlOption)
        case .adaptive: return Shortcut(keyCode: UInt32(kVK_ANSI_D), modifiers: controlOption)
        case .find: return Shortcut(keyCode: UInt32(kVK_ANSI_F), modifiers: controlOption)
        case .takeAudio: return Shortcut(keyCode: UInt32(kVK_ANSI_M), modifiers: controlOption)
        }
    }
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false

    @discardableResult
    func register(id: UInt32, shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        unregister(id: id)
        guard installHandler() else { return false }
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4255_4448), id: id) // 'BUDH'
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        handlers[id] = action
        return true
    }

    func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        handlers[id] = nil
    }

    func unregisterAll() {
        for id in refs.keys { unregister(id: id) }
    }

    @discardableResult
    private func installHandler() -> Bool {
        guard !handlerInstalled else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async { HotKeyCenter.shared.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
        guard status == noErr else { return false }
        handlerInstalled = true
        return true
    }
}

@MainActor
private final class ShortcutRecorderRegistry {
    static let shared = ShortcutRecorderRegistry()
    private var activeID: UUID?
    private var activeStop: (() -> Void)?

    func begin(id: UUID, stop: @escaping () -> Void) {
        if activeID != id { activeStop?() }
        activeID = id
        activeStop = stop
    }

    func end(id: UUID) {
        if activeID == id {
            activeID = nil
            activeStop = nil
        }
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var id = UUID()
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? "Type shortcut…" : (shortcut?.display ?? "Record Shortcut"))
                    .font(shortcut == nil || recording ? .callout : .callout.monospaced())
                    .foregroundStyle(recording ? Color.accentColor : (shortcut == nil ? .secondary : .primary))
                    .frame(minWidth: 120)
            }
            .buttonStyle(.glass)

            if shortcut != nil && !recording {
                Button { shortcut = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .help("Clear shortcut")
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        ShortcutRecorderRegistry.shared.begin(id: id) { stop() }
        recording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            switch Int(event.keyCode) {
            case kVK_Escape where mods.isEmpty:
                stop()
            case kVK_Delete where mods.isEmpty:
                shortcut = nil
                stop()
            default:
                if mods.isEmpty && !Shortcut.isFunctionKey(event.keyCode) {
                    NSSound.beep()
                } else {
                    shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods.rawValue)
                    stop()
                }
            }
            return nil
        }
    }

    private func stop() {
        ShortcutRecorderRegistry.shared.end(id: id)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { onRecordingChange(false) }
        recording = false
    }
}
