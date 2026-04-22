//
//  ScreenCaptureTests.swift
//  Exercises the pure scaling math that decides the JPEG output dimensions.
//  Actual ScreenCaptureKit calls are NOT made here — those would need
//  Screen Recording TCC at test time.
//

import XCTest
@testable import Clicky

final class ScreenCaptureTests: XCTestCase {
    func testScaledSizeLeavesSmallDisplaysUntouched() {
        let (w, h) = ScreenCapture.scaledSize(nativeWidth: 800, nativeHeight: 600, maxWidth: 1280)
        XCTAssertEqual(w, 800)
        XCTAssertEqual(h, 600)
    }

    func testScaledSizeScalesDownRetinaDisplay() {
        // A 2880x1800 native resolution (typical M-series internal display, 2x)
        // should scale to width 1280, preserving 16:10 aspect → 800 height.
        let (w, h) = ScreenCapture.scaledSize(nativeWidth: 2880, nativeHeight: 1800, maxWidth: 1280)
        XCTAssertEqual(w, 1280)
        XCTAssertEqual(h, 800)
    }

    func testScaledSizeHandlesUltrawide() {
        // 3440x1440 ultrawide → cap at 1280 width, preserve 2.39:1 aspect.
        let (w, h) = ScreenCapture.scaledSize(nativeWidth: 3440, nativeHeight: 1440, maxWidth: 1280)
        XCTAssertEqual(w, 1280)
        // 1440 * (1280/3440) = 535.8 → Int rounds down to 535
        XCTAssertEqual(h, 535)
    }

    func testScaledSizeKeepsExactWidthMatch() {
        // When native width already equals the cap, no scaling happens.
        let (w, h) = ScreenCapture.scaledSize(nativeWidth: 1280, nativeHeight: 720, maxWidth: 1280)
        XCTAssertEqual(w, 1280)
        XCTAssertEqual(h, 720)
    }
}
