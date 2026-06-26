package com.henryezeanyim.nketa

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "nketa/gallery"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "saveImageToGallery") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    val success = saveImageToGallery(this, filePath)
                    result.success(success)
                } else {
                    result.error("NO_PATH", "No file path provided", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveImageToGallery(context: Context, filePath: String): Boolean {
        return try {
            val file = File(filePath)
            val filename = file.name
            val mimeType = "image/png"
            val fos: OutputStream?

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                }
                val imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                fos = imageUri?.let { resolver.openOutputStream(it) }
            } else {
                val imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val destFile = File(imagesDir, filename)
                fos = destFile.outputStream()
            }

            val inputStream = FileInputStream(file)
            fos?.use { output ->
                inputStream.copyTo(output)
            }
            inputStream.close()
            fos?.close()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
