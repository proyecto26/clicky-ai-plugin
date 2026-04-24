//
//  AudioConversionTests.swift
//  Unit tests for WAVFileBuilder — verifies the exact byte layout a
//  standards-compliant WAV PCM16 container requires. PCM16AudioConverter
//  is not tested here because it needs a real AVAudioPCMBuffer (which
//  in turn needs AVAudioEngine) — covered by manual smoke tests of the
//  dictation flow.
//

import XCTest
@testable import OpenClicky

final class WAVFileBuilderTests: XCTestCase {
    func testHeaderStartsWithRIFFChunkDescriptor() {
        let wav = WAVFileBuilder.buildWAVData(fromPCM16MonoAudio: Data(), sampleRate: 16000)
        XCTAssertEqual(wav.prefix(4), Data("RIFF".utf8))
        XCTAssertEqual(wav.subdata(in: 8..<12), Data("WAVE".utf8))
        XCTAssertEqual(wav.subdata(in: 12..<16), Data("fmt ".utf8))
        XCTAssertEqual(wav.subdata(in: 36..<40), Data("data".utf8))
    }

    func testFmtChunkCarriesStandardPCM16MonoParameters() {
        let wav = WAVFileBuilder.buildWAVData(fromPCM16MonoAudio: Data(), sampleRate: 16000)
        let fmtChunkSize = UInt32(littleEndian: wav[16..<20].withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(fmtChunkSize, 16)

        let audioFormat = UInt16(littleEndian: wav[20..<22].withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(audioFormat, 1, "audio format 1 = uncompressed PCM")

        let channelCount = UInt16(littleEndian: wav[22..<24].withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(channelCount, 1)

        let sampleRate = UInt32(littleEndian: wav[24..<28].withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(sampleRate, 16_000)

        let byteRate = UInt32(littleEndian: wav[28..<32].withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(byteRate, 16_000 * 1 * 16 / 8)

        let blockAlign = UInt16(littleEndian: wav[32..<34].withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(blockAlign, 2)

        let bitsPerSample = UInt16(littleEndian: wav[34..<36].withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(bitsPerSample, 16)
    }

    func testFileSizeIsDataPlus36() {
        let samples = Data(repeating: 0x42, count: 320) // 160 PCM16 mono samples
        let wav = WAVFileBuilder.buildWAVData(fromPCM16MonoAudio: samples, sampleRate: 48_000)
        let riffSize = UInt32(littleEndian: wav[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) })
        let dataSize = UInt32(littleEndian: wav[40..<44].withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(dataSize, UInt32(samples.count))
        XCTAssertEqual(riffSize, dataSize + 36)
    }

    func testPayloadFollowsDataChunkHeader() {
        let samples = Data([0x01, 0x00, 0x02, 0x00, 0x03, 0x00])
        let wav = WAVFileBuilder.buildWAVData(fromPCM16MonoAudio: samples, sampleRate: 16_000)
        XCTAssertEqual(wav.suffix(samples.count), samples)
    }

    func testTotalHeaderSizeIs44Bytes() {
        let wav = WAVFileBuilder.buildWAVData(fromPCM16MonoAudio: Data(), sampleRate: 16_000)
        XCTAssertEqual(wav.count, 44, "RIFF + WAVE + fmt (24 total) + data header (8) = 44 bytes for empty PCM")
    }
}
