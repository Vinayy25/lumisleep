import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum SessionState { idle, running, paused, error }

class SleepSessionManager with ChangeNotifier {
  // For development - set to true to disable features that might crash the app
  final bool debugMode = true;

  // Session configuration
  double startFrequency = 30.0;
  double endFrequency = 7.0;
  double currentFrequency = 30.0;
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
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
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
      // Save default brightness for restoration later
      defaultBrightness = await ScreenBrightness().current;

      // Check if device has vibration capabilities
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;

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

      // Load session duration (default 15min)
      final minutes = prefs.getInt('sessionDuration') ?? 15;
      sessionDuration = Duration(minutes: minutes);

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
      await prefs.setInt('sessionDuration', sessionDuration.inMinutes);
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
    if (_state == SessionState.running) return;

    sessionDuration = Duration(minutes: minutes);
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

  // Start sleep session
  Future<bool> startSession() async {
    if (_state == SessionState.running) return true;
    if (!_isInitialized) await initialize();

    try {
      // Check basic permissions for brightness
      await _checkPermissions();

      // Restore session if paused
      if (_state == SessionState.paused && _remainingTimeAtPause != null) {
        _sessionEndTime = DateTime.now().add(_remainingTimeAtPause!);
      } else {
        // Start new session
        currentFrequency = startFrequency;
        _sessionEndTime = DateTime.now().add(sessionDuration);
      }

      // Update state first - this ensures the UI updates even if some components fail
      _state = SessionState.running;
      _lastError = null;
      notifyListeners();

      // Try to keep screen on
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('Wakelock error (continuing anyway): $e');
      }

      // Start processes
      _startFrequencyTimer();
      _startPulseTimer();

      // Start vibration if enabled
      if (useVibration && _hasVibrator) {
        try {
          await _startVibrationTimer();
        } catch (e) {
          debugPrint('Vibration error (continuing anyway): $e');
        }
      }

      // Start foreground service on Android - do this LAST as it may fail
      if (Platform.isAndroid && !debugMode) {
        try {
          await FlutterForegroundTask.startService(
            notificationTitle: "Sleep session active",
            notificationText: "Pulsing to help you sleep",
            callback: startForegroundTask,
          );

          // If successful, start notification updates
          _startNotificationUpdateTimer();
        } catch (e) {
          // Log but continue - the app can work without foreground service
          debugPrint('Foreground service error (continuing anyway): $e');
        }
      }

      return true;
    } catch (e) {
      _lastError = "Failed to start session: ${e.toString()}";
      _state = SessionState.error;
      debugPrint(_lastError);
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

  // Stop sleep session
  Future<void> stopSession() async {
    if (_state == SessionState.idle) return;

    try {
      // Cancel all timers
      _frequencyTimer?.cancel();
      _pulseTimer?.cancel();
      _vibrationTimer?.cancel();
      _notificationUpdateTimer?.cancel();

      // Reset brightness
      await ScreenBrightness().setScreenBrightness(defaultBrightness);

      // Stop vibration
      if (_hasVibrator) {
        await Vibration.cancel();
      }

      // Allow screen to turn off
      await WakelockPlus.disable();

      // Stop foreground service on Android
      if (Platform.isAndroid) {
        await FlutterForegroundTask.stopService();
      }

      // Reset state
      _state = SessionState.idle;
      _sessionEndTime = null;
      _sessionPausedAt = null;
      _remainingTimeAtPause = null;

      notifyListeners();
    } catch (e) {
      _lastError = "Error stopping session: ${e.toString()}";
      _state = SessionState.error;
      debugPrint(_lastError);
      notifyListeners();
    }
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

        // Set screen brightness
        await ScreenBrightness().setScreenBrightness(currentBrightness);
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

  // Generate vibration pattern at current frequency
  Future<void> _startVibrationTimer() async {
    if (!_hasVibrator || !useVibration) return;

    _vibrationTimer?.cancel();

    try {
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

        // Create pattern of alternating vibration/pause
        try {
          if (_hasAmplitudeControl) {
            await Vibration.vibrate(
              pattern: [0, pulseLength, interval - pulseLength],
              intensities: [0, intensity, 0],
              repeat: -1,
            );
          } else {
            await Vibration.vibrate(
              pattern: [0, pulseLength, interval - pulseLength],
              repeat: -1,
            );
          }
        } catch (e) {
          _lastError = "Vibration error: ${e.toString()}";
          debugPrint(_lastError);
        }
      }

      _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        updateVibration();
      });

      // Start initial vibration
      updateVibration();
    } catch (e) {
      _lastError = "Vibration initialization error: ${e.toString()}";
      debugPrint(_lastError);
    }
  }

  // Handle app lifecycle changes
  void onAppLifecycleChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background, may need special handling on iOS
        if (Platform.isIOS && _state == SessionState.running) {
          // iOS doesn't allow brightness control in background
          // Consider pausing here or implementing fallback
        }
        break;

      case AppLifecycleState.resumed:
        // App coming to foreground
        if (_state == SessionState.running) {
          // Ensure brightness control is working
          _canControlBrightness = true;
        }
        break;

      default:
        break;
    }
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
