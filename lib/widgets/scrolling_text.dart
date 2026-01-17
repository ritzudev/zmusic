import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration pauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(seconds: 10),
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  late ScrollController _scrollController;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Reiniciar scroll al cambiar texto
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverflow();
      });
    }
  }

  void _checkOverflow() {
    if (!mounted) return;

    // Usamos TextPainter para calcular si el texto desbordaría en el contenedor
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final containerWidth = context.size?.width ?? 0;
    // Añadimos un pequeño margen de error
    final isOverflowing = textPainter.width > containerWidth;

    if (isOverflowing != _shouldScroll) {
      setState(() {
        _shouldScroll = isOverflowing;
      });
      if (isOverflowing) {
        _startScrolling();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() async {
    // Pequeño retardo adicional para asegurar que el ScrollController tenga clientes
    await Future.delayed(const Duration(milliseconds: 100));

    while (mounted && _shouldScroll) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_shouldScroll) return;

      if (_scrollController.hasClients) {
        final maxScrollExtent = _scrollController.position.maxScrollExtent;
        if (maxScrollExtent > 0) {
          final double pixelsPerSecond = 30.0;
          final duration = Duration(
            milliseconds: (maxScrollExtent * 1000 / pixelsPerSecond).round(),
          );

          await _scrollController.animateTo(
            maxScrollExtent,
            duration: duration,
            curve: Curves.linear,
          );

          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no desborda, mostramos el texto normal
    if (!_shouldScroll) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Si desborda, activamos la marquesina
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style, maxLines: 1),
          const SizedBox(width: 50),
          Text(widget.text, style: widget.style, maxLines: 1),
          const SizedBox(width: 50),
        ],
      ),
    );
  }
}
