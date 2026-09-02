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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                LookoutWordmark()
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("A spare phone\nbecomes a watch.")
                        .font(.system(size: 36, weight: .regular, design: .serif))
                        .foregroundStyle(LookoutTheme.paper)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Same Wi-Fi. No account. No cloud.")
                        .font(.system(size: 15))
                        .foregroundStyle(LookoutTheme.mute)
                }

                VStack(alignment: .leading, spacing: 8) {
                    LookoutLabel(text: "Room")
                    TextField("Kitchen", text: $roomName)
                        .font(.system(.title3, design: .monospaced))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .lookoutField()
                }

                VStack(alignment: .leading, spacing: 10) {
                    LookoutLabel(text: "This phone is the")
                    Button {
                        saveRoom()
                        role = .camera
                    } label: {
                        roleRow(title: "Camera", detail: "Stays plugged in, points at the room.", icon: "video.fill")
                    }
                    .buttonStyle(LookoutPrimaryButton())

                    Button {
                        saveRoom()
                        role = .viewer
                    } label: {
                        roleRow(title: "Viewer", detail: "Finds cameras on this Wi-Fi.", icon: "eye.fill")
                    }
                    .buttonStyle(LookoutSecondaryButton())
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(LookoutTheme.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private func roleRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.6)
        }
        .padding(.horizontal, 16)
    }

    private func saveRoom() {
        let trimmed = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        roomName = trimmed.isEmpty ? "Kitchen" : trimmed
        UserDefaults.standard.set(roomName, forKey: LookoutDefaults.roomNameKey)
    }
}
