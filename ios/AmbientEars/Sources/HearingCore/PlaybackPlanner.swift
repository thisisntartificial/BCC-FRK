import Foundation

public struct PlaybackPlanConfig {
    /// Rate used while something is audible.
    public var activeRate: Float

    /// Rate used while coasting through silence.
    public var idleRate: Float

    /// How early playback returns to `activeRate` before a sound starts.
    ///
    /// Without this the player is still racing through silence when the sound
    /// begins and the first syllable is lost.
    public var lookahead: TimeInterval

    /// How long playback stays at `activeRate` after a sound ends, so decays
    /// and trailing words are not cut off.
    public var tail: TimeInterval

    /// Time taken to move between the two rates. Instant jumps are audible as
    /// a lurch, so the change is ramped.
    public var rampDuration: TimeInterval

    public init(
        activeRate: Float = 1.0,
        idleRate: Float = 8.0,
        lookahead: TimeInterval = 0.75,
        tail: TimeInterval = 0.6,
        rampDuration: TimeInterval = 0.3
    ) {
        self.activeRate = activeRate
        self.idleRate = idleRate
        self.lookahead = lookahead
        self.tail = tail
        self.rampDuration = rampDuration
    }

    public static let `default` = PlaybackPlanConfig()

    /// Rates the audio engine can render without artefacts.
    public static let supportedRateRange: ClosedRange<Float> = 0.25 ... 32

    public var clamped: PlaybackPlanConfig {
        var copy = self
        let range = PlaybackPlanConfig.supportedRateRange
        copy.activeRate = min(max(activeRate, range.lowerBound), range.upperBound)
        copy.idleRate = min(max(idleRate, range.lowerBound), range.upperBound)
        copy.lookahead = max(0, lookahead)
        copy.tail = max(0, tail)
        copy.rampDuration = max(0, rampDuration)
        return copy
    }
}

/// Chooses a playback rate for every instant of a recording.
///
/// Silence is skimmed and audible moments play at normal speed. The plan is
/// derived up front from the level index rather than reacting to audio as it
/// plays, which is what makes it possible to slow down *before* a sound starts.
public struct PlaybackPlan {
    public let config: PlaybackPlanConfig
    public let duration: TimeInterval

    /// Stretches played at `activeRate`, already widened by lookahead and tail.
    public let normalIntervals: [ClosedRange<TimeInterval>]

    public init(
        segments: [ActivitySegment],
        duration: TimeInterval,
        config: PlaybackPlanConfig = .default
    ) {
        let config = config.clamped
        self.config = config
        self.duration = max(0, duration)
        self.normalIntervals = PlaybackPlan.normalIntervals(
            from: segments,
            duration: self.duration,
            lookahead: config.lookahead,
            tail: config.tail
        )
    }

    static func normalIntervals(
        from segments: [ActivitySegment],
        duration: TimeInterval,
        lookahead: TimeInterval,
        tail: TimeInterval
    ) -> [ClosedRange<TimeInterval>] {
        let widened = segments
            .filter(\.isActive)
            .map { segment -> ClosedRange<TimeInterval> in
                let start = max(0, segment.start - lookahead)
                let end = min(duration, segment.end + tail)
                return start ... max(start, end)
            }

        return merge(widened)
    }

    static func merge(
        _ intervals: [ClosedRange<TimeInterval>]
    ) -> [ClosedRange<TimeInterval>] {
        guard !intervals.isEmpty else { return [] }

        let sorted = intervals.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<TimeInterval>] = []
        var current = sorted[0]

        for interval in sorted.dropFirst() {
            if interval.lowerBound <= current.upperBound {
                current = current.lowerBound ... max(current.upperBound, interval.upperBound)
            } else {
                merged.append(current)
                current = interval
            }
        }

        merged.append(current)
        return merged
    }

    /// Rate to play at `time`.
    ///
    /// Inside a normal interval this is `activeRate`. Elsewhere it approaches
    /// `idleRate`, but is pulled back down near either edge of a normal
    /// interval so the transition is gradual and lands exactly on the boundary.
    public func rate(at time: TimeInterval) -> Float {
        guard !normalIntervals.isEmpty else { return config.idleRate }

        if normalIntervals.contains(where: { $0.contains(time) }) {
            return config.activeRate
        }

        guard config.rampDuration > 0 else { return config.idleRate }

        var distance = TimeInterval.infinity
        for interval in normalIntervals {
            if time < interval.lowerBound {
                distance = min(distance, interval.lowerBound - time)
            } else if time > interval.upperBound {
                distance = min(distance, time - interval.upperBound)
            }
        }

        guard distance.isFinite else { return config.idleRate }

        let progress = Float(min(max(distance / config.rampDuration, 0), 1))
        return config.activeRate + (config.idleRate - config.activeRate) * progress
    }

    /// Wall-clock time needed to listen to the whole recording under this plan.
    public var compressedDuration: TimeInterval {
        guard duration > 0 else { return 0 }

        let step = resolvedStep
        var elapsed: TimeInterval = 0
        var time: TimeInterval = 0

        while time < duration {
            let span = min(step, duration - time)
            // Rate at the midpoint keeps ramps from being over- or
            // under-counted the way sampling an endpoint would.
            let rate = rate(at: time + span / 2)
            elapsed += span / TimeInterval(max(rate, 0.0001))
            time += span
        }

        return elapsed
    }

    /// How much shorter the session is than the recording, as a multiplier.
    public var speedUpFactor: Double {
        let compressed = compressedDuration
        guard compressed > 0 else { return 1 }
        return duration / compressed
    }

    private var resolvedStep: TimeInterval {
        let candidates = [config.rampDuration / 8, 0.05].filter { $0 > 0 }
        return candidates.min() ?? 0.05
    }
}
