import Foundation
import HearingCore

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

// `Format` now lives in HearingCore, where it can be tested without Xcode.
