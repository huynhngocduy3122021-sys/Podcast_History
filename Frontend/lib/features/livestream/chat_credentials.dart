class ChatCredentials {
  const ChatCredentials({
    required this.appId,
    required this.channelName,
    required this.userId,
    required this.displayName,
    required this.token,
    required this.expiresAt,
  });

  final String appId;
  final String channelName;
  final String userId;
  final String displayName;
  final String token;
  final DateTime expiresAt;

  factory ChatCredentials.fromJson(Map<String, dynamic> json) =>
      ChatCredentials(
        appId: '${json['appId'] ?? ''}',
        channelName: '${json['channelName'] ?? ''}',
        userId: '${json['userId'] ?? ''}',
        displayName: '${json['displayName'] ?? ''}',
        token: '${json['token'] ?? ''}',
        expiresAt: DateTime.parse('${json['expiresAt']}'),
      );
}
