import AVFoundation
import Foundation
import HearingCore

/// Amplifies what the microphone hears straight into headphones.
///
/// This is the only path in the app with a hard real-time constraint: the audio
/// must reach the ear fast enough that it does not sound like an echo of the
/// room, which is why the whole chain stays inside AVAudioEngine and never
/// crosses into application code per buffer.
@MainActor
final class LiveMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var inputLevelDBFS: Float = LevelTrack.silenceDBFS
    @Published private(set) var errorMessage: String?

    /// Refuses to start without headphones, because amplifying the room into
    /// the speaker feeds straight back into the microphone.
    @Published private(set) var requiresHeadphones = false

    @Published var gain: Float = 4 {
        didSet { applyGain() }
    }

    static let gainRange: ClosedRange<Float> = 1 ... 25

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()

    init() {
        engine.attach(mixer)
    }

    func start() async {
        guard !isRunning else { return }
        errorMessage = nil
        requiresHeadphones = false

        guard await AudioSessionController.requestMicrophoneAccess() else {
            errorMessage = AudioSessionController.Failure
                .microphonePermissionDenied.errorDescription
            return
        }

        do {
            try AudioSessionController.activate(for: .liveMonitor)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        guard AudioSessionController.isUsingHeadphones else {
            requiresHeadphones = true
            errorMessage = "Connect headphones first. Playing amplified audio "
                + "through the speaker feeds back into the microphone."
            AudioSessionController.deactivate()
            return
        }

        do {
            try startGraph()
            isRunning = true
        } catch {
            errorMessage = error.localizedDescription
            stop()
        }
    }

    func stop() {
        guard engine.isRunning || isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        inputLevelDBFS = LevelTrack.silenceDBFS
        AudioSessionController.deactivate()
    }

    private func startGraph() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        engine.connect(input, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        applyGain()

        // Metering only. The amplified audio itself never passes through here.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let samples = Array(
                UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
            )
            let level = LevelTrackBuilder.decibels(rmsOf: samples[...])

            Task { @MainActor in
                self?.inputLevelDBFS = level
            }
        }

        engine.prepare()
        try engine.start()
    }

    private func applyGain() {
        mixer.outputVolume = min(max(gain, LiveMonitor.gainRange.lowerBound),
                                 LiveMonitor.gainRange.upperBound)
    }
}
