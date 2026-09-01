import SwiftUI

struct ViewerHomeView: View {
    var onLeave: () -> Void
    @State private var controller = ViewerController()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Roles", action: leave)
                    .foregroundStyle(LookoutTheme.mute)
                Spacer()
                Text(controller.statusLine.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(LookoutTheme.brass)
            }

            ZStack {
                LookoutTheme.panel
                if let data = controller.latestJPEG, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text("Waiting for a camera")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(LookoutTheme.mute)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .overlay(Rectangle().stroke(LookoutTheme.line, lineWidth: 1))

            TextField("PIN", text: $controller.pin)
                .keyboardType(.numberPad)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(LookoutTheme.paper)
                .padding(12)
                .background(LookoutTheme.panel)
                .overlay(Rectangle().stroke(LookoutTheme.line, lineWidth: 1))

            if controller.nodes.isEmpty {
                Text("No cameras on this Wi-Fi yet. Open Lookout on the spare phone and choose camera.")
                    .font(.footnote)
                    .foregroundStyle(LookoutTheme.mute)
            } else {
                ForEach(controller.nodes) { node in
                    Button("Connect to \(node.name)") {
                        controller.connect(to: node)
                    }
                    .buttonStyle(LookoutPrimaryButton())
                }
            }

            DisclosureGroup("Custom URL") {
                TextField("http://100.x.x.x:8787", text: $controller.customURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .background(LookoutTheme.panel)
                SecureField("Token", text: $controller.customToken)
                    .padding(10)
                    .background(LookoutTheme.panel)
                Button("Watch custom URL") {
                    controller.connectCustomURL()
                }
                .buttonStyle(LookoutSecondaryButton())
            }
            .tint(LookoutTheme.brass)
            .foregroundStyle(LookoutTheme.paper)

            if let error = controller.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.83, green: 0.42, blue: 0.29))
            }
            Spacer()
        }
        .padding(24)
        .background(LookoutTheme.ink.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear { controller.startBrowsing() }
        .onDisappear { controller.stop() }
    }

    private func leave() {
        controller.stop()
        onLeave()
    }
}
