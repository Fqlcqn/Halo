import Foundation

@main struct GeometryTests {
    static func main() {
        var checks = 0
        func expect(_ condition: Bool, _ message: String) { precondition(condition, message); checks += 1 }
        let g = WheelGeometry()
        for direction in [-1.0, 1.0] {
            var angle = Double.pi / 2
            for _ in 0..<8 {
                let next = angle + direction * .pi
                let delta = WheelGeometry.selectionDelta(from: angle, to: next, pointer: angle + direction * (.pi / 2 + 0.01))
                expect(abs(delta - direction * .pi) < 0.000001, "Opposite sectors follow pointer clockwise and counterclockwise through repeated full turns")
                angle += delta
            }
        }
        var perApp = HaloPreferences()
        perApp.appQuitOverrides = ["example.editor": false, "example.game": true]
        for global in [false, true] {
            perApp.forceQuitApps = global
            expect(!perApp.shouldForceQuit("example.editor") && perApp.shouldForceQuit("example.game"), "Per-app modes override either global default")
            expect(perApp.shouldForceQuit(nil) == global && perApp.shouldForceQuit("unknown") == global, "Unconfigured apps inherit default")
        }
        expect(try! JSONDecoder().decode(HaloPreferences.self, from: JSONEncoder().encode(perApp)) == perApp, "Per-app rules survive export and relaunch")
        perApp.appQuitOverrides.removeValue(forKey: "example.editor")
        expect(perApp.shouldForceQuit("example.editor"), "Use default removes override")
        for reach in [nil, 100.0, 1200.0] as [Double?] {
            let preview = WheelGeometry(maximumSelectionDistance: reach)
            let size = preview.panelSize
            for point in [CGPoint(x: -1, y: size/2), CGPoint(x: size, y: size/2), CGPoint(x: size/2, y: -1), CGPoint(x: size/2, y: size)] {
                expect(preview.previewIndex(at: point, count: 8) == nil, "Every preview edge stops selection regardless of reach")
            }
            expect(preview.previewIndex(at: CGPoint(x: size/2+90, y: size/2), count: 8) != nil, "Preview selects inside square and configured reach")
        }
        expect(!HaloPreferences().lessAnimation && !HaloPreferences().previewHaptics, "Smooth wheels and quiet previews default independently")
        var pending = PendingQuitTracker()
        pending.begin(101, until: 2)
        pending.begin(102, until: 3)
        expect(pending.active(at: 1) == [101, 102], "Pending quits disappear immediately")
        pending.remove(101)
        expect(pending.active(at: 1) == [102], "Rejected quits immediately return")
        pending.expire(at: 3)
        expect(pending.active(at: 3).isEmpty, "Cancelled or stalled quits return after bounded grace")
        pending.begin(101, until: 4)
        pending.begin(101, until: 6)
        pending.expire(at: 4)
        expect(pending.active(at: 5) == [101], "Earlier expiry cannot erase a newer pending request")
        for diameter in [240.0, 300, 520] {
            for thickness in [36.0, 66, 78] {
                let dense = WheelGeometry(diameter: diameter, thickness: thickness)
                for count in [8, 16, 24] {
                    for index in 0..<count {
                        let offset = dense.offset(index: index, count: count, selected: true)
                        let size = dense.itemSize(count: count)
                        let close = CGPoint(x: dense.panelSize/2 + offset.x + size/2 - 5,
                                            y: dense.panelSize/2 + offset.y - size/2 + 5)
                        expect(dense.editorHit(at: close, count: count, selected: index, lift: 8, active: index) == index, "Visible remove button wins over adjacent sectors")
                    }
                }
            }
        }
        var scroll = ScrollDetents()
        expect(scroll.step(delta: 5, precise: true, momentum: false, time: 0) == 0, "Trackpad jitter accumulates below detent")
        expect(scroll.step(delta: 7, precise: true, momentum: false, time: 0.01) == 1, "Trackpad threshold produces one detent")
        expect(scroll.step(delta: 100, precise: true, momentum: true, time: 0.02) == 0, "Momentum never changes settings")
        expect(scroll.step(delta: -12, precise: true, momentum: false, time: 0.03) == -1, "Reverse scrolling steps down")
        expect(scroll.step(delta: 1, precise: false, momentum: false, time: 1) == 1, "Mouse wheel notch steps once")
        expect(scroll.step(delta: 120, precise: true, momentum: false, time: 2) == 1, "Large event emits one value change and haptic, not a burst")
        for stops in [SliderStops.finish, .diameter, .thickness, .deadZone, .reach] {
            expect(stops.value(at: -1) == stops.values.first && stops.value(at: 999) == stops.values.last, "Slider endpoints clamp")
            var current = stops.values[0]
            var feedbackCount = 0
            for index in stops.values.indices {
                expect(stops.index(for: stops.values[index]) == Double(index), "All stops map to exact slider indices")
                for offset in [0.0, 0.1, 0.3, 0.1, 0.0] {
                    if let next = stops.change(from: current, to: Double(index) + offset) {
                        current = next; feedbackCount += 1
                    }
                }
                expect(current == stops.values[index], "Pointer jitter stays on a single detent")
            }
            expect(feedbackCount == stops.values.count - 1, "Exactly one feedback event per changed stop, no repeats")
            for index in stops.values.indices.reversed() {
                if let next = stops.change(from: current, to: Double(index)) { current = next; feedbackCount += 1 }
            }
            expect(feedbackCount == 2 * (stops.values.count - 1), "Reverse traversal has identical feedback")
        }
        expect(SliderStops.diameter.values.contains(300) && SliderStops.deadZone.values.contains(86), "Defaults are exact detents")
        expect(SliderStops.reach.value(at: 19) == 2000 && SliderStops.reach.value(at: 20) == 2100, "Last finite stop precedes the unlimited sentinel")
        for diameter in SliderStops.diameter.values {
            for thickness in SliderStops.thickness.values {
                let sized = WheelGeometry(diameter: diameter, thickness: thickness)
                expect(abs(sized.iconSize / 58 - thickness / 66) < 0.000001, "Thickness scales icons proportionally")
                expect(abs(sized.iconRadius - (diameter - thickness) / 2) < 0.000001, "Icons stay centered in the ring")
                expect(sized.innerDiameter == diameter - 2 * thickness, "Selection and glass share the inner boundary")
                expect(sized.selectedIndex(dx: 0, dy: sized.iconRadius + 0.001, count: 8) == 0, "Icon centers remain selectable on thick small wheels")
            }
        }
        expect(g.iconSize == 58 && g.padding == 4 && g.thickness == 66, "Reference icon and ring dimensions")
        expect(g.innerDiameter == 168 && g.iconRadius == 117 && g.panelSize == 356, "Reference wheel geometry")
        expect(WheelGeometry(diameter: -1).diameter == 240 && WheelGeometry(diameter: 999).diameter == 520, "Diameter clamps")
        expect(WheelGeometry(diameter: .nan).diameter == 300, "Nonfinite diameter")
        expect(WheelGeometry(selectionDistance: 1000).selectionDistance == 86, "Legacy selection-distance clamp")
        expect(g.selectedIndex(dx: 0, dy: 0, count: 8) == nil, "Center cancels")
        expect(g.selectedIndex(dx: 0, dy: 85.999, count: 8) == nil, "Dead zone edge")
        expect(g.selectedIndex(dx: 0, dy: 86, count: 8) == 0, "Dead zone inclusive boundary")
        expect(g.selectedIndex(dx: 0, dy: 1000, count: 8) == 0, "Selection extends beyond ring")
        expect(g.selectedIndex(dx: 0, dy: 100000, count: 8) == 0, "Unlimited selection has no outer cutoff")
        let bounded = WheelGeometry(maximumSelectionDistance: 200)
        expect(bounded.selectedIndex(dx: 0, dy: 200, count: 8) == 0, "Outer boundary is inclusive")
        expect(bounded.selectedIndex(dx: 0, dy: 200.01, count: 8) == nil, "Beyond finite distance selects nothing")
        expect(g.iconLift(distance: 86, dynamic: true) == 0, "Dynamic lift starts at zero")
        expect(g.iconLift(distance: 118, dynamic: true) == 4, "Pointer radius continuously controls lift")
        expect(g.iconLift(distance: 150, dynamic: true) == 8 && g.iconLift(distance: 10000, dynamic: true) == 8, "Lift caps at original maximum")
        expect(g.iconLift(distance: 90, dynamic: false) == 8, "Toggle off preserves original lift")
        for radius in stride(from: 86.0, through: 150.0, by: 0.25) {
            expect(g.iconLift(distance: radius, dynamic: true) <= g.iconLift(distance: radius+0.25, dynamic: true), "Dynamic lift is monotonic")
        }
        expect(g.selectedIndex(dx: .infinity, dy: 0, count: 8) == nil, "Invalid pointer")
        expect(g.selectedIndex(dx: 0, dy: 100, count: 0) == nil, "Empty launcher")
        for quitter in [false, true] {
            let geometry = WheelGeometry(quitter: quitter)
            for count in 1...64 {
                for index in 0..<count {
                    for adjustment in [-0.49, 0, 0.49] {
                        let angle = geometry.angle(index: index, count: count) + adjustment * 2 * .pi / Double(count)
                        let selected = geometry.selectedIndex(dx: cos(angle)*200, dy: -sin(angle)*200, count: count)
                        expect(selected == index, "Every sector maps correctly, including angular wrap")
                    }
                    let p = geometry.offset(index: index, count: count, selected: true)
                    expect(abs(hypot(p.x,p.y)-125) < 0.00001, "Selected icon lifts eight points")
                }
            }
        }
        let quitter = WheelGeometry(quitter: true)
        expect(g.itemSize(count: 8) == 58 && g.itemSize(count: 24) < 26, "Dense wheels fit icons without changing eight-app sizing")
        for position in TrashPosition.allCases {
            let pinned = WheelGeometry(quitter: true, trashPosition: position)
            expect(pinned.selectedIndex(dx: cos(position.angle)*120, dy: -sin(position.angle)*120, count: 8) == 0, "Pinned Trash hit testing follows its position")
        }
        var order = LauncherTarget.original
        let movedID = order[0].id
        LauncherTarget.move(movedID, to: 7, in: &order)
        expect(order[7].id == movedID && order[0].id == LauncherTarget.original[1].id, "Dragging inserts and shifts neighbors")
        order.remove(at: 2)
        LauncherTarget.move(movedID, to: 0, in: &order)
        expect(order[0].id == movedID && Set(order.map(\.id)).count == 7, "Reorder after removal preserves identities")
        expect(quitter.selectedIndex(dx: 0, dy: -100, count: 6) == 0, "Trash remains anchored at bottom")
        expect(quitter.selectedIndex(dx: 0, dy: 100, count: 6) == 3, "Quitter top matches video")
        expect(abs(WheelGeometry.shortestDelta(from: .pi-0.1, to: -.pi+0.1)-0.2) < 0.00001, "Highlight crosses seam via shortest path")
        let domain = "Halo.Rebuild.GeometryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:domain)!
        defer { defaults.removePersistentDomain(forName:domain) }
        let store = PreferenceStore(defaults:defaults)
        for force in [false, true] {
            expect(QuitDisposition.resolve(bundleIdentifier: "com.apple.finder", force: force) == .closeFinderWindows, "Finder never terminates in either quit mode")
            expect(QuitDisposition.resolve(bundleIdentifier: "example.editor", force: force) == (force ? .force : .normal), "Other apps honor quit mode")
            expect(QuitDisposition.resolve(bundleIdentifier: nil, force: force) == (force ? .force : .normal), "Unknown bundle honors quit mode")
        }
        var tinted = HaloPreferences()
        tinted.settingsTint = HaloTint(red: 0.5, green: 0.2, blue: 1)
        tinted.selectionTint = HaloTint(red: 1, green: 0.4, blue: 0.1)
        tinted.forceQuitApps = false
        expect(store.save(tinted), "Tint and normal quit save synchronously")
        expect(PreferenceStore(defaults: UserDefaults(suiteName: domain)!).value == tinted, "Fresh defaults read sees saved tint and quit mode immediately")
        var tintLegacy = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(tinted)) as! [String: Any]
        for key in ["settingsTint", "selectionTint", "forceQuitApps"] { tintLegacy.removeValue(forKey: key) }
        let migratedTint = try! JSONDecoder().decode(HaloPreferences.self, from: JSONSerialization.data(withJSONObject: tintLegacy))
        expect(migratedTint.settingsTint == .white && migratedTint.selectionTint == .white && !migratedTint.forceQuitApps, "Legacy configuration adopts safe regular-quit default")
        var v1ForceQuit = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(tinted)) as! [String: Any]
        v1ForceQuit["version"] = 1
        v1ForceQuit["forceQuitApps"] = true
        v1ForceQuit["appQuitOverrides"] = ["example.game": true]
        let migratedV1 = try! JSONDecoder().decode(HaloPreferences.self, from: JSONSerialization.data(withJSONObject: v1ForceQuit))
        expect(!migratedV1.forceQuitApps && migratedV1.shouldForceQuit("example.game") && !migratedV1.shouldForceQuit("unknown"), "Version 1 force-quit default migrates while explicit per-app rule remains")
        tinted.settingsTint.red = -0.01
        expect(!store.save(tinted), "Invalid settings tint rejected")
        tinted.settingsTint = .white; tinted.selectionTint.blue = .nan
        expect(!store.save(tinted), "Invalid selection tint rejected")
        let finitePreview = WheelGeometry(diameter: 300, selectionDistance: 86, maximumSelectionDistance: 1200)
        expect(finitePreview.selectedIndex(dx: 1199, dy: 0, count: 8) != nil, "Finite preview selects beyond its visible bounds")
        expect(finitePreview.selectedIndex(dx: 1201, dy: 0, count: 8) == nil, "Finite preview stops at configured reach")
        for finish in WheelGlassFinish.allCases {
            var legacyFinish = HaloPreferences(); legacyFinish.glassFinish = finish
            var json = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(legacyFinish)) as! [String: Any]
            json.removeValue(forKey: "wheelThickness"); json.removeValue(forKey: "glassAmount")
            let migrated = try! JSONDecoder().decode(HaloPreferences.self, from: JSONSerialization.data(withJSONObject: json))
            expect(migrated.wheelThickness == 66 && migrated.glassLevel == finish.level, "Old glass presets and thickness migrate without data loss")
        }
        for level in SliderStops.finish.values {
            var custom = HaloPreferences(); custom.glassLevel = level; custom.wheelThickness = 48
            expect(store.save(custom) && PreferenceStore(defaults: defaults).value == custom, "Every finish stop and thickness persist")
        }
        var invalid = HaloPreferences(); invalid.glassAmount = 1.1
        expect(!store.save(invalid), "Out-of-range glass is rejected")
        invalid = HaloPreferences(); invalid.wheelThickness = 79
        expect(!store.save(invalid), "Out-of-range thickness is rejected")
        _ = store.save(HaloPreferences())
        expect(store.value == HaloPreferences(), "Clean install defaults")
        expect(store.value.glassFinish == .standard, "Existing glass is the default")
        for finish in WheelGlassFinish.allCases {
            var setting = HaloPreferences(); setting.glassFinish = finish
            expect(store.save(setting) && PreferenceStore(defaults: defaults).value.glassFinish == finish, "All glass presets survive relaunch")
        }
        _ = store.save(HaloPreferences())
        var preferences = store.value
        preferences.launcherDiameter = 412; preferences.launcherTargets.reverse()
        expect(store.save(preferences), "Settings save")
        expect(PreferenceStore(defaults:defaults).value == preferences, "Settings survive relaunch")
        var variants = preferences
        variants.launcherTargets = [
            .init(id: "copy-a", name: "Variant A", bundleIdentifier: "example.app", applicationPath: "/Applications/A.app"),
            .init(id: "copy-b", name: "Variant B", bundleIdentifier: "example.app", applicationPath: "/Applications/B.app")
        ]
        variants.showsTrash = false; variants.highlightsTrash = false; variants.trashPosition = .right
        expect(store.save(variants) && PreferenceStore(defaults: defaults).value == variants, "Explicit variants and Trash options round-trip")
        variants.launcherTargets[0].applicationPath = "/tmp/not-an-app.txt"
        expect(!store.save(variants), "Non-app explicit paths are rejected")
        _ = store.save(preferences)
        let oldData = try! JSONEncoder().encode(preferences)
        var legacy = try! JSONSerialization.jsonObject(with: oldData) as! [String: Any]
        legacy.removeValue(forKey: "maximumSelectionDistance"); legacy.removeValue(forKey: "dynamicIconMovement")
        legacy.removeValue(forKey: "glassFinish")
        legacy.removeValue(forKey: "lessAnimation"); legacy.removeValue(forKey: "previewHaptics")
        legacy.removeValue(forKey: "appQuitOverrides")
        defaults.set(try! JSONSerialization.data(withJSONObject: legacy), forKey: PreferenceStore.key)
        expect(PreferenceStore(defaults: defaults).value == preferences, "Old settings migrate without losing customization")
        preferences.appQuitOverrides = ["example.editor": false, "example.game": true]
        expect(store.save(preferences) && PreferenceStore(defaults: defaults).value == preferences, "Per-app rules persist immediately to a fresh store")
        preferences.lessAnimation = true; preferences.previewHaptics = true; preferences.haptics = false
        expect(store.save(preferences) && PreferenceStore(defaults: defaults).value == preferences, "Animation and independent preview feedback survive relaunch")
        preferences.maximumSelectionDistance = 320; preferences.dynamicIconMovement = true
        expect(store.save(preferences) && PreferenceStore(defaults: defaults).value == preferences, "Distance and movement toggle persist")
        preferences.maximumSelectionDistance = nil
        expect(store.save(preferences) && PreferenceStore(defaults: defaults).value == preferences, "Infinity exports and persists as JSON-safe unlimited")
        preferences.maximumSelectionDistance = .infinity
        expect(!store.save(preferences), "Non-JSON numeric infinity is rejected")
        preferences.maximumSelectionDistance = nil
        preferences.launcherTargets.append(preferences.launcherTargets[0])
        expect(!store.save(preferences), "Duplicate app rejected")
        defaults.set(Data("broken".utf8),forKey:PreferenceStore.key)
        let recovered = PreferenceStore(defaults:defaults)
        expect(recovered.value == HaloPreferences(), "Corrupt settings fallback")
        expect(defaults.data(forKey:PreferenceStore.key+".recovery") == Data("broken".utf8), "Corrupt data preserved")
        print("PASS: \(checks) geometry, selection, layout, and persistence checks")
    }
}
