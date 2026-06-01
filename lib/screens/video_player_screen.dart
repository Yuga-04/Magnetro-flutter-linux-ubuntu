import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

// ── Aspect Ratio Options ──────────────────────────────────────────────────────
enum _AspectRatioOption {
  bestFit,
  fitToScreen;

  String get label {
    switch (this) {
      case bestFit:
        return 'Best Fit';
      case fitToScreen:
        return 'Fit Screen';
    }
  }

  _AspectRatioOption get next {
    final values = _AspectRatioOption.values;
    return values[(index + 1) % values.length];
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const VideoPlayerScreen({super.key, required this.url, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin, WindowListener {
  // ── Core ──────────────────────────────────────────────────────────────────
  late final Player _player;
  late final VideoController _controller;

  // ── Focus ─────────────────────────────────────────────────────────────────
  final FocusNode _focusNode = FocusNode();

  // ── UI State ──────────────────────────────────────────────────────────────
  bool _showControls = true;
  bool _isBuffering = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // ── Lock State ────────────────────────────────────────────────────────────
  bool _isLocked = false;
  bool _showUnlockButton = true;
  Timer? _hideUnlockTimer;

  // ── Tracks ────────────────────────────────────────────────────────────────
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  AudioTrack? _selectedAudio;
  SubtitleTrack _selectedSubtitle = SubtitleTrack.no();
  bool _subtitlesEnabled = false;

  // ── Aspect Ratio ──────────────────────────────────────────────────────────
  _AspectRatioOption _aspectRatio = _AspectRatioOption.bestFit;

  // ── Fullscreen ────────────────────────────────────────────────────────────
  bool _isFullscreen = false;

  // ── Time Display ──────────────────────────────────────────────────────────
  bool _showRemainingTime = false;

  // ── Overlay Feedback ──────────────────────────────────────────────────────
  bool _showSeekLeft = false;
  bool _showSeekRight = false;
  bool _showPlayPause = false;
  IconData _playPauseIcon = Icons.play_arrow_rounded;

  // ── Volume Overlay (keyboard-controlled) ─────────────────────────────────
  double _volume = 1.0;
  bool _showVolumeOverlay = false;
  Timer? _hideVolumeOverlayTimer;

  // ── Seek Overlay (keyboard-controlled) ────────────────────────────────────
  final int _seekSeconds = 15;
  final int _seekSecondsShift = 40;

  // ── Slider Seek (bottom bar) ──────────────────────────────────────────────
  bool _isDraggingSeek = false;
  double _seekDragValue = 0;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _hideControlsTimer;
  Timer? _feedbackTimer;
  Timer? _seekLeftFeedbackTimer;
  Timer? _seekRightFeedbackTimer;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _controlsFadeAnim;
  late AnimationController _seekLeftAnim;
  late AnimationController _seekRightAnim;
  late AnimationController _playPauseAnim;
  late AnimationController _unlockButtonAnim;

  // ── Subscriptions ─────────────────────────────────────────────────────────
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _player = Player();
    _controller = VideoController(_player);
    // Sync initial volume from player
    _volume = _player.state.volume / 100.0;
    Future.microtask(_initPlayer);
    _initSystemUi();
    // Add window listener to detect fullscreen changes externally (e.g. OS-level)
    windowManager.addListener(this);
    // Sync initial fullscreen state
    _syncFullscreenState();
  }

  // ── FIX: WindowListener callback — keeps _isFullscreen in sync ────────────
  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullscreen = false);
  }

  Future<void> _syncFullscreenState() async {
    try {
      final isFs = await windowManager.isFullScreen();
      if (mounted) setState(() => _isFullscreen = isFs);
    } catch (_) {
      // windowManager may not be available on all platforms; silently ignore
    }
  }

  void _initAnimations() {
    _controlsFadeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _seekLeftAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _seekRightAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _playPauseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // FIX: _unlockButtonAnim declared as non-nullable `late`; always initialized here
    _unlockButtonAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
  }

  void _initPlayer() {
    _subs.addAll([
      _player.stream.playing.listen((v) {
        if (mounted) setState(() => _isPlaying = v);
      }),
      _player.stream.buffering.listen((v) {
        if (mounted) setState(() => _isBuffering = v);
      }),
      _player.stream.position.listen((v) {
        if (!_isDraggingSeek && mounted) {
          setState(() => _position = v);
        }
      }),
      _player.stream.duration.listen((v) {
        if (mounted) setState(() => _duration = v);
      }),
      _player.stream.volume.listen((v) {
        if (mounted) setState(() => _volume = v / 100.0);
      }),
      _player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _audioTracks = tracks.audio;
          _subtitleTracks = tracks.subtitle;
        });
      }),
      _player.stream.track.listen((track) {
        if (!mounted) return;
        setState(() {
          _selectedAudio = track.audio;
          _selectedSubtitle = track.subtitle;
        });
      }),
    ]);

    _player.open(Media(widget.url));
    _player.setSubtitleTrack(SubtitleTrack.no());
    _startHideControlsTimer();
  }

  void _initSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // ── FIX: Fullscreen Toggle — use WindowListener for state sync instead of
  //         re-reading after setFullScreen (avoids timing race conditions) ────
  Future<void> _toggleFullscreen() async {
    try {
      // Read current state reliably
      final currentlyFullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!currentlyFullscreen);
      // State will be updated via onWindowEnterFullScreen / onWindowLeaveFullScreen
      // But also set it immediately for snappy UI response
      if (mounted) {
        setState(() => _isFullscreen = !currentlyFullscreen);
      }
    } catch (e) {
      debugPrint('Fullscreen toggle error: $e');
    }
    _showControlsTemporarily();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _focusNode.dispose();
    for (final s in _subs) s.cancel();
    _player.dispose();
    _controlsFadeAnim.dispose();
    _seekLeftAnim.dispose();
    _seekRightAnim.dispose();
    _playPauseAnim.dispose();
    _unlockButtonAnim.dispose();
    _hideControlsTimer?.cancel();
    _feedbackTimer?.cancel();
    _seekLeftFeedbackTimer?.cancel();
    _seekRightFeedbackTimer?.cancel();
    _hideUnlockTimer?.cancel();
    _hideVolumeOverlayTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── Keyboard Handler ──────────────────────────────────────────────────────
  // FIX: Focus.onKeyEvent expects a sync callback (KeyEventResult), not Future.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_isLocked) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyL) {
        _unlockControls();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _togglePlayPause();
      _showControlsTemporarily();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      isShift ? _seekForward(_seekSecondsShift) : _seekForward(_seekSeconds);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      isShift ? _seekBackward(_seekSecondsShift) : _seekBackward(_seekSeconds);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _adjustVolume(0.1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _adjustVolume(-0.1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen(); // fire-and-forget
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyL) {
      _lockControls();
      return KeyEventResult.handled;
    }

    // ── FIX: ESC / Backspace — exit fullscreen OR navigate back ──────────
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      if (_isFullscreen) {
        // fire-and-forget async call; keep handler sync
        unawaited(windowManager.setFullScreen(false));
        if (mounted) setState(() => _isFullscreen = false);
      } else {
        if (mounted) Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    final numMap = {
      LogicalKeyboardKey.digit0: 0.0,
      LogicalKeyboardKey.digit1: 0.1,
      LogicalKeyboardKey.digit2: 0.2,
      LogicalKeyboardKey.digit3: 0.3,
      LogicalKeyboardKey.digit4: 0.4,
      LogicalKeyboardKey.digit5: 0.5,
      LogicalKeyboardKey.digit6: 0.6,
      LogicalKeyboardKey.digit7: 0.7,
      LogicalKeyboardKey.digit8: 0.8,
      LogicalKeyboardKey.digit9: 0.9,
    };
    if (numMap.containsKey(key)) {
      final fraction = numMap[key]!;
      final ms = (fraction * _duration.inMilliseconds).round();
      _player.seek(Duration(milliseconds: ms));
      _showControlsTemporarily();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── Lock / Unlock ─────────────────────────────────────────────────────────
  void _lockControls() {
    _hideControlsTimer?.cancel();
    // FIX: Guard animation call — only reverse if currently animating forward
    if (_controlsFadeAnim.status == AnimationStatus.completed ||
        _controlsFadeAnim.status == AnimationStatus.forward) {
      _controlsFadeAnim.reverse();
    }
    setState(() {
      _isLocked = true;
      _showControls = false;
      _showUnlockButton = true;
    });
    _unlockButtonAnim.forward(from: 0);
    _startHideUnlockButtonTimer();
  }

  void _unlockControls() {
    _hideUnlockTimer?.cancel();
    setState(() {
      _isLocked = false;
      _showUnlockButton = false;
    });
    _showControlsTemporarily();
  }

  void _onLockedTap() {
    _hideUnlockTimer?.cancel();
    _unlockButtonAnim.forward(from: 0);
    setState(() => _showUnlockButton = true);
    _startHideUnlockButtonTimer();
  }

  void _startHideUnlockButtonTimer() {
    _hideUnlockTimer?.cancel();
    _hideUnlockTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isLocked) {
        _unlockButtonAnim.reverse();
        setState(() => _showUnlockButton = false);
      }
    });
  }

  // ── Controls Visibility ───────────────────────────────────────────────────
  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (_isPlaying && mounted && !_isLocked) {
        _controlsFadeAnim.reverse();
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    if (_isLocked) return;
    _controlsFadeAnim.forward();
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  void _toggleControls() {
    if (_isLocked) return;
    if (_showControls) {
      _controlsFadeAnim.reverse();
      setState(() => _showControls = false);
      _hideControlsTimer?.cancel();
    } else {
      _showControlsTemporarily();
    }
  }

  // ── Play / Pause ──────────────────────────────────────────────────────────
  void _togglePlayPause() {
    if (_isLocked) return;
    _player.playOrPause();
    if (!_showControls) {
      setState(() {
        _playPauseIcon = _isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;
        _showPlayPause = true;
      });
      _playPauseAnim.forward(from: 0);
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showPlayPause = false);
      });
    }
  }

  // ── Seek ──────────────────────────────────────────────────────────────────
  void _seekForward(int seconds) {
    if (_isLocked) return;
    final targetMs = (_position.inMilliseconds + seconds * 1000).clamp(
      0,
      _duration.inMilliseconds,
    );
    _player.seek(Duration(milliseconds: targetMs));
    setState(() => _showSeekRight = true);
    _seekRightAnim.forward(from: 0);
    _seekRightFeedbackTimer?.cancel();
    _seekRightFeedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSeekRight = false);
    });
    _showControlsTemporarily();
  }

  void _seekBackward(int seconds) {
    if (_isLocked) return;
    final targetMs = (_position.inMilliseconds - seconds * 1000).clamp(
      0,
      _duration.inMilliseconds,
    );
    _player.seek(Duration(milliseconds: targetMs));
    setState(() => _showSeekLeft = true);
    _seekLeftAnim.forward(from: 0);
    _seekLeftFeedbackTimer?.cancel();
    _seekLeftFeedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSeekLeft = false);
    });
    _showControlsTemporarily();
  }

  // ── Volume ────────────────────────────────────────────────────────────────
  void _adjustVolume(double delta) {
    final newVol = (_volume + delta).clamp(0.0, 1.0);
    setState(() => _volume = newVol);
    _player.setVolume(newVol * 100);
    _showVolumeOverlayBriefly();
    _showControlsTemporarily();
  }

  void _toggleMute() {
    if (_volume > 0) {
      _player.setVolume(0);
      setState(() => _volume = 0);
    } else {
      _player.setVolume(100);
      setState(() => _volume = 1.0);
    }
    _showVolumeOverlayBriefly();
  }

  void _showVolumeOverlayBriefly() {
    setState(() => _showVolumeOverlay = true);
    _hideVolumeOverlayTimer?.cancel();
    _hideVolumeOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showVolumeOverlay = false);
    });
  }

  // ── Aspect Ratio ──────────────────────────────────────────────────────────
  void _cycleAspectRatio() {
    setState(() => _aspectRatio = _aspectRatio.next);
    _showControlsTemporarily();
  }

  BoxFit get _videoFit {
    switch (_aspectRatio) {
      case _AspectRatioOption.bestFit:
        return BoxFit.contain;
      case _AspectRatioOption.fitToScreen:
        return BoxFit.cover;
    }
  }

  // ── Track Sheets ──────────────────────────────────────────────────────────
  void _openSheet(Widget sheet) {
    _hideControlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    ).whenComplete(_showControlsTemporarily);
  }

  bool _isRealAudioTrack(AudioTrack t) => t.id != 'no' && t.id != 'auto';
  bool _isRealSubtitleTrack(SubtitleTrack t) => t.id != 'no' && t.id != 'auto';

  void _showAudioSheet() {
    final firstRealTrack = _audioTracks.where(_isRealAudioTrack).isNotEmpty
        ? _audioTracks.where(_isRealAudioTrack).first
        : null;
    final bool isOff = _selectedAudio?.id == 'no';
    final bool isAuto = _selectedAudio == null || _selectedAudio?.id == 'auto';

    _openSheet(
      _TrackSheet(
        title: 'Audio Track',
        icon: Icons.music_note_rounded,
        items: [
          _TrackItem(
            label: 'Off',
            isSelected: isOff,
            onTap: () {
              _player.setAudioTrack(AudioTrack.no());
              setState(() => _selectedAudio = AudioTrack.no());
              Navigator.pop(context);
            },
          ),
          ..._audioTracks.where(_isRealAudioTrack).map((t) {
            final isSelected = isAuto
                ? t.id == firstRealTrack?.id
                : _selectedAudio?.id == t.id;
            return _TrackItem(
              label: _audioLabel(t),
              isSelected: isSelected,
              onTap: () {
                _player.setAudioTrack(t);
                setState(() => _selectedAudio = t);
                Navigator.pop(context);
              },
            );
          }),
        ],
        emptyMessage: 'No audio tracks found',
      ),
    );
  }

  void _showSubtitleSheet() => _openSheet(
        _TrackSheet(
          title: 'Subtitles',
          icon: Icons.subtitles_rounded,
          items: [
            _TrackItem(
              label: 'Off',
              isSelected: !_subtitlesEnabled,
              onTap: () {
                _player.setSubtitleTrack(SubtitleTrack.no());
                setState(() {
                  _subtitlesEnabled = false;
                  _selectedSubtitle = SubtitleTrack.no();
                });
                Navigator.pop(context);
              },
            ),
            ..._subtitleTracks.where(_isRealSubtitleTrack).map((t) {
              final isSelected = _subtitlesEnabled && t.id == _selectedSubtitle.id;
              return _TrackItem(
                label: _subtitleLabel(t),
                isSelected: isSelected,
                onTap: () {
                  _player.setSubtitleTrack(t);
                  setState(() {
                    _subtitlesEnabled = true;
                    _selectedSubtitle = t;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
          emptyMessage: 'No subtitle tracks found',
        ),
      );

  String _audioLabel(AudioTrack t) {
    final parts = <String>[];
    if (t.language != null && t.language!.isNotEmpty) {
      parts.add(t.language!.toUpperCase());
    }
    if (t.title != null && t.title!.isNotEmpty) parts.add(t.title!);
    if (parts.isEmpty) parts.add('Track ${t.id}');
    return parts.isEmpty ? 'Unknown' : parts.join(' — ');
  }

  String _subtitleLabel(SubtitleTrack t) {
    final parts = <String>[];
    if (t.language != null && t.language!.isNotEmpty) {
      parts.add(t.language!.toUpperCase());
    }
    if (t.title != null && t.title!.isNotEmpty) parts.add(t.title!);
    if (parts.isEmpty) parts.add('Track ${t.id}');
    return parts.isEmpty ? 'Unknown' : parts.join(' — ');
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final half = w / 2;

    final Widget rawVideo = Video(
      controller: _controller,
      controls: NoVideoControls,
      fill: Colors.black,
      fit: _videoFit,
    );
    final Widget videoWidget = _aspectRatio == _AspectRatioOption.fitToScreen
        ? ClipRect(child: rawVideo)
        : rawVideo;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: MouseRegion(
            onEnter: (_) => _showControlsTemporarily(),
            onHover: (_) {
              if (!_showControls) _showControlsTemporarily();
            },
            child: Stack(
              children: [
                // ── Video ──────────────────────────────────────────────────
                Positioned.fill(child: videoWidget),

                // ── Gesture Layer ──────────────────────────────────────────
                if (!_isLocked) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: half,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleControls,
                      onDoubleTap: () => _seekBackward(_seekSeconds),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: half,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleControls,
                      onDoubleTap: () => _seekForward(_seekSeconds),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 80,
                      height: h,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _togglePlayPause,
                      ),
                    ),
                  ),
                ],

                // ── Locked: full-screen absorber ──────────────────────────
                if (_isLocked)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onLockedTap,
                      child: const SizedBox.expand(),
                    ),
                  ),

                // ── Buffering ──────────────────────────────────────────────
                if (_isBuffering)
                  const Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),

                // ── Seek Feedbacks ─────────────────────────────────────────
                if (_showSeekLeft)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: half,
                    child: _SeekFeedback(
                      isLeft: true,
                      seconds: HardwareKeyboard.instance.isShiftPressed
                          ? _seekSecondsShift
                          : _seekSeconds,
                      anim: _seekLeftAnim,
                    ),
                  ),
                if (_showSeekRight)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: half,
                    child: _SeekFeedback(
                      isLeft: false,
                      seconds: HardwareKeyboard.instance.isShiftPressed
                          ? _seekSecondsShift
                          : _seekSeconds,
                      anim: _seekRightAnim,
                    ),
                  ),

                // ── Play/Pause Feedback ────────────────────────────────────
                if (_showPlayPause)
                  Center(
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _playPauseAnim,
                        curve: Curves.elasticOut,
                      ),
                      child: FadeTransition(
                        opacity: ReverseAnimation(
                          CurvedAnimation(
                            parent: _playPauseAnim,
                            curve: const Interval(0.6, 1.0),
                          ),
                        ),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _playPauseIcon,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Volume Overlay ─────────────────────────────────────────
                if (_showVolumeOverlay)
                  Positioned(
                    right: 24,
                    top: h * 0.2,
                    bottom: h * 0.2,
                    child: _SliderOverlay(
                      icon: _volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      value: _volume,
                    ),
                  ),

                // ── Controls Overlay ───────────────────────────────────────
                if (!_isLocked)
                  FadeTransition(
                    opacity: _controlsFadeAnim,
                    child: _showControls
                        ? _ControlsOverlay(
                            title: widget.title,
                            isPlaying: _isPlaying,
                            position: _position,
                            duration: _duration,
                            isDraggingSeek: _isDraggingSeek,
                            seekDragValue: _seekDragValue,
                            subtitlesEnabled: _subtitlesEnabled,
                            showRemainingTime: _showRemainingTime,
                            aspectRatio: _aspectRatio,
                            isFullscreen: _isFullscreen,
                            onPlayPause: _togglePlayPause,
                            onBack: () => Navigator.of(context).pop(),
                            onAudio: _showAudioSheet,
                            onSubtitle: _showSubtitleSheet,
                            onAspectRatio: _cycleAspectRatio,
                            onFullscreen: _toggleFullscreen,
                            onToggleTimeDisplay: () => setState(
                              () => _showRemainingTime = !_showRemainingTime,
                            ),
                            onLock: _lockControls,
                            onSeekChanged: (v) => setState(() {
                              _isDraggingSeek = true;
                              _seekDragValue = v;
                            }),
                            onSeekEnd: (v) {
                              final ms = (v * _duration.inMilliseconds).round();
                              _player.seek(Duration(milliseconds: ms));
                              setState(() => _isDraggingSeek = false);
                              _showControlsTemporarily();
                            },
                            fmt: _fmt,
                          )
                        : const SizedBox.shrink(),
                  ),

                // ── Unlock Button ──────────────────────────────────────────
                if (_isLocked && _showUnlockButton)
                  Positioned(
                    top: 14,
                    right: 20,
                    child: FadeTransition(
                      opacity: _unlockButtonAnim,
                      child: GestureDetector(
                        onTap: _unlockControls,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Unlock  (Esc / L)',
                                style: TextStyle(
                                  fontFamily: 'UberMove',
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controls Overlay
// ─────────────────────────────────────────────────────────────────────────────
class _ControlsOverlay extends StatelessWidget {
  final String title;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isDraggingSeek;
  final double seekDragValue;
  final bool subtitlesEnabled;
  final bool showRemainingTime;
  final _AspectRatioOption aspectRatio;
  final bool isFullscreen;
  final VoidCallback onPlayPause;
  final VoidCallback onBack;
  final VoidCallback onAudio;
  final VoidCallback onSubtitle;
  final VoidCallback onAspectRatio;
  final VoidCallback onFullscreen;
  final VoidCallback onToggleTimeDisplay;
  final VoidCallback onLock;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final String Function(Duration) fmt;

  const _ControlsOverlay({
    required this.title,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.isDraggingSeek,
    required this.seekDragValue,
    required this.subtitlesEnabled,
    required this.showRemainingTime,
    required this.aspectRatio,
    required this.isFullscreen,
    required this.onPlayPause,
    required this.onBack,
    required this.onAudio,
    required this.onSubtitle,
    required this.onAspectRatio,
    required this.onFullscreen,
    required this.onToggleTimeDisplay,
    required this.onLock,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.fmt,
  });

  double get _progress {
    if (isDraggingSeek) return seekDragValue;
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  Duration get _currentPosition => isDraggingSeek
      ? Duration(
          milliseconds: (seekDragValue * duration.inMilliseconds).round(),
        )
      : position;

  Duration get _remainingTime => duration - _currentPosition;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Top bar ───────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'UberMove',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 20),
                _TopBarButton(
                  icon: Icons.aspect_ratio_rounded,
                  label: aspectRatio.label,
                  onTap: onAspectRatio,
                  active: aspectRatio != _AspectRatioOption.bestFit,
                ),
                const SizedBox(width: 10),
                _TopBarButton(
                  icon: Icons.music_note_rounded,
                  label: 'Audio',
                  onTap: onAudio,
                  active: false,
                ),
                const SizedBox(width: 10),
                _TopBarButton(
                  icon: Icons.subtitles_rounded,
                  label: 'CC',
                  onTap: onSubtitle,
                  active: subtitlesEnabled,
                ),
                const SizedBox(width: 10),
                _TopBarButton(
                  icon: isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  label: isFullscreen ? 'Exit FS' : 'Full',
                  onTap: onFullscreen,
                  active: isFullscreen,
                ),
                const SizedBox(width: 10),
                _TopBarButton(
                  icon: Icons.lock_open_rounded,
                  label: 'Lock',
                  onTap: onLock,
                  active: false,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),

        // ── Centre play/pause ─────────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),

        // ── Bottom bar ─────────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fmt(_currentPosition),
                        style: const TextStyle(
                          fontFamily: 'UberMove',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: onToggleTimeDisplay,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            showRemainingTime
                                ? '-${fmt(_remainingTime)}'
                                : fmt(duration),
                            style: const TextStyle(
                              fontFamily: 'UberMove',
                              color: Colors.white60,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: _progress.clamp(0.0, 1.0),
                    onChanged: onSeekChanged,
                    onChangeEnd: onSeekEnd,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar Button
// ─────────────────────────────────────────────────────────────────────────────
class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  static const _accent = Color(0xFFA91743);

  const _TopBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: active ? _accent : Colors.white70, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'UberMove',
                    color: active ? _accent : Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (active)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TrackSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_TrackItem> items;
  final String emptyMessage;

  static const _bg = Color(0xFF181818);
  static const _accent = Color(0xFFA91743);

  const _TrackSheet({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: _accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'UberMove',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(
                      fontFamily: 'UberMove',
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                )
              : Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (_, i) => items[i],
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Item Row
// ─────────────────────────────────────────────────────────────────────────────
class _TrackItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const _accent = Color(0xFFA91743);

  const _TrackItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: 18,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: isSelected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'UberMove',
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: _accent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seek Feedback Widget
// ─────────────────────────────────────────────────────────────────────────────
class _SeekFeedback extends StatelessWidget {
  final bool isLeft;
  final int seconds;
  final AnimationController anim;

  const _SeekFeedback({
    required this.isLeft,
    required this.seconds,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final opacity =
            anim.value < 0.6 ? 1.0 : 1.0 - ((anim.value - 0.6) / 0.4);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                colors: [Colors.black, Colors.transparent],
                stops: const [0.0, 0.75],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLeft
                      ? Icons.fast_rewind_rounded
                      : Icons.fast_forward_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  '$seconds seconds',
                  style: const TextStyle(
                    fontFamily: 'UberMove',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slider Overlay (Volume)
// ─────────────────────────────────────────────────────────────────────────────
class _SliderOverlay extends StatelessWidget {
  final IconData icon;
  final double value;

  const _SliderOverlay({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Expanded(
            child: RotatedBox(
              quarterTurns: -1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              fontFamily: 'UberMove',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}