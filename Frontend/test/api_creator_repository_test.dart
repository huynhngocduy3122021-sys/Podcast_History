import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/core/network/api_endpoints.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/api_creator_repository.dart';

void main() {
  group('FE2 Creator Studio API Calling Tests', () {
    late ApiClient apiClient;
    late ApiCreatorRepository repository;
    final capturedRequests = <http.Request>[];

    setUp(() {
      capturedRequests.clear();
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        final path = request.url.path;

        // 1. Profile / Creator Applications
        if (path == ApiEndpoints.myCreatorApplication) {
          return http.Response(
            jsonEncode({
              'applicationId': '11111111-1111-1111-1111-111111111111',
              'channelName': 'Sử Kể Kênh API',
              'introduction': 'Giới thiệu kênh từ Backend',
              'portfolioUrl': 'https://portfolio.test',
              'status': 'APPROVED',
              'reviewNote': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == ApiEndpoints.creatorApplications && request.method == 'POST') {
          final body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'applicationId': '22222222-2222-2222-2222-222222222222',
              'channelName': body['channelName'],
              'introduction': body['introduction'],
              'status': 'PENDING',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // 2. Categories
        if (path == ApiEndpoints.categories) {
          return http.Response(
            jsonEncode([
              {
                'categoryId': '99999999-9999-9999-9999-999999999999',
                'name': '1945–1954',
                'slug': '1945-1954',
                'isActive': true,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // 3. Creator Podcasts
        if (path == ApiEndpoints.creatorPodcasts) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'podcastId': '33333333-3333-3333-3333-333333333333',
                  'title': 'Chiến dịch Điện Biên Phủ từ API',
                  'description': 'Tập podcast live từ Backend',
                  'thumbnailUrl': 'https://example.com/cover.jpg',
                  'durationSeconds': 1800,
                  'exclusive': false,
                  'visibility': 'PUBLIC',
                  'status': 'PUBLISHED',
                  'createdAt': '2026-10-15T12:00:00Z',
                }
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (request.method == 'POST') {
            final body = jsonDecode(request.body);
            return http.Response(
              jsonEncode({
                'podcastId': '44444444-4444-4444-4444-444444444444',
                'title': body['title'],
                'description': body['description'],
                'thumbnailUrl': body['thumbnailUrl'],
                'durationSeconds': body['durationSeconds'],
                'exclusive': body['exclusive'],
                'status': 'DRAFT',
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
        }

        // Submit podcast
        if (path == ApiEndpoints.creatorPodcastSubmit('44444444-4444-4444-4444-444444444444')) {
          return http.Response(
            jsonEncode({
              'podcastId': '44444444-4444-4444-4444-444444444444',
              'title': 'Podcast Mới',
              'status': 'PENDING_REVIEW',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Update podcast
        if (request.method == 'PUT' && path.startsWith('/api/creator/podcasts/')) {
          final body = jsonDecode(request.body);
          final id = path.split('/').last;
          return http.Response(
            jsonEncode({
              'podcastId': id,
              'title': body['title'],
              'description': body['description'],
              'thumbnailUrl': body['thumbnailUrl'],
              'durationSeconds': body['durationSeconds'],
              'exclusive': body['exclusive'],
              'status': 'DRAFT',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Delete podcast
        if (path == ApiEndpoints.creatorPodcastById('33333333-3333-3333-3333-333333333333') &&
            request.method == 'DELETE') {
          return http.Response('', 204);
        }

        // 4. Incoming requests
        if (path == ApiEndpoints.incomingRequests) {
          return http.Response(
            jsonEncode([
              {
                'requestId': '55555555-5555-5555-5555-555555555555',
                'title': 'Yêu cầu làm tập về Cố Đô Huế',
                'description': 'Kịch bản chi tiết về di tích triều Nguyễn',
                'proposedBudget': 3000000,
                'status': 'PENDING',
                'createdAt': '2026-10-15T10:00:00Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Accept request
        if (path == ApiEndpoints.acceptRequest('55555555-5555-5555-5555-555555555555')) {
          return http.Response(
            jsonEncode({'status': 'ACCEPTED'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Reject request
        if (path == ApiEndpoints.rejectRequest('55555555-5555-5555-5555-555555555555')) {
          return http.Response(
            jsonEncode({'status': 'REJECTED'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Upload image
        if (path == ApiEndpoints.uploads) {
          return http.Response(
            jsonEncode({
              'url': 'https://r2.vietcast.example.com/images/cover.jpg',
              'mediaKey': 'images/cover.jpg',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // 5. Wallet - Not implemented in BE ("cái nào chưa có thì bỏ qua")
        if (path.contains('/wallet')) {
          return http.Response(
            jsonEncode({'error': 'Not Found', 'message': 'Wallet endpoint not implemented'}),
            404,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      apiClient = ApiClient(
        baseUrl: 'http://localhost:8081',
        initialToken: 'test_jwt_bearer_token',
        client: mockClient,
      );
      repository = ApiCreatorRepository(apiClient);
    });

    test('1. Đăng ký làm creator: Calls POST /api/creator-applications with Bearer header', () async {
      await repository.submitRegistration(
        channelName: 'Sử Kể Đêm Khuya',
        handle: '@sukledemkhuya',
        bio: 'Podcast lịch sử cận hiện đại',
        category: 'Kháng chiến 1945–1975',
        socialLink: 'https://youtube.com/@su',
        sampleVoiceName: 'sample.mp3',
      );

      final req = capturedRequests.firstWhere((r) => r.url.path == ApiEndpoints.creatorApplications);
      expect(req.method, 'POST');
      expect(req.headers['authorization'], 'Bearer test_jwt_bearer_token');
      final body = jsonDecode(req.body);
      expect(body['channelName'], 'Sử Kể Đêm Khuya');
    });

    test('2. Dashboard & Profile: Calls GET /api/creator-applications/me and GET /api/creator/podcasts', () async {
      final profile = await repository.getProfile();
      expect(profile.name, 'Sử Kể Kênh API');
      expect(profile.status, CreatorStatus.approved);

      final podcasts = await repository.getPodcasts();
      expect(podcasts.length, 1);
      expect(podcasts.first.title, 'Chiến dịch Điện Biên Phủ từ API');
      expect(podcasts.first.status, PodcastStatus.published);
    });

    test('3. Tạo, đăng & xóa podcast: Calls POST and DELETE endpoints', () async {
      final newPod = await repository.createPodcast(
        title: 'Podcast Mới',
        description: 'Mô tả chi tiết',
        eraTag: '1945–1954',
        sources: 'Sách giáo khoa lịch sử',
        isExclusive: false,
        coverUrl: 'https://example.com/cover.jpg',
        audioFileName: 'audio.mp3',
        duration: const Duration(minutes: 25),
      );

      expect(newPod.title, 'Podcast Mới');

      // Verify category query was made
      expect(capturedRequests.any((r) => r.url.path == ApiEndpoints.categories), isTrue);

      // Verify create podcast was made
      final createReq = capturedRequests.firstWhere(
        (r) => r.url.path == ApiEndpoints.creatorPodcasts && r.method == 'POST',
      );
      final body = jsonDecode(createReq.body);
      expect(body['title'], 'Podcast Mới');
      expect(body['durationSeconds'], 1500);

      // Verify delete podcast
      await repository.deletePodcast('33333333-3333-3333-3333-333333333333');
      expect(
        capturedRequests.any((r) =>
            r.url.path == ApiEndpoints.creatorPodcastById('33333333-3333-3333-3333-333333333333') &&
            r.method == 'DELETE'),
        isTrue,
      );
    });

    test('3b. Cập nhật podcast và audio: Calls PUT /api/creator/podcasts/{id}', () async {
      final updated = await repository.updatePodcast(
        id: '33333333-3333-3333-3333-333333333333',
        title: 'Podcast Đã Sửa Âm Thanh',
        description: 'Mô tả mới',
        eraTag: '1945–1954',
        sources: 'Tài liệu lưu trữ quốc gia',
        isExclusive: true,
        coverUrl: 'https://example.com/cover_new.jpg',
        audioFileName: 'new_audio_recording.mp3',
        duration: const Duration(minutes: 30),
      );

      expect(updated.title, 'Podcast Đã Sửa Âm Thanh');
      expect(updated.audioFileName, 'new_audio_recording.mp3');

      final putReq = capturedRequests.firstWhere(
        (r) =>
            r.url.path == ApiEndpoints.creatorPodcastById('33333333-3333-3333-3333-333333333333') &&
            r.method == 'PUT',
      );
      final body = jsonDecode(putReq.body);
      expect(body['title'], 'Podcast Đã Sửa Âm Thanh');
      expect(body['durationSeconds'], 1800);
      expect(body['visibility'], 'MEMBERS_ONLY');
      expect(body['exclusive'], true);
    });

    test('4. Podcast requests: Incoming list, accept and reject API calls', () async {
      final requests = await repository.getRequests();
      expect(requests.length, 1);
      expect(requests.first.topic, 'Yêu cầu làm tập về Cố Đô Huế');

      await repository.acceptRequest('55555555-5555-5555-5555-555555555555');
      expect(
        capturedRequests.any((r) =>
            r.url.path == ApiEndpoints.acceptRequest('55555555-5555-5555-5555-555555555555') &&
            r.method == 'POST'),
        isTrue,
      );

      await repository.rejectRequest('55555555-5555-5555-5555-555555555555', 'Lịch sản xuất bận');
      expect(
        capturedRequests.any((r) =>
            r.url.path == ApiEndpoints.rejectRequest('55555555-5555-5555-5555-555555555555') &&
            r.method == 'POST'),
        isTrue,
      );
    });

    test('5. Upload ảnh R2: Calls multipart POST /api/uploads', () async {
      final url = await repository.uploadImageFile(
        fileBytes: [1, 2, 3, 4],
        filename: 'cover.jpg',
      );
      expect(url, 'https://r2.vietcast.example.com/images/cover.jpg');
    });

    test('6. Cái nào chưa có thì bỏ qua: Wallet 404 does not crash and fallbacks gracefully', () async {
      // Wallet endpoint returns 404
      final balance = await repository.getWalletBalance();
      expect(balance['available'], 0);
      expect(balance['pending'], 0);

      final txs = await repository.getTransactions();
      expect(txs, isEmpty);

      // Funds release should complete without error
      await repository.releaseFunds();
    });
  });
}
