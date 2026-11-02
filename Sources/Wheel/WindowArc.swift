import Foundation

struct WindowArc {
    let angle: Double
    let count: Int
    let width: Double
    let inner: Double
    let outer: Double
    init(angle: Double, count: Int, parentWidth: Double, geometry: WheelGeometry) {
        self.angle = angle
        self.count = count
        inner = geometry.diameter / 2 + 6
        outer = inner + geometry.thickness
        width = min(parentWidth, 2 * .pi / Double(max(count, 1)))
    }
    func center(_ index: Int) -> Double {
        angle + (Double(index) - Double(count - 1) / 2) * width
    }
    // Bounding rectangle in tangent/radial coordinates, including both
    // curved edges. Aspect-fill this rectangle before applying the sector mask.
    var crop: (size: CGSize, radialCenter: Double) {
        let half = width / 2
        let base = (half <= .pi/2 ? inner : outer) * cos(half)
        return (CGSize(width: 2 * outer * sin(min(half, .pi/2)) + 2,
                       height: outer - base + 2), (outer + base) / 2)
    }
    func index(distance: Double, direction: Double) -> Int? {
        guard distance >= inner, count > 0 else { return nil }
        let offset = WheelGeometry.shortestDelta(from: angle, to: direction) + Double(count) * width / 2
        guard offset >= 0, offset < Double(count) * width else { return nil }
        return min(count - 1, Int(offset / width))
    }
}

struct WindowPull {
    private var anchor: CGPoint
    private var anchorDistance: Double
    private var anchorTime: Double
    private var stroke: (start: Double, time: Double)?
    private var peak: Double
    private(set) var requested = false

    init(point: CGPoint, time: Double) {
        anchor = point
        anchorDistance = hypot(point.x, point.y)
        peak = anchorDistance
        anchorTime = time
    }

    // The pointer must settle in a three-point neighborhood before the
    // outward stroke. Moving sideways through a sector never counts as rest.
    mutating func sample(point: CGPoint, time now: Double) -> Double {
        let distance = hypot(point.x, point.y)
        if requested && distance < peak - 12 {
            requested = false
            stroke = nil
        }
        if hypot(point.x - anchor.x, point.y - anchor.y) > 3 {
            if now - anchorTime >= 0.12 {
                stroke = distance > anchorDistance ? (anchorDistance, now) : nil
            }
            anchor = point
            anchorTime = now
            anchorDistance = distance
        }
        if let stroke, now - stroke.time > 0.09 || distance < stroke.start - 3 {
            self.stroke = nil
        }
        guard let stroke else { return 0 }
        let travel = max(0, distance - stroke.start)
        if travel >= 44 && !requested {
            requested = true
            peak = distance
        }
        if requested { peak = max(peak, distance) }
        return 19 * (1 - exp(-travel / 24))
    }
}
