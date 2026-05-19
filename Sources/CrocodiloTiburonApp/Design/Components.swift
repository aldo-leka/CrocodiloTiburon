import SwiftUI

struct CTPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CTTheme.Typography.button)
            .foregroundStyle(.white)
            .padding(.horizontal, CTTheme.Spacing.lg)
            .padding(.vertical, CTTheme.Spacing.md)
            .background(configuration.isPressed ? CTTheme.primaryActive : CTTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous))
    }
}

struct CTSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CTTheme.Typography.button)
            .foregroundStyle(CTTheme.ink)
            .padding(.horizontal, CTTheme.Spacing.lg)
            .padding(.vertical, CTTheme.Spacing.md)
            .background(CTTheme.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous)
                    .stroke(CTTheme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct CTCard<Content: View>: View {
    var background: Color = CTTheme.surfaceSoft
    var border: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(CTTheme.Spacing.lg)
            .background(background)
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous)
                        .stroke(border, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous))
    }
}

struct PillTag: View {
    var text: String
    var color: Color = CTTheme.surfaceStrong
    var textColor: Color = CTTheme.ink

    var body: some View {
        Text(text)
            .font(CTTheme.Typography.caption)
            .foregroundStyle(textColor)
            .padding(.horizontal, CTTheme.Spacing.sm)
            .padding(.vertical, CTTheme.Spacing.xs)
            .background(color)
            .clipShape(Capsule())
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(CTTheme.hairline)
            .frame(height: 1)
    }
}
