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
        inner = geometry.diameter / 2 + 3
        outer = inner + geometry.thickness
        width = min(parentWidth, .pi / 4, (.pi * 1.65) / Double(max(count, 1)))
    }
    func center(_ index: Int) -> Double {
        angle + (Double(index) - Double(count - 1) / 2) * width
    }
    func index(distance: Double, direction: Double) -> Int? {
        guard distance >= inner, count > 0 else { return nil }
        let offset = WheelGeometry.shortestDelta(from: angle, to: direction) + Double(count) * width / 2
        guard offset >= 0, offset < Double(count) * width else { return nil }
        return Int(offset / width)
    }
}

struct WindowPull {
    private var origin: Double
    var previous: Double
    var time: Double
    var velocity = 0.0
    private var armed = false
    var requested = false
    init(distance: Double, time: Double) {
        origin = distance
        previous = distance
        self.time = time
    }
    mutating func sample(distance: Double, time now: Double, rim: Double) -> Double {
        let dt = max(0.004, now - time)
        let speed = (distance - previous) / dt
        // A continuous ballistic launch flick should cross the rim normally.
        // Arm after a pause or a slowdown over the parent, then respond to a
        // second outward push. A deliberate steady pull can break through too.
        if !armed && (dt >= 0.045 || (velocity > 100 && speed < velocity * 0.65) || abs(speed) < 160) {
            origin = previous
            armed = true
        }
        let travel = max(0, distance - max(origin, rim - 10))
        let accelerating = speed > 280 && speed > velocity + 65
        if armed && ((travel >= 24 && accelerating) || travel >= 54) { requested = true }
        if distance < rim - 8 { requested = false }
        // A sample after a stationary interval averages away a real flick.
        if armed && dt >= 0.045 && distance - previous >= 30 && travel >= 24 { requested = true }
        velocity = speed
        previous = distance
        time = now
        return 22 * (1 - exp(-travel / 24))
    }
}
