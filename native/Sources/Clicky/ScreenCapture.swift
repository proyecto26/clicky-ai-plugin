//
//  ScreenCapture.swift
//  Thin wrapper around ScreenCaptureKit that returns a single JPEG snapshot
//  of the primary display. Sized to the display's native pixel resolution
//  but capped at a max width to keep CLI payload small.
//
//  Requires the app to have Screen Recording permission granted. The first
//  call triggers the system TCC prompt if not already granted.
//

import AppKit
import Foundation
import ScreenCaptureKit

enum ScreenCaptureError: Error, CustomStringConvertible {
    case noDisplaysAvailable
    case captureFailed(underlying: Error)
    case encodingFailed

    var description: String {
        switch self {
        case .noDisplaysAvailable:
            return "No displays available to capture. Is a monitor connected?"
        case .captureFailed(let underlying):
            return "Screen capture failed: \(underlying.localizedDescription). Grant Screen Recording in System Settings → Privacy & Security."
        case .encodingFailed:
            return "Failed to encode captured frame as JPEG."
        }
    }
}

struct CapturedFrame {
    let jpegData: Data
    let widthPx: Int
    let heightPx: Int
    let label: String
}

struct ScreenCapture {
    /// Captures the primary display and returns a JPEG snapshot plus dimensions.
    /// Width is capped at `maxWidth` preserving aspect ratio.
    static func capturePrimaryDisplay(maxWidth: Int = 1280) async throws -> CapturedFrame {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw ScreenCaptureError.captureFailed(underlying: error)
        }
        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplaysAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let nativeWidth = Int(display.width)
        let nativeHeight = Int(display.height)
        let (targetW, targetH) = scaledSize(nativeWidth: nativeWidth, nativeHeight: nativeHeight, maxWidth: maxWidth)
        config.width = targetW
        config.height = targetH
        config.capturesAudio = false
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw ScreenCaptureError.captureFailed(underlying: error)
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw ScreenCaptureError.encodingFailed
        }

        return CapturedFrame(
            jpegData: jpegData,
            widthPx: cgImage.width,
            heightPx: cgImage.height,
            label: "screen1 (primary focus, \(cgImage.width)x\(cgImage.height))"
        )
    }

    /// Internal (not private) so XCTest can exercise the scaling math
    /// without needing Screen Recording permission for an actual capture.
    static func scaledSize(nativeWidth: Int, nativeHeight: Int, maxWidth: Int) -> (Int, Int) {
        guard nativeWidth > maxWidth else {
            return (nativeWidth, nativeHeight)
        }
        let scale = Double(maxWidth) / Double(nativeWidth)
        let scaledHeight = Int(Double(nativeHeight) * scale)
        return (maxWidth, scaledHeight)
    }
}
