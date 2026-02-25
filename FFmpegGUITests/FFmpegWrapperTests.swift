//
//  FFmpegWrapperTests.swift
//  FFmpegGUITests
//

import XCTest
@testable import FFmpegGUI

final class FFmpegWrapperTests: XCTestCase {
    var sut: FFmpegWrapper!

    override func setUp() {
        super.setUp()
        sut = FFmpegWrapper()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testParseFrameRate_ValidFraction() {
        let result = sut.parseFrameRate("30000/1001")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 30000.0 / 1001.0, accuracy: 0.0001)
    }

    func testParseFrameRate_Integer() {
        let result = sut.parseFrameRate("30")
        XCTAssertEqual(result, 30.0)
    }

    func testParseFrameRate_Decimal() {
        let result = sut.parseFrameRate("29.97")
        XCTAssertEqual(result, 29.97)
    }

    func testParseFrameRate_Nil() {
        let result = sut.parseFrameRate(nil)
        XCTAssertNil(result)
    }

    func testParseFrameRate_Empty() {
        let result = sut.parseFrameRate("")
        XCTAssertNil(result)
    }

    func testParseFrameRate_InvalidString() {
        let result = sut.parseFrameRate("abc")
        XCTAssertNil(result)
    }

    func testParseFrameRate_DivisionByZero() {
        let result = sut.parseFrameRate("30/0")
        XCTAssertNil(result)
    }

    func testParseFrameRate_MultipleSlashes() {
        let result = sut.parseFrameRate("1/2/3")
        XCTAssertNil(result)
    }

    func testParseFrameRate_Whitespace() {
        let result = sut.parseFrameRate(" 24000/1001 ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 24000.0 / 1001.0, accuracy: 0.0001)
    }

    func testEscapeForConcat() {
        let testCases = [
            ("simple.mp4", "simple.mp4"),
            ("my'file.mp4", "my'\\''file.mp4"),
            ("Bob's Video's.mp4", "Bob'\\''s Video'\\''s.mp4"),
            ("'leading", "'\\''leading"),
            ("trailing'", "trailing'\\''")
        ]

        for (input, expected) in testCases {
            let result = FFmpegWrapper.escapeForConcat(input)
            XCTAssertEqual(result, expected, "Failed for input: \(input)")
        }
    }
}
