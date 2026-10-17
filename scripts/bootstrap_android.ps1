$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the Flutter repository root (pubspec.yaml not found)."
}

if (-not (Test-Path "android")) {
    Write-Host "Generating a fresh Android host with the installed Flutter SDK..."
    flutter create --platforms=android .
} else {
    Write-Host "android/ already exists; keeping it unchanged."
}

$manifest = "android/app/src/main/AndroidManifest.xml"
if (-not (Test-Path $manifest)) {
    throw "AndroidManifest.xml was not generated at $manifest"
}

$xml = Get-Content $manifest -Raw
if ($xml -notmatch 'android.permission.NFC') {
    $xml = $xml -replace '(<manifest\b[^>]*>)', '$1' + "`r`n    <uses-permission android:name=""android.permission.NFC"" />"
}
if ($xml -notmatch 'android.hardware.nfc') {
    $xml = $xml -replace '(</manifest>)', '    <uses-feature android:name="android.hardware.nfc" android:required="false" />' + "`r`n$1"
}
Set-Content -Path $manifest -Value $xml -Encoding UTF8

Write-Host "Android host ready. Next run:"
Write-Host "  flutter pub get"
Write-Host "  flutter analyze"
Write-Host "  flutter test"
Write-Host "  flutter run"
