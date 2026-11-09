import SwiftUI

struct SubscriptionView: View {
    let onImport: ([VPNServer]) -> Void

    @State private var name = "Моя подписка"
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var imported: [VPNServer] = []

    var body: some View {
        ZStack {
            MistBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Название", text: $name, placeholder: "Например, Дом")
                    field("URL подписки", text: $urlString, placeholder: "https://…")

                    BigButton(
                        title: isLoading ? "Загрузка…" : "Обновить подписку",
                        systemImage: "arrow.clockwise.circle.fill",
                        style: .primary,
                        isLoading: isLoading
                    ) {
                        Task { await fetch() }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(OloTheme.captionFont)
                            .foregroundStyle(OloTheme.coral)
                    }

                    if !imported.isEmpty {
                        Text("Найдено серверов: \(imported.count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(OloTheme.ink)

                        ForEach(imported.prefix(6)) { server in
                            ServerRow(server: server, isSelected: false) {}
                                .disabled(true)
                        }

                        if imported.count > 6 {
                            Text("и ещё \(imported.count - 6)…")
                                .font(OloTheme.captionFont)
                                .foregroundStyle(OloTheme.inkSoft)
                        }

                        BigButton(
                            title: "Добавить все",
                            systemImage: "square.and.arrow.down.fill",
                            style: .primary
                        ) {
                            onImport(imported)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Подписка")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

    @MainActor
    private func fetch() async {
        errorText = nil
        imported = []
        isLoading = true
        defer { isLoading = false }

        do {
            imported = try await SubscriptionImporter.fetchServers(
                from: urlString,
                namePrefix: name
            )
        } catch {
            errorText = error.localizedDescription
        }
    }
}
