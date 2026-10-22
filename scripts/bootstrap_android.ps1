$ErrorActionPreference = "Stop"

# Run from the repository root. Safe to run many times (idempotent):
# - creates android/ if missing
# - NFC permission
# - tag tapped while app is in background / screen locked => Android starts the app (intent-filter)
# - MainActivity.kt: (1) reads the tag UID from the intent and forwards it to Dart,
#                    (2) folder picker + read/write of backup files in a user-chosen
#                        folder (Storage Access Framework, no storage permission needed)
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

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 1) Receives the NFC intent when a tag is tapped while the app is not in the
 *    foreground (locked screen, another app, home screen) and forwards the UID
 *    to Dart through the "chamcong/nfc_launch" channel.
 * 2) "chamcong/backup" channel: lets the user pick a folder once (Storage Access
 *    Framework) and reads/writes small backup files there. The grant is lost when
 *    the app is uninstalled, so after a reinstall the user picks the folder again.
 * Overwritten by scripts/bootstrap_android.ps1 on every run.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val REQ_PICK_FOLDER = 7101
        private const val PREFS = "chamcong_backup"
        private const val KEY_TREE = "tree_uri"
    }

    private var channel: MethodChannel? = null
    private var pendingUid: String? = null
    private var resumed = false
    private var pickResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingUid = takeUid(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val ch = MethodChannel(messenger, "chamcong/nfc_launch")
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

        MethodChannel(messenger, "chamcong/backup").setMethodCallHandler { call, result ->
            handleBackup(call, result)
        }
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

    // ------------------------------------------------------------ Backup

    private fun handleBackup(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getFolder" -> result.success(folderInfo())
                "pickFolder" -> pickFolder(result)
                "writeText" -> {
                    writeText(call.argument<String>("name")!!, call.argument<String>("text") ?: "")
                    result.success(null)
                }
                "readText" -> result.success(readText(call.argument<String>("name")!!))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("backup_error", e.message ?: e.toString(), null)
        }
    }

    /** Saved folder, only if the persisted read+write grant still exists. */
    private fun savedTree(): Uri? {
        val s = getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_TREE, null) ?: return null
        val uri = Uri.parse(s)
        val granted = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        return if (granted) uri else null
    }

    private fun requireTree(): Uri =
        savedTree() ?: throw IllegalStateException("No backup folder selected, or the permission was lost")

    private fun displayName(tree: Uri): String {
        return try {
            val doc = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            contentResolver.query(
                doc,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null
            )?.use { c -> if (c.moveToFirst()) (c.getString(0) ?: "") else "" } ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    private fun folderInfo(): Map<String, String>? {
        val tree = savedTree() ?: return null
        return mapOf("uri" to tree.toString(), "name" to displayName(tree))
    }

    private fun pickFolder(result: MethodChannel.Result) {
        if (pickResult != null) {
            result.error("busy", "Folder picker is already open", null)
            return
        }
        pickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQ_PICK_FOLDER)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_PICK_FOLDER) {
            val r = pickResult
            pickResult = null
            val uri = data?.data
            if (resultCode == Activity.RESULT_OK && uri != null) {
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        .edit().putString(KEY_TREE, uri.toString()).apply()
                    r?.success(mapOf("uri" to uri.toString(), "name" to displayName(uri)))
                } catch (e: Exception) {
                    r?.error("backup_error", e.message ?: e.toString(), null)
                }
            } else {
                r?.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun findChild(tree: Uri, name: String): Uri? {
        val parentId = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            ),
            null, null, null
        )?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
                }
            }
        }
        return null
    }

    private fun writeText(name: String, text: String) {
        val tree = requireTree()
        var doc = findChild(tree, name)
        if (doc == null) {
            val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            doc = DocumentsContract.createDocument(contentResolver, parent, "application/json", name)
        }
        val target = doc ?: throw IllegalStateException("Could not create file $name")
        val out = contentResolver.openOutputStream(target, "wt")
            ?: throw IllegalStateException("Could not open $name for writing")
        out.use { it.write(text.toByteArray(Charsets.UTF_8)) }
    }

    private fun readText(name: String): String? {
        val tree = requireTree()
        val doc = findChild(tree, name) ?: return null
        return contentResolver.openInputStream(doc)?.use { it.readBytes().toString(Charsets.UTF_8) }
    }
}
'@
$kotlin = $kotlin.Replace('__PACKAGE__', $pkg).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($mainKt.FullName, $kotlin, $utf8)
Write-Host "  + MainActivity.kt (package $pkg): NFC launch + backup folder"

Write-Host ""
Write-Host "Android host ready. Next run:"
Write-Host "  flutter pub get"
Write-Host "  flutter analyze"
Write-Host "  flutter test"
Write-Host "  flutter run"
