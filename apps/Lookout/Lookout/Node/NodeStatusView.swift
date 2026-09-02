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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LookoutViewfinder(
                    topLeft: roomName,
                    topRight: "Camera",
                    bottomLeft: "Wi-Fi",
                    bottomRight: cameraGranted ? controller.statusLine : "No camera"
                ) {
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(LookoutTheme.brassDim)
                        Text(cameraGranted ? "Broadcasting this room" : "Camera access needed")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(LookoutTheme.mute)
                    }
                }

                LookoutCard {
                    LookoutLabel(text: "Address")
                    Text("\(controller.host):\(LookoutBonjour.httpPort)")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LookoutTheme.paper)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    Text("\(roomName) · \(controller.statusLine)".uppercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(LookoutTheme.brass)
                }

                LookoutCard {
                    LookoutLabel(text: "PIN")
                    Text(controller.pin)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .tracking(10)
                        .foregroundStyle(LookoutTheme.paper)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("Enter this on the viewer.")
                        .font(.footnote)
                        .foregroundStyle(LookoutTheme.mute)
                }

                if let error = controller.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(LookoutTheme.danger)
                }

                Text("Keep this phone plugged in and this screen open.")
                    .font(.footnote)
                    .foregroundStyle(LookoutTheme.mute)
            }
            .padding(20)
        }
        .background(LookoutTheme.background)
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

    private var header: some View {
        HStack {
            Button(action: leave) {
                Label("Roles", systemImage: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LookoutTheme.mute)
            }
            Spacer()
            LookoutBadge(text: cameraGranted ? "Live" : "Off", mode: cameraGranted ? .live : .off)
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
