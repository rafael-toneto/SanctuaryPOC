import SwiftUI
import UIKit

enum SanctuaryTheme {
    static let ink = Color(red: 0.035, green: 0.11, blue: 0.085)
    static let deepForest = Color(red: 0.02, green: 0.17, blue: 0.12)
    static let forest = Color(red: 0.07, green: 0.30, blue: 0.18)
    static let moss = Color(red: 0.39, green: 0.58, blue: 0.22)
    static let lime = Color(red: 0.68, green: 0.83, blue: 0.32)
    static let cream = Color(red: 0.96, green: 0.95, blue: 0.86)
    static let sand = Color(red: 0.79, green: 0.72, blue: 0.51)
    static let warning = Color(red: 0.96, green: 0.64, blue: 0.23)
}

extension Biome {
    var mapTitle: String {
        switch self {
        case .grassland: "Planície"
        default: title
        }
    }

    var symbolName: String {
        switch self {
        case .aquatic: "water.waves"
        case .wetland: "drop.fill"
        case .forest: "tree.fill"
        case .grassland: "sun.max.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .aquatic: Color(red: 0.25, green: 0.72, blue: 0.84)
        case .wetland: Color(red: 0.42, green: 0.64, blue: 0.38)
        case .forest: Color(red: 0.25, green: 0.69, blue: 0.35)
        case .grassland: Color(red: 0.91, green: 0.73, blue: 0.27)
        }
    }

    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .aquatic:
            colors = [
                Color(red: 0.04, green: 0.39, blue: 0.51),
                Color(red: 0.10, green: 0.57, blue: 0.64)
            ]
        case .wetland:
            colors = [
                Color(red: 0.18, green: 0.36, blue: 0.20),
                Color(red: 0.36, green: 0.49, blue: 0.21)
            ]
        case .forest:
            colors = [
                Color(red: 0.04, green: 0.31, blue: 0.16),
                Color(red: 0.14, green: 0.48, blue: 0.22)
            ]
        case .grassland:
            colors = [
                Color(red: 0.43, green: 0.50, blue: 0.14),
                Color(red: 0.66, green: 0.62, blue: 0.20)
            ]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct SanctuaryBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [SanctuaryTheme.deepForest, SanctuaryTheme.ink],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(SanctuaryTheme.moss.opacity(0.14))
                    .frame(width: proxy.size.width * 0.9)
                    .blur(radius: 55)
                    .offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.32)

                Circle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: proxy.size.width * 0.75)
                    .blur(radius: 60)
                    .offset(x: -proxy.size.width * 0.45, y: proxy.size.height * 0.25)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 240))
                    .foregroundStyle(.white.opacity(0.025))
                    .rotationEffect(.degrees(-24))
                    .offset(x: proxy.size.width * 0.35, y: proxy.size.height * 0.32)
            }
        }
        .ignoresSafeArea()
    }
}

struct ResourcePill: View {
    let amount: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(SanctuaryTheme.lime)
            VStack(alignment: .leading, spacing: 0) {
                Text(Int(floor(amount)).formatted())
                    .font(.subheadline.bold())
                    .contentTransition(.numericText())
                Text("RECURSOS")
                    .font(.caption2.bold())
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recursos disponíveis")
        .accessibilityValue(Int(floor(amount)).formatted())
    }
}

struct BiomeBadge: View {
    let biome: Biome

    var body: some View {
        Label(biome.title, systemImage: biome.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SanctuaryTheme.cream)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.24), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12)))
    }
}

struct NoticeBanner: View {
    let notice: SanctuaryNotice

    var body: some View {
        Label(
            notice.message,
            systemImage: notice.kind == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(SanctuaryTheme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            notice.kind == .success ? SanctuaryTheme.lime : SanctuaryTheme.warning,
            in: Capsule()
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.message)
        .accessibilityAddTraits([.isStaticText, .updatesFrequently])
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: notice.message)
        }
    }
}

private struct SanctuaryNoticeOverlay: ViewModifier {
    @ObservedObject var store: SanctuaryStore
    let bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let notice = store.notice {
                    NoticeBanner(notice: notice)
                        .padding(.bottom, bottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: store.notice)
    }
}

extension View {
    func sanctuaryNoticeOverlay(store: SanctuaryStore, bottomPadding: CGFloat = 20) -> some View {
        modifier(SanctuaryNoticeOverlay(store: store, bottomPadding: bottomPadding))
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption2.bold())
                .tracking(1.5)
                .foregroundStyle(SanctuaryTheme.lime)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(SanctuaryTheme.cream)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(SanctuaryTheme.lime)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
    }
}

struct FilledActionButtonStyle: ButtonStyle {
    var tint: Color = SanctuaryTheme.lime

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(SanctuaryTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SoftActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SanctuaryTheme.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.06 : 0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
    }
}

enum SanctuaryHaptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
