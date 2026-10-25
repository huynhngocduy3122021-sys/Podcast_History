import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import 'package:podcast_history/api_service.dart';

class ListenerLivestreamScreen extends StatefulWidget {
  const ListenerLivestreamScreen({super.key, required this.api});

  final ListenerApi api;

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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.liveLivestreams();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text('Xem và nghe các buổi phát trực tiếp từ Content Creator.'),
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
            message: 'Hiện chưa có Content Creator nào đang phát trực tiếp.',
          )
        else
          ..._items.map(
            (item) => _LivestreamCard(
              item: item,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListenerLivestreamViewerPage(
                    api: widget.api,
                    livestream: item,
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
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.red, size: 9),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

class ListenerLivestreamViewerPage extends StatefulWidget {
  const ListenerLivestreamViewerPage({
    super.key,
    required this.api,
    required this.livestream,
  });

  final ListenerApi api;
  final ListenerLivestream livestream;

  @override
  State<ListenerLivestreamViewerPage> createState() =>
      _ListenerLivestreamViewerPageState();
}

class _ListenerLivestreamViewerPageState
    extends State<ListenerLivestreamViewerPage> {
  RtcEngine? _engine;
  VideoViewController? _videoController;
  int? _remoteUid;
  bool _loading = true;
  String? _error;
  ListenerAgoraJoin? _join;

  @override
  void initState() {
    super.initState();
    _joinLivestream();
  }

  Future<void> _joinLivestream() async {
    try {
      final detail = await widget.api.livestream(
        widget.livestream.livestreamId,
      );
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
                widget.livestream.livestreamId,
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
      _join = join;
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_leave());
    super.dispose();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.livestream.title)),
    body: Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Không thể tham gia livestream.\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : _remoteUid != null && _videoController != null
                ? AgoraVideoView(controller: _videoController!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loading) const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _loading
                            ? 'Đang kết nối tới livestream…'
                            : 'Creator chưa bật camera hoặc đã rời phòng.',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
        ListTile(
          title: Text(widget.livestream.title),
          subtitle: Text(widget.livestream.creatorChannelName),
          leading: const Icon(Icons.person),
          trailing: _join?.role.toLowerCase() == 'audience'
              ? const Chip(label: Text('Audience'))
              : null,
        ),
      ],
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
          if (action != null) action!,
        ],
      ),
    ),
  );
}
