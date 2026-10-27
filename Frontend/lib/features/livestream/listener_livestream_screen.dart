import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:podcast_history/api_service.dart';
import 'package:podcast_history/features/livestream/livestream_chat_panel.dart';

class ListenerLivestreamScreen extends StatefulWidget {
  const ListenerLivestreamScreen({super.key, required this.api});
  final ListenerApi api;
  @override
  State<ListenerLivestreamScreen> createState() => _ListenerLivestreamScreenState();
}

class _ListenerLivestreamScreenState extends State<ListenerLivestreamScreen> {
  List<ListenerLivestream> _items = const [];
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final items = await widget.api.liveLivestreams(); if (mounted) setState(() => _items = items); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 32), children: [
      Row(children: [Expanded(child: Text('Đang phát trực tiếp', style: Theme.of(context).textTheme.headlineSmall)), IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
      const Text('Vuốt lên hoặc xuống để chuyển nhanh giữa các buổi livestream.'),
      const SizedBox(height: 18),
      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
      else if (_error != null) _StateCard(icon: Icons.cloud_off, message: 'Không thể tải danh sách livestream.\n$_error', action: TextButton(onPressed: _load, child: const Text('Thử lại')))
      else if (_items.isEmpty) const _StateCard(icon: Icons.live_tv_outlined, message: 'Hiện chưa có livestream nào đang phát.')
      else ..._items.map((item) => _LivestreamCard(item: item, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListenerLivestreamFeedPage(api: widget.api, livestreams: _items, initialIndex: _items.indexOf(item))))))
    ]),
  );
}

class _LivestreamCard extends StatelessWidget {
  const _LivestreamCard({required this.item, required this.onTap});
  final ListenerLivestream item; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.live_tv, color: Colors.red)), const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.circle, color: Colors.red, size: 9), SizedBox(width: 6), Text('LIVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))]), const SizedBox(height: 5), Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(item.creatorChannelName)])), const Icon(Icons.chevron_right),
  ]))));
}

class ListenerLivestreamFeedPage extends StatefulWidget {
  const ListenerLivestreamFeedPage({super.key, required this.api, required this.livestreams, required this.initialIndex});
  final ListenerApi api; final List<ListenerLivestream> livestreams; final int initialIndex;
  @override State<ListenerLivestreamFeedPage> createState() => _ListenerLivestreamFeedPageState();
}

class _ListenerLivestreamFeedPageState extends State<ListenerLivestreamFeedPage> {
  late final PageController _pageController; late int _index;
  RtcEngine? _engine; VideoViewController? _videoController; int? _remoteUid;
  bool _loading = true; String? _error;

  @override
  void initState() { super.initState(); _index = widget.initialIndex.clamp(0, widget.livestreams.length - 1); _pageController = PageController(initialPage: _index); _joinLivestream(); }

