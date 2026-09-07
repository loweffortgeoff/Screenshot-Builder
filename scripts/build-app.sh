#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
swift build
app_path="$PWD/build/Screenshot Builder.app"
mkdir -p "$app_path/Contents/MacOS"
cp .build/debug/ScreenshotBuilder "$app_path/Contents/MacOS/ScreenshotBuilder"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.loweffortapps.screenshotbuilder</string>
<key>CFBundleName</key><string>Screenshot Builder</string>
<key>CFBundleDisplayName</key><string>Screenshot Builder</string>
<key>CFBundleExecutable</key><string>ScreenshotBuilder</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Screenshot Set</string>
<key>CFBundleTypeRole</key><string>Editor</string>
<key>LSHandlerRank</key><string>Owner</string>
<key>LSItemContentTypes</key><array><string>com.loweffortapps.screenshotbuilder.shotset</string></array>
</dict></array>
<key>UTExportedTypeDeclarations</key><array><dict>
<key>UTTypeIdentifier</key><string>com.loweffortapps.screenshotbuilder.shotset</string>
<key>UTTypeDescription</key><string>Screenshot Set</string>
<key>UTTypeConformsTo</key><array><string>public.json</string></array>
<key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>shotset</string></array></dict>
</dict></array>
</dict></plist>
PLIST
codesign --force --sign - "$app_path"
print "Built $app_path"
