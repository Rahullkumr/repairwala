package com.theekhogaya.theek_ho_gaya

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "theek/whatsapp")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareToChat") {
                    val phone = call.argument<String>("phone") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    result.success(shareToChat(phone, text, paths))
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun isInstalled(pkg: String): Boolean {
        return try {
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun mimeFor(file: File): String {
        val n = file.name.lowercase()
        return when {
            n.endsWith(".png") -> "image/png"
            n.endsWith(".jpg") || n.endsWith(".jpeg") -> "image/jpeg"
            n.endsWith(".mp3") -> "audio/mpeg"
            else -> "*/*"
        }
    }

    private fun shareToChat(phone: String, text: String, paths: List<String>): Boolean {
        val pkg = when {
            isInstalled("com.whatsapp") -> "com.whatsapp"
            isInstalled("com.whatsapp.w4b") -> "com.whatsapp.w4b"
            else -> return false
        }
        try {
            val files = paths.map { File(it) }
            val uris = ArrayList<Uri>()
            for (f in files) {
                uris.add(FileProvider.getUriForFile(this, "$packageName.fileprovider", f))
            }
            val intent = Intent()
            if (uris.size > 1) {
                intent.action = Intent.ACTION_SEND_MULTIPLE
                intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                val types = files.map { mimeFor(it) }.toSet()
                intent.type = if (types.size == 1) types.first() else "*/*"
            } else if (uris.size == 1) {
                intent.action = Intent.ACTION_SEND
                intent.putExtra(Intent.EXTRA_STREAM, uris[0])
                intent.type = mimeFor(files[0])
            } else {
                intent.action = Intent.ACTION_SEND
                intent.type = "text/plain"
            }
            intent.setPackage(pkg)
            intent.putExtra("jid", "$phone@s.whatsapp.net")
            intent.putExtra(Intent.EXTRA_TEXT, text)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(intent)
            return true
        } catch (e: ActivityNotFoundException) {
            return false
        } catch (e: Exception) {
            return false
        }
    }
}
