import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:podcast_history/api_service.dart';
import 'package:podcast_history/features/livestream/livestream_chat_panel.dart';
import 'package:podcast_history/features/notifications/notification_socket.dart';

class ListenerLivestreamScreen extends StatefulWidget {
  const ListenerLivestreamScreen({
    super.key,
    required this.api,
    required this.socket,
  });
  final ListenerApi api;
  final NotificationSocket socket;
  @override
  State<ListenerLivestreamScreen> createState() =>
      _ListenerLivestreamScreenState();
}

class _ListenerLivestreamScreenState extends State<ListenerLivestreamScreen> {
  List<ListenerLivestream> _items = const [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.socket.listen('/topic/livestreams', (_) => _load());
    _load();
  }

  @override
  void dispose() {
    widget.socket.unlisten('/topic/livestreams');
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.liveLivestreams();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Đang phát trực tiếp',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Vuốt lên hoặc xuống để chuyển nhanh giữa các buổi livestream.',
        ),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _StateCard(
            icon: Icons.cloud_off,
            message: 'Không thể tải danh sách livestream.\n$_error',
            action: TextButton(onPressed: _load, child: const Text('Thử lại')),
          )
        else if (_items.isEmpty)
          const _StateCard(
            icon: Icons.live_tv_outlined,
            message: 'Hiện chưa có livestream nào đang phát.',
          )
        else
          ..._items.map(
            (item) => _LivestreamCard(
              item: item,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListenerLivestreamFeedPage(
                    api: widget.api,
                    livestreams: _items,
                    initialIndex: _items.indexOf(item),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _LivestreamCard extends StatelessWidget {
  const _LivestreamCard({required this.item, required this.onTap});
  final ListenerLivestream item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.live_tv, color: Colors.red),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 9),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(item.creatorChannelName),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class ListenerLivestreamFeedPage extends StatefulWidget {
  const ListenerLivestreamFeedPage({
    super.key,
    required this.api,
    required this.livestreams,
    required this.initialIndex,
  });
  final ListenerApi api;
  final List<ListenerLivestream> livestreams;
  final int initialIndex;
  @override
  State<ListenerLivestreamFeedPage> createState() =>
      _ListenerLivestreamFeedPageState();
}

class _ListenerLivestreamFeedPageState
    extends State<ListenerLivestreamFeedPage> {
  late final PageController _pageController;
  late int _index;
  RtcEngine? _engine;
  VideoViewController? _videoController;
  int? _remoteUid;
  bool _loading = true;
  String? _error;
  bool _chatOpen = false;
  bool _chatSessionEnded = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.livestreams.length - 1);
    _pageController = PageController(initialPage: _index);
    _joinLivestream();
  }

  Future<void> _joinLivestream() async {
    final item = widget.livestreams[_index];
    try {
      final detail = await widget.api.livestream(item.livestreamId);
      final join = await widget.api.joinLivestream(detail.livestreamId);
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: join.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, _) {
            if (mounted) setState(() => _loading = false);
          },
          onUserJoined: (_, uid, _) {
            if (!mounted) return;
            setState(() {
              _remoteUid = uid;
              _videoController = VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: join.channelName),
              );
            });
          },
          onUserOffline: (_, uid, _) {
            if (mounted && _remoteUid == uid) setState(() => _remoteUid = null);
          },
          onTokenPrivilegeWillExpire: (_, _) async {
            try {
              final refreshed = await widget.api.joinLivestream(
                item.livestreamId,
              );
              await engine.renewToken(refreshed.token);
            } catch (_) {}
          },
          onError: (_, message) {
            if (mounted && _remoteUid == null) setState(() => _error = message);
          },
        ),
      );
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.enableVideo();
      await engine.joinChannelWithUserAccount(
        token: join.token,
        channelId: join.channelName,
        userAccount: join.userAccount,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      _engine = engine;
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkLivestreamStatus(item.livestreamId),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _checkLivestreamStatus(String livestreamId) async {
    try {
      final detail = await widget.api.livestream(livestreamId);
      if (!mounted || detail.status.toUpperCase() == 'LIVE') return;
      _statusTimer?.cancel();
      await _leave();
      if (mounted) {
        setState(() {
          _chatOpen = false;
          _chatSessionEnded = true;
          _error = 'Livestream đã kết thúc.';
          _loading = false;
        });
      }
    } catch (_) {
      // Keep the current chat session when a temporary status check fails.
    }
  }

  Future<void> _leave() async {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) await controller.dispose();
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      await engine.leaveChannel();
      await engine.release();
    }
  }

  Future<void> _changeLivestream(int index) async {
    if (index == _index) return;
    _statusTimer?.cancel();
    await _leave();
    if (!mounted) return;
    setState(() {
      _index = index;
      _loading = true;
      _error = null;
      _remoteUid = null;
      _chatOpen = false;
      _chatSessionEnded = false;
    });
    await _joinLivestream();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pageController.dispose();
    unawaited(_leave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.livestreams.length,
      onPageChanged: _changeLivestream,
      itemBuilder: (_, i) => _buildLivePage(widget.livestreams[i]),
    ),
  );

  Widget _buildLivePage(ListenerLivestream item) {
    final current =
        item.livestreamId == widget.livestreams[_index].livestreamId;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (current && _remoteUid != null && _videoController != null)
          AgoraVideoView(controller: _videoController!)
        else
          const ColoredBox(color: Colors.black),
        if (current && _error != null)
          Center(
            child: Text(
              'Không thể tham gia livestream.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          )
        else if (current && _remoteUid == null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  _loading
                      ? 'Đang kết nối tới livestream…'
                      : 'Đang chờ Creator vào phòng phát.',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        const _LiveGradient(),
        SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 10, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${item.creatorChannelName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description ??
                                'Đang giao lưu trực tiếp cùng thính giả.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 18),
                    child: Column(
                      children: [
                        _LiveAction(
                          icon: Icons.chat_bubble,
                          label: 'Chat',
                          onTap: () => _showComments(item),
                        ),
                        const SizedBox(height: 16),
                        _LiveAction(
                          icon: Icons.flag_outlined,
                          label: 'Báo cáo',
                          onTap: () => _reportLivestream(item),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (current && _chatOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _chatOpen = false),
              child: const SizedBox.expand(),
            ),
          ),
        if (current && !_chatSessionEnded)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            height: MediaQuery.sizeOf(context).height * .58,
            child: Offstage(
              offstage: !_chatOpen,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xff191919),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Đóng chat',
                          onPressed: () => setState(() => _chatOpen = false),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        child: LivestreamChatPanel(
                          key: ValueKey('listener-chat-${item.livestreamId}'),
                          livestreamId: item.livestreamId,
                          loadCredentials: () =>
                              widget.api.livestreamChatToken(item.livestreamId),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showComments(ListenerLivestream item) {
    if (item.livestreamId != widget.livestreams[_index].livestreamId ||
        _chatSessionEnded) {
      return;
    }
    setState(() => _chatOpen = true);
  }

  Future<void> _reportLivestream(ListenerLivestream item) async {
    if (item.livestreamId != widget.livestreams[_index].livestreamId ||
        _chatSessionEnded) {
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LivestreamReportSheet(api: widget.api, item: item),
    );
    if (!mounted || sent != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã gửi báo cáo livestream cho người quản trị.'),
      ),
    );
  }
}

class _LivestreamReportSheet extends StatefulWidget {
  const _LivestreamReportSheet({required this.api, required this.item});
  final ListenerApi api;
  final ListenerLivestream item;

  @override
  State<_LivestreamReportSheet> createState() => _LivestreamReportSheetState();
}

class _LivestreamReportSheetState extends State<_LivestreamReportSheet> {
  static const _reasons = <String, String>{
    'FALSE_HISTORY': 'Thông tin lịch sử sai hoặc xuyên tạc',
    'OFF_TOPIC': 'Nội dung không liên quan',
    'INAPPROPRIATE_SPEECH': 'Lời nói không phù hợp',
    'OTHER': 'Khác',
  };
  final _description = TextEditingController();
  String _reasonCode = 'FALSE_HISTORY';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(
        () => _error = 'Hãy mô tả lời nói hoặc thời điểm xảy ra để người quản trị kiểm tra.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.createReport(
        targetType: 'LIVESTREAM',
        targetId: widget.item.livestreamId,
        reasonCode: _reasonCode,
        description: description,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Không thể gửi báo cáo: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Báo cáo livestream',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(widget.item.title),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _reasonCode,
              decoration: const InputDecoration(labelText: 'Lý do báo cáo'),
              items: _reasons.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) {
                      if (value != null) setState(() => _reasonCode = value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_sending,
              minLines: 3,
              maxLines: 5,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Mô tả chi tiết',
                hintText:
                    'Nội dung đã nói và thời điểm gần đúng trong buổi live',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                child: Text(_sending ? 'Đang gửi…' : 'Gửi báo cáo'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LiveAction extends StatelessWidget {
  const _LiveAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.black54,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LiveGradient extends StatelessWidget {
  const _LiveGradient();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: const [.0, .42, 1.0],
        ),
      ),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
