package com.terax.terax
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val ui = Handler(Looper.getMainLooper())
    private var audioAccessResult: MethodChannel.Result? = null
    private var filesResult: MethodChannel.Result? = null
    private var shareChannel: MethodChannel? = null
    private var soundChannel: MethodChannel? = null
    private var transferSounds: TransferSoundPlayer? = null
    private var listening = false
    private var initialTaken = false
    private var initialLoading = false
    private var initialResult: MethodChannel.Result? = null
    private var initialShare: Map<String, Any?>? = null
    private val pendingShares = mutableListOf<Map<String, Any?>>()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) acceptShare(intent, true)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acceptShare(intent, false)
    }
    private fun acceptShare(intent: Intent?, initial: Boolean) {
        if (intent?.action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) return
        val incoming = intent ?: return
        val text = incoming.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        @Suppress("DEPRECATION")
        val streams = if (incoming.action == Intent.ACTION_SEND_MULTIPLE) incoming.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
            else listOfNotNull(incoming.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        // Providers may supply only ClipData; combine all sources without duplicate copies.
        val uris = streams.toMutableSet()
        incoming.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) clip.getItemAt(index).uri?.let { uris.add(it) }
        }
        incoming.data?.let { uris.add(it) }
        if (initial) initialLoading = true
        io.execute {
            var rejected = 0
            val files = uris.mapNotNull { uri ->
                try { fileRow(uri, true) } catch (_: Exception) { rejected++; null }
            }
            val warning = if (rejected > 0) "No se pudieron leer algunos archivos compartidos o superan el límite de 1 GB." else null
            val payload = mapOf<String, Any?>("text" to text, "files" to files, "warning" to warning)
            ui.post {
                if (initial) {
                    initialLoading = false
                    if (initialResult != null) {
                        initialResult?.success(payload)
                        initialResult = null
                        initialTaken = true
                    } else if (!initialTaken) initialShare = payload
                } else if (listening) shareChannel?.invokeMethod("shared", payload)
                else pendingShares.add(payload)
            }
        }
        // Prevent duplicate delivery if Android recreates this activity.
        incoming.action = Intent.ACTION_MAIN
    }
    private fun fileRow(uri: Uri, cache: Boolean): Map<String, Any> {
        require(uri.scheme == "content") { "Archivo no válido." }
        var name = "archivo"
        var size = -1L
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                name = cursor.getString(0) ?: name
                if (!cursor.isNull(1)) size = cursor.getLong(1)
            }
        }
        require(size <= 1073741824L) { "El archivo supera el límite de 1 GB." }
        name = name.substringAfterLast('/').substringAfterLast('\\').replace(Regex("[^\\p{L}\\p{N} ._()-]"), "_").take(160).ifBlank { "archivo" }
        val row = mutableMapOf<String, Any>("id" to uri.toString(), "name" to name, "size" to size.coerceAtLeast(0), "isImage" to (contentResolver.getType(uri)?.startsWith("image/") == true))
        if (cache) {
            val path = materialize(uri.toString(), name)
            row["path"] = path
            row["size"] = File(path).length()
        }
        return row
    }
    private var folderResult: MethodChannel.Result? = null
    private val prefs by lazy { getSharedPreferences("terax_library", MODE_PRIVATE) }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        transferSounds?.dispose()
        transferSounds = try { TransferSoundPlayer() } catch (_: Exception) { null }
        soundChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "terax/sounds").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> transferSounds?.play(call.argument<String>("path"), result) ?: result.success(false)
                    "stop" -> { transferSounds?.stop(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "terax/share").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeInitial" -> {
                        if (initialTaken) result.success(null)
                        else if (initialLoading) {
                            if (initialResult == null) initialResult = result else result.success(null)
                        } else { initialTaken = true; result.success(initialShare); initialShare = null }
                    }
                    "listen" -> { listening = true; pendingShares.toList().forEach { channel.invokeMethod("shared", it) }; pendingShares.clear(); result.success(null) }
                    "stopListening" -> { listening = false; result.success(null) }
                    "openLink" -> {
                        val uri = Uri.parse(call.argument<String>("url") ?: "")
                        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) result.success(false)
                        else try { startActivity(Intent(Intent.ACTION_VIEW, uri)); result.success(true) } catch (_: Exception) { result.success(false) }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "terax/library").setMethodCallHandler { call, result ->
            if (call.method == "requestAudioAccess") {
                requestAudioAccess(call.argument<Boolean>("automatic") ?: false, result)
            } else if (call.method == "chooseFiles") {
                if (filesResult != null || folderResult != null) { result.error("busy", "Ya hay una selección abierta.", null); return@setMethodCallHandler }
                filesResult = result
                val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
                    .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                try { startActivityForResult(picker, 7042) } catch (e: Exception) { filesResult = null; result.error("files", e.message, null) }
            } else if (call.method == "chooseFolder") {
                if (folderResult != null || filesResult != null) { result.error("busy", "Ya hay una selección de carpeta abierta.", null); return@setMethodCallHandler }
                folderResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                try { startActivityForResult(intent, 7041) } catch (e: Exception) { folderResult = null; result.error("folder", e.message, null) }
            } else {
                io.execute {
                    try {
                        val value: Any? = when (call.method) {
                            "list" -> listDocuments(call.argument<String>("location"))
                            "materialize" -> materialize(call.argument<String>("uri")!!, call.argument<String>("name") ?: "archivo")
                            else -> null
                        }
                        ui.post { if (call.method in listOf("list", "materialize")) result.success(value) else result.notImplemented() }
                    } catch (e: Exception) {
                        ui.post { result.error("library", if (e is SecurityException) "El permiso de esta carpeta venció. Vuelve a agregarla." else e.message ?: "No se pudo leer el archivo.", null) }
                    }
                }
            }
        }
    }
    private fun requestAudioAccess(automatic: Boolean, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 23) { result.success(true); return }
        val permission = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) { result.success(true); return }
        val preferences = getSharedPreferences("terax_permissions", MODE_PRIVATE)
        if (audioAccessResult != null || (automatic && preferences.getBoolean("audio_requested", false))) { result.success(false); return }
        audioAccessResult = result
        try {
            preferences.edit().putBoolean("audio_requested", true).apply()
            requestPermissions(arrayOf(permission), 7063)
        } catch (_: Exception) { audioAccessResult = null; result.success(false) }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7063) {
            val result = audioAccessResult; audioAccessResult = null
            result?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        }
    }
    @Deprecated("Activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7042) {
            val result = filesResult ?: return
            filesResult = null
            if (resultCode != Activity.RESULT_OK || data == null) { result.success(emptyList<Any>()); return }
            val uris = mutableListOf<Uri>()
            data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
            data.data?.let { uris.add(it) }
            io.execute {
                try {
                    val rows = uris.distinct().map { uri ->
                        var persisted = false
                        try { contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION); persisted = true } catch (_: SecurityException) { }
                        fileRow(uri, !persisted)
                    }
                    ui.post { result.success(rows) }
                } catch (e: Exception) { ui.post { result.error("files", e.message ?: "No se pudo leer el archivo.", null) } }
            }
            return
        }
        if (requestCode != 7041) return
        val result = folderResult ?: return
        folderResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val roots = prefs.getStringSet("roots", emptySet())!!.toMutableSet()
            roots.add(uri.toString())
            prefs.edit().putStringSet("roots", roots).apply()
            result.success(uri.toString())
        } catch (e: Exception) { result.error("permission", "No se pudo guardar el permiso de la carpeta.", null) }
    }
    private fun listDocuments(location: String?): List<Map<String, Any>> {
        if (location == null) {
            return prefs.getStringSet("roots", emptySet())!!.map { raw ->
                val tree = Uri.parse(raw)
                val doc = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                queryRows(doc, tree).firstOrNull() ?: mapOf("id" to raw, "name" to "Carpeta no disponible", "directory" to true)
            }
        }
        val tree = Uri.parse(location)
        val id = if (DocumentsContract.isDocumentUri(this, tree)) DocumentsContract.getDocumentId(tree) else DocumentsContract.getTreeDocumentId(tree)
        return queryRows(DocumentsContract.buildChildDocumentsUriUsingTree(tree, id), tree)
    }
    private fun queryRows(query: Uri, tree: Uri): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED)
        contentResolver.query(query, projection, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val mime = cursor.getString(2) ?: "application/octet-stream"
                rows.add(mapOf("id" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(), "name" to (cursor.getString(1) ?: "Archivo"), "mime" to mime, "directory" to (mime == DocumentsContract.Document.MIME_TYPE_DIR), "size" to cursor.getLong(3), "modified" to cursor.getLong(4)))
            }
        }
        return rows
    }
    private fun materialize(raw: String, name: String): String {
        val uri = Uri.parse(raw)
        require(uri.scheme == "content") { "Archivo no válido." }
        val safe = name.substringAfterLast('/').substringAfterLast('\\').replace(Regex("[^\\p{L}\\p{N} ._()-]"), "_").take(160).ifBlank { "archivo" }
        val directory = File(cacheDir, "library").apply { mkdirs() }
        // Metadata is queried on every selection so changed documents are not
        // served from an earlier preview. Providers without metadata are copied.
        var size = -1L
        var modified = 0L
        try {
            contentResolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    if (!cursor.isNull(0)) size = cursor.getLong(0)
                    if (!cursor.isNull(1)) modified = cursor.getLong(1)
                }
            }
        } catch (_: IllegalArgumentException) { /* Generic sharing provider: copy and enforce the byte limit. */ }
        require(size <= 1073741824L) { "El archivo supera el límite de 1 GB." }
        val reusable = size >= 0L && modified > 0L
        val key = if (reusable) java.security.MessageDigest.getInstance("SHA-256").digest("$raw|$size|$modified".toByteArray()).joinToString("") { "%02x".format(it) } else java.util.UUID.randomUUID().toString()
        val target = File(directory, "${key}_$safe")
        if (reusable && target.isFile && target.length() == size) return target.absolutePath
        val partial = File(directory, "${key}_${java.util.UUID.randomUUID()}.part")
        try {
            contentResolver.openInputStream(uri)?.use { input ->
                partial.outputStream().use { output ->
                    val buffer = ByteArray(65536)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        require(total <= 1073741824L) { "El archivo supera el límite de 1 GB." }
                        output.write(buffer, 0, count)
                    }
                }
            } ?: throw IllegalStateException("El archivo ya no está disponible.")
            check(partial.renameTo(target)) { "No se pudo preparar el archivo." }
            return target.absolutePath
        } catch (e: Exception) { partial.delete(); throw e }
    }
    override fun onDestroy() {
        audioAccessResult?.success(false); audioAccessResult = null
        filesResult?.error("closed", "La selección de archivos se cerró.", null)
        filesResult = null
        initialResult?.success(null)
        initialResult = null
        listening = false
        shareChannel?.setMethodCallHandler(null)
        shareChannel = null
        folderResult?.error("closed", "La selección de carpeta se cerró.", null)
        folderResult = null
        soundChannel?.setMethodCallHandler(null)
        soundChannel = null
        transferSounds?.dispose()
        transferSounds = null
        io.shutdown()
        super.onDestroy()
    }
}
