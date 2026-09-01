import Foundation

@MainActor
final class RecordingLibrary: ObservableObject {
    @Published private(set) var recordings: [Recording] = []

    func add(_ recording: Recording) {
        recordings.insert(recording, at: 0)
    }

    func remove(_ recording: Recording) {
        recordings.removeAll { $0.id == recording.id }
        try? FileManager.default.removeItem(at: recording.url)
    }
}

enum Format {
    /// Compact duration such as "1h 04m" or "3m 12s".
    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    /// Position within a recording, always including minutes and seconds.
    static func timecode(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
