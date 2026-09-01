import AVFoundation
import Combine
import Foundation
import HearingCore

/// Plays a recording back, skimming silence and slowing to normal speed for
/// anything audible.
///
/// The rate comes from a `PlaybackPlan` computed up front, so the player knows
/// a sound is coming and can be back at normal speed before it starts.
@MainActor
final class SmartPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var currentRate: Float = 1
    @Published private(set) var errorMessage: String?

    /// When off, the recording plays at `manualRate` throughout.
    @Published var isSmartModeEnabled = true {
        didSet { refreshRate() }
    }

    /// Rate used when smart mode is off, and the ceiling users can tune.
    @Published var manualRate: Float = 1 {
        didSet { refreshRate() }
    }

    @Published var config: PlaybackPlanConfig = .default {
        didSet { rebuildPlan() }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()

    private var recording: Recording?
    private var plan: PlaybackPlan?
    private var file: AVAudioFile?
    private var seekOffset: TimeInterval = 0
    private var ticker: AnyCancellable?

    var duration: TimeInterval { recording?.duration ?? 0 }
    var events: [ActivitySegment] { recording?.events ?? [] }

    /// Estimated listening time for the whole recording under the current plan.
    var projectedDuration: TimeInterval { plan?.compressedDuration ?? duration }

    init() {
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
    }

    func load(_ recording: Recording) {
        stop()
        self.recording = recording
        rebuildPlan()

        do {
            file = try AVAudioFile(forReading: recording.url)
        } catch {
            errorMessage = "That recording could not be opened."
            file = nil
        }
    }

    func play(from time: TimeInterval? = nil) {
        guard let file else { return }
        errorMessage = nil

        do {
            try AudioSessionController.activate(for: .playback)
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let start = min(max(time ?? currentTime, 0), duration)
        seekOffset = start
        player.stop()

        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(start * sampleRate)
        let remaining = AVAudioFrameCount(max(0, file.length - startFrame))
        guard remaining > 0 else { return }

        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: remaining,
            at: nil
        )

        refreshRate()
        player.play()
        isPlaying = true
        startTicking()
    }

    func pause() {
        player.pause()
        isPlaying = false
        ticker?.cancel()
    }

    func stop() {
        player.stop()
        if engine.isRunning { engine.stop() }
        ticker?.cancel()
        isPlaying = false
        currentTime = 0
        seekOffset = 0
    }

    func seek(to time: TimeInterval) {
        let wasPlaying = isPlaying
        player.stop()
        currentTime = min(max(time, 0), duration)
        if wasPlaying {
            play(from: currentTime)
        } else {
            seekOffset = currentTime
            refreshRate()
        }
    }

    /// Jumps to shortly before the next audible event.
    func skipToNextEvent() {
        guard let target = EventNavigator.nextTarget(
            after: currentTime,
            in: events,
            lookahead: config.lookahead
        ) else { return }

        seek(to: target)
    }

    func skipToPreviousEvent() {
        seek(to: EventNavigator.previousTarget(
            before: currentTime,
            in: events,
            lookahead: config.lookahead
        ))
    }

    private func rebuildPlan() {
        guard let recording else {
            plan = nil
            return
        }
        plan = recording.plan(with: config)
        refreshRate()
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        currentTime = resolvedCurrentTime()
        refreshRate()

        if currentTime >= duration - 0.01 {
            pause()
            currentTime = duration
        }
    }

    private func resolvedCurrentTime() -> TimeInterval {
        guard
            let nodeTime = player.lastRenderTime,
            let playerTime = player.playerTime(forNodeTime: nodeTime),
            playerTime.sampleRate > 0
        else {
            return seekOffset
        }

        let played = Double(playerTime.sampleTime) / playerTime.sampleRate
        return min(seekOffset + played, duration)
    }

    private func refreshRate() {
        let rate = RateResolver.resolve(
            planned: plan?.rate(at: currentTime),
            manualRate: manualRate,
            isSmartModeEnabled: isSmartModeEnabled
        )

        timePitch.rate = rate
        currentRate = rate
    }
}
