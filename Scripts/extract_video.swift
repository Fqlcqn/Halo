import AppKit
import AVFoundation

@main struct ExtractVideo {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else { fatalError("Usage: extract_video video output-directory [interval]") }
        let url = URL(fileURLWithPath: args[1])
        let output = URL(fileURLWithPath: args[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let interval = args.count > 3 ? Double(args[3])! : 0.5
        var frames: [(Double, CGImage)] = []
        for time in stride(from: 0.0, to: duration, by: interval) {
            let result = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
            frames.append((time, result.image))
            let bitmap = NSBitmapImageRep(cgImage: result.image)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(String(format: "%06.2f.png", time)))
        }
        print("duration=\(duration) frames=\(frames.count) dimensions=\(frames[0].1.width)x\(frames[0].1.height)")
        for offset in stride(from: 0, to: frames.count, by: 24) {
            let batch = Array(frames.dropFirst(offset).prefix(24))
            let width = 400.0, height = 260.0
            let sheet = NSImage(size: NSSize(width: width*4, height: height*Double((batch.count+3)/4)))
            sheet.lockFocus()
            NSColor.darkGray.setFill(); NSRect(origin: .zero, size: sheet.size).fill()
            for (i, frame) in batch.enumerated() {
                let rect = NSRect(x: Double(i%4)*width, y: sheet.size.height-Double(i/4+1)*height, width: width, height: height)
                let image = NSImage(cgImage: frame.1, size: .zero)
                let scale = min(width/image.size.width,(height-22)/image.size.height)
                image.draw(in: NSRect(x: rect.minX, y: rect.minY+22, width:image.size.width*scale,height:image.size.height*scale))
                (String(format: "%.2fs",frame.0) as NSString).draw(at: rect.origin, withAttributes:[.foregroundColor:NSColor.white,.font:NSFont.monospacedDigitSystemFont(ofSize:16,weight:.medium)])
            }
            sheet.unlockFocus()
            let bitmap = NSBitmapImageRep(data:sheet.tiffRepresentation!)!
            try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("sheet-\(offset/24).png"))
        }
    }
}
