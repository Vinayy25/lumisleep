import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:lumisleep/screens/home_screen.dart';
import 'package:lumisleep/state/sleep_session_manager.dart';
import 'package:provider/provider.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lumisleep/services/overlay_service.dart'
    hide SleepSessionManager;

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  // Use overlayListener instead of receiveData().listen
  FlutterOverlayWindow.overlayListener.listen((event) {
    if (event is Map<String, dynamic>) {
      if (event["type"] == "update_opacity") {
        // Update the opacity of our overlay
        final opacity = event["opacity"] as int;
        final frequency = event["frequency"] as double;

        // This would be handled by the Flutter UI in the overlay
        print("Updating overlay: opacity=$opacity, frequency=$frequency");

        // You would update the global state or notify a stream here
        // For example:
        OverlayState.getInstance().updateState(opacity, frequency);
      }
    } else if (event == "STOP") {
      // Handle stop command - close the overlay
      FlutterOverlayWindow.closeOverlay();
    }
  });

  // Run a basic Flutter app as the overlay
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWidget(),
  ));
}

// A simple state management class for the overlay
class OverlayState {
  static final OverlayState _instance = OverlayState._internal();
  static OverlayState getInstance() => _instance;
  OverlayState._internal();

  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  void updateState(int opacity, double frequency) {
    _stateController.add({
      'opacity': opacity,
      'frequency': frequency,
    });
  }

  void dispose() {
    _stateController.close();
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

    // Listen for state changes
    OverlayState.getInstance().stateStream.listen((data) {
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
    return Container(
      color: Colors.black.withOpacity(opacity),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${frequency.toStringAsFixed(1)} Hz",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Use shareData instead of sendData
                FlutterOverlayWindow.shareData("STOP");
              },
              child: Text("Stop Session"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'lumisleep_notification_channel',
      channelName: 'LumiSleep Session',
      channelDescription: 'Sleep session is active',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 1000,
      autoRunOnBoot: false,
      allowWifiLock: false,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => SleepSessionManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Use a try-catch or delay to ensure the provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final manager =
            Provider.of<SleepSessionManager>(context, listen: false);
        manager.onAppLifecycleChange(state);
      } catch (e) {
        debugPrint("Lifecycle error: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LumiSleep',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
