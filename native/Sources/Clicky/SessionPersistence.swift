//
//  SessionPersistence.swift
//  Reads and writes the most recent `claude` CLI session_id so the next
//  app launch can resume the same conversation via `--resume`.
//
//  File: ~/Library/Application Support/Clicky/last-session.json
//    { "version": 1, "sessionId": "<uuid>", "updatedAt": "<iso-8601>" }
//

import Foundation
import os

struct SessionPersistence {
    static let shared = SessionPersistence()

    private let logger = Logger(subsystem: "com.proyecto26.clicky", category: "SessionPersistence")
    private let filename = "last-session.json"

    private var directoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Clicky", isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(filename, isDirectory: false)
    }

    /// Loads the last saved session_id, or nil if missing/malformed.
    func load() -> String? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.info("last-session.json is not a JSON object; ignoring")
                return nil
            }
            guard let sessionId = obj["sessionId"] as? String, !sessionId.isEmpty else {
                logger.info("last-session.json has no sessionId; ignoring")
                return nil
            }
            return sessionId
        } catch {
            logger.info("last-session.json read failed: \(error.localizedDescription, privacy: .public); ignoring")
            return nil
        }
    }

    /// Saves a session_id. Creates the directory if needed. Never throws.
    func save(sessionId: String) {
        guard !sessionId.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let payload: [String: Any] = [
                "version": 1,
                "sessionId": sessionId,
                "updatedAt": ISO8601DateFormatter().string(from: Date()),
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("Failed to save last-session.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Clears the persisted session. Used by "clear conversation" UX.
    func clear() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
