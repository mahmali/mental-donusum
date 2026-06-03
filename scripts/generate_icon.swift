#!/usr/bin/env swift
// Mental Dönüşüm uygulama simgesini üretir.
// Tasarım: koyu indigo squircle arka plan, tek beyaz konuşma balonu
// silueti (sol-alt kuyrukla), içinde iki zıt yönlü ok = çift yönlü çeviri.
//
// Çalıştır: swift scripts/generate_icon.swift

import AppKit

let outputDir = "MentalDonusum/Assets.xcassets/AppIcon.appiconset"
let pixelSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

func makeBitmap(_ pixels: Int) -> NSBitmapImageRep {
    let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    bmp.size = NSSize(width: pixels, height: pixels)
    return bmp
}

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let bmp = makeBitmap(pixels)
    let s = CGFloat(pixels)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let ctx = NSGraphicsContext(bitmapImageRep: bmp)!
    ctx.shouldAntialias = true
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx

    // ---- Arka plan: squircle, koyu indigo ----
    let bg = NSColor(srgbRed: 0.16, green: 0.13, blue: 0.42, alpha: 1.0)
    let bgRect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.2237
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)
    bg.setFill()
    bgPath.fill()

    // ---- Konuşma balonu (beyaz) ----
    // Daha küçük boyutlarda detayları korumak için biraz büyütüyoruz.
    let scale: CGFloat = pixels <= 32 ? 0.72 : 0.62
    let bw = s * scale
    let bh = s * (scale * 0.81)
    let bx = (s - bw) / 2
    let by = (s - bh) / 2 + s * 0.04
    let br = bh * 0.30

    let bubble = NSBezierPath(roundedRect: NSRect(x: bx, y: by, width: bw, height: bh),
                              xRadius: br, yRadius: br)

    // Kuyruk: sol-alt köşede üçgen
    let tail = NSBezierPath()
    let tx = bx + bw * 0.22
    tail.move(to: NSPoint(x: tx, y: by + 1))
    tail.line(to: NSPoint(x: tx - bh * 0.18, y: by - bh * 0.24))
    tail.line(to: NSPoint(x: tx + bh * 0.22, y: by + 1))
    tail.close()
    bubble.append(tail)
    bubble.windingRule = .nonZero

    NSColor.white.setFill()
    bubble.fill()

    // ---- İçeriği çiz (16/32 boyutlarda detay kaybı için atla) ----
    guard pixels >= 48 else { return bmp }

    let lineW = max(1.5, s * 0.030)
    let arrowLen = bw * 0.36
    let cx = bx + bw / 2
    let topY = by + bh * 0.62
    let botY = by + bh * 0.34
    let headSize = lineW * 1.6

    bg.setStroke()

    // Üst ok: → (sağa)
    let p1 = NSBezierPath()
    p1.lineWidth = lineW; p1.lineCapStyle = .round; p1.lineJoinStyle = .round
    p1.move(to: NSPoint(x: cx - arrowLen / 2, y: topY))
    p1.line(to: NSPoint(x: cx + arrowLen / 2, y: topY))
    p1.move(to: NSPoint(x: cx + arrowLen / 2 - headSize, y: topY + headSize))
    p1.line(to: NSPoint(x: cx + arrowLen / 2, y: topY))
    p1.line(to: NSPoint(x: cx + arrowLen / 2 - headSize, y: topY - headSize))
    p1.stroke()

    // Alt ok: ← (sola)
    let p2 = NSBezierPath()
    p2.lineWidth = lineW; p2.lineCapStyle = .round; p2.lineJoinStyle = .round
    p2.move(to: NSPoint(x: cx - arrowLen / 2, y: botY))
    p2.line(to: NSPoint(x: cx + arrowLen / 2, y: botY))
    p2.move(to: NSPoint(x: cx - arrowLen / 2 + headSize, y: botY + headSize))
    p2.line(to: NSPoint(x: cx - arrowLen / 2, y: botY))
    p2.line(to: NSPoint(x: cx - arrowLen / 2 + headSize, y: botY - headSize))
    p2.stroke()

    return bmp
}

func savePNG(_ bmp: NSBitmapImageRep, to path: String) throws {
    guard let data = bmp.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try data.write(to: URL(fileURLWithPath: path))
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for pixels in pixelSizes {
    let bmp = drawIcon(pixels: pixels)
    let path = "\(outputDir)/icon_\(pixels).png"
    do {
        try savePNG(bmp, to: path)
        print("✔ \(path)  (\(bmp.pixelsWide)×\(bmp.pixelsHigh))")
    } catch {
        print("✗ \(path): \(error.localizedDescription)")
    }
}
