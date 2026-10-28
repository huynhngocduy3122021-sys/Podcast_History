import 'dart:convert';

import 'package:agora_rtm/agora_rtm.dart';

import 'chat_client.dart';
import 'chat_credentials.dart';

ChatClient createChatClient() => _NativeChatClient();

class _NativeChatClient implements ChatClient {
  RtmClient? _client;
  String? _channel;

  void _check(RtmStatus status) {
    if (status.error) {
      throw StateError(
        'Agora Signaling: ${status.reason} (${status.errorCode})',
      );
    }
  }

  @override
  Future<void> connect(
    ChatCredentials credentials,
    void Function(String publisher, String message) onMessage,
  ) async {
    final (status, client) = await RTM(credentials.appId, credentials.userId);
    _check(status);
    _client = client;
    _channel = credentials.channelName;
    client.addListener(
      message: (event) {
        if (event.channelName == _channel && event.message != null) {
          onMessage(
            event.publisher ?? '',
            utf8.decode(event.message!, allowMalformed: true),
          );
        }
      },
    );
    final (loginStatus, _) = await client.login(credentials.token);
    _check(loginStatus);
    final (subscribeStatus, _) = await client.subscribe(
      credentials.channelName,
    );
    _check(subscribeStatus);
  }

  @override
  Future<void> send(String message) async {
    final client = _client;
    final channel = _channel;
    if (client == null || channel == null) {
      throw StateError('Chat chưa kết nối.');
    }
    final (status, _) = await client.publish(
      channel,
      message,
      channelType: RtmChannelType.message,
      storeInHistory: false,
    );
    _check(status);
  }

  @override
  Future<void> renewToken(String token) async {
    final client = _client;
    if (client == null) return;
    final (status, _) = await client.renewToken(token);
    _check(status);
  }

  @override
  Future<void> dispose() async {
    final client = _client;
    final channel = _channel;
    _client = null;
    _channel = null;
    if (client == null) return;
    if (channel != null) await client.unsubscribe(channel);
    await client.logout();
    await client.release();
  }
}
