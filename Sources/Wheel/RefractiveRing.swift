import SwiftUI

/// One continuous contour, not a union of small lenses. Opposite winding
/// preserves the open center and gives the native compositor both boundaries.
struct GlassAnnulus: Shape {
    var thickness: Double
    var animatableData: Double {
        get { thickness }
        set { thickness = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let diameter = min(rect.width, rect.height)
        let outer = CGRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2, width: diameter, height: diameter)
        let inner = outer.insetBy(dx: min(thickness, diameter / 2), dy: min(thickness, diameter / 2))
        var path = Path()
        path.addEllipse(in: outer)
        // Reflect the inner ellipse to reverse its winding, keeping a true
        // circular hole without seams, polygon wedges, or a bitmap mask.
        path.addPath(Path(ellipseIn: inner), transform: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 2 * rect.midX, ty: 0))
        return path
    }
}

struct RefractiveRing: View {
    let diameter: Double
    let thickness: Double
    let finish: WheelGlassFinish
    var amount: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let shape = GlassAnnulus(thickness: thickness)
        let level = min(1, max(0, amount ?? finish.level))
        ZStack {
            // Optical material stays light even when the Settings UI is dark.
            // Keep one stable glass surface: changing opacity does not swap
            // lenses or rebuild a backdrop hierarchy during slider movement.
            // Keep the system blur subtle; a restrained white glaze prevents
            // translucent mode from becoming either a black or white disk.
            // A tiny optical diffusion floor reduces high-frequency grain at
            // clear edges, without resampling the native refractive surface.
            shape.fill(.regularMaterial).opacity(0.025 + 0.195 * pow(level, 1.15))
            shape.fill(Color.white.opacity(0.055 + 0.075 * level))
            Color.clear.glassEffect(.clear, in: shape)
                .opacity(1 - 0.45 * level)
            // Soften only the contour highlight. Filtering the glass itself
            // forces an intermediate layer and can destroy backdrop sampling.
            shape.stroke(.white.opacity(0.035), lineWidth: 1)
                .blur(radius: 0.65)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: level)
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }
}
