import Foundation

/// A stretch of the recording classified as either containing sound or not.
public struct ActivitySegment: Equatable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let isActive: Bool

    public init(start: TimeInterval, end: TimeInterval, isActive: Bool) {
        self.start = start
        self.end = end
        self.isActive = isActive
    }

    public var duration: TimeInterval { end - start }

    public func contains(_ time: TimeInterval) -> Bool {
        time >= start && time < end
    }
}

public struct ActivityDetectorConfig {
    /// How far above the estimated noise floor a hop must rise to open a segment.
    public var openOffsetDB: Float

    /// Gap between the opening and closing thresholds. Without it, audio
    /// hovering near the threshold would chatter between states.
    public var hysteresisDB: Float

    /// Quantile of the recording treated as the noise floor.
    public var floorPercentile: Double

    /// Detection never triggers on audio quieter than this, which keeps a
    /// near-silent recording from being classified as wall-to-wall activity.
    public var absoluteFloorDBFS: Float

    /// Bursts shorter than this are discarded as clicks and handling noise.
    public var minActiveDuration: TimeInterval

    /// Gaps shorter than this are absorbed, so a pause between words does not
    /// split one event into many.
    public var minSilenceDuration: TimeInterval

    public init(
        openOffsetDB: Float = 9,
        hysteresisDB: Float = 4,
        floorPercentile: Double = 0.2,
        absoluteFloorDBFS: Float = -65,
        minActiveDuration: TimeInterval = 0.25,
        minSilenceDuration: TimeInterval = 0.75
    ) {
        self.openOffsetDB = openOffsetDB
        self.hysteresisDB = hysteresisDB
        self.floorPercentile = floorPercentile
        self.absoluteFloorDBFS = absoluteFloorDBFS
        self.minActiveDuration = minActiveDuration
        self.minSilenceDuration = minSilenceDuration
    }

    public static let `default` = ActivityDetectorConfig()
}

/// Splits a `LevelTrack` into sounding and silent stretches.
public struct ActivityDetector {
    public let config: ActivityDetectorConfig

    public init(config: ActivityDetectorConfig = .default) {
        self.config = config
    }

    /// Noise floor estimated from the recording, floored by the absolute limit.
    public func noiseFloorDBFS(for track: LevelTrack) -> Float {
        guard !track.isEmpty else { return config.absoluteFloorDBFS }
        return max(
            track.percentileDBFS(config.floorPercentile),
            config.absoluteFloorDBFS
        )
    }

    public func segments(for track: LevelTrack) -> [ActivitySegment] {
        guard !track.isEmpty else { return [] }

        let floor = noiseFloorDBFS(for: track)
        let openThreshold = floor + config.openOffsetDB
        let closeThreshold = openThreshold - config.hysteresisDB

        let flags = activeFlags(
            for: track,
            openThreshold: openThreshold,
            closeThreshold: closeThreshold
        )

        let raw = runs(from: flags, hopDuration: track.hopDuration)
        let gapsClosed = absorbShortRuns(
            in: raw,
            shorterThan: config.minSilenceDuration,
            matching: false
        )
        let cleaned = absorbShortRuns(
            in: gapsClosed,
            shorterThan: config.minActiveDuration,
            matching: true
        )
        return cleaned
    }

    private func activeFlags(
        for track: LevelTrack,
        openThreshold: Float,
        closeThreshold: Float
    ) -> [Bool] {
        var isActive = false
        return track.levelsDBFS.map { level in
            if isActive {
                if level < closeThreshold { isActive = false }
            } else {
                if level >= openThreshold { isActive = true }
            }
            return isActive
        }
    }

    private func runs(from flags: [Bool], hopDuration: TimeInterval) -> [ActivitySegment] {
        guard let first = flags.first else { return [] }

        var segments: [ActivitySegment] = []
        var runValue = first
        var runStart = 0

        for index in 1 ..< flags.count where flags[index] != runValue {
            segments.append(
                ActivitySegment(
                    start: Double(runStart) * hopDuration,
                    end: Double(index) * hopDuration,
                    isActive: runValue
                )
            )
            runValue = flags[index]
            runStart = index
        }

        segments.append(
            ActivitySegment(
                start: Double(runStart) * hopDuration,
                end: Double(flags.count) * hopDuration,
                isActive: runValue
            )
        )
        return segments
    }

    /// Removes runs of `matching` shorter than `limit` by merging them into
    /// their neighbours, then coalesces any adjacent runs left with equal state.
    private func absorbShortRuns(
        in segments: [ActivitySegment],
        shorterThan limit: TimeInterval,
        matching state: Bool
    ) -> [ActivitySegment] {
        guard segments.count > 1 else { return segments }

        var kept: [ActivitySegment] = []
        for segment in segments {
            let isRemovable = segment.isActive == state
                && segment.duration < limit
                && !(kept.isEmpty && segment.start == 0 && segments.count == 1)

            if isRemovable, !kept.isEmpty || segment != segments[0] {
                kept.append(
                    ActivitySegment(
                        start: segment.start,
                        end: segment.end,
                        isActive: !state
                    )
                )
            } else {
                kept.append(segment)
            }
        }

        return coalesce(kept)
    }

    private func coalesce(_ segments: [ActivitySegment]) -> [ActivitySegment] {
        guard var current = segments.first else { return [] }
        var merged: [ActivitySegment] = []

        for segment in segments.dropFirst() {
            if segment.isActive == current.isActive {
                current = ActivitySegment(
                    start: current.start,
                    end: segment.end,
                    isActive: current.isActive
                )
            } else {
                merged.append(current)
                current = segment
            }
        }

        merged.append(current)
        return merged
    }
}
