import SwiftUI

struct RolePickerView: View {
    @State private var role: NodeRole?
    @State private var roomName = LookoutDefaults.roomName

    var body: some View {
        NavigationStack {
            Group {
                switch role {
                case .none:
                    picker
                case .camera:
                    NodeStatusView(roomName: roomName) {
                        role = nil
                    }
                case .viewer:
                    ViewerHomeView {
                        role = nil
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("LOOKOUT")
                .font(.system(size: 13, weight: .bold))
                .tracking(6)
                .foregroundStyle(LookoutTheme.brass)

            Text("A spare phone\nbecomes a watch.")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(LookoutTheme.paper)
                .fixedSize(horizontal: false, vertical: true)

            Text("Same Wi-Fi. No account. Keep the camera plugged in.")
                .font(.subheadline)
                .foregroundStyle(LookoutTheme.mute)

            VStack(alignment: .leading, spacing: 8) {
                Text("ROOM")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(LookoutTheme.brass.opacity(0.7))
                TextField("Kitchen", text: $roomName)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(LookoutTheme.paper)
                    .padding(12)
                    .background(LookoutTheme.panel)
                    .overlay(Rectangle().stroke(LookoutTheme.line, lineWidth: 1))
                    .textInputAutocapitalization(.words)
            }

            VStack(spacing: 10) {
                Button("This phone is the camera") {
                    saveRoom()
                    role = .camera
                }
                .buttonStyle(LookoutPrimaryButton())

                Button("This phone is the viewer") {
                    saveRoom()
                    role = .viewer
                }
                .buttonStyle(LookoutSecondaryButton())
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LookoutTheme.ink.ignoresSafeArea())
    }

    private func saveRoom() {
        let trimmed = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        roomName = trimmed.isEmpty ? "Kitchen" : trimmed
        UserDefaults.standard.set(roomName, forKey: LookoutDefaults.roomNameKey)
    }
}
