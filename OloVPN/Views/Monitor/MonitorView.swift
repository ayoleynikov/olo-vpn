import SwiftUI
import Charts

struct MonitorView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var monitor: TrafficMonitor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MistBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        liveHeader
                        totalsRow
                        speedChart
                        destinationChart
                        leakSection
                        logSection
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Монитор")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            monitor.runLeakScan(using: store)
                        } label: {
                            Label("Проверить утечки", systemImage: "waveform.path.ecg")
                        }
                        Button(role: .destructive) {
                            monitor.clear()
                        } label: {
                            Label("Очистить лог", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var liveHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(monitor.isLive ? OloTheme.signal.opacity(0.18) : OloTheme.mistDeep)
                    .frame(width: 52, height: 52)
                Circle()
                    .fill(monitor.isLive ? OloTheme.signal : OloTheme.inkSoft.opacity(0.35))
                    .frame(width: 14, height: 14)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(monitor.isLive ? "Живой трафик" : "Ожидание")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Text(monitor.isLive
                     ? "Сессия \(monitor.sessionDurationText) · \(store.routingSummary)"
                     : "Включите VPN — здесь появятся сайты, графики и утечки")
                    .font(OloTheme.captionFont)
                    .foregroundStyle(OloTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("IP сейчас: \(monitor.currentIPLabel)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.signalDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                Task { await monitor.refreshPublicIP(reason: "вручную") }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OloTheme.signalDeep)
                    .padding(10)
                    .background(OloTheme.signal.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Обновить IP")
        }
        .padding(16)
        .background(OloTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var totalsRow: some View {
        HStack(spacing: 10) {
            metricCard(
                title: "↓ Входящий",
                value: ByteFormat.string(monitor.downloadTotal),
                rate: ByteFormat.rate(monitor.currentDownloadRate),
                tint: OloTheme.signal
            )
            metricCard(
                title: "↑ Исходящий",
                value: ByteFormat.string(monitor.uploadTotal),
                rate: ByteFormat.rate(monitor.currentUploadRate),
                tint: Color(red: 0.18, green: 0.45, blue: 0.72)
            )
        }
    }

    private func metricCard(title: String, value: String, rate: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.inkSoft)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(OloTheme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(rate)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OloTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1.5)
        )
    }

    private var speedChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Скорость")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.ink)

            if monitor.samples.isEmpty {
                chartPlaceholder("График появится после подключения")
            } else {
                Chart {
                    ForEach(monitor.samples) { sample in
                        AreaMark(
                            x: .value("t", sample.date),
                            y: .value("↓", sample.downloadBytesPerSec / 1024)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [OloTheme.signal.opacity(0.35), OloTheme.signal.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("t", sample.date),
                            y: .value("↓", sample.downloadBytesPerSec / 1024)
                        )
                        .foregroundStyle(OloTheme.signal)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("t", sample.date),
                            y: .value("↑", sample.uploadBytesPerSec / 1024)
                        )
                        .foregroundStyle(Color(red: 0.18, green: 0.45, blue: 0.72))
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 3]))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(OloTheme.hairline)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(OloTheme.inkSoft)
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading) {
                    HStack(spacing: 14) {
                        legendDot(OloTheme.signal, "Входящий KB/s")
                        legendDot(Color(red: 0.18, green: 0.45, blue: 0.72), "Исходящий KB/s")
                    }
                }
                .frame(height: 180)
                .padding(14)
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var destinationChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Куда уходит")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Spacer()
                Text("VPN \(Int(monitor.vpnShare * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.signalDeep)
            }

            if monitor.destinations.isEmpty {
                chartPlaceholder("Здесь будут сайты и сервисы")
            } else {
                Chart(monitor.destinations) { item in
                    BarMark(
                        x: .value("bytes", item.bytes),
                        y: .value("host", item.host)
                    )
                    .foregroundStyle(by: .value("path", item.path.title))
                    .cornerRadius(6)
                }
                .chartForegroundStyleScale([
                    TrafficPath.vpn.title: OloTheme.signal,
                    TrafficPath.direct.title: Color(red: 0.86, green: 0.45, blue: 0.18),
                    TrafficPath.dns.title: Color(red: 0.18, green: 0.45, blue: 0.72),
                    TrafficPath.leak.title: OloTheme.coral,
                    TrafficPath.blocked.title: OloTheme.inkSoft
                ])
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(OloTheme.hairline)
                        AxisValueLabel {
                            if let bytes = value.as(Int64.self) {
                                Text(ByteFormat.string(bytes))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let host = value.as(String.self) {
                                Text(host)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(OloTheme.ink)
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: CGFloat(max(140, monitor.destinations.count * 28 + 40)))
                .padding(14)
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var leakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Утечки")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Spacer()
                Button {
                    monitor.runLeakScan(using: store)
                } label: {
                    Text("Проверить")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(OloTheme.signalDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(OloTheme.signal.opacity(0.14))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(monitor.leaks) { leak in
                    leakCard(leak)
                }
            }
        }
    }

    private func leakCard(_ leak: LeakCheck) -> some View {
        let tint: Color = {
            switch leak.status {
            case .ok: return OloTheme.signal
            case .leak: return OloTheme.coral
            case .checking: return Color(red: 0.18, green: 0.45, blue: 0.72)
            case .idle, .unknown: return OloTheme.inkSoft
            }
        }()

        let title: String = {
            switch leak.status {
            case .idle: return "Не проверено"
            case .checking: return "Проверяем…"
            case .ok(let s): return s
            case .leak(let s): return s
            case .unknown(let s): return s
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: leak.kind.symbol)
                    .foregroundStyle(tint)
                Text(leak.kind.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
            }
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(OloTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(OloTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
        )
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Лог")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.ink)

            if monitor.entries.isEmpty {
                chartPlaceholder("События подключений и сайтов появятся здесь")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(monitor.entries.prefix(40)) { entry in
                        logRow(entry)
                    }
                }
            }
        }
    }

    private func logRow(_ entry: TrafficLogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(pathColor(entry.path).opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: entry.path.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(pathColor(entry.path))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(entry.host)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(OloTheme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.date, style: .time)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(OloTheme.inkSoft)
                }
                Text(entry.detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(OloTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.path.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(pathColor(entry.path))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func pathColor(_ path: TrafficPath) -> Color {
        switch path {
        case .vpn: return OloTheme.signal
        case .direct: return Color(red: 0.86, green: 0.45, blue: 0.18)
        case .dns: return Color(red: 0.18, green: 0.45, blue: 0.72)
        case .leak: return OloTheme.coral
        case .blocked: return OloTheme.inkSoft
        }
    }

    private func chartPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(OloTheme.captionFont)
            .foregroundStyle(OloTheme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(28)
            .background(OloTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(OloTheme.inkSoft)
        }
    }
}
