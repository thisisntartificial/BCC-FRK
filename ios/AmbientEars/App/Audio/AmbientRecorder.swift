import AVFoundation
import Foundation
import HearingCore

/// Captures a long unattended recording while building its loudness index.
///
/// The index is written as the audio arrives. Deriving it afterwards would mean
/// re-reading hours of audio before the user could review anything.
@MainActor
final class AmbientRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var currentLevelDBFS: Float = LevelTrack.silenceDBFS
    @Published private(set) var errorMessage: String?

    /// Loudness index accumulated so far.
    @Published private(set) var levelTrack = LevelTrack(hopDuration: 0.05, levelsDBFS: [])

    private let engine = AVAudioEngine()
    private var accumulator: LevelAccumulator?
    private var destination: URL?
    private var refresher: Task<Void, Never>?

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    func start() async {
        guard !isRecording else { return }
        errorMessage = nil

        guard await AudioSessionController.requestMicrophoneAccess() else {
            errorMessage = AudioSessionController.Failure
                .microphonePermissionDenied.errorDescription
            return
        }

        do {
            try AudioSessionController.activate(for: .capture)
            try beginCapture()
            isRecording = true
            startedAt = Date()
            startRefreshing()
        } catch {
            errorMessage = error.localizedDescription
            teardown()
        }
    }

    @discardableResult
    func stop() -> Recording? {
        guard isRecording else { return nil }

        let url = destination
        let started = startedAt
        let finalTrack = accumulator?.finish() ?? levelTrack

        teardown()
        isRecording = false
        startedAt = nil
        currentLevelDBFS = LevelTrack.silenceDBFS
        levelTrack = finalTrack

        guard let url, let started else { return nil }

        return Recording(
            url: url,
            startedAt: started,
            duration: finalTrack.duration,
            levelTrack: finalTrack
        )
    }

    private func beginCapture() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let url = Recording.makeDestinationURL()
        destination = url

        // Uncompressed, so review-time seeking is exact and the level index
        // lines up with the audio.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        // Captured by the tap so the real-time thread never reads actor state.
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let accumulator = LevelAccumulator(sampleRate: format.sampleRate)
        self.accumulator = accumulator

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            try? file.write(from: buffer)

            guard let channel = buffer.floatChannelData?[0] else { return }
            accumulator.append(
                Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            )
        }

        engine.prepare()
        try engine.start()
    }

    /// Publishes the envelope on a timer rather than per buffer, which would
    /// wake the main actor hundreds of times a second for no visible benefit.
    private func startRefreshing() {
        refresher?.cancel()
        refresher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self, let accumulator = self.accumulator else { return }

                let snapshot = accumulator.snapshot()
                self.levelTrack = snapshot
                self.currentLevelDBFS = snapshot.levelsDBFS.last ?? LevelTrack.silenceDBFS
            }
        }
    }

    private func teardown() {
        refresher?.cancel()
        refresher = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        accumulator = nil
        destination = nil
        AudioSessionController.deactivate()
    }
}
