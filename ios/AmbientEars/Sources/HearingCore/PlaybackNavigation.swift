import Foundation

/// Where the skip-forward and skip-back controls should land.
///
/// Both targets sit a lookahead *before* the event rather than on it, so the
/// listener hears the moment the sound begins instead of joining it late.
public enum EventNavigator {
    /// Without this, tapping forward while a sound is already playing would
    /// select the event currently being heard and appear to do nothing.
    public static let forwardGuard: TimeInterval = 0.25

    /// Tapping back just after an event starts should return to the start of
    /// that same event, which is what a listener means by "again".
    public static let backwardGuard: TimeInterval = 1.0

    /// Returns nil when nothing audible remains, so the caller can leave
    /// playback untouched rather than jumping to the end.
    public static func nextTarget(
        after time: TimeInterval,
        in segments: [ActivitySegment],
        lookahead: TimeInterval
    ) -> TimeInterval? {
        let next = segments
            .filter(\.isActive)
            .first { $0.start > time + forwardGuard }

        return next.map { max(0, $0.start - lookahead) }
    }

    /// Falls back to the start of the recording, so the control still responds
    /// when the listener is already before the first event.
    public static func previousTarget(
        before time: TimeInterval,
        in segments: [ActivitySegment],
        lookahead: TimeInterval
    ) -> TimeInterval {
        let previous = segments
            .filter(\.isActive)
            .last { $0.start < time - backwardGuard }

        guard let previous else { return 0 }
        return max(0, previous.start - lookahead)
    }
}

/// Combines the planned rate with the listener's own speed preference.
public enum RateResolver {
    /// The manual rate scales the plan rather than replacing it, so someone who
    /// prefers a gentler skim still slows down at every event.
    ///
    /// The result is always inside the range the time-pitch unit accepts;
    /// handing it something outside that range is undefined behaviour.
    public static func resolve(
        planned: Float?,
        manualRate: Float,
        isSmartModeEnabled: Bool
    ) -> Float {
        let combined: Float
        if isSmartModeEnabled, let planned {
            combined = planned * manualRate
        } else {
            combined = manualRate
        }

        let range = PlaybackPlanConfig.supportedRateRange
        guard combined.isFinite else { return 1 }
        return min(max(combined, range.lowerBound), range.upperBound)
    }
}
