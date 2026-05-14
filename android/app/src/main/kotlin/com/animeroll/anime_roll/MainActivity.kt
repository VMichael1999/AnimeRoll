package com.animeroll.anime_roll

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "anime_roll/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveVideo" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val displayName = call.argument<String>("displayName") ?: "AnimeRoll.mp4"
                    val mimeType = call.argument<String>("mimeType") ?: "video/mp4"
                    if (sourcePath.isNullOrBlank()) {
                        result.error("invalid_source", "sourcePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(saveVideo(sourcePath, displayName, mimeType))
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveVideo(sourcePath: String, displayName: String, mimeType: String): String {
        val source = File(sourcePath)
        if (!source.exists()) {
            throw IllegalArgumentException("File does not exist")
        }

        val resolver = applicationContext.contentResolver
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }

        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Video.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/AnimeRoll")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }

        val item = resolver.insert(collection, values) ?: throw IllegalStateException("Could not create MediaStore item")
        resolver.openOutputStream(item)?.use { output ->
            FileInputStream(source).use { input -> input.copyTo(output) }
        } ?: throw IllegalStateException("Could not open output stream")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(item, values, null, null)
        }

        return item.toString()
    }
}
