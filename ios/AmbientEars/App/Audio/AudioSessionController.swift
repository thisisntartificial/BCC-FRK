import AVFoundation
import Foundation

/// Owns the shared `AVAudioSession` configuration.
///
/// The two jobs of this app want different session setups, and switching
/// between them in one place avoids the engine being reconfigured underneath a
/// running graph.
enum AudioSessionController {
    enum Purpose {
        /// Unattended capture. Playback is not needed, so the session stays
        /// record-only and other audio is allowed to keep playing.
        case capture

        /// Live amplification into headphones. Needs simultaneous input and
        /// output with the lowest latency the device will grant.
        case liveMonitor

        /// Reviewing a finished recording.
        case playback
    }

    enum Failure: LocalizedError {
        case microphonePermissionDenied
        case configurationFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access is off. Turn it on in Settings to record."
            case let .configurationFailed(underlying):
                return "The audio system could not start: \(underlying.localizedDescription)"
            }
        }
    }

    static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func activate(for purpose: Purpose) throws {
        let session = AVAudioSession.sharedInstance()

        do {
            switch purpose {
            case .capture:
                try session.setCategory(
                    .record,
                    mode: .measurement,
                    options: [.allowBluetooth]
                )

            case .liveMonitor:
                try session.setCategory(
                    .playAndRecord,
                    mode: .measurement,
                    options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
                )
                // Amplifying the room and playing it back through the speaker
                // is a feedback loop, so ask for the shortest practical buffer
                // and rely on the UI to require headphones.
                try? session.setPreferredIOBufferDuration(0.005)

            case .playback:
                try session.setCategory(.playback, mode: .default)
            }

            try session.setActive(true, options: [])
        } catch {
            throw Failure.configurationFailed(underlying: error)
        }
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Whether audio is currently leaving the device by a route that will not
    /// feed straight back into the microphone.
    static var isUsingHeadphones: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        let safeOutputs: Set<AVAudioSession.Port> = [
            .headphones,
            .bluetoothA2DP,
            .bluetoothHFP,
            .bluetoothLE,
            .usbAudio,
            .airPlay,
        ]
        return route.outputs.contains { safeOutputs.contains($0.portType) }
    }
}
