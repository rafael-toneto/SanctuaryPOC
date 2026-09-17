import SpriteKit
import SwiftUI

/// Cena SpriteKit do Mapa do Santuário, acelerada por Metal GPU.
/// Fornece pan e zoom suaves, gestão de camadas (Z), animações de animais
/// com SKActions nativas e contenção física da câmera no esqueleto do santuário.
final class SanctuaryMapScene: SKScene {
    // MARK: - Callbacks de Interação
    var onSelectUndefinedLot: ((Int) -> Void)?
    var onOpenTerrain: ((Terrain) -> Void)?
    var onCollectTerrain: ((Terrain) -> Void)?

    // MARK: - Nós de Camada e Câmera
    let cameraNode = SKCameraNode()
    private let worldNode = SKNode()
    private let backdropLayer = SKNode()
    private let undefinedLotsLayer = SKNode()
    private let cloudsLayer = SKNode()
    private let ownedLotsLayer = SKNode()
    private let decorationsLayer = SKNode()
    private let animalsLayer = SKNode()
    private let buttonsLayer = SKNode()

    // MARK: - Parâmetros de Câmera e Restrições
    var minimumScale: CGFloat = 0.45
    var maximumScale: CGFloat = 1.85
    private(set) var currentScale: CGFloat = 1.0

    private var activeRectLimit: CGRect = .zero
    private var canvasSize: CGSize = CGSize(width: 1360, height: 1360)
    private var terrainsByLotID: [Int: Terrain] = [:]
    private var cloudNodesByLotID: [Int: SKSpriteNode] = [:]
    private var terrainMasksByLotID: [Int: AlphaMask] = [:]
    private var renderedMapKey: Int?
    private var spriteKitFrameTimestamp: TimeInterval = 0

    // Texturas em cache para evitar recarregamento
    private static var texturesCached = false
    private static var foxIdleTextures: [SKTexture] = []
    private static var octopusWalkTextures: [SKTexture] = []
    private static var alphaMasks: [String: AlphaMask] = [:]

