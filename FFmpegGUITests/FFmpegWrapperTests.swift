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

    func testImageAnalysisResult_WarningMessage_None() {
        let info = FFmpegWrapper.ImageDimensionInfo(width: 1920, height: 1080, count: 10, hasOddDimension: false)
        let result = FFmpegWrapper.ImageAnalysisResult(mostCommonDimension: info, totalImages: 10, uniqueDimensions: [info], hasMixedSizes: false, needsCorrection: false)
        XCTAssertNil(result.warningMessage)
    }

    func testImageAnalysisResult_WarningMessage_OddDimensions() {
        let info = FFmpegWrapper.ImageDimensionInfo(width: 1921, height: 1080, count: 10, hasOddDimension: true)
        let result = FFmpegWrapper.ImageAnalysisResult(mostCommonDimension: info, totalImages: 10, uniqueDimensions: [info], hasMixedSizes: false, needsCorrection: true)
        XCTAssertEqual(result.warningMessage, "Most common size (1921x1080) has odd dimensions")
    }

    func testImageAnalysisResult_WarningMessage_MixedSizes() {
        let info1 = FFmpegWrapper.ImageDimensionInfo(width: 1920, height: 1080, count: 5, hasOddDimension: false)
        let info2 = FFmpegWrapper.ImageDimensionInfo(width: 1280, height: 720, count: 5, hasOddDimension: false)
        let result = FFmpegWrapper.ImageAnalysisResult(mostCommonDimension: info1, totalImages: 10, uniqueDimensions: [info1, info2], hasMixedSizes: true, needsCorrection: true)
        XCTAssertEqual(result.warningMessage, "2 different image sizes detected")
    }

    func testImageAnalysisResult_WarningMessage_BothWarnings() {
        let info1 = FFmpegWrapper.ImageDimensionInfo(width: 1921, height: 1080, count: 5, hasOddDimension: true)
        let info2 = FFmpegWrapper.ImageDimensionInfo(width: 1280, height: 720, count: 5, hasOddDimension: false)
        let result = FFmpegWrapper.ImageAnalysisResult(mostCommonDimension: info1, totalImages: 10, uniqueDimensions: [info1, info2], hasMixedSizes: true, needsCorrection: true)
        XCTAssertEqual(result.warningMessage, "Most common size (1921x1080) has odd dimensions. 2 different image sizes detected")
    }
}
