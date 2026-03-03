#!/usr/bin/env swift
import AppKit
import Foundation

func renderIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let ctx = NSGraphicsContext.current!.cgContext

        // Solid background — deep indigo, no gradient
        let bg = NSColor(red: 0.22, green: 0.24, blue: 0.66, alpha: 1.0)
        let inset = size * 0.0
        let iconRect = rect.insetBy(dx: inset, dy: inset)
        let cornerRadius = iconRect.width * 0.22

        let bgPath = CGPath(
            roundedRect: iconRect,
            cornerWidth: cornerRadius, cornerHeight: cornerRadius,
            transform: nil
        )
        ctx.setFillColor(bg.cgColor)
        ctx.addPath(bgPath)
        ctx.fillPath()

        // Bell — centered, clean, geometric
        let cx = iconRect.midX
        let cy = iconRect.midY + size * 0.02
        let bellW = size * 0.38
        let bellH = size * 0.34

        ctx.setFillColor(NSColor.white.cgColor)

        // Bell body: a simple rounded trapezoid shape using a bezier path
        let bellPath = CGMutablePath()
        let topW = bellW * 0.36
        let topY = cy + bellH * 0.48
        let botY = cy - bellH * 0.38
        let midY = cy + bellH * 0.05

        // Top dome (semicircle)
        bellPath.addArc(
            center: CGPoint(x: cx, y: topY),
            radius: topW,
            startAngle: 0, endAngle: .pi,
            clockwise: false
        )

        // Left side curve down to bottom
        bellPath.addCurve(
            to: CGPoint(x: cx - bellW * 0.52, y: botY),
            control1: CGPoint(x: cx - topW, y: midY),
            control2: CGPoint(x: cx - bellW * 0.48, y: botY + bellH * 0.12)
        )

        // Bottom bar
        bellPath.addLine(to: CGPoint(x: cx + bellW * 0.52, y: botY))

        // Right side curve up
        bellPath.addCurve(
            to: CGPoint(x: cx + topW, y: topY),
            control1: CGPoint(x: cx + bellW * 0.48, y: botY + bellH * 0.12),
            control2: CGPoint(x: cx + topW, y: midY)
        )

        bellPath.closeSubpath()
        ctx.addPath(bellPath)
        ctx.fillPath()

        // Bottom bar (wider base)
        let barH = size * 0.028
        let barW = bellW * 1.15
        let barY = botY - barH
        let barRect = CGRect(x: cx - barW / 2, y: barY, width: barW, height: barH)
        let barPath = CGPath(
            roundedRect: barRect,
            cornerWidth: barH / 2, cornerHeight: barH / 2,
            transform: nil
        )
        ctx.addPath(barPath)
        ctx.fillPath()

        // Clapper (small circle at bottom)
        let clapperR = size * 0.035
        let clapperY = barY - clapperR * 0.6
        ctx.addArc(
            center: CGPoint(x: cx, y: clapperY),
            radius: clapperR,
            startAngle: 0, endAngle: .pi * 2,
            clockwise: false
        )
        ctx.fillPath()

        return true
    }
}

func savePNG(_ image: NSImage, to url: URL, pixelSize: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift generate-icon.swift <output-directory>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try! FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16",      16),
    ("icon_16@2x",   32),
    ("icon_32",      32),
    ("icon_32@2x",   64),
    ("icon_128",     128),
    ("icon_128@2x",  256),
    ("icon_256",     256),
    ("icon_256@2x",  512),
    ("icon_512",     512),
    ("icon_512@2x",  1024),
]

let icon = renderIcon(size: 1024)

for entry in sizes {
    let url = outputDir.appendingPathComponent("\(entry.name).png")
    savePNG(icon, to: url, pixelSize: entry.pixels)
    print("  \(entry.name).png (\(entry.pixels)px)")
}
print("Done!")
