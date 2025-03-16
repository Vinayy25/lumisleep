import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:lumisleep/state/sleep_session_manager.dart';
import 'package:lumisleep/widgets/pulsing_overlay.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepSessionManager>(
      builder: (context, sleepManager, child) {
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text('LumiSleep'),
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                actions: [
                  IconButton(
                    icon: Icon(Icons.settings),
                    onPressed: () => _openSettings(context),
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session duration slider
                    Text(
                      'Session Duration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                            '${sleepManager.sessionDuration.inMinutes} minutes'),
                        Expanded(
                          child: Slider(
                            value: sleepManager.sessionDuration.inMinutes
                                .toDouble(),
                            min: 5,
                            max: 30,
                            divisions: 5,
                            label:
                                '${sleepManager.sessionDuration.inMinutes} min',
                            onChanged: sleepManager.isRunning
                                ? null
                                : (value) => sleepManager
                                    .setSessionDuration(value.round()),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Vibration toggle
                    SwitchListTile(
                      title: const Text('Use Vibration'),
                      subtitle: const Text(
                          'Haptic feedback synced with light pulses'),
                      value: sleepManager.useVibration,
                      onChanged: sleepManager.isRunning
                          ? null
                          : (value) => sleepManager.toggleVibration(value),
                    ),

                    const SizedBox(height: 48),

                    // Frequency display (when active)
                    if (sleepManager.isRunning) ...[
                      Text(
                        'Current Frequency',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${sleepManager.currentFrequency.toStringAsFixed(1)} Hz',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Time Remaining: ${sleepManager.remainingTimeFormatted}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Start/stop button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (sleepManager.isRunning) {
                            sleepManager.stopSession();
                          } else {
                            // Show immediate feedback before starting the session
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Starting sleep session...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            sleepManager.startSession();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        icon: Icon(sleepManager.isRunning
                            ? Icons.stop
                            : Icons.play_arrow),
                        label: Text(sleepManager.isRunning
                            ? 'Stop Session'
                            : 'Start Session'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pulse overlay appears when session is active
            if (sleepManager.isRunning)
              PulseOverlay(frequency: sleepManager.currentFrequency),
          ],
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text('Battery Optimization'),
              subtitle: Text(
                  'Exempt app from battery optimization for better performance'),
              trailing: Icon(Icons.arrow_forward),
              onTap: () async {
                Navigator.pop(context);
                await FlutterForegroundTask
                    .openIgnoreBatteryOptimizationSettings();
              },
            ),
            ListTile(
              title: Text('Overlay Permission'),
              subtitle: Text('Allow app to display over other apps'),
              trailing: Icon(Icons.arrow_forward),
              onTap: () async {
                Navigator.pop(context);
                await FlutterForegroundTask.openSystemAlertWindowSettings();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
