import SwiftUI
import UIKit

final class SanctuaryMapGestureGate: ObservableObject {
    private(set) var suppressesLotActions = false
    private var releaseWorkItem: DispatchWorkItem?

    func beginPinch() {
        releaseWorkItem?.cancel()
        suppressesLotActions = true
    }

    func finishPinch() {
        releaseWorkItem?.cancel()

        // SwiftUI can finish a Button's touch sequence just after UIKit reports
        // the pinch as ended. Keep actions blocked through that short window so
        // lifting the last finger can never be interpreted as a terrain tap.
        let workItem = DispatchWorkItem { [weak self] in
            self?.suppressesLotActions = false
        }
        releaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    deinit {
        releaseWorkItem?.cancel()
    }
}

final class SanctuaryMapUIScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        decelerationRate = .normal
    }
}

/// Observes a pinch even when it starts over a SwiftUI Button, but never
/// prevents another recognizer. The native UIScrollView pinch remains solely
/// responsible for scale, focal point and content offset.
final class SanctuaryMapPinchGestureRecognizer: UIPinchGestureRecognizer {
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}

struct SanctuaryZoomScrollView<Content: View>: UIViewRepresentable {
    @Binding var zoomScale: CGFloat

    let centerRequest: Int
    let minimumZoomScale: CGFloat
    let maximumZoomScale: CGFloat
    let canvasSize: CGSize
    let activeRectLimit: CGRect
    let ownedLotPositions: [CGPoint]
    let ownedSkeletonSegments: [SanctuaryMapSegment]
    let gestureGate: SanctuaryMapGestureGate
    let content: Content

