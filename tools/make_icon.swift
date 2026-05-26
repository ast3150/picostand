#!/usr/bin/env swift
import AppKit

let size: CGFloat = 1024
let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(red: 0.78, green: 0.95, blue: 0.84, alpha: 1).cgColor,
        NSColor(red: 0.36, green: 0.78, blue: 0.50, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bgGradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])

ctx.setFillColor(NSColor(white: 1, alpha: 0.32).cgColor)
ctx.fillEllipse(in: CGRect(x: 110, y: 110, width: 804, height: 804))

let darkGreen = NSColor(red: 0.10, green: 0.34, blue: 0.22, alpha: 1)
let config = NSImage.SymbolConfiguration(pointSize: 560, weight: .medium)
let symbol = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: nil)!
    .withSymbolConfiguration(config)!

let tinted = NSImage(size: symbol.size)
tinted.lockFocus()
darkGreen.set()
let r = NSRect(origin: .zero, size: symbol.size)
r.fill()
symbol.draw(in: r, from: .zero, operation: .destinationIn, fraction: 1)
tinted.unlockFocus()

let fSize = tinted.size
let fRect = NSRect(
    x: (size - fSize.width) / 2,
    y: (size - fSize.height) / 2,
    width: fSize.width,
    height: fSize.height
)
tinted.draw(in: fRect)

canvas.unlockFocus()

let tiff = canvas.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote", outPath)
