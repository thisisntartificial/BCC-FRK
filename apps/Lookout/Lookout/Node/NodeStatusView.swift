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
        VStack(spacing: 24) {
            HStack {
                Button("Change role", action: leave)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(controller.addressBlock)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)

            VStack(spacing: 8) {
                Text("PIN")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(controller.pin)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .tracking(8)
                Text("Enter this on the viewer phone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(controller.statusLine)
                .foregroundStyle(.green)
            if let error = controller.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Text("Keep this phone plugged in and this screen open.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
        .background(Color.black.ignoresSafeArea())
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
