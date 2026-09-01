import Foundation

/// Maps between times in a recording and positions along the timeline strip.
///
/// Kept out of the view so the degenerate cases — an empty recording, a scrub
/// that ends off the edge of the strip — are settled by tests rather than
/// discovered as a division by zero on a device.
public enum TimelineGeometry {
    /// Position of `time` as a 0...1 fraction of the strip.
    public static func fraction(
        of time: TimeInterval,
        duration: TimeInterval
    ) -> Double {
        guard duration > 0, time.isFinite else { return 0 }
        return min(max(time / duration, 0), 1)
    }

    /// Time under a scrub at `fraction` along the strip. Drags that end past
    /// either edge resolve to the nearest end rather than off the recording.
    public static func time(
        atFraction fraction: Double,
        duration: TimeInterval
    ) -> TimeInterval {
        guard duration > 0, fraction.isFinite else { return 0 }
        return min(max(fraction, 0), 1) * duration
    }
}
