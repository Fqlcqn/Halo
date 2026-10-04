import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CustomizationPage: View {
    let tab: Int
    let store: PreferenceStore
    @State private var draft: HaloPreferences
    @State private var message = ""
    @State private var quitter = false
    @State private var quitAppID = ""
    @State private var backdrop = PreviewBackdrop.Style.color
    init(tab: Int, store: PreferenceStore) {
        self.tab = tab; self.store = store
        _draft = State(initialValue: store.value)
    }
    // Persist within the control's setter, not a later SwiftUI render cycle.
    private var preferences: HaloPreferences {
        get { draft }
        nonmutating set {
            var next = newValue
            // A wheel can discover positions while Settings is open. Ordinary
            // controls must not overwrite those silently persisted discoveries.
            if next.quitterPreferredAngles == draft.quitterPreferredAngles {
                for (id, angle) in store.value.quitterPreferredAngles where next.quitterPreferredAngles[id] == nil {
                    next.quitterPreferredAngles[id] = angle
                }
            }
            if store.save(next) { draft = next }
            else { message = "Could not save these settings." }
        }
    }
    private var preferencesBinding: Binding<HaloPreferences> {
        Binding(get: { preferences }, set: { preferences = $0 })
    }
    private func binding<T>(_ key: WritableKeyPath<HaloPreferences,T>) -> Binding<T> {
        Binding(get: { preferences[keyPath:key] }, set: { preferences[keyPath:key] = $0 })
    }
    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                if tab == 1 {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            section("Glass") {
                                HStack { Text("Wheel finish"); Spacer(); Text(preferences.glassTitle).foregroundStyle(.secondary) }
                                detentedSlider("Wheel glass", value: binding(\.glassLevel),
                                    stops: .finish, display: preferences.glassTitle)
                                HStack { Text("Very Liquid"); Spacer(); Text("Translucent") }
                                    .overlay(alignment: .leading) {
                                        GeometryReader { geometry in
                                            Text("Default").position(x: geometry.size.width * 0.35, y: geometry.size.height / 2)
                                        }
                                    }
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                                ColorPicker("Settings tint", selection: tintBinding(\.settingsTint), supportsOpacity: false)
                                ColorPicker("Selection tint", selection: tintBinding(\.selectionTint), supportsOpacity: false)
                            }
                            section("Size & selection") {
                                sizeControl("Launcher diameter", value: binding(\.launcherDiameter), stops: .diameter)
                                sizeControl("Quitter diameter", value: binding(\.quitterDiameter), stops: .diameter)
                                sizeControl("Wheel thickness", value: binding(\.wheelThickness), stops: .thickness)
                                sizeControl("Center dead zone", value: binding(\.selectionDistance), stops: .deadZone)
                                VStack(spacing: 5) {
                                    HStack {
                                        Text("Selection reach"); Spacer()
                                        Text(reachLabel).monospacedDigit().foregroundStyle(.secondary)
                                    }
                                    detentedSlider("Maximum selection distance", value: Binding(
                                        get: { preferences.maximumSelectionDistance ?? 2100 },
                                        set: { preferences.maximumSelectionDistance = $0 == 2100 ? nil : $0 }),
                                        stops: .reach, display: reachLabel)
                                }
                                Divider().opacity(0.4)
                                Toggle("Follow pointer distance", isOn: binding(\.dynamicIconMovement))
                                    .help("Selected icons glide outward as you move away from the center.")
                            }
                            Button("Reset appearance") {
                                guard confirmReset("Reset appearance?") else { return }
                                var next = preferences
                                next.launcherDiameter = 300; next.quitterDiameter = 300; next.selectionDistance = 86
                                next.maximumSelectionDistance = nil; next.dynamicIconMovement = false; next.glassFinish = .standard
                                next.glassAmount = nil; next.wheelThickness = 66
                                next.settingsTint = .white; next.selectionTint = .white
                                preferences = next
                            }.buttonStyle(.borderless).foregroundStyle(.secondary).font(.caption)
                        }.frame(width: 310)
                        VStack(spacing: 12) {
                            wheelPicker
                            ZStack {
                                PreviewBackdrop(style: backdrop).allowsHitTesting(false).accessibilityHidden(true)
                                WheelEditor(preferences: preferencesBinding, quitter: quitter, editable: false,
                                            previewLimit: 388)
                            }.frame(height: 400).clipShape(RoundedRectangle(cornerRadius: 18))
                            SlidingChoiceSwitch(selection: Binding(
                                get: { PreviewBackdrop.Style.allCases.firstIndex(of: backdrop) ?? 0 },
                                set: { backdrop = PreviewBackdrop.Style.allCases[$0] }), changed: tick,
                                labels: PreviewBackdrop.Style.allCases.map(\.rawValue), controlWidth: 280,
                                accessibilityTitle: "Preview background")
                            previewHapticsControl
                            VStack(spacing: 4) {
                                Text("Live preview · \(Int(quitter ? preferences.quitterDiameter : preferences.launcherDiameter)) pt")
                                    .foregroundStyle(.secondary)
                                Text((quitter ? preferences.quitterDiameter : preferences.launcherDiameter) + 56 <= 388
                                     ? "Actual size · Hover to try selection." : "Scaled to fit · Same proportions as the wheel.")
                                    .foregroundStyle(.tertiary)
                            }.font(.caption)
                        }.frame(maxWidth: .infinity)
                    }
                } else if tab == 2 {
                    HStack {
                        wheelPicker.frame(width: 220)
                        Spacer()
                        previewHapticsControl
                        Button(action: addApps) { Label("Add apps…", systemImage: "plus") }
                            .buttonStyle(.glass).disabled(quitter || preferences.launcherTargets.count >= 24)
                    }
                    HStack(alignment: .center, spacing: 20) {
                        VStack(spacing: 12) {
                            WheelEditor(preferences: preferencesBinding, quitter: quitter, editable: true,
                                        previewLimit: 356)
                                .frame(height: 380)
                            Text(quitter ? "Preview only · No apps are quit" : "Drag to reorder · Hover × to remove")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).frame(height: 440)
                        appsOptions.frame(width: 340)
                    }
                } else {
                    section("Behavior") {
                        Toggle("Less animation", isOn: binding(\.lessAnimation))
                            .help("Show and hide wheels instantly. Off keeps the smooth animation.")
                        Toggle("Haptic feedback", isOn: binding(\.haptics))
                        Toggle("Open Settings at launch", isOn: binding(\.showSettingsOnLaunch))
                        Toggle("Force quit apps", isOn: binding(\.forceQuitApps))
                            .help("Off: apps can save or ask before quitting. Finder always closes its windows instead.")
                    }
                    section("Customization") {
                        HStack { Button("Export…", action: exportPreferences); Button("Import…", action: importPreferences) }
                    }
                    Text((preferences.forceQuitApps ? "Force quit can lose unsaved changes. " : "Regular quit allows apps to save or ask before closing. ") + "Finder only closes its windows. Empty Trash permanently removes its contents.")
                        .font(.caption).foregroundStyle(.secondary)
                    section("Made by") {
                        Text("Maneesh Getni").font(.system(size: 14, weight: .medium))
                    }
                }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("customization-message") }
            }.padding(.trailing, 8).padding(.bottom, 16)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .font(.system(size: 13)).tint(.white).environment(\.colorScheme, .dark)
        .toggleStyle(HaloToggleStyle())
    }
    @ViewBuilder private var appsOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if quitter {
                section("Layout") {
                    Toggle("Stable app positions", isOn: binding(\.stableQuitterPositions))
                    Text(preferences.stableQuitterPositions
                         ? "Match Launcher directions and remember other apps. Empty slots stay put until the wheel closes."
                         : "Space running apps evenly. Remaining apps rearrange when one quits.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                section("Per-app quit behavior") {
                    Menu(quitAppID.isEmpty ? "Choose app…" : quitAppName(quitAppID)) {
                        ForEach(quitAppIDs, id: \.self) { id in
                            Button(quitAppName(id)) { quitAppID = id }
                        }
                        Divider()
                        Button("Choose another app…", action: chooseQuitApp)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Text("Action")
                        Spacer()
                        Picker("Quit behavior", selection: Binding(
                            get: { preferences.appQuitOverrides[quitAppID].map { $0 ? 2 : 1 } ?? 0 },
                            set: { preferences.appQuitOverrides[quitAppID] = $0 == 0 ? nil : $0 == 2 })) {
                            Text("Use default").tag(0)
                            Text("Quit").tag(1)
                            Text("Force quit").tag(2)
                        }.labelsHidden().frame(width: 160)
                            .disabled(quitAppID.isEmpty || quitAppID == "com.apple.finder")
                    }
                    Text(quitAppID == "com.apple.finder" ? "Finder always closes its windows." : "Default: \(preferences.forceQuitApps ? "Force quit" : "Quit") · Force quit can lose unsaved changes.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                section("Pinned Trash") {
                    Toggle("Show Trash", isOn: binding(\.showsTrash))
                    Toggle("Highlight sector", isOn: binding(\.highlightsTrash)).disabled(!preferences.showsTrash)
                    HStack {
                        Text("Position")
                        Spacer()
                        Picker("Position", selection: binding(\.trashPosition)) {
                            ForEach(TrashPosition.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                        }.labelsHidden().frame(width: 120).disabled(!preferences.showsTrash)
                    }
                }
            } else {
                section("Launcher apps") {
                    Text("\(preferences.launcherTargets.count) of 24 apps").font(.system(size: 14, weight: .medium))
                    Text("Add apps above, then drag their icons around the wheel to choose their positions.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("Hover an icon and click × to remove it from Halo. The app stays on your Mac.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider().opacity(0.4)
                    Button("Reset apps") {
                        if confirmReset("Reset launcher apps?") { preferences.launcherTargets = LauncherTarget.original }
                    }.buttonStyle(.borderless).font(.caption)
                }
            }
        }
    }
    private func tintBinding(_ key: WritableKeyPath<HaloPreferences, HaloTint>) -> Binding<Color> {
        Binding(get: { preferences[keyPath: key].color }, set: { preferences[keyPath: key] = HaloTint($0) })
    }
    private var quitAppIDs: [String] {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier)
        return Set(running + Array(preferences.appQuitOverrides.keys) + (quitAppID.isEmpty ? [] : [quitAppID]))
            .sorted { quitAppName($0).localizedStandardCompare(quitAppName($1)) == .orderedAscending }
    }
    private func quitAppName(_ id: String) -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == id }), let name = app.localizedName { return name }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id
    }
    private func chooseQuitApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), bundle.executableURL != nil,
              let id = bundle.bundleIdentifier else { return }
        quitAppID = id
    }
    private func confirmReset(_ title: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "This replaces your custom choices with the defaults."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset")
        return alert.runModal() == .alertSecondButtonReturn
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }
    private func tick() {
        if preferences.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
    }
    private var reachLabel: String { preferences.maximumSelectionDistance.map { "\(Int($0)) pt" } ?? "Unlimited" }
    private var wheelPicker: some View {
        WheelModeSwitch(quitter: $quitter, changed: tick)
    }
    private var previewHapticsControl: some View {
        HStack(spacing: 6) {
            Text("Preview haptics").font(.caption).foregroundStyle(.secondary)
            WheelModeSwitch(quitter: binding(\.previewHaptics), labels: ["Off", "On"], controlWidth: 84,
                            accessibilityTitle: "Preview haptics")
        }.fixedSize().help("Feedback for Settings previews only. Actual wheel haptics are controlled in Advanced.")
    }
    private func detentedSlider(_ title: String, value: Binding<Double>, stops: SliderStops, display: String) -> some View {
        Slider(value: Binding(get: { stops.index(for: value.wrappedValue) }, set: { index in
            guard let next = stops.change(from: value.wrappedValue, to: index) else { return }
            value.wrappedValue = next
            tick()
        }), in: 0...Double(stops.values.count - 1), step: 1)
        .accessibilityLabel(title).accessibilityValue(display)
        .background(SliderScroll { direction in
            guard let next = stops.change(from: value.wrappedValue,
                to: stops.index(for: value.wrappedValue) + Double(direction)) else { return }
            value.wrappedValue = next; tick()
        })
    }
    private func sizeControl(_ title: String, value: Binding<Double>, stops: SliderStops) -> some View {
        VStack(spacing: 5) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) pt").monospacedDigit().foregroundStyle(.secondary) }
            detentedSlider(title, value: value, stops: stops, display: "\(Int(value.wrappedValue)) points")
        }
    }
    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]; panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false; panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.prompt = "Add to Halo"
        guard panel.runModal() == .OK else { return }
        var rejected = 0
        for url in panel.urls {
            guard preferences.launcherTargets.count < 24,
                  url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, bundle.executableURL != nil,
                  !preferences.launcherTargets.contains(where: { ApplicationCatalog.url(for: $0)?.resolvingSymlinksInPath().path == url.resolvingSymlinksInPath().path }) else { rejected += 1; continue }
            let name = url.deletingPathExtension().lastPathComponent
            preferences.launcherTargets.append(.init(id: UUID().uuidString, name: name, bundleIdentifier: id,
                applicationPath: url.path, bookmark: try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)))
        }
        message = rejected > 0 ? "Skipped duplicates, invalid apps, or apps beyond the 24-app limit." : ""
    }
    private func exportPreferences() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Halo-customization.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; try encoder.encode(preferences).write(to:url,options:.atomic); message = "Customization exported." }
        catch { message = error.localizedDescription }
    }
    private func importPreferences() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 1_048_576 else { message = "This configuration is too large."; return }
            let decoded = try JSONDecoder().decode(HaloPreferences.self, from: Data(contentsOf: url))
            guard decoded.isValid else { message = "That configuration contains unsupported values."; return }
            preferences = decoded; message = "Customization imported."
        } catch { message = "Could not import: \(error.localizedDescription)" }
    }
}

@_cdecl("HaloAddCustomizationPage") @MainActor
func addCustomizationPage(_ pointer: UnsafeMutableRawPointer, _ tab: Int) {
    guard let store = HaloAppDelegate.current?.store else { return }
    let parent = Unmanaged<NSView>.fromOpaque(pointer).takeUnretainedValue()
    let page = CustomizationPage(tab: tab, store: store)
    let host = CustomizationHost(rootView: page)
    host.sizingOptions = []; host.safeAreaRegions = []
    host.frame = NSRect(x: 0, y: 46, width: parent.bounds.width, height: parent.bounds.height - 46)
    host.autoresizingMask = [.width, .height]; parent.addSubview(host)
}

private final class CustomizationHost: NSHostingView<CustomizationPage> {
    // Editor gestures belong to the wheel, not to background window dragging.
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
