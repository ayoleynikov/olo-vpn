import SwiftUI

struct ConnectOrb: View {
    let state: ConnectionState
    let serverName: String?
    var routingSummary: String? = nil
    let action: () -> Void

    @State private var pulse = false

    private var isBusy: Bool {
        state == .connecting || state == .disconnecting
    }

    private var isOn: Bool {
        state == .connected
    }

    var body: some View {
        VStack(spacing: 18) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isOn ? OloTheme.signal.opacity(0.18) : Color.white.opacity(0.35))
                        .frame(width: 210, height: 210)
                        .scaleEffect(pulse && isOn ? 1.08 : 1)
                        .opacity(pulse && isOn ? 0.55 : 1)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isOn
                                    ? [OloTheme.signal, OloTheme.signalDeep]
                                    : [Color.white, OloTheme.mistDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 168, height: 168)
                        .shadow(
                            color: isOn ? OloTheme.signal.opacity(0.45) : .black.opacity(0.08),
                            radius: isOn ? 28 : 16,
                            y: 10
                        )

                    VStack(spacing: 8) {
                        if isBusy {
                            ProgressView()
                                .controlSize(.large)
                                .tint(isOn ? .white : OloTheme.ink)
                        } else {
                            Image(systemName: isOn ? "checkmark.shield.fill" : "power")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(isOn ? .white : OloTheme.ink)
                        }

                        Text(isOn ? "Вкл" : "Выкл")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(isOn ? .white : OloTheme.inkSoft)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(serverName == nil || isBusy)
            .opacity(serverName == nil ? 0.55 : 1)
            .accessibilityLabel(isOn ? "Отключить VPN" : "Подключить VPN")

            VStack(spacing: 6) {
                Text(state.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)

                Text(serverName ?? "Сначала добавьте сервер")
                    .font(OloTheme.captionFont)
                    .foregroundStyle(OloTheme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let routingSummary {
                    Text(routingSummary)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(OloTheme.signalDeep)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
        }
        .onAppear { startPulse() }
        .onChange(of: state) { _, newValue in
            if newValue == .connected {
                startPulse()
            }
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
