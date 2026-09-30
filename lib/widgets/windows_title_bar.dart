import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowsTitleBar extends StatefulWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final double height;
  final Color? backgroundColor;

  const WindowsTitleBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.height = 40.0,
    this.backgroundColor,
  });

  @override
  State<WindowsTitleBar> createState() => _WindowsTitleBarState();
}

class _WindowsTitleBarState extends State<WindowsTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _checkMaximized();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final isMax = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMax;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: widget.height,
      color: widget.backgroundColor ?? Colors.transparent,
      child: Row(
        children: [
          // Área izquierda (Logo / Título)
          if (widget.leading != null) widget.leading!,
          if (widget.title != null) ...[
            const SizedBox(width: 8),
            widget.title!,
          ],

          // Área central expandida para arrastre de la ventana
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              child: const DragToMoveArea(
                child: SizedBox(
                  height: double.infinity,
                  width: double.infinity,
                ),
              ),
            ),
          ),

          // Acciones opcionales
          if (widget.actions != null) ...widget.actions!,

          // Botones de control de ventana de Windows 11
          _WindowButton(
            icon: Icons.remove,
            tooltip: 'Minimizar',
            hoverColor: isDark ? Colors.white12 : Colors.black12,
            iconColor: isDark ? Colors.white70 : Colors.black87,
            onPressed: () => windowManager.minimize(),
          ),
          _WindowButton(
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
            iconSize: _isMaximized ? 14 : 16,
            hoverColor: isDark ? Colors.white12 : Colors.black12,
            iconColor: isDark ? Colors.white70 : Colors.black87,
            onPressed: () async {
              if (_isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            hoverColor: const Color(0xFFE81123),
            iconColor: isDark ? Colors.white70 : Colors.black87,
            hoverIconColor: Colors.white,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final double iconSize;
  final Color hoverColor;
  final Color iconColor;
  final Color? hoverIconColor;
  final VoidCallback onPressed;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    this.iconSize = 16,
    required this.hoverColor,
    required this.iconColor,
    this.hoverIconColor,
    required this.onPressed,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverColor : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _isHovered && widget.hoverIconColor != null
                  ? widget.hoverIconColor
                  : widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
