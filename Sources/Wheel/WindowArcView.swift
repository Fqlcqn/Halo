import SwiftUI

// Trim the four corners along the annular contours, keeping each cell
// centered on the exact angle used by pointer hit testing.
private struct PreviewSector: Shape {
    let angle: Double, width: Double, inner: Double, outer: Double
    func path(in rect: CGRect) -> Path {
        let start = angle - width / 2, end = angle + width / 2
        let r = min(3.5, inner * width / 5)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        func point(_ radius: Double, _ a: Double) -> CGPoint {
            CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
        }
        var path = Path()
        path.move(to: point(outer, start + r / outer))
        path.addArc(center: center, radius: outer, startAngle: .radians(start + r / outer), endAngle: .radians(end - r / outer), clockwise: false)
        path.addQuadCurve(to: point(outer - r, end), control: point(outer, end))
        path.addLine(to: point(inner + r, end))
        path.addQuadCurve(to: point(inner, end - r / inner), control: point(inner, end))
        path.addArc(center: center, radius: inner, startAngle: .radians(end - r / inner), endAngle: .radians(start + r / inner), clockwise: true)
        path.addQuadCurve(to: point(inner + r, start), control: point(inner, start))
        path.addLine(to: point(outer - r, start))
        path.addQuadCurve(to: point(outer, start + r / outer), control: point(outer, start))
        path.closeSubpath()
        return path
    }
}

private struct ArcReveal: AnimatableModifier {
    let arc: WindowArc
    nonisolated var progress: Double
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let p = min(1, max(0, progress))
        let radius = arc.inner + (arc.outer - arc.inner) * p
        let span = arc.width * (0.25 + (Double(arc.count) - 0.25) * p)
        let center = arc.appAngle + (arc.angle - arc.appAngle) * p
        content.mask(RingSector(start: center - span/2, end: center + span/2, innerRatio: arc.inner / radius)
            .frame(width: 2 * radius, height: 2 * radius))
            .opacity(min(1, 3 * p))
    }
}

struct WindowArcView: View {
    let previews: [WindowPreview]
    let previewIndex: Int?
    let finish: WheelGlassFinish
    let amount: Double?
    let tint: HaloTint
    let arc: WindowArc
    @Environment(\.accessibilityReduceTransparency) private var solid
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectionAngle: Double?

    var body: some View {
        let size = 2 * arc.outer
        let ratio = arc.inner / arc.outer
        let crop = arc.crop
        ZStack {
            ForEach(Array(previews.enumerated()), id: \.element.id) { i, preview in
                let angle = arc.center(i)
                let sector = PreviewSector(angle: angle, width: arc.width, inner: arc.inner, outer: arc.outer)
                let imageMask = PreviewSector(angle: angle, width: max(arc.width * 0.85, arc.width - 2.4 / arc.inner),
                                              inner: arc.inner + 1.2, outer: arc.outer - 1.2)
                // Orient the long axis tangent to the wheel while keeping
                // the screenshot upright on the lower half.
                let tangent = atan2(sin(angle + .pi/2), cos(angle + .pi/2))
                let rotation = abs(tangent) > .pi/2 ? tangent - .pi : tangent
                ZStack {
                    if solid { sector.fill(Color(white: 0.18)) }
                    else { WheelGlassSurface(shape: sector, diameter: size, finish: finish, amount: amount) }
                    Image(decorative: preview.image, scale: 1)
                        .resizable().interpolation(.high).scaledToFill()
                        .frame(width: crop.size.width, height: crop.size.height).clipped()
                        .rotationEffect(.radians(rotation))
                        .offset(x: cos(angle) * crop.radialCenter, y: sin(angle) * crop.radialCenter)
                        .frame(width: size, height: size)
                        .mask(imageMask)
                        .opacity(solid ? 1 : 0.89)
                    GlassContour(shape: sector)
                    imageMask.stroke(.black.opacity(0.18), lineWidth: 0.65)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Window \(i + 1) of \(preview.app.localizedName ?? "app")")
            }
            let target = selectionAngle ?? arc.center(previewIndex ?? 0)
            SelectionBand(diameter: size, innerDiameter: 2 * arc.inner, angle: target,
                          before: arc.width / 2, after: arc.width / 2,
                          visible: previewIndex != nil, tint: tint)
                .mask(ZStack {
                    ForEach(0..<arc.count, id: \.self) { i in
                        PreviewSector(angle: arc.center(i), width: arc.width, inner: arc.inner, outer: arc.outer)
                    }
                })
                .opacity(0.65 + 0.35 * (amount ?? finish.level))
                .animation(reduceMotion ? nil : .spring(response: 0.14, dampingFraction: 0.98, blendDuration: 0.04), value: target)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: previewIndex != nil)
        }
        .frame(width: size, height: size)
        .mask(RingSector(start: arc.angle - arc.width * Double(arc.count)/2,
                         end: arc.angle + arc.width * Double(arc.count)/2, innerRatio: ratio))
        .onChange(of: previewIndex, initial: true) { _, next in
            if let next { selectionAngle = arc.highlightAngle(for: next, from: selectionAngle) }
        }
        .transition(.modifier(active: ArcReveal(arc: arc, progress: 0), identity: ArcReveal(arc: arc, progress: 1)))
    }
}
