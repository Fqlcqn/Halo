import AppKit
import SwiftUI

/// Uses the production renderer and geometry. No ActionService is reachable here.
struct WheelEditor: View {
    @Binding var preferences: HaloPreferences
    let quitter: Bool
    let editable: Bool
    var previewLimit: Double = 340
    var scalesToLargestWheel = false
    @StateObject private var state = WheelState()
    @State private var catalog = ApplicationCatalog()
    @State private var hovered: String?
    @State private var dragging: String?
    @State private var dragPoint: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animation: Animation? { reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88) }
    private var scale: Double { min(1, previewLimit / (scalesToLargestWheel ? 576 : state.geometry.panelSize)) }
    private var missing: [LauncherTarget] {
        preferences.launcherTargets.filter { target in !state.items.contains { $0.id == target.id } }
    }
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                WheelView(state: state, showsIcons: false)
                if state.items.isEmpty {
                    Text(quitter ? "No running apps" : "Add your first app")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(state.items) { item in
                    editorIcon(item)
                }
            }
            .frame(width: state.geometry.panelSize, height: state.geometry.panelSize)
            .coordinateSpace(name: "wheel-editor")
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard dragging == nil else { return }
                switch phase {
                case .active(let point):
                    let active = state.items.firstIndex { $0.id == hovered }
                    let hit = state.geometry.editorHit(at: point, count: state.items.count,
                        selected: state.selected, lift: state.motion.lift, active: active)
                    hovered = hit.map { state.items[$0].id }
                    select(at: point, override: editable && !quitter ? hit : nil)
                case .ended: state.selected = nil; hovered = nil
                }
            }
            .scaleEffect(scale)
            .frame(width: state.geometry.panelSize * scale, height: state.geometry.panelSize * scale)
            .frame(maxWidth: .infinity)
            .animation(animation, value: state.geometry.diameter)
            if editable && !quitter && !missing.isEmpty {
                HStack {
                    Text("\(missing.count) unavailable").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Menu("Manage missing apps") {
                        ForEach(missing) { target in
                            Button("Remove \(target.name)") { remove(target.id) }
                        }
                    }.font(.caption)
                }
            }
        }
        .onAppear { refresh() }
        .onChange(of: preferences) { _, _ in refresh() }
        .onChange(of: quitter) { _, _ in dragging = nil; dragPoint = nil; refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in if quitter { refresh() } }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in if quitter { refresh() } }
        .onDisappear { catalog.stop() }
    }
    private func editorIcon(_ item: WheelItem) -> some View {
        let index = state.items.firstIndex(where: { $0.id == item.id }) ?? 0
        let geometry = state.geometry
        let offset = geometry.offset(index: index, count: state.items.count, selected: state.selected == index, lift: state.motion.lift)
        let point = dragging == item.id ? (dragPoint ?? CGPoint(x: geometry.panelSize / 2 + offset.x, y: geometry.panelSize / 2 + offset.y))
            : CGPoint(x: geometry.panelSize / 2 + offset.x, y: geometry.panelSize / 2 + offset.y)
        return IconTile(item: item, selected: hovered == item.id || dragging == item.id, size: geometry.itemSize(count: state.items.count))
            .contentShape(Rectangle())
            .overlay(alignment: .topTrailing) {
                if editable && !quitter {
                    Button { remove(item.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(.regularMaterial, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.5))
                    }.buttonStyle(.plain).offset(x: 5, y: -5)
                        .opacity(hovered == item.id && dragging == nil ? 1 : 0)
                        .allowsHitTesting(hovered == item.id && dragging == nil)
                        .accessibilityLabel("Remove \(item.name) from wheel")
                }
            }
            .help(item.name)
            .onTapGesture { hovered = item.id }
            .gesture(DragGesture(minimumDistance: 5, coordinateSpace: .named("wheel-editor"))
                .onChanged { value in
                    guard editable && !quitter else { return }
                    dragging = item.id; dragPoint = value.location
                    let dx = value.location.x - geometry.panelSize / 2
                    let dy = geometry.panelSize / 2 - value.location.y
                    guard let destination = geometry.selectedIndex(dx: dx, dy: dy, count: state.items.count),
                          destination != index,
                          let target = preferences.launcherTargets.firstIndex(where: { $0.id == state.items[destination].id }) else { return }
                    withAnimation(animation) { LauncherTarget.move(item.id, to: target, in: &preferences.launcherTargets) }
                }
                .onEnded { _ in withAnimation(animation) { dragging = nil; dragPoint = nil } })
            .contextMenu {
                if editable && !quitter {
                    Button("Move clockwise") { move(item.id, by: 1) }
                    Button("Move counterclockwise") { move(item.id, by: -1) }
                    Button("Remove from wheel") { remove(item.id) }
                }
            }
            .accessibilityActions {
                if editable && !quitter {
                    Button("Remove from wheel") { remove(item.id) }
                    Button("Move clockwise") { move(item.id, by: 1) }
                }
            }
            .position(point)
            .zIndex(dragging == item.id ? 2 : hovered == item.id ? 1 : 0)
            .animation(dragging == item.id ? nil : animation, value: point)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }
    private func select(at point: CGPoint, override: Int? = nil) {
        let g = state.geometry
        let dx = point.x - g.panelSize / 2, dy = g.panelSize / 2 - point.y
        let index = override ?? g.previewIndex(at: point, count: state.items.count)
        state.motion.lift = g.iconLift(distance: hypot(dx, dy), dynamic: preferences.dynamicIconMovement)
        if let index, index != state.selected {
            if preferences.previewHaptics {
                NSHapticFeedbackManager.defaultPerformer.perform(quitter ? .alignment : .levelChange, performanceTime: .now)
            }
            state.selectionHasOrigin = state.selected != nil
            state.selectionAngle += WheelGeometry.shortestDelta(from: state.selectionAngle, to: g.angle(index: index, count: state.items.count))
        }
        state.selected = index
    }
    private func refresh() {
        state.geometry = WheelGeometry(diameter: quitter ? preferences.quitterDiameter : preferences.launcherDiameter,
            selectionDistance: preferences.selectionDistance, maximumSelectionDistance: preferences.maximumSelectionDistance,
            quitter: quitter, trashPosition: preferences.trashPosition, thickness: preferences.wheelThickness)
        state.glassFinish = preferences.glassFinish; state.highlightsTrash = preferences.highlightsTrash
        state.glassAmount = preferences.glassAmount
        state.selectionTint = preferences.selectionTint
        state.revealed = true; state.selected = nil
        let items = quitter ? catalog.quitter(showsTrash: preferences.showsTrash) : catalog.launcher(targets: preferences.launcherTargets)
        withAnimation(animation) { state.items = items }
    }
    private func remove(_ id: String) {
        withAnimation(animation) { preferences.launcherTargets.removeAll { $0.id == id } }
        hovered = nil
    }
    private func move(_ id: String, by delta: Int) {
        guard let index = preferences.launcherTargets.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(animation) { LauncherTarget.move(id, to: index + delta, in: &preferences.launcherTargets) }
    }
}
