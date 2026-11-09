import SwiftUI

struct ServerRow: View {
    let server: VPNServer
    let isSelected: Bool
    var latencyLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? OloTheme.signal.opacity(0.16) : OloTheme.mistDeep.opacity(0.7))
                        .frame(width: 48, height: 48)
                    Image(systemName: server.proto.symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSelected ? OloTheme.signalDeep : OloTheme.inkSoft)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(server.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(OloTheme.ink)
                        .lineLimit(1)
                    Text("\(server.proto.title) · \(server.endpointLabel)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(OloTheme.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let latencyLabel {
                    Text(latencyLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(latencyColor(latencyLabel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(latencyColor(latencyLabel).opacity(0.12))
                        .clipShape(Capsule())
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(OloTheme.signal)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.92) : OloTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? OloTheme.signal.opacity(0.45) : OloTheme.hairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
    }

    private func latencyColor(_ label: String) -> Color {
        if label.contains("нет") || label == "—" { return OloTheme.coral }
        if let ms = Int(label.replacingOccurrences(of: " ms", with: "")) {
            if ms < 120 { return OloTheme.signalDeep }
            if ms < 250 { return Color(red: 0.86, green: 0.45, blue: 0.18) }
            return OloTheme.coral
        }
        return OloTheme.inkSoft
    }
}
