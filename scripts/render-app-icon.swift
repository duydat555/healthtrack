#!/usr/bin/env swift
// Vẽ icon ứng dụng HealthTrack (chữ H có thanh ngang là một nhịp tim) và sinh mọi tệp PNG cần cho
// iOS và Android từ cùng một hình học. Dùng: swift scripts/render-app-icon.swift [thư mục xem trước]
// Hình học này phải khớp với mobile/lib/widgets/app_logo.dart.
import AppKit
import CoreGraphics

// MARK: Hình học trên lưới 1024
let stemW: CGFloat = 104
let top: CGFloat = 250, bottom: CGFloat = 774
let leftX: CGFloat = 232, rightX: CGFloat = 792
let beat: [CGPoint] = [
    CGPoint(x: leftX + stemW - 10, y: 512), CGPoint(x: 408, y: 512), CGPoint(x: 458, y: 384),
    CGPoint(x: 514, y: 648), CGPoint(x: 566, y: 512), CGPoint(x: rightX - stemW + 10, y: 512),
]
let beatWidth: CGFloat = 62

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: a)
}

enum Variant { case light, dark, tinted }

/// Vẽ chữ H + nhịp tim bằng màu `ink`, trong hệ tọa độ 1024 (gốc ở dưới trái như CoreGraphics).
func drawMark(_ c: CGContext, ink: CGColor, scale s: CGFloat = 1) {
    c.saveGState()
    // Lật trục Y để dùng tọa độ "gốc trên trái" như thiết kế
    c.translateBy(x: 512, y: 512); c.scaleBy(x: s, y: -s); c.translateBy(x: -512, y: -512)
    c.setFillColor(ink)
    for x in [leftX, rightX - stemW] {
        let r = CGRect(x: x, y: top, width: stemW, height: bottom - top)
        c.addPath(CGPath(roundedRect: r, cornerWidth: stemW / 2, cornerHeight: stemW / 2, transform: nil))
        c.fillPath()
    }
    c.setStrokeColor(ink); c.setLineWidth(beatWidth); c.setLineCap(.round); c.setLineJoin(.round)
    c.move(to: beat[0]); for p in beat.dropFirst() { c.addLine(to: p) }
    c.strokePath()
    c.restoreGState()
}

func makeContext(_ size: Int, opaque: Bool) -> CGContext {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)!
    c.interpolationQuality = .high
    c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    return c
}

func background(_ c: CGContext, _ v: Variant) {
    let colors: [CGColor]
    switch v {
    case .light: colors = [rgb(0xFFD60A), rgb(0xFFB800)]
    case .dark: colors = [rgb(0x3A3A3C), rgb(0x141416)]
    case .tinted: colors = [rgb(0x303030), rgb(0x000000)]
    }
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])
}

func inkColor(_ v: Variant) -> CGColor {
    switch v { case .light: return rgb(0x1C1C1E); case .dark: return rgb(0xFFD60A); case .tinted: return rgb(0xFFFFFF) }
}

/// Icon vuông kín nền (iOS 1024, Android cũ).
func renderIcon(_ size: Int, _ v: Variant, rounded: Bool = false) -> CGImage {
    let c = makeContext(size, opaque: !rounded)
    if rounded {
        c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024), cornerWidth: 229, cornerHeight: 229, transform: nil))
        c.clip()
    }
    background(c, v)
    drawMark(c, ink: inkColor(v))
    return c.makeImage()!
}

/// Lớp trước của adaptive icon Android (nền trong suốt, H thu nhỏ vào vùng an toàn 66/108).
func renderForeground(_ size: Int, ink: CGColor) -> CGImage {
    let c = makeContext(size, opaque: false)
    drawMark(c, ink: ink, scale: 0.88)
    return c.makeImage()!
}

func writePNG(_ image: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
}

// MARK: Đầu ra
let root = FileManager.default.currentDirectoryPath
let ios = "\(root)/mobile/ios/Runner/Assets.xcassets"
let res = "\(root)/mobile/android/app/src/main/res"

// iOS: một ảnh 1024 cho mỗi kiểu giao diện (Xcode tự tạo mọi kích thước)
let appIconSet = "\(ios)/AppIcon.appiconset"
if let old = try? FileManager.default.contentsOfDirectory(atPath: appIconSet) {
    for f in old where f.hasSuffix(".png") { try? FileManager.default.removeItem(atPath: "\(appIconSet)/\(f)") }
}
writePNG(renderIcon(1024, .light), "\(appIconSet)/AppIcon.png")
writePNG(renderIcon(1024, .dark), "\(appIconSet)/AppIcon-Dark.png")
writePNG(renderIcon(1024, .tinted), "\(appIconSet)/AppIcon-Tinted.png")
try! """
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "AppIcon-Dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ], "filename" : "AppIcon-Tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

""".write(toFile: "\(appIconSet)/Contents.json", atomically: true, encoding: .utf8)

// iOS: logo cho màn khởi động (ô icon bo góc, 120pt: 120/240/360 px)
let launchSet = "\(ios)/LaunchLogo.imageset"
for (suffix, px) in [("", 120), ("@2x", 240), ("@3x", 360)] {
    writePNG(renderIcon(px, .light, rounded: true), "\(launchSet)/LaunchLogo\(suffix).png")
    writePNG(renderIcon(px, .dark, rounded: true), "\(launchSet)/LaunchLogo-Dark\(suffix).png")
}
try! """
{
  "images" : [
    { "filename" : "LaunchLogo.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "LaunchLogo@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "LaunchLogo@3x.png", "idiom" : "universal", "scale" : "3x" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "LaunchLogo-Dark.png", "idiom" : "universal", "scale" : "1x" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "LaunchLogo-Dark@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "LaunchLogo-Dark@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

""".write(toFile: "\(launchSet)/Contents.json", atomically: true, encoding: .utf8)

// Android: logo màn khởi động (<bitmap> không đọc được adaptive icon XML nên cần PNG riêng)
writePNG(renderIcon(360, .light, rounded: true), "\(res)/drawable-nodpi/launch_logo.png")

// Android: icon cũ (bo góc) + adaptive (lớp trước, đơn sắc)
for (dir, legacy, adaptive) in [("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216), ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432)] {
    writePNG(renderIcon(legacy, .light, rounded: true), "\(res)/mipmap-\(dir)/ic_launcher.png")
    writePNG(renderForeground(adaptive, ink: rgb(0x1C1C1E)), "\(res)/mipmap-\(dir)/ic_launcher_foreground.png")
    writePNG(renderForeground(adaptive, ink: rgb(0x000000)), "\(res)/mipmap-\(dir)/ic_launcher_monochrome.png")
}
try! FileManager.default.createDirectory(atPath: "\(res)/mipmap-anydpi-v26", withIntermediateDirectories: true)
try! """
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>

""".write(toFile: "\(res)/mipmap-anydpi-v26/ic_launcher.xml", atomically: true, encoding: .utf8)
try! """
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFCB05</color>
</resources>

""".write(toFile: "\(res)/values/colors.xml", atomically: true, encoding: .utf8)

// Ảnh xem trước (không commit)
if CommandLine.arguments.count > 1 {
    let out = CommandLine.arguments[1]
    writePNG(renderIcon(512, .light, rounded: true), "\(out)/preview-light.png")
    writePNG(renderIcon(512, .dark, rounded: true), "\(out)/preview-dark.png")
    writePNG(renderIcon(512, .tinted, rounded: true), "\(out)/preview-tinted.png")
    writePNG(renderIcon(60, .light, rounded: true), "\(out)/preview-60.png")
}
print("Đã sinh icon")
