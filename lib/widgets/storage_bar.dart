import 'dart:async';
import 'package:flutter/material.dart';

class StorageBar extends StatefulWidget {
  final double used;
  final double max;

  const StorageBar({super.key, required this.used, required this.max});

  @override
  State<StorageBar> createState() => _StorageBarState();
}

class _StorageBarState extends State<StorageBar> {
  Timer? _hideTimer;

  String _fmt(double bytes) {
    if (bytes <= 0) return '0 MB';

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.max > 0
        ? (widget.used / widget.max).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      height: 40,
      width: 430,
      child: Row(
        children: [
          const SizedBox(width: 18),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(
                  Color.fromARGB(255, 169, 23, 67),
                ),
              ),
            ),
          ),

          const SizedBox(width: 18),

          Text(
            '${_fmt(widget.used)} / ${_fmt(widget.max)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontFamily: 'UberMove',
            ),
          ),

          
        ],
      ),
    );
  }
}
