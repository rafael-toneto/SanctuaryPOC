import SwiftUI

struct MapLegendItem: View {
    let color: Color
    let title: String
    var hasBorder = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay {
                    if hasBorder {
                        Circle().stroke(.black.opacity(0.3), lineWidth: 1)
                    }
                }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SanctuaryTheme.cream)
        }
    }
}

struct SanctuaryMapBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.075, green: 0.15, blue: 0.125),
                    SanctuaryTheme.ink,
                    Color(red: 0.045, green: 0.13, blue: 0.105)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                let spacing: CGFloat = 90
                var path = Path()

                stride(from: CGFloat.zero, through: size.width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat.zero, through: size.height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }

                context.stroke(path, with: .color(.white.opacity(0.026)), lineWidth: 1)

                for index in 0..<8 {
                    let inset = CGFloat(index) * 70 + 80
                    let rect = CGRect(
                        x: inset,
                        y: inset * 0.92,
                        width: max(0, size.width - inset * 2),
                        height: max(0, size.height - inset * 1.84)
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(SanctuaryTheme.lime.opacity(0.022)),
                        lineWidth: 2
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension Biome {
    var mapAssetName: String {
        switch self {
        case .aquatic: "TerrainAquatic"
        case .wetland: "TerrainWetland"
        case .forest: "TerrainForest"
        case .grassland: "TerrainGrassland"
        }
    }

    var mapColor: Color {
        switch self {
        case .aquatic: Color(red: 0.11, green: 0.39, blue: 0.94)
        case .wetland: Color(red: 0.10, green: 0.72, blue: 0.67)
        case .forest: Color(red: 0.03, green: 0.68, blue: 0.04)
        case .grassland: Color(red: 0.68, green: 0.78, blue: 0.25)
        }
    }
}
