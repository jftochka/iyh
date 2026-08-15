import Carbon
import Foundation

struct KeyboardLayout {
    let source: TISInputSource
    let id: String
    let name: String
}

struct LayoutConversion {
    let text: String
    let source: KeyboardLayout
    let target: KeyboardLayout
}

@MainActor
final class KeyboardLayoutService {
    private struct KeyStroke {
        let keyCode: UInt16
        let modifiers: UInt32
    }

    func availableLayouts() -> [KeyboardLayout] {
        guard let unmanagedSources = TISCreateInputSourceList(nil, false) else {
            return []
        }

        let sources = unmanagedSources.takeRetainedValue() as NSArray
        var result: [KeyboardLayout] = []
        var seenIDs = Set<String>()

        for case let source as TISInputSource in sources {
            guard booleanProperty(source, kTISPropertyInputSourceIsEnabled),
                  booleanProperty(source, kTISPropertyInputSourceIsSelectCapable),
                  property(source, kTISPropertyUnicodeKeyLayoutData) != nil,
                  let id = stringProperty(source, kTISPropertyInputSourceID),
                  let name = stringProperty(source, kTISPropertyLocalizedName),
                  seenIDs.insert(id).inserted else {
                continue
            }

            result.append(KeyboardLayout(source: source, id: id, name: name))
        }

        return result
    }

    func currentLayoutID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return stringProperty(source, kTISPropertyInputSourceID)
    }

    func convertToNextLayout(_ text: String) throws -> LayoutConversion {
        let layouts = availableLayouts()
        guard layouts.count >= 2 else {
            throw IYHError.notEnoughLayouts
        }

        guard let currentID = currentLayoutID(),
              let sourceIndex = layouts.firstIndex(where: { $0.id == currentID }) else {
            throw IYHError.currentLayoutUnavailable
        }

        let source = layouts[sourceIndex]
        let target = layouts[(sourceIndex + 1) % layouts.count]
        let converted = convert(text, from: source, to: target)

        return LayoutConversion(text: converted, source: source, target: target)
    }

    func select(_ layout: KeyboardLayout) throws {
        let status = TISSelectInputSource(layout.source)
        guard status == noErr else {
            throw IYHError.cannotSelectLayout(status)
        }
    }

    func convert(_ text: String, from source: KeyboardLayout, to target: KeyboardLayout) -> String {
        let sourceIndex = keyIndex(for: source)
        var result = ""
        result.reserveCapacity(text.count)

        for character in text {
            let original = String(character)
            let normalized = original.precomposedStringWithCanonicalMapping
            guard let stroke = sourceIndex[original] ?? sourceIndex[normalized],
                  let translated = translate(
                    layout: target,
                    keyCode: stroke.keyCode,
                    modifiers: stroke.modifiers
                  ),
                  !translated.isEmpty else {
                result.append(contentsOf: original)
                continue
            }
            result.append(contentsOf: translated)
        }

        return result
    }

    private func keyIndex(for layout: KeyboardLayout) -> [String: KeyStroke] {
        let modifierVariants: [UInt32] = [
            0,
            UInt32(shiftKey),
            UInt32(optionKey),
            UInt32(shiftKey | optionKey)
        ]
        var index: [String: KeyStroke] = [:]

        for modifiers in modifierVariants {
            for keyCode in UInt16(0)..<UInt16(128) {
                guard let output = translate(
                    layout: layout,
                    keyCode: keyCode,
                    modifiers: modifiers
                ), !output.isEmpty else {
                    continue
                }

                let normalized = output.precomposedStringWithCanonicalMapping
                let stroke = KeyStroke(keyCode: keyCode, modifiers: modifiers)
                if index[output] == nil {
                    index[output] = stroke
                }
                if index[normalized] == nil {
                    index[normalized] = stroke
                }
            }
        }

        return index
    }

    private func translate(
        layout: KeyboardLayout,
        keyCode: UInt16,
        modifiers: UInt32
    ) -> String? {
        guard let pointer = property(layout.source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let keyboardLayout = UnsafeRawPointer(bytes)
            .assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var actualLength = 0
        var buffer = [UniChar](repeating: 0, count: 16)

        let status = buffer.withUnsafeMutableBufferPointer { characters in
            UCKeyTranslate(
                keyboardLayout,
                keyCode,
                UInt16(kUCKeyActionDown),
                modifiers >> 8,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &actualLength,
                characters.baseAddress
            )
        }

        guard status == noErr, actualLength > 0 else {
            return nil
        }

        return buffer.withUnsafeBufferPointer { characters in
            String(utf16CodeUnits: characters.baseAddress!, count: actualLength)
        }
    }

    private func property(_ source: TISInputSource, _ key: CFString) -> UnsafeMutableRawPointer? {
        TISGetInputSourceProperty(source, key)
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = property(source, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private func booleanProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = property(source, key) else {
            return false
        }
        let value = Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue()
        return CFBooleanGetValue(value)
    }
}
