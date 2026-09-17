import SwiftUI
import Combine

/// Monitor de taxa de quadros processados pela cena SpriteKit.
final class FPSCounter: ObservableObject {
    static let shared = FPSCounter()

    @Published private(set) var currentFPS: Double = 60.0
    @Published private(set) var nominalMaxFPS: Double = 60.0

    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var accumulatedDuration: CFTimeInterval = 0

    init() {
        nominalMaxFPS = Double(UIScreen.main.maximumFramesPerSecond)
    }

    /// Registra um frame que completou o ciclo de atualização do SpriteKit.
    func recordSpriteKitFrame(at timestamp: TimeInterval) {
        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }

        let delta = timestamp - lastTimestamp
        lastTimestamp = timestamp

        frameCount += 1
        accumulatedDuration += delta

        // Atualiza o valor a cada ~0.35s para não sobrecarregar com re-renders excessivos do SwiftUI
        if accumulatedDuration >= 0.35 {
            let fps = Double(frameCount) / accumulatedDuration
            self.currentFPS = min(nominalMaxFPS, max(0, fps))
            frameCount = 0
            accumulatedDuration = 0
        }
    }

}

/// View flutuante moderna para visualização do medidor de FPS e taxa da tela
struct FPSOverlayView: View {
    @ObservedObject var fpsCounter = FPSCounter.shared

    private var statusColor: Color {
        let ratio = fpsCounter.currentFPS / max(1.0, fpsCounter.nominalMaxFPS)
        if ratio >= 0.90 {
            return .green
        } else if ratio >= 0.70 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.8), radius: 3)

            Text("\(Int(round(fpsCounter.currentFPS))) FPS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)

            Text("/ \(Int(round(fpsCounter.nominalMaxFPS)))Hz")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.75), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }
}
