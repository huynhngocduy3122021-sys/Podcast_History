import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:podcast_history/core/network/api_client.dart' show ApiException;
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/image_url_helper.dart' show resolveImageUrl;
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_livestream_model.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/series/series_management_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/wallet_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_notification_button.dart';
import 'package:podcast_history/features/livestream/chat_credentials.dart';
import 'package:podcast_history/features/livestream/livestream_chat_panel.dart';

class CreatorLivestreamScreen extends ConsumerStatefulWidget {
  const CreatorLivestreamScreen({super.key});

  @override
  ConsumerState<CreatorLivestreamScreen> createState() =>
      _CreatorLivestreamScreenState();
}

class _CreatorLivestreamScreenState
    extends ConsumerState<CreatorLivestreamScreen> {
  // Agora RTC Engine State
  RtcEngine? _engine;
  VideoViewController? _videoViewController;
  bool _isEngineReady = false;
  bool _isLive = false;
  bool _isLoading = false;
  bool _isMuted = false;
  bool _isVideoDisabled = false;
  bool _cameraUnavailable = false;
  bool _isSwitchingCamera = false;
  String _connectionStatus = 'Sẵn sàng';

  // Active Livestream Information
  String? _activeLivestreamId;
  String? _activeChannelName;
  String? _activeTitle;

  // Timer & Stats
  Timer? _durationTimer;
  int _liveSeconds = 0;

  // Form Controllers
  final _titleController = TextEditingController(
    text: 'Giao lưu Lịch sử & Kể chuyện cùng Thính giả',
  );
  final _descController = TextEditingController(
    text: 'Cùng thảo luận về các sự kiện hào hùng, giải đáp thắc mắc và chia sẻ góc nhìn lịch sử mới mẻ.',
  );
  bool _isScheduled = false;
  DateTime? _scheduledDateTime;

  // Filter for livestream list
  String _selectedFilter = 'ALL'; // ALL, DRAFT, LIVE, ENDED

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _disposeAgoraEngine();
    super.dispose();
  }

  // --- AGORA RTC LIFECYCLE ---

  Future<bool> _requestPermissions() async {
    if (kIsWeb) {
      _isVideoDisabled = false;
      _cameraUnavailable = false;
      return true;
    }
    final statuses = await [Permission.camera, Permission.microphone].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

    if (!micGranted) {
      if (mounted) {
        _showErrorSnackBar('Vui lòng cấp quyền Microphone để phát livestream.');
      }
      return false;
    }
    _isVideoDisabled = !cameraGranted;
    _cameraUnavailable = !cameraGranted;
    return true;
  }

  Future<void> _initAgoraEngine(String appId) async {
    if (_engine != null) {
      await _disposeAgoraEngine();
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (!mounted) return;
            setState(() {
              _isLive = true;
              _connectionStatus = 'Đang phát sóng';
            });
            _startDurationTimer();
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            if (!mounted) return;
            setState(() {
              _isLive = false;
              _connectionStatus = 'Đã rời phòng';
            });
            _stopDurationTimer();
          },
          onTokenPrivilegeWillExpire:
              (RtcConnection connection, String token) async {
                _renewHostToken();
              },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora Error] $err: $msg');
            if (mounted) {
              _showErrorSnackBar('Lỗi Agora: $msg ($err)');
            }
          },
        ),
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();
      if (!_isVideoDisabled) {
        try {
          await _engine!.enableVideo();
          await _engine!.startPreview();
          _videoViewController = VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0),
          );
        } catch (cameraError) {
          debugPrint('Không thể mở camera, tiếp tục phát audio: $cameraError');
          _isVideoDisabled = true;
          _cameraUnavailable = true;
          try {
            await _engine!.disableVideo();
          } catch (_) {}
          if (mounted) {
            _showErrorSnackBar(
              'Không mở được camera. Livestream sẽ phát âm thanh.',
            );
          }
        }
      }

      setState(() {
        _isEngineReady = true;
      });
    } catch (e) {
      debugPrint('Error initializing Agora engine: $e');
      rethrow;
    }
  }

  Future<void> _disposeAgoraEngine() async {
    _stopDurationTimer();
    if (_videoViewController != null) {
      try {
        await _videoViewController!.dispose();
      } catch (_) {}
      _videoViewController = null;
    }

    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
      } catch (_) {}
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
    }

    _isEngineReady = false;
  }

  Future<void> _renewHostToken() async {
    if (_activeLivestreamId == null || _engine == null) return;
    try {
      debugPrint('Token sắp hết hạn, tự động gọi API gia hạn...');
      final response = await ref
          .read(creatorLivestreamsProvider.notifier)
          .renewToken(_activeLivestreamId!);
      await _engine!.renewToken(response.token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tự động gia hạn Agora Token thành công.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Lỗi gia hạn token: $e');
    }
  }

  // --- ACTIONS ---

  Future<void> _startNewLivestream() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập tiêu đề cho buổi Livestream.');
      return;
    }
    if (title.length > 220) {
      _showErrorSnackBar('Tiêu đề không được vượt quá 220 ký tự.');
      return;
    }

    final hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    setState(() => _isLoading = true);

    try {
      // 1. Tạo bản nháp (DRAFT)
      final draft = await ref
          .read(creatorLivestreamsProvider.notifier)
          .createLivestream(
            title: title,
            description: _descController.text.trim(),
            scheduledAt: _isScheduled ? _scheduledDateTime : null,
          );

      // 2. Gọi /start để chuyển sang LIVE và nhận AgoraJoin credentials
      final join = await ref
          .read(creatorLivestreamsProvider.notifier)
          .startLivestream(draft.livestreamId);

      _activeLivestreamId = draft.livestreamId;
      _activeChannelName = join.channelName;
      _activeTitle = draft.title;

      // 3. Khởi tạo Agora Engine
      await _initAgoraEngine(join.appId);

      // 4. Tham gia kênh bằng user account (theo chuẩn AGORA_SETUP)
      await _engine!.joinChannelWithUserAccount(
        token: join.token,
        channelId: join.channelName,
        userAccount: join.userAccount,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: !_isVideoDisabled,
          publishMicrophoneTrack: true,
        ),
      );

      setState(() {
        _isLive = true;
        _isLoading = false;
      });
    } catch (e) {
      await _disposeAgoraEngine();
      setState(() => _isLoading = false);
      _handleApiError(e, 'Không thể bắt đầu phát trực tiếp');
    }
  }

  Future<void> _startExistingLivestream(CreatorLivestreamItem item) async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    setState(() => _isLoading = true);

    try {
      final join = await ref
          .read(creatorLivestreamsProvider.notifier)
          .startLivestream(item.livestreamId);

      _activeLivestreamId = item.livestreamId;
      _activeChannelName = join.channelName;
      _activeTitle = item.title;

      await _initAgoraEngine(join.appId);

      await _engine!.joinChannelWithUserAccount(
        token: join.token,
        channelId: join.channelName,
        userAccount: join.userAccount,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: !_isVideoDisabled,
          publishMicrophoneTrack: true,
        ),
      );

      setState(() {
        _isLive = true;
        _isLoading = false;
      });
    } catch (e) {
      await _disposeAgoraEngine();
      setState(() => _isLoading = false);
      _handleApiError(e, 'Không thể vào phòng phát trực tiếp');
    }
  }

  Future<void> _saveDraftOnly() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập tiêu đề cho buổi Livestream.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(creatorLivestreamsProvider.notifier)
          .createLivestream(
            title: title,
            description: _descController.text.trim(),
            scheduledAt: _isScheduled ? _scheduledDateTime : null,
          );
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu bản nháp livestream thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _handleApiError(e, 'Không thể lưu bản nháp');
    }
  }

  Future<void> _confirmAndEndLive([String? targetId]) async {
    final idToEnd = targetId ?? _activeLivestreamId;
    if (idToEnd == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết thúc Livestream?'),
        content: const Text(
          'Bạn có chắc chắn muốn kết thúc buổi phát này không? Thính giả sẽ không thể tiếp tục theo dõi và trạng thái sẽ chuyển sang ĐÃ KẾT THÚC.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kết thúc ngay'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(creatorLivestreamsProvider.notifier)
          .endLivestream(idToEnd);
    } catch (e) {
      debugPrint('Error calling /end endpoint: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _handleApiError(e, 'Không thể kết thúc livestream trên máy chủ');
      }
      return;
    }

    if (idToEnd == _activeLivestreamId) {
      await _disposeAgoraEngine();
      if (mounted) {
        setState(() {
          _isLive = false;
          _isLoading = false;
          _activeLivestreamId = null;
          _activeChannelName = null;
          _activeTitle = null;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
      ref.read(creatorLivestreamsProvider.notifier).loadLivestreams();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã kết thúc buổi Livestream.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleScheduleToggle(bool val) async {
    if (val) {
      final now = DateTime.now();
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(hours: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 30)),
      );
      if (pickedDate != null && mounted) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(
            now.add(const Duration(hours: 1)),
          ),
        );
        if (pickedTime != null && mounted) {
          setState(() {
            _isScheduled = true;
            _scheduledDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          });
          return;
        }
      }
    } else {
      setState(() {
        _isScheduled = false;
        _scheduledDateTime = null;
      });
    }
  }

  // --- CONTROLS ---

  Future<void> _toggleMute() async {
    if (_engine == null) return;
    final nextState = !_isMuted;
    await _engine!.muteLocalAudioStream(nextState);
    setState(() => _isMuted = nextState);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isMuted ? 'Đã tắt Micro' : 'Đã bật Micro'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleVideo() async {
    if (_engine == null) return;
    if (_isVideoDisabled && _videoViewController == null) {
      if (!kIsWeb && !(await Permission.camera.request()).isGranted) {
        _showErrorSnackBar('Cần cấp quyền Camera để bật hình ảnh.');
        return;
      }
      VideoViewController? controller;
      try {
        await _engine!.enableVideo();
        await _engine!.startPreview();
        controller = VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
        );
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(publishCameraTrack: true),
        );
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() {
          _videoViewController = controller;
          _isVideoDisabled = false;
          _cameraUnavailable = false;
        });
      } catch (error) {
        await controller?.dispose();
        debugPrint('Không thể bật camera: $error');
        try {
          await _engine!.disableVideo();
        } catch (_) {}
        if (mounted) _showErrorSnackBar('Không mở được camera: $error');
      }
      return;
    }
    final nextState = !_isVideoDisabled;
    await _engine!.muteLocalVideoStream(nextState);
    setState(() {
      _isVideoDisabled = nextState;
      _cameraUnavailable = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isVideoDisabled ? 'Đã tắt Camera' : 'Đã bật Camera'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_engine == null || _isSwitchingCamera) return;
    if (_cameraUnavailable) {
      _showErrorSnackBar('Chưa có camera để chuyển.');
      return;
    }
    _isSwitchingCamera = true;
    try {
      await _engine!.switchCamera();
    } catch (e) {
      debugPrint('Switch camera error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _liveSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _liveSeconds++);
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _liveSeconds = 0;
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _handleApiError(dynamic error, String defaultPrefix) {
    final agoraConfigMissing =
        error is ApiException &&
        error.statusCode == 503 &&
        (error.message.contains('AGORA_APP_ID') ||
            error.message.contains('Agora chưa được cấu hình'));
    if (agoraConfigMissing) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 40,
          ),
          title: const Text('Agora chưa được cấu hình'),
          content: const Text(
            'Máy chủ Backend chưa được điền AGORA_APP_ID và AGORA_APP_CERTIFICATE trong file Backend/.env.\n\nVui lòng cấu hình trên server để sử dụng tính năng Livestream theo tài liệu AGORA_SETUP.md.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    } else {
      _showErrorSnackBar('$defaultPrefix: $error');
    }
  }

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value;

    return Scaffold(
      appBar: _isLive
          ? null
          : AppBar(
              title: const Text('Livestream Studio'),
        actions: [
          // Nút Series
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SeriesManagementScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : const Color(0xFFF3ECE4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.outlineDark
                          : const Color(0xFFDFD4C8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_collection_rounded,
                        size: 15,
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Series',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Nút Ví tiền
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : const Color(0xFFF3ECE4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.outlineDark
                          : const Color(0xFFDFD4C8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 15,
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        wallet != null
                            ? '${(wallet.available / 1000).toStringAsFixed(0)}k đ'
                            : 'Ví tiền',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const CreatorNotificationButton(),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _isLive
          ? _buildLiveBroadcastingView(isDark)
          : _buildStudioSetupView(isDark),
    );
  }

  // --- VIEW: BROADCASTING (WHEN LIVE) ---

  Widget _buildLiveBroadcastingView(bool isDark) {
    final creatorProfile = ref.watch(creatorProfileProvider).value;
    final avatarUrl = creatorProfile?.avatarUrl;
    final displayName = creatorProfile?.name.isNotEmpty == true
        ? creatorProfile!.name
        : (_activeTitle ?? 'Phát trực tiếp');

    final controlButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTikTokGlassButton(
          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          isActive: !_isMuted,
          isDestructive: _isMuted,
          tooltip: _isMuted ? 'Bật Mic' : 'Tắt Mic',
          onTap: _toggleMute,
        ),
        const SizedBox(width: 8),
        _buildTikTokGlassButton(
          icon: _isVideoDisabled
              ? Icons.videocam_off_rounded
              : Icons.videocam_rounded,
          isActive: !_isVideoDisabled,
          isDestructive: _isVideoDisabled,
          tooltip: _isVideoDisabled ? 'Bật Cam' : 'Tắt Cam',
          onTap: _toggleVideo,
        ),
        const SizedBox(width: 8),
        _buildTikTokGlassButton(
          icon: Icons.flip_camera_ios_rounded,
          tooltip: 'Đổi Cam',
          onTap: _switchCamera,
        ),
        const SizedBox(width: 8),
        _buildTikTokGlassButton(
          icon: Icons.call_end_rounded,
          isDestructive: true,
          tooltip: 'Kết thúc Live',
          onTap: () => _confirmAndEndLive(),
        ),
      ],
    );

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Agora Local Video Feed
          if (_videoViewController != null &&
              _isEngineReady &&
              !_isVideoDisabled)
            AgoraVideoView(controller: _videoViewController!)
          else
            Container(
              color: const Color(0xFF141414),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white12,
                      child: Icon(
                        _isVideoDisabled
                            ? Icons.videocam_off_rounded
                            : Icons.sensors_rounded,
                        size: 46,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _cameraUnavailable
                          ? 'Không có camera - đang phát âm thanh'
                          : _isVideoDisabled
                          ? 'Camera đang tắt'
                          : 'Đang kết nối tín hiệu...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isMuted
                          ? 'Micro đang tắt'
                          : 'Âm thanh vẫn đang phát trực tiếp',
                      style: TextStyle(
                        color: _isMuted ? AppColors.error : Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Top Scrim Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 130,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Scrim Gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 350,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 4. TikTok Top Bar (Host Pill + Series + Close)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 12,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Host Capsule Pill
                Tooltip(
                  message: _activeChannelName != null
                      ? 'Kênh: $_activeChannelName • $_connectionStatus'
                      : _connectionStatus,
                  child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white24,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: (avatarUrl != null &&
                                avatarUrl.trim().isNotEmpty)
                            ? NetworkImage(resolveImageUrl(avatarUrl))
                            : null,
                        child: (avatarUrl == null || avatarUrl.trim().isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatDuration(_liveSeconds),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (_connectionStatus != 'Đang phát sóng' &&
                                    _connectionStatus != 'Sẵn sàng') ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '• $_connectionStatus',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),

                const Spacer(),

                // Series Shortcut Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SeriesManagementScreen(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.video_collection_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Series',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Close / End Live Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _confirmAndEndLive(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                          color: Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. TikTok Chat Panel with Floating Bubbles + Bottom Action Bar
          if (_activeLivestreamId != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              height: 320,
              child: LivestreamChatPanel(
                key: ValueKey('chat-$_activeLivestreamId'),
                livestreamId: _activeLivestreamId!,
                isOverlay: true,
                trailingActions: controlButtons,
                loadCredentials: () async {
                  final result = await ref
                      .read(apiClientProvider)
                      .post(
                        '/api/creator/livestreams/$_activeLivestreamId/chat-token',
                      );
                  return ChatCredentials.fromJson(
                    result as Map<String, dynamic>,
                  );
                },
              ),
            )
          else
            Positioned(
              right: 12,
              bottom: 12,
              child: controlButtons,
            ),

          // 6. Loading overlay if busy
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTikTokGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool isActive = true,
    bool isDestructive = false,
  }) {
    Color bg;
    Color fg;
    if (isDestructive) {
      bg = const Color(0xFFE53935);
      fg = Colors.white;
    } else if (isActive) {
      bg = Colors.black.withValues(alpha: 0.5);
      fg = Colors.white;
    } else {
      bg = Colors.black.withValues(alpha: 0.35);
      fg = Colors.white54;
    }

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDestructive ? Colors.transparent : Colors.white24,
              width: 0.8,
            ),
          ),
          child: Icon(icon, color: fg, size: 20),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  // --- VIEW: STUDIO SETUP (WHEN IDLE) ---

  Widget _buildStudioSetupView(bool isDark) {
    final livestreamsAsync = ref.watch(creatorLivestreamsProvider);

    return livestreamsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Không thể tải dữ liệu Livestream: $e',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                onPressed: () => ref
                    .read(creatorLivestreamsProvider.notifier)
                    .loadLivestreams(),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        // Kiểm tra xem kênh có phiên nào đang LIVE hay không
        final activeLive = items.cast<CreatorLivestreamItem?>().firstWhere(
          (it) => it?.isLive == true,
          orElse: () => null,
        );

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(creatorLivestreamsProvider.notifier)
                    .loadLivestreams();
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  // 1. Cảnh báo hoặc thẻ tham gia lại nếu kênh đang có 1 phiên LIVE
                  if (activeLive != null) ...[
                    _buildActiveLiveAlertBanner(activeLive, isDark),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 2. Thẻ Thiết lập và Bắt đầu buổi Livestream mới
                  _buildStreamCreationCard(isDark, activeLive != null),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Hướng dẫn & Tiêu chuẩn phát sóng Agora RTC
                  _buildAgoraStandardsCard(isDark),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. Danh sách các buổi Livestream của Creator (Mine)
                  _buildLivestreamListSection(items, isDark),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  // --- CARD: ACTIVE LIVE ALERT ---

  Widget _buildActiveLiveAlertBanner(
    CreatorLivestreamItem liveItem,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text(
                      'PHIÊN ĐANG PHÁT SÓNG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (liveItem.startedAt != null)
                Text(
                  'Bắt đầu: ${DateFormat('HH:mm - dd/MM').format(liveItem.startedAt!.toLocal())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            liveItem.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Kênh của bạn hiện có phiên livestream đang ở trạng thái LIVE. Mỗi kênh chỉ được phép phát 1 phiên cùng lúc theo quy định Agora.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? AppColors.onSurfaceMutedDark
                  : AppColors.onSurfaceMutedLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.sensors_rounded, size: 18),
                  label: const Text('Vào phòng phát lại'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: () => _startExistingLivestream(liveItem),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Kết thúc phiên'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () => _confirmAndEndLive(liveItem.livestreamId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CARD: STREAM CREATION ---

  Widget _buildStreamCreationCard(bool isDark, bool hasActiveLive) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.video_call_rounded,
                size: 20,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
              const SizedBox(width: 8),
              const Text(
                'Thiết lập buổi Livestream mới',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Tiêu đề
          AppTextField(
            label: 'Tiêu đề buổi Livestream *',
            controller: _titleController,
            hint: 'Nhập tiêu đề hấp dẫn (tối đa 220 ký tự)...',
          ),
          const SizedBox(height: AppSpacing.md),

          // Mô tả
          AppTextField(
            label: 'Mô tả nội dung & Lộ trình trao đổi',
            controller: _descController,
            hint: 'Tóm tắt nội dung sẽ thảo luận cùng thính giả...',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),

          // Lên lịch phát sóng
          InkWell(
            onTap: () => _handleScheduleToggle(!_isScheduled),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lên lịch phát sóng sau',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isScheduled && _scheduledDateTime != null
                              ? 'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(_scheduledDateTime!.toLocal())}'
                              : 'Đặt trước thời gian dự kiến phát trực tiếp',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.onSurfaceMutedDark
                                : AppColors.onSurfaceMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isScheduled,
                    onChanged: _handleScheduleToggle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Nút hành động
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: hasActiveLive
                      ? 'Kênh đang có phiên LIVE'
                      : 'Bắt đầu phát trực tiếp',
                  icon: const Icon(Icons.sensors_rounded, size: 18),
                  type: AppButtonType.primary,
                  onPressed: hasActiveLive ? null : _startNewLivestream,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Lưu nháp'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _saveDraftOnly,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CARD: AGORA STANDARDS & PROTOCOL ---

  Widget _buildAgoraStandardsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.info),
              SizedBox(width: 8),
              Text(
                'Cơ chế kết nối Agora RTC (Real-Time)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '• Hệ thống sử dụng Agora RTC WebRTC, truyền trực tiếp hình ảnh/âm thanh từ Camera & Micro của bạn tới người nghe.\n'
            '• Token kết nối được cấp tự động từ máy chủ bảo mật và có thời hạn 3600s (ứng dụng tự động gia hạn khi phát).\n'
            '• Mỗi kênh Creator chỉ được phép mở duy nhất 1 phòng LIVE cùng lúc.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: isDark
                  ? AppColors.onSurfaceMutedDark
                  : AppColors.onSurfaceMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION: LIVESTREAM LIST (MINE) ---

  Widget _buildLivestreamListSection(
    List<CreatorLivestreamItem> items,
    bool isDark,
  ) {
    // Filter
    final filteredItems = items.where((item) {
      if (_selectedFilter == 'DRAFT') return item.isDraft;
      if (_selectedFilter == 'LIVE') return item.isLive;
      if (_selectedFilter == 'ENDED') return item.isEnded;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Danh sách Livestream của kênh',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              '${items.length} buổi',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.onSurfaceMutedDark
                    : AppColors.onSurfaceMutedLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tất cả', 'ALL'),
              const SizedBox(width: 6),
              _buildFilterChip('Đang phát (LIVE)', 'LIVE'),
              const SizedBox(width: 6),
              _buildFilterChip('Bản nháp (DRAFT)', 'DRAFT'),
              const SizedBox(width: 6),
              _buildFilterChip('Đã kết thúc (ENDED)', 'ENDED'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (filteredItems.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 40,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
                const SizedBox(height: 8),
                Text(
                  'Chưa có buổi Livestream nào trong mục này.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.onSurfaceMutedDark
                        : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          )
        else
          ...filteredItems.map(
            (item) => _buildLivestreamItemCard(item, isDark),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildLivestreamItemCard(CreatorLivestreamItem item, bool isDark) {
    StatusType chipType;
    String statusLabel;
    if (item.isLive) {
      chipType = StatusType.error;
      statusLabel = 'ĐANG PHÁT';
    } else if (item.isDraft) {
      chipType = StatusType.warning;
      statusLabel = 'BẢN NHÁP';
    } else {
      chipType = StatusType.neutral;
      statusLabel = 'ĐÃ KẾT THÚC';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: item.isLive
              ? AppColors.error.withValues(alpha: 0.5)
              : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
          width: item.isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: statusLabel, type: chipType),
              const Spacer(),
              if (item.createdAt != null)
                Text(
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(item.createdAt!.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.onSurfaceMutedDark
                        : AppColors.onSurfaceMutedLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description!,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.onSurfaceMutedDark
                    : AppColors.onSurfaceMutedLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),

          // Dates info & actions
          Row(
            children: [
              if (item.scheduledAt != null)
                Expanded(
                  child: Text(
                    'Lịch phát: ${DateFormat('dd/MM HH:mm').format(item.scheduledAt!.toLocal())}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (item.startedAt != null)
                Expanded(
                  child: Text(
                    'Bắt đầu: ${DateFormat('HH:mm dd/MM').format(item.startedAt!.toLocal())}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                )
              else
                const Spacer(),

              // Quick Actions based on status
              if (item.isDraft)
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Phát ngay'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _startExistingLivestream(item),
                )
              else if (item.isLive)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () => _startExistingLivestream(item),
                      child: const Text('Vào lại'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () => _confirmAndEndLive(item.livestreamId),
                      child: const Text('Kết thúc'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
