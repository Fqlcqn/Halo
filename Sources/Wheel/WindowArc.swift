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
    private var anchorTime: Double
    private var stroke: (origin: CGPoint, time: Double)?
    private(set) var requested = false

    init(point: CGPoint, time: Double) {
        anchor = point
        anchorTime = time
    }

    // Work in pointer coordinates: an equally fast diagonal or tangential
    // second stroke counts just as much when the wheel is far away.
    mutating func sample(point: CGPoint, time now: Double) -> Double {
        if hypot(point.x - anchor.x, point.y - anchor.y) > 4 {
            if now - anchorTime >= 0.10 {
                stroke = (anchor, now)
            }
            anchor = point
            anchorTime = now
        }
        if let stroke, now - stroke.time > 0.10 { self.stroke = nil }
        guard let stroke else { return requested ? 20 : 0 }
        let travel = hypot(point.x - stroke.origin.x, point.y - stroke.origin.y)
        if travel >= 40 { requested = true }
        return 24 * (1 - exp(-travel / 25))
    }
}
