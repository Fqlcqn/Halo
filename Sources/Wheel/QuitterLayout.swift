import Foundation

/// A nonvisual description of a running app's place on the Quitter wheel.
/// `identifier` is normally an NSRunningApplication bundle identifier; a URL
/// key is used only when macOS does not provide one.
struct QuitterLayoutRequest: Equatable {
    let identifier: String
    let launcherAngle: Double?
    let rememberedAngle: Double?
    let persistsAngle: Bool
}

struct QuitterLayoutPlan: Equatable {
    let slots: [WheelLayoutSlot]
    /// New assignments are persisted as turns in [0, 1), never raw radians.
    let newlyRememberedAngles: [String: Double]
}

/// Keeps Quitter directions stable without asking the running-app list to be
/// symmetrical. It is deliberately pure so persistent layouts are testable.
enum QuitterLayoutPlanner {
    static let turn = 2 * Double.pi

    static func normalizedTurn(for angle: Double) -> Double {
        let normalized = normalize(angle) / turn
        return normalized == 1 ? 0 : normalized
    }

    static func angle(forNormalizedTurn turn: Double) -> Double {
        normalize(turn * Self.turn)
    }

    static func plan(
        requests: [QuitterLayoutRequest],
        fixedSlots: [WheelLayoutSlot],
        minimumSeparation: Double
    ) -> QuitterLayoutPlan {
        let separation = min(.pi, max(0.01, minimumSeparation.isFinite ? minimumSeparation : 0.4))
        var slots = fixedSlots
        var remembered: [String: Double] = [:]
        var remaining = requests

        // Launcher positions always lead. Existing remembered positions follow,
        // then unknown apps fill the largest available gap in stable ID order.
        for priority in [2, 1, 0] {
            let group = remaining.filter { request in
                switch priority {
                case 2: return request.launcherAngle != nil
                case 1: return request.launcherAngle == nil && request.rememberedAngle != nil
                default: return request.launcherAngle == nil && request.rememberedAngle == nil
                }
            }.sorted { $0.identifier < $1.identifier }
            for request in group {
                let desired: Double
                if let launcher = request.launcherAngle { desired = normalize(launcher) }
                else if let existing = request.rememberedAngle { desired = normalize(existing) }
                else {
                    desired = largestGapCenter(in: slots, fallback: -.pi / 2)
                }
                let angle = nearestAvailable(to: desired, among: slots, separation: separation)
                if request.launcherAngle == nil, request.rememberedAngle == nil, request.persistsAngle {
                    // Save the angle after collision spacing, because this is
                    // the direction the user actually learned on screen.
                    remembered[request.identifier] = normalizedTurn(for: angle)
                }
                slots.append(.init(id: request.identifier, angle: angle))
            }
            remaining.removeAll { completed in group.contains(where: { $0.identifier == completed.identifier }) }
        }
        return .init(slots: slots, newlyRememberedAngles: remembered)
    }

    private static func nearestAvailable(to desired: Double, among slots: [WheelLayoutSlot], separation: Double) -> Double {
        guard !slots.isEmpty else { return normalize(desired) }
        let sorted = slots.map(\.angle).map(normalize).sorted()
        var candidates: [Double] = []
        for index in sorted.indices {
            let start = sorted[index]
            let end = index + 1 < sorted.count ? sorted[index + 1] : sorted[0] + turn
            let availableStart = start + separation
            let availableEnd = end - separation
            guard availableEnd >= availableStart else { continue }
            let unwrapped = unwrap(desired, near: (availableStart + availableEnd) / 2)
            candidates.append(normalize(min(availableEnd, max(availableStart, unwrapped))))
        }
        if let best = candidates.min(by: { circularDistance($0, desired) < circularDistance($1, desired) }) { return best }
        return largestGapCenter(in: slots, fallback: desired)
    }

    private static func largestGapCenter(in slots: [WheelLayoutSlot], fallback: Double) -> Double {
        guard !slots.isEmpty else { return normalize(fallback) }
        let sorted = slots.map(\.angle).map(normalize).sorted()
        var bestStart = sorted[0]
        var bestGap = -Double.infinity
        for index in sorted.indices {
            let start = sorted[index]
            let end = index + 1 < sorted.count ? sorted[index + 1] : sorted[0] + turn
            let gap = end - start
            // Stable iteration order resolves equal gaps deterministically.
            if gap > bestGap + 0.0000001 { bestGap = gap; bestStart = start }
        }
        return normalize(bestStart + bestGap / 2)
    }

    private static func normalize(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: turn)
        return remainder < 0 ? remainder + turn : remainder
    }

    private static func unwrap(_ angle: Double, near reference: Double) -> Double {
        var result = normalize(angle)
        while result - reference > .pi { result -= turn }
        while reference - result > .pi { result += turn }
        return result
    }

    private static func circularDistance(_ a: Double, _ b: Double) -> Double {
        abs(WheelGeometry.shortestDelta(from: a, to: b))
    }
}
