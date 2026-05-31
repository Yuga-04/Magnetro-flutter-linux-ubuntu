import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:get/get.dart';

enum SnackType { success, error, info }

class _SnackConfig {
  final IconData icon;
  final Color color;
  const _SnackConfig({required this.icon, required this.color});
}

_SnackConfig _getConfig(SnackType type) {
  switch (type) {
    case SnackType.success:
      return const _SnackConfig(
        icon: Icons.check_circle_rounded,
        color: Color(0xFF4CAF50),
      );
    case SnackType.error:
      return const _SnackConfig(
        icon: Icons.error_rounded,
        color: Color(0xFFEF5350),
      );
    case SnackType.info:
      return const _SnackConfig(
        icon: Icons.info_rounded,
        color: Color(0xFF42A5F5),
      );
  }
}

class AppSnack {
  AppSnack._();

  static OverlayEntry? _current;

  static void show(
    String message, {
    SnackType type = SnackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    try { _current?.remove(); } catch (_) {}
    _current = null;

    final overlayState = Get.key.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SnackOverlay(
        message: message,
        config: _getConfig(type),
        duration: duration,
        onDone: () {
          try { entry.remove(); } catch (_) {}
          if (_current == entry) _current = null;
        },
      ),
    );

    _current = entry;
    overlayState.insert(entry);
  }

  static void success(String message) => show(message, type: SnackType.success);
  static void error(String message)   => show(message, type: SnackType.error);
  static void info(String message)    => show(message, type: SnackType.info);
}

class _SnackOverlay extends StatefulWidget {
  final String message;
  final _SnackConfig config;
  final Duration duration;
  final VoidCallback onDone;

  const _SnackOverlay({
    required this.message,
    required this.config,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_SnackOverlay> createState() => _SnackOverlayState();
}

class _SnackOverlayState extends State<_SnackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  double _dragX = 0;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slide = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
    Future.delayed(widget.duration, () {
      if (mounted && !_dismissed) _dismiss();
    });
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    await _ctrl.reverse();
    try { widget.onDone(); } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 0,
      right: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            onTap: _dismiss,
            onHorizontalDragUpdate: (d) => setState(() => _dragX += d.delta.dx),
            onHorizontalDragEnd: (d) {
              if (_dragX.abs() > 80) {
                _dismiss();
              } else {
                setState(() => _dragX = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(_dragX, 0),
              child: _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 6,
          intensity: 0.7,
          color: const Color(0xFF1C1C1C),
          lightSource: LightSource.topLeft,
          shadowDarkColor: Colors.black87,
          shadowLightColor: Colors.white10,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(widget.config.icon, color: widget.config.color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Color(0xFFDDDDDD),
                    fontSize: 13,
                    fontFamily: 'UberMove',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}