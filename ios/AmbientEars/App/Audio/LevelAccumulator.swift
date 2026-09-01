import Foundation
import HearingCore

/// Thread-safe wrapper around `LevelTrackBuilder`.
///
/// Audio taps run on a real-time thread while the interface reads the envelope
/// on the main actor, so the builder cannot be touched directly from both.
final class LevelAccumulator: @unchecked Sendable {
    private var builder: LevelTrackBuilder
    private let lock = NSLock()

    init(sampleRate: Double, hopDuration: TimeInterval = 0.05) {
        builder = LevelTrackBuilder(sampleRate: sampleRate, hopDuration: hopDuration)
    }

    func append(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        builder.append(samples)
    }

    func snapshot() -> LevelTrack {
        lock.lock()
        defer { lock.unlock() }
        return builder.snapshot()
    }

    func finish() -> LevelTrack {
        lock.lock()
        defer { lock.unlock() }
        return builder.finish()
    }
}
