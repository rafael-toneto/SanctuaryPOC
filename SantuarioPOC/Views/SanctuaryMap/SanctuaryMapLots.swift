import SwiftUI

/// A compact approximation of the opaque part shared by all terrain PNGs.
/// Keeping the path slightly inside the feathered edge avoids ambiguous taps
/// in the transparent corners while preserving a generous target in the lot.
struct TerrainInteractionShape: Shape {
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

struct SanctuaryTerrainLot: View {
    @ObservedObject var store: SanctuaryStore
    let terrain: Terrain
    let rotation: Angle
    let open: () -> Void
    let collect: () -> Void

    private var residents: [AnimalInstance] { store.residents(in: terrain.id) }
    private var species: SpeciesDefinition? { store.residentSpecies(in: terrain.id) }
    private var collectableAmount: Int { Int(floor(terrain.storedResources)) }
    
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

    var body: some View {
        ZStack {
            ZStack {
                Image(terrain.biome.mapAssetName)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(rotation)
                    .shadow(color: terrain.biome.mapColor.opacity(0.3), radius: 16, y: 9)

                if terrain.isUnlocked, let species = species {
                    let slots = animalSlots(for: rotation)
                    ForEach(Array(residents.prefix(4).enumerated()), id: \.element.id) { index, resident in
                        let slot = slots[index % slots.count]
                        WanderingAnimalView(
                            animal: species.spriteName,
                            center: slot.position,
                            isFacingLeft: slot.isFacingLeft
                        )
                    }
                }
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
        }
        .accessibilityElement(children: .contain)
    }
}

struct ForestDecorationsLot: View {
    let rotation: Angle
    
    private func rotatedPoint(x: CGFloat, y: CGFloat) -> CGPoint {
        let radians = CGFloat(rotation.radians)
        let cosine = cos(radians)
        let sine = sin(radians)
        
        return CGPoint(
            x: x * cosine - y * sine,
            y: x * sine + y * cosine
        )
    }

    var body: some View {
        ZStack {
            let topOak = rotatedPoint(x: -35, y: -70)
            let rightPine = rotatedPoint(x: 75, y: 20)
            let bottomOak = rotatedPoint(x: 25, y: 110)
            
            Image("oak-tree")
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 55)
                .shadow(color: .black.opacity(0.4), radius: 5, x: 4, y: -5)
                .offset(x: topOak.x, y: topOak.y - 20)
                
            Image("pine-tree")
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 55)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .offset(x: rightPine.x, y: rightPine.y - 15)
                
            Image("oak-tree")
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .offset(x: bottomOak.x, y: bottomOak.y - 15)
        }
        .allowsHitTesting(false)
    }
}

struct TerrainBadgeLot: View {
    let terrain: Terrain
    let rotation: Angle
    let collect: () -> Void
    let showBadges: Bool
    let residentCount: Int

    private var collectableAmount: Int { Int(floor(terrain.storedResources)) }

    private func rotatedPoint(x: CGFloat, y: CGFloat) -> CGPoint {
        let radians = CGFloat(rotation.radians)
        let cosine = cos(radians)
        let sine = sin(radians)
        return CGPoint(x: x * cosine - y * sine, y: x * sine + y * cosine)
    }

    private var badgeOffset: CGSize {
        let pt = rotatedPoint(x: 0, y: -75)
        return CGSize(width: pt.x, height: pt.y)
    }

    var body: some View {
        ZStack {
            if showBadges && terrain.isUnlocked {
                HStack(spacing: 4) {
                    if collectableAmount > 0 {
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
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction {
                                collect()
                            }
                            .accessibilityLabel("Coletar \(collectableAmount) recursos do terreno \(terrain.biome.title)")
                    }
                    
                    if residentCount > 4 {
                        Label("\(residentCount)", systemImage: "pawprint.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(minHeight: 36)
                            .background(SanctuaryTheme.ink.opacity(0.8), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.3)))
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                            .accessibilityLabel("\(residentCount) animais no terreno \(terrain.biome.title)")
                    }
                }
                .offset(badgeOffset)
            }
        }
    }
}

struct UndefinedTerrainBase: View {
    let rotation: Angle

    var body: some View {
        Image("TerrainUndefined")
            .resizable()
            .scaledToFit()
            .rotationEffect(rotation)
            .opacity(0.88)
            .shadow(color: .black.opacity(0.22), radius: 12, y: 7)
            .frame(
                width: SanctuaryMapLayout.lotSize.width,
                height: SanctuaryMapLayout.lotSize.height
            )
            .frame(
                width: SanctuaryMapLayout.lotInteractionSize.width,
                height: SanctuaryMapLayout.lotInteractionSize.height
            )
            .allowsHitTesting(false)
    }
}

struct UndefinedTerrainButton: View {
    let rotation: Angle
    let chooseBiome: () -> Void

    var body: some View {
        Circle()
            .fill(SanctuaryTheme.ink.opacity(0.82))
            .frame(width: 40, height: 40)
            .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1.5))
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
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
            .accessibilityLabel("Terreno disponível para compra")
            .accessibilityHint("Toque para escolher o bioma deste terreno")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                chooseBiome()
            }
    }
}

struct AnimalSpriteView: View {
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

struct AnimalSlot {
    let position: CGPoint
    let isFacingLeft: Bool
}

struct WanderingAnimalView: View {
    let animal: String
    let center: CGPoint
    let isFacingLeft: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            
            AnimalSpriteView(animal: animal, t: t)
                .frame(width: 48, height: 48)
                .scaleEffect(x: isFacingLeft ? -1 : 1, y: 1)
                .offset(x: center.x, y: center.y - 10)
        }
    }
}
