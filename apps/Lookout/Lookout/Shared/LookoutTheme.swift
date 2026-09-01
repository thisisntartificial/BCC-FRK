import SwiftUI

enum LookoutTheme {
    static let ink = Color(red: 0.047, green: 0.043, blue: 0.035)
    static let panel = Color(red: 0.086, green: 0.075, blue: 0.059)
    static let line = Color(red: 0.227, green: 0.196, blue: 0.149)
    static let brass = Color(red: 0.894, green: 0.761, blue: 0.478)
    static let paper = Color(red: 0.953, green: 0.902, blue: 0.769)
    static let mute = Color(red: 0.604, green: 0.561, blue: 0.478)
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
            .background(LookoutTheme.panel)
            .foregroundStyle(LookoutTheme.brass)
            .overlay(Rectangle().stroke(LookoutTheme.brass, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
