//
//  PointTagParserTests.swift
//  Covers every flavour of the POINT tag grammar plus realistic
//  "Claude said" strings the upstream README gives as examples.
//

import XCTest
@testable import Clicky

final class PointTagParserTests: XCTestCase {
    func testStripsFullTagAndReturnsCoordinates() {
        let response = "click source control up top. [POINT:285,11:source control]"
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.spokenText, "click source control up top.")
        XCTAssertEqual(result.point?.x, 285)
        XCTAssertEqual(result.point?.y, 11)
        XCTAssertEqual(result.point?.label, "source control")
        XCTAssertNil(result.point?.screen)
        XCTAssertFalse(result.explicitNone)
    }

    func testHandlesExplicitNone() {
        let response = "html stands for hypertext markup language. [POINT:none]"
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.spokenText, "html stands for hypertext markup language.")
        XCTAssertNil(result.point)
        XCTAssertTrue(result.explicitNone)
    }

    func testParsesMultiMonitorScreenSuffix() {
        let response = "that terminal is over there. [POINT:400,300:terminal:screen2]"
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.spokenText, "that terminal is over there.")
        XCTAssertEqual(result.point?.x, 400)
        XCTAssertEqual(result.point?.y, 300)
        XCTAssertEqual(result.point?.label, "terminal")
        XCTAssertEqual(result.point?.screen, 2)
    }

    func testNoTagLeavesTextUnchanged() {
        let response = "just a regular reply with no tag."
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.spokenText, "just a regular reply with no tag.")
        XCTAssertNil(result.point)
        XCTAssertFalse(result.explicitNone)
    }

    func testAcceptsMissingLabel() {
        let response = "look here. [POINT:100,200]"
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.spokenText, "look here.")
        XCTAssertEqual(result.point?.x, 100)
        XCTAssertEqual(result.point?.y, 200)
        XCTAssertNil(result.point?.label)
    }

    func testIgnoresTagMidSentence() {
        // The anchor $ means only trailing tags count. A stray [POINT:…]
        // in the middle of text would be a content coincidence, not a
        // real pointing directive.
        let response = "I once saw [POINT:1,2] in the wild but not at the end."
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.spokenText, "I once saw [POINT:1,2] in the wild but not at the end.")
        XCTAssertNil(result.point)
    }

    func testTrailingWhitespaceAfterTagIsAllowed() {
        let response = "hit save. [POINT:10,20:save button]   \n"
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.spokenText, "hit save.")
        XCTAssertEqual(result.point?.label, "save button")
    }

    func testLongerLabelWithSpaces() {
        let response = "over in the color inspector. [POINT:1100,42:color inspector]"
        let result = PointTagParser.parse(response)
        XCTAssertEqual(result.point?.label, "color inspector")
    }
}
