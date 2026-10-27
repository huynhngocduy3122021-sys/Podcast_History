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
  });

  final String livestreamId;
  final Future<ChatCredentials> Function() loadCredentials;

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
  Widget build(BuildContext context) => Container(
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
