//
//  AudioConversion.swift
//  Audio conversion helpers shared by transcription providers and any
//  future upload-based flows.
//
//  Ports clicky/leanring-buddy/BuddyAudioConversionSupport.swift:
//    - PCM16AudioConverter: live AVAudioConverter wrapper that takes
//      whatever format AVAudioEngine's mic tap produces and resamples
//      it to 16-bit PCM mono at the provider's preferred sample rate.
//      Rebuilds the converter lazily when the input format changes.
//    - WAVFileBuilder: builds an in-memory WAV container around PCM16
//      samples for upload-style STT backends. Pure byte math — fully
//      unit-testable without microphone access.
//

import AVFoundation
import Foundation

final class PCM16AudioConverter {
    private let targetAudioFormat: AVAudioFormat
    private var audioConverter: AVAudioConverter?
    private var currentInputFormatDescription: String?

    init(targetSampleRate: Double) {
        self.targetAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        )!
    }

    func convertToPCM16Data(from audioBuffer: AVAudioPCMBuffer) -> Data? {
        let inputFormatDescription = audioBuffer.format.settings.description

        if currentInputFormatDescription != inputFormatDescription {
            audioConverter = AVAudioConverter(from: audioBuffer.format, to: targetAudioFormat)
            currentInputFormatDescription = inputFormatDescription
        }

        guard let audioConverter else { return nil }

        let sampleRateRatio = targetAudioFormat.sampleRate / audioBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(
            (Double(audioBuffer.frameLength) * sampleRateRatio).rounded(.up) + 32
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetAudioFormat,
            frameCapacity: outputFrameCapacity
        ) else { return nil }

        var hasProvidedSourceBuffer = false
        var conversionError: NSError?

        let conversionStatus = audioConverter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if hasProvidedSourceBuffer {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasProvidedSourceBuffer = true
            outStatus.pointee = .haveData
            return audioBuffer
        }

        guard conversionStatus != .error else { return nil }
        guard let pcmDataPointer = outputBuffer.audioBufferList.pointee.mBuffers.mData else { return nil }

        let bytesPerFrame = Int(targetAudioFormat.streamDescription.pointee.mBytesPerFrame)
        let byteCount = Int(outputBuffer.frameLength) * bytesPerFrame
        guard byteCount > 0 else { return nil }

        return Data(bytes: pcmDataPointer, count: byteCount)
    }
}

enum WAVFileBuilder {
    /// Wraps PCM16 little-endian samples in a WAV container.
    /// Byte layout per RIFF WAVE spec: "RIFF" + size + "WAVE" + fmt
    /// chunk (16 bytes, format 1 = PCM) + data chunk.
    static func buildWAVData(
        fromPCM16MonoAudio pcm16AudioData: Data,
        sampleRate: Int,
        channelCount: Int = 1,
        bitsPerSample: Int = 16
    ) -> Data {
        let byteRate = sampleRate * channelCount * bitsPerSample / 8
        let blockAlign = channelCount * bitsPerSample / 8
        let dataChunkSize = UInt32(pcm16AudioData.count)
        let fileSize = UInt32(36) + dataChunkSize

        var wavData = Data()
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(littleEndianData(from: fileSize))
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(littleEndianData(from: UInt32(16)))              // fmt chunk size
        wavData.append(littleEndianData(from: UInt16(1)))               // audio format: PCM
        wavData.append(littleEndianData(from: UInt16(channelCount)))
        wavData.append(littleEndianData(from: UInt32(sampleRate)))
        wavData.append(littleEndianData(from: UInt32(byteRate)))
        wavData.append(littleEndianData(from: UInt16(blockAlign)))
        wavData.append(littleEndianData(from: UInt16(bitsPerSample)))
        wavData.append("data".data(using: .ascii)!)
        wavData.append(littleEndianData(from: dataChunkSize))
        wavData.append(pcm16AudioData)
        return wavData
    }

    private static func littleEndianData<T: FixedWidthInteger>(from value: T) -> Data {
        var littleEndianValue = value.littleEndian
        return Data(bytes: &littleEndianValue, count: MemoryLayout<T>.size)
    }
}
