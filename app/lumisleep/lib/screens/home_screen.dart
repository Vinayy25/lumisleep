import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:lumisleep/state/sleep_session_manager.dart';
import 'package:lumisleep/widgets/pulsing_overlay.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart'; // <------------ import iconsax

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepSessionManager>(
      builder: (context, sleepManager, child) {
        return Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E0E44), // Dark purple
                    Color(0xFF200A3B), // Deep purple
                    Color(0xFF28064E), // Rich purple
                  ],
                ),
              ),
            ),

            // Animated patterns overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.07,
                child: Image.network(
                  'https://images.unsplash.com/photo-1506318164473-2dfd3ede3623',
                  fit: BoxFit.cover,
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 6.seconds, delay: 0.5.seconds)
                    .then()
                    .fadeIn(duration: 1.seconds),
              ),
            ),

            Scaffold(
              backgroundColor: Colors.transparent,
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: const Text(
                  'LumiSleep',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Iconsax.menu, color: Colors.white70),
                    onPressed: () => _openSettings(context),
                  ),
                ],
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Header with status
                        _buildStatusHeader(context, sleepManager),

                        const SizedBox(height: 40),

                        // Session duration card
                        _buildDurationCard(context, sleepManager),

                        const SizedBox(height: 24),

                        // Vibration card
                        _buildVibrationCard(context, sleepManager),

                        const SizedBox(height: 32),

                        // Frequency display card (when active)
                        if (sleepManager.isRunning)
                          _buildFrequencyCard(context, sleepManager),

                        const SizedBox(height: 40),

                        // Start/stop button
                        _buildControlButton(
                            context, sleepManager, sleepManager.isActive),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
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

  Widget _buildStatusHeader(
      BuildContext context, SleepSessionManager sleepManager) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sleepManager.isRunning ? Colors.greenAccent : Colors.amber,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeOut(duration: 1.seconds, curve: Curves.easeInOut)
              .fadeIn(duration: 1.seconds, curve: Curves.easeInOut),
          SizedBox(width: 12),
          Text(
            sleepManager.isRunning ? 'Session Active' : 'Ready to Start',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          Spacer(),
          if (sleepManager.isRunning)
            Text(
              sleepManager.remainingTimeFormatted,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 0.5.seconds)
        .slide(duration: 0.5.seconds, begin: Offset(0, -0.1), end: Offset.zero);
  }

  Widget _buildDurationCard(
      BuildContext context, SleepSessionManager sleepManager) {
    String durationText = sleepManager.sessionDuration.inSeconds < 60
        ? '${sleepManager.sessionDuration.inSeconds} seconds'
        : '${sleepManager.sessionDuration.inMinutes} minutes';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.timer, color: Colors.purpleAccent),
                SizedBox(width: 12),
                Text(
                  'Session Duration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              durationText,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.purpleAccent,
                inactiveTrackColor: Colors.purpleAccent.withOpacity(0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.purpleAccent.withOpacity(0.3),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: sleepManager.sessionDuration.inSeconds / 60,
                min: 0.5,
                max: 30,
                divisions: 59,
                label: sleepManager.sessionDuration.inSeconds < 60
                    ? '${sleepManager.sessionDuration.inSeconds} sec'
                    : '${sleepManager.sessionDuration.inMinutes} min',
                onChanged: sleepManager.isRunning
                    ? null
                    : (value) {
                        int seconds = (value * 60).round();
                        sleepManager.setSessionDurationFromSeconds(seconds);
                      },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('30s', style: TextStyle(color: Colors.white70)),
                Text('30m', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 0.5.seconds, delay: 0.2.seconds)
        .slide(duration: 0.5.seconds, begin: Offset(0, 0.1), end: Offset.zero);
  }

  Widget _buildVibrationCard(
      BuildContext context, SleepSessionManager sleepManager) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.activity, color: Colors.purpleAccent),
                    SizedBox(width: 12),
                    Text(
                      'Haptic Feedback',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: sleepManager.useVibration,
                  onChanged: sleepManager.isRunning
                      ? null
                      : (value) => sleepManager.toggleVibration(value),
                  activeColor: Colors.purpleAccent,
                  trackColor: MaterialStateProperty.resolveWith((states) =>
                      states.contains(MaterialState.selected)
                          ? Colors.purpleAccent.withOpacity(0.5)
                          : Colors.grey.withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Syncs haptic patterns with visual pulses for a deeper experience',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 0.5.seconds, delay: 0.3.seconds)
        .slide(duration: 0.5.seconds, begin: Offset(0, 0.1), end: Offset.zero);
  }

  Widget _buildFrequencyCard(
      BuildContext context, SleepSessionManager sleepManager) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.purpleAccent.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves, color: Colors.purpleAccent),
                SizedBox(width: 12),
                Text(
                  'Current Frequency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${sleepManager.currentFrequency.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Center(
              child: Text(
                'Hz',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: (sleepManager.startFrequency -
                      sleepManager.currentFrequency) /
                  (sleepManager.startFrequency - sleepManager.endFrequency),
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${sleepManager.startFrequency.toStringAsFixed(1)} Hz',
                    style: TextStyle(color: Colors.white70)),
                Text('${sleepManager.endFrequency.toStringAsFixed(1)} Hz',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 0.5.seconds)
        .shimmer(duration: 2.seconds, delay: 0.5.seconds)
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
          duration: 3.seconds,
          begin: Offset(1, 1),
          end: Offset(1.02, 1.02),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          duration: 3.seconds,
          begin: Offset(1.02, 1.02),
          end: Offset(1, 1),
          curve: Curves.easeInOut,
        );
  }

  Widget _buildControlButton(
      BuildContext context, SleepSessionManager sleepManager, bool isActive) {
    return Center(
      child: GestureDetector(
        onTap: () async {
          if (sleepManager.isRunning) {
            sleepManager.stopSession();
          } else {
            sleepManager.startSession(context);
          }
        },
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple,
                Colors.deepPurple,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            sleepManager.isActive == true ? Iconsax.pause : Iconsax.play,
            color: Colors.white,
            size: 40,
          ),
        ),
      )
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: 2.seconds,
            color: Colors.white.withOpacity(0.3),
          )
          .scale(
            duration: 2.seconds,
            begin: Offset(1, 1),
            end: Offset(1.05, 1.05),
            curve: Curves.easeInOut,
          )
          .then()
          .scale(
            duration: 2.seconds,
            begin: Offset(1.05, 1.05),
            end: Offset(1, 1),
            curve: Curves.easeInOut,
          ),
    );
  }

  void _openSettings(BuildContext context) {
    final sleepManager =
        Provider.of<SleepSessionManager>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Color(0xFF200A3B).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingsOption(
                  icon: Iconsax.battery_3full,
                  title: 'Battery Optimization',
                  subtitle: 'Exempt app from battery optimization',
                  onTap: () async {
                    Navigator.pop(context);
                    await FlutterForegroundTask
                        .openIgnoreBatteryOptimizationSettings();
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.1)),
                _buildSettingsOption(
                  icon: Iconsax.shield,
                  title: 'Overlay Permission',
                  subtitle: 'Allow display over other apps',
                  onTap: () async {
                    Navigator.pop(context);
                    await FlutterForegroundTask.openSystemAlertWindowSettings();
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.1)),
                _buildSettingsSwitch(
                  context: context,
                  icon: Iconsax.mobile,
                  title: 'Debug Mode',
                  subtitle: 'Disable system changes for testing',
                  value: sleepManager.debugMode,
                  onChanged: (value) {
                    sleepManager.debugMode = value;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Debug mode: ${value ? 'ON' : 'OFF'}'),
                        backgroundColor: Colors.deepPurple,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(color: Colors.purpleAccent),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(color: Colors.purpleAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn().scale(
              begin: Offset(0.9, 0.9),
              end: Offset(1, 1),
              duration: 0.3.seconds,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purpleAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.purpleAccent),
      ),
      title: Text(title, style: TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
      trailing: Icon(Iconsax.arrow1, color: Colors.white54, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSettingsSwitch({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purpleAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.purpleAccent),
      ),
      title: Text(title, style: TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.purpleAccent,
        trackColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected)
                ? Colors.purpleAccent.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3)),
      ),
    );
  }
}
