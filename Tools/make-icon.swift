#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Zeichnet das App-Symbol und legt daraus ein .icns an.
//
// Die Bildmarke ist die Kernaussage des Werkzeugs in einem Bild: drei Balken
// (Verbrauch) und eine harte Linie darüber (die Grenze). Der dritte Balken
// stößt an — was darüber liegt, bleibt als Geist stehen. Genau das macht die
// App: sie zeigt den Verbrauch und kappt ihn.
//
// Gezeichnet statt aus einer SVG konvertiert, weil macOS ohne Zusatzwerkzeug
// keine SVG rastern kann und eine weitere Abhängigkeit den Bau erschweren würde.

let size: CGFloat = 1024

func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha)
}

let ink = hex(0x0B1524)
let inkDeep = hex(0x050B14)
let green = hex(0x3DDC97)
let amber = hex(0xFFB020)
let red = hex(0xFF5F56)
let chalk = hex(0xF7FAFC)

func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func draw(into ctx: CGContext, scale: CGFloat, withBackground: Bool) {
    ctx.saveGState()
    ctx.scaleBy(x: scale, y: scale)

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)

    if withBackground {
        // Grundfläche: macOS-typischer Radius, dunkler Verlauf von oben.
        let plate = roundedPath(canvas.insetBy(dx: 0, dy: 0), size * 0.2237)
        ctx.saveGState()
        ctx.addPath(plate)
        ctx.clip()

        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [hex(0x16263F), ink, inkDeep] as CFArray,
                                  locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: size * 0.12, y: size),
                               end: CGPoint(x: size * 0.7, y: 0),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        // Schwacher Lichtschein hinter den Balken — gibt Tiefe, ohne zu glänzen.
        let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [hex(0x3DDC97, 0.20), hex(0x3DDC97, 0)] as CFArray,
                              locations: [0, 1])!
        ctx.drawRadialGradient(glow,
                               startCenter: CGPoint(x: size * 0.5, y: size * 0.34),
                               startRadius: 0,
                               endCenter: CGPoint(x: size * 0.5, y: size * 0.34),
                               endRadius: size * 0.52,
                               options: [])
        ctx.restoreGState()
    }

    // Balken: Verbrauch, von klein nach groß.
    let barWidth: CGFloat = 120
    let radius = barWidth / 2
    let baseline: CGFloat = 236
    let limitY: CGFloat = 654
    let cut = limitY - 24          // hier stoßen die Balken an die Grenze
    let columns: [(x: CGFloat, height: CGFloat, color: CGColor)] = [
        (288, 222, green),
        (452, 344, amber),
        (616, 574, red),
    ]

    for column in columns {
        let top = baseline + column.height
        let visibleHeight = min(top, cut) - baseline

        // Der Teil oberhalb der Grenze bleibt als Umriss stehen: Das ist der
        // Verbrauch, der nicht mehr stattfindet — sichtbar, aber nicht gezählt.
        if top > cut {
            let ghost = CGRect(x: column.x, y: baseline,
                               width: barWidth, height: top - baseline)
            ctx.saveGState()
            ctx.addPath(roundedPath(ghost, radius))
            ctx.setStrokeColor(hex(0xFF5F56, 0.28))
            ctx.setLineWidth(10)
            ctx.strokePath()
            ctx.restoreGState()
        }

        let bar = CGRect(x: column.x, y: baseline, width: barWidth, height: visibleHeight)
        ctx.addPath(roundedPath(bar, radius))
        ctx.setFillColor(column.color)
        ctx.fillPath()
    }

    // Die Grenze: eine Linie, die nicht verhandelbar aussieht.
    let lineRect = CGRect(x: 208, y: limitY - 14, width: size - 416, height: 28)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 26, color: hex(0xF7FAFC, 0.45))
    ctx.addPath(roundedPath(lineRect, 14))
    ctx.setFillColor(chalk)
    ctx.fillPath()
    ctx.restoreGState()

    // Griff an der Linie — macht aus der Grenze etwas Einstellbares.
    ctx.addPath(CGPath(ellipseIn: CGRect(x: 208 - 34, y: limitY - 34, width: 68, height: 68),
                       transform: nil))
    ctx.setFillColor(chalk)
    ctx.fillPath()
    ctx.addPath(CGPath(ellipseIn: CGRect(x: 208 - 15, y: limitY - 15, width: 30, height: 30),
                       transform: nil))
    ctx.setFillColor(ink)
    ctx.fillPath()

    ctx.restoreGState()
}

func render(pixels: Int, withBackground: Bool = true) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let ctx = context.cgContext
    ctx.setAllowsAntialiasing(true)
    draw(into: ctx, scale: CGFloat(pixels) / size, withBackground: withBackground)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("dist/AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in variants {
    try render(pixels: pixels).write(to: iconset.appendingPathComponent("\(name).png"))
}

// Für Website und README zusätzlich einzeln. 512 Pixel reichen für Favicon
// und Vorschaubild; eine 1024er Fassung wäre ein Megabyte im Repository,
// das niemand ausliefert.
let web = root.appendingPathComponent("web/public")
try? FileManager.default.createDirectory(at: web, withIntermediateDirectories: true)
try render(pixels: 512).write(to: web.appendingPathComponent("icon-512.png"))
try render(pixels: 256).write(to: root.appendingPathComponent("dist/icon-256.png"))

print("▸ Symbole geschrieben nach \(iconset.path)")
