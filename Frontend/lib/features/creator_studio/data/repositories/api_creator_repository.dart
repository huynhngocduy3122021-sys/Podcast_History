import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:podcast_history/api_service.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/mock_creator_repository.dart';

/// Uses the real backend for creator registration while keeping the other
/// unfinished Creator Studio operations on the existing local implementation.
class ApiCreatorRepository extends MockCreatorRepository {
  ApiCreatorRepository({required this.accessToken, http.Client? client})
    : _client = client ?? http.Client();

  final String? accessToken;
  final http.Client _client;

  @override
  Future<void> submitRegistration({
    required String channelName,
    required String handle,
    required String bio,
    required String category,
    required String socialLink,
    required String sampleVoiceName,
  }) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException('Vui long dang nhap de gui ho so Creator.', 401);
    }

    final response = await _client.post(
      Uri.parse('$apiBaseUrl/api/creator-applications'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'channelName': channelName,
        'introduction': bio,
        'portfolioUrl': socialLink.isEmpty ? null : socialLink,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }

    await super.submitRegistration(
      channelName: channelName,
      handle: handle,
      bio: bio,
      category: category,
      socialLink: socialLink,
      sampleVoiceName: sampleVoiceName,
    );
  }

  String _errorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return '${json['message'] ?? 'Gui ho so that bai (${response.statusCode}).'}';
    } catch (_) {
      return 'Gui ho so that bai (${response.statusCode}).';
    }
  }
}
