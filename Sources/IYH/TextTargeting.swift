import Foundation

enum TextTargeting {
    static func previousTokenRange(in value: String, caret: Int) -> CFRange? {
        let text = value as NSString
        var cursor = min(max(caret, 0), text.length)

        while cursor > 0 {
            let range = text.rangeOfComposedCharacterSequence(at: cursor - 1)
            let character = text.substring(with: range)
            guard isWhitespace(character) else {
                break
            }
            cursor = range.location
        }

        let end = cursor
        while cursor > 0 {
            let range = text.rangeOfComposedCharacterSequence(at: cursor - 1)
            let character = text.substring(with: range)
            if isWhitespace(character) {
                break
            }
            cursor = range.location
        }

        guard cursor < end else {
            return nil
        }
        return CFRange(location: cursor, length: end - cursor)
    }

    static func substring(_ value: String, range: CFRange) -> String? {
        let text = value as NSString
        guard range.location >= 0,
              range.length >= 0,
              range.location + range.length <= text.length else {
            return nil
        }
        return text.substring(with: NSRange(location: range.location, length: range.length))
    }

    private static func isWhitespace(_ value: String) -> Bool {
        !value.unicodeScalars.isEmpty && value.unicodeScalars.allSatisfy {
            CharacterSet.whitespacesAndNewlines.contains($0)
        }
    }
}
