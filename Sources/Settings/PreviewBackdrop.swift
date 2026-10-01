import SwiftUI

/// Local, static test patterns beneath the same glass renderer as the live wheel.
struct PreviewBackdrop: View {
    enum Style: String, CaseIterable { case color = "Color", text = "Text", grid = "Grid" }
    let style: Style
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch style {
                case .color:
                    LinearGradient(colors: [.cyan, .indigo, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.mint).frame(width: 230).blur(radius: 24).offset(x: -90, y: 80)
                    Circle().fill(.orange).frame(width: 210).blur(radius: 18).offset(x: 120, y: -130)
                case .text:
                    Color(white: 0.94)
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(0..<12) { row in
                            Text(row.isMultiple(of: 3) ? "Halo · A clearer perspective" : "Light, texture, detail. 0123456789")
                                .font(.system(size: 17, weight: row.isMultiple(of: 3) ? .semibold : .regular))
                                .foregroundStyle(Color(white: 0.16)).lineLimit(1)
                        }
                    }.padding(12)
                case .grid:
                    Color(white: 0.88)
                    Canvas { context, size in
                        var grid = Path()
                        for x in stride(from: 0.0, through: size.width, by: 20) {
                            grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: 0.0, through: size.height, by: 20) {
                            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(grid, with: .color(.gray.opacity(0.5)), lineWidth: 1)
                        var diagonal = Path()
                        diagonal.move(to: .zero); diagonal.addLine(to: CGPoint(x: size.width, y: size.height))
                        context.stroke(diagonal, with: .color(.indigo.opacity(0.7)), lineWidth: 14)
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
}
