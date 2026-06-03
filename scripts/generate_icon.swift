#!/usr/bin/env swift
// Mental Dönüşüm uygulama simgesini üretir.
// Çalıştır: swift scripts/generate_icon.swift
// Üretilenler: MentalDonusum/Assets.xcassets/AppIcon.appiconset/*.png

import AppKit
import CoreText

let outputDir = "MentalDonusum/Assets.xcassets/AppIcon.appiconset"

let pixelSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

func makeIcon(pixels: Int) -> NSImage {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.2237
    let bg = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)

    let top = NSColor(srgbRed: 0.43, green: 0.27, blue: 0.96, alpha: 1.0)
    let mid = NSColor(srgbRed: 0.28, green: 0.30, blue: 0.95, alpha: 1.0)
    let bottom = NSColor(srgbRed: 0.13, green: 0.42, blue: 0.92, alpha: 1.0)
    if let gradient = NSGradient(colors: [top, mid, bottom]) {
        gradient.draw(in: bg, angle: -75)
    }

    // Inner subtle highlight ring (only at large sizes)
    if pixels >= 64 {
        let inset = size * 0.012
        let highlightRect = rect.insetBy(dx: inset, dy: inset)
        let highlightCorner = max(0, corner - inset)
        let highlight = NSBezierPath(roundedRect: highlightRect, xRadius: highlightCorner, yRadius: highlightCorner)
        highlight.lineWidth = max(1, size * 0.006)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        highlight.stroke()
    }

    // "Aa" + arrow + "Bb" composition (translator look)
    drawTranslatorGlyph(size: size)

    image.unlockFocus()
    return image
}

func drawTranslatorGlyph(size: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.40, weight: .heavy),
        .foregroundColor: NSColor.white,
        .kern: -size * 0.012
    ]
    let leftAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.40, weight: .heavy),
        .foregroundColor: NSColor.white,
    ]
    let rightAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.40, weight: .heavy),
        .foregroundColor: NSColor.white.withAlphaComponent(0.92),
    ]

    let left = NSAttributedString(string: "A", attributes: leftAttrs)
    let right = NSAttributedString(string: "字", attributes: rightAttrs)
    _ = attrs

    let leftSize = left.size()
    let rightSize = right.size()

    let arrowWidth = size * 0.18
    let spacing = size * 0.04
    let totalWidth = leftSize.width + spacing + arrowWidth + spacing + rightSize.width

    let startX = (size - totalWidth) / 2
    let baselineY = (size - leftSize.height) / 2 - size * 0.02

    left.draw(at: NSPoint(x: startX, y: baselineY))

    // Arrow in the middle
    let arrowY = size / 2
    let arrowStartX = startX + leftSize.width + spacing
    let arrowEndX = arrowStartX + arrowWidth

    let arrowPath = NSBezierPath()
    arrowPath.lineWidth = max(2, size * 0.024)
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    NSColor.white.setStroke()
    arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
    arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowY))
    let head = size * 0.05
    arrowPath.move(to: NSPoint(x: arrowEndX - head, y: arrowY + head))
    arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowY))
    arrowPath.line(to: NSPoint(x: arrowEndX - head, y: arrowY - head))
    arrowPath.stroke()

    right.draw(at: NSPoint(x: arrowEndX + spacing, y: baselineY))
}

func savePNG(_ image: NSImage, to path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
        throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "tiff rep oluşturulamadı"])
    }
    // Pixel boyutunu kesinleştir (HiDPI'den etkilenmesin)
    rep.size = NSSize(width: image.size.width, height: image.size.height)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 2)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for pixels in pixelSizes {
    let image = makeIcon(pixels: pixels)
    let path = "\(outputDir)/icon_\(pixels).png"
    do {
        try savePNG(image, to: path)
        print("✔ \(path) (\(pixels)×\(pixels))")
    } catch {
        print("✗ \(path): \(error.localizedDescription)")
    }
}

print("Tamam. Şimdi Contents.json'u güncelleyin (zaten güncelse atlanır).")
