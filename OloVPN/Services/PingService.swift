import Foundation
import Network

struct PingResult: Identifiable, Equatable {
    let id: UUID
    let serverID: UUID
    let latencyMs: Int?
    let error: String?

    var label: String {
        if let latencyMs {
            return "\(latencyMs) ms"
        }
        return error ?? "—"
    }
}

enum PingService {
    /// TCP connect latency to host:port (no root / ICMP needed).
    static func ping(server: VPNServer, timeout: TimeInterval = 3) async -> PingResult {
        let start = Date()
        do {
            try await tcpConnect(host: server.host, port: UInt16(clamping: server.port), timeout: timeout)
            let ms = max(1, Int(Date().timeIntervalSince(start) * 1000))
            return PingResult(id: UUID(), serverID: server.id, latencyMs: ms, error: nil)
        } catch {
            return PingResult(id: UUID(), serverID: server.id, latencyMs: nil, error: "нет ответа")
        }
    }

    static func pingAll(_ servers: [VPNServer]) async -> [UUID: PingResult] {
        await withTaskGroup(of: PingResult.self) { group in
            for server in servers {
                group.addTask { await ping(server: server) }
            }
            var map: [UUID: PingResult] = [:]
            for await result in group {
                map[result.serverID] = result
            }
            return map
        }
    }

    private static func tcpConnect(host: String, port: UInt16, timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            let lock = NSLock()
            var resumed = false
            let finish: (Result<Void, Error>) -> Void = { result in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                cont.resume(with: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(()))
                case .failed(let error):
                    finish(.failure(error))
                case .cancelled:
                    break
                default:
                    break
                }
            }
            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(.failure(URLError(.timedOut)))
            }
        }
    }
}
