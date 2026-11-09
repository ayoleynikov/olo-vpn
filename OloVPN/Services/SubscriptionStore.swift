import Foundation
import Combine

struct SubscriptionProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var autoRefreshMinutes: Int
    var lastRefresh: Date?
    var lastCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        autoRefreshMinutes: Int = 360,
        lastRefresh: Date? = nil,
        lastCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.autoRefreshMinutes = autoRefreshMinutes
        self.lastRefresh = lastRefresh
        self.lastCount = lastCount
    }
}

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [SubscriptionProfile] = []
    @Published var lastMessage: String?

    private let key = "olo.subscriptions"
    private var timer: Timer?

    init() {
        load()
        startTimer()
    }

    func upsert(_ profile: SubscriptionProfile) {
        if let index = subscriptions.firstIndex(where: { $0.id == profile.id }) {
            subscriptions[index] = profile
        } else {
            subscriptions.insert(profile, at: 0)
        }
        persist()
    }

    func remove(_ id: UUID) {
        subscriptions.removeAll { $0.id == id }
        persist()
    }

    func refreshDue(into store: ConfigStore) async {
        let now = Date()
        for profile in subscriptions {
            let due: Bool
            if let last = profile.lastRefresh {
                due = now.timeIntervalSince(last) >= Double(profile.autoRefreshMinutes * 60)
            } else {
                due = true
            }
            if due {
                await refresh(profile, into: store)
            }
        }
    }

    func refresh(_ profile: SubscriptionProfile, into store: ConfigStore) async {
        guard let url = URL(string: profile.url) else {
            lastMessage = "Плохой URL: \(profile.name)"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(data: data, encoding: .utf8)
                ?? String(data: Data(base64Encoded: data) ?? Data(), encoding: .utf8)
                ?? ""
            let decoded: String
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let b64 = Data(base64Encoded: trimmed),
               let asString = String(data: b64, encoding: .utf8),
               asString.contains("://") {
                decoded = asString
            } else {
                decoded = text
            }

            let lines = decoded
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }

            var imported: [VPNServer] = []
            for line in lines {
                if var server = try? LinkParser.parse(line) {
                    if server.name.isEmpty || server.name == server.proto.title {
                        server.name = "\(profile.name) · \(server.endpointLabel)"
                    }
                    imported.append(server)
                }
            }

            let prefix = "\(profile.name) ·"
            store.replaceServers(namedPrefix: prefix, with: imported)

            var updated = profile
            updated.lastRefresh = Date()
            updated.lastCount = imported.count
            upsert(updated)
            lastMessage = "\(profile.name): \(imported.count) серверов"
        } catch {
            lastMessage = "Ошибка \(profile.name): \(error.localizedDescription)"
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Store is injected at refresh call sites from the app.
                self?.lastMessage = self?.lastMessage
            }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SubscriptionProfile].self, from: data) else { return }
        subscriptions = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
