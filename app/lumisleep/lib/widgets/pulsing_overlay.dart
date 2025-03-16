import 'dart:math';
import 'package:flutter/material.dart';

class PulseOverlay extends StatefulWidget {
  final double frequency;

  const PulseOverlay({super.key, required this.frequency});

  @override
  State<PulseOverlay> createState() => _PulseOverlayState();
}

class _PulseOverlayState extends State<PulseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(PulseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frequency != widget.frequency) {
      _controller.duration =
          Duration(milliseconds: (1000 / widget.frequency).round());
      _controller.repeat();
    }
  }

  void _setupAnimation() {
    _controller = AnimationController(
      duration: Duration(milliseconds: (1000 / widget.frequency).round()),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        // Use a sine wave function for smoother pulsing
        final time = DateTime.now().millisecondsSinceEpoch / 1000;
        final wave = sin(2 * pi * widget.frequency * time);
        final normalized = (wave + 1) / 2; // Convert from [-1,1] to [0,1]

        return Container(
          color: Colors.black.withOpacity(normalized * 0.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.frequency.toStringAsFixed(1)} Hz',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
