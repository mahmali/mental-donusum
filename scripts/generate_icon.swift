#!/usr/bin/env swift
// Mental Dönüşüm uygulama simgesini üretir.
// Çalıştır: swift scripts/generate_icon.swift
//
// NSBitmapImageRep'i doğrudan piksel olarak boyutlandırır — Retina backing scale
// devreye girmez, üretilen PNG tam istenen boyutta olur.

import AppKit

let outputDir = "MentalDonusum/Assets.xcassets/AppIcon.appiconset"
let pixelSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixels)

    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: bitmap)!
    ctx.shouldAntialias = true
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.2237
    let bg = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)

    let top = NSColor(srgbRed: 0.43, green: 0.27, blue: 0.96, alpha: 1.0)
    let mid = NSColor(srgbRed: 0.28, green: 0.30, blue: 0.95, alpha: 1.0)
    let bot = NSColor(srgbRed: 0.13, green: 0.42, blue: 0.92, alpha: 1.0)
    if let gradient = NSGradient(colors: [top, mid, bot]) {
        gradient.draw(in: bg, angle: -75)
    }

    if pixels >= 64 {
        let inset = size * 0.012
        let highlightRect = rect.insetBy(dx: inset, dy: inset)
        let highlightCorner = max(0, corner - inset)
        let highlight = NSBezierPath(roundedRect: highlightRect, xRadius: highlightCorner, yRadius: highlightCorner)
        highlight.lineWidth = max(1, size * 0.006)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        highlight.stroke()
    }

    drawGlyph(size: size)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawGlyph(size: CGFloat) {
    let fontSize = size * 0.40
    let leftAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.white
    ]
    let rightAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.white.withAlphaComponent(0.94)
    ]

    let left = NSAttributedString(string: "A", attributes: leftAttrs)
    let right = NSAttributedString(string: "字", attributes: rightAttrs)

    let leftSize = left.size()
    let rightSize = right.size()

    let arrowWidth = size * 0.18
    let spacing = size * 0.045
    let totalWidth = leftSize.width + spacing + arrowWidth + spacing + rightSize.width
    let startX = (size - totalWidth) / 2
    let baselineY = (size - leftSize.height) / 2 - size * 0.025

    left.draw(at: NSPoint(x: startX, y: baselineY))

    let arrowY = size / 2
    let arrowStartX = startX + leftSize.width + spacing
    let arrowEndX = arrowStartX + arrowWidth

    let arrowPath = NSBezierPath()
    arrowPath.lineWidth = max(2, size * 0.028)
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    NSColor.white.setStroke()
    arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
    arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowY))
    let head = size * 0.055
    arrowPath.move(to: NSPoint(x: arrowEndX - head, y: arrowY + head))
    arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowY))
    arrowPath.line(to: NSPoint(x: arrowEndX - head, y: arrowY - head))
    arrowPath.stroke()

    right.draw(at: NSPoint(x: arrowEndX + spacing, y: baselineY))
}

func savePNG(_ bitmap: NSBitmapImageRep, to path: String) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for pixels in pixelSizes {
    let bitmap = drawIcon(pixels: pixels)
    let path = "\(outputDir)/icon_\(pixels).png"
    do {
        try savePNG(bitmap, to: path)
        print("✔ \(path) (\(pixels)×\(pixels), pixels=\(bitmap.pixelsWide)×\(bitmap.pixelsHigh))")
    } catch {
        print("✗ \(path): \(error.localizedDescription)")
    }
}
