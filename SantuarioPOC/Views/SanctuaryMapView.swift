import SwiftUI
import UIKit

private final class SanctuaryMapGestureGate: ObservableObject {
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

struct SanctuaryMapView: View {
    @ObservedObject var store: SanctuaryStore
    let openTerrain: (Terrain) -> Void
    let collect: (Terrain) -> Void

    private let minimumZoom: CGFloat = 0.55
    private let maximumZoom: CGFloat = 2.25

    @State private var selectedUndefinedLotID: Int?
    @State private var committedZoom: CGFloat = 1
    @State private var centerRequest = 0
    @StateObject private var gestureGate = SanctuaryMapGestureGate()

    private var lotCount: Int {
        let lastOccupiedSlot = store.state.terrains.compactMap(\.mapSlot).max() ?? -1
        let requiredCount = max(lastOccupiedSlot + 1, store.state.terrains.count + 8)
        let completeTrios = (requiredCount + 2) / 3 * 3
        return max(21, completeTrios)
    }

    private var lots: [SanctuaryMapLot] {
        SanctuaryMapLayout.lots(count: lotCount, canvasSize: canvasSize)
    }

    private var canvasSize: CGSize {
        SanctuaryMapLayout.canvasSize(for: lotCount)
    }

    var body: some View {
        ZStack {
            SanctuaryZoomScrollView(
                zoomScale: $committedZoom,
                centerRequest: centerRequest,
                minimumZoomScale: minimumZoom,
                maximumZoomScale: maximumZoom,
                canvasSize: canvasSize,
                gestureGate: gestureGate
            ) {
                ZStack(alignment: .topLeading) {
                    SanctuaryMapBackdrop()

                    ForEach(lots) { lot in
                        lotView(for: lot)
                            .frame(
                                width: SanctuaryMapLayout.lotInteractionSize.width,
                                height: SanctuaryMapLayout.lotInteractionSize.height
                            )
                            .position(lot.position)
                            .zIndex(terrain(at: lot.id) == nil ? 0 : 2)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
            }
            .background(SanctuaryTheme.ink)
            .accessibilityLabel("Mapa navegável do santuário")

            mapInstructions

            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        mapControlButton(
                            systemImage: "minus.magnifyingglass",
                            accessibilityLabel: "Diminuir mapa"
                        ) {
                            updateZoom(by: 0.8)
                        }

                        mapControlButton(
                            systemImage: "scope",
                            accessibilityLabel: "Centralizar mapa"
                        ) {
                            centerRequest += 1
                            SanctuaryHaptics.selection()
                        }

                        mapControlButton(
                            systemImage: "plus.magnifyingglass",
                            accessibilityLabel: "Ampliar mapa"
                        ) {
                            updateZoom(by: 1.25)
                        }
                    }
                }

                Spacer()
                mapLegend
            }
            .padding(12)
        }
        .sheet(
            isPresented: Binding(
                get: { selectedUndefinedLotID != nil },
                set: { if !$0 { selectedUndefinedLotID = nil } }
            )
        ) {
            BiomeSelectionSheet { biome in
                if selectedUndefinedLotID != nil {
                    defineSelectedLot(as: biome)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(SanctuaryTheme.ink)
        }
    }

    @ViewBuilder
    private func lotView(for lot: SanctuaryMapLot) -> some View {
        if let terrain = terrain(at: lot.id) {
            SanctuaryTerrainLot(
                store: store,
                terrain: terrain,
                rotation: lot.rotation,
                open: {
                    guard !gestureGate.suppressesLotActions else { return }
                    SanctuaryHaptics.selection()
                    openTerrain(terrain)
                },
                collect: {
                    guard !gestureGate.suppressesLotActions else { return }
                    collect(terrain)
                }
            )
        } else {
            UndefinedTerrainLot(
                rotation: lot.rotation,
                chooseBiome: {
                    guard !gestureGate.suppressesLotActions else { return }
                    selectedUndefinedLotID = lot.id
                    SanctuaryHaptics.selection()
                }
            )
        }
    }

    private func terrain(at mapSlot: Int) -> Terrain? {
        store.state.terrains.first { $0.mapSlot == mapSlot }
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(maximumZoom, max(minimumZoom, value))
    }

    private func updateZoom(by factor: CGFloat) {
        withAnimation(.easeInOut(duration: 0.22)) {
            committedZoom = clampedZoom(committedZoom * factor)
        }
        SanctuaryHaptics.selection()
    }

    private func defineSelectedLot(as biome: Biome) {
        guard let mapSlot = selectedUndefinedLotID else { return }
        if case .success = store.defineTerrain(biome: biome, atMapSlot: mapSlot) {
            SanctuaryHaptics.success()
        }
    }

    private func mapControlButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.bold())
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(SanctuaryTheme.cream)
        .background(SanctuaryTheme.ink.opacity(0.86), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .accessibilityLabel(accessibilityLabel)
    }

