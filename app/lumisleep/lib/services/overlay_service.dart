import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static bool _isRunning = false;
  static Timer? _updateTimer;
  static double _currentFrequency = 30.0;
  static double _minOpacity = 0.0;
  static double _maxOpacity = 0.6;
  static int _currentOpacity = 50; // Value from 0 to 255

  /// Initialize overlay service (e.g. request overlay permission)
  static Future<void> initialize() async {
    // For example, check if permission is granted, and request if not:
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      final bool? granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) {
        debugPrint("Overlay permission was denied.");
      }
    }
    // You can perform further initialization if needed.
  }

  // Start the overlay and begin periodic updates
  static Future<bool> startOverlay({
    required double frequency,
    required double minOpacity,
    required double maxOpacity,
  }) async {
    if (_isRunning) return true;

    _currentFrequency = frequency;
    _minOpacity = minOpacity;
    _maxOpacity = maxOpacity;

    // Check overlay permission
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      final bool? granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) {
        debugPrint("Overlay permission denied");
        return false;
      }
    }

    // Show the overlay over other apps
    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      height: WindowSize.fullCover,
      width: WindowSize.fullCover,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.defaultFlag,
    );

    _isRunning = true;
    // Allow a short delay before starting updates
    await Future.delayed(const Duration(milliseconds: 500));
    _startUpdating();
    return true;
  }

  static void _startUpdating() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateOverlayOpacity();
    });
  }

  static void _updateOverlayOpacity() {
    if (!_isRunning) return;
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final wave = sin(2 * pi * _currentFrequency * time);
    final normalized = (wave + 1) / 2; // value between 0 and 1
    final computedOpacity =
        _minOpacity + normalized * (_maxOpacity - _minOpacity);
    _currentOpacity = (computedOpacity * 255).round();

    // Share overlay update with the overlay widget
    FlutterOverlayWindow.shareData({
      "type": "update_opacity",
      "opacity": _currentOpacity,
      "frequency": _currentFrequency
    });

    // Also update the state stream for your in-app overlay widget
    OverlayStateManager.getInstance()
        .updateState(_currentOpacity, _currentFrequency);
  }

  static void updateFrequency(double frequency) {
    _currentFrequency = frequency;
  }

  static Future<void> stopOverlay() async {
    if (!_isRunning) return;
    _updateTimer?.cancel();
    await FlutterOverlayWindow.closeOverlay();
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
