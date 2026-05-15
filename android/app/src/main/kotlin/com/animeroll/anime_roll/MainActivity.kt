package com.animeroll.anime_roll

import android.content.ComponentName
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "anime_roll/media_store"
    private val iconChannelName = "anime_roll/app_icon"

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
                "deleteVideo" -> {
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(deleteVideo(uri))
                    } catch (error: Exception) {
                        result.error("delete_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iconChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "setIconStyle" -> {
                    val style = call.argument<String>("style") ?: "violeta"
                    try {
                        setIconStyle(style)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("icon_swap_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setIconStyle(style: String) {
        val mainActivity = "com.animeroll.anime_roll.MainActivity"
        val aliases = mapOf(
            "oceano" to "com.animeroll.anime_roll.MainActivityOceano",
            "carmesi" to "com.animeroll.anime_roll.MainActivityCarmesi",
            "esmeralda" to "com.animeroll.anime_roll.MainActivityEsmeralda"
        )
        val packageManager = applicationContext.packageManager
        val selectedAlias = aliases[style]

        // violeta (default) = MainActivity enabled, all aliases disabled.
        // others = MainActivity disabled, only the target alias enabled.
        // (Android requires exactly one LAUNCHER-eligible component enabled to
        // avoid the dual-icon glitch in the launcher.)
        packageManager.setComponentEnabledSetting(
            ComponentName(applicationContext, mainActivity),
            if (selectedAlias == null) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            PackageManager.DONT_KILL_APP
        )

        aliases.forEach { (_, alias) ->
            packageManager.setComponentEnabledSetting(
                ComponentName(applicationContext, alias),
                if (alias == selectedAlias) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                },
                PackageManager.DONT_KILL_APP
            )
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

    private fun deleteVideo(uri: String): Boolean {
        val deleted = applicationContext.contentResolver.delete(Uri.parse(uri), null, null)
        return deleted > 0
    }
}
