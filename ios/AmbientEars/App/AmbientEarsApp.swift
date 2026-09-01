import SwiftUI

@main
struct AmbientEarsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @StateObject private var library = RecordingLibrary()

    var body: some View {
        TabView {
            CaptureView(library: library)
                .tabItem { Label("Capture", systemImage: "waveform.badge.mic") }

            LibraryView(library: library)
                .tabItem { Label("Review", systemImage: "list.bullet") }

            LiveListenView()
                .tabItem { Label("Live", systemImage: "ear") }
        }
        .tint(Theme.accent)
    }
}

enum Theme {
    static let accent = Color(red: 0.0, green: 0.90, blue: 0.46)
    static let background = Color(red: 0.04, green: 0.06, blue: 0.04)
    static let card = Color(red: 0.06, green: 0.08, blue: 0.08)
    static let warning = Color(red: 1.0, green: 0.70, blue: 0.0)
    static let danger = Color(red: 1.0, green: 0.09, blue: 0.27)
}
