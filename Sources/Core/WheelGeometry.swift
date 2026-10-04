import Foundation
import CoreGraphics

/// A stable visual direction used by a wheel presentation. It is independent
/// of the transient running-app array order.
struct WheelLayoutSlot: Equatable, Identifiable {
    let id: String
    let angle: Double
}

/// Sliders travel through discrete indices so labels, persisted values and
/// feedback share exactly the same stops. Imported legacy values are preserved
/// until the user actually moves the control.
struct SliderStops {
    let values: [Double]
    static let finish = SliderStops(values: (0...20).map { Double($0) / 20 })
    static let thickness = SliderStops(values: Array(stride(from: 36.0, through: 78, by: 3)))
    static let diameter = SliderStops(values: Array(stride(from: 240.0, through: 520, by: 20)))
    static let deadZone = SliderStops(values: Array(stride(from: 40.0, through: 86, by: 2)))
    // Final position represents unlimited without serializing numeric infinity.
    static let reach = SliderStops(values: Array(stride(from: 100.0, through: 2100, by: 100)))
    func index(for value: Double) -> Double {
        Double(values.indices.min(by: { abs(values[$0] - value) < abs(values[$1] - value) }) ?? 0)
    }
    func value(at index: Double) -> Double {
        values[min(values.count - 1, max(0, Int((index.isFinite ? index : 0).rounded())))]
    }
    func change(from current: Double, to index: Double) -> Double? {
        let next = value(at: index)
        return next == current ? nil : next
    }
}

/// Coordinate-independent behavior recovered from the approved application.
struct WheelGeometry: Equatable {
    let diameter: Double
    let selectionDistance: Double
    let maximumSelectionDistance: Double?
    let startAngle: Double
    let thickness: Double
    var iconSize: Double { 58 * thickness / 66 }
    var padding: Double { 4 * thickness / 66 }
    var innerDiameter: Double { max(80, diameter - thickness * 2) }
    var iconRadius: Double { diameter / 2 - padding - iconSize / 2 }
    var panelSize: Double { diameter + 56 }
    func itemSize(count: Int) -> Double {
        guard count > 1 else { return iconSize }
        return min(iconSize, max(18, 2 * iconRadius * sin(.pi / Double(count)) - 6))
    }

    init(diameter: Double = 300, selectionDistance: Double = 86, maximumSelectionDistance: Double? = nil, quitter: Bool = false, trashPosition: TrashPosition = .bottom, thickness: Double = 66) {
        self.diameter = diameter.isFinite ? min(520, max(240, diameter)) : 300
        self.thickness = thickness.isFinite ? min(78, max(36, thickness)) : 66
        self.selectionDistance = min(selectionDistance.isFinite ? min(86, max(40, selectionDistance)) : 86,
                                     (self.diameter - self.thickness) / 2)
        self.maximumSelectionDistance = maximumSelectionDistance.flatMap { $0.isFinite ? min(2000, max(100, $0)) : nil }
        self.startAngle = quitter ? trashPosition.angle : -.pi / 2
    }

    func angle(index: Int, count: Int) -> Double {
        guard count > 0 else { return startAngle }
        return Double(index) * 2 * .pi / Double(count) + startAngle
    }

    func offset(index: Int, count: Int, selected: Bool, lift: Double = 8) -> CGPoint {
        offset(angle: angle(index: index, count: count), selected: selected, lift: lift)
    }

    func offset(angle: Double, selected: Bool, lift: Double = 8) -> CGPoint {
        let radius = iconRadius + (selected ? min(8, max(0, lift)) : 0)
        let a = angle
        return CGPoint(x: cos(a) * radius, y: sin(a) * radius)
    }

    /// AppKit global coordinates: positive y points upward.
    func selectedIndex(dx: Double, dy: Double, count: Int) -> Int? {
        selectedIndex(dx: dx, dy: dy, angles: (0..<count).map { angle(index: $0, count: count) })
    }

