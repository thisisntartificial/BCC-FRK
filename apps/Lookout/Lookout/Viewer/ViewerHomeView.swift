import SwiftUI

struct ViewerHomeView: View {
    var onLeave: () -> Void
    @State private var controller = ViewerController()

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Change role", action: leave)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(controller.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let data = controller.latestJPEG, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxHeight: 320)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 200)
                    .overlay {
                        Text("No feed yet")
                            .foregroundStyle(.secondary)
                    }
            }

            TextField("PIN from camera", text: $controller.pin)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.system(.title3, design: .monospaced))

            if controller.nodes.isEmpty {
                Text("No cameras on this Wi-Fi yet. Open Lookout on the spare phone and choose camera.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(controller.nodes) { node in
                    Button("Connect to \(node.name)") {
                        controller.connect(to: node)
                    }
                    .buttonStyle(LookoutPrimaryButton())
                }
            }

            DisclosureGroup("Custom URL (your route)") {
                TextField("http://100.x.x.x:8787", text: $controller.customURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Token (if required)", text: $controller.customToken)
                    .textFieldStyle(.roundedBorder)
                Button("Connect custom URL") {
                    controller.connectCustomURL()
                }
                .buttonStyle(LookoutSecondaryButton())
            }
            .padding(.top, 8)

            if let error = controller.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(24)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear { controller.startBrowsing() }
        .onDisappear { controller.stop() }
    }

    private func leave() {
        controller.stop()
        onLeave()
    }
}
