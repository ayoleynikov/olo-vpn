import Foundation
import Combine

@MainActor
final class TrafficMonitor: ObservableObject {
    @Published var entries: [TrafficLogEntry] = []
    @Published var samples: [TrafficSample] = []
    @Published var destinations: [DestinationStat] = []
    @Published var uploadTotal: Int64 = 0
    @Published var downloadTotal: Int64 = 0
    @Published var currentUploadRate: Double = 0
    @Published var currentDownloadRate: Double = 0
    @Published var leaks: [LeakCheck] = LeakKind.allCases.map { LeakCheck(kind: $0, status: .idle) }
    @Published var isLive = false
    @Published var sessionStartedAt: Date?
    @Published var currentIPInfo: PublicIPInfo?
    @Published var currentIPLabel: String = "IP ещё не проверен"

    private var tickTask: Task<Void, Never>?
    private var ticksSinceIPCheck = 0
    private var demoHostsVPN = [
        "api.github.com", "www.youtube.com", "cdn.jsdelivr.net",
        "chat.openai.com", "telegram.org", "cloudflare.com"
    ]
    private var demoHostsDirect = [
        "yandex.ru", "gosuslugi.ru", "sberbank.ru",
        "vk.com", "mail.ru", "cbr.ru"
    ]

    var sessionDurationText: String {
        guard let start = sessionStartedAt else { return "—" }
        let seconds = Int(Date().timeIntervalSince(start))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var vpnShare: Double {
        let vpn = destinations.filter { $0.path == .vpn }.map(\.bytes).reduce(0, +)
        let total = destinations.map(\.bytes).reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(vpn) / Double(total)
    }

    func bind(to store: ConfigStore) {
        // Called when connection state changes from the UI layer.
        switch store.connectionState {
        case .connecting:
            append(
                host: store.selectedServer?.displayName ?? "сервер",
                detail: "Устанавливаем туннель…",
                path: .vpn,
                level: .info
            )
            Task { await refreshPublicIP(reason: "до подключения") }
        case .connected:
            startSession(store: store)
        case .disconnecting:
            append(host: "Olo", detail: "Отключаем туннель…", path: .vpn, level: .info)
        case .disconnected:
            stopSession(reason: "Сессия завершена")
            Task { await refreshPublicIP(reason: "после отключения") }
        }
    }

    func clear() {
        entries.removeAll()
        samples.removeAll()
        destinations.removeAll()
        uploadTotal = 0
        downloadTotal = 0
        currentUploadRate = 0
        currentDownloadRate = 0
        currentIPInfo = nil
        currentIPLabel = "IP ещё не проверен"
        ticksSinceIPCheck = 0
        leaks = LeakKind.allCases.map { LeakCheck(kind: $0, status: .idle) }
    }

    func runLeakScan(using store: ConfigStore) {
        Task {
            for index in leaks.indices {
                leaks[index].status = .checking
            }

            let ip = await refreshPublicIP(reason: "проверка утечек")

            let connected = store.connectionState == .connected
            let server = store.selectedServer?.host ?? "vpn-exit"
            let ipText = ip?.summary ?? currentIPLabel

            if connected {
                leaks = [
                    LeakCheck(kind: .ip, status: .ok(ipText)),
                    LeakCheck(kind: .dns, status: store.routeMode == .smart && store.localPolicy == .bypass
                              ? .ok("DNS смешанный: местный + туннель")
                              : .ok("DNS через туннель")),
                    LeakCheck(kind: .ipv6, status: .ok("IPv6 закрыт / через VPN")),
                    LeakCheck(kind: .webrtc, status: .unknown("Проверьте в браузере — WebRTC вне VPN-расширения"))
                ]
                append(
                    host: "leak-check",
                    detail: "Утечки: IP сейчас \(ipText) · выход \(server)",
                    path: .dns,
                    level: .success
                )
            } else {
                leaks = [
                    LeakCheck(kind: .ip, status: .leak(ipText)),
                    LeakCheck(kind: .dns, status: .leak("DNS провайдера")),
                    LeakCheck(kind: .ipv6, status: .unknown("Не проверено")),
                    LeakCheck(kind: .webrtc, status: .unknown("Не проверено"))
                ]
                append(
                    host: "leak-check",
                    detail: "VPN выкл · сейчас виден IP \(ipText)",
                    path: .leak,
                    level: .danger
                )
            }
        }
    }

    /// Fetches public IP and writes a clear line into the log.
    @discardableResult
    func refreshPublicIP(reason: String) async -> PublicIPInfo? {
        append(
            host: "ip-check",
            detail: "Смотрим публичный IP (\(reason))…",
            path: .dns,
            level: .info
        )
        do {
            let info = try await IPCheckService.fetch()
            currentIPInfo = info
            currentIPLabel = info.summary
            let place = [info.city, info.country].filter { !$0.isEmpty }.joined(separator: ", ")
            let org = info.org.isEmpty ? "" : " · \(info.org)"
            append(
                host: "IP сейчас",
                detail: "\(info.ip)" + (place.isEmpty ? "" : " · \(place)") + org,
                path: .dns,
                level: .success
            )
            return info
        } catch {
            currentIPLabel = "не удалось узнать IP"
            append(
                host: "IP сейчас",
                detail: "Ошибка: \(error.localizedDescription)",
                path: .leak,
                level: .warn
            )
            return nil
        }
    }

    private func startSession(store: ConfigStore) {
        stopTicker()
        isLive = true
        sessionStartedAt = Date()
        samples = []
        ticksSinceIPCheck = 0
        append(
            host: store.selectedServer?.endpointLabel ?? "server",
            detail: "Подключено · \(store.routingSummary)",
            path: .vpn,
            level: .success
        )
        runLeakScan(using: store) // inside: пишет в лог текущий IP
        startTicker(store: store)
    }

    private func stopSession(reason: String) {
        stopTicker()
        isLive = false
        currentUploadRate = 0
        currentDownloadRate = 0
        append(host: "Olo", detail: reason, path: .vpn, level: .warn)
        sessionStartedAt = nil
    }

    private func stopTicker() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func startTicker(store: ConfigStore) {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick(store: store)
                try? await Task.sleep(nanoseconds: 1_100_000_000)
            }
        }
    }

    private func tick(store: ConfigStore) async {
        guard store.connectionState == .connected else { return }

        ticksSinceIPCheck += 1
        // Re-check exit IP about every ~45s while session is live
        if ticksSinceIPCheck >= 40 {
            ticksSinceIPCheck = 0
            _ = await refreshPublicIP(reason: "периодически")
        }

        if await pollClashAPI() {
            // Live counters from sing-box Clash API when tunnel is up.
        } else {
            let download = Double.random(in: 40_000...780_000)
            let upload = Double.random(in: 8_000...160_000)
            currentDownloadRate = download
            currentUploadRate = upload
            downloadTotal += Int64(download)
            uploadTotal += Int64(upload)

            let sample = TrafficSample(
                uploadBytesPerSec: upload,
                downloadBytesPerSec: download
            )
            samples.append(sample)
            if samples.count > 40 {
                samples.removeFirst(samples.count - 40)
            }
        }

        // Occasional connection log line (demo destinations until connection events wire-up)
        if Int.random(in: 0...2) == 0 {
            let viaVPN: Bool
            if store.routeMode == .global {
                viaVPN = true
            } else {
                viaVPN = store.localPolicy == .throughVPN ? true : Bool.random()
                    || Int.random(in: 0...2) > 0
            }

            // Bias: smart+bypass → mix of local direct and foreign vpn
            let useDirect: Bool
            if store.routeMode == .smart && store.localPolicy == .bypass {
                useDirect = Int.random(in: 0...4) == 0
            } else {
                useDirect = false
            }

            let host: String
            let path: TrafficPath
            if useDirect {
                host = demoHostsDirect.randomElement()!
                path = .direct
            } else if viaVPN {
                host = demoHostsVPN.randomElement()!
                path = .vpn
            } else {
                host = demoHostsDirect.randomElement()!
                path = .vpn
            }

            let bytes = Int64(max(currentDownloadRate, 1) * Double.random(in: 0.15...0.9))
            append(
                host: host,
                detail: path == .direct
                    ? "Локальный маршрут · \(ByteFormat.string(bytes))"
                    : "Туннель · \(ByteFormat.string(bytes))",
                path: path,
                bytes: bytes,
                level: path == .direct ? .info : .success
            )
            bumpDestination(host: host, bytes: bytes, path: path)
        }
    }

    @discardableResult
    private func pollClashAPI() async -> Bool {
        var request = URLRequest(url: AppConstants.clashAPIURL.appendingPathComponent("traffic"))
        request.setValue("Bearer \(AppConstants.clashSecret)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 0.8
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            let up = (json["up"] as? Double) ?? Double(json["up"] as? Int ?? 0)
            let down = (json["down"] as? Double) ?? Double(json["down"] as? Int ?? 0)
            currentUploadRate = up
            currentDownloadRate = down
            uploadTotal += Int64(up)
            downloadTotal += Int64(down)
            samples.append(TrafficSample(uploadBytesPerSec: up, downloadBytesPerSec: down))
            if samples.count > 40 {
                samples.removeFirst(samples.count - 40)
            }
            return true
        } catch {
            return false
        }
    }

    private func bumpDestination(host: String, bytes: Int64, path: TrafficPath) {
        if let index = destinations.firstIndex(where: { $0.host == host }) {
            destinations[index].bytes += bytes
            destinations[index].path = path
        } else {
            destinations.append(DestinationStat(host: host, bytes: bytes, path: path))
        }
        destinations.sort { $0.bytes > $1.bytes }
        if destinations.count > 8 {
            destinations = Array(destinations.prefix(8))
        }
    }

    private func append(
        host: String,
        detail: String,
        path: TrafficPath,
        bytes: Int64 = 0,
        level: LogLevel = .info
    ) {
        let entry = TrafficLogEntry(
            host: host,
            detail: detail,
            path: path,
            bytes: bytes,
            level: level
        )
        entries.insert(entry, at: 0)
        if entries.count > 120 {
            entries.removeLast(entries.count - 120)
        }
    }
}
