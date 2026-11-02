import SwiftUI

struct WindowArcView: View {
    @ObservedObject var state: WheelState
    let arc: WindowArc
    @Environment(\.accessibilityReduceTransparency) private var solid
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastIndex = 0

    var body: some View {
        let size = 2 * arc.outer
        let ratio = arc.inner / arc.outer
        let crop = arc.crop
        ZStack {
            ForEach(Array(state.previews.enumerated()), id: \.element.id) { i, preview in
                let angle = arc.center(i)
                let sector = RingSector(start: angle - arc.width / 2, end: angle + arc.width / 2, innerRatio: ratio)
                // Orient the long axis tangent to the wheel while keeping
                // the screenshot upright on the lower half.
                let tangent = atan2(sin(angle + .pi/2), cos(angle + .pi/2))
                let rotation = abs(tangent) > .pi/2 ? tangent - .pi : tangent
                ZStack {
                    if solid { sector.fill(Color(white: 0.18)) }
                    else { WheelGlassSurface(shape: sector, diameter: size, finish: state.glassFinish, amount: state.glassAmount) }
                    Image(decorative: preview.image, scale: 1)
                        .resizable().interpolation(.high).scaledToFill()
                        .frame(width: crop.size.width, height: crop.size.height).clipped()
                        .rotationEffect(.radians(rotation))
                        .offset(x: cos(angle) * crop.radialCenter, y: sin(angle) * crop.radialCenter)
                        .frame(width: size, height: size)
                        .mask(sector)
                        .opacity(solid ? 1 : 0.89)
                    GlassContour(shape: sector)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Window \(i + 1) of \(preview.app.localizedName ?? "app")")
            }
            let target = arc.center(state.previewIndex ?? lastIndex)
            SelectionBand(diameter: size, innerDiameter: 2 * arc.inner, angle: target,
                          before: arc.width / 2, after: arc.width / 2,
                          visible: state.previewIndex != nil, tint: state.selectionTint)
                .opacity(0.65 + 0.35 * (state.glassAmount ?? state.glassFinish.level))
                .animation(reduceMotion ? nil : .spring(response: 0.14, dampingFraction: 0.98, blendDuration: 0.04), value: target)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: state.previewIndex != nil)
        }
        .frame(width: size, height: size)
        .mask(RingSector(start: arc.angle - arc.width * Double(arc.count)/2,
                         end: arc.angle + arc.width * Double(arc.count)/2, innerRatio: ratio))
        .onChange(of: state.previewIndex, initial: true) { _, next in
            if let next { lastIndex = next }
        }
        .transition(.opacity)
    }
}
