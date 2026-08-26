#!/usr/bin/env swift
import CoreGraphics
import Foundation

// Gibt die Fensternummer des ConnectionLimit-Fensters aus. `screencapture -l`
// braucht sie, und nur so bleiben die abgerundeten Ecken und der Schatten
// erhalten — ein Ausschnitt nach Koordinaten schneidet den Desktop mit ab.
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                      kCGNullWindowID) as? [[String: Any]] ?? []

// Das größte Fenster gewinnt: Beim Öffnen kann kurz ein zweites, winziges
// Fenster in der Liste stehen, und ein Bildschirmfoto davon wäre wertlos.
var best: (number: Int, area: CGFloat)?
for window in list {
    guard window[kCGWindowOwnerName as String] as? String == "ConnectionLimit",
          (window[kCGWindowLayer as String] as? Int) == 0,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? CGFloat, let height = bounds["Height"] as? CGFloat,
          width > 400,
          let number = window[kCGWindowNumber as String] as? Int else { continue }
    if best == nil || width * height > best!.area { best = (number, width * height) }
}
guard let best else { exit(1) }
print(best.number)
