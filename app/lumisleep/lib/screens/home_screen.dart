import 'package:flutter/material.dart';
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
                        onPressed: sleepManager.isRunning
                            ? sleepManager.stopSession
                            : sleepManager.startSession,
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
}
