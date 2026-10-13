import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TimedCommentPin {
  final double fraction; // 0.0 -> 1.0
  final String avatarUrl;
  final String authorName;
  final String content;
  final VoidCallback? onTap;

  const TimedCommentPin({
    required this.fraction,
    required this.avatarUrl,
    required this.authorName,
    required this.content,
    this.onTap,
  });
}

/// Widget hiển thị dải sóng âm đặc trưng của SoundCloud
/// gồm các thanh biên độ (peaks), màu đã phát / chưa phát, và các avatar bình luận ghim tại mốc thời gian
class SoundCloudWaveform extends StatefulWidget {
  final double progress; // 0.0 -> 1.0
  final ValueChanged<double>? onSeek;
  final List<double>? peaks;
  final List<TimedCommentPin> comments;
  final double height;
  final Color? playedColor;
  final Color? unplayedColor;
  final bool showComments;
  final bool isInteractive;

  const SoundCloudWaveform({
    super.key,
    this.progress = 0.35,
    this.onSeek,
    this.peaks,
    this.comments = const [],
    this.height = 54.0,
    this.playedColor,
    this.unplayedColor,
    this.showComments = true,
    this.isInteractive = true,
  });

  @override
  State<SoundCloudWaveform> createState() => _SoundCloudWaveformState();
}

class _SoundCloudWaveformState extends State<SoundCloudWaveform> {
  late List<double> _effectivePeaks;

  @override
  void initState() {
    super.initState();
    _effectivePeaks = widget.peaks ?? _generateMockPeaks(60);
  }

  @override
  void didUpdateWidget(covariant SoundCloudWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.peaks != oldWidget.peaks && widget.peaks != null) {
      _effectivePeaks = widget.peaks!;
    }
  }

  List<double> _generateMockPeaks(int count) {
    final rand = math.Random(42);
    final list = <double>[];
    for (int i = 0; i < count; i++) {
      // Dải tần âm thanh hình chuông tự nhiên
      final factor = math.sin((i / count) * math.pi);
      final raw = 0.2 + (rand.nextDouble() * 0.7) * (0.4 + 0.6 * factor);
      list.add(raw.clamp(0.15, 0.98));
    }
    return list;
  }

  void _handleTouch(Offset localPosition, double width) {
    if (!widget.isInteractive || widget.onSeek == null) return;
    final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
    widget.onSeek!(fraction);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final playedCol = widget.playedColor ?? (isDark ? AppColors.primaryDark : AppColors.primaryLight);
    final unplayedCol = widget.unplayedColor ?? (isDark ? AppColors.outlineDark : AppColors.outlineLight);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return SizedBox(
          height: widget.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _handleTouch(details.localPosition, width),
            onHorizontalDragUpdate: (details) => _handleTouch(details.localPosition, width),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Thanh sóng âm CustomPainter
                CustomPaint(
                  size: Size(width, widget.height),
                  painter: _SoundCloudWaveformPainter(
                    peaks: _effectivePeaks,
                    progress: widget.progress.clamp(0.0, 1.0),
                    playedColor: playedCol,
                    unplayedColor: unplayedCol,
                  ),
                ),

                // Ghim avatar bình luận (Timed Comments Pins)
                if (widget.showComments && widget.comments.isNotEmpty)
                  ...widget.comments.map((comment) {
                    final leftPos = (comment.fraction * width) - 10;
                    return Positioned(
                      left: leftPos.clamp(0.0, width - 20),
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (comment.onTap != null) {
                            comment.onTap!();
                          } else if (widget.onSeek != null) {
                            widget.onSeek!(comment.fraction);
                          }
                        },
                        child: Tooltip(
                          message: '${comment.authorName}: ${comment.content}',
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                comment.avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: AppColors.primaryLight,
                                  child: const Icon(Icons.person, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SoundCloudWaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _SoundCloudWaveformPainter({
    required this.peaks,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width <= 0) return;

    const barWidth = 2.5;
    const barSpacing = 1.8;
    const totalStep = barWidth + barSpacing;

    final barCount = (size.width / totalStep).floor();
    if (barCount <= 0) return;

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final splitX = size.width * progress;

    for (int i = 0; i < barCount; i++) {
      final x = i * totalStep + (barWidth / 2);
      final peakIndex = ((i / barCount) * peaks.length).floor().clamp(0, peaks.length - 1);
      final amplitude = peaks[peakIndex];

      // Sóng âm có chiều cao tối thiểu 4dp
      final barHeight = (size.height * 0.85 * amplitude).clamp(4.0, size.height);
      final topY = (size.height - barHeight) / 2;
      final bottomY = topY + barHeight;

      final isPlayed = x <= splitX;
      canvas.drawLine(
        Offset(x, topY),
        Offset(x, bottomY),
        isPlayed ? playedPaint : unplayedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoundCloudWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor ||
        oldDelegate.peaks != peaks;
  }
}
