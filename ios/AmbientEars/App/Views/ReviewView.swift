import HearingCore
import SwiftUI

struct LibraryView: View {
    @ObservedObject var library: RecordingLibrary

    var body: some View {
        NavigationStack {
            Group {
                if library.recordings.isEmpty {
                    ContentUnavailableView(
                        "No recordings yet",
                        systemImage: "waveform",
                        description: Text("Sessions you capture will appear here.")
                    )
                } else {
                    List {
                        ForEach(library.recordings) { recording in
                            NavigationLink {
                                ReviewView(recording: recording)
                            } label: {
                                row(for: recording)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { library.recordings[$0] }.forEach(library.remove)
                        }
                    }
                }
            }
            .navigationTitle("Review")
        }
    }

    private func row(for recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Format.timestamp(recording.startedAt))
                .font(.headline)

            HStack(spacing: 12) {
                Label(Format.duration(recording.duration), systemImage: "clock")
                Label("\(recording.events.count)", systemImage: "waveform.badge.exclamationmark")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct ReviewView: View {
    let recording: Recording

    @StateObject private var player = SmartPlayer()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                summary

                ActivityTimeline(
                    segments: recording.segments,
                    duration: recording.duration,
                    position: player.currentTime
                ) { time in
                    player.seek(to: time)
                }
                .frame(height: 70)

                rateReadout
                transport
                controls

                Spacer()
            }
            .padding()
        }
        .navigationTitle(Format.timestamp(recording.startedAt))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { player.load(recording) }
        .onDisappear { player.stop() }
    }

    private var summary: some View {
        HStack {
            stat(
                title: "Recorded",
                value: Format.duration(recording.duration)
            )
            stat(
                title: "Listening time",
                value: Format.duration(player.projectedDuration)
            )
            stat(
                title: "Events",
                value: "\(recording.events.count)"
            )
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var rateReadout: some View {
        HStack {
            Text(Format.timecode(player.currentTime))
                .font(.system(.body, design: .monospaced))

            Spacer()

            Text(String(format: "%.1f×", player.currentRate))
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(player.currentRate > 1.05 ? Theme.warning : Theme.accent)
                .animation(.easeOut(duration: 0.2), value: player.currentRate)
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Button { player.skipToPreviousEvent() } label: {
                Image(systemName: "backward.end.fill").font(.title2)
            }

            Button {
                player.isPlaying ? player.pause() : player.play()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(Theme.accent)
            }

            Button { player.skipToNextEvent() } label: {
                Image(systemName: "forward.end.fill").font(.title2)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $player.isSmartModeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skim silence")
                    Text("Speeds up when nothing is happening, and is back to normal before each sound starts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accent)

            labelledSlider(
                title: player.isSmartModeEnabled ? "Speed while audible" : "Speed",
                value: $player.manualRate,
                range: 0.5 ... 3,
                display: String(format: "%.2f×", player.manualRate)
            )

            if player.isSmartModeEnabled {
                labelledSlider(
                    title: "Speed through silence",
                    value: Binding(
                        get: { player.config.idleRate },
                        set: { player.config.idleRate = $0 }
                    ),
                    range: 2 ... 24,
                    display: String(format: "%.0f×", player.config.idleRate)
                )
            }
        }
        .padding()
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func labelledSlider(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        display: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(display)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.accent)
            }
            Slider(value: value, in: range)
                .tint(Theme.accent)
        }
    }
}

/// Strip showing where sound occurs across the whole recording.
struct ActivityTimeline: View {
    let segments: [ActivitySegment]
    let duration: TimeInterval
    let position: TimeInterval
    let onScrub: (TimeInterval) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Theme.card)

                ForEach(Array(segments.filter(\.isActive).enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent)
                        .frame(width: max(2, offset(for: segment.duration, in: width)))
                        .offset(x: offset(for: segment.start, in: width))
                }

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .offset(x: offset(for: position, in: width))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    guard duration > 0, width > 0 else { return }
                    onScrub(Double(value.location.x / width) * duration)
                }
            )
        }
    }

    private func offset(for time: TimeInterval, in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time / duration) * width
    }
}
