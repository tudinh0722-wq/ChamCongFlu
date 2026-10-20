$ErrorActionPreference = "Stop"

# Run from the repository root. Safe to run many times (idempotent):
# - creates android/ if missing
# - NFC permission
# - tag tapped while app is in background / screen locked => Android starts the app (intent-filter)
# - MainActivity.kt: reads the tag UID from the intent and forwards it to Dart
# (ASCII only on purpose: Windows PowerShell 5.1 reads UTF-8 without BOM as ANSI)

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the Flutter repository root (pubspec.yaml not found)."
}

if (-not (Test-Path "android")) {
    Write-Host "Generating a fresh Android host with the installed Flutter SDK..."
    flutter create --platforms=android .
} else {
    Write-Host "android/ already exists; keeping it and patching NFC support."
}

$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Read-Text([string]$relative) {
    return [System.IO.File]::ReadAllText((Join-Path $root $relative))
}
function Write-Text([string]$relative, [string]$text) {
    [System.IO.File]::WriteAllText((Join-Path $root $relative), $text, $utf8)
}

# ---------------------------------------------------------------- Manifest
$manifest = "android/app/src/main/AndroidManifest.xml"
if (-not (Test-Path $manifest)) {
    throw "AndroidManifest.xml was not generated at $manifest"
}
$xml = Read-Text $manifest
$nl = "`r`n"

if ($xml -notmatch 'android.permission.NFC') {
    $m = [regex]::Match($xml, '<manifest\b[^>]*>')
    $perm = $nl + '    <uses-permission android:name="android.permission.NFC" />'
    $xml = $xml.Insert($m.Index + $m.Length, $perm)
    Write-Host "  + NFC permission"
}

if ($xml -notmatch 'android.hardware.nfc') {
    $feature = '    <uses-feature android:name="android.hardware.nfc" android:required="false" />' + $nl
    $xml = $xml.Replace('</manifest>', $feature + '</manifest>')
    Write-Host "  + uses-feature NFC"
}

# NTAG (NfcA) tapped while the app is not in the foreground => start MainActivity.
if ($xml -notmatch 'android.nfc.action.TECH_DISCOVERED') {
    $filter = @'
            <intent-filter>
                <action android:name="android.nfc.action.TECH_DISCOVERED" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <meta-data
                android:name="android.nfc.action.TECH_DISCOVERED"
                android:resource="@xml/nfc_tech_filter" />

'@
    $filter = $filter.Replace("`r`n", "`n").Replace("`n", $nl)
    $idx = $xml.IndexOf('</activity>')
    if ($idx -lt 0) { throw "</activity> not found in AndroidManifest.xml" }
    $xml = $xml.Insert($idx, $filter)
    Write-Host "  + intent-filter TECH_DISCOVERED"
}

# Show over the lock screen and turn the screen on when a tag starts the app.
if ($xml -notmatch 'android:showWhenLocked') {
    $attrs = 'android:name=".MainActivity"' + $nl + '            android:showWhenLocked="true"' + $nl + '            android:turnScreenOn="true"'
    $xml = $xml.Replace('android:name=".MainActivity"', $attrs)
    Write-Host "  + showWhenLocked / turnScreenOn"
}

Write-Text $manifest $xml

# ------------------------------------------------------------- Tech filter
$techDir = "android/app/src/main/res/xml"
New-Item -ItemType Directory -Force -Path (Join-Path $root $techDir) | Out-Null
$tech = @'
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
    <tech-list>
        <tech>android.nfc.tech.NfcA</tech>
    </tech-list>
</resources>
'@
Write-Text "$techDir/nfc_tech_filter.xml" $tech
Write-Host "  + res/xml/nfc_tech_filter.xml"

# ------------------------------------------------------------ MainActivity
$mainKt = Get-ChildItem -Path (Join-Path $root "android/app/src/main") -Recurse -Filter "MainActivity.kt" | Select-Object -First 1
if (-not $mainKt) {
    throw "MainActivity.kt not found (Flutter Kotlin template required)."
}
$existing = [System.IO.File]::ReadAllText($mainKt.FullName)
if ($existing -match '(?m)^\s*package\s+([\w\.]+)') {
    $pkg = $Matches[1]
} else {
    throw "Cannot read the package name from $($mainKt.FullName)"
}

$kotlin = @'
package __PACKAGE__

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives the NFC intent when a tag is tapped while the app is not in the
 * foreground (locked screen, another app, home screen) and forwards the UID
 * to Dart through a MethodChannel.
 * Overwritten by scripts/bootstrap_android.ps1 on every run.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingUid: String? = null
    private var resumed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingUid = takeUid(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chamcong/nfc_launch")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialTap" -> {
                    val uid = pendingUid
                    pendingUid = null
                    result.success(if (uid == null) null else mapOf("uid" to uid, "background" to true))
                }
                "moveToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uid = takeUid(intent) ?: return
        // resumed == false: app was in the background / brought up by the tag.
        channel?.invokeMethod("onTag", mapOf("uid" to uid, "background" to !resumed))
    }

    override fun onResume() {
        super.onResume()
        resumed = true
    }

    override fun onPause() {
        resumed = false
        super.onPause()
    }

    private fun takeUid(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action
        if (action != NfcAdapter.ACTION_TECH_DISCOVERED &&
            action != NfcAdapter.ACTION_TAG_DISCOVERED &&
            action != NfcAdapter.ACTION_NDEF_DISCOVERED
        ) return null

        val tag: Tag? = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }
        // Do not process the same intent twice if the activity is recreated.
        intent.action = Intent.ACTION_MAIN
        val id = tag?.id ?: return null
        return id.joinToString(":") { "%02X".format(it) }
    }
}
'@
$kotlin = $kotlin.Replace('__PACKAGE__', $pkg).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($mainKt.FullName, $kotlin, $utf8)
Write-Host "  + MainActivity.kt (package $pkg)"

Write-Host ""
Write-Host "Android host ready. Next run:"
Write-Host "  flutter pub get"
Write-Host "  flutter analyze"
Write-Host "  flutter test"
Write-Host "  flutter run"
