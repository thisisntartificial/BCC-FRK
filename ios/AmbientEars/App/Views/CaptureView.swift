import HearingCore
import SwiftUI

struct CaptureView: View {
    @ObservedObject var library: RecordingLibrary
    @StateObject private var recorder = AmbientRecorder()
    @State private var tick = Date()

    private let clock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    statusHeader

                    LevelMeter(levelDBFS: recorder.currentLevelDBFS)
                        .frame(height: 140)

                    if recorder.isRecording {
                        liveSummary
                    } else {
                        idleHint
                    }

                    Spacer()

                    if let message = recorder.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    recordButton
                }
                .padding()
            }
            .navigationTitle("Capture")
            .onReceive(clock) { tick = $0 }
        }
    }

    private var statusHeader: some View {
        HStack {
            Circle()
                .fill(recorder.isRecording ? Theme.danger : .gray)
                .frame(width: 10, height: 10)

            Text(recorder.isRecording ? "RECORDING" : "IDLE")
                .font(.caption.weight(.semibold))
                .kerning(1.5)
                .foregroundStyle(recorder.isRecording ? Theme.danger : .secondary)

            Spacer()

            Text(Format.timecode(recorder.elapsed))
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.primary)
                .id(tick)
        }
    }

    private var liveSummary: some View {
        let events = ActivityDetector().segments(for: recorder.levelTrack).filter(\.isActive)

        return VStack(spacing: 6) {
            Text("\(events.count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text(events.count == 1 ? "sound event so far" : "sound events so far")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var idleHint: some View {
        VStack(spacing: 8) {
            Text("Leave the device somewhere quiet")
                .font(.headline)
            Text(
                "Everything is recorded, and quiet stretches are skimmed "
                + "automatically when you review it."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private var recordButton: some View {
        Button {
            Task {
                if recorder.isRecording {
                    if let finished = recorder.stop() {
                        library.add(finished)
                    }
                } else {
                    await recorder.start()
                }
            }
        } label: {
            Label(
                recorder.isRecording ? "Stop" : "Start recording",
                systemImage: recorder.isRecording ? "stop.fill" : "record.circle"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(recorder.isRecording ? Theme.danger : Theme.accent)
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

/// Horizontal bar showing instantaneous loudness on a decibel scale.
struct LevelMeter: View {
    let levelDBFS: Float

    private var normalized: Double {
        let floor: Float = -60
        guard levelDBFS > floor else { return 0 }
        return Double((levelDBFS - floor) / -floor)
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.card)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(normalized > 0.85 ? Theme.warning : Theme.accent)
                        .frame(width: geometry.size.width * normalized)
                        .animation(.linear(duration: 0.05), value: normalized)
                }
            }
            .frame(height: 18)

            Text(levelDBFS <= -119 ? "silent" : String(format: "%.0f dBFS", levelDBFS))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