    // Controle de Gestos
    private var isDragging = false
    private var lastPanTranslation: CGPoint = .zero

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.05, green: 0.12, blue: 0.09, alpha: 1.0)
        scaleMode = .resizeFill

        // Configuração de renderização de alto desempenho
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true

        if camera == nil {
            addChild(worldNode)
            worldNode.addChild(backdropLayer)
            worldNode.addChild(undefinedLotsLayer)
            worldNode.addChild(cloudsLayer)
            worldNode.addChild(ownedLotsLayer)
            worldNode.addChild(decorationsLayer)
            worldNode.addChild(animalsLayer)
            worldNode.addChild(buttonsLayer)

            addChild(cameraNode)
            camera = cameraNode
            cameraNode.position = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        }

        Self.preloadTexturesIfNeeded()
    }

    private static func preloadTexturesIfNeeded() {
        guard !texturesCached else { return }
        texturesCached = true
        foxIdleTextures = (1...4).map { SKTexture(imageNamed: "fox-idle-\($0)") }
        octopusWalkTextures = (1...6).map { SKTexture(imageNamed: "octopus-walking-\($0)") }
    }

    private static func alphaMask(named imageName: String) -> AlphaMask? {
        if let cached = alphaMasks[imageName] { return cached }
        let texture = SKTexture(imageNamed: imageName)
        let image = texture.cgImage()

        let width = 64
        let height = 64
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }

            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        let mask = AlphaMask(
            width: width,
            height: height,
            alpha: stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
        )
        alphaMasks[imageName] = mask
        return mask
    }

    private var hasCenteredInitially = false

    override func update(_ currentTime: TimeInterval) {
        spriteKitFrameTimestamp = currentTime
    }

    override func didFinishUpdate() {
        FPSCounter.shared.recordSpriteKitFrame(at: spriteKitFrameTimestamp)
    }

    // MARK: - Sincronização com ViewModel
    func sync(viewModel: SanctuaryMapViewModel, store: SanctuaryStore) {
        let mapKey = viewModel.mapRenderKey
        guard renderedMapKey != mapKey else {
            clampCameraPosition()
            return
        }

        let shouldAnimateCloudTransition = renderedMapKey != nil
        renderedMapKey = mapKey
        self.canvasSize = viewModel.canvasSize
        self.activeRectLimit = viewModel.sanctuaryActiveRect

        rebuildBackdrop()
        rebuildUndefinedLots(viewModel: viewModel)
        rebuildClouds(viewModel: viewModel, animated: shouldAnimateCloudTransition)
        rebuildOwnedLots(viewModel: viewModel, store: store)
        rebuildDecorations(viewModel: viewModel)
        rebuildButtons(viewModel: viewModel)

        if !hasCenteredInitially && activeRectLimit.width > 0 {
            hasCenteredInitially = true
            centerOnSanctuary(animated: false)
        } else {
            clampCameraPosition()
        }
    }

    // MARK: - Reconstrução do Fundo
    private func rebuildBackdrop() {
        backdropLayer.removeAllChildren()

        let bg = SKSpriteNode(color: UIColor(red: 0.045, green: 0.11, blue: 0.08, alpha: 1.0), size: canvasSize)
        bg.position = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        bg.zPosition = 0
        backdropLayer.addChild(bg)

        // Grid sutil
        let gridPath = CGMutablePath()
        let spacing: CGFloat = 90
        stride(from: CGFloat.zero, through: canvasSize.width, by: spacing).forEach { x in
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: canvasSize.height))
        }
        stride(from: CGFloat.zero, through: canvasSize.height, by: spacing).forEach { y in
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: canvasSize.width, y: y))
        }

        let gridNode = SKShapeNode(path: gridPath)
        gridNode.strokeColor = UIColor.white.withAlphaComponent(0.026)
        gridNode.lineWidth = 1
        gridNode.zPosition = 1
        backdropLayer.addChild(gridNode)
    }

    // MARK: - Reconstrução de Terrenos Indefinidos
    private func rebuildUndefinedLots(viewModel: SanctuaryMapViewModel) {
        undefinedLotsLayer.removeAllChildren()

        for lot in viewModel.displayableLots {
            if viewModel.terrain(at: lot.id) == nil {
                let sprite = SKSpriteNode(imageNamed: "TerrainUndefined")
                sprite.size = CGSize(width: 224, height: 276)
                // Converte posição SwiftUI (topo esquerdo) para SpriteKit (base esquerda invertida em Y)
                sprite.position = CGPoint(x: lot.position.x, y: canvasSize.height - lot.position.y)
                sprite.zRotation = -CGFloat(lot.rotation.radians)
                sprite.alpha = 0.88
                sprite.zPosition = 100
                // O lote inteiro é acionável; o botão + permanece apenas como indicação.
                sprite.name = "buy_lot_\(lot.id)"
                undefinedLotsLayer.addChild(sprite)
            }
        }
    }

    // MARK: - Reconstrução de Nuvens
    private func rebuildClouds(viewModel: SanctuaryMapViewModel, animated: Bool) {
        let targetLots = Dictionary(uniqueKeysWithValues: viewModel.cloudPuffs.map { ($0.id, $0) })
        let targetIDs = Set(targetLots.keys)
        let activeCenter = CGPoint(
            x: activeRectLimit.midX,
            y: canvasSize.height - activeRectLimit.midY
        )

        // Nuvens reveladas por uma compra recuam antes de desaparecer.
        let removedCloudIDs = cloudNodesByLotID.keys.filter { !targetIDs.contains($0) }
        for id in removedCloudIDs {
            guard let cloud = cloudNodesByLotID.removeValue(forKey: id) else { continue }
            cloud.removeAction(forKey: "cloud.transition")

            let dx = cloud.position.x - activeCenter.x
            let dy = cloud.position.y - activeCenter.y
            let length = max(1, hypot(dx, dy))
            let retreat = CGVector(dx: dx / length * 70, dy: dy / length * 70)
            let retreatAction = SKAction.moveBy(x: retreat.dx, y: retreat.dy, duration: 0.42)
            retreatAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: 0.42)
            cloud.run(
                SKAction.sequence([SKAction.group([retreatAction, fadeAction]), .removeFromParent()]),
                withKey: "cloud.transition"
            )
        }

        for lot in targetLots.values {
            let targetPosition = CGPoint(x: lot.position.x, y: canvasSize.height - lot.position.y)
            if let cloud = cloudNodesByLotID[lot.id] {
                cloud.zPosition = 1500
                cloud.removeAction(forKey: "cloud.transition")
                guard animated else {
                    cloud.position = targetPosition
                    cloud.alpha = 0.75
                    continue
                }

                let moveAction = SKAction.move(to: targetPosition, duration: 0.55)
                moveAction.timingMode = .easeOut
                cloud.run(moveAction, withKey: "cloud.transition")
            } else {
                let cloud = SKSpriteNode(imageNamed: "clouds-background")
                cloud.size = CGSize(width: 420, height: 420)
                cloud.position = targetPosition
                cloud.alpha = animated ? 0 : 0.75
                cloud.zPosition = 1500
                cloudsLayer.addChild(cloud)
                cloudNodesByLotID[lot.id] = cloud

                if animated {
                    let appearAction = SKAction.fadeAlpha(to: 0.75, duration: 0.38)
                    appearAction.timingMode = .easeOut
                    cloud.run(appearAction, withKey: "cloud.transition")
                }
            }
        }
    }

    // MARK: - Reconstrução de Terrenos Comprados e Animais
    private func rebuildOwnedLots(viewModel: SanctuaryMapViewModel, store: SanctuaryStore) {
        ownedLotsLayer.removeAllChildren()
        animalsLayer.removeAllChildren()
        terrainsByLotID.removeAll()
        terrainMasksByLotID.removeAll()

        for lot in viewModel.displayableLots {
            guard let terrain = viewModel.terrain(at: lot.id) else { continue }
            terrainsByLotID[lot.id] = terrain

            let lotNode = SKSpriteNode(imageNamed: terrain.biome.mapAssetName)
            lotNode.size = CGSize(width: 224, height: 276)
            let skPos = CGPoint(x: lot.position.x, y: canvasSize.height - lot.position.y)
            lotNode.position = skPos
            lotNode.zRotation = -CGFloat(lot.rotation.radians)
            lotNode.zPosition = 1000 + (canvasSize.height - lot.position.y) / 10
            lotNode.name = "owned_terrain_\(lot.id)"
            if let mask = Self.alphaMask(named: terrain.biome.mapAssetName) {
                terrainMasksByLotID[lot.id] = mask
            }
            ownedLotsLayer.addChild(lotNode)

            // Animais do terreno
            if terrain.isUnlocked, let species = viewModel.residentSpecies(in: terrain.id) {
                let residents = viewModel.residents(in: terrain.id)
                let slots = animalSlots(for: lot.rotation)
                let activeResidents = Array(residents.prefix(4).enumerated())
                let terrainMask = terrainMasksByLotID[lot.id]

                for (idx, _) in activeResidents {
                    let proposedSlot = slots[idx % slots.count]
                    // Animal sprites must stay inside the same opaque terrain
                    // area used by the terrain hit-test. The source PNGs have
                    // irregular silhouettes, so a rectangular slot can land
                    // in the transparent corners between neighboring lots.
                    guard let slot = terrainMask.flatMap({ fitAnimalSlot(proposedSlot, in: $0) }) else {
                        continue
                    }
                    let animNode = makeAnimalNode(species: species, slot: slot, basePos: skPos, rotation: lot.rotation)
                    animalsLayer.addChild(animNode)
                }
            }
        }
    }

    private func makeAnimalNode(species: SpeciesDefinition, slot: AnimalSlot, basePos: CGPoint, rotation: Angle) -> SKNode {
        let container = SKNode()
        let rad = -CGFloat(rotation.radians)
        let cosR = cos(rad)
        let sinR = sin(rad)
        let rotX = slot.position.x * cosR - (-slot.position.y) * sinR
        let rotY = slot.position.x * sinR + (-slot.position.y) * cosR

        container.position = CGPoint(x: basePos.x + rotX, y: basePos.y + rotY + 10)
        container.zPosition = 3000

        let isOctopus = species.id == "peixe-boi-demo" || species.id == "jacare-demo"
        let textures = isOctopus ? Self.octopusWalkTextures : Self.foxIdleTextures
        let sprite = SKSpriteNode(texture: textures.first)
        sprite.size = CGSize(width: 48, height: 48)
        sprite.xScale = slot.isFacingLeft ? -1.0 : 1.0

        if !textures.isEmpty {
            let animAction = SKAction.animate(with: textures, timePerFrame: 1.0 / 6.0)
            sprite.run(SKAction.repeatForever(animAction))
        }

        container.addChild(sprite)
        return container
    }

    private func fitAnimalSlot(_ slot: AnimalSlot, in mask: AlphaMask) -> AnimalSlot? {
        let terrainSize = CGSize(width: 224, height: 276)
        let target = CGPoint(x: slot.position.x, y: -slot.position.y)

        if mask.containsFootprint(center: target, radius: 18, in: terrainSize) {
            return slot
        }

        // Keep the authored layout whenever possible, otherwise find the
        // nearest opaque patch. This runs only when lots are rebuilt, not per
        // frame, so the alpha check does not affect camera performance.
        var best: CGPoint?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for dx in stride(from: -64, through: 64, by: 8) {
            for dy in stride(from: -64, through: 64, by: 8) {
                let candidate = CGPoint(x: target.x + CGFloat(dx), y: target.y + CGFloat(dy))
                guard mask.containsFootprint(center: candidate, radius: 18, in: terrainSize) else { continue }
                let distance = hypot(candidate.x - target.x, candidate.y - target.y)
                if distance < bestDistance {
                    bestDistance = distance
                    best = candidate
                }
            }
        }

        guard let best else { return nil }
        return AnimalSlot(position: CGPoint(x: best.x, y: -best.y), isFacingLeft: slot.isFacingLeft)
    }

    private func animalSlots(for rotation: Angle) -> [AnimalSlot] {
        let degrees = Int(round(rotation.degrees))
        switch degrees {
        case 120:
            return [
                AnimalSlot(position: CGPoint(x: -40, y: 40), isFacingLeft: true),
                AnimalSlot(position: CGPoint(x: 45, y: -40), isFacingLeft: true),
                AnimalSlot(position: CGPoint(x: -70, y: -10), isFacingLeft: false),
                AnimalSlot(position: CGPoint(x: 20, y: 05), isFacingLeft: false),
            ]
        case -121, -120:
            return [
                AnimalSlot(position: CGPoint(x: 0, y: -25), isFacingLeft: false),
                AnimalSlot(position: CGPoint(x: 10, y: 30), isFacingLeft: true),
                AnimalSlot(position: CGPoint(x: 50, y: -55), isFacingLeft: true),
                AnimalSlot(position: CGPoint(x: -20, y: 70), isFacingLeft: false),
            ]
        default:
            return [
                AnimalSlot(position: CGPoint(x: -50, y: -35), isFacingLeft: false),
                AnimalSlot(position: CGPoint(x: -30, y: 0), isFacingLeft: false),
                AnimalSlot(position: CGPoint(x: 35, y: 25), isFacingLeft: true),
                AnimalSlot(position: CGPoint(x: 25, y: 65), isFacingLeft: true),
            ]
        }
    }

    // MARK: - Decorações de Floresta
    private func rebuildDecorations(viewModel: SanctuaryMapViewModel) {
        decorationsLayer.removeAllChildren()

        for lot in viewModel.displayableLots {
            guard let terrain = viewModel.terrain(at: lot.id), terrain.biome == .forest else { continue }

            let basePos = CGPoint(x: lot.position.x, y: canvasSize.height - lot.position.y)
            let rad = -CGFloat(lot.rotation.radians)
            let cosR = cos(rad)
            let sinR = sin(rad)

            func offsetPos(x: CGFloat, y: CGFloat) -> CGPoint {
                let rx = x * cosR - (-y) * sinR
                let ry = x * sinR + (-y) * cosR
                return CGPoint(x: basePos.x + rx, y: basePos.y + ry)
            }

            let tree1 = SKSpriteNode(imageNamed: "oak-tree")
            tree1.size = CGSize(width: 55, height: 55)
            tree1.position = offsetPos(x: -35, y: -70)
            tree1.zPosition = 2500
            decorationsLayer.addChild(tree1)

            let tree2 = SKSpriteNode(imageNamed: "pine-tree")
            tree2.size = CGSize(width: 55, height: 55)
            tree2.position = offsetPos(x: 75, y: 20)
            tree2.zPosition = 2501
            decorationsLayer.addChild(tree2)

            let tree3 = SKSpriteNode(imageNamed: "oak-tree")
            tree3.size = CGSize(width: 45, height: 45)
            tree3.position = offsetPos(x: 25, y: 110)
            tree3.zPosition = 2502
            decorationsLayer.addChild(tree3)
        }
    }

    // MARK: - Botões de Compra (+)
    private func rebuildButtons(viewModel: SanctuaryMapViewModel) {
        buttonsLayer.removeAllChildren()

        for lot in viewModel.displayableLots {
            if viewModel.terrain(at: lot.id) == nil {
                let btn = SKShapeNode(circleOfRadius: 20)
                btn.fillColor = UIColor(SanctuaryTheme.ink).withAlphaComponent(0.85)
                btn.strokeColor = UIColor.white.withAlphaComponent(0.4)
                btn.lineWidth = 1.5
                btn.position = CGPoint(x: lot.position.x, y: canvasSize.height - lot.position.y)
                btn.zPosition = 4000
                btn.name = "buy_lot_\(lot.id)"

                let label = SKLabelNode(text: "+")
                label.fontName = "HelveticaNeue-Bold"
                label.fontSize = 20
                label.fontColor = .white
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.name = "buy_lot_\(lot.id)"
                btn.addChild(label)

                buttonsLayer.addChild(btn)
            }
        }
    }

    // MARK: - Restrição da Câmera (Bounding Box Externa)
    func clampCameraPosition() {
        guard let view = self.view, view.bounds.width > 0, view.bounds.height > 0 else { return }

        // Converte o centro da câmera em coordenadas UIKit/SwiftUI (onde Y desce)
        let swiftUICenter = CGPoint(x: cameraNode.position.x, y: canvasSize.height - cameraNode.position.y)

        var clampedX = swiftUICenter.x
        var clampedY = swiftUICenter.y

        // Bloqueio estrito da área total (não deixa vazar fora da tela).
        let viewportW = view.bounds.width * currentScale
        let viewportH = view.bounds.height * currentScale

        let halfVW = viewportW / 2
        let halfVH = viewportH / 2

        if activeRectLimit.width >= viewportW {
            clampedX = min(max(clampedX, activeRectLimit.minX + halfVW), activeRectLimit.maxX - halfVW)
        } else {
            clampedX = activeRectLimit.midX
        }

        if activeRectLimit.height >= viewportH {
            clampedY = min(max(clampedY, activeRectLimit.minY + halfVH), activeRectLimit.maxY - halfVH)
        } else {
            clampedY = activeRectLimit.midY
        }

        cameraNode.position = CGPoint(x: clampedX, y: canvasSize.height - clampedY)
    }

    // MARK: - Controle de Zoom e Centralização
    func zoomIn() {
        setCameraScale(currentScale * 0.82, animated: true)
    }

    func zoomOut() {
        setCameraScale(currentScale * 1.22, animated: true)
    }

    func centerOnSanctuary(animated: Bool = true) {
        let targetSKPos = CGPoint(x: activeRectLimit.midX, y: canvasSize.height - activeRectLimit.midY)
        if animated {
            let move = SKAction.move(to: targetSKPos, duration: 0.35)
            move.timingMode = .easeOut
            let completion = SKAction.run { [weak self] in
                self?.clampCameraPosition()
            }
            cameraNode.run(SKAction.sequence([move, completion]), withKey: "camera.position")
        } else {
            cameraNode.position = targetSKPos
            clampCameraPosition()
        }
    }

    func setCameraScale(_ scale: CGFloat, animated: Bool = false) {
        let clampedScale = min(maximumScale, max(minimumScale, scale))
        currentScale = clampedScale
        if animated {
            let scaleAction = SKAction.scale(to: clampedScale, duration: 0.25)
            scaleAction.timingMode = .easeOut
            let completion = SKAction.run { [weak self] in
                self?.clampCameraPosition()
            }
            cameraNode.run(SKAction.sequence([scaleAction, completion]), withKey: "camera.scale")
        } else {
            cameraNode.setScale(clampedScale)
            clampCameraPosition()
        }
    }

    // MARK: - Toques e Gestos
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        // Os botões de compra continuam usando o hit-test geométrico normal.
        for node in touchedNodes {
            if let name = node.name {
                if name.hasPrefix("buy_lot_") {
                    let idStr = name.replacingOccurrences(of: "buy_lot_", with: "")
                    if let lotID = Int(idStr) {
                        onSelectUndefinedLot?(lotID)
                        return
                    }
                }
            }
        }

        // Os terrenos são testados pela máscara alpha, sem corpos físicos.
        let terrainNodes = ownedLotsLayer.children
            .compactMap { $0 as? SKSpriteNode }
            .filter { $0.name?.hasPrefix("owned_terrain_") == true }
            .sorted { $0.zPosition > $1.zPosition }

        for node in terrainNodes {
            guard let name = node.name,
                  let lotID = Int(name.replacingOccurrences(of: "owned_terrain_", with: "")),
                  let mask = terrainMasksByLotID[lotID] else { continue }

            let localPoint = node.convert(location, from: self)
            guard mask.contains(localPoint, in: node.size) else { continue }
            if let terrain = terrainsByLotID[lotID] {
                onOpenTerrain?(terrain)
            }
            return
        }
    }

    // Processamento de Pan (Arrasto)
    func handlePan(translation: CGPoint, state: UIGestureRecognizer.State) {
        switch state {
        case .began:
            // Evita disputa entre a animação de centralização/zoom e o gesto direto.
            cameraNode.removeAction(forKey: "camera.position")
            cameraNode.removeAction(forKey: "camera.scale")
            lastPanTranslation = .zero
        case .changed:
            let dx = translation.x - lastPanTranslation.x
            let dy = translation.y - lastPanTranslation.y
            lastPanTranslation = translation

            // No SpriteKit, arrastar a tela para a direita move a câmera para a esquerda
            cameraNode.position = CGPoint(
                x: cameraNode.position.x - dx * currentScale,
                y: cameraNode.position.y + dy * currentScale
            )
            clampCameraPosition()
        case .ended, .cancelled:
            lastPanTranslation = .zero
            clampCameraPosition()
        default:
            break
        }
    }

    // Processamento de Pinch (Pinça)
    func handlePinch(scale: CGFloat, state: UIGestureRecognizer.State) {
        switch state {
        case .began, .changed:
            let newScale = currentScale / scale
            setCameraScale(newScale, animated: false)
        case .ended, .cancelled:
            clampCameraPosition()
        default:
            break
        }
    }
}