    /// Shared radial hit-test for a fixed visual layout. Unlike count-based
    /// selection, these angles do not shift when an item disappears.
    func selectedIndex(dx: Double, dy: Double, angles: [Double]) -> Int? {
        guard !angles.isEmpty, dx.isFinite, dy.isFinite else { return nil }
        let distance = hypot(dx, dy)
        guard distance.isFinite, distance >= selectionDistance,
              maximumSelectionDistance.map({ distance <= $0 }) ?? true else { return nil }
        let pointer = atan2(-dy, dx)
        var best: (Int, Double)?
        for (index, angle) in angles.enumerated() {
            let delta = abs(Self.shortestDelta(from: angle, to: pointer))
            if best == nil || delta < best!.1 { best = (index, delta) }
        }
        return best?.0
    }

    /// At the center dead-zone boundary lift is zero; at the outer rim (or a
    /// nearer finite selection limit) it reaches the original eight points.
    func iconLift(distance: Double, dynamic: Bool) -> Double {
        guard dynamic else { return 8 }
        guard distance.isFinite else { return 0 }
        let end = min(diameter / 2, maximumSelectionDistance ?? diameter / 2)
        return 8 * min(1, max(0, (distance - selectionDistance) / (end - selectionDistance)))
    }

    /// Previews are bounded by their square, even when live selection is unlimited.
    func previewIndex(at point: CGPoint, count: Int) -> Int? {
        guard point.x >= 0, point.y >= 0, point.x < panelSize, point.y < panelSize else { return nil }
        return selectedIndex(dx: point.x - panelSize / 2, dy: panelSize / 2 - point.y, count: count)
    }

    /// Keep the visible remove control attached to its icon, even when its
    /// corner crosses a neighboring angular sector on a crowded wheel.
    func editorHit(at point: CGPoint, count: Int, selected: Int?, lift: Double, active: Int?) -> Int? {
        guard count > 0 else { return nil }
        let size = itemSize(count: count)
        func rect(_ index: Int, lifted: Bool) -> CGRect {
            let offset = offset(index: index, count: count, selected: lifted, lift: lift)
            return CGRect(x: panelSize / 2 + offset.x - size / 2,
                          y: panelSize / 2 + offset.y - size / 2, width: size, height: size)
        }
        if let active, (0..<count).contains(active) {
            let icon = rect(active, lifted: selected == active)
            let button = CGRect(x: icon.maxX - 15, y: icon.minY - 5, width: 20, height: 20)
            if button.insetBy(dx: -2, dy: -2).contains(point) || icon.union(rect(active, lifted: false)).contains(point) { return active }
        }
        return (0..<count).filter { rect($0, lifted: selected == $0).contains(point) }.min {
            let a = rect($0, lifted: selected == $0), b = rect($1, lifted: selected == $1)
            return hypot(point.x-a.midX, point.y-a.midY) < hypot(point.x-b.midX, point.y-b.midY)
        }
    }

    /// Opposite sectors have two equally short paths. Follow the side crossed
    /// by the pointer so a two-item wheel can rotate in either direction.
    static func selectionDelta(from: Double, to: Double, pointer: Double?) -> Double {
        let delta = shortestDelta(from: from, to: to)
        guard abs(abs(delta) - .pi) < 0.000001, let pointer else { return delta }
        return shortestDelta(from: from, to: pointer) < 0 ? -.pi : .pi
    }

    static func shortestDelta(from: Double, to: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }
}

struct LauncherTarget: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var bundleIdentifier: String? = nil
    var applicationPath: String? = nil
    var bookmark: Data? = nil
    var resolvedBundleIdentifier: String { bundleIdentifier ?? id }

    /// Moves by stable identity, including after earlier removals/reorders.
    static func move(_ id: String, to destination: Int, in targets: inout [Self]) {
        guard let source = targets.firstIndex(where: { $0.id == id }), !targets.isEmpty else { return }
        let target = min(targets.count - 1, max(0, destination))
        guard source != target else { return }
        let item = targets.remove(at: source)
        targets.insert(item, at: target)
    }
    static let original: [Self] = [
        .init(id: "com.operasoftware.OperaGX", name: "Opera GX"),
        .init(id: "com.apple.Notes", name: "Notes"),
        .init(id: "com.spotify.client", name: "Spotify"),
        .init(id: "com.surfshark.vpnclient.macos", name: "Surfshark"),
        .init(id: "com.apple.ActivityMonitor", name: "Activity Monitor"),
        .init(id: "com.apple.MobileSMS", name: "Messages"),
        .init(id: "com.moonsworth.client", name: "Lunar Client"),
        .init(id: "com.apple.systempreferences", name: "System Settings")
    ]
}

