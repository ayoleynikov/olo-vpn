import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var monitor: TrafficMonitor
    @EnvironmentObject private var tunnel: TunnelManager
    @EnvironmentObject private var subscriptions: SubscriptionStore

    @State private var showAdd = false
    @State private var showMonitor = false
    @State private var showProtect = false
    @State private var appear = false
    @State private var pings: [UUID: PingResult] = [:]
    @State private var pinging = false
    @State private var connectError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MistBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        header
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 12)

                        ConnectOrb(
                            state: store.connectionState,
                            serverName: store.selectedServer?.displayName,
                            routingSummary: store.connectionState == .connected || store.connectionState == .connecting
                                ? store.routingSummary
                                : nil,
                            action: { toggleVPN() }
                        )
                        .opacity(appear ? 1 : 0)
                        .scaleEffect(appear ? 1 : 0.92)

                        if let connectError {
                            Text(connectError)
                                .font(OloTheme.captionFont)
                                .foregroundStyle(OloTheme.coral)
                                .multilineTextAlignment(.center)
                        }

                        RoutingControls(
                            routeMode: $store.routeMode,
                            localPolicy: $store.localPolicy,
                            localRegion: $store.localRegion
                        )

                        BigButton(
                            title: "Защита IP",
                            subtitle: tunnel.protection.killSwitch ? "Kill switch · DNS · IPv6" : "Настройте защиту от утечек",
                            systemImage: "checkmark.shield.fill",
                            style: .secondary
                        ) {
                            showProtect = true
                        }

                        BigButton(
                            title: "Монитор и лог",
                            subtitle: monitor.isLive
                                ? "↓ \(ByteFormat.string(monitor.downloadTotal)) · живые графики"
                                : "Куда идёт трафик, утечки, размер",
                            systemImage: "waveform.path.ecg",
                            style: .secondary
                        ) {
                            showMonitor = true
                        }

                        BigButton(
                            title: "Добавить сервер",
                            subtitle: "Ссылка · QR · подписка · вручную",
                            systemImage: "plus.circle.fill",
                            style: .primary
                        ) {
                            showAdd = true
                        }
                        .padding(.horizontal, 4)

                        serversSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(isPresented: $showAdd) {
                AddServerSheet()
                    .environmentObject(store)
                    #if os(macOS)
                    .frame(minWidth: 440, minHeight: 560)
                    #endif
            }
            .sheet(isPresented: $showMonitor) {
                MonitorView()
                    .environmentObject(store)
                    .environmentObject(monitor)
                    #if os(macOS)
                    .frame(minWidth: 480, minHeight: 640)
                    #endif
            }
            .sheet(isPresented: $showProtect) {
                ProtectView()
                    .environmentObject(store)
                    .environmentObject(tunnel)
                    .environmentObject(monitor)
                    #if os(macOS)
                    .frame(minWidth: 440, minHeight: 560)
                    #endif
            }
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    appear = true
                }
                Task {
                    await subscriptions.refreshDue(into: store)
                    await refreshPings()
                }
            }
            .onChange(of: tunnel.status) { _, newValue in
                store.applyTunnelStatus(newValue.oloConnectionState)
                monitor.bind(to: store)
            }
            .onChange(of: store.servers.count) { _, _ in
                Task { await refreshPings() }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Olo")
                    .font(OloTheme.brandFont)
                    .foregroundStyle(OloTheme.ink)
                Text("Открытый VPN для iPhone и Mac")
                    .font(OloTheme.captionFont)
                    .foregroundStyle(OloTheme.inkSoft)
            }
            Spacer()
            Text("OSS")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(OloTheme.signalDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(OloTheme.signal.opacity(0.14))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var serversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Серверы")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Spacer()
                Button {
                    Task { await refreshPings() }
                } label: {
                    HStack(spacing: 6) {
                        if pinging {
                            ProgressView().controlSize(.small)
                        }
                        Text(pinging ? "Пинг…" : "Пинг")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(OloTheme.signalDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OloTheme.signal.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(pinging || store.servers.isEmpty)

                Text("\(store.servers.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.inkSoft)
            }

            if store.servers.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.servers) { server in
                        ServerRow(
                            server: server,
                            isSelected: store.selectedID == server.id,
                            latencyLabel: pings[server.id]?.label
                        ) {
                            store.select(server)
                        }
                        .contextMenu {
                            Button {
                                Task {
                                    pings[server.id] = await PingService.ping(server: server)
                                }
                            } label: {
                                Label("Пинг", systemImage: "gauge.with.dots.needle.33percent")
                            }
                            Button(role: .destructive) {
                                store.delete(server)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(OloTheme.inkSoft)
            Text("Пока пусто")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.ink)
            Text("Добавьте ссылку, QR или подписку — всё по шагам и крупно.")
                .font(OloTheme.captionFont)
                .foregroundStyle(OloTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(OloTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(OloTheme.hairline, lineWidth: 1)
        )
    }

    private func toggleVPN() {
        connectError = nil
        switch store.connectionState {
        case .disconnected:
            Task {
                do {
                    store.applyTunnelStatus(.connecting)
                    monitor.bind(to: store)
                    try await tunnel.connect(store: store)
                } catch {
                    store.applyTunnelStatus(.disconnected)
                    monitor.bind(to: store)
                    #if targetEnvironment(simulator)
                    connectError = "Симулятор не поднимает VPN. Соберите на iPhone/Mac с Developer Team."
                    #else
                    connectError = error.localizedDescription
                        + " Проверьте подпись, Network Extension и App Group group.app.olo.vpn."
                    #endif
                }
            }
        case .connected:
            tunnel.disconnect()
            store.applyTunnelStatus(.disconnecting)
            monitor.bind(to: store)
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if store.connectionState == .disconnecting {
                    store.applyTunnelStatus(.disconnected)
                    monitor.bind(to: store)
                }
            }
        case .connecting, .disconnecting:
            break
        }
    }

    private func refreshPings() async {
        guard !store.servers.isEmpty else { return }
        pinging = true
        defer { pinging = false }
        pings = await PingService.pingAll(store.servers)
    }
}
