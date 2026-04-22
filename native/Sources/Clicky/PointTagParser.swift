//
//  PointTagParser.swift
//  Parses the `[POINT:x,y:label:screenN]` tag Claude appends when it
//  wants to flag a UI element. Pure function, fully unit-testable.
//
//  Tag grammar (regex ported from upstream Clicky):
//    [POINT:none]
//    [POINT:<x>,<y>]
//    [POINT:<x>,<y>:<label>]
//    [POINT:<x>,<y>:<label>:screen<N>]
//
//  Tag must be at the very end of the response, optionally followed by
//  trailing whitespace. Everything before it is the spoken text.
//

import CoreGraphics
import Foundation

struct PointTag: Equatable {
    let x: Double
    let y: Double
    let label: String?
    let screen: Int?

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct PointParseResult: Equatable {
    /// Text Claude produced, with any trailing POINT tag stripped. Safe
    /// to feed directly to TTS.
    let spokenText: String

    /// The parsed POINT target, or nil when the tag is `[POINT:none]`
    /// or absent.
    let point: PointTag?

    /// True when the tag explicitly said `[POINT:none]`. Useful for
    /// telemetry: Claude intentionally decided not to point.
    let explicitNone: Bool
}

enum PointTagParser {
    /// Regex verbatim from upstream Clicky. Anchored to end-of-string so
    /// a stray `[POINT:...]` mid-sentence doesn't get mistaken for a tag.
    private static let pattern = #"\[POINT:(?:none|(\d+)\s*,\s*(\d+)(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?)\]\s*$"#
    private static let regex = try! NSRegularExpression(pattern: pattern)

    static func parse(_ responseText: String) -> PointParseResult {
        let nsResponse = responseText as NSString
        let fullRange = NSRange(location: 0, length: nsResponse.length)

        guard let match = regex.firstMatch(in: responseText, range: fullRange) else {
            return PointParseResult(
                spokenText: responseText.trimmingCharacters(in: .whitespacesAndNewlines),
                point: nil,
                explicitNone: false
            )
        }

        // Everything before the tag, whitespace-trimmed, is what TTS speaks.
        let spokenText = nsResponse.substring(to: match.range.location)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // [POINT:none] case — groups 1 & 2 are absent.
        guard match.range(at: 1).location != NSNotFound,
              match.range(at: 2).location != NSNotFound,
              let x = Double(nsResponse.substring(with: match.range(at: 1))),
              let y = Double(nsResponse.substring(with: match.range(at: 2)))
        else {
            return PointParseResult(spokenText: spokenText, point: nil, explicitNone: true)
        }

        var label: String? = nil
        if match.range(at: 3).location != NSNotFound {
            let raw = nsResponse.substring(with: match.range(at: 3))
                .trimmingCharacters(in: .whitespaces)
            label = raw.isEmpty ? nil : raw
        }

        var screen: Int? = nil
        if match.range(at: 4).location != NSNotFound {
            screen = Int(nsResponse.substring(with: match.range(at: 4)))
        }

        return PointParseResult(
            spokenText: spokenText,
            point: PointTag(x: x, y: y, label: label, screen: screen),
            explicitNone: false
        )
    }
}
