import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:get/get.dart';
import 'package:marquee/marquee.dart';
import '../screens/video_player_screen.dart';
import '../api/seedr_api.dart';

class FileTile extends StatefulWidget {
  final String name;
  final double size;
  final String? parentName;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final int index;
  final String fileId;
  final SeedrApi api;

  const FileTile({
    super.key,
    required this.name,
    required this.size,
    this.parentName,
    required this.onDownload,
    required this.onDelete,
    required this.index,
    required this.fileId,
    required this.api,
  });

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  bool _isLoadingPlay = false;

  String _fmt(double bytes) {
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _onPlay() async {
    if (_isLoadingPlay) return;
    setState(() => _isLoadingPlay = true);
    try {
      final url = await widget.api.getFileDownload(widget.fileId);
      if (!mounted) return;
      await Get.to(
        () => VideoPlayerScreen(url: url, title: widget.name),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load stream: ${e.toString().replaceAll('Exception: ', '')}',
              style: const TextStyle(fontFamily: 'UberMove'),
            ),
            backgroundColor: const Color(0xFF2A2A2A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          NeumorphicButton(
            onPressed: () {},
            style: NeumorphicStyle(
              depth: 0,
              intensity: 0,
              color: Colors.transparent,
              shadowLightColor: Colors.transparent,
              shadowDarkColor: Colors.transparent,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: _buildInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildNumber() {
    return SizedBox(
      width: 25,
      child: Text(
        '${widget.index + 1}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'UberMove',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7A7A7A),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildNumber(),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              LayoutBuilder(
                builder: (context, constraints) {
                  const style = TextStyle(
                    fontFamily: 'UberMove',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFEDEDED),
                  );

                  final painter = TextPainter(
                    text: TextSpan(text: widget.name, style: style),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                  )..layout();

                  final textFits = painter.width <= constraints.maxWidth;

                  if (textFits) {
                    return SizedBox(
                      height: 30,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(widget.name, maxLines: 1, style: style),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 30,
                    child: Marquee(
                      text: widget.name,
                      blankSpace: 50,
                      velocity: 32,
                      pauseAfterRound: const Duration(seconds: 5),
                      startPadding: 2,
                      accelerationDuration: const Duration(milliseconds: 800),
                      decelerationDuration: const Duration(milliseconds: 500),
                      style: style,
                    ),
                  );
                },
              ), // Meta row
              SizedBox(height: 3,),
              Row(
                children: [
                  Text(
                    _fmt(widget.size),
                    style: const TextStyle(
                      fontFamily: 'UberMove',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),
                  // const Spacer(),
                  SizedBox(width: 10,),

                  // ── Play button ──────────────────────────────────────────
                  _isLoadingPlay
                      ? const SizedBox(
                          width: 35,
                          height: 35,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7A7A7A),
                            ),
                          ),
                        )
                      : _buildActionButton(
                          icon: Icons.play_arrow_rounded,
                          onTap: _onPlay,
                        ),

                  const SizedBox(width: 10),

                  _buildActionButton(
                    icon: Icons.download_rounded,
                    onTap: widget.onDownload,
                  ),

                  const SizedBox(width: 10),

                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        radius: 10,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: const Color(0xFF7A7A7A), size: 28),
        ),
      ),
    );
  }
}
