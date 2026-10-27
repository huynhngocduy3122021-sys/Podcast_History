import 'chat_client.dart';
import 'chat_credentials.dart';

ChatClient createChatClient() => _UnsupportedChatClient();

class _UnsupportedChatClient implements ChatClient {
  @override
  Future<void> connect(
    ChatCredentials credentials,
    void Function(String publisher, String message) onMessage,
  ) async => throw UnsupportedError('Nền tảng chưa hỗ trợ Agora Signaling.');
  @override
  Future<void> send(String message) async =>
      throw UnsupportedError('Chat không hỗ trợ.');
  @override
  Future<void> renewToken(String token) async =>
      throw UnsupportedError('Chat không hỗ trợ.');
  @override
  Future<void> dispose() async {}
}
