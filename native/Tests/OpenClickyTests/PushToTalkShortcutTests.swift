//
//  PushToTalkShortcutTests.swift
//  Exercises the pure state-machine step PushToTalkShortcut.transition.
//  The CGEvent tap itself can't be unit-tested without Accessibility TCC,
//  but the modifier-decoding logic is fully pure and covers the whole
//  "did the chord just press / release" contract.
//

import AppKit
import CoreGraphics
import XCTest
@testable import OpenClicky

final class PushToTalkShortcutTests: XCTestCase {
    private let control  = NSEvent.ModifierFlags.control.rawValue
    private let option   = NSEvent.ModifierFlags.option.rawValue
    private let shift    = NSEvent.ModifierFlags.shift.rawValue

    // MARK: - Happy path

    func testPressedWhenControlOptionComesDown() {
        let transition = PushToTalkShortcut.transition(
            eventType: .flagsChanged,
            modifierFlagsRawValue: UInt64(control | option),
            wasPreviouslyPressed: false
        )
        XCTAssertEqual(transition, .pressed)
    }

    func testReleasedWhenControlOptionGoesUp() {
        let transition = PushToTalkShortcut.transition(
            eventType: .flagsChanged,
            modifierFlagsRawValue: 0,
            wasPreviouslyPressed: true
        )
        XCTAssertEqual(transition, .released)
    }

    // MARK: - Negative cases

    func testNoTransitionWhenHeldFlagsRepeat() {
        let transition = PushToTalkShortcut.transition(
            eventType: .flagsChanged,
            modifierFlagsRawValue: UInt64(control | option),
            wasPreviouslyPressed: true
        )
        XCTAssertEqual(transition, .none)
    }

    func testNoTransitionForKeyDownEvents() {
        // Only flagsChanged matters for a modifier-only chord.
        let transition = PushToTalkShortcut.transition(
            eventType: .keyDown,
            modifierFlagsRawValue: UInt64(control | option),
            wasPreviouslyPressed: false
        )
        XCTAssertEqual(transition, .none)
    }

    func testNoTransitionWhenOnlyControlIsHeld() {
        let transition = PushToTalkShortcut.transition(
            eventType: .flagsChanged,
            modifierFlagsRawValue: UInt64(control),
            wasPreviouslyPressed: false
        )
        XCTAssertEqual(transition, .none)
    }

    func testNoTransitionWhenOnlyOptionIsHeld() {
        let transition = PushToTalkShortcut.transition(
            eventType: .flagsChanged,
            modifierFlagsRawValue: UInt64(option),
            wasPreviouslyPressed: false
        )
        XCTAssertEqual(transition, .none)
    }

    // MARK: - Edge cases

    func testExtraModifiersStillCountAsPressed() {
        // Holding shift as well must not break the chord — user may be
        // chording while already holding shift for another shortcut.
        let transition = PushToTalkShortcut.transition(
            eventType: .flagsChanged,
            modifierFlagsRawValue: UInt64(control | option | shift),
            wasPreviouslyPressed: false
        )
        XCTAssertEqual(transition, .pressed)
    }

    func testDroppingToJustControlCountsAsRelease() {
        // The chord is no longer fully held; we care about transition,
        // not exact equality.
        let transition = PushToTalkShortcut.transition(
            eventType: .flagsChanged,
            modifierFlagsRawValue: UInt64(control),
            wasPreviouslyPressed: true
        )
        XCTAssertEqual(transition, .released)
    }
}