    private var mapInstructions: some View {
        VStack {
            HStack {
                Label("Arraste • belisque", systemImage: "hand.draw.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SanctuaryTheme.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SanctuaryTheme.ink.opacity(0.84), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12)))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .accessibilityHidden(true)
                Spacer()
            }
            Spacer()
        }
        .padding(12)
        .allowsHitTesting(false)
    }

    private var mapLegend: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Biome.allCases) { biome in
                    MapLegendItem(color: biome.mapColor, title: biome.mapTitle)
                }
                MapLegendItem(color: .white, title: "A definir", hasBorder: true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .background(SanctuaryTheme.ink.opacity(0.88), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.13)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .frame(maxWidth: 520)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legenda: azul aquático, verde-água úmido, verde floresta, verde amarelado planície e branco a definir")
    }
}

struct SanctuaryMapLot: Identifiable {
    let id: Int
    let position: CGPoint
    let rotation: Angle
}

enum SanctuaryMapLayout {
    static let lotSize = CGSize(width: 224, height: 276)
    /// A rotated asset can extend beyond `lotSize`. The view needs a square
    /// large enough to contain every rotation so its organic hit shape is not
    /// clipped back to the unrotated image bounds.
    static let lotInteractionSize: CGSize = {
        let side = ceil(hypot(lotSize.width, lotSize.height))
        return CGSize(width: side, height: side)
    }()
    private static let minimumCanvasSide: CGFloat = 1_360
    private static let canvasPadding: CGFloat = 40

    /// One fitted module transcribed from the Figma reference. Figma's named
    /// rotations run in the opposite visual direction to SwiftUI for this
    /// asset, hence `-120` becomes `120` and `121` becomes `-121` here.
    private static let trioMembers = [
        TrioMember(offset: .zero, rotation: .degrees(120)),
        TrioMember(offset: CGPoint(x: -95, y: 106), rotation: .zero),
        TrioMember(offset: CGPoint(x: 45, y: 135), rotation: .degrees(-121))
    ]

    /// Neighboring trio origins form the same oblique hexagonal lattice shown
    /// in the reference. Keeping the module and its lattice separate lets the
    /// pattern expand beyond the first 21 lots without changing the fit.
    private static let trioStepQ = CGVector(dx: 292, dy: 72)
    private static let trioStepR = CGVector(dx: 85, dy: 291)

    private struct TrioMember {
        let offset: CGPoint
        let rotation: Angle
    }

    private struct RelativeLot {
        let position: CGPoint
        let rotation: Angle
    }

    private struct AxialCoordinate {
        let q: Int
        let r: Int

        var distanceFromCenter: Int {
            max(abs(q), max(abs(r), abs(q + r)))
        }

        var point: CGPoint {
            CGPoint(
                x: CGFloat(q) * trioStepQ.dx + CGFloat(r) * trioStepR.dx,
                y: CGFloat(q) * trioStepQ.dy + CGFloat(r) * trioStepR.dy
            )
        }

        var clockwiseOrder: CGFloat {
            let angle = atan2(point.y, point.x) + .pi / 2
            if abs(angle) < 0.000_001 { return 0 }
            return angle < 0 ? angle + 2 * .pi : angle
        }
    }

    static func canvasSize(for count: Int) -> CGSize {
        let relativeLots = relativeLots(count: count)
        guard let bounds = pointBounds(of: relativeLots) else {
            return CGSize(width: minimumCanvasSide, height: minimumCanvasSide)
        }

        let rotatedLotRadius = hypot(lotSize.width / 2, lotSize.height / 2)
        let requiredSide = max(
            bounds.width + 2 * (rotatedLotRadius + canvasPadding),
            bounds.height + 2 * (rotatedLotRadius + canvasPadding)
        )
        let side = max(minimumCanvasSide, ceil(requiredSide))
        return CGSize(width: side, height: side)
    }