    init(
        zoomScale: Binding<CGFloat>,
        centerRequest: Int,
        minimumZoomScale: CGFloat,
        maximumZoomScale: CGFloat,
        canvasSize: CGSize,
        activeRectLimit: CGRect,
        ownedLotPositions: [CGPoint],
        ownedSkeletonSegments: [SanctuaryMapSegment],
        gestureGate: SanctuaryMapGestureGate,
        @ViewBuilder content: () -> Content
    ) {
        _zoomScale = zoomScale
        self.centerRequest = centerRequest
        self.minimumZoomScale = minimumZoomScale
        self.maximumZoomScale = maximumZoomScale
        self.canvasSize = canvasSize
        self.activeRectLimit = activeRectLimit
        self.ownedLotPositions = ownedLotPositions
        self.ownedSkeletonSegments = ownedSkeletonSegments
        self.gestureGate = gestureGate
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            zoomScale: $zoomScale,
            gestureGate: gestureGate,
            activeRectLimit: activeRectLimit,
            ownedLotPositions: ownedLotPositions,
            ownedSkeletonSegments: ownedSkeletonSegments
        )
    }

    func makeUIView(context: Context) -> SanctuaryMapUIScrollView {
        let scrollView = SanctuaryMapUIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.pinchGestureRecognizer?.isEnabled = true
        scrollView.pinchGestureRecognizer?.cancelsTouchesInView = true

        let mapPinchGestureRecognizer = SanctuaryMapPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.observeMapPinch(_:))
        )
        mapPinchGestureRecognizer.delegate = context.coordinator
        mapPinchGestureRecognizer.cancelsTouchesInView = true
        mapPinchGestureRecognizer.delaysTouchesBegan = false
        scrollView.addGestureRecognizer(mapPinchGestureRecognizer)

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isMultipleTouchEnabled = true
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostingController.view)

        let widthConstraint = hostingController.view.widthAnchor.constraint(
            equalToConstant: canvasSize.width
        )
        let heightConstraint = hostingController.view.heightAnchor.constraint(
            equalToConstant: canvasSize.height
        )
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            hostingController.view.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            hostingController.view.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            hostingController.view.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            widthConstraint,
            heightConstraint
        ])

        context.coordinator.hostingController = hostingController
        context.coordinator.widthConstraint = widthConstraint
        context.coordinator.heightConstraint = heightConstraint
        context.coordinator.scrollView = scrollView
        context.coordinator.mapPinchGestureRecognizer = mapPinchGestureRecognizer
        return scrollView
    }

    func updateUIView(_ scrollView: SanctuaryMapUIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.zoomScale = $zoomScale
        coordinator.gestureGate = gestureGate
        coordinator.activeRectLimit = activeRectLimit
        coordinator.ownedLotPositions = ownedLotPositions
        coordinator.ownedSkeletonSegments = ownedSkeletonSegments
        coordinator.hostingController?.rootView = content
        coordinator.widthConstraint?.constant = canvasSize.width
        coordinator.heightConstraint?.constant = canvasSize.height

        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale

        let requestedZoom = min(maximumZoomScale, max(minimumZoomScale, zoomScale))
        coordinator.reconcilePinchCommit(
            requestedZoom: requestedZoom,
            in: scrollView
        )
        if !coordinator.isMapPinching,
           !scrollView.isZooming,
           !scrollView.isZoomBouncing,
           abs(scrollView.zoomScale - requestedZoom) > 0.001 {
            coordinator.isApplyingSwiftUIUpdate = true
            scrollView.setZoomScale(
                requestedZoom,
                animated: context.transaction.animation != nil
            )
            coordinator.isApplyingSwiftUIUpdate = false
        }

        coordinator.updateContentInsets(in: scrollView)

        if !coordinator.isMapPinching,
           !scrollView.isZooming,
           !scrollView.isZoomBouncing,
           !scrollView.isTracking,
           !scrollView.isDragging,
           !scrollView.isDecelerating {
            let current = scrollView.contentOffset
            let clamped = coordinator.clampOffset(current, in: scrollView)
            if abs(current.x - clamped.x) > 0.5 || abs(current.y - clamped.y) > 0.5 {
                coordinator.isClamping = true
                scrollView.contentOffset = clamped
                coordinator.isClamping = false
            }
        }

        guard coordinator.lastCenterRequest != centerRequest else { return }
        let shouldAnimate = coordinator.lastCenterRequest != nil
        coordinator.lastCenterRequest = centerRequest
        DispatchQueue.main.async {
            scrollView.layoutIfNeeded()
            coordinator.updateContentInsets(in: scrollView)
            coordinator.centerContent(in: scrollView, animated: shouldAnimate)
        }
    }

    static func dismantleUIView(
        _ scrollView: SanctuaryMapUIScrollView,
        coordinator: Coordinator
    ) {
        if let mapPinchGestureRecognizer = coordinator.mapPinchGestureRecognizer {
            scrollView.removeGestureRecognizer(mapPinchGestureRecognizer)
        }
        scrollView.delegate = nil
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var zoomScale: Binding<CGFloat>
        var gestureGate: SanctuaryMapGestureGate
        var activeRectLimit: CGRect
        var ownedLotPositions: [CGPoint]
        var ownedSkeletonSegments: [SanctuaryMapSegment]
        var hostingController: UIHostingController<Content>?
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        weak var scrollView: SanctuaryMapUIScrollView?
        weak var mapPinchGestureRecognizer: SanctuaryMapPinchGestureRecognizer?
        var lastCenterRequest: Int?
        var isApplyingSwiftUIUpdate = false
        var isClamping = false

        private var isPinchLifecycleActive = false
        private var pinchSettlementWorkItem: DispatchWorkItem?

        var isMapPinching: Bool {
            isPinchLifecycleActive
                || mapPinchGestureRecognizer?.state == .began
                || mapPinchGestureRecognizer?.state == .changed
        }

        init(
            zoomScale: Binding<CGFloat>,
            gestureGate: SanctuaryMapGestureGate,
            activeRectLimit: CGRect,
            ownedLotPositions: [CGPoint],
            ownedSkeletonSegments: [SanctuaryMapSegment]
        ) {
            self.zoomScale = zoomScale
            self.gestureGate = gestureGate
            self.activeRectLimit = activeRectLimit
            self.ownedLotPositions = ownedLotPositions
            self.ownedSkeletonSegments = ownedSkeletonSegments
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }

        @objc func observeMapPinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
            switch gestureRecognizer.state {
            case .began:
                pinchSettlementWorkItem?.cancel()
                isPinchLifecycleActive = true
                gestureGate.beginPinch()

            case .ended:
                if let scrollView {
                    commitCurrentZoom(from: scrollView)
                }
                gestureGate.finishPinch()
                settlePinchAfterBindingUpdate()

            case .cancelled:
                if let scrollView {
                    commitCurrentZoom(from: scrollView)
                }
                gestureGate.finishPinch()
                settlePinchAfterBindingUpdate()

            case .failed:
                gestureGate.finishPinch()
                isPinchLifecycleActive = false

            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let nativePinch = scrollView?.pinchGestureRecognizer else { return false }
            return gestureRecognizer === nativePinch || otherGestureRecognizer === nativePinch
        }

        func reconcilePinchCommit(
            requestedZoom: CGFloat,
            in scrollView: UIScrollView
        ) {
            guard isPinchLifecycleActive else { return }
            let recognizerState = mapPinchGestureRecognizer?.state
            guard recognizerState != .began, recognizerState != .changed else { return }
            guard abs(scrollView.zoomScale - requestedZoom) <= 0.001 else { return }

            pinchSettlementWorkItem?.cancel()
            pinchSettlementWorkItem = nil
            isPinchLifecycleActive = false
        }

        func clampOffset(_ offset: CGPoint, in scrollView: UIScrollView) -> CGPoint {
            guard !ownedLotPositions.isEmpty else { return offset }
            let zoom = scrollView.zoomScale
            let bounds = scrollView.bounds
            guard bounds.width > 0, bounds.height > 0 else { return offset }

            // 1. Centro proposto da câmera em coordenadas do canvas
            let proposedCenterX = (offset.x + bounds.width / 2) / zoom
            let proposedCenterY = (offset.y + bounds.height / 2) / zoom
            let p = CGPoint(x: proposedCenterX, y: proposedCenterY)

            // 2. Encontrar o ponto mais próximo no esqueleto orgânico dos terrenos comprados
            var minDistSq: CGFloat = .infinity
            var closestPoint = ownedLotPositions[0]

            for v in ownedLotPositions {
                let dx = p.x - v.x
                let dy = p.y - v.y
                let dSq = dx * dx + dy * dy
                if dSq < minDistSq {
                    minDistSq = dSq
                    closestPoint = v
                }
            }

            for seg in ownedSkeletonSegments {
                let abx = seg.end.x - seg.start.x
                let aby = seg.end.y - seg.start.y
                let apx = p.x - seg.start.x
                let apy = p.y - seg.start.y
                let segLenSq = abx * abx + aby * aby
                if segLenSq > 0.001 {
                    let t = max(0, min(1, (apx * abx + apy * aby) / segLenSq))
                    let proj = CGPoint(x: seg.start.x + t * abx, y: seg.start.y + t * aby)
                    let dx = p.x - proj.x
                    let dy = p.y - proj.y
                    let dSq = dx * dx + dy * dy
                    if dSq < minDistSq {
                        minDistSq = dSq
                        closestPoint = proj
                    }
                }
            }

            let minDistance = sqrt(minDistSq)

            // 3. Raio orgânico contínuo ao redor do esqueleto dos terrenos comprados
            let maxAllowedRadius: CGFloat = 130
            // Zona focal central da tela (círculo verde de 120pt de diâmetro -> 60pt de raio)
            // Impede que a borda do círculo central saia da área permitida ou penetre em frestas menores que ele
            let centerZoneRadius: CGFloat = 60

            var clampedCenterX = p.x
            var clampedCenterY = p.y

            // Se o centro somado ao seu raio de ocupação ultrapassar a área permitida
            if minDistance > (maxAllowedRadius - centerZoneRadius) && minDistance > 0.001 {
                let effectiveMax = max(10, maxAllowedRadius - centerZoneRadius)
                let factor = effectiveMax / minDistance
                clampedCenterX = closestPoint.x + (p.x - closestPoint.x) * factor
                clampedCenterY = closestPoint.y + (p.y - closestPoint.y) * factor
            }

            // 4. Converte o centro restrito para contentOffset inicial
            var clampedX = clampedCenterX * zoom - bounds.width / 2
            var clampedY = clampedCenterY * zoom - bounds.height / 2

            // 5. Contenção da Bounding Box Total (Impede que a Bounding Box amarela saia da tela)
            let boxMinX = activeRectLimit.minX * zoom
            let boxMaxX = activeRectLimit.maxX * zoom
            let boxMinY = activeRectLimit.minY * zoom
            let boxMaxY = activeRectLimit.maxY * zoom

            let viewportW = bounds.width
            let viewportH = bounds.height

            if (boxMaxX - boxMinX) >= viewportW {
                clampedX = min(max(clampedX, boxMinX), boxMaxX - viewportW)
            } else {
                clampedX = (boxMinX + boxMaxX - viewportW) / 2
            }

            if (boxMaxY - boxMinY) >= viewportH {
                clampedY = min(max(clampedY, boxMinY), boxMaxY - viewportH)
            } else {
                clampedY = (boxMinY + boxMaxY - viewportH) / 2
            }

            return CGPoint(x: clampedX, y: clampedY)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isApplyingSwiftUIUpdate, !isClamping else { return }
            let current = scrollView.contentOffset
            let clamped = clampOffset(current, in: scrollView)
            if abs(current.x - clamped.x) > 0.5 || abs(current.y - clamped.y) > 0.5 {
                isClamping = true
                scrollView.contentOffset = clamped
                isClamping = false
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            updateContentInsets(in: scrollView)
            guard !isClamping else { return }
            let current = scrollView.contentOffset
            let clamped = clampOffset(current, in: scrollView)
            if abs(current.x - clamped.x) > 0.5 || abs(current.y - clamped.y) > 0.5 {
                isClamping = true
                scrollView.contentOffset = clamped
                isClamping = false
            }
        }

        func scrollViewDidEndZooming(
            _ scrollView: UIScrollView,
            with view: UIView?,
            atScale scale: CGFloat
        ) {
            guard !isApplyingSwiftUIUpdate else { return }
            commitCurrentZoom(from: scrollView)
        }

        func updateContentInsets(in scrollView: UIScrollView) {
            let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
            let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
            let updatedInsets = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
            let currentInsets = scrollView.contentInset
            guard abs(currentInsets.top - updatedInsets.top) > 0.001
                    || abs(currentInsets.left - updatedInsets.left) > 0.001
                    || abs(currentInsets.bottom - updatedInsets.bottom) > 0.001
                    || abs(currentInsets.right - updatedInsets.right) > 0.001
            else { return }
            scrollView.contentInset = updatedInsets
        }

        func centerContent(in scrollView: UIScrollView, animated: Bool) {
            let zoom = scrollView.zoomScale
            let bounds = scrollView.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }

            let targetX = activeRectLimit.midX * zoom - bounds.width / 2
            let targetY = activeRectLimit.midY * zoom - bounds.height / 2
            let clamped = clampOffset(CGPoint(x: targetX, y: targetY), in: scrollView)
            scrollView.setContentOffset(clamped, animated: animated)
        }

        private func settlePinchAfterBindingUpdate() {
            guard pinchSettlementWorkItem == nil else { return }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pinchSettlementWorkItem = nil
                self.isPinchLifecycleActive = false
            }
            pinchSettlementWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
        }

        private func commitCurrentZoom(from scrollView: UIScrollView) {
            let clampedZoom = min(
                scrollView.maximumZoomScale,
                max(scrollView.minimumZoomScale, scrollView.zoomScale)
            )
            guard abs(zoomScale.wrappedValue - clampedZoom) > 0.001 else { return }
            zoomScale.wrappedValue = clampedZoom
        }
    }
}
