import ApplicationServices
import Foundation

struct ReplacementSuccess {
    let sourceName: String
    let targetName: String
    let convertedText: String
}

@MainActor
final class TextReplacementService {
    private struct PreviousConversion {
        let processID: pid_t
        let range: CFRange
        let replacement: String
        let expectedCaret: Int
        let createdAt: Date
    }

    private let layouts: KeyboardLayoutService
    private var previousConversion: PreviousConversion?

    init(layouts: KeyboardLayoutService) {
        self.layouts = layouts
    }

    func convertFocusedText() throws -> ReplacementSuccess {
        guard AXIsProcessTrusted() else {
            throw IYHError.accessibilityRequired
        }

        let element = try focusedElement()
        if stringAttribute(element, kAXSubroleAttribute as CFString) == kAXSecureTextFieldSubrole as String {
            throw IYHError.secureTextField
        }

        guard let value = stringAttribute(element, kAXValueAttribute as CFString),
              let selectedRange = rangeAttribute(element, kAXSelectedTextRangeAttribute as CFString) else {
            throw IYHError.noFocusedText
        }

        var processID: pid_t = 0
        AXUIElementGetPid(element, &processID)

        let targetRange: CFRange
        let caretBeforeReplacement: Int
        let hadSelection = selectedRange.length > 0

        if hadSelection {
            targetRange = selectedRange
            caretBeforeReplacement = selectedRange.location + selectedRange.length
        } else if let previous = reusablePreviousConversion(
            processID: processID,
            value: value,
            caret: selectedRange.location
        ) {
            targetRange = previous.range
            caretBeforeReplacement = selectedRange.location
        } else {
            guard let wordRange = TextTargeting.previousTokenRange(
                in: value,
                caret: selectedRange.location
            ) else {
                throw IYHError.noTextBeforeCursor
            }
            targetRange = wordRange
            caretBeforeReplacement = selectedRange.location
        }

        guard let sourceText = TextTargeting.substring(value, range: targetRange) else {
            throw IYHError.noFocusedText
        }

        let conversion = try layouts.convertToNextLayout(sourceText)
        try replace(
            in: element,
            range: targetRange,
            with: conversion.text,
            caretBeforeReplacement: caretBeforeReplacement,
            hadSelection: hadSelection
        )
        try layouts.select(conversion.target)

        let replacementLength = (conversion.text as NSString).length
        let caretAfterReplacement: Int
        if hadSelection {
            caretAfterReplacement = targetRange.location + replacementLength
        } else {
            caretAfterReplacement = caretBeforeReplacement + replacementLength - targetRange.length
        }

        previousConversion = PreviousConversion(
            processID: processID,
            range: CFRange(location: targetRange.location, length: replacementLength),
            replacement: conversion.text,
            expectedCaret: caretAfterReplacement,
            createdAt: Date()
        )

        return ReplacementSuccess(
            sourceName: conversion.source.name,
            targetName: conversion.target.name,
            convertedText: conversion.text
        )
    }

    private func focusedElement() throws -> AXUIElement {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )
        guard status == .success, let value else {
            throw IYHError.noFocusedText
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func reusablePreviousConversion(
        processID: pid_t,
        value: String,
        caret: Int
    ) -> PreviousConversion? {
        guard let previous = previousConversion,
              previous.processID == processID,
              previous.expectedCaret == caret,
              Date().timeIntervalSince(previous.createdAt) <= 8,
              TextTargeting.substring(value, range: previous.range) == previous.replacement else {
            return nil
        }
        return previous
    }

    private func replace(
        in element: AXUIElement,
        range: CFRange,
        with replacement: String,
        caretBeforeReplacement: Int,
        hadSelection: Bool
    ) throws {
        try setRange(range, on: element)

        let status = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFString
        )
        guard status == .success else {
            throw IYHError.textCannotBeEdited
        }

        let replacementLength = (replacement as NSString).length
        let caret: Int
        if hadSelection {
            caret = range.location + replacementLength
        } else {
            caret = caretBeforeReplacement + replacementLength - range.length
        }
        try setRange(CFRange(location: caret, length: 0), on: element)
    }

    private func setRange(_ range: CFRange, on element: AXUIElement) throws {
        var mutableRange = range
        guard let value = AXValueCreate(.cfRange, &mutableRange) else {
            throw IYHError.textCannotBeEdited
        }
        let status = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            value
        )
        guard status == .success else {
            throw IYHError.textCannotBeEdited
        }
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func rangeAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }
        return range
    }
}