    /// Produces fitted trios center-out, then expands their origins in an
    /// oblique hexagonal spiral matching the supplied Figma composition.
    static func lots(count: Int, canvasSize: CGSize) -> [SanctuaryMapLot] {
        let relativeLots = relativeLots(count: count)
        guard let bounds = pointBounds(of: relativeLots) else { return [] }

        let layoutCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        return relativeLots.enumerated().map { index, lot in
            SanctuaryMapLot(
                id: index,
                position: CGPoint(
                    x: canvasCenter.x + lot.position.x - layoutCenter.x,
                    y: canvasCenter.y + lot.position.y - layoutCenter.y
                ),
                rotation: lot.rotation
            )
        }
    }

    private static func relativeLots(count: Int) -> [RelativeLot] {
        guard count > 0 else { return [] }

        let trioCount = Int(ceil(Double(count) / Double(trioMembers.count)))
        let radius = ringRadius(for: trioCount)

        var coordinates: [AxialCoordinate] = []
        for q in -radius...radius {
            let lowerR = max(-radius, -q - radius)
            let upperR = min(radius, -q + radius)
            for r in lowerR...upperR {
                coordinates.append(AxialCoordinate(q: q, r: r))
            }
        }

        coordinates.sort {
            if $0.distanceFromCenter != $1.distanceFromCenter {
                return $0.distanceFromCenter < $1.distanceFromCenter
            }
            return $0.clockwiseOrder < $1.clockwiseOrder
        }

        var result: [RelativeLot] = []
        result.reserveCapacity(count)

        for coordinate in coordinates.prefix(trioCount) {
            for member in trioMembers where result.count < count {
                result.append(
                    RelativeLot(
                        position: CGPoint(
                            x: coordinate.point.x + member.offset.x,
                            y: coordinate.point.y + member.offset.y
                        ),
                        rotation: member.rotation
                    )
                )
            }
        }
        return result
    }

    private static func pointBounds(of lots: [RelativeLot]) -> CGRect? {
        guard let first = lots.first else { return nil }

        var minimumX = first.position.x
        var maximumX = first.position.x
        var minimumY = first.position.y
        var maximumY = first.position.y

        for lot in lots.dropFirst() {
            minimumX = min(minimumX, lot.position.x)
            maximumX = max(maximumX, lot.position.x)
            minimumY = min(minimumY, lot.position.y)
            maximumY = max(maximumY, lot.position.y)
        }

        return CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    private static func ringRadius(for count: Int) -> Int {
        guard count > 1 else { return 0 }
        var radius = 0
        while 1 + 3 * radius * (radius + 1) < count {
            radius += 1
        }
        return radius
    }
}

private final class SanctuaryMapUIScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        true
    }
}

/// Observes a pinch even when it starts over a SwiftUI Button, but never
/// prevents another recognizer. The native UIScrollView pinch remains solely
/// responsible for scale, focal point and content offset.
private final class SanctuaryMapPinchGestureRecognizer: UIPinchGestureRecognizer {
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}

private struct SanctuaryZoomScrollView<Content: View>: UIViewRepresentable {
    @Binding var zoomScale: CGFloat

    let centerRequest: Int
    let minimumZoomScale: CGFloat
    let maximumZoomScale: CGFloat
    let canvasSize: CGSize
    let gestureGate: SanctuaryMapGestureGate
    let content: Content

