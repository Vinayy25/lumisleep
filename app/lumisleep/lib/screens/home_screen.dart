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
                        // Update the text to show seconds when under 1 minute
                        Text(sleepManager.sessionDuration.inSeconds < 60
                            ? '${sleepManager.sessionDuration.inSeconds} seconds'
                            : '${sleepManager.sessionDuration.inMinutes} minutes'),
                        Expanded(
                          child: Slider(
                            value: sleepManager.sessionDuration.inSeconds /
                                60, // Convert to minutes for slider value
                            min: 0.5, // 30 seconds minimum
                            max: 30, // 30 minutes maximum
                            divisions: 59, // Allow increments of 30 seconds
                            label: sleepManager.sessionDuration.inSeconds < 60
                                ? '${sleepManager.sessionDuration.inSeconds} sec'
                                : '${sleepManager.sessionDuration.inMinutes} min',
                            onChanged: sleepManager.isRunning
                                ? null
                                : (value) {
                                    int seconds = (value * 60).round();
                                    sleepManager
                                        .setSessionDurationFromSeconds(seconds);
                                  },
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
                        onPressed: () async {
                          if (sleepManager.isRunning) {
                            sleepManager.stopSession();
                          } else {
                          
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
