import AVFoundation
import SwiftUI

struct NodeStatusView: View {
    let roomName: String
    var onLeave: () -> Void

    @State private var controller: NodeController
    @State private var cameraGranted = false

    init(roomName: String, onLeave: @escaping () -> Void) {
        self.roomName = roomName
        self.onLeave = onLeave
        _controller = State(initialValue: NodeController(roomName: roomName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button("Roles", action: leave)
                    .foregroundStyle(LookoutTheme.mute)
                Spacer()
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LookoutTheme.brass)
                    .foregroundStyle(LookoutTheme.ink)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ADDRESS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(LookoutTheme.brass.opacity(0.7))
                Text("\(controller.host):\(LookoutBonjour.httpPort)")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(LookoutTheme.paper)
                    .textSelection(.enabled)
                Text("LOOKOUT · \(roomName.uppercased()) · \(controller.statusLine.uppercased())")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(LookoutTheme.brass)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LookoutTheme.panel)
            .overlay(Rectangle().stroke(LookoutTheme.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("PIN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(LookoutTheme.brass.opacity(0.7))
                Text(controller.pin)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .foregroundStyle(LookoutTheme.paper)
                Text("Enter this on the viewer.")
                    .font(.footnote)
                    .foregroundStyle(LookoutTheme.mute)
            }

            if let error = controller.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.83, green: 0.42, blue: 0.29))
            }

            Text("Keep this phone plugged in and this screen open.")
                .font(.footnote)
                .foregroundStyle(LookoutTheme.mute)
            Spacer()
        }
        .padding(24)
        .background(LookoutTheme.ink.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task {
            await requestCamera()
            if cameraGranted {
                controller.start()
            }
        }
        .onDisappear {
            controller.stop()
        }
    }

    private func leave() {
        controller.stop()
        onLeave()
    }

    private func requestCamera() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraGranted = true
        case .notDetermined:
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
            if cameraGranted == false {
                controller.lastError = "Camera permission denied"
            }
        default:
            cameraGranted = false
            controller.lastError = "Enable Camera in Settings"
        }
    }
}
