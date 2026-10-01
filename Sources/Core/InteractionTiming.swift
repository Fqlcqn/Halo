import Foundation

/// Optimistic removal has a finite lifetime: cancelled/stalled quits return.
struct PendingQuitTracker {
    private var deadlines: [Int32: Double] = [:]
    mutating func begin(_ pid: Int32, until deadline: Double) { deadlines[pid] = deadline }
    mutating func remove(_ pid: Int32) { deadlines.removeValue(forKey: pid) }
    mutating func expire(at time: Double) { deadlines = deadlines.filter { $0.value > time } }
    func active(at time: Double) -> Set<Int32> { Set(deadlines.filter { $0.value > time }.keys) }
}

/// One discrete step per wheel notch / accumulated 12-point trackpad motion.
/// Momentum never edits preferences, and reversing direction resets residue.
struct ScrollDetents {
    private var residue = 0.0
    private var last = -Double.infinity
    mutating func step(delta: Double, precise: Bool, momentum: Bool, time: Double) -> Int {
        guard !momentum, delta.isFinite, delta != 0 else { return 0 }
        if time - last > 0.25 || residue * delta < 0 { residue = 0 }
        last = time
        residue += delta
        let threshold = precise ? 12.0 : 1.0
        guard abs(residue) >= threshold else { return 0 }
        let direction = residue > 0 ? 1 : -1
        residue = residue.truncatingRemainder(dividingBy: threshold)
        return direction
    }
}
