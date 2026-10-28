import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_client.dart';
import 'chat_credentials.dart';

class LivestreamChatPanel extends StatefulWidget {
  const LivestreamChatPanel({
    super.key,
    required this.livestreamId,
    required this.loadCredentials,
    this.isOverlay = false,
    this.trailingActions,
  });

  final String livestreamId;
  final Future<ChatCredentials> Function() loadCredentials;
  final bool isOverlay;
  final Widget? trailingActions;

  @override
  State<LivestreamChatPanel> createState() => _LivestreamChatPanelState();
}

class _ChatMessage {
  const _ChatMessage(this.sender, this.text, this.mine);
  final String sender;
  final String text;
  final bool mine;

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
        'mine': mine,
      };

  static _ChatMessage? fromJson(dynamic value) {
    if (value is! Map) return null;
    final sender = '${value['sender'] ?? ''}'.trim();
    final text = '${value['text'] ?? ''}'.trim();
    if (sender.isEmpty || text.isEmpty || text.length > 300) return null;
    return _ChatMessage(sender, text, value['mine'] == true);
  }
}

class _LivestreamChatPanelState extends State<LivestreamChatPanel> {
  final _input = TextEditingController();
  final _messages = <_ChatMessage>[];
  ChatClient? _client;
  ChatCredentials? _credentials;
  Timer? _renewTimer;
  bool _connecting = true;
  bool _sending = false;
  String? _error;

  String get _historyKey => 'livestream_chat_history_${widget.livestreamId}';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadHistory();
    if (mounted) await _connect();
  }

  Future<void> _loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_historyKey) ?? const [];
    if (!mounted) return;
    final history = raw
        .map((entry) {
          try {
            return _ChatMessage.fromJson(jsonDecode(entry));
          } catch (_) {
            return null;
          }
        })
        .whereType<_ChatMessage>()
        .toList();
    final start = history.length > 100 ? history.length - 100 : 0;
    setState(() {
      _messages
        ..clear()
        ..addAll(history.sublist(start));
    });
  }

  Future<void> _saveHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _historyKey,
      _messages.map((message) => jsonEncode(message.toJson())).toList(),
    );
  }

  Future<void> _connect() async {
    ChatClient? client;
    try {
      final credentials = await widget.loadCredentials();
      client = createChatClient();
      await client.connect(credentials, (publisher, payload) {
        if (!mounted || publisher == credentials.userId) return;
        try {
          final json = jsonDecode(payload);
          if (json is! Map<String, dynamic>) return;
          final text = '${json['text'] ?? ''}'.trim();
          if (text.isEmpty || text.length > 300) return;
          final sender = '${json['name'] ?? 'Người xem'}'.trim();
          setState(() => _addMessage(_ChatMessage(sender, text, false)));
        } catch (_) {
          // Ignore messages sent to this Agora channel in another format.
        }
      });
      if (!mounted) {
        await client.dispose();
        return;
      }
      _client = client;
      _credentials = credentials;
      _renewTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _renewIfNeeded(),
      );
      setState(() {
        _connecting = false;
        _error = null;
      });
    } catch (error) {
      if (client != null) {
        await client.dispose();
      }
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Không kết nối được chat Agora: $error';
        });
      }
    }
  }

  Future<void> _renewIfNeeded() async {
    final credentials = _credentials;
    final client = _client;
    if (credentials == null ||
        client == null ||
        DateTime.now().isBefore(
          credentials.expiresAt.subtract(const Duration(minutes: 2)),
        )) {
      return;
    }
    try {
      final refreshed = await widget.loadCredentials();
      await client.renewToken(refreshed.token);
      _credentials = refreshed;
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Không gia hạn được chat: $error');
      }
    }
  }

  void _addMessage(_ChatMessage message) {
    _messages.add(message);
    if (_messages.length > 100) _messages.removeAt(0);
    unawaited(_saveHistory());
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final credentials = _credentials;
    final client = _client;
    if (text.isEmpty ||
        text.length > 300 ||
        credentials == null ||
        client == null ||
        _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await client.send(
        jsonEncode({'name': credentials.displayName, 'text': text}),
      );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _addMessage(_ChatMessage(credentials.displayName, text, true));
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Gửi tin nhắn thất bại: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _renewTimer?.cancel();
    _input.dispose();
    final client = _client;
    if (client != null) {
      unawaited(client.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOverlay) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _connecting
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.only(bottom: 6),
                        itemCount: _messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x66FFB800),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0x99FFB800),
                                    width: 0.5,
                                  ),
                                ),
                                child: const Text(
                                  '👋 Chào mừng đến với phòng live! Hãy bình luận văn minh và lịch sự.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }
                          final message =
                              _messages[_messages.length - 1 - index];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2.5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white12,
                                  width: 0.5,
                                ),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${message.sender}: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: message.mine
                                            ? const Color(0xFFFFD54F)
                                            : const Color(0xFF81D4FA),
                                      ),
                                    ),
                                    TextSpan(
                                      text: message.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            inputDecorationTheme: const InputDecorationTheme(
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                            ),
                          ),
                          child: TextField(
                            controller: _input,
                            enabled: _client != null,
                            maxLength: 300,
                            cursorColor: const Color(0xFFFFD54F),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Thêm bình luận...',
                              hintStyle: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                              counterText: '',
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _client == null || _sending ? null : _send,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFD54F),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.trailingActions != null) ...[
                const SizedBox(width: 8),
                widget.trailingActions!,
              ],
            ],
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE8191919),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chat trực tiếp',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
            ),
          Expanded(
            child: _connecting
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${message.sender}: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: message.mine
                                      ? Colors.amberAccent
                                      : Colors.lightBlueAccent,
                                ),
                              ),
                              TextSpan(
                                text: message.text,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: _client != null,
                  maxLength: 300,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Nhập tin nhắn',
                    hintStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF303030),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              IconButton(
                onPressed: _client == null || _sending ? null : _send,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