enum WheelGlassFinish: Int, Codable, CaseIterable {
    case veryLiquid = 0, standard = 1, translucent = 2
    var level: Double { self == .veryLiquid ? 0 : self == .standard ? 0.35 : 1 }
    var title: String {
        switch self {
        case .veryLiquid: return "Very Liquid"
        case .standard: return "Default"
        case .translucent: return "Translucent"
        }
    }
}

enum TrashPosition: String, Codable, CaseIterable {
    case bottom, left, top, right
    var angle: Double {
        switch self { case .bottom: .pi / 2; case .left: .pi; case .top: -.pi / 2; case .right: 0 }
    }
}

struct HaloTint: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    static let white = HaloTint(red: 1, green: 1, blue: 1)
    var isValid: Bool { [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) } }
}

enum QuitDisposition: Equatable {
    case closeFinderWindows, normal, force
    static func resolve(bundleIdentifier: String?, force: Bool) -> Self {
        bundleIdentifier == "com.apple.finder" ? .closeFinderWindows : force ? .force : .normal
    }
}

struct HaloPreferences: Codable, Equatable {
    var lessAnimation = false
    var previewHaptics = false
    var settingsTint = HaloTint.white
    var selectionTint = HaloTint.white
    /// Regular quit is the safe default. Force quit is deliberate, either
    /// globally through Settings or for an individual app.
    var forceQuitApps = false
    var appQuitOverrides: [String: Bool] = [:]
    func shouldForceQuit(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier.flatMap { appQuitOverrides[$0] } ?? forceQuitApps
    }
    var glassFinish: WheelGlassFinish = .standard
    var glassAmount: Double? = nil
    var wheelThickness = 66.0
    var glassLevel: Double {
        get { glassAmount ?? glassFinish.level }
        set { glassAmount = newValue }
    }
    var glassTitle: String {
        if glassLevel == 0 { return "Very Liquid" }
        if glassLevel == 0.35 { return "Default" }
        if glassLevel == 1 { return "Translucent" }
        return "\(Int((glassLevel * 100).rounded()))% diffusion"
    }
    var quitterPreferredAngles: [String: Double] = [:]
    var version = 3
    var launcherDiameter = 300.0
    var quitterDiameter = 300.0
    var selectionDistance = 86.0
    var maximumSelectionDistance: Double? = nil // nil encodes unlimited selection without non-JSON infinity.
    var dynamicIconMovement = false
    var launcherTargets = LauncherTarget.original
    var showsTrash = true
    var highlightsTrash = true
    var trashPosition: TrashPosition = .bottom
    var haptics = true
    var showSettingsOnLaunch = true

