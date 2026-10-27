import 'dart:js_interop';

import 'chat_client.dart';
import 'chat_credentials.dart';

@JS('agoraChatConnect')
external JSPromise<JSNumber> _connect(
  JSString appId,
  JSString userId,
  JSString token,
  JSString channelName,
  JSFunction onMessage,
);
@JS('agoraChatSend')
external JSPromise<JSAny?> _send(JSNumber id, JSString message);
@JS('agoraChatRenewToken')
external JSPromise<JSAny?> _renew(JSNumber id, JSString token);
@JS('agoraChatDisconnect')
external JSPromise<JSAny?> _disconnect(JSNumber id);

ChatClient createChatClient() => _WebChatClient();

class _WebChatClient implements ChatClient {
  int? _id;
  JSFunction? _onMessage;

  @override
  Future<void> connect(
    ChatCredentials credentials,
    void Function(String publisher, String message) onMessage,
  ) async {
    _onMessage = ((JSString publisher, JSString message) {
      onMessage(publisher.toDart, message.toDart);
    }).toJS;
    _id = (await _connect(
      credentials.appId.toJS,
      credentials.userId.toJS,
      credentials.token.toJS,
      credentials.channelName.toJS,
      _onMessage!,
    ).toDart).toDartInt;
  }

  @override
  Future<void> send(String message) async {
    final id = _id;
    if (id == null) throw StateError('Chat chưa kết nối.');
    await _send(id.toJS, message.toJS).toDart;
  }

  @override
  Future<void> renewToken(String token) async {
    final id = _id;
    if (id != null) await _renew(id.toJS, token.toJS).toDart;
  }

  @override
  Future<void> dispose() async {
    final id = _id;
    _id = null;
    _onMessage = null;
    if (id != null) await _disconnect(id.toJS).toDart;
  }
}
