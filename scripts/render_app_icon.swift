#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RenderArguments {
    let inputPath: String
    let outputPath: String
}

private func parseArguments() -> RenderArguments? {
    var inputPath: String?
    var outputPath: String?

    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--input":
            inputPath = iterator.next()
        case "--output":
            outputPath = iterator.next()
        default:
            fputs("Unknown argument: \(argument)\n", stderr)
            return nil
        }
    }

    guard let inputPath, let outputPath else {
        return nil
    }

    return RenderArguments(inputPath: inputPath, outputPath: outputPath)
}

private func color(hex: UInt32) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xFF) / 255.0
    let green = CGFloat((hex >> 8) & 0xFF) / 255.0
    let blue = CGFloat(hex & 0xFF) / 255.0
    return CGColor(red: red, green: green, blue: blue, alpha: 1.0)
}

private func makeBitmapContext(size: Int) -> CGContext? {
    CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
}

private func drawBackground(in context: CGContext, size: CGFloat) {
    let colors = [color(hex: 0x081018), color(hex: 0x10273A), color(hex: 0x07131E)] as CFArray
    let locations: [CGFloat] = [0.0, 0.58, 1.0]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    context.saveGState()
    context.addRect(rect)
    context.clip()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    let glowColors = [color(hex: 0xFA8F40).copy(alpha: 0.0)!, color(hex: 0xFA8F40).copy(alpha: 0.16)!] as CFArray
    let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: size * 0.78, y: size * 0.24),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.78, y: size * 0.24),
        endRadius: size * 0.58,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()
}

private func drawPDF(at inputPath: String, in context: CGContext, size: CGFloat) throws {
    guard let provider = CGDataProvider(filename: inputPath),
          let document = CGPDFDocument(provider),
          let page = document.page(at: 1) else {
        throw NSError(domain: "render_app_icon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Failed to load PDF icon source at \(inputPath)"
        ])
    }

    let mediaBox = page.getBoxRect(.mediaBox)
    let inset = size * 0.015
    let targetRect = CGRect(x: inset, y: inset, width: size - (inset * 2), height: size - (inset * 2))
    let scale = min(targetRect.width / mediaBox.width, targetRect.height / mediaBox.height)
    let drawWidth = mediaBox.width * scale
    let drawHeight = mediaBox.height * scale
    let drawRect = CGRect(
        x: (size - drawWidth) / 2.0,
        y: (size - drawHeight) / 2.0,
        width: drawWidth,
        height: drawHeight
    )

    context.saveGState()
    context.translateBy(x: drawRect.minX, y: drawRect.minY)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -mediaBox.minX, y: -mediaBox.minY)
    context.drawPDFPage(page)
    context.restoreGState()
}

private func writePNG(from context: CGContext, to outputPath: String) throws {
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outputPath) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "render_app_icon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Failed to create PNG destination at \(outputPath)"
        ])
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "render_app_icon", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Failed to write PNG output to \(outputPath)"
        ])
    }
}

private func renderIcon(arguments: RenderArguments) throws {
    let canvasSize = 1024

    let outputURL = URL(fileURLWithPath: arguments.outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: nil
    )

    guard let context = makeBitmapContext(size: canvasSize) else {
        throw NSError(domain: "render_app_icon", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Failed to create bitmap context"
        ])
    }

    let size = CGFloat(canvasSize)
    drawBackground(in: context, size: size)
    try drawPDF(at: arguments.inputPath, in: context, size: size)
    try writePNG(from: context, to: arguments.outputPath)
}

if let arguments = parseArguments() {
    do {
        try renderIcon(arguments: arguments)
    } catch {
        fputs("render_app_icon.swift: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else {
    fputs("Usage: render_app_icon.swift --input <pdf> --output <png>\n", stderr)
    exit(1)
}
