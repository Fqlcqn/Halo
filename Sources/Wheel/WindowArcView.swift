import SwiftUI

struct WindowArcView: View {
    @ObservedObject var state: WheelState
    let arc: WindowArc
    @Environment(\.accessibilityReduceTransparency) private var solid
    var body: some View {
        let radius = (arc.inner + arc.outer) / 2
        let ratio = arc.inner / arc.outer
        ZStack {
            ForEach(Array(state.previews.enumerated()), id: \.element.id) { i, preview in
                let angle = arc.center(i)
                let sector = RingSector(start: angle - arc.width / 2, end: angle + arc.width / 2, innerRatio: ratio)
                ZStack {
                    if solid {
                        sector.fill(Color(white: 0.18))
                    } else {
                        WheelGlassSurface(shape: sector, diameter: 2 * arc.outer, finish: state.glassFinish, amount: state.glassAmount)
                    }
                    GlassContour(shape: sector)
                    SelectionBand(diameter: 2 * arc.outer, innerDiameter: 2 * arc.inner, angle: angle,
                                  before: arc.width / 2, after: arc.width / 2,
                                  visible: state.previewIndex == i, tint: state.selectionTint)
                        .opacity(0.65 + 0.35 * (state.glassAmount ?? state.glassFinish.level))
                    Image(decorative: preview.image, scale: 1)
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(width: min(radius * arc.width * 0.76, state.geometry.thickness * 1.35),
                               height: state.geometry.thickness * 0.70)
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                        .frame(width: 2 * arc.outer, height: 2 * arc.outer)
                        .mask(sector)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Window \(i + 1) of \(preview.app.localizedName ?? "app")")
            }
        }
        .frame(width: 2 * arc.outer, height: 2 * arc.outer)
        .transition(.opacity.combined(with: .scale(scale: 0.82, anchor: UnitPoint(x: 0.5 + 0.35 * cos(arc.angle), y: 0.5 + 0.35 * sin(arc.angle)))))
    }
}
