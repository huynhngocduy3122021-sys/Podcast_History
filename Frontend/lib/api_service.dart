import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bullpen-viewer-overfill.ngrok-free.dev',
);

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl = '',
    this.bio = '',
  });

  final String id;
  final String username;
  final String email;
  final String displayName;
  final String role;
  final String avatarUrl;
  final String bio;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: '${json['id'] ?? json['userId'] ?? ''}',
    username: '${json['username'] ?? ''}',
    email: '${json['email'] ?? ''}',
    displayName: '${json['displayName'] ?? ''}',
    role: '${json['role'] ?? 'LISTENER'}',
    avatarUrl: '${json['avatarUrl'] ?? ''}',
    bio: '${json['bio'] ?? ''}',
  );
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshExpiresIn,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final int refreshExpiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    accessToken: '${json['accessToken'] ?? ''}',
    refreshToken: '${json['refreshToken'] ?? ''}',
    tokenType: '${json['tokenType'] ?? 'Bearer'}',
    expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 600,
    refreshExpiresIn: (json['refreshExpiresIn'] as num?)?.toInt() ?? 604800,
  );
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/api/auth/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );
    return AuthUser.fromJson(_decode(response));
  }

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/api/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    return AuthSession.fromJson(_decode(response));
  }

  Future<AuthUser> me(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/api/auth/me'),
      headers: _authHeaders(accessToken),
    );
    return AuthUser.fromJson(_decode(response));
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/api/auth/refresh'),
          headers: _jsonHeaders,
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 20));
    return AuthSession.fromJson(_decode(response));
  }

  Future<void> logout(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/api/auth/logout'),
      headers: _jsonHeaders,
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
  }

  Map<String, String> get _jsonHeaders => const {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  Map<String, String> _authHeaders(String token) => {
    ..._jsonHeaders,
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _errorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return '${json['message'] ?? 'Yeu cau that bai (${response.statusCode}).'}';
    } catch (_) {
      return 'Yeu cau that bai (${response.statusCode}).';
    }
  }
}

class ListenerPodcast {
  const ListenerPodcast({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.creatorId,
    required this.creatorChannelName,
    required this.visibility,
  });

  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final int durationSeconds;
  final String? creatorId;
  final String creatorChannelName;
  final String visibility;

  factory ListenerPodcast.fromJson(Map<String, dynamic> json) =>
      ListenerPodcast(
        id: '${json['podcastId']}',
        title: '${json['title'] ?? ''}',
        description: '${json['description'] ?? ''}',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        creatorId: json['creatorProfileId']?.toString(),
        creatorChannelName: '${json['creatorChannelName'] ?? ''}',
        visibility: '${json['visibility'] ?? 'PUBLIC'}',
      );
}

