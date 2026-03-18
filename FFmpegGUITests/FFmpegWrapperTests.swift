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

    func testTimeStringToSeconds_HHMMSS() {
        XCTAssertEqual(sut.timeStringToSeconds("00:01:30.5"), 90.5)
        XCTAssertEqual(sut.timeStringToSeconds("01:02:03"), 3723.0)
    }

    func testTimeStringToSeconds_MMSS() {
        XCTAssertEqual(sut.timeStringToSeconds("01:30.5"), 90.5)
        XCTAssertEqual(sut.timeStringToSeconds("10:00"), 600.0)
    }

    func testTimeStringToSeconds_SecondsOnly() {
        XCTAssertEqual(sut.timeStringToSeconds("90.5"), 90.5)
        XCTAssertEqual(sut.timeStringToSeconds("45"), 45.0)
    }

    func testTimeStringToSeconds_WithUnits() {
        XCTAssertEqual(sut.timeStringToSeconds("90.5s"), 90.5)
        XCTAssertEqual(sut.timeStringToSeconds("1500ms"), 1.5)
        XCTAssertEqual(sut.timeStringToSeconds("1000000us"), 1.0)
    }

    func testTimeStringToSeconds_Whitespace() {
        XCTAssertEqual(sut.timeStringToSeconds("  00:00:10  "), 10.0)
    }

    func testTimeStringToSeconds_Invalid() {
        XCTAssertNil(sut.timeStringToSeconds(""))
        XCTAssertNil(sut.timeStringToSeconds("invalid"))
        XCTAssertNil(sut.timeStringToSeconds("1:60:00")) // minutes > 59 not allowed by regex
    }

    func testTimeStringToSeconds_Negative() {
        XCTAssertEqual(sut.timeStringToSeconds("-10s"), -10.0)
    }
}
