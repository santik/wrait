package com.wrait.flutter

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
    private var pendingEntryImportResult: MethodChannel.Result? = null
    private val entryImportLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        handlePickedCsvImport(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableCaptureProtection()

        if (shouldEnableAutomationLockscreenMode()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }

        super.onCreate(savedInstanceState)
        // Flutter can retarget the live activity window during attach/startup,
        // so reassert secure capture protection once the Flutter activity is ready.
        enableCaptureProtection()
    }

    override fun onResume() {
        super.onResume()
        // Reassert protection when Android brings the activity back to foreground.
        enableCaptureProtection()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Some lifecycle/app-switch flows restore focus after the live window changes.
            enableCaptureProtection()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_ID_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                GET_DEVICE_ID_METHOD -> {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        if (androidId.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            result.success(androidId)
                        }
                    } catch (exception: Exception) {
                        result.error(
                            DEVICE_ID_ERROR_CODE,
                            "Failed to retrieve Android device ID.",
                            exception.message
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_LOCK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                OPEN_SECURITY_SETTINGS_METHOD -> {
                    result.success(openSecuritySettings())
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ENTRY_EXPORT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                WRITE_CSV_EXPORT_METHOD -> {
                    val fileName = call.argument<String>("fileName")?.trim()
                    val contents = call.argument<String>("contents")
                    if (fileName.isNullOrEmpty() || contents.isNullOrEmpty()) {
                        result.error(
                            ENTRY_EXPORT_ERROR_CODE,
                            "Invalid export arguments.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val pathLabel = writeCsvExport(fileName, contents)
                        result.success(
                            mapOf(
                                "fileName" to fileName,
                                "pathLabel" to pathLabel
                            )
                        )
                    } catch (exception: Exception) {
                        result.error(
                            ENTRY_EXPORT_ERROR_CODE,
                            "Failed to write CSV export.",
                            exception.message
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ENTRY_IMPORT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                PICK_CSV_IMPORT_METHOD -> {
                    pickCsvImport(result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val AUTOMATION_LOCKSCREEN_MODE_SETTING =
            "com.wrait.flutter.debug.automation_lockscreen_mode"
        const val APP_LOCK_CHANNEL = "wrait/app_lock"
        const val DEVICE_ID_CHANNEL = "wrait/preferences"
        const val DEVICE_ID_ERROR_CODE = "device-id-unavailable"
        const val ENTRY_EXPORT_CHANNEL = "wrait/entry_export"
        const val ENTRY_EXPORT_ERROR_CODE = "entry-export-failed"
        const val ENTRY_IMPORT_CHANNEL = "wrait/entry_import"
        const val ENTRY_IMPORT_ERROR_CODE = "entry-import-failed"
        const val ENTRY_IMPORT_FILE_TOO_LARGE_ERROR_CODE = "entry-import-file-too-large"
        const val ENTRY_IMPORT_MAX_BYTES = 10 * 1024 * 1024
        const val EXPORT_DIRECTORY_NAME = "Wrait"
        const val GET_DEVICE_ID_METHOD = "getDeviceId"
        const val OPEN_SECURITY_SETTINGS_METHOD = "openSecuritySettings"
        const val PICK_CSV_IMPORT_METHOD = "pickCsvImport"
        const val WRITE_CSV_EXPORT_METHOD = "writeCsvExport"
        val ENTRY_IMPORT_MIME_TYPES = arrayOf(
            "text/csv",
            "application/csv",
            "text/comma-separated-values",
            "application/vnd.ms-excel",
            "text/*"
        )
    }

    private data class EntryImportMetadata(
        val fileName: String,
        val sizeBytes: Long?
    )

    private fun shouldEnableAutomationLockscreenMode(): Boolean {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            return false
        }

        return Settings.Global.getString(
            contentResolver,
            AUTOMATION_LOCKSCREEN_MODE_SETTING
        ) == "1"
    }

    private fun openSecuritySettings(): Boolean {
        val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val resolvedActivity = intent.resolveActivity(packageManager) ?: return false

        return try {
            intent.setClassName(
                resolvedActivity.packageName,
                resolvedActivity.className
            )
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun enableCaptureProtection() {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun pickCsvImport(result: MethodChannel.Result) {
        if (pendingEntryImportResult != null) {
            result.error(
                ENTRY_IMPORT_ERROR_CODE,
                "Another CSV import picker request is already active.",
                null
            )
            return
        }

        pendingEntryImportResult = result
        try {
            entryImportLauncher.launch(ENTRY_IMPORT_MIME_TYPES)
        } catch (exception: Exception) {
            pendingEntryImportResult = null
            result.error(
                ENTRY_IMPORT_ERROR_CODE,
                "Failed to launch the CSV import picker.",
                exception.message
            )
        }
    }

    private fun handlePickedCsvImport(uri: Uri?) {
        val result = pendingEntryImportResult ?: return
        pendingEntryImportResult = null

        if (uri == null) {
            result.success(null)
            return
        }

        try {
            val metadata = queryEntryImportMetadata(uri)
            if ((metadata.sizeBytes ?: 0) > ENTRY_IMPORT_MAX_BYTES) {
                throw EntryImportFileTooLargeException(
                    "Selected CSV import file exceeds the ${ENTRY_IMPORT_MAX_BYTES}-byte limit."
                )
            }
            val fileName = metadata.fileName.ifBlank { "import.csv" }
            val contents = readCsvImportContents(uri)

            result.success(
                mapOf(
                    "fileName" to fileName,
                    "contents" to contents
                )
            )
        } catch (exception: EntryImportFileTooLargeException) {
            result.error(
                ENTRY_IMPORT_FILE_TOO_LARGE_ERROR_CODE,
                "Selected CSV import file is too large.",
                exception.message
            )
        } catch (exception: Exception) {
            result.error(
                ENTRY_IMPORT_ERROR_CODE,
                "Failed to read CSV import.",
                exception.message
            )
        }
    }

    private fun queryEntryImportMetadata(uri: Uri): EntryImportMetadata {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null
        )?.use {
            var fileName = ""
            var sizeBytes: Long? = null
            if (it.moveToFirst()) {
                val displayNameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (displayNameIndex >= 0) {
                    fileName = it.getString(displayNameIndex) ?: ""
                }
                val sizeIndex = it.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex >= 0 && !it.isNull(sizeIndex)) {
                    sizeBytes = it.getLong(sizeIndex)
                }
            }
            return EntryImportMetadata(
                fileName = fileName.ifBlank { uri.lastPathSegment ?: "" },
                sizeBytes = sizeBytes
            )
        }

        return EntryImportMetadata(
            fileName = uri.lastPathSegment ?: "",
            sizeBytes = null
        )
    }

    private fun readCsvImportContents(uri: Uri): String {
        val bytes = contentResolver.openInputStream(uri)?.use { inputStream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            var totalBytes = 0

            while (true) {
                val readCount = inputStream.read(buffer)
                if (readCount <= 0) {
                    break
                }

                totalBytes += readCount
                if (totalBytes > ENTRY_IMPORT_MAX_BYTES) {
                    throw EntryImportFileTooLargeException(
                        "Selected CSV import file exceeds the ${ENTRY_IMPORT_MAX_BYTES}-byte limit."
                    )
                }
                output.write(buffer, 0, readCount)
            }

            output.toByteArray()
        } ?: throw IOException("Failed to open CSV import stream.")

        if (bytes.isEmpty()) {
            throw IOException("Selected CSV import file was empty.")
        }

        return bytes.toString(Charsets.UTF_8)
    }

    private class EntryImportFileTooLargeException(message: String) : IOException(message)

    private fun writeCsvExport(fileName: String, contents: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            writeCsvExportToMediaStore(fileName, contents)
        } else {
            writeCsvExportToAppExternalDownloads(fileName, contents)
        }
    }

    private fun writeCsvExportToMediaStore(fileName: String, contents: String): String {
        val resolver = contentResolver
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$EXPORT_DIRECTORY_NAME"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("Failed to create MediaStore entry.")
        try {
            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(contents.toByteArray(Charsets.UTF_8))
            } ?: throw IOException("Failed to open MediaStore output stream.")

            val completedValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            val updateCount = resolver.update(uri, completedValues, null, null)
            if (updateCount <= 0) {
                throw IOException("Failed to finalize MediaStore entry.")
            }
            return "Downloads/$EXPORT_DIRECTORY_NAME"
        } catch (exception: Exception) {
            runCatching {
                resolver.delete(uri, null, null)
            }.onFailure { cleanupError ->
                exception.addSuppressed(cleanupError)
            }
            throw exception
        }
    }

    private fun writeCsvExportToAppExternalDownloads(fileName: String, contents: String): String {
        val downloadsDirectory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IOException("App external downloads directory unavailable.")
        val exportDirectory = File(downloadsDirectory, EXPORT_DIRECTORY_NAME)
        if (!exportDirectory.exists() && !exportDirectory.mkdirs()) {
            throw IOException("Failed to create export directory.")
        }

        val outputFile = File(exportDirectory, fileName)
        outputFile.writeText(contents, Charsets.UTF_8)
        return "App Downloads/$EXPORT_DIRECTORY_NAME (app-specific)"
    }
}
