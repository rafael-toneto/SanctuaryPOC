import SwiftUI

struct SanctuaryMapLot: Identifiable, Equatable {
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
