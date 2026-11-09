import SwiftUI

struct RoutingControls: View {
    @Binding var routeMode: RouteMode
    @Binding var localPolicy: LocalTrafficPolicy
    @Binding var localRegion: LocalRegion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Маршрут")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(OloTheme.ink)

            HStack(spacing: 10) {
                ForEach(RouteMode.allCases) { mode in
                    modeCard(mode)
                }
            }

            if routeMode == .smart {
                localBlock
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: routeMode)
    }

    private func modeCard(_ mode: RouteMode) -> some View {
        let selected = routeMode == mode
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                routeMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(selected ? .white : OloTheme.signalDeep)

                Text(mode.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? .white : OloTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(mode.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : OloTheme.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        selected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [OloTheme.signal, OloTheme.signalDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                              )
                            : AnyShapeStyle(OloTheme.surface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? Color.clear : OloTheme.hairline, lineWidth: 1)
            )
            .shadow(color: selected ? OloTheme.signal.opacity(0.28) : .black.opacity(0.04), radius: selected ? 12 : 6, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var localBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Местные сайты")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(OloTheme.ink)
                Spacer()
                regionMenu
            }

            Text(localExplainer)
                .font(OloTheme.captionFont)
                .foregroundStyle(OloTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ForEach(LocalTrafficPolicy.allCases) { policy in
                    localButton(policy)
                }
            }
        }
        .padding(16)
        .background(OloTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(OloTheme.hairline, lineWidth: 1)
        )
    }

    private var regionMenu: some View {
        Menu {
            ForEach(LocalRegion.allCases) { region in
                Button {
                    localRegion = region
                } label: {
                    if localRegion == region {
                        Label(region.title, systemImage: "checkmark")
                    } else {
                        Text(region.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(localRegion.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(OloTheme.signalDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(OloTheme.signal.opacity(0.12))
            .clipShape(Capsule())
        }
        .accessibilityLabel("Регион местных сайтов")
    }

    private func localButton(_ policy: LocalTrafficPolicy) -> some View {
        let selected = localPolicy == policy
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                localPolicy = policy
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: policy.symbol)
                    .font(.system(size: 18, weight: .bold))
                Text(policy.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(policy.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(selected ? .white : OloTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? OloTheme.ink : Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Color.clear : OloTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(policy.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var localExplainer: String {
        switch localPolicy {
        case .bypass:
            return "Сайты региона «\(localRegion.title)» идут напрямую. Остальной интернет — через VPN. Так банки и местные сервисы обычно работают стабильнее."
        case .throughVPN:
            return "Даже сайты региона «\(localRegion.title)» идут через сервер. Удобно, если нужно скрыть и локальный IP."
        }
    }
}
