#!/usr/bin/env swift
//
// アプリアイコン生成スクリプト
// 使用方法: swift GenerateAppIcon.swift
//

import Foundation
import AppKit

// アイコンサイズ
let size: CGFloat = 1024

// 画像を生成
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

// 外側：黒背景
let blackBackground = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: size * 0.22, yRadius: size * 0.22)
NSColor.black.setFill()
blackBackground.fill()

// 内側：青い円形グラデーション
let innerPadding: CGFloat = size * 0.12
let innerRect = NSRect(x: innerPadding, y: innerPadding, width: size - innerPadding * 2, height: size - innerPadding * 2)
let innerPath = NSBezierPath(ovalIn: innerRect)

let blueGradient = NSGradient(colors: [
    NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 1.0),  // 明るい青
    NSColor(red: 0.0, green: 0.35, blue: 0.85, alpha: 1.0)  // 深い青
])!
blueGradient.draw(in: innerPath, angle: -45)

// 波形のシンボルを描画
let waveformConfig = NSImage.SymbolConfiguration(pointSize: size * 0.38, weight: .medium)
if let waveformImage = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)?.withSymbolConfiguration(waveformConfig) {
    let waveformSize = waveformImage.size
    let waveformRect = NSRect(
        x: (size - waveformSize.width) / 2,
        y: (size - waveformSize.height) / 2 + size * 0.02,
        width: waveformSize.width,
        height: waveformSize.height
    )

    // 白色で描画
    let tintedImage = NSImage(size: waveformSize)
    tintedImage.lockFocus()
    NSColor.white.set()
    waveformImage.draw(in: NSRect(origin: .zero, size: waveformSize), from: .zero, operation: .sourceOver, fraction: 1.0)
    NSRect(origin: .zero, size: waveformSize).fill(using: .sourceAtop)
    tintedImage.unlockFocus()

    tintedImage.draw(in: waveformRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

// AIテキストを追加
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size * 0.1, weight: .bold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.95),
    .paragraphStyle: paragraphStyle
]

let text = "AI VOICE"
let textRect = NSRect(x: 0, y: size * 0.18, width: size, height: size * 0.12)
text.draw(in: textRect, withAttributes: attributes)

image.unlockFocus()

// PNG形式で保存
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {

    let outputPath = "./AppIcon.png"
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("✅ アイコンを生成しました: \(outputPath)")
    } catch {
        print("❌ 保存エラー: \(error)")
    }
}