    init() {}
    enum CodingKeys: String, CodingKey {
        case lessAnimation, previewHaptics, appQuitOverrides, quitterPreferredAngles
        case glassFinish, glassAmount, wheelThickness, settingsTint, selectionTint, forceQuitApps
        case version, launcherDiameter, quitterDiameter, selectionDistance, maximumSelectionDistance
        case dynamicIconMovement, launcherTargets, haptics, showSettingsOnLaunch
        case showsTrash, highlightsTrash, trashPosition
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lessAnimation = try c.decodeIfPresent(Bool.self, forKey: .lessAnimation) ?? false
        previewHaptics = try c.decodeIfPresent(Bool.self, forKey: .previewHaptics) ?? false
        settingsTint = try c.decodeIfPresent(HaloTint.self, forKey: .settingsTint) ?? .white
        selectionTint = try c.decodeIfPresent(HaloTint.self, forKey: .selectionTint) ?? .white
        let storedVersion = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        // Version 1 used force quit by default. The version 2 product default
        // is regular quit, so migrate legacy installs to it while retaining
        // each explicit per-app choice.
        forceQuitApps = storedVersion >= 2
            ? (try c.decodeIfPresent(Bool.self, forKey: .forceQuitApps) ?? false)
            : false
        appQuitOverrides = try c.decodeIfPresent([String: Bool].self, forKey: .appQuitOverrides) ?? [:]
        quitterPreferredAngles = try c.decodeIfPresent([String: Double].self, forKey: .quitterPreferredAngles) ?? [:]
        glassFinish = try c.decodeIfPresent(WheelGlassFinish.self, forKey: .glassFinish) ?? .standard
        glassAmount = try c.decodeIfPresent(Double.self, forKey: .glassAmount)
        wheelThickness = try c.decodeIfPresent(Double.self, forKey: .wheelThickness) ?? 66
        version = 3
        launcherDiameter = try c.decode(Double.self, forKey: .launcherDiameter)
        quitterDiameter = try c.decode(Double.self, forKey: .quitterDiameter)
        selectionDistance = try c.decode(Double.self, forKey: .selectionDistance)
        maximumSelectionDistance = try c.decodeIfPresent(Double.self, forKey: .maximumSelectionDistance)
        dynamicIconMovement = try c.decodeIfPresent(Bool.self, forKey: .dynamicIconMovement) ?? false
        launcherTargets = try c.decode([LauncherTarget].self, forKey: .launcherTargets)
        showsTrash = try c.decodeIfPresent(Bool.self, forKey: .showsTrash) ?? true
        highlightsTrash = try c.decodeIfPresent(Bool.self, forKey: .highlightsTrash) ?? true
        trashPosition = try c.decodeIfPresent(TrashPosition.self, forKey: .trashPosition) ?? .bottom
        haptics = try c.decode(Bool.self, forKey: .haptics)
        showSettingsOnLaunch = try c.decode(Bool.self, forKey: .showSettingsOnLaunch)
    }

    var isValid: Bool {
        version == 3 && appQuitOverrides.count <= 512 &&
        appQuitOverrides.keys.allSatisfy { !$0.isEmpty && $0.count <= 255 } &&
        quitterPreferredAngles.count <= 512 &&
        quitterPreferredAngles.allSatisfy { key, value in !key.isEmpty && key.count <= 4096 && value.isFinite && (0..<1).contains(value) } &&
        settingsTint.isValid && selectionTint.isValid &&
        wheelThickness.isFinite && (36...78).contains(wheelThickness) &&
        (glassAmount.map { $0.isFinite && (0...1).contains($0) } ?? true) &&
        launcherDiameter.isFinite && quitterDiameter.isFinite &&
        (240...520).contains(launcherDiameter) && (240...520).contains(quitterDiameter) &&
        selectionDistance.isFinite && (40...86).contains(selectionDistance) &&
        (maximumSelectionDistance.map { $0.isFinite && (100...2000).contains($0) } ?? true) &&
        launcherTargets.count <= 24 && Set(launcherTargets.map(\.id)).count == launcherTargets.count &&
        launcherTargets.allSatisfy {
            !$0.id.isEmpty && $0.id.count <= 255 && !$0.name.isEmpty && $0.name.count <= 255 &&
            !$0.resolvedBundleIdentifier.isEmpty && $0.resolvedBundleIdentifier.count <= 255 &&
            ($0.applicationPath.map { $0.hasPrefix("/") && $0.lowercased().hasSuffix(".app") && $0.count <= 4096 } ?? true) &&
            ($0.bookmark.map { $0.count <= 16384 } ?? true)
        }
    }
}

/// Separate defaults domain in development; never writes the original app's settings.
final class PreferenceStore {
    static let key = "HaloPreferences.v1"
    let defaults: UserDefaults
    private(set) var value: HaloPreferences
    var onChange: (() -> Void)?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(HaloPreferences.self, from: data), decoded.isValid {
            value = decoded
        } else {
            value = HaloPreferences()
            // Retain invalid bytes for user-assisted recovery, instead of discarding them.
            if let data = defaults.data(forKey: Self.key) { defaults.set(data, forKey: Self.key + ".recovery") }
        }
    }

    @discardableResult func save(_ value: HaloPreferences, notify: Bool = true) -> Bool {
        guard value.isValid, let encoded = try? JSONEncoder().encode(value) else { return false }
        defaults.set(encoded, forKey: Self.key)
        guard defaults.synchronize() else { return false }
        self.value = value
        if notify {
            NotificationCenter.default.post(name: Notification.Name("HaloAppearanceChanged"), object: nil)
            onChange?()
        }
        return true
    }
}
