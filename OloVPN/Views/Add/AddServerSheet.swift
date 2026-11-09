import SwiftUI

struct AddServerSheet: View {
    @EnvironmentObject private var store: ConfigStore
    @Environment(\.dismiss) private var dismiss

    enum Route: Hashable {
        case paste
        case subscription
        case manual
        case qr
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                MistBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Как добавить?")
                            .font(OloTheme.titleFont)
                            .foregroundStyle(OloTheme.ink)

                        Text("Выберите понятный способ. Большие кнопки — меньше ошибок.")
                            .font(OloTheme.bodyFont)
                            .foregroundStyle(OloTheme.inkSoft)

                        IconTileButton(
                            title: "Вставить ссылку",
                            subtitle: "ss:// · vless:// · или https:// подписка",
                            systemImage: "doc.on.clipboard.fill",
                            tint: OloTheme.signal
                        ) {
                            path.append(.paste)
                        }

                        IconTileButton(
                            title: "Подписка",
                            subtitle: "URL со списком серверов, обновление в один тап",
                            systemImage: "arrow.triangle.2.circlepath",
                            tint: Color(red: 0.18, green: 0.45, blue: 0.72)
                        ) {
                            path.append(.subscription)
                        }

                        IconTileButton(
                            title: "QR‑код",
                            subtitle: "Камера на iPhone или вставка ссылки с QR",
                            systemImage: "qrcode.viewfinder",
                            tint: Color(red: 0.55, green: 0.30, blue: 0.70)
                        ) {
                            path.append(.qr)
                        }

                        IconTileButton(
                            title: "Вручную",
                            subtitle: "Только нужные поля выбранного протокола",
                            systemImage: "slider.horizontal.3",
                            tint: Color(red: 0.86, green: 0.45, blue: 0.18)
                        ) {
                            path.append(.manual)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Новый сервер")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .paste:
                    PasteLinkView(
                        onSave: { server in
                            store.add(server)
                            dismiss()
                        },
                        onSaveMany: { servers in
                            servers.forEach(store.add)
                            dismiss()
                        }
                    )
                case .subscription:
                    SubscriptionView { servers in
                        servers.forEach(store.add)
                        dismiss()
                    }
                case .manual:
                    ManualServerView { server in
                        store.add(server)
                        dismiss()
                    }
                case .qr:
                    QRImportView { server in
                        store.add(server)
                        dismiss()
                    }
                }
            }
        }
    }
}
