import AppKit
import Foundation

struct IconSpec {
  let filename: String
  let points: Double
  let scale: Int

  var pixels: Int {
    Int((points * Double(scale)).rounded())
  }
}

let defaultOutputPath = "/Users/guoxl/Documents/Playground/DailyBetter/Resources/Assets.xcassets/AppIcon.appiconset"
let outputPath = CommandLine.arguments.dropFirst().first ?? defaultOutputPath
let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)

let specs: [IconSpec] = [
  .init(filename: "iphone-20@2x.png", points: 20, scale: 2),
  .init(filename: "iphone-20@3x.png", points: 20, scale: 3),
  .init(filename: "iphone-29@2x.png", points: 29, scale: 2),
  .init(filename: "iphone-29@3x.png", points: 29, scale: 3),
  .init(filename: "iphone-40@2x.png", points: 40, scale: 2),
  .init(filename: "iphone-40@3x.png", points: 40, scale: 3),
  .init(filename: "iphone-60@2x.png", points: 60, scale: 2),
  .init(filename: "iphone-60@3x.png", points: 60, scale: 3),
  .init(filename: "ipad-20@1x.png", points: 20, scale: 1),
  .init(filename: "ipad-20@2x.png", points: 20, scale: 2),
  .init(filename: "ipad-29@1x.png", points: 29, scale: 1),
  .init(filename: "ipad-29@2x.png", points: 29, scale: 2),
  .init(filename: "ipad-40@1x.png", points: 40, scale: 1),
  .init(filename: "ipad-40@2x.png", points: 40, scale: 2),
  .init(filename: "ipad-76@1x.png", points: 76, scale: 1),
  .init(filename: "ipad-76@2x.png", points: 76, scale: 2),
  .init(filename: "ipad-83.5@2x.png", points: 83.5, scale: 2),
  .init(filename: "marketing-1024@1x.png", points: 1024, scale: 1),
]

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

for spec in specs {
  try autoreleasepool {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

    guard let cgContext = CGContext(
      data: nil,
      width: spec.pixels,
      height: spec.pixels,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: bitmapInfo.rawValue
    ) else {
      throw NSError(domain: "GenerateAppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap"])
    }

    cgContext.interpolationQuality = .high

    let graphicsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    drawIcon(in: CGRect(x: 0, y: 0, width: spec.pixels, height: spec.pixels), context: cgContext)
    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = cgContext.makeImage() else {
      throw NSError(domain: "GenerateAppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to capture image"])
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
      throw NSError(domain: "GenerateAppIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    let fileURL = outputURL.appendingPathComponent(spec.filename)
    try pngData.write(to: fileURL)
    print("Wrote \(fileURL.path)")
  }
}

func drawIcon(in rect: CGRect, context: CGContext) {
  // App Store icons must be fully opaque. Paint an edge-to-edge square first and
  // let the system apply rounded masking when it displays the icon.
  let canvas = rect
  let backgroundPath = NSBezierPath(rect: canvas)

  NSGraphicsContext.saveGraphicsState()

  let gradient = NSGradient(
    colors: [
      NSColor(calibratedRed: 0.97, green: 0.90, blue: 0.77, alpha: 1.0),
      NSColor(calibratedRed: 0.77, green: 0.89, blue: 0.82, alpha: 1.0),
      NSColor(calibratedRed: 0.46, green: 0.70, blue: 0.59, alpha: 1.0),
    ]
  )
  gradient?.draw(in: backgroundPath, angle: -55)

  NSColor.white.withAlphaComponent(0.22).setFill()
  NSBezierPath(
    ovalIn: CGRect(
      x: canvas.maxX - canvas.width * 0.34,
      y: canvas.maxY - canvas.height * 0.28,
      width: canvas.width * 0.30,
      height: canvas.width * 0.30
    )
  ).fill()

  NSColor(calibratedRed: 0.27, green: 0.52, blue: 0.42, alpha: 0.10).setFill()
  NSBezierPath(
    ovalIn: CGRect(
      x: canvas.minX - canvas.width * 0.10,
      y: canvas.minY + canvas.height * 0.02,
      width: canvas.width * 0.42,
      height: canvas.width * 0.42
    )
  ).fill()

  NSGraphicsContext.restoreGraphicsState()

  let badgeRect = CGRect(
    x: canvas.minX + canvas.width * 0.21,
    y: canvas.minY + canvas.height * 0.21,
    width: canvas.width * 0.58,
    height: canvas.height * 0.58
  )

  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -canvas.height * 0.02), blur: canvas.width * 0.05, color: NSColor.black.withAlphaComponent(0.10).cgColor)
  NSColor(calibratedWhite: 1.0, alpha: 0.95).setFill()
  NSBezierPath(ovalIn: badgeRect).fill()
  context.restoreGState()

  NSColor(calibratedRed: 0.78, green: 0.90, blue: 0.84, alpha: 1.0).setFill()
  let baseRect = CGRect(
    x: badgeRect.minX + badgeRect.width * 0.22,
    y: badgeRect.minY + badgeRect.height * 0.27,
    width: badgeRect.width * 0.56,
    height: badgeRect.height * 0.08
  )
  NSBezierPath(roundedRect: baseRect, xRadius: baseRect.height / 2, yRadius: baseRect.height / 2).fill()

  drawSymbol(
    named: "leaf.fill",
    in: CGRect(
      x: badgeRect.midX - badgeRect.width * 0.18,
      y: badgeRect.midY - badgeRect.height * 0.01,
      width: badgeRect.width * 0.36,
      height: badgeRect.height * 0.36
    ),
    pointSize: badgeRect.width * 0.34,
    weight: .regular,
    color: NSColor(calibratedRed: 0.22, green: 0.48, blue: 0.36, alpha: 1.0),
    rotationDegrees: -18,
    context: context
  )

  drawSymbol(
    named: "sparkles",
    in: CGRect(
      x: badgeRect.maxX - badgeRect.width * 0.24,
      y: badgeRect.maxY - badgeRect.height * 0.16,
      width: badgeRect.width * 0.14,
      height: badgeRect.width * 0.14
    ),
    pointSize: badgeRect.width * 0.14,
    weight: .semibold,
    color: NSColor(calibratedRed: 0.37, green: 0.56, blue: 0.45, alpha: 0.80),
    rotationDegrees: 0,
    context: context
  )
}

func drawSymbol(
  named systemName: String,
  in rect: CGRect,
  pointSize: CGFloat,
  weight: NSFont.Weight,
  color: NSColor,
  rotationDegrees: CGFloat,
  context: CGContext
) {
  let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)

  guard
    let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(configuration),
    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
  else {
    return
  }

  context.saveGState()
  context.translateBy(x: rect.midX, y: rect.midY)
  context.rotate(by: rotationDegrees * .pi / 180)

  let drawRect = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
  context.clip(to: drawRect, mask: cgImage)
  context.setFillColor(color.cgColor)
  context.fill(drawRect)
  context.restoreGState()
}