  Future<void> _joinLivestream() async {
    final item = widget.livestreams[_index];
    try {
      final detail = await widget.api.livestream(item.livestreamId); final join = await widget.api.joinLivestream(detail.livestreamId); final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: join.appId, channelProfile: ChannelProfileType.channelProfileLiveBroadcasting));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (_, _) { if (mounted) setState(() => _loading = false); },
        onUserJoined: (_, uid, _) { if (!mounted) return; setState(() { _remoteUid = uid; _videoController = VideoViewController.remote(rtcEngine: engine, canvas: VideoCanvas(uid: uid), connection: RtcConnection(channelId: join.channelName)); }); },
        onUserOffline: (_, uid, _) { if (mounted && _remoteUid == uid) setState(() => _remoteUid = null); },
        onTokenPrivilegeWillExpire: (_, _) async { try { final refreshed = await widget.api.joinLivestream(item.livestreamId); await engine.renewToken(refreshed.token); } catch (_) {} },
        onError: (_, message) { if (mounted && _remoteUid == null) setState(() => _error = message); },
      ));
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience); await engine.enableVideo();
      await engine.joinChannelWithUserAccount(token: join.token, channelId: join.channelName, userAccount: join.userAccount, options: const ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleAudience, channelProfile: ChannelProfileType.channelProfileLiveBroadcasting, publishCameraTrack: false, publishMicrophoneTrack: false, autoSubscribeAudio: true, autoSubscribeVideo: true));
      _engine = engine;
    } catch (e) { if (mounted) setState(() { _loading = false; _error = e.toString(); }); }
  }

  Future<void> _leave() async { final controller = _videoController; _videoController = null; if (controller != null) await controller.dispose(); final engine = _engine; _engine = null; if (engine != null) { await engine.leaveChannel(); await engine.release(); } }
  Future<void> _changeLivestream(int index) async { if (index == _index) return; await _leave(); if (!mounted) return; setState(() { _index = index; _loading = true; _error = null; _remoteUid = null; }); await _joinLivestream(); }
  @override void dispose() { _pageController.dispose(); unawaited(_leave()); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, body: PageView.builder(controller: _pageController, scrollDirection: Axis.vertical, itemCount: widget.livestreams.length, onPageChanged: _changeLivestream, itemBuilder: (_, i) => _buildLivePage(widget.livestreams[i])));

  Widget _buildLivePage(ListenerLivestream item) {
    final current = item.livestreamId == widget.livestreams[_index].livestreamId;
    return Stack(fit: StackFit.expand, children: [
      if (current && _remoteUid != null && _videoController != null) AgoraVideoView(controller: _videoController!) else const ColoredBox(color: Colors.black),
      if (current && _error != null) Center(child: Text('Không thể tham gia livestream.\n$_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))
      else if (current && _remoteUid == null) Center(child: Column(mainAxisSize: MainAxisSize.min, children: [if (_loading) const CircularProgressIndicator(), const SizedBox(height: 12), Text(_loading ? 'Đang kết nối tới livestream…' : 'Đang chờ Creator vào phòng phát.', style: const TextStyle(color: Colors.white))])),
      const _LiveGradient(),
      SafeArea(child: Column(children: [
        Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)), Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const SizedBox(width: 48)]),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(18, 0, 10, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('@${item.creatorChannelName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 8), Text(item.description ?? 'Đang giao lưu trực tiếp cùng thính giả.', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, height: 1.35))]))), Padding(padding: const EdgeInsets.only(right: 12, bottom: 18), child: Column(children: [_LiveAction(icon: Icons.chat_bubble, label: 'Chat', onTap: () => _showComments(item)), const SizedBox(height: 16), _LiveAction(icon: Icons.card_giftcard, label: 'Donate', onTap: _showDonateSheet, accent: true)]))]),
      ])),
    ]);
  }

  void _showComments(ListenerLivestream item) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xff191919),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .58,
          child: LivestreamChatPanel(
            key: ValueKey('listener-chat-${item.livestreamId}'),
            loadCredentials: () =>
                widget.api.livestreamChatToken(item.livestreamId),
          ),
        ),
      ),
    ),
  );
  void _showDonateSheet() => showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xff211b19), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Ủng hộ Creator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('Chọn một mức quà để gửi lời cảm ơn.', style: TextStyle(color: Colors.white70)), const SizedBox(height: 18), Wrap(spacing: 10, children: [10000, 20000, 50000, 100000].map((amount) => OutlinedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Đã chọn ủng hộ ${amount ~/ 1000}K (chờ tích hợp thanh toán).'))); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)), child: Text('${amount ~/ 1000}K'))).toList())]))));
}

class _LiveAction extends StatelessWidget { const _LiveAction({required this.icon, required this.label, required this.onTap, this.accent = false}); final IconData icon; final String label; final VoidCallback onTap; final bool accent; @override Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Column(children: [CircleAvatar(radius: 24, backgroundColor: accent ? Colors.redAccent : Colors.black54, child: Icon(icon, color: Colors.white)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))])); }
class _LiveGradient extends StatelessWidget { const _LiveGradient(); @override Widget build(BuildContext context) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.black87], stops: const [.0, .42, 1.0])))); }
class _StateCard extends StatelessWidget { const _StateCard({required this.icon, required this.message, this.action}); final IconData icon; final String message; final Widget? action; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icon(icon, size: 42), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), ?action]))); }
