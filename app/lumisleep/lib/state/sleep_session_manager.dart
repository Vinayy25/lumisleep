import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:io';
import 'package:lumisleep/utils/brightness_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:lumisleep/services/overlay_service.dart';

// Create a custom overlay service that doesn't depend on third-party packages
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SimpleOverlayService {
  static const platform = MethodChannel('app.lumisleep/overlay');
  static bool _isRunning = false;
  static Timer? _updateTimer;
  static double _currentFrequency = 30.0;
  static double _minOpacity = 0.0;
  static double _maxOpacity = 0.5;
  static int _currentOpacity = 0;

  static Future<void> initialize() async {
    // No special initialization needed
  }

  static Future<void> startOverlay({
    required double frequency,
    required double minOpacity,
    required double maxOpacity,
  }) async {
    if (_isRunning) return;

    _currentFrequency = frequency;
    _minOpacity = minOpacity;
    _maxOpacity = maxOpacity;

    try {
      await platform.invokeMethod('startOverlay');
      _isRunning = true;
      _updateTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        _updateOverlayOpacity();
      });
    } catch (e) {
      print('Error starting overlay: $e');
    }
  }

  static void updateFrequency(double frequency) {
    _currentFrequency = frequency;

    if (_isRunning) {
      platform.invokeMethod('updateOverlay', {
        'frequency': frequency,
      });
    }
  }

  static Future<void> stopOverlay() async {
    if (!_isRunning) return;

    _updateTimer?.cancel();
    await platform.invokeMethod('stopOverlay');
    _isRunning = false;
  }

  static void _updateOverlayOpacity() {
    if (!_isRunning) return;

    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final wave = sin(2 * pi * _currentFrequency * time);
    final normalized = (wave + 1) / 2; // Convert from [-1,1] to [0,1]

    // Map to opacity range
    final opacity = _minOpacity + normalized * (_maxOpacity - _minOpacity);
    _currentOpacity = (opacity * 255).round();

    // Update state for the overlay widget
    OverlayStateManager.getInstance()
        .updateState(_currentOpacity, _currentFrequency);

    // Use shareData instead of sendData
    FlutterOverlayWindow.shareData({
      "type": "update_opacity",
      "opacity": _currentOpacity,
      "frequency": _currentFrequency
    });
  }
}

enum SessionState { idle, running, paused, error }

class SleepSessionManager with ChangeNotifier {
  // Add debug mode flag
  bool debugMode = false; // Set to true during development

  // Session configuration
  double startFrequency = 30.0;
  double endFrequency = 7.0;
  double currentFrequency = 20.0;
  SessionState _state = SessionState.idle;
  bool useVibration = true;
  Duration sessionDuration = const Duration(minutes: 15);
  String? _lastError;

  // Animation control
  double currentBrightness = 0.5;
  double minBrightness = 0.2;
  double maxBrightness = 0.8;
  double defaultBrightness = 0.5;
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;

  // Platform capabilities
  bool _canControlBrightness = true;
  bool _isInitialized = false;

  // Timers
  Timer? _frequencyTimer;
  Timer? _pulseTimer;
  Timer? _vibrationTimer;
  Timer? _notificationUpdateTimer;
  DateTime? _sessionEndTime;
  DateTime? _sessionPausedAt;
  Duration? _remainingTimeAtPause;
  bool isActive = false;

  // Add this line with your other class properties (around line 145)
  double _savedBrightness = 0.5;

  // Get current session state
  SessionState get state => _state;
  bool get isRunning => _state == SessionState.running;
  bool get isPaused => _state == SessionState.paused;
  bool get hasError => _state == SessionState.error;
  String? get lastError => _lastError;

