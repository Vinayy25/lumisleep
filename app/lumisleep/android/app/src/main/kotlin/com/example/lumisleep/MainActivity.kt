package com.example.lumisleep

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "brightness_channel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSystemBrightness" -> {
                    val brightness = call.arguments as Double
                    setBrightness(brightness, result)
                }
                "getBrightness" -> {
                    result.success(getBrightness())
                }
                "resetSystemBrightness" -> {
                    resetBrightness(result)
                }
                "hasBrightnessPermission" -> {
                    result.success(Settings.System.canWrite(applicationContext))
                }
                "requestBrightnessPermission" -> {
                    val granted = requestWriteSettingsPermission()
                    result.success(granted)
                }
                "keepScreenOn" -> {
                    val keepOn = call.arguments as Boolean
                    keepScreenOn(keepOn)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getBrightness(): Double {
        return try {
            val brightness = Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS)
            brightness / 255.0
        } catch (e: Exception) {
            0.5 // Default to 50% brightness if there's an error
        }
    }

    private fun setBrightness(brightness: Double, result: MethodChannel.Result) {
        if (Settings.System.canWrite(applicationContext)) {
            try {
                // Convert 0.0-1.0 to 0-255
                val brightnessValue = (brightness * 255).toInt().coerceIn(1, 255)
                
                // Set manual brightness mode
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                )
                
                // Update brightness
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    brightnessValue
                )
                
                // Also update the window brightness
                val layoutParams = window.attributes
                layoutParams.screenBrightness = brightness.toFloat()
                window.attributes = layoutParams
                
                result.success(true)
            } catch (e: Exception) {
                result.error("BRIGHTNESS_ERROR", e.message, null)
            }
        } else {
            result.error("PERMISSION_NEEDED", "WRITE_SETTINGS permission required", null)
        }
    }
    
    private fun resetBrightness(result: MethodChannel.Result) {
        try {
            // Set auto brightness mode
            Settings.System.putInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
            )
            
            // Reset window brightness
            val layoutParams = window.attributes
            layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            window.attributes = layoutParams
            
            result.success(true)
        } catch (e: Exception) {
            result.error("BRIGHTNESS_ERROR", e.message, null)
        }
    }
    
    private fun requestWriteSettingsPermission(): Boolean {
        if (Settings.System.canWrite(applicationContext)) {
            return true
        } else {
            try {
                // This intent opens system settings where user can grant permission
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)  // Add this flag!
                startActivity(intent)
                Log.d("BrightnessControl", "Launched settings screen for WRITE_SETTINGS permission")
                
                // Return false as permission isn't granted immediately
                return false
            } catch (e: Exception) {
                Log.e("BrightnessControl", "Error opening settings: ${e.message}")
                return false
            }
        }
    }
    
    private fun keepScreenOn(on: Boolean) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
