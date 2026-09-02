import SwiftUI

struct ViewerHomeView: View {
    var onLeave: () -> Void
    @State private var controller = ViewerController()
    @State private var showCustom = false

    private var hasFrame: Bool { controller.latestJPEG != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LookoutViewfinder(
                    topLeft: hasFrame ? "Remote" : "Viewer",
                    topRight: "",
                    bottomLeft: "Wi-Fi",
                    bottomRight: controller.statusLine
                ) {
                    if let data = controller.latestJPEG, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "eye")
                                .font(.system(size: 28))
                                .foregroundStyle(LookoutTheme.brassDim)
                            Text("Waiting for a camera")
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(LookoutTheme.mute)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    LookoutLabel(text: "PIN from the camera phone")
                    TextField("000000", text: $controller.pin)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .lookoutField()
                }

                VStack(alignment: .leading, spacing: 10) {
                    LookoutLabel(text: "Cameras on this Wi-Fi")
                    if controller.nodes.isEmpty {
                        LookoutCard {
                            HStack(spacing: 10) {
                                ProgressView().tint(LookoutTheme.brass)
                                Text("Searching. Open Lookout on the spare phone and choose Camera.")
                                    .font(.footnote)
                                    .foregroundStyle(LookoutTheme.mute)
                            }
                        }
                    } else {
                        ForEach(controller.nodes) { node in
                            Button {
                                controller.connect(to: node)
                            } label: {
                                HStack {
                                    Image(systemName: "video.fill")
                                    Text(node.name)
                                    Spacer()
                                    Text("CONNECT")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .tracking(1.5)
                                }
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(LookoutPrimaryButton())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showCustom.toggle() }
                    } label: {
                        HStack {
                            LookoutLabel(text: "Custom URL")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(LookoutTheme.brassDim)
                                .rotationEffect(.degrees(showCustom ? 180 : 0))
                        }
                    }

                    if showCustom {
                        TextField("http://100.x.x.x:8787", text: $controller.customURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.system(.body, design: .monospaced))
                            .lookoutField()
                        SecureField("Token", text: $controller.customToken)
                            .font(.system(.body, design: .monospaced))
                            .lookoutField()
                        Button("Watch custom URL") {
                            controller.connectCustomURL()
                        }
                        .buttonStyle(LookoutSecondaryButton())
                    }
                }

                if let error = controller.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(LookoutTheme.danger)
                }
            }
            .padding(20)
        }
        .background(LookoutTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .onAppear { controller.startBrowsing() }
        .onDisappear { controller.stop() }
    }

    private var header: some View {
        HStack {
            Button(action: leave) {
                Label("Roles", systemImage: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LookoutTheme.mute)
            }
            Spacer()
            LookoutBadge(text: hasFrame ? "Live" : "Searching", mode: hasFrame ? .live : .wait)
        }
    }

    private func leave() {
        controller.stop()
        onLeave()
    }
}
