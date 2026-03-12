import XCTest
@testable import FFmpegGUI

final class FFmpegWrapperBitrateTests: XCTestCase {

    func testIsValidBitrate() {
        // Table-driven tests
        let testCases: [(input: String, expected: Bool)] = [
            // Valid cases (Integers)
            ("500", true),
            ("1000000", true),
            ("0", true),

            // Valid cases (Decimals)
            ("2.5", true),
            ("0.5", true),

            // Valid cases (Suffixes)
            ("500k", true),
            ("500K", true),
            ("2m", true),
            ("2M", true),
            ("1g", true),
            ("1G", true),

            // Valid cases (Decimals with Suffixes)
            ("2.5M", true),
            ("0.5g", true),

            // Valid cases (Whitespace handling)
            ("", true),
            ("   ", true),
            ("  500k  ", true),
            ("\t2M\n", true),

            // Invalid cases (Negatives)
            ("-500", false),
            ("-2.5M", false),

            // Invalid cases (Invalid Suffixes)
            ("500kbps", false),
            ("2mb", false),
            ("1B", false),

            // Invalid cases (Multiple Decimals)
            ("1.2.3", false),
            ("1.2.3M", false),
            ("1..5M", false),

            // Invalid cases (Missing leading digits)
            (".5M", false),
            ("k", false),
            ("M", false),

            // Invalid cases (Letters/Garbage)
            ("abc", false),
            ("500 k", false), // space before suffix
            ("5 00k", false)  // space in digits
        ]

        for (input, expected) in testCases {
            let result = FFmpegWrapper.isValidBitrate(input)
            XCTAssertEqual(result, expected, "Failed for input: '\(input)'. Expected \(expected) but got \(result).")
        }
    }
}
