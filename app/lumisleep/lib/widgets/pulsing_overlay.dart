import 'package:flutter/material.dart';
import 'dart:math' as math;

class PulseOverlay extends StatefulWidget {
  final double frequency;

  const PulseOverlay({Key? key, required this.frequency}) : super(key: key);

  @override
  _PulseOverlayState createState() => _PulseOverlayState();
}

class _PulseOverlayState extends State<PulseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_updateOpacity);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateOpacity() {
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    final wave = math.sin(2 * math.pi * widget.frequency * time);
    final normalized = (wave + 1) / 2; // value between 0 and 1

    setState(() {
      // Calculate opacity: min 0.0 to max 0.6
      _opacity = normalized * 0.6;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient overlay that's always present
        Container(
          color: Colors.transparent,
        ),

        // Pulsing overlay with changing opacity
        AnimatedOpacity(
          opacity: _opacity,
          duration: Duration(milliseconds: 32),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.purpleAccent.withOpacity(0.7),
                  Colors.deepPurple.withOpacity(0.3),
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
                center: Alignment.center,
                radius: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
