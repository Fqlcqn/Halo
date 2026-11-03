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
    private enum Phase {
        case settling, armed, pushing(deadline: Double), triggered
    }
    private var phase: Phase = .settling
    private let minimumRadius: Double
    private var anchor: CGPoint
    private var since: Double
    private var lastSample: Double
    private var peak: Double = 0
    var requested: Bool { if case .triggered = phase { return true }; return false }

    init(point: CGPoint, time: Double, wheelRadius: Double) {
        minimumRadius = wheelRadius + 24
        anchor = point
        since = time
        lastSample = time
    }

    private mutating func settle(at point: CGPoint, time: Double) -> Double {
        phase = .settling
        anchor = point
        since = time
        return 0
    }

    mutating func sample(point: CGPoint, time now: Double) -> Double {
        let elapsed = now - lastSample
        let previousTime = lastSample
        lastSample = now
        let radius = hypot(point.x, point.y)
        // Never infer rest or speed from a gap in event delivery.
        guard radius >= minimumRadius, elapsed >= 0, elapsed <= 0.055 else {
            return settle(at: point, time: now)
        }
        let travel = hypot(point.x - anchor.x, point.y - anchor.y)
        switch phase {
        case .settling:
            guard hypot(anchor.x, anchor.y) >= minimumRadius, travel <= 2 else {
                return settle(at: point, time: now)
            }
            if now - since >= 0.13 { phase = .armed }
            return 0
        case .armed:
            guard travel > 2 else { return 0 }
            phase = .pushing(deadline: previousTime + 0.10)
            peak = hypot(anchor.x, anchor.y)
        case .pushing, .triggered:
            break
        }
        let progress = radius - hypot(anchor.x, anchor.y)
        guard radius >= peak - 3, progress > 0, progress >= travel * 0.80 else {
            return settle(at: point, time: now)
        }
        peak = max(peak, radius)
        if case .pushing(let deadline) = phase {
            guard now <= deadline else { return settle(at: point, time: now) }
            if progress >= 44 { phase = .triggered }
        }
        return 24 * (1 - exp(-progress / 25))
    }
}
