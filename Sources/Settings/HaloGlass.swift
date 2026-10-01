import AppKit
import SwiftUI

// One native glass card with a restrained, configurable color veil.
private struct SettingsGlass: View {
    @State private var tint = HaloTint.white
    var body: some View {
        GlassEffectContainer(spacing: 14) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
        .environment(\.colorScheme, .dark)
        // A restrained graphite veil keeps the desktop softly visible while
        // reducing the amount of background detail showing through the glass.
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.04))
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.color.opacity(0.045))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .allowsHitTesting(false)
        .onAppear { tint = HaloAppDelegate.current?.store?.value.settingsTint ?? .white }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HaloAppearanceChanged"))) { _ in
            tint = HaloAppDelegate.current?.store?.value.settingsTint ?? .white
        }
    }
}

extension HaloTint {
    var color: Color { Color(red: red, green: green, blue: blue) }
    init(_ color: Color) {
        let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
        // Wide-gamut picker colors can convert outside sRGB; keep the persisted
        // portable RGB representation valid rather than dropping the change.
        self.init(red: min(1, max(0, rgb.redComponent)), green: min(1, max(0, rgb.greenComponent)), blue: min(1, max(0, rgb.blueComponent)))
    }
}

@_cdecl("HaloAddSettingsGlass")
@MainActor
func addSettingsGlass(_ pointer: UnsafeMutableRawPointer) {
        let parent = Unmanaged<NSView>.fromOpaque(pointer).takeUnretainedValue()
        let hosting = SettingsGlassHost(rootView: SettingsGlass())
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        hosting.frame = parent.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.cornerRadius = 24
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        parent.addSubview(hosting)
}

private final class SettingsGlassHost: NSHostingView<SettingsGlass> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
