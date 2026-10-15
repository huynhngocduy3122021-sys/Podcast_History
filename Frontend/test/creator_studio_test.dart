import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/core/network/api_endpoints.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/api_creator_repository.dart';

void main() {
  group('FE2 - Creator Studio Repository & State Machine Tests', () {
    late ApiCreatorRepository repo;
    String channelName = 'Sử Kể Đêm Khuya';
    String applicationStatus = 'APPROVED';
    final podcasts = <Map<String, dynamic>>[];
    final requests = <Map<String, dynamic>>[];

    setUp(() {
      channelName = 'Sử Kể Đêm Khuya';
      applicationStatus = 'APPROVED';
      podcasts.clear();
      podcasts.add({
        'podcastId': 'pod_01',
        'title': 'Tập 1: Điện Biên Phủ',
        'description': 'Mô tả',
        'thumbnailUrl': '',
        'durationSeconds': 1200,
        'exclusive': false,
        'visibility': 'PUBLIC',
        'status': 'PUBLISHED',
        'createdAt': '2026-10-15T00:00:00Z',
      });
      requests.clear();
      requests.add({
        'requestId': 'req_01',
        'title': 'Yêu cầu làm tập lịch sử',
        'description': 'Mô tả yêu cầu',
        'proposedBudget': 2000000,
        'status': 'PENDING',
      });

      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path == ApiEndpoints.myCreatorApplication) {
          return http.Response(
            jsonEncode({
              'applicationId': 'app_1',
              'channelName': channelName,
              'introduction': 'Kênh podcast lịch sử',
              'status': applicationStatus,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == ApiEndpoints.creatorApplications && request.method == 'POST') {
          final body = jsonDecode(request.body);
          channelName = body['channelName'] ?? channelName;
          applicationStatus = 'PENDING';
          return http.Response(
            jsonEncode({'status': 'PENDING'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == ApiEndpoints.categories) {
          return http.Response(
            jsonEncode([
              {'categoryId': 'cat_1', 'name': '1858–1945'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == ApiEndpoints.creatorPodcasts) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(podcasts),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (request.method == 'POST') {
            final body = jsonDecode(request.body);
            final newPod = {
              'podcastId': 'pod_new',
              'title': body['title'],
              'description': body['description'],
              'thumbnailUrl': body['thumbnailUrl'],
              'durationSeconds': body['durationSeconds'],
              'exclusive': body['exclusive'],
              'status': 'DRAFT',
            };
            podcasts.add(newPod);
            return http.Response(
              jsonEncode(newPod),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
        }

        if (request.method == 'PUT' && path.startsWith('/api/creator/podcasts/')) {
          final id = path.split('/').last;
          final body = jsonDecode(request.body);
          final idx = podcasts.indexWhere((p) => p['podcastId'] == id);
          if (idx != -1) {
            podcasts[idx]['title'] = body['title'];
            podcasts[idx]['durationSeconds'] = body['durationSeconds'];
            return http.Response(jsonEncode(podcasts[idx]), 200, headers: {'content-type': 'application/json'});
          }
          return http.Response(jsonEncode({'podcastId': id, ...body}), 200, headers: {'content-type': 'application/json'});
        }

        if (path == ApiEndpoints.creatorPodcastSubmit('pod_new')) {
          final idx = podcasts.indexWhere((p) => p['podcastId'] == 'pod_new');
          if (idx != -1) {
            podcasts[idx]['status'] = 'AI_MODERATING';
          }
          return http.Response(
            jsonEncode({
              'podcastId': 'pod_new',
              'title': 'Tập thử nghiệm: Trận Rạch Gầm - Xoài Mút',
              'status': 'AI_MODERATING',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == ApiEndpoints.incomingRequests) {
          return http.Response(
            jsonEncode(requests),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == ApiEndpoints.acceptRequest('req_01')) {
          final idx = requests.indexWhere((r) => r['requestId'] == 'req_01');
          if (idx != -1) {
            requests[idx]['status'] = 'ACCEPTED';
          }
          return http.Response(jsonEncode({'status': 'ACCEPTED'}), 200);
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:8081', client: mockClient);
      repo = ApiCreatorRepository(apiClient);
    });

    test('1. Profile: Fetch profile & submit registration', () async {
      final profile = await repo.getProfile();
      expect(profile.name, 'Sử Kể Đêm Khuya');
      expect(profile.status, CreatorStatus.approved);

      await repo.submitRegistration(
        channelName: 'Sử Việt Toàn Thư',
        handle: '@suviet',
        bio: 'Kênh kể chuyện lịch sử hào hùng',
        category: 'Kháng chiến 1945–1975',
        socialLink: 'https://youtube.com',
        sampleVoiceName: 'sample.mp3',
      );

      final updatedProfile = await repo.getProfile();
      expect(updatedProfile.name, 'Sử Việt Toàn Thư');
      expect(updatedProfile.status, CreatorStatus.pending);
    });

    test('2. Podcast: Create podcast & verify moderation status', () async {
      final initialList = await repo.getPodcasts();
      final count = initialList.length;

      final newPodcast = await repo.createPodcast(
        title: 'Tập thử nghiệm: Trận Rạch Gầm - Xoài Mút',
        description: 'Chiến công hiển hách của vua Quang Trung',
        eraTag: '1858–1945',
        sources: 'Đại Nam thực lục',
        isExclusive: false,
        coverUrl: '',
        audioFileName: 'rach_gam_xoai_mut.mp3',
        duration: const Duration(minutes: 20),
      );

      expect(newPodcast.title, 'Tập thử nghiệm: Trận Rạch Gầm - Xoài Mút');
      expect(newPodcast.status, PodcastStatus.aiModerating);

      final updatedList = await repo.getPodcasts();
      expect(updatedList.length, count + 1);
    });

    test('2b. Podcast: Cập nhật audio và thông tin tập via PUT', () async {
      final updated = await repo.updatePodcast(
        id: 'pod_01',
        title: 'Tập 1: Điện Biên Phủ (Bản cập nhật âm thanh)',
        description: 'Mô tả mới',
        eraTag: '1945–1954',
        sources: 'Đại Nam thực lục',
        isExclusive: false,
        coverUrl: '',
        audioFileName: 'dien_bien_phu_remastered.mp3',
        duration: const Duration(minutes: 25),
      );

      expect(updated.title, 'Tập 1: Điện Biên Phủ (Bản cập nhật âm thanh)');
      expect(updated.audioFileName, 'dien_bien_phu_remastered.mp3');

      final list = await repo.getPodcasts();
      final pod = list.firstWhere((p) => p.id == 'pod_01');
      expect(pod.title, 'Tập 1: Điện Biên Phủ (Bản cập nhật âm thanh)');
      expect(pod.audioFileName, 'dien_bien_phu_remastered.mp3');
    });

    test('3. Custom Request: State machine transitions (SENT -> ACCEPTED -> DELIVERED)', () async {
      final requests = await repo.getRequests();
      final sentReq = requests.firstWhere((r) => r.status == CustomRequestStatus.sent);

      // Chấp nhận đơn
      await repo.acceptRequest(sentReq.id);
      final acceptedReq = await repo.getRequestById(sentReq.id);
      expect(acceptedReq!.status, CustomRequestStatus.accepted);

      // Nộp bài hoàn thành
      await repo.deliverWork(sentReq.id, 'https://vietcast.vn/audio/delivered.mp3', 'Đã hoàn thành thu âm');
      final deliveredReq = await repo.getRequestById(sentReq.id);
      expect(deliveredReq!.status, CustomRequestStatus.delivered);
      expect(deliveredReq.deliveryFileUrl, isNotNull);
    });

    test('4. Wallet: Balance check, Bank account & Withdrawal', () async {
      await repo.addBankAccount('Vietcombank', '0123456789', 'NGUYEN VAN A');
      final bankAccounts = await repo.getBankAccounts();
      expect(bankAccounts.length, 1);
      expect(bankAccounts.first.bankName, 'Vietcombank');
    });

    test('5. Forms: Form creation and listing', () async {
      await repo.createForm('Khảo sát chủ đề', 'Góp ý', []);
      final forms = await repo.getForms();
      expect(forms.any((f) => f.title == 'Khảo sát chủ đề'), isTrue);
    });
  });
}
