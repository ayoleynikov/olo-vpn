import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ManualServerView: View {
    let onSave: (VPNServer) -> Void

    /// nil = Авто — протокол подставится из ссылки или останется выбранным вручную после детекта
    @State private var proto: ProxyProtocol? = nil
    @State private var name = ""
    @State private var host = ""
    @State private var port = "443"
    @State private var password = ""
    @State private var uuid = ""
    @State private var method = "aes-256-gcm"
    @State private var sni = ""
    @State private var transport = "tcp"
    @State private var errorText: String?
    @State private var autoHint: String?
    @State private var detectedFromLink = false

    private var activeProto: ProxyProtocol {
        proto ?? .vless
    }

    var body: some View {
        ZStack {
            MistBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Протокол")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(OloTheme.inkSoft)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            autoChip
                            ForEach(ProxyProtocol.allCases) { item in
                                protoChip(item)
                            }
                        }
                    }

                    if let autoHint {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                            Text(autoHint)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(OloTheme.signalDeep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OloTheme.signal.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    BigButton(
                        title: "Вставить ссылку — определю сам",
                        subtitle: "ss:// · vless:// · trojan:// · hy2:// …",
                        systemImage: "wand.and.stars",
                        style: .secondary
                    ) {
                        pasteAndDetect()
                    }

                    field("Название", text: $name, placeholder: "Домашний сервер")
                    smartHostField
                    field("Порт", text: $port, placeholder: "443")

                    protocolFields

                    if let errorText {
                        Text(errorText)
                            .font(OloTheme.captionFont)
                            .foregroundStyle(OloTheme.coral)
                    }

                    BigButton(
                        title: "Сохранить",
                        systemImage: "checkmark.circle.fill",
                        style: .primary
                    ) {
                        save()
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Вручную")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if proto == nil {
                autoHint = "Авто: вставьте ссылку — протокол выберу сам"
            }
        }
    }

    private var autoChip: some View {
        let selected = proto == nil
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                proto = nil
                detectedFromLink = false
                autoHint = "Авто: вставьте ссылку — протокол выберу сам"
                errorText = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                Text("Авто")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected ? .white : OloTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? OloTheme.signal : Color.white.opacity(0.8))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(selected ? Color.clear : OloTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func protoChip(_ item: ProxyProtocol) -> some View {
        let selected = proto == item
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                proto = item
                detectedFromLink = false
                autoHint = nil
                errorText = nil
            }
        } label: {
            Text(item.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? .white : OloTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selected ? OloTheme.signal : Color.white.opacity(0.8))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(selected ? Color.clear : OloTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var smartHostField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Адрес или ссылка")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.inkSoft)
            TextField("example.com или ss://…", text: $host)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .padding(16)
                .background(Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .onChange(of: host) { _, newValue in
                    tryAutoDetect(from: newValue)
                }
        }
    }

    @ViewBuilder
    private var protocolFields: some View {
        switch activeProto {
        case .shadowsocks:
            field("Пароль", text: $password, placeholder: "секрет")
            field("Метод", text: $method, placeholder: "aes-256-gcm")
        case .trojan, .hysteria2:
            field("Пароль", text: $password, placeholder: "секрет")
            field("SNI", text: $sni, placeholder: "как в сертификате")
        case .vless, .vmess:
            field("UUID", text: $uuid, placeholder: "xxxxxxxx-xxxx-…")
            field("Транспорт", text: $transport, placeholder: "tcp / ws / grpc")
            field("SNI", text: $sni, placeholder: "опционально")
        case .tuic:
            field("UUID", text: $uuid, placeholder: "uuid")
            field("Пароль", text: $password, placeholder: "пароль")
        case .socks, .http:
            field("Логин", text: $uuid, placeholder: "опционально")
            field("Пароль", text: $password, placeholder: "опционально")
        case .wireguard:
            field("Приватный ключ", text: $password, placeholder: "base64")
            Text("Полный WireGuard-импорт из файла добавим следующим шагом.")
                .font(OloTheme.captionFont)
                .foregroundStyle(OloTheme.inkSoft)
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.inkSoft)
            TextField(placeholder, text: text)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .padding(16)
                .background(Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
        }
    }

    private func clipboardString() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #else
        return NSPasteboard.general.string(forType: .string)
        #endif
    }

    private func pasteAndDetect() {
        guard let string = clipboardString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else {
            errorText = "Буфер пуст — скопируйте ссылку"
            return
        }
        applyDetected(string)
    }

    private func tryAutoDetect(from raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Любая полная ссылка сразу переключает протокол и поля
        guard looksLikeProxyLink(trimmed) else { return }
        applyDetected(trimmed)
    }

    private func looksLikeProxyLink(_ value: String) -> Bool {
        let lower = value.lowercased()
        let prefixes = [
            "ss://", "vless://", "vmess://", "trojan://",
            "hysteria2://", "hy2://", "tuic://",
            "socks://", "socks5://", "http://", "https://"
        ]
        // http(s) alone is ambiguous — only treat as link if it has typical proxy query bits later;
        // for now skip plain https to avoid eating website URLs typed as host.
        return prefixes
            .filter { $0 != "http://" && $0 != "https://" }
            .contains { lower.hasPrefix($0) }
    }

    private func applyDetected(_ raw: String) {
        do {
            let server = try LinkParser.parse(raw)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                proto = server.proto
                name = server.name
                host = server.host
                port = String(server.port)
                password = server.password
                uuid = server.uuid
                method = server.method.isEmpty ? method : server.method
                sni = server.sni
                transport = server.transport.isEmpty ? transport : server.transport
                detectedFromLink = true
                autoHint = "Определён: \(server.proto.title)"
                errorText = nil
            }
        } catch {
            // If user is mid-typing a link, don't spam errors until paste button
            if raw.contains("://") {
                errorText = error.localizedDescription
            }
        }
    }

    private func save() {
        if proto == nil {
            errorText = "Выберите протокол или вставьте ссылку — определю сам"
            return
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty,
              !looksLikeProxyLink(trimmedHost),
              let portValue = Int(port),
              portValue > 0,
              portValue <= 65535 else {
            errorText = looksLikeProxyLink(trimmedHost)
                ? "Ссылка не разобралась — проверьте формат"
                : "Проверьте адрес и порт"
            return
        }

        let chosen = activeProto
        let server = VPNServer(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "\(chosen.title) · \(trimmedHost)"
                : name.trimmingCharacters(in: .whitespacesAndNewlines),
            proto: chosen,
            host: trimmedHost,
            port: portValue,
            password: password,
            uuid: uuid,
            method: method,
            sni: sni.isEmpty ? trimmedHost : sni,
            transport: transport
        )
        onSave(server)
    }
}
