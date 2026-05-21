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

    func testImageAnalysisResult_WarningMessage() {
        let evenDim = FFmpegWrapper.ImageDimensionInfo(width: 1920, height: 1080, count: 10, hasOddDimension: false)
        let oddWidthDim = FFmpegWrapper.ImageDimensionInfo(width: 1921, height: 1080, count: 10, hasOddDimension: true)
        let oddHeightDim = FFmpegWrapper.ImageDimensionInfo(width: 1920, height: 1081, count: 10, hasOddDimension: true)

        let testCases: [(mostCommon: FFmpegWrapper.ImageDimensionInfo, hasMixed: Bool, uniqueCount: Int, expected: String?)] = [
            // No warnings
            (evenDim, false, 1, nil),

            // Odd dimensions only
            (oddWidthDim, false, 1, "Most common size (1921x1080) has odd dimensions"),
            (oddHeightDim, false, 1, "Most common size (1920x1081) has odd dimensions"),

            // Mixed sizes only
            (evenDim, true, 2, "2 different image sizes detected"),
            (evenDim, true, 5, "5 different image sizes detected"),

            // Both warnings
            (oddWidthDim, true, 3, "Most common size (1921x1080) has odd dimensions. 3 different image sizes detected")
        ]

        for (mostCommon, hasMixed, uniqueCount, expected) in testCases {
            // Mock uniqueDimensions with empty ones as only count is used in warningMessage
            let uniqueDimensions = Array(repeating: evenDim, count: uniqueCount)

            let result = FFmpegWrapper.ImageAnalysisResult(
                mostCommonDimension: mostCommon,
                totalImages: 100,
                uniqueDimensions: uniqueDimensions,
                hasMixedSizes: hasMixed,
                needsCorrection: mostCommon.hasOddDimension || hasMixed
            )

            XCTAssertEqual(result.warningMessage, expected, "Failed for mostCommon: \(mostCommon.width)x\(mostCommon.height), hasMixed: \(hasMixed), uniqueCount: \(uniqueCount)")
        }
    }
}
