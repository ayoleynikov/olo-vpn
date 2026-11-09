import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PasteLinkView: View {
    let onSave: (VPNServer) -> Void
    var onSaveMany: (([VPNServer]) -> Void)? = nil

    @State private var link = ""
    @State private var preview: VPNServer?
    @State private var subscriptionPreview: [VPNServer] = []
    @State private var isLoadingSub = false
    @State private var errorText: String?
    @State private var hintText: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            MistBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Вставьте ссылку целиком")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(OloTheme.ink)

                    Text("Подойдёт ss:// · vless:// · trojan:// или https:// подписка (как в Shadowrocket).")
                        .font(OloTheme.captionFont)
                        .foregroundStyle(OloTheme.inkSoft)

                    TextEditor(text: $link)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .focused($focused)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .frame(minHeight: 140)
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(OloTheme.hairline, lineWidth: 1)
                        )
                        .onChange(of: link) { _, _ in
                            previewParse()
                        }

                    BigButton(
                        title: "Вставить из буфера",
                        systemImage: "doc.on.clipboard",
                        style: .secondary
                    ) {
                        #if os(iOS)
                        if let string = UIPasteboard.general.string {
                            link = string
                        }
                        #else
                        if let string = NSPasteboard.general.string(forType: .string) {
                            link = string
                        }
                        #endif
                    }

                    if SubscriptionImporter.isSubscriptionURL(link) {
                        BigButton(
                            title: isLoadingSub ? "Загрузка подписки…" : "Загрузить подписку",
                            subtitle: "Это URL списка серверов, не один узел",
                            systemImage: "arrow.triangle.2.circlepath",
                            style: .primary,
                            isLoading: isLoadingSub
                        ) {
                            Task { await loadSubscription() }
                        }
                    }

                    if let hintText {
                        Text(hintText)
                            .font(OloTheme.captionFont)
                            .foregroundStyle(OloTheme.signalDeep)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(OloTheme.captionFont)
                            .foregroundStyle(OloTheme.coral)
                    }

                    if let preview {
                        previewCard(preview)

                        BigButton(
                            title: "Сохранить сервер",
                            systemImage: "checkmark.circle.fill",
                            style: .primary
                        ) {
                            onSave(preview)
                        }
                    }

                    if !subscriptionPreview.isEmpty {
                        Text("Найдено серверов: \(subscriptionPreview.count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(OloTheme.ink)

                        ForEach(subscriptionPreview.prefix(8)) { server in
                            ServerRow(server: server, isSelected: false) {}
                                .disabled(true)
                        }
                        if subscriptionPreview.count > 8 {
                            Text("и ещё \(subscriptionPreview.count - 8)…")
                                .font(OloTheme.captionFont)
                                .foregroundStyle(OloTheme.inkSoft)
                        }

                        BigButton(
                            title: "Добавить все",
                            systemImage: "square.and.arrow.down.fill",
                            style: .primary
                        ) {
                            if let onSaveMany {
                                onSaveMany(subscriptionPreview)
                            } else {
                                subscriptionPreview.forEach(onSave)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Ссылка")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { focused = true }
    }

    private func previewCard(_ server: VPNServer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Проверьте перед сохранением")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.inkSoft)

            labeled("Имя", server.displayName)
            labeled("Протокол", server.proto.title)
            labeled("Адрес", server.endpointLabel)
            if !server.method.isEmpty {
                labeled("Шифрование", server.method)
            }
            if !server.transport.isEmpty {
                labeled("Транспорт", server.transport)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(OloTheme.signal.opacity(0.35), lineWidth: 2)
        )
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(OloTheme.captionFont)
                .foregroundStyle(OloTheme.inkSoft)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(OloTheme.ink)
            Spacer(minLength: 0)
        }
    }

    private func previewParse() {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        preview = nil
        subscriptionPreview = []
        errorText = nil
        hintText = nil

        guard !trimmed.isEmpty else { return }

        if SubscriptionImporter.isSubscriptionURL(trimmed) {
            let remark = SubscriptionImporter.remark(from: trimmed)
            hintText = "Это подписка Shadowrocket (https). Нажмите «Загрузить подписку»."
                + (remark.map { " Имя: \($0)" } ?? "")
            return
        }

        do {
            preview = try LinkParser.parse(trimmed)
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func loadSubscription() async {
        errorText = nil
        subscriptionPreview = []
        isLoadingSub = true
        defer { isLoadingSub = false }

        let remark = SubscriptionImporter.remark(from: link)
        do {
            let servers = try await SubscriptionImporter.fetchServers(
                from: link,
                namePrefix: remark
            )
            subscriptionPreview = servers
            hintText = "Подписка разобрана — \(servers.count) серверов"
        } catch {
            errorText = error.localizedDescription
        }
    }
}
