#!/bin/bash
# Собирает PerfHUD.app из PerfHUD.swift (нужны Xcode Command Line Tools).
# Запуск:  bash build_app.sh
set -e
cd "$(dirname "$0")"

APP="PerfHUD.app"
MINIMUM_MACOS_VERSION="26.0"
export MACOSX_DEPLOYMENT_TARGET="$MINIMUM_MACOS_VERSION"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Компиляция…"
swiftc -parse-as-library -swift-version 5 -O \
    -target "$(uname -m)-apple-macosx${MINIMUM_MACOS_VERSION}" \
    -Xlinker -undefined -Xlinker dynamic_lookup \
    -module-cache-path "${TMPDIR:-/tmp}/perfhud-swift-module-cache" \
    PerfHUD.swift -o "$APP/Contents/MacOS/PerfHUD"

# swiftc may ignore MACOSX_DEPLOYMENT_TARGET; validate the actual Mach-O target.
BUILT_MINIMUM_MACOS_VERSION="$(xcrun vtool -show-build "$APP/Contents/MacOS/PerfHUD" | awk '/minos/ { print $2; exit }')"
if [ "$BUILT_MINIMUM_MACOS_VERSION" != "$MINIMUM_MACOS_VERSION" ]; then
    echo "Unexpected minimum macOS version: $BUILT_MINIMUM_MACOS_VERSION (expected $MINIMUM_MACOS_VERSION)" >&2
    exit 1
fi

echo "▸ Info.plist…"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PerfHUD</string>
    <key>CFBundleDisplayName</key><string>PerfHUD</string>
    <key>CFBundleIdentifier</key><string>local.perfhud.app</string>
    <key>CFBundleExecutable</key><string>PerfHUD</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.2</string>
    <key>CFBundleVersion</key><string>3</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

make_icon() {
    echo "▸ Иконка…"
    local tmp
    tmp="$(mktemp -d)"
    cat > "$tmp/icon.swift" <<'SWIFT'
import AppKit
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let bgPath = NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190)
NSGradient(colors: [NSColor(red: 0.13, green: 0.15, blue: 0.22, alpha: 1),
                    NSColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)])!.draw(in: bgPath, angle: -90)
let ys: [CGFloat] = [0.30, 0.34, 0.31, 0.45, 0.38, 0.62, 0.50, 0.72, 0.55, 0.66, 0.48, 0.58]
let line = NSBezierPath()
for (i, y) in ys.enumerated() {
    let p = NSPoint(x: 200 + CGFloat(i) * (624 / CGFloat(ys.count - 1)), y: 200 + y * 560)
    if i == 0 { line.move(to: p) } else { line.line(to: p) }
}
line.lineWidth = 36
line.lineCapStyle = .round
line.lineJoinStyle = .round
NSColor(red: 0.35, green: 0.92, blue: 0.75, alpha: 1).setStroke()
line.stroke()
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT
    swift "$tmp/icon.swift" "$tmp/icon.png"
    mkdir "$tmp/AppIcon.iconset"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
        sips -z $((s*2)) $((s*2)) "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$tmp/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
    rm -rf "$tmp"
}
make_icon || echo "  (иконку создать не удалось — приложение будет с иконкой по умолчанию)"

echo "▸ Подпись…"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"

echo
echo "✓ Готово: $(pwd)/$APP"
echo "  Перетащите PerfHUD.app в «Программы» и запускайте двойным кликом."
open "$APP"
