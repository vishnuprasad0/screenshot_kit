package com.vishnuprasadkp.screenshot_kit

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Captures the whole app window, including platform views, as PNG bytes. */
class ScreenshotKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var executor: ExecutorService? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "screenshot_kit")
        channel.setMethodCallHandler(this)
        executor = Executors.newSingleThreadExecutor()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor?.shutdown()
        executor = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method != "captureScreen") {
            result.notImplemented()
            return
        }
        val current = activity
        if (current == null) {
            result.error("no_activity", "No foreground activity to capture.", null)
            return
        }
        capture(current, result)
    }

    private fun capture(activity: Activity, result: Result) {
        val window = activity.window
        val root = window.decorView
        if (root.width <= 0 || root.height <= 0) {
            result.error("no_window", "The window has no size yet.", null)
            return
        }
        val screen = try {
            Bitmap.createBitmap(root.width, root.height, Bitmap.Config.ARGB_8888)
        } catch (e: OutOfMemoryError) {
            result.error("out_of_memory", "Could not allocate the capture bitmap.", null)
            return
        }

        val onWindowCopied = {
            val surfaces = mutableListOf<SurfaceView>()
            collectSurfaces(root, surfaces)
            overlaySurfaces(screen, surfaces, 0) { encode(screen, result) }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                PixelCopy.request(window, screen, { code ->
                    if (code == PixelCopy.SUCCESS) {
                        onWindowCopied()
                    } else {
                        screen.recycle()
                        result.error("capture_failed", "Window copy failed with code $code.", null)
                    }
                }, mainHandler)
            } catch (e: IllegalArgumentException) {
                screen.recycle()
                result.error("capture_failed", e.message, null)
            }
        } else {
            // Window PixelCopy needs API 26; older devices draw the view tree.
            root.draw(Canvas(screen))
            onWindowCopied()
        }
    }

    private fun collectSurfaces(view: View, into: MutableList<SurfaceView>) {
        if (view.visibility != View.VISIBLE) return
        if (view is SurfaceView) into.add(view)
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) collectSurfaces(view.getChildAt(i), into)
        }
    }

    // A window copy leaves SurfaceViews (Flutter's own surface, maps, web views)
    // black or empty, so each one is copied separately and drawn on top.
    private fun overlaySurfaces(
        screen: Bitmap,
        surfaces: List<SurfaceView>,
        index: Int,
        done: () -> Unit,
    ) {
        if (index >= surfaces.size) return done()
        val surface = surfaces[index]
        if (surface.width <= 0 || surface.height <= 0 || !surface.holder.surface.isValid) {
            return overlaySurfaces(screen, surfaces, index + 1, done)
        }
        val bitmap = Bitmap.createBitmap(surface.width, surface.height, Bitmap.Config.ARGB_8888)
        try {
            PixelCopy.request(surface, bitmap, { code ->
                if (code == PixelCopy.SUCCESS) {
                    val location = IntArray(2)
                    surface.getLocationInWindow(location)
                    Canvas(screen).drawBitmap(bitmap, location[0].toFloat(), location[1].toFloat(), null)
                }
                bitmap.recycle()
                overlaySurfaces(screen, surfaces, index + 1, done)
            }, mainHandler)
        } catch (e: IllegalArgumentException) {
            // The surface was released after the validity check; skip it.
            bitmap.recycle()
            overlaySurfaces(screen, surfaces, index + 1, done)
        }
    }

    private fun encode(screen: Bitmap, result: Result) {
        val pool = executor
        if (pool == null) {
            screen.recycle()
            result.error("capture_failed", "Plugin detached.", null)
            return
        }
        pool.execute {
            try {
                val out = ByteArrayOutputStream()
                screen.compress(Bitmap.CompressFormat.PNG, 100, out)
                val bytes = out.toByteArray()
                mainHandler.post { result.success(bytes) }
            } catch (e: Exception) {
                mainHandler.post { result.error("encode_failed", e.message, null) }
            } finally {
                screen.recycle()
            }
        }
    }
}