private struct AlphaMask {
    let width: Int
    let height: Int
    let alpha: [UInt8]

    func contains(_ point: CGPoint, in size: CGSize) -> Bool {
        guard size.width > 0, size.height > 0,
              abs(point.x) <= size.width / 2,
              abs(point.y) <= size.height / 2 else { return false }

        let u = point.x / size.width + 0.5
        let v = point.y / size.height + 0.5
        let x = min(width - 1, max(0, Int(u * CGFloat(width))))
        let y = min(height - 1, max(0, Int((1 - v) * CGFloat(height))))
        return alpha[y * width + x] > 20
    }

    func containsFootprint(center: CGPoint, radius: CGFloat, in size: CGSize) -> Bool {
        let diagonal = radius * 0.7
        let samples = [
            CGPoint.zero,
            CGPoint(x: radius, y: 0), CGPoint(x: -radius, y: 0),
            CGPoint(x: 0, y: radius), CGPoint(x: 0, y: -radius),
            CGPoint(x: diagonal, y: diagonal), CGPoint(x: -diagonal, y: diagonal),
            CGPoint(x: diagonal, y: -diagonal), CGPoint(x: -diagonal, y: -diagonal)
        ]
        return samples.allSatisfy { contains(CGPoint(x: center.x + $0.x, y: center.y + $0.y), in: size) }
    }
}

struct AnimalSlot {
    let position: CGPoint
    let isFacingLeft: Bool
}

extension SpeciesDefinition {
    var spriteName: String {
        switch self.id {
        case "peixe-boi-demo", "jacare-demo":
            return "octopus"
        default:
            return "fox"
        }
    }
}