  // Get remaining session time in seconds
  int get remainingTimeSeconds {
    if (_state == SessionState.paused && _remainingTimeAtPause != null) {
      return _remainingTimeAtPause!.inSeconds;
    }

    if (_sessionEndTime == null || _state != SessionState.running) return 0;
    final remaining = _sessionEndTime!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  // Get remaining session time as formatted string
  String get remainingTimeFormatted {
    final seconds = remainingTimeSeconds;

    // Format differently based on duration
    if (seconds < 60) {
      return '$seconds sec';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  // Get session progress as percentage (0-100)
  double get sessionProgressPercent {
    if (_state != SessionState.running && _state != SessionState.paused)
      return 0;
    final totalSeconds = sessionDuration.inSeconds;
    final remaining = remainingTimeSeconds;
    final progress = (totalSeconds - remaining) / totalSeconds * 100;
    return progress.clamp(0.0, 100.0);
  }

  // Initialize manager and detect device capabilities
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check vibration capabilities with detailed logging
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;

      debugPrint("==== VIBRATION CAPABILITIES ====");
      debugPrint("Device has vibrator: $_hasVibrator");
      debugPrint("Device has amplitude control: $_hasAmplitudeControl");

      if (_hasVibrator) {
        debugPrint("Testing vibration...");
        await Vibration.vibrate(duration: 100);
        debugPrint("Vibration test completed");
      }

      // ... rest of the initialize method

      // Initialize the overlay service
      await OverlayService.initialize();

      // Save default brightness for restoration later using BrightnessControl
      defaultBrightness = await BrightnessControl.getBrightness();

      // Check if device has vibration capabilities
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;

      debugPrint(
          "Vibration available: $_hasVibrator, amplitude control: $_hasAmplitudeControl");

      // Test vibration to ensure it works
      if (_hasVibrator) {
        Vibration.vibrate(duration: 100);
        debugPrint("Vibration test performed");
      }

      // Check brightness control permission
      _canControlBrightness = await BrightnessControl.hasPermission();
      debugPrint("Brightness control permission: $_canControlBrightness");

      // Load saved preferences
      await _loadPreferences();

      _isInitialized = true;
    } catch (e) {
      _lastError = "Failed to initialize: ${e.toString()}";
      _state = SessionState.error;
      debugPrint(_lastError);
    }
  }

  // Load user preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load session duration (default 15min, or 900 seconds)
      final seconds = prefs.getInt('sessionDurationSeconds') ?? 900;
      sessionDuration = Duration(seconds: seconds);

      // Load vibration preference (default true)
      useVibration = prefs.getBool('useVibration') ?? true;

      // Load brightness range
      minBrightness = prefs.getDouble('minBrightness') ?? 0.2;
      maxBrightness = prefs.getDouble('maxBrightness') ?? 0.8;

      // Load frequency range
      startFrequency = prefs.getDouble('startFrequency') ?? 30.0;
      endFrequency = prefs.getDouble('endFrequency') ?? 7.0;
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      // Use defaults if preferences can't be loaded
    }
  }

  // Save user preferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sessionDurationSeconds', sessionDuration.inSeconds);
      await prefs.setBool('useVibration', useVibration);
      await prefs.setDouble('minBrightness', minBrightness);
      await prefs.setDouble('maxBrightness', maxBrightness);
      await prefs.setDouble('startFrequency', startFrequency);
      await prefs.setDouble('endFrequency', endFrequency);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  // Set session duration in minutes
  Future<void> setSessionDuration(int minutes) async {
    await setSessionDurationFromSeconds(minutes * 60);
  }

  // Add this new method to set duration in seconds
  Future<void> setSessionDurationFromSeconds(int seconds) async {
    if (_state == SessionState.running) return;

    sessionDuration = Duration(seconds: seconds);
    await _savePreferences();
    notifyListeners();
  }

  // Set brightness range
  Future<void> setBrightnessRange(double min, double max) async {
    if (_state == SessionState.running) return;

    minBrightness = min.clamp(0.1, 0.5);
    maxBrightness = max.clamp(0.5, 1.0);
    await _savePreferences();
    notifyListeners();
  }

  // Set frequency range
  Future<void> setFrequencyRange(double start, double end) async {
    if (_state == SessionState.running) return;

    // Safety checks for frequency ranges
    startFrequency = start.clamp(5.0, 40.0);
    endFrequency = end.clamp(5.0, startFrequency);
    await _savePreferences();
    notifyListeners();
  }

  // Toggle vibration
  Future<void> toggleVibration(bool value) async {
    useVibration = value;

    // Update active vibration if session is running
    if (_state == SessionState.running) {
      if (useVibration) {
        await _startVibrationTimer();
      } else if (_vibrationTimer != null) {
        _vibrationTimer?.cancel();
        await Vibration.cancel();
      }
    }

    await _savePreferences();
    notifyListeners();
  }

  // Check permissions and capabilities
  Future<bool> _checkPermissions() async {
    // Check if we can control brightness
    try {
      final brightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(brightness);
      _canControlBrightness = true;
    } catch (e) {
      _canControlBrightness = false;
      debugPrint('Cannot control brightness: $e');
    }

    // Don't block the session for permissions - just return success
    return true;
  }

  // Your startSession method can now use _savedBrightness without errors
  Future<bool> startSession(BuildContext context) async {
    if (_state == SessionState.running) return true;

    try {
      debugPrint("Starting sleep session...");

      // First check Android permission for WRITE_SETTINGS
      if (debugMode) {
        debugPrint("Checking brightness control permissions...");
      }

      final hasPermission = await BrightnessControl.hasPermission();
      if (!hasPermission) {
        if (debugMode) {
          debugPrint("No permission to control brightness, requesting...");
          // Show a message to the user
          _lastError = "Need WRITE_SETTINGS permission (debug mode)";
          notifyListeners();
          return false;
        } else {
          // Show a dialog explaining what to do
          _showPermissionDialog(context);

          // Request permissions - this should open system settings
          final granted = await BrightnessControl.requestPermission();
          if (!granted) {
            _lastError = "Please enable 'Modify system settings' permission";
            _state = SessionState.error;
            notifyListeners();
            return false;
          }
        }
      }

      if (debugMode) {
        debugPrint("Saving current brightness...");
      }

      // Save current brightness
      await BrightnessControl.saveBrightness();

      if (debugMode) {
        debugPrint("Starting overlay service...");
      }

      // Start the overlay service with debugging disabled in debug mode
      final started = await OverlayService.startOverlay(
        frequency: currentFrequency,
        minOpacity: 0.0,
        maxOpacity: 0.6,
        debugMode: debugMode,
      );

      if (started) {
        _state = SessionState.running;
        // Start timer for session duration
        if (debugMode) {
          debugPrint("Starting session timer...");
        }
        _startSessionTimer();
        notifyListeners();
        return true;
      } else {
        _lastError = "Failed to start overlay";
        _state = SessionState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = "Start session error: ${e.toString()}";
      _state = SessionState.error;

      // Print detailed error info for debugging
      debugPrint("ERROR STARTING SESSION: $e");
      if (e is Error) {
        debugPrint("STACKTRACE: ${e.stackTrace}");
      }

      notifyListeners();
      return false;
    }
  }

  // Pause sleep session
  Future<void> pauseSession() async {
    if (_state != SessionState.running) return;

    try {
      _state = SessionState.paused;
      _sessionPausedAt = DateTime.now();
      _remainingTimeAtPause = Duration(seconds: remainingTimeSeconds);

      // Pause all timers
      _frequencyTimer?.cancel();
      _pulseTimer?.cancel();
      _vibrationTimer?.cancel();
      _notificationUpdateTimer?.cancel();

      // Reset brightness
      await ScreenBrightness().resetScreenBrightness();

      // Stop vibration
      if (_hasVibrator) {
        await Vibration.cancel();
      }

      notifyListeners();
    } catch (e) {
      _lastError = "Failed to pause session: ${e.toString()}";
      debugPrint(_lastError);
    }
  }

  // Make sure vibration is properly stopped
  Future<void> stopSession() async {
    if (_state == SessionState.idle) return;

    debugPrint("Stopping session...");

    // Cancel all the timers first
    _frequencyTimer?.cancel();
    _pulseTimer?.cancel();
    _vibrationTimer?.cancel();
    _notificationUpdateTimer?.cancel();

    // Stop vibration with extra care
    if (_hasVibrator) {
      try {
        await Vibration.cancel();
        // Additional cancel to make absolutely sure
        await Future.delayed(Duration(milliseconds: 100));
        await Vibration.cancel();
        debugPrint("✅ Vibration stopped successfully");
      } catch (e) {
        debugPrint("❌ Error stopping vibration: $e");
      }
    }

    // Rest of your stopSession method...
    // Stop the overlay
    await OverlayService.stopOverlay();

    // Reset screen brightness
    try {
      await BrightnessControl.resetBrightness();
      await BrightnessControl.restoreBrightness();
    } catch (e) {
      debugPrint("Error resetting brightness: $e");
    }

    // Allow screen to turn off again
    WakelockPlus.disable();

    // Stop foreground service if running
    if (Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    }

    _state = SessionState.idle;
    notifyListeners();
  }

  // Update Android notification periodically
  void _startNotificationUpdateTimer() {
    _notificationUpdateTimer?.cancel();
    _notificationUpdateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_state != SessionState.running) return;

      FlutterForegroundTask.updateService(
        notificationTitle: "Sleep session active",
        notificationText:
            "Pulsing at ${currentFrequency.toStringAsFixed(1)} Hz - ${remainingTimeFormatted} remaining",
      );
    });
  }

  // Gradually decrease frequency over time
  void _startFrequencyTimer() {
    double lastVibratedFrequency = currentFrequency;

    _frequencyTimer?.cancel();
    _frequencyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != SessionState.running) {
        timer.cancel();
        return;
      }

      try {
        final progress =
            1.0 - (remainingTimeSeconds / sessionDuration.inSeconds);
        currentFrequency =
            startFrequency - ((startFrequency - endFrequency) * progress);

        // Update overlay with new frequency
        OverlayService.updateFrequency(currentFrequency);

        // Update vibration if frequency has changed significantly
        // This helps vibration stay in sync with visual pulsing
        if (useVibration &&
            _hasVibrator &&
            (lastVibratedFrequency - currentFrequency).abs() > 0.5) {
          directVibrate();
          lastVibratedFrequency = currentFrequency;
        }

        // End session when time is up
        if (remainingTimeSeconds <= 0) {
          stopSession();
        }

        notifyListeners();
      } catch (e) {
        _lastError = "Frequency calculation error: ${e.toString()}";
        debugPrint(_lastError);
      }
    });
  }

  // Pulse brightness at current frequency
  void _startPulseTimer() {
    _pulseTimer?.cancel();

    void updateBrightness() async {
      if (_state != SessionState.running) return;
      if (!_canControlBrightness) return;

      try {
        // Calculate sine wave brightness
        final time = DateTime.now().millisecondsSinceEpoch / 1000;
        final wave = sin(2 * pi * currentFrequency * time);
        final normalized = (wave + 1) / 2; // Convert from [-1,1] to [0,1]

        // Map to brightness range
        currentBrightness =
            minBrightness + normalized * (maxBrightness - minBrightness);

        // Set system brightness instead of app brightness
        await BrightnessControl.setBrightness(currentBrightness);

        // Debug log to verify brightness changes
        if (DateTime.now().millisecondsSinceEpoch % 1000 < 50) {
          debugPrint(
              "System brightness set to: ${currentBrightness.toStringAsFixed(2)}");
        }
      } catch (e) {
        // If we get multiple errors, disable brightness control
        _canControlBrightness = false;
        _lastError = "Brightness control error: ${e.toString()}";
        debugPrint(_lastError);
      }
    }

    // Update brightness at 60fps for smooth animation
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      updateBrightness();
    });
  }
  List<int> generateDynamicPattern(double frequency) {
    // Calculate where we are in the frequency range (0 = start frequency, 1 = end frequency)
    double progress =
        (startFrequency - frequency) / (startFrequency - endFrequency);
    progress = progress.clamp(0.0, 1.0);

    debugPrint(
        "🔄 Generating pattern for frequency ${frequency.toStringAsFixed(1)}Hz (progress: ${(progress * 100).toStringAsFixed(0)}%)");

    // At the beginning (high frequency): shorter, faster pulses with more repetitions
    // At the end (low frequency): longer, slower pulses with fewer repetitions

    if (progress < 0.3) {
      // High frequency range (beginning of session)
      // Multiple short pulses for alertness
      return [0, 200, 150, 200, 150, 200, 150];
    } else if (progress < 0.6) {
      // Mid frequency range (middle of session)
      // Medium pulses for transition
      return [0, 250, 180, 250, 180];
    } else if (progress < 0.8) {
      // Lower frequency range (approaching end)
      // Longer, fewer pulses for relaxation
      return [0, 300, 200, 300, 200];
    } else {
      // Very low frequency (end of session)
      // Long, deep pulses for deep relaxation
      return [0, 400, 250, 400];
    }
  }


  // Generate vibration pattern at current frequency - DIRECT PORT FROM WORKING CODE
  Future<void> _startVibrationTimer() async {
    _vibrationTimer?.cancel();

    try {
      debugPrint(
          "🟢 Starting vibration timer with frequency ${currentFrequency.toStringAsFixed(1)} Hz");

      // Clean up any existing vibration first
      try {
        await Vibration.cancel();
        debugPrint("Cancelled existing vibration");
      } catch (e) {
        debugPrint("Error cancelling existing vibration: $e");
      }

      // We'll create a custom pattern based on current frequency
      void updateVibration() async {
        if (_state != SessionState.running || !useVibration) {
          await Vibration.cancel();
          return;
        }

        // Calculate interval based on current frequency
        final interval = (1000 / currentFrequency).round();

        // For higher frequencies, we'll use shorter pulses
        final pulseLength = (interval / 2).clamp(20, 200).round();

        // Intensity varies with frequency (higher freq = lower intensity)
        final intensity = _hasAmplitudeControl
            ? ((1 -
                        (currentFrequency - endFrequency) /
                            (startFrequency - endFrequency)) *
                    255)
                .round()
                .clamp(64, 255)
            : 255;

        debugPrint(
            "🟡 Vibrating with pattern: ON for ${pulseLength}ms, OFF for ${interval - pulseLength}ms, intensity $intensity");

        // Create pattern of alternating vibration/pause
        try {
          // IMPORTANT: Using a specific pattern format that worked in previous code
          final pattern = generateDynamicPattern(currentFrequency);



          if (_hasAmplitudeControl) {
            final intensities = [0, intensity, 0];
            debugPrint(
                "📳 Calling vibrate with pattern $pattern, intensities $intensities, repeat -1");

            await Vibration.vibrate(
              pattern: pattern,
              intensities: intensities,
              repeat: -1,
            );
          } else {
            debugPrint("📳 Calling vibrate with pattern $pattern, repeat -1");

            await Vibration.vibrate(
              pattern: pattern,
              repeat: -1,
            );
          }

          debugPrint("✅ Vibration started successfully");
        } catch (e) {
          debugPrint("❌ Vibration error: ${e.toString()}");
          _lastError = "Vibration error: ${e.toString()}";
        }
      }

      // Important: Call updateVibration immediately once, then setup periodic timer
      updateVibration();

      _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        updateVibration();
      });
    } catch (e) {
      _lastError = "Vibration initialization error: ${e.toString()}";
      debugPrint("❌ Vibration initialization error: ${e.toString()}");
    }
  }

  // New: Direct vibration function that works reliably
  Future<bool> directVibrate() async {
    // First, cancel any existing vibration
    try {
      await Vibration.cancel();
      await Future.delayed(Duration(milliseconds: 100));
      debugPrint("📱 Previous vibration cancelled");
    } catch (e) {
      debugPrint("⚠️ Error cancelling vibration: $e");
    }

    debugPrint(
        "📳 Starting direct vibration at ${currentFrequency.toStringAsFixed(1)}Hz");

    try {
      // Calculate pattern based on current frequency
      final interval = (1000 / currentFrequency).round(); // Total cycle length
      final pulseLength =
          (interval / 2).clamp(20, 200).round(); // Active vibration time
      final pauseLength = interval - pulseLength; // Pause time

      // Use fixed pattern for higher frequencies
      final pattern = currentFrequency > 15
          ? [0, 100, 100] // Faster for high frequencies
          : [0, pulseLength, pauseLength];

      // Calculate intensity (higher for lower frequencies)
      int intensity = 255;
      if (_hasAmplitudeControl) {
        // Higher intensity for lower frequencies
        double intensityFactor = 1.0 -
            ((currentFrequency - endFrequency) /
                    (startFrequency - endFrequency))
                .clamp(0.0, 1.0);
        intensity = (intensityFactor * 255).round().clamp(100, 255);
      }

      debugPrint("📳 Vibrate pattern: $pattern, intensity: $intensity");

      if (_hasAmplitudeControl) {
        await Vibration.vibrate(
          pattern: pattern,
          intensities: [0, intensity, 0],
          repeat: -1, // Continuous repeat
        );
      } else {
        await Vibration.vibrate(
          pattern: pattern,
          repeat: -1, // Continuous repeat
        );
      }

      debugPrint("✅ Direct vibration started successfully");
      return true;
    } catch (e) {
      debugPrint("❌ Direct vibration error: $e");
      return false;
    }
  }

  // Handle app lifecycle changes
  void onAppLifecycleChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background
        if (_state == SessionState.running) {
          // Stop direct brightness control (won't work in background)
          _pulseTimer?.cancel();

          // Make sure overlay is running (works in background)
          if (Platform.isAndroid && _state == SessionState.running) {
            try {
              await OverlayService.startOverlay(
                frequency: currentFrequency,
                minOpacity: 0.0,
                maxOpacity: 0.5,
              );
            } catch (e) {
              debugPrint('Failed to start overlay in background: $e');
            }
          }
        }
        break;

      case AppLifecycleState.resumed:
        // App coming to foreground
        if (_state == SessionState.running) {
          // May want to restart direct brightness control here
          if (_pulseTimer == null || !_pulseTimer!.isActive) {
            _startPulseTimer();
          }
        }
        break;

      default:
        break;
    }
  }

  Future<void> testVibration() async {
    debugPrint("Testing basic vibration...");

    // Test if simple vibration works
    await Vibration.cancel();
    await Future.delayed(const Duration(milliseconds: 200));

    debugPrint("Simple vibration test:");
    await Vibration.vibrate(duration: 500);
    await Future.delayed(const Duration(seconds: 1));

    debugPrint("Pattern test:");
    await Vibration.vibrate(
      pattern: [0, 300, 200, 300, 200],
      repeat: 0,
    );

    debugPrint("Done testing vibration");
  }

  // Reset error state
  void resetError() {
    if (_state == SessionState.error) {
      _state = SessionState.idle;
      _lastError = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopSession();
    super.dispose();
  }

  // Add this method to your SleepSessionManager class
  void _startSessionTimer() {
    // Calculate session end time
    _sessionEndTime = DateTime.now().add(sessionDuration);

    // Start the various timers needed for the session
    _startFrequencyTimer();

    // If using in-app brightness control
    if (_canControlBrightness) {
      _startPulseTimer();
    }
    _startVibrationTimer();

    // Start vibration immediately if enabled
    if (useVibration && _hasVibrator) {
      // Use the simple direct approach instead of the timer-based approach
      directVibrate().then((success) {
        if (success) {
          // Setup a timer to update vibration periodically when frequency changes
          _vibrationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
            if (_state == SessionState.running && useVibration) {
              directVibrate();
            }
          });
        }
      });
    }

    // Update notification if using foreground service
    _startNotificationUpdateTimer();

    // Ensure screen stays on during session
    WakelockPlus.enable();

    // Start foreground service for Android
    _ensureForegroundService();
  }

  // Add this method to your SleepSessionManager class
  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(
            'Please enable the "Modify system settings" permission on the next screen to allow brightness control.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Add this method to ensure the foreground service is properly started
  Future<void> _ensureForegroundService() async {
    if (Platform.isAndroid) {
      try {
        await FlutterForegroundTask.startService(
          notificationTitle: "Sleep session active",
          notificationText:
              "Pulsing at ${currentFrequency.toStringAsFixed(1)} Hz",
          callback: startForegroundTask,
          // Add this to match the type in FlutterForegroundTask.init():
        );
        debugPrint("Foreground service started successfully");
      } catch (e) {
        debugPrint("Error starting foreground service: $e");
      }
    }
  }
}

// Callback function for Android foreground service
@pragma('vm:entry-point')
void startForegroundTask() {
  try {
    FlutterForegroundTask.setTaskHandler(SleepSessionTaskHandler());
  } catch (e) {
    debugPrint('Error setting task handler: $e');
  }
}

class SleepSessionTaskHandler extends TaskHandler {
  // Simplified handler to maintain foreground service
  Timer? _keepAliveTimer;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    try {
      debugPrint('Foreground task started');
    } catch (e) {
      debugPrint('Error in onStart: $e');
    }
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    try {
      // Keep service alive with a simple timer
      if (_keepAliveTimer == null || !_keepAliveTimer!.isActive) {
        _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {});
      }
    } catch (e) {
      debugPrint('Error in onEvent: $e');
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    try {
      // Just a basic implementation - nothing to do here
    } catch (e) {
      debugPrint('Error in onRepeatEvent: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    try {
      // Clean up
      _keepAliveTimer?.cancel();
      debugPrint('Foreground task destroyed');
    } catch (e) {
      debugPrint('Error in onDestroy: $e');
    }
  }
}
