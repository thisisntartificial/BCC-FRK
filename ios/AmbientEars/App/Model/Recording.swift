import Foundation
import HearingCore

/// A finished capture plus the loudness index gathered while it was made.
struct Recording: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let startedAt: Date
    let duration: TimeInterval
    let levelTrack: LevelTrack

    /// Segmentation is done once, at init. It is O(n log n) over the whole
    /// envelope, and SwiftUI reads these on every render — recomputing there
    /// would stall the interface on a recording of any length.
    let segments: [ActivitySegment]
    let events: [ActivitySegment]

    init(
        id: UUID = UUID(),
        url: URL,
        startedAt: Date,
        duration: TimeInterval,
        levelTrack: LevelTrack,
        detector: ActivityDetector = ActivityDetector()
    ) {
        self.id = id
        self.url = url
        self.startedAt = startedAt
        self.duration = duration
        self.levelTrack = levelTrack
        self.segments = detector.segments(for: levelTrack)
        self.events = segments.filter(\.isActive)
    }

    func plan(with config: PlaybackPlanConfig) -> PlaybackPlan {
        PlaybackPlan(segments: segments, duration: duration, config: config)
    }

    static var storageDirectory: URL {
        let base = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Recordings", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
        return base
    }

    static func makeDestinationURL(now: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return storageDirectory
            .appendingPathComponent("session-\(formatter.string(from: now)).wav")
    }
}
