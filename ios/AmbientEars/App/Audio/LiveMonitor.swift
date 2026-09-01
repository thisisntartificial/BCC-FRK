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

    /// Amplification as a multiple of the input, shown to the user as "8×".
    @Published var gain: Float = 4 {
        didSet { applyGain() }
    }

    /// Ceiling is set by what the gain stage can deliver: `AVAudioUnitEQ`
    /// tops out at +24 dB, which is a little under 16x.
    static let gainRange = GainStage.supportedRange

    private let engine = AVAudioEngine()

    /// Mixer volume cannot amplify — it is limited to unity — so boosting has
    /// to happen in a real gain stage measured in decibels.
    private let amplifier = AVAudioUnitEQ(numberOfBands: 0)

    init() {
        engine.attach(amplifier)
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

        engine.connect(input, to: amplifier, format: format)
        engine.connect(amplifier, to: engine.mainMixerNode, format: format)
        applyGain()

        // Metering only. The amplified audio itself never passes through here.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let level = LevelTrackBuilder.decibels(
                rmsOf: Array(
                    UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
                )[...]
            )

            Task { @MainActor in
                self?.inputLevelDBFS = level
            }
        }

        engine.prepare()
        try engine.start()
    }

    private func applyGain() {
        amplifier.globalGain = GainStage.decibels(forMultiplier: gain)
    }
}
