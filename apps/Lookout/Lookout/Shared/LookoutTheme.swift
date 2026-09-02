import SwiftUI

enum LookoutTheme {
    static let ink = Color(red: 0.047, green: 0.043, blue: 0.035)
    static let ink2 = Color(red: 0.027, green: 0.024, blue: 0.020)
    static let panel = Color(red: 0.086, green: 0.075, blue: 0.059)
    static let panel2 = Color(red: 0.114, green: 0.098, blue: 0.078)
    static let line = Color(red: 0.227, green: 0.196, blue: 0.149)
    static let lineSoft = Color(red: 0.149, green: 0.129, blue: 0.102)
    static let brass = Color(red: 0.894, green: 0.761, blue: 0.478)
    static let brassDim = Color(red: 0.541, green: 0.439, blue: 0.251)
    static let paper = Color(red: 0.953, green: 0.902, blue: 0.769)
    static let mute = Color(red: 0.604, green: 0.561, blue: 0.478)
    static let danger = Color(red: 0.83, green: 0.42, blue: 0.29)

    /// Page background with the same warm top glow as the computer viewer.
    static var background: some View {
        ZStack {
            ink
            RadialGradient(
                colors: [Color(red: 0.165, green: 0.133, blue: 0.094), .clear],
                center: UnitPoint(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Type

/// Small brass tracking label: ADDRESS, PIN, ROOM.
struct LookoutLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(2.6)
            .foregroundStyle(LookoutTheme.brassDim)
    }
}

/// Wordmark used in every screen header.
struct LookoutWordmark: View {
    var body: some View {
        Text("LOOKOUT")
            .font(.system(size: 12, weight: .bold))
            .tracking(5.5)
            .foregroundStyle(LookoutTheme.brass)
    }
}

/// Pill status badge: LIVE (brass), or muted for connecting / offline.
struct LookoutBadge: View {
    enum Mode { case live, wait, off }
    let text: String
    var mode: Mode = .live

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(mode == .live ? LookoutTheme.brass : LookoutTheme.panel2)
        .foregroundStyle(mode == .live ? LookoutTheme.ink : (mode == .wait ? LookoutTheme.brass : LookoutTheme.mute))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(mode == .live ? .clear : LookoutTheme.line, lineWidth: 1))
    }

    private var dot: Color {
        switch mode {
        case .live: return LookoutTheme.ink
        case .wait: return LookoutTheme.brass
        case .off: return LookoutTheme.danger
        }
    }
}

// MARK: - Containers

/// Bordered plaque (address block, PIN block).
struct LookoutCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [LookoutTheme.panel2, LookoutTheme.panel], startPoint: .top, endPoint: .bottom)
            )
            .overlay(Rectangle().stroke(LookoutTheme.line, lineWidth: 1))
    }
}

/// Viewfinder chrome: brass corner brackets + HUD strips, matching the computer viewer.
struct LookoutViewfinder<Content: View>: View {
    var topLeft: String
    var topRight: String
    var bottomLeft: String
    var bottomRight: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LookoutTheme.ink2
            content
            hud
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipped()
        .overlay(Rectangle().stroke(LookoutTheme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
    }

    private var hud: some View {
        VStack {
            HStack {
                corner(.topLeading)
                hudText(topLeft, dim: false)
                Spacer()
                hudText(topRight, dim: true)
                corner(.topTrailing)
            }
            Spacer()
            HStack {
                corner(.bottomLeading)
                hudText(bottomLeft, dim: true)
                Spacer()
                hudText(bottomRight, dim: false)
                corner(.bottomTrailing)
            }
        }
        .padding(12)
        .allowsHitTesting(false)
    }

    private func hudText(_ text: String, dim: Bool) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(dim ? LookoutTheme.mute : LookoutTheme.brass)
            .shadow(color: .black, radius: 4)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
    }

    private func corner(_ alignment: Alignment) -> some View {
        Path { path in
            let size: CGFloat = 20
            switch alignment {
            case .topLeading:
                path.move(to: CGPoint(x: 0, y: size)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: size, y: 0))
            case .topTrailing:
                path.move(to: CGPoint(x: 0, y: 0)); path.addLine(to: CGPoint(x: size, y: 0)); path.addLine(to: CGPoint(x: size, y: size))
            case .bottomLeading:
                path.move(to: .zero); path.addLine(to: CGPoint(x: 0, y: size)); path.addLine(to: CGPoint(x: size, y: size))
            default:
                path.move(to: CGPoint(x: 0, y: size)); path.addLine(to: CGPoint(x: size, y: size)); path.addLine(to: CGPoint(x: size, y: 0))
            }
        }
        .stroke(LookoutTheme.brass, lineWidth: 2)
        .frame(width: 20, height: 20)
    }
}

// MARK: - Controls

struct LookoutField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(LookoutTheme.paper)
            .padding(12)
            .background(Color(red: 0.063, green: 0.055, blue: 0.043))
            .overlay(Rectangle().stroke(LookoutTheme.line, lineWidth: 1))
    }
}

extension View {
    func lookoutField() -> some View { modifier(LookoutField()) }
}

struct LookoutPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .tracking(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LookoutTheme.brass)
            .foregroundStyle(LookoutTheme.ink)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct LookoutSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .tracking(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? LookoutTheme.brass.opacity(0.12) : Color.clear)
            .foregroundStyle(LookoutTheme.brass)
            .overlay(Rectangle().stroke(LookoutTheme.brass, lineWidth: 1))
    }
}
