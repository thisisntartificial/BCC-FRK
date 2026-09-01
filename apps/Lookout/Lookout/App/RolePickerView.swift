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
        VStack(spacing: 28) {
            Spacer()
            Text("LOOKOUT")
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .tracking(4)
            Text("Spare iPhone camera. Same Wi-Fi. No account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("ROOM NAME")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Kitchen", text: $roomName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
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
            .padding(.horizontal, 32)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func saveRoom() {
        let trimmed = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        roomName = trimmed.isEmpty ? "Kitchen" : trimmed
        UserDefaults.standard.set(roomName, forKey: LookoutDefaults.roomNameKey)
    }
}

struct LookoutPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct LookoutSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.08))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
