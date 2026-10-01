import AppKit
import SwiftUI

struct WheelItem: Identifiable {
    enum Action { case launch(URL, bundleIdentifier: String), quit(NSRunningApplication), emptyTrash }
    let id: String
    let name: String
    let icon: NSImage?
    let action: Action
    var isTrash: Bool { if case .emptyTrash = action { return true }; return false }
}

@MainActor final class WheelState: ObservableObject {
    let motion = IconMotion()
    @Published var glassFinish: WheelGlassFinish = .standard
    @Published var glassAmount: Double?
    @Published var selectionTint = HaloTint.white
    @Published var items: [WheelItem] = []
    @Published var selected: Int?
    @Published var selectionAngle = -Double.pi / 2
    @Published var selectionHasOrigin = false
    @Published var revealed = false
    @Published var instantTransitions = false
    @Published var geometry = WheelGeometry()
    @Published var highlightsTrash = true
}

/// Pointer-distance changes invalidate only the icons, not the native glass.
@MainActor final class IconMotion: ObservableObject {
    @Published var lift = 8.0
}

struct RingSector: Shape {
    var start: Double
    var end: Double
    var innerRatio: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
        path.addArc(center: center, radius: radius * innerRatio, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct RingGlass: View {
    let geometry: WheelGeometry
    let finish: WheelGlassFinish
    var amount: Double? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            if reduceTransparency {
                Circle().strokeBorder(Color(white: 0.18), lineWidth: geometry.thickness)
                    .frame(width: geometry.diameter, height: geometry.diameter)
            } else {
                RefractiveRing(diameter: geometry.diameter, thickness: geometry.thickness, finish: finish, amount: amount)
                    .frame(width: geometry.diameter, height: geometry.diameter)
            }
            ForEach([geometry.diameter - 0.5, geometry.innerDiameter + 0.5], id: \.self) { size in
                Circle().stroke(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.03), .white.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.65)
                    .frame(width: size, height: size)
                    .blur(radius: 0.45)
            }
        }
    }
}

private struct SelectionBand: View {
    let geometry: WheelGeometry
    let angle: Double
    let span: Double
    let visible: Bool
    let tint: HaloTint
    var sector: RingSector { RingSector(start: -span / 2, end: span / 2, innerRatio: geometry.innerDiameter / geometry.diameter) }
    var body: some View {
        ZStack {
            sector.fill(LinearGradient(colors: [
                Color(red: 0.96, green: 0.99, blue: 0.98).opacity(0.30),
                Color(red: 0.73, green: 0.91, blue: 0.86).opacity(0.40),
                Color(red: 0.56, green: 0.78, blue: 0.74).opacity(0.24)
            ], startPoint: .top, endPoint: .bottom)).blendMode(.screen)
            sector.fill(RadialGradient(colors: [.white.opacity(0.18), .clear], center: .top, startRadius: 12, endRadius: geometry.diameter * 0.42)).blendMode(.screen)
            sector.stroke(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1.1)
            sector.fill(Color(red: 0.76, green: 0.95, blue: 0.90).opacity(0.22)).blur(radius: 14).blendMode(.screen)
        }
        .frame(width: geometry.diameter, height: geometry.diameter)
        .colorMultiply(tint.color)
        .rotationEffect(.radians(angle))
        .opacity(visible ? 1 : 0)
    }
}

private struct LockedBand: View {
    let geometry: WheelGeometry
    let span: Double
    var shape: RingSector { .init(start: -span / 2, end: span / 2, innerRatio: geometry.innerDiameter / geometry.diameter) }
    var body: some View {
        ZStack {
            shape.fill(LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom))
            shape.stroke(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.10)], startPoint: .top, endPoint: .bottom), lineWidth: 1.25)
            shape.stroke(.white.opacity(0.06), lineWidth: 5).blur(radius: 10)
        }
        .frame(width: geometry.diameter, height: geometry.diameter)
        .rotationEffect(.radians(geometry.startAngle))
    }
}

struct IconTile: View {
    let item: WheelItem
    let selected: Bool
    let size: Double
    var body: some View {
        Group {
            if let image = item.icon, !item.isTrash {
                Image(nsImage: image).resizable().interpolation(.high).frame(width: size, height: size)
            } else {
                ZStack {
                    Circle().fill(.white.opacity(selected ? 0.28 : 0.10))
                    Circle().stroke(.white.opacity(selected ? 0.42 : (item.isTrash ? 0.26 : 0.12)), lineWidth: 1)
                    Circle().fill(.white.opacity(selected ? 0.12 : 0)).blur(radius: selected ? 10 : 0)
                    Image(systemName: item.isTrash ? "trash" : "app")
                        .font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white.opacity(selected ? 1 : 0.96))
                }.frame(width: size, height: size)
            }
        }
        .shadow(color: .black.opacity(selected ? 0.28 : 0.16), radius: selected ? 8 : 5, x: 0, y: 2)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct WheelView: View {
    @ObservedObject var state: WheelState
    var activate: (Int) -> Void = { _ in }
    var showsIcons = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let geometry = state.geometry
        let span = 2 * Double.pi / Double(max(1, state.items.count))
        ZStack {
            RingGlass(geometry: geometry, finish: state.glassFinish, amount: state.glassAmount)
            if state.highlightsTrash && state.items.first?.isTrash == true { LockedBand(geometry: geometry, span: span) }
            SelectionBand(geometry: geometry, angle: state.selectionAngle, span: span, visible: state.selected != nil, tint: state.selectionTint)
                .opacity(0.65 + 0.35 * (state.glassAmount ?? state.glassFinish.level))
                .animation(reduceMotion || !state.selectionHasOrigin ? nil : .spring(response: 0.14, dampingFraction: 0.98, blendDuration: 0.04), value: state.selectionAngle)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: state.selected != nil)
            if showsIcons { WheelIcons(state: state, motion: state.motion, activate: activate) }
        }
        .frame(width: geometry.diameter + 28, height: geometry.diameter + 28)
        .padding(14)
        .background(.clear)
        .scaleEffect(state.revealed || reduceMotion ? 1 : 0.97)
        .opacity(state.revealed ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: state.revealed ? 0.032 : 0.016), value: state.revealed)
        .transaction { transaction in
            if state.instantTransitions || reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
        }
    }
}

private struct WheelIcons: View {
    @ObservedObject var state: WheelState
    @ObservedObject var motion: IconMotion
    let activate: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                let selected = index == state.selected
                let offset = state.geometry.offset(index: index, count: state.items.count, selected: selected, lift: motion.lift)
                IconTile(item: item, selected: selected, size: state.geometry.itemSize(count: state.items.count))
                    .offset(x: offset.x, y: offset.y)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .animation(reduceMotion ? nil : .linear(duration: 1.0 / 120.0), value: motion.lift)
                    .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.86), value: state.selected)
                    .accessibilityAction { activate(index) }
            }
        }
    }
}
