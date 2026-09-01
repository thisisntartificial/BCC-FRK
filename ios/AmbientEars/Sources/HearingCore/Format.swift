import Foundation

/// Human-readable renderings of times and durations.
///
/// These live in the core rather than beside the views so they can be tested
/// without an Xcode toolchain.
public enum Format {
    /// Compact duration such as "1h 04m" or "3m 12s".
    public static func duration(_ interval: TimeInterval) -> String {
        let (hours, minutes, seconds) = components(of: interval)

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    /// Position within a recording, always including minutes and seconds.
    public static func timecode(_ interval: TimeInterval) -> String {
        let (hours, minutes, seconds) = components(of: interval)

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Negative intervals are clamped rather than rendered with a stray minus
    /// sign: they only arise from arithmetic slop near zero.
    private static func components(
        of interval: TimeInterval
    ) -> (hours: Int, minutes: Int, seconds: Int) {
        guard interval.isFinite else { return (0, 0, 0) }
        let total = Int(max(0, interval).rounded())
        return (total / 3600, (total % 3600) / 60, total % 60)
    }
}