class ListenerApi {
  ListenerApi({
    required this.accessToken,
    this.refreshToken,
    this.onSessionRefreshed,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String accessToken;
  String? refreshToken;
  final void Function(AuthSession)? onSessionRefreshed;
  Future<AuthSession>? _refreshing;
  final http.Client _client;

  Future<List<ListenerPodcast>> searchPodcasts({
    String? query,
    String? categoryId,
    String? creatorId,
    String? seriesId,
    int page = 0,
    int size = 20,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'size': '$size',
      if (query?.trim().isNotEmpty ?? false) 'q': query!.trim(),
      if (categoryId case final value?) 'categoryId': value,
      if (creatorId case final value?) 'creatorId': value,
      if (seriesId case final value?) 'seriesId': value,
    };
    final json = await _send(
      'GET',
      '/api/podcasts',
      queryParameters: queryParameters,
    );
    return _pageItems(json)
        .map(ListenerPodcast.fromJson)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> categories() async =>
      _list('GET', '/api/categories', authenticated: false);

  Future<List<Map<String, dynamic>>> creators() =>
      _list('GET', '/api/creators');

  Future<Map<String, dynamic>> creator(String creatorId) =>
      _sendMap('GET', '/api/creators/$creatorId');

  Future<ListenerPodcast> podcast(String podcastId) async =>
      ListenerPodcast.fromJson(await _send('GET', '/api/podcasts/$podcastId'));

  Future<Map<String, dynamic>> playback(String podcastId) =>
      _sendMap('GET', '/api/podcasts/$podcastId/playback');

  Future<Map<String, dynamic>> saveProgress(
    String podcastId, {
    required int progressSeconds,
    required bool completed,
  }) => _sendMap(
    'PUT',
    '/api/podcasts/$podcastId/listening-progress',
    body: {'progressSeconds': progressSeconds, 'completed': completed},
  );

  Future<List<Map<String, dynamic>>> listeningHistory({
    int page = 0,
    int size = 20,
  }) async => _pageItems(
    await _send(
      'GET',
      '/api/me/listening-history',
      queryParameters: {'page': '$page', 'size': '$size'},
    ),
  );

  Future<Map<String, dynamic>> listeningHistoryForPodcast(String podcastId) =>
      _sendMap('GET', '/api/me/listening-history/$podcastId');

  Future<void> deleteListeningHistory(String podcastId) async {
    await _send('DELETE', '/api/me/listening-history/$podcastId');
  }

  Future<Map<String, dynamic>> likes(String podcastId) =>
      _sendMap('GET', '/api/podcasts/$podcastId/likes');

  Future<Map<String, dynamic>> like(String podcastId) =>
      _sendMap('PUT', '/api/podcasts/$podcastId/like');

  Future<Map<String, dynamic>> unlike(String podcastId) =>
      _sendMap('DELETE', '/api/podcasts/$podcastId/like');

  Future<List<Map<String, dynamic>>> comments(
    String podcastId, {
    int page = 0,
    int size = 20,
  }) async => _pageItems(
    await _send(
      'GET',
      '/api/podcasts/$podcastId/comments',
      queryParameters: {'page': '$page', 'size': '$size'},
    ),
  );

  Future<Map<String, dynamic>> createComment(
    String podcastId,
    String content, {
    int? timestampSeconds,
  }) => _sendMap(
    'POST',
    '/api/podcasts/$podcastId/comments',
    body: {'content': content, 'timestampSeconds': timestampSeconds},
  );

  Future<Map<String, dynamic>> updateComment(
    String commentId,
    String content,
  ) => _sendMap('PUT', '/api/comments/$commentId', body: {'content': content});

  Future<void> deleteComment(String commentId) async {
    await _send('DELETE', '/api/comments/$commentId');
  }

  Stream<String> commentStream(String podcastId) async* {
    final request =
        http.Request(
            'GET',
            Uri.parse('$apiBaseUrl/api/podcasts/$podcastId/comments/stream'),
          )
          ..headers.addAll({
            'Accept': 'text/event-stream',
            'ngrok-skip-browser-warning': 'true',
            'Authorization': 'Bearer $accessToken',
          });
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Khong the mo comment stream.', response.statusCode);
    }
    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  Future<Map<String, dynamic>> createReport({
    required String targetType,
    required String targetId,
    required String reasonCode,
    String? description,
  }) => _sendMap(
    'POST',
    '/api/reports',
    body: {
      'targetType': targetType,
      'targetId': targetId,
      'reasonCode': reasonCode,
      if (description case final value?) 'description': value,
    },
  );

  Future<List<Map<String, dynamic>>> reports({
    int page = 0,
    int size = 20,
  }) async => _pageItems(
    await _send(
      'GET',
      '/api/me/reports',
      queryParameters: {'page': '$page', 'size': '$size'},
    ),
  );

  Future<Map<String, dynamic>> updateReport(
    String reportId, {
    required String reasonCode,
    String? description,
  }) => _sendMap(
    'PATCH',
    '/api/me/reports/$reportId',
    body: {
      'reasonCode': reasonCode,
      if (description case final value?) 'description': value,
    },
  );

  Future<void> deleteReport(String reportId) async {
    await _send('DELETE', '/api/me/reports/$reportId');
  }

  Future<List<Map<String, dynamic>>> follows({
    int page = 0,
    int size = 20,
  }) async => _pageItems(
    await _send(
      'GET',
      '/api/me/follows',
      queryParameters: {'page': '$page', 'size': '$size'},
    ),
  );

  Future<Map<String, dynamic>> follow(String creatorId) =>
      _sendMap('PUT', '/api/creators/$creatorId/follow');

  Future<void> unfollow(String creatorId) async {
    await _send('DELETE', '/api/creators/$creatorId/follow');
  }

  Future<List<Map<String, dynamic>>> savedPodcasts({
    int page = 0,
    int size = 20,
  }) async => _pageItems(
    await _send(
      'GET',
      '/api/me/saved-podcasts',
      queryParameters: {'page': '$page', 'size': '$size'},
    ),
  );

  Future<Map<String, dynamic>> savePodcast(String podcastId) =>
      _sendMap('PUT', '/api/me/saved-podcasts/$podcastId');

  Future<void> unsavePodcast(String podcastId) async {
    await _send('DELETE', '/api/me/saved-podcasts/$podcastId');
  }

  Future<List<Map<String, dynamic>>> membershipPlans(String creatorId) =>
      _list('GET', '/api/creators/$creatorId/membership-plans');

  Future<List<Map<String, dynamic>>> subscriptions() =>
      _list('GET', '/api/me/subscriptions');

  Future<Map<String, dynamic>> checkout(String membershipPlanId) => _sendMap(
    'POST',
    '/api/me/subscriptions',
    body: {'membershipPlanId': membershipPlanId},
  );

  Future<void> cancelSubscription(String subscriptionId) async {
    await _send('DELETE', '/api/me/subscriptions/$subscriptionId');
  }

  Future<List<Map<String, dynamic>>> seriesRequests() =>
      _list('GET', '/api/me/series-requests');

  Future<Map<String, dynamic>> createSeriesRequest(
    String creatorId, {
    required String requestedTitle,
    required String description,
  }) => _sendMap(
    'POST',
    '/api/creators/$creatorId/series-requests',
    body: {'requestedTitle': requestedTitle, 'description': description},
  );

  Future<Map<String, dynamic>> updateSeriesRequest(
    String requestId, {
    required String requestedTitle,
    required String description,
  }) => _sendMap(
    'PUT',
    '/api/me/series-requests/$requestId',
    body: {'requestedTitle': requestedTitle, 'description': description},
  );

  Future<void> cancelSeriesRequest(String requestId) async {
    await _send('DELETE', '/api/me/series-requests/$requestId');
  }

  Future<Map<String, dynamic>> _sendMap(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final json = await _send(
      method,
      path,
      queryParameters: queryParameters,
      body: body,
      authenticated: authenticated,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<Map<String, dynamic>>> _list(
    String method,
    String path, {
    bool authenticated = true,
  }) async {
    final json = await _send(method, path, authenticated: authenticated);
    if (json is List) {
      return json
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return _pageItems(json);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path')
        .replace(queryParameters: queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated) 'Authorization': 'Bearer $accessToken',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    Future<http.Response> send() async => (switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => _client.put(uri, headers: headers, body: encodedBody),
      'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => throw ArgumentError('Unsupported HTTP method: $method'),
    }).timeout(const Duration(seconds: 20));
    var response = await send();
    if (authenticated && response.statusCode == 401 && refreshToken != null) {
      final pending = _refreshing ??= AuthApi(client: _client)
          .refresh(refreshToken!);
      try {
        final session = await pending;
        if (identical(_refreshing, pending)) {
          accessToken = session.accessToken;
          refreshToken = session.refreshToken;
          onSessionRefreshed?.call(session);
        }
      } finally {
        if (identical(_refreshing, pending)) _refreshing = null;
      }
      headers['Authorization'] = 'Bearer $accessToken';
      response = await send();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body);
  }

  List<Map<String, dynamic>> _pageItems(dynamic json) {
    if (json is Map<String, dynamic> && json['content'] is List) {
      return (json['content'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    if (json is List) {
      return json
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return const [];
  }

  String _errorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return '${json['message'] ?? 'Yeu cau that bai (${response.statusCode}).'}';
    } catch (_) {
      return 'Yeu cau that bai (${response.statusCode}).';
    }
  }
}
