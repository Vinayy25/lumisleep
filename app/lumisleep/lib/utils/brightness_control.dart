import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class BrightnessControl {
  static const _channel = MethodChannel('brightness_channel');
  static double _savedBrightness = 0.5;

  // Get current brightness
  static Future<double> getBrightness() async {
    try {
      final double brightness = await _channel.invokeMethod('getBrightness');
      return brightness;
    } on PlatformException catch (e) {
      debugPrint("Error getting brightness: ${e.message}");
      return 0.5; // Default fallback
    }
  }

  // Save current brightness for later restoration
  static Future<void> saveBrightness() async {
    try {
      _savedBrightness = await getBrightness();
    } on PlatformException catch (e) {
      debugPrint("Error saving brightness: ${e.message}");
    }
  }

  // Set brightness (0.0 to 1.0)
  static Future<bool> setBrightness(double brightness) async {
    try {
      await _channel.invokeMethod(
          'setSystemBrightness', brightness.clamp(0.01, 1.0));
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_NEEDED') {
        // Handle Android permission request
        final bool granted = await _requestAndroidPermission();
        if (granted) {
          return await setBrightness(brightness); // Retry after permission
        }
      }
      debugPrint("Error setting brightness: ${e.message}");
      return false;
    }
  }

  // Restore previously saved brightness
  static Future<bool> restoreBrightness() async {
    return await setBrightness(_savedBrightness);
  }

  // Reset to system controlled brightness (Android)
  static Future<bool> resetBrightness() async {
    try {
      await _channel.invokeMethod('resetSystemBrightness');
      return true;
    } on PlatformException catch (e) {
      debugPrint("Error resetting brightness: ${e.message}");
      return false;
    }
  }

  // Keep screen on
  static Future<bool> keepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod('keepScreenOn', on);
      return true;
    } on PlatformException catch (e) {
      debugPrint("Error setting screen on: ${e.message}");
      return false;
    }
  }

  static Future<bool> _requestAndroidPermission() async {
    return await requestPermission(); // Use the public method
  }

  // Check if we have permission to modify brightness
  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod('hasBrightnessPermission');
    } on PlatformException catch (e) {
      debugPrint("Error checking permission: ${e.message}");
      return false;
    }
  }

  // Add this public method to request permission
  static Future<bool> requestPermission() async {
    try {
      final bool granted =
          await _channel.invokeMethod('requestBrightnessPermission');
      return granted;
    } on PlatformException catch (e) {
      debugPrint("Error requesting brightness permission: ${e.message}");
      return false;
    }
  }
}
