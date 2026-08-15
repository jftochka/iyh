import Foundation

@MainActor
enum SelfTest {
    static func run() -> Int32 {
        var failures: [String] = []

        expectRange("say ghbdtn", caret: 10, expected: "ghbdtn", failures: &failures)
        expectRange("say ghbdtn  ", caret: 12, expected: "ghbdtn", failures: &failures)
        expectRange("hello\nworld", caret: 11, expected: "world", failures: &failures)

        let service = KeyboardLayoutService()
        let layouts = service.availableLayouts()
        if let latin = layouts.first(where: {
            $0.id.hasSuffix(".ABC") || $0.id.hasSuffix(".US")
        }),
           let alternate = layouts.first(where: { $0.id != latin.id }) {
            let sample = "ghbdtn"
            let converted = service.convert(sample, from: latin, to: alternate)
            expect(
                service.convert(converted, from: alternate, to: latin) == sample,
                "ABC → alternate layout → ABC should round-trip",
                failures: &failures
            )
            let capitalizedSample = "Ghbdtn"
            let capitalizedConverted = service.convert(
                capitalizedSample,
                from: latin,
                to: alternate
            )
            expect(
                service.convert(capitalizedConverted, from: alternate, to: latin) == capitalizedSample,
                "ABC → alternate layout should preserve Shift/case",
                failures: &failures
            )
        } else {
            let description = layouts.map { "\($0.name) [\($0.id)]" }.joined(separator: ", ")
            print("SKIP: ABC/alternate layout integration check; found: \(description)")
        }

        if failures.isEmpty {
            print("PASS: all iyh self-tests")
            return 0
        }

        failures.forEach { print("FAIL: \($0)") }
        return 1
    }

    private static func expectRange(
        _ value: String,
        caret: Int,
        expected: String,
        failures: inout [String]
    ) {
        guard let range = TextTargeting.previousTokenRange(in: value, caret: caret),
              let actual = TextTargeting.substring(value, range: range) else {
            failures.append("No token range for \(String(reflecting: value))")
            return
        }
        expect(
            actual == expected,
            "Expected \(String(reflecting: expected)), got \(String(reflecting: actual))",
            failures: &failures
        )
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        failures: inout [String]
    ) {
        if !condition() {
            failures.append(message)
        }
    }
}