    init(
        zoomScale: Binding<CGFloat>,
        centerRequest: Int,
        minimumZoomScale: CGFloat,
        maximumZoomScale: CGFloat,
        canvasSize: CGSize,
        gestureGate: SanctuaryMapGestureGate,
        @ViewBuilder content: () -> Content
    ) {
        _zoomScale = zoomScale
        self.centerRequest = centerRequest
        self.minimumZoomScale = minimumZoomScale
        self.maximumZoomScale = maximumZoomScale
        self.canvasSize = canvasSize
        self.gestureGate = gestureGate
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale, gestureGate: gestureGate)
    }

    func makeUIView(context: Context) -> SanctuaryMapUIScrollView {
        let scrollView = SanctuaryMapUIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.zoomScale = zoomScale
        scrollView.isMultipleTouchEnabled = true
        scrollView.canCancelContentTouches = true
        scrollView.delaysContentTouches = false
        scrollView.bounces = true
        scrollView.bouncesZoom = false
        scrollView.decelerationRate = .fast
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
        var hostingController: UIHostingController<Content>?
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        weak var scrollView: SanctuaryMapUIScrollView?
        weak var mapPinchGestureRecognizer: SanctuaryMapPinchGestureRecognizer?
        var lastCenterRequest: Int?
        var isApplyingSwiftUIUpdate = false

        private var isPinchLifecycleActive = false
        private var pinchSettlementWorkItem: DispatchWorkItem?

        var isMapPinching: Bool {
            isPinchLifecycleActive
                || mapPinchGestureRecognizer?.state == .began
                || mapPinchGestureRecognizer?.state == .changed
        }

        init(zoomScale: Binding<CGFloat>, gestureGate: SanctuaryMapGestureGate) {
            self.zoomScale = zoomScale
            self.gestureGate = gestureGate
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

        /// A Button changing from pressed to released can update SwiftUI after
        /// the recognizer reaches `.ended`, but before the new zoom binding is
        /// delivered back to this representable. Until both values match, an
        /// update contains the stale pre-pinch scale and must not be applied.
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

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            updateContentInsets(in: scrollView)
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
            let offset = CGPoint(
                x: (scrollView.contentSize.width - scrollView.bounds.width) / 2,
                y: (scrollView.contentSize.height - scrollView.bounds.height) / 2
            )
            scrollView.setContentOffset(offset, animated: animated)
        }

        private func settlePinchAfterBindingUpdate() {
            pinchSettlementWorkItem?.cancel()

            // Normally updateUIView reconciles and clears the lifecycle on the
            // next render. The fallback also covers a pinch whose scale changed
            // by less than the binding tolerance and caused no render at all.
            let workItem = DispatchWorkItem { [weak self] in
                self?.isPinchLifecycleActive = false
                self?.pinchSettlementWorkItem = nil
            }
            pinchSettlementWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
        }

        private func commitCurrentZoom(from scrollView: UIScrollView) {
            let scale = scrollView.zoomScale
            guard abs(zoomScale.wrappedValue - scale) > 0.001 else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                zoomScale.wrappedValue = scale
            }
        }
    }
}

private struct SanctuaryTerrainLot: View {
    @ObservedObject var store: SanctuaryStore
    let terrain: Terrain
    let rotation: Angle
    let open: () -> Void
    let collect: () -> Void

    private var residents: [AnimalInstance] { store.residents(in: terrain.id) }
    private var species: SpeciesDefinition? { store.residentSpecies(in: terrain.id) }
    private var collectableAmount: Int { Int(floor(terrain.storedResources)) }

    var body: some View {
        ZStack {
            ZStack {
                Image(terrain.biome.mapAssetName)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(rotation)
                    .shadow(color: terrain.biome.mapColor.opacity(0.3), radius: 16, y: 9)

                lotSummary
            }
            .frame(
                width: SanctuaryMapLayout.lotSize.width,
                height: SanctuaryMapLayout.lotSize.height
            )
            .frame(
                width: SanctuaryMapLayout.lotInteractionSize.width,
                height: SanctuaryMapLayout.lotInteractionSize.height
            )
            .contentShape(TerrainInteractionShape(rotation: rotation))
            .onTapGesture(perform: open)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                open()
            }

            if terrain.isUnlocked, collectableAmount > 0 {
                Label(collectableAmount.formatted(), systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(SanctuaryTheme.ink)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 36)
                    .background(SanctuaryTheme.lime, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.5)))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    .contentShape(Capsule())
                    .onTapGesture(perform: collect)
                    .offset(x: 70, y: -76)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        collect()
                    }
                    .accessibilityLabel("Coletar \(collectableAmount) recursos do terreno \(terrain.biome.title)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var lotSummary: some View {
        VStack(spacing: 6) {
            Label(terrain.biome.mapTitle, systemImage: terrain.biome.symbolName)
                .font(.caption2.bold())
                .tracking(0.3)

            if terrain.isUnlocked {
                if let species {
                    HStack(spacing: 6) {
                        Text(species.symbol)
                            .font(.title3)
                        Text("\(residents.count)/\(store.capacity(of: terrain))")
                            .font(.caption.bold())
                    }
                } else {
                    Label("Disponível", systemImage: "plus.circle.fill")
                        .font(.caption2.weight(.semibold))
                }
            } else {
                Label("Expandir", systemImage: "lock.fill")
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.22)))
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
        .frame(maxWidth: 150)
    }
}

private struct UndefinedTerrainLot: View {
    let rotation: Angle
    let chooseBiome: () -> Void

