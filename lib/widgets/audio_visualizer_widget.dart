import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizerWidget extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final double barWidth;
  final Color? color;
  final List<Color>? gradientColors;

  const AudioVisualizerWidget({
    super.key,
    required this.isPlaying,
    this.barCount = 4,
    this.height = 18.0,
    this.barWidth = 3.0,
    this.color,
    this.gradientColors,
  });

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<double> _targetHeights;
  late List<double> _currentHeights;

  @override
  void initState() {
    super.initState();
    _targetHeights = List.generate(widget.barCount, (_) => 0.2);
    _currentHeights = List.generate(widget.barCount, (_) => 0.2);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addListener(_updateHeights);

    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      } else {
        _controller.stop();
        setState(() {
          for (int i = 0; i < widget.barCount; i++) {
            _currentHeights[i] = 0.2;
          }
        });
      }
    }
  }

  void _updateHeights() {
    if (!widget.isPlaying) return;

    setState(() {
      for (int i = 0; i < widget.barCount; i++) {
        // Generar alturas orgánicas
        if (_controller.value < 0.1 || _controller.value > 0.9) {
          _targetHeights[i] = 0.15 + _random.nextDouble() * 0.85;
        }
        _currentHeights[i] +=
            (_targetHeights[i] - _currentHeights[i]) * 0.35;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          final barHeight =
              (widget.height * (_currentHeights[index].clamp(0.15, 1.0)));

          return Container(
            margin: EdgeInsets.symmetric(horizontal: widget.barWidth / 2.5),
            width: widget.barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.barWidth),
              gradient: widget.gradientColors != null
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: widget.gradientColors!,
                    )
                  : null,
              color: widget.gradientColors == null ? primaryColor : null,
            ),
          );
        }),
      ),
    );
  }
}
