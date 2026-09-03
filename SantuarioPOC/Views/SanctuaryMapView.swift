import SwiftUI
import UIKit

struct SanctuaryMapView: View {
    @ObservedObject var store: SanctuaryStore
    let openTerrain: (Terrain) -> Void
    let collect: (Terrain) -> Void

    private let minimumZoom: CGFloat = 0.55
    private let maximumZoom: CGFloat = 2.25

    @State private var selectedUndefinedLotID: Int?
    @State private var committedZoom: CGFloat = 1
    @State private var centerRequest = 0

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
                canvasSize: canvasSize
            ) {
                ZStack(alignment: .topLeading) {
                    SanctuaryMapBackdrop()

                    ForEach(lots) { lot in
                        lotView(for: lot)
                            .frame(
                                width: SanctuaryMapLayout.lotSize.width,
                                height: SanctuaryMapLayout.lotSize.height
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
        .confirmationDialog(
            "Definir tipo de terreno",
            isPresented: Binding(
                get: { selectedUndefinedLotID != nil },
                set: { if !$0 { selectedUndefinedLotID = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(Biome.allCases) { biome in
                Button(biome.mapTitle) {
                    defineSelectedLot(as: biome)
                }
            }
            Button("Cancelar", role: .cancel) {
                selectedUndefinedLotID = nil
            }
        } message: {
            Text("Escolha o bioma. O novo terreno ficará disponível imediatamente.")
        }
    }

    @ViewBuilder
    private func lotView(for lot: SanctuaryMapLot) -> some View {
        if let terrain = terrain(at: lot.id) {
            SanctuaryTerrainLot(
                store: store,
                terrain: terrain,
                rotation: lot.rotation,
                open: { openTerrain(terrain) },
                collect: { collect(terrain) }
            )
        } else {
            UndefinedTerrainLot(
                rotation: lot.rotation,
                chooseBiome: {
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
        selectedUndefinedLotID = nil
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

private struct SanctuaryZoomScrollView<Content: View>: UIViewRepresentable {
    @Binding var zoomScale: CGFloat

    let centerRequest: Int
    let minimumZoomScale: CGFloat
    let maximumZoomScale: CGFloat
    let canvasSize: CGSize
    let content: Content

    init(
        zoomScale: Binding<CGFloat>,
        centerRequest: Int,
        minimumZoomScale: CGFloat,
        maximumZoomScale: CGFloat,
        canvasSize: CGSize,
        @ViewBuilder content: () -> Content
    ) {
        _zoomScale = zoomScale
        self.centerRequest = centerRequest
        self.minimumZoomScale = minimumZoomScale
        self.maximumZoomScale = maximumZoomScale
        self.canvasSize = canvasSize
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale)
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
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.pinchGestureRecognizer?.cancelsTouchesInView = true

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
        return scrollView
    }

    func updateUIView(_ scrollView: SanctuaryMapUIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.zoomScale = $zoomScale
        coordinator.hostingController?.rootView = content
        coordinator.widthConstraint?.constant = canvasSize.width
        coordinator.heightConstraint?.constant = canvasSize.height

        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale

        let requestedZoom = min(maximumZoomScale, max(minimumZoomScale, zoomScale))
        if !scrollView.isZooming,
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
        scrollView.delegate = nil
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var zoomScale: Binding<CGFloat>
        var hostingController: UIHostingController<Content>?
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        var lastCenterRequest: Int?
        var isApplyingSwiftUIUpdate = false

        init(zoomScale: Binding<CGFloat>) {
            self.zoomScale = zoomScale
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
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
            if abs(zoomScale.wrappedValue - scale) > 0.001 {
                zoomScale.wrappedValue = scale
            }
        }

        func updateContentInsets(in scrollView: UIScrollView) {
            let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
            let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        func centerContent(in scrollView: UIScrollView, animated: Bool) {
            let offset = CGPoint(
                x: (scrollView.contentSize.width - scrollView.bounds.width) / 2,
                y: (scrollView.contentSize.height - scrollView.bounds.height) / 2
            )
            scrollView.setContentOffset(offset, animated: animated)
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
            Button(action: open) {
                ZStack {
                    Image(terrain.biome.mapAssetName)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(rotation)
                        .shadow(color: terrain.biome.mapColor.opacity(0.3), radius: 16, y: 9)

                    if terrain.isUnlocked, let species = species {
                        ForEach(residents) { resident in
                            WanderingAnimalView(animal: species.spriteName)
                        }
                    }
                }
            }
            .buttonStyle(MapLotButtonStyle())

            if terrain.isUnlocked, collectableAmount > 0 {
                Button(action: collect) {
                    Label(collectableAmount.formatted(), systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(SanctuaryTheme.ink)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 36)
                        .background(SanctuaryTheme.lime, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.5)))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .offset(x: 70, y: -76)
                .accessibilityLabel("Coletar (collectableAmount) recursos do terreno (terrain.biome.title)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct UndefinedTerrainLot: View {
    let rotation: Angle
    let chooseBiome: () -> Void

    var body: some View {
        Button(action: chooseBiome) {
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
        }
        .buttonStyle(MapLotButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Terreno sem tipo")
        .accessibilityHint("Toque para escolher o bioma deste terreno")
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

private struct MapLotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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

    var mapTitle: String {
        switch self {
        case .grassland: "Planície"
        default: title
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

private struct AnimalSpriteView: View {
    let animal: String
    let t: TimeInterval

    var body: some View {
        let frameCount = animal == "fox" ? 4 : 6
        let action = animal == "fox" ? "idle" : "walking"
        let currentFrame = (Int(t * 6.0) % frameCount) + 1
        
        Image("\(animal)-\(action)-\(currentFrame)")
            .resizable()
            .scaledToFit()
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
    }
}

private extension SpeciesDefinition {
    var spriteName: String {
        switch self.id {
        case "peixe-boi-demo", "jacare-demo":
            return "octopus"
        default:
            return "fox"
        }
    }
}

private struct WanderingAnimalView: View {
    let animal: String

    let centerX = CGFloat.random(in: -30...30)
    let centerY = CGFloat.random(in: -20...20)
    let isFacingLeft = Bool.random()

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            
            AnimalSpriteView(animal: animal, t: t)
                .frame(width: 48, height: 48)
                .scaleEffect(x: isFacingLeft ? -1 : 1, y: 1)
                .offset(x: centerX, y: centerY - 10)
        }
    }
}
