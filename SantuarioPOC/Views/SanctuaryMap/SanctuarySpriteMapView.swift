import SwiftUI
import SpriteKit

/// Container UIViewRepresentable para SKView, integrando gestos de UIPan e UIPinch
/// de alta sensibilidade e sem atrasos diretamente na cena SpriteKit.
struct SanctuarySpriteMapView: UIViewRepresentable {
    @ObservedObject var viewModel: SanctuaryMapViewModel
    let store: SanctuaryStore
    let openTerrain: (Terrain) -> Void
    let collect: (Terrain) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, store: store, openTerrain: openTerrain, collect: collect)
    }

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .clear
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = true
        skView.preferredFramesPerSecond = 120

        let scene = context.coordinator.scene
        skView.presentScene(scene)

        // Adiciona Gestos de Pan e Pinch nativos
        let panRecognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panRecognizer.maximumNumberOfTouches = 1
        skView.addGestureRecognizer(panRecognizer)

        let pinchRecognizer = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        skView.addGestureRecognizer(pinchRecognizer)

        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.update(viewModel: viewModel, store: store)
    }

    @MainActor
    final class Coordinator: NSObject {
        let scene = SanctuaryMapScene()
        var lastCenterRequest = 0
        var lastZoomIn = 0
        var lastZoomOut = 0

        private let viewModel: SanctuaryMapViewModel
        private let store: SanctuaryStore
        private let openTerrain: (Terrain) -> Void
        private let collect: (Terrain) -> Void

        init(
            viewModel: SanctuaryMapViewModel,
            store: SanctuaryStore,
            openTerrain: @escaping (Terrain) -> Void,
            collect: @escaping (Terrain) -> Void
        ) {
            self.viewModel = viewModel
            self.store = store
            self.openTerrain = openTerrain
            self.collect = collect
            super.init()

            scene.onSelectUndefinedLot = { [weak self] lotID in
                self?.viewModel.selectUndefinedLot(id: lotID)
            }

            scene.onOpenTerrain = { [weak self] terrain in
                self?.viewModel.openTerrain(terrain, callback: openTerrain)
            }

            scene.onCollectTerrain = { [weak self] terrain in
                self?.collect(terrain)
            }
        }

        private var lastCommittedZoom: CGFloat = 1.0

        func update(viewModel: SanctuaryMapViewModel, store: SanctuaryStore) {
            scene.sync(viewModel: viewModel, store: store)

            if viewModel.centerRequest != lastCenterRequest {
                lastCenterRequest = viewModel.centerRequest
                scene.centerOnSanctuary(animated: true)
            }

            if abs(viewModel.committedZoom - lastCommittedZoom) > 0.001 {
                lastCommittedZoom = viewModel.committedZoom
                let skScale = 1.0 / viewModel.committedZoom
                scene.setCameraScale(skScale, animated: true)
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            scene.handlePan(translation: translation, state: recognizer.state)
            if recognizer.state == .ended || recognizer.state == .cancelled {
                recognizer.setTranslation(.zero, in: view)
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            scene.handlePinch(scale: recognizer.scale, state: recognizer.state)
            if recognizer.state == .changed {
                recognizer.scale = 1.0
            }
        }
    }
}
