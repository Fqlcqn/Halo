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
    private var previous: Double
    private var time: Double
    private var lastSpeed = 0.0
    private var stop: Double?
    private var peak: Double
    private(set) var requested = false

    init(distance: Double, time: Double) {
        previous = distance
        peak = distance
        self.time = time
    }

    // Only moved-pointer samples enter here. A gap between them records
    // stationary time even when AppKit sends no mouse-moved event at the stop.
    mutating func sample(distance: Double, time now: Double) -> Double {
        let dt = max(0.002, now - time)
        let delta = distance - previous
        let speed = delta / dt
        let paused = dt >= 0.038
        if distance < peak - 8 {
            requested = false
            stop = nil
            peak = distance
        }
        if !requested && (paused || (lastSpeed > 100 && speed >= 0 && speed < min(110, lastSpeed * 0.35))) {
            stop = previous
        }
        if let stop { self.stop = min(stop, distance) }
        let travel = max(0, distance - (stop ?? distance))
        // A train of small packets at steady renewed velocity is still
        // acceleration from rest. Do not require the *last* packet to accelerate.
        if travel >= 10 && (speed >= 145 || (paused && delta >= 10)) {
            requested = true
        }
        previous = distance
        time = now
        lastSpeed = speed
        peak = max(peak, distance)
        return 19 * (1 - exp(-travel / 12))
    }
}
