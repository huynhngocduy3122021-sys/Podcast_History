import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/mock_creator_repository.dart';

void main() {
  group('FE2 - Creator Studio Repository & State Machine Tests', () {
    late MockCreatorRepository repo;

    setUp(() {
      repo = MockCreatorRepository();
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

      expect(newPodcast.status, PodcastStatus.aiModerating);
      expect(newPodcast.aiModerationScore, isNotNull);

      final updatedList = await repo.getPodcasts();
      expect(updatedList.length, count + 1);
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

    test('4. Wallet: Balance check, Release funds, and Withdrawal validation', () async {
      final balance = await repo.getWalletBalance();
      final available = balance['available']!;
      final pending = balance['pending']!;

      expect(available, greaterThan(0));

      // Release pending funds
      if (pending > 0) {
        await repo.releaseFunds();
        final newBalance = await repo.getWalletBalance();
        expect(newBalance['available'], available + pending);
        expect(newBalance['pending'], 0);
      }

      // Withdraw money
      final bankAccounts = await repo.getBankAccounts();
      final tx = await repo.withdrawMoney(1000000, bankAccounts.first.id, '123456');
      expect(tx.status, TransactionStatus.processing);
      expect(tx.amount, -1000000);
    });

    test('5. Comments & Forms: Pin comment & Form creation', () async {
      final comments = await repo.getComments();
      final target = comments.first;
      final wasPinned = target.isPinned;

      await repo.togglePinComment(target.id);
      final updatedComments = await repo.getComments();
      expect(updatedComments.first.isPinned, !wasPinned);

      // Form builder
      await repo.createForm('Khảo sát chủ đề', 'Góp ý', []);
      final forms = await repo.getForms();
      expect(forms.any((f) => f.title == 'Khảo sát chủ đề'), isTrue);
    });
  });
}
