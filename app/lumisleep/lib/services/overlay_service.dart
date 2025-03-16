import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lumisleep/utils/brightness_control.dart';

class OverlayService {
  static bool _isRunning = false;
  static Timer? _updateTimer;
  static double _currentFrequency = 30.0;
  static double _minOpacity = 0.0;
  static double _maxOpacity = 0.6;
  static int _currentOpacity = 50; // Value from 0 to 255
  static double _defaultBrightness = 0.5; // Default system brightness
  static bool _useBrightnessControl =
      true; // Set to true to use brightness control
  static bool _useOverlay = false; // Disable overlay

  /// Initialize overlay service (e.g. request overlay permission)
  static Future<void> initialize() async {
    // Save the current brightness to restore it later
    try {
      await BrightnessControl.saveBrightness();

      // Keep the screen on during sessions
      await BrightnessControl.keepScreenOn(true);

      // Optionally initialize overlay window as well
      if (_useOverlay) {
        final bool status = await FlutterOverlayWindow.isPermissionGranted();
        if (!status) {
          final bool? granted = await FlutterOverlayWindow.requestPermission();
          if (granted != true) {
            debugPrint("Overlay permission was denied.");
          }
        }
      }
    } catch (e) {
      debugPrint("Error initializing brightness control: $e");
      // Fallback to overlay method if brightness control fails
      _useBrightnessControl = false;
      _useOverlay = true;
    }
  }

  // Start the overlay and begin periodic updates
  static Future<bool> startOverlay({
    required double frequency,
    required double minOpacity,
    required double maxOpacity,
    bool debugMode = false,
  }) async {
    if (_isRunning) return true;

    _currentFrequency = frequency;
    _minOpacity = minOpacity;
    _maxOpacity = maxOpacity;

    // Try to save current brightness
    try {
      _defaultBrightness = await BrightnessControl.getBrightness();
      if (debugMode) {
        debugPrint("Current brightness: $_defaultBrightness");
      }
    } catch (e) {
      debugPrint("Could not get current brightness: $e");
    }

    // IMPORTANT CHANGE: Never use overlay window, as it closes the app
    _useOverlay = false;

    _isRunning = true;

    // Keep the screen on
    if (!debugMode) {
      await BrightnessControl.keepScreenOn(true);
    }

    // Allow a short delay before starting updates
    await Future.delayed(const Duration(milliseconds: 500));
    _startUpdating(debugMode);
    return true;
  }

  static void _startUpdating([bool debugMode = false]) {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateOverlayOpacity(debugMode);
    });
  }

  static void _updateOverlayOpacity([bool debugMode = false]) {
    if (!_isRunning) return;
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final wave = sin(2 * pi * _currentFrequency * time);
    final normalized = (wave + 1) / 2; // value between 0 and 1
    final computedOpacity =
        _minOpacity + normalized * (_maxOpacity - _minOpacity);
    _currentOpacity = (computedOpacity * 255).round();

    // Update brightness if enabled
    if (_useBrightnessControl) {
      // Map opacity to brightness (0.0 to 1.0)
      // Use a narrower range like 0.05 to 0.6 to avoid extremes
      final minBrightness = 0.05; // Avoid going completely dark
      final maxBrightness = 0.6; // Avoid going too bright
      final brightness =
          minBrightness + normalized * (maxBrightness - minBrightness);

      try {
        // In debug mode, print the brightness but don't actually change it
        if (debugMode) {
          debugPrint("Would set brightness to: $brightness");
        } else {
          BrightnessControl.setBrightness(brightness);
        }
      } catch (e) {
        debugPrint("Error setting brightness: $e");
      }
    }

    // Also update the state stream for your in-app overlay widget
    try {
      OverlayStateManager.getInstance()
          .updateState(_currentOpacity, _currentFrequency);
    } catch (e) {
      debugPrint("Error updating overlay state: $e");
    }
  }

  static void updateFrequency(double frequency) {
    _currentFrequency = frequency;
  }

  static Future<void> stopOverlay() async {
    if (!_isRunning) return;
    _updateTimer?.cancel();

    // Restore default brightness
    if (_useBrightnessControl) {
      try {
        await BrightnessControl.restoreBrightness();
        await BrightnessControl.resetBrightness();
        await BrightnessControl.keepScreenOn(false);
      } catch (e) {
        debugPrint("Error restoring brightness: $e");
      }
    }

    // Close overlay if needed
    if (_useOverlay) {
      // await FlutterOverlayWindow.closeOverlay();
    }

    _isRunning = false;
  }
}

class OverlayWidget extends StatefulWidget {
  @override
  _OverlayWidgetState createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  double opacity = 0.3;
  double frequency = 30.0;

  @override
  void initState() {
    super.initState();
    OverlayStateManager.getInstance().stateStream.listen((data) {
      if (mounted) {
        setState(() {
          opacity = (data['opacity'] as int) / 255;
          frequency = data['frequency'] as double;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black.withOpacity(opacity),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              onPressed: () {
                FlutterOverlayWindow.shareData("STOP");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.5),
                minimumSize: const Size(60, 40),
                padding: const EdgeInsets.all(8),
              ),
              child: const Text("STOP", style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }
}

class SleepSessionManager {
  String? _lastError;

  Future<bool> checkAndRequestOverlayPermission() async {
    try {
      final bool hasPermission =
          await FlutterOverlayWindow.isPermissionGranted();
      if (!hasPermission) {
        return await FlutterOverlayWindow.requestPermission() ?? false;
      }
      return true;
    } catch (e) {
      _lastError = "Overlay permission error: ${e.toString()}";
      debugPrint(_lastError);
      return false;
    }
  }
}

// Add this class to your overlay_service.dart file
class OverlayStateManager {
  // Singleton instance
  static final OverlayStateManager _instance = OverlayStateManager._internal();
  static OverlayStateManager getInstance() => _instance;

  // Private constructor
  OverlayStateManager._internal();

  // Stream controller for state updates
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  // Method to update state
  void updateState(int opacity, double frequency) {
    _stateController.add({
      'opacity': opacity,
      'frequency': frequency,
    });
  }

  // Close the stream when done
  void dispose() {
    _stateController.close();
  }
}
