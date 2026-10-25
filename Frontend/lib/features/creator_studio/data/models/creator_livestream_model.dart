class CreatorLivestreamItem {
  final String livestreamId;
  final String creatorId;
  final String creatorChannelName;
  final String title;
  final String? description;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CreatorLivestreamItem({
    required this.livestreamId,
    required this.creatorId,
    required this.creatorChannelName,
    required this.title,
    this.description,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isLive => status.toUpperCase() == 'LIVE';
  bool get isEnded => status.toUpperCase() == 'ENDED';

  factory CreatorLivestreamItem.fromJson(Map<String, dynamic> json) {
    return CreatorLivestreamItem(
      livestreamId: json['livestreamId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      creatorChannelName: json['creatorChannelName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      scheduledAt: _parseDateTime(json['scheduledAt']),
      startedAt: _parseDateTime(json['startedAt']),
      endedAt: _parseDateTime(json['endedAt']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'livestreamId': livestreamId,
      'creatorId': creatorId,
      'creatorChannelName': creatorChannelName,
      'title': title,
      if (description != null) 'description': description,
      'status': status,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toUtc().toIso8601String(),
      if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class AgoraJoinResponse {
  final String livestreamId;
  final String appId;
  final String channelName;
  final String userAccount;
  final String role;
  final String token;
  final DateTime? expiresAt;

  const AgoraJoinResponse({
    required this.livestreamId,
    required this.appId,
    required this.channelName,
    required this.userAccount,
    required this.role,
    required this.token,
    this.expiresAt,
  });

  factory AgoraJoinResponse.fromJson(Map<String, dynamic> json) {
    return AgoraJoinResponse(
      livestreamId: json['livestreamId']?.toString() ?? '',
      appId: json['appId']?.toString() ?? '',
      channelName: json['channelName']?.toString() ?? '',
      userAccount: json['userAccount']?.toString() ?? '',
      role: json['role']?.toString() ?? 'host',
      token: json['token']?.toString() ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'livestreamId': livestreamId,
      'appId': appId,
      'channelName': channelName,
      'userAccount': userAccount,
      'role': role,
      'token': token,
      if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    };
  }
}
