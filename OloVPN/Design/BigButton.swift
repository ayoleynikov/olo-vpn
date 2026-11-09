import SwiftUI

struct BigButton: View {
    enum Style {
        case primary
        case danger
        case secondary
        case ghost
    }

    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var style: Style = .primary
    var isLoading: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            action()
        }) {
            HStack(spacing: 14) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .opacity(0.8)
                    }
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .padding(.vertical, subtitle == nil ? 20 : 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(border, lineWidth: style == .ghost || style == .secondary ? 1.5 : 0)
            )
            .shadow(color: shadow, radius: pressed ? 4 : 14, y: pressed ? 2 : 8)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.12)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { pressed = false }
                }
        )
        .accessibilityLabel(title)
    }

    private var foreground: Color {
        switch style {
        case .primary, .danger: return .white
        case .secondary, .ghost: return OloTheme.ink
        }
    }

    private var background: some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [OloTheme.signal, OloTheme.signalDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .danger:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [OloTheme.coral, Color(red: 0.78, green: 0.22, blue: 0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(OloTheme.surface)
        case .ghost:
            return AnyShapeStyle(Color.clear)
        }
    }

    private var border: Color {
        switch style {
        case .secondary: return OloTheme.hairline
        case .ghost: return OloTheme.ink.opacity(0.18)
        default: return .clear
        }
    }

    private var shadow: Color {
        switch style {
        case .primary: return OloTheme.signal.opacity(0.35)
        case .danger: return OloTheme.coral.opacity(0.30)
        default: return .black.opacity(0.06)
        }
    }
}

struct IconTileButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 58, height: 58)
                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(OloTheme.ink)
                    Text(subtitle)
                        .font(OloTheme.captionFont)
                        .foregroundStyle(OloTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OloTheme.inkSoft.opacity(0.6))
            }
            .padding(16)
            .background(OloTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(OloTheme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: pressed ? 2 : 10, y: pressed ? 1 : 4)
            .scaleEffect(pressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.12)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { pressed = false }
                }
        )
    }
}
