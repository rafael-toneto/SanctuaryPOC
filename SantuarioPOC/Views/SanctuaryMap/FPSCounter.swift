import SwiftUI
import Combine

/// Monitor de taxa de quadros (FPS) baseado em CADisplayLink.
/// Conecta-se diretamente ao refresh rate nativo da tela (60Hz ou 120Hz ProMotion).
final class FPSCounter: ObservableObject {
    static let shared = FPSCounter()

    @Published private(set) var currentFPS: Double = 60.0
    @Published private(set) var nominalMaxFPS: Double = 60.0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var accumulatedDuration: CFTimeInterval = 0

    init() {
        start()
    }

    func start() {
        stop()
        let dl = CADisplayLink(target: self, selector: #selector(handleFrame(_:)))
        
        // Ativa suporte total a ProMotion / alta taxa de quadros nativa da tela
        if #available(iOS 15.0, *) {
            let maxHz = Float(UIScreen.main.maximumFramesPerSecond)
            nominalMaxFPS = Double(maxHz)
            dl.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: maxHz,
                preferred: maxHz
            )
        }
        
        dl.add(to: .main, forMode: .common)
        self.displayLink = dl
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
        accumulatedDuration = 0
    }

    @objc private func handleFrame(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        let delta = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp

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

    deinit {
        stop()
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
