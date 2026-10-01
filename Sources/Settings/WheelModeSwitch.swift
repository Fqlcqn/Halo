import SwiftUI

/// The thumb follows the pointer, then settles into one of two modes.
/// Click, keyboard and VoiceOver remain available alongside dragging.
struct WheelModeSwitch: View {
    @Binding var quitter: Bool
    var changed: () -> Void = {}
    var labels = ["Launcher", "Quitter"]
    var controlWidth: CGFloat = 220
    var accessibilityTitle = "Preview wheel"
    var body: some View {
        SlidingChoiceSwitch(selection: Binding(get: { quitter ? 1 : 0 }, set: { quitter = $0 == 1 }),
                            changed: changed, labels: labels, controlWidth: controlWidth, accessibilityTitle: accessibilityTitle)
    }
}

struct SlidingChoiceSwitch: View {
    @Binding var selection: Int
    var changed: () -> Void = {}
    let labels: [String]
    var controlWidth: CGFloat = 220
    let accessibilityTitle: String
    @GestureState private var pointer: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func select(_ candidate: Int) {
        let next = min(labels.count - 1, max(0, candidate))
        guard next != selection else { return }
        selection = next; changed()
    }
    var body: some View {
        GeometryReader { proxy in
            let travel = (proxy.size.width - 6) / CGFloat(labels.count)
            let position = pointer.map { min(travel * CGFloat(labels.count - 1), max(0, $0 - travel / 2 - 3)) } ?? CGFloat(selection) * travel
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.07))
                Capsule().fill(.white.opacity(0.2))
                    .frame(width: travel, height: 26).offset(x: 3 + position)
                HStack(spacing: 0) {
                    ForEach(labels.indices, id: \.self) { Text(labels[$0]).frame(maxWidth: .infinity) }
                }.font(.system(size: 12, weight: .medium))
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 3)
                .updating($pointer) { value, state, _ in state = value.location.x }
                .onChanged { value in select(Int(max(0, value.location.x) / proxy.size.width * CGFloat(labels.count))) }
                .onEnded { value in select(Int(max(0, value.location.x) / proxy.size.width * CGFloat(labels.count))) })
            .simultaneousGesture(SpatialTapGesture().onEnded { select(Int(max(0, $0.location.x) / proxy.size.width * CGFloat(labels.count))) })
            .animation(reduceMotion || pointer != nil ? nil : .spring(response: 0.18, dampingFraction: 0.9), value: position)
        }
        .frame(width: controlWidth, height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(labels[selection])
        .accessibilityAdjustableAction { direction in
            switch direction { case .increment: select(selection + 1); case .decrement: select(selection - 1); @unknown default: break }
        }
        .accessibilityActions { ForEach(labels.indices, id: \.self) { index in Button(labels[index]) { select(index) } } }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { select(selection - 1); return .handled }
        .onKeyPress(.rightArrow) { select(selection + 1); return .handled }
        .onKeyPress(.space) { select((selection + 1) % labels.count); return .handled }
    }
}

struct HaloToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            WheelModeSwitch(quitter: configuration.$isOn, labels: ["Off", "On"], controlWidth: 96,
                            accessibilityTitle: "Enabled")
        }.accessibilityElement(children: .combine)
    }
}

private struct ActivationSwitch: View {
    @State var enabled: Bool
    let title: String
    let changed: (Bool) -> Void
    var body: some View {
        WheelModeSwitch(quitter: Binding(get: { enabled }, set: { enabled = $0; changed($0) }),
                        labels: ["Hold", "Toggle"], controlWidth: 212, accessibilityTitle: title)
            .foregroundStyle(.white).environment(\.colorScheme, .dark)
    }
}

@_cdecl("HaloAddActivationSwitch") @MainActor
func addActivationSwitch(_ pointer: UnsafeMutableRawPointer, _ quitter: Bool, _ enabled: Bool,
                         _ changed: @escaping @convention(block) (Bool) -> Void) {
    let parent = Unmanaged<NSView>.fromOpaque(pointer).takeUnretainedValue()
    let host = ActivationSwitchHost(rootView: ActivationSwitch(enabled: enabled,
        title: quitter ? "Quitter activation" : "Launcher activation", changed: changed))
    host.sizingOptions = []; host.safeAreaRegions = []
    host.frame = parent.bounds; host.autoresizingMask = [.width, .height]
    parent.addSubview(host)
}

private final class ActivationSwitchHost: NSHostingView<ActivationSwitch> {
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
