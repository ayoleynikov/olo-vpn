import SwiftUI

struct ProtectView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var tunnel: TunnelManager
    @EnvironmentObject private var monitor: TrafficMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var ipInfo: PublicIPInfo?
    @State private var ipLoading = false
    @State private var ipError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MistBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Защита IP")
                            .font(OloTheme.titleFont)
                            .foregroundStyle(OloTheme.ink)

                        Text("Kill switch, DNS и IPv6 — чтобы настоящий IP и страна не светились.")
                            .font(OloTheme.bodyFont)
                            .foregroundStyle(OloTheme.inkSoft)

                        ipCard

                        toggleCard(
                            title: "Kill switch",
                            subtitle: "Если VPN упал — трафик режется, домашний IP не всплывает",
                            isOn: $tunnel.protection.killSwitch,
                            symbol: "bolt.shield.fill"
                        )
                        toggleCard(
                            title: "DNS через VPN",
                            subtitle: "Запросы имён идут в туннель, не к провайдеру",
                            isOn: $tunnel.protection.dnsThroughVPN,
                            symbol: "text.magnifyingglass"
                        )
                        toggleCard(
                            title: "Блок IPv6",
                            subtitle: "Частая дыра: IPv6 может показать реальный адрес",
                            isOn: $tunnel.protection.blockIPv6,
                            symbol: "6.circle.fill"
                        )
                        toggleCard(
                            title: "Локальная сеть",
                            subtitle: "Принтер и роутер в LAN остаются доступны",
                            isOn: $tunnel.protection.allowLAN,
                            symbol: "house.fill"
                        )

                        BigButton(
                            title: "Проверить утечки",
                            systemImage: "waveform.path.ecg",
                            style: .primary
                        ) {
                            monitor.runLeakScan(using: store)
                            Task { await refreshIP() }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Защита")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task { await refreshIP() }
        }
    }

    private var ipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Мой IP сейчас")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    Task { await refreshIP() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(ipLoading)
            }

            if ipLoading {
                ProgressView()
            } else if let ipInfo {
                Text(ipInfo.ip)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Text(ipInfo.summary)
                    .font(OloTheme.captionFont)
                    .foregroundStyle(OloTheme.inkSoft)
                if !ipInfo.org.isEmpty {
                    Text(ipInfo.org)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(OloTheme.inkSoft)
                }
                Text(store.connectionState == .connected
                     ? "Должен быть IP сервера VPN, не домашний"
                     : "VPN выключен — виден адрес провайдера")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(store.connectionState == .connected ? OloTheme.signalDeep : OloTheme.coral)
            } else if let ipError {
                Text(ipError)
                    .font(OloTheme.captionFont)
                    .foregroundStyle(OloTheme.coral)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OloTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func toggleCard(title: String, subtitle: String, isOn: Binding<Bool>, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(OloTheme.signalDeep)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Text(subtitle)
                    .font(OloTheme.captionFont)
                    .foregroundStyle(OloTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(OloTheme.signal)
        }
        .padding(16)
        .background(OloTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func refreshIP() async {
        ipLoading = true
        ipError = nil
        defer { ipLoading = false }
        do {
            ipInfo = try await IPCheckService.fetch()
        } catch {
            ipError = error.localizedDescription
        }
    }
}