    var body: some View {
        ZStack {
            Image("TerrainUndefined")
                .resizable()
                .scaledToFit()
                .rotationEffect(rotation)
                .opacity(0.88)
                .shadow(color: .black.opacity(0.22), radius: 12, y: 7)

            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption.bold())
                Text("ESCOLHER BIOMA")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundStyle(SanctuaryTheme.ink.opacity(0.78))
            .padding(8)
            .background(.white.opacity(0.86), in: Capsule())
            .overlay(Capsule().stroke(SanctuaryTheme.ink.opacity(0.14)))
        }
        .frame(
            width: SanctuaryMapLayout.lotSize.width,
            height: SanctuaryMapLayout.lotSize.height
        )
        .frame(
            width: SanctuaryMapLayout.lotInteractionSize.width,
            height: SanctuaryMapLayout.lotInteractionSize.height
        )
        .contentShape(TerrainInteractionShape(rotation: rotation))
        .onTapGesture(perform: chooseBiome)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Terreno sem tipo")
        .accessibilityHint("Toque para escolher o bioma deste terreno")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            chooseBiome()
        }
    }
}

/// A compact approximation of the opaque part shared by all terrain PNGs.
/// Keeping the path slightly inside the feathered edge avoids ambiguous taps
/// in the transparent corners while preserving a generous target in the lot.
private struct TerrainInteractionShape: Shape {
    let rotation: Angle

    private static let normalizedOutline = [
        CGPoint(x: 0.34, y: 0.09),
        CGPoint(x: 0.40, y: 0.08),
        CGPoint(x: 0.45, y: 0.15),
        CGPoint(x: 0.48, y: 0.31),
        CGPoint(x: 0.53, y: 0.36),
        CGPoint(x: 0.77, y: 0.40),
        CGPoint(x: 0.89, y: 0.46),
        CGPoint(x: 0.95, y: 0.56),
        CGPoint(x: 0.92, y: 0.66),
        CGPoint(x: 0.80, y: 0.75),
        CGPoint(x: 0.71, y: 0.84),
        CGPoint(x: 0.70, y: 0.95),
        CGPoint(x: 0.63, y: 0.98),
        CGPoint(x: 0.53, y: 0.95),
        CGPoint(x: 0.47, y: 0.87),
        CGPoint(x: 0.44, y: 0.73),
        CGPoint(x: 0.36, y: 0.67),
        CGPoint(x: 0.13, y: 0.59),
        CGPoint(x: 0.07, y: 0.53),
        CGPoint(x: 0.07, y: 0.43),
        CGPoint(x: 0.12, y: 0.34),
        CGPoint(x: 0.23, y: 0.24),
        CGPoint(x: 0.29, y: 0.13)
    ]

    func path(in rect: CGRect) -> Path {
        let imageRect = CGRect(
            x: rect.midX - SanctuaryMapLayout.lotSize.width / 2,
            y: rect.midY - SanctuaryMapLayout.lotSize.height / 2,
            width: SanctuaryMapLayout.lotSize.width,
            height: SanctuaryMapLayout.lotSize.height
        )
        let center = CGPoint(x: imageRect.midX, y: imageRect.midY)
        let radians = CGFloat(rotation.radians)
        let cosine = cos(radians)
        let sine = sin(radians)

        func point(for normalizedPoint: CGPoint) -> CGPoint {
            let point = CGPoint(
                x: imageRect.minX + normalizedPoint.x * imageRect.width,
                y: imageRect.minY + normalizedPoint.y * imageRect.height
            )
            let deltaX = point.x - center.x
            let deltaY = point.y - center.y
            return CGPoint(
                x: center.x + deltaX * cosine - deltaY * sine,
                y: center.y + deltaX * sine + deltaY * cosine
            )
        }

        var path = Path()
        guard let firstPoint = Self.normalizedOutline.first else { return path }
        path.move(to: point(for: firstPoint))
        for outlinePoint in Self.normalizedOutline.dropFirst() {
            path.addLine(to: point(for: outlinePoint))
        }
        path.closeSubpath()
        return path
    }
}

private struct MapLegendItem: View {
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

private struct SanctuaryMapBackdrop: View {
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

private extension Biome {
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

#Preview("Mapa do santuário") {
    SanctuaryMapView(
        store: SanctuaryStore(persistence: PreviewSanctuaryPersistence()),
        openTerrain: { _ in },
        collect: { _ in }
    )
    .frame(height: 760)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .padding()
    .background(SanctuaryTheme.ink)
}

private final class PreviewSanctuaryPersistence: SanctuaryPersisting {
    func load() -> SanctuaryState? { nil }
    func save(_ state: SanctuaryState) {}
    func clear() {}
}
