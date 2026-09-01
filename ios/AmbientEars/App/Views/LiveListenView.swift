import SwiftUI

struct LiveListenView: View {
    @StateObject private var monitor = LiveMonitor()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    LevelMeter(levelDBFS: monitor.inputLevelDBFS)
                        .frame(height: 120)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Amplification")
                            Spacer()
                            Text(String(format: "%.0f×", monitor.gain))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Theme.accent)
                        }
                        Slider(
                            value: $monitor.gain,
                            in: LiveMonitor.gainRange
                        )
                        .tint(Theme.accent)
                    }
                    .padding()
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let message = monitor.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(monitor.requiresHeadphones ? Theme.warning : Theme.danger)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Headphones required. Raise the level gradually.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            monitor.isRunning ? monitor.stop() : await monitor.start()
                        }
                    } label: {
                        Label(
                            monitor.isRunning ? "Stop listening" : "Start listening",
                            systemImage: monitor.isRunning ? "stop.fill" : "ear.fill"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(monitor.isRunning ? Theme.danger : Theme.accent)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .navigationTitle("Live")
        }
    }
}
