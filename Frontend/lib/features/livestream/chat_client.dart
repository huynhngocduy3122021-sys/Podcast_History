import 'chat_credentials.dart';
import 'chat_client_stub.dart'
    if (dart.library.io) 'chat_client_native.dart'
    if (dart.library.js_interop) 'chat_client_web.dart'
    as platform;

abstract class ChatClient {
  Future<void> connect(
    ChatCredentials credentials,
    void Function(String publisher, String message) onMessage,
  );
  Future<void> send(String message);
  Future<void> renewToken(String token);
  Future<void> dispose();
}

ChatClient createChatClient() => platform.createChatClient();
