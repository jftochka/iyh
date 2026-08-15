import Foundation

enum IYHError: LocalizedError {
    case accessibilityRequired
    case noFocusedText
    case secureTextField
    case noTextBeforeCursor
    case textCannotBeEdited
    case notEnoughLayouts
    case currentLayoutUnavailable
    case cannotSelectLayout(OSStatus)

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            return "Allow iyh to control your computer in Accessibility"
        case .noFocusedText:
            return "The cursor is not in editable text"
        case .secureTextField:
            return "Password fields are not converted"
        case .noTextBeforeCursor:
            return "There is no text before the cursor"
        case .textCannotBeEdited:
            return "This application does not allow text replacement through Accessibility"
        case .notEnoughLayouts:
            return "Enable at least two keyboard layouts"
        case .currentLayoutUnavailable:
            return "The current layout does not support character-by-character conversion"
        case .cannotSelectLayout(let status):
            return "Could not select the next layout (status \(status))"
        }
    }
}
