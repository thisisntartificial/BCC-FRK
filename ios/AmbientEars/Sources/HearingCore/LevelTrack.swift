import Foundation

/// A loudness envelope sampled at a fixed interval.
///
/// A multi-hour recording is far too large to scan every time the user drags a
/// scrubber, so the app keeps this compact envelope alongside the audio and
/// drives detection, the timeline and playback planning from it.
public struct LevelTrack: Equatable {
    /// Seconds represented by each entry in `levelsDBFS`.
    public let hopDuration: TimeInterval

    /// Loudness of each hop in dBFS. Silence is `LevelTrack.silenceDBFS`.
    public let levelsDBFS: [Float]

    /// Level used for a hop containing no measurable signal.
    public static let silenceDBFS: Float = -120

    public init(hopDuration: TimeInterval, levelsDBFS: [Float]) {
        precondition(hopDuration > 0, "hopDuration must be positive")
        self.hopDuration = hopDuration
        self.levelsDBFS = levelsDBFS
    }

    public var duration: TimeInterval {
        Double(levelsDBFS.count) * hopDuration
    }

    public var isEmpty: Bool { levelsDBFS.isEmpty }

    public func time(atIndex index: Int) -> TimeInterval {
        Double(index) * hopDuration
    }

    public func index(atTime time: TimeInterval) -> Int {
        guard hopDuration > 0 else { return 0 }
        return max(0, min(levelsDBFS.count - 1, Int(time / hopDuration)))
    }

    /// Loudness below which the given fraction of hops fall.
    ///
    /// Ambient recordings have wildly different noise floors, so thresholds are
    /// derived from the recording itself rather than a fixed constant.
    public func percentileDBFS(_ fraction: Double) -> Float {
        guard !levelsDBFS.isEmpty else { return LevelTrack.silenceDBFS }
        let clamped = min(max(fraction, 0), 1)
        let sorted = levelsDBFS.sorted()
        let position = clamped * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        if lower == upper { return sorted[lower] }
        let t = Float(position - Double(lower))
        return sorted[lower] + (sorted[upper] - sorted[lower]) * t
    }
}

/// Converts incoming PCM into a `LevelTrack` while a recording is in progress.
///
/// Audio arrives in buffers whose size is chosen by the audio hardware and does
/// not divide evenly into hops, so leftover samples are carried across calls.
public struct LevelTrackBuilder {
    public let sampleRate: Double
    public let hopDuration: TimeInterval

    private let samplesPerHop: Int
    private var pending: [Float] = []
    private var levels: [Float] = []

    public init(sampleRate: Double, hopDuration: TimeInterval = 0.05) {
        precondition(sampleRate > 0, "sampleRate must be positive")
        precondition(hopDuration > 0, "hopDuration must be positive")
        self.sampleRate = sampleRate
        self.hopDuration = hopDuration
        self.samplesPerHop = max(1, Int((sampleRate * hopDuration).rounded()))
    }

    public var hopCount: Int { levels.count }

    public mutating func append(_ samples: [Float]) {
        pending.append(contentsOf: samples)

        while pending.count >= samplesPerHop {
            let hop = pending[0 ..< samplesPerHop]
            levels.append(LevelTrackBuilder.decibels(rmsOf: hop))
            pending.removeFirst(samplesPerHop)
        }
    }

    /// Emits the track, including a final partial hop if any samples remain.
    public mutating func finish() -> LevelTrack {
        if !pending.isEmpty {
            levels.append(LevelTrackBuilder.decibels(rmsOf: pending[...]))
            pending.removeAll()
        }
        return LevelTrack(hopDuration: hopDuration, levelsDBFS: levels)
    }

    /// The track built so far, leaving the builder able to accept more audio.
    public func snapshot() -> LevelTrack {
        LevelTrack(hopDuration: hopDuration, levelsDBFS: levels)
    }

    /// Loudness of a block of samples in dBFS.
    public static func decibels(rmsOf samples: ArraySlice<Float>) -> Float {
        guard !samples.isEmpty else { return LevelTrack.silenceDBFS }

        var sumOfSquares: Double = 0
        for sample in samples {
            sumOfSquares += Double(sample) * Double(sample)
        }

        let rms = (sumOfSquares / Double(samples.count)).squareRoot()
        guard rms > 0 else { return LevelTrack.silenceDBFS }

        let db = Float(20 * log10(rms))
        return max(db, LevelTrack.silenceDBFS)
    }
}
