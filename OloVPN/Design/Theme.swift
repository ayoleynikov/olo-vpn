import SwiftUI

enum OloTheme {
    // Atmosphere: cool mist + deep ink + signal teal. Not purple, not cream.
    static let mist = Color(red: 0.91, green: 0.94, blue: 0.96)
    static let mistDeep = Color(red: 0.84, green: 0.89, blue: 0.93)
    static let ink = Color(red: 0.06, green: 0.11, blue: 0.14)
    static let inkSoft = Color(red: 0.28, green: 0.35, blue: 0.40)
    static let signal = Color(red: 0.00, green: 0.66, blue: 0.62)
    static let signalDeep = Color(red: 0.00, green: 0.52, blue: 0.49)
    static let coral = Color(red: 0.91, green: 0.36, blue: 0.30)
    static let surface = Color.white.opacity(0.72)
    static let hairline = Color.black.opacity(0.06)

    static let brandFont = Font.system(size: 44, weight: .heavy, design: .rounded)
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let bodyFont = Font.system(size: 17, weight: .medium, design: .rounded)
    static let captionFont = Font.system(size: 14, weight: .medium, design: .rounded)
}

struct MistBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    OloTheme.mist,
                    Color(red: 0.88, green: 0.93, blue: 0.95),
                    OloTheme.mistDeep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft radial glow behind the connect area
            Circle()
                .fill(OloTheme.signal.opacity(0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 50)
                .offset(y: -40)

            // Subtle grid of dots — network atmosphere
            GeometryReader { geo in
                Canvas { context, size in
                    let step: CGFloat = 28
                    for x in stride(from: 0, through: size.width, by: step) {
                        for y in stride(from: 0, through: size.height, by: step) {
                            let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                            context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.04)))
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
