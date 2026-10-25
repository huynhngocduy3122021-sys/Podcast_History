import 'package:podcast_history/core/widgets/status_chip.dart';

// --- ENUMS & STATUSES ---

enum CreatorStatus { notRegistered, pending, approved, rejected }

enum PodcastStatus { draft, aiModerating, pendingAdmin, published, rejected }

enum CustomRequestStatus {
  sent,
  accepted,
  rejected,
  inProduction,
  delivered,
  approved,
  revisionRequested,
  completed,
  disputed,
}

enum TransactionType { requestEarning, membership, withdrawal, refund }

enum TransactionStatus { success, processing, holding, failed }

// --- CREATOR PROFILE ---

class CreatorProfile {
  final String id;
  final String name;
  final String handle;
  final String bio;
  final String avatarUrl;
  final String bannerUrl;
  final bool isVerified;
  final bool isPremium;
  final int maxFreePodcasts;
  final int currentPodcastCount;
  final int followersCount;
  final CreatorStatus status;
  final String? rejectReason;

  static const empty = CreatorProfile(
    id: '',
    name: '',
    handle: '',
    bio: '',
    avatarUrl: '',
    bannerUrl: '',
    isVerified: false,
    isPremium: false,
    maxFreePodcasts: 5,
    currentPodcastCount: 0,
    followersCount: 0,
    status: CreatorStatus.notRegistered,
  );

  const CreatorProfile({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.isVerified,
    required this.isPremium,
    this.maxFreePodcasts = 5,
    required this.currentPodcastCount,
    required this.followersCount,
    required this.status,
    this.rejectReason,
  });

  CreatorProfile copyWith({
    String? id,
    String? name,
    String? handle,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    bool? isVerified,
    bool? isPremium,
    int? maxFreePodcasts,
    int? currentPodcastCount,
    int? followersCount,
    CreatorStatus? status,
    String? rejectReason,
  }) {
    return CreatorProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      maxFreePodcasts: maxFreePodcasts ?? this.maxFreePodcasts,
      currentPodcastCount: currentPodcastCount ?? this.currentPodcastCount,
      followersCount: followersCount ?? this.followersCount,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }
}

// --- CREATOR PODCAST ---

class CreatorPodcast {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final String? audioFileName;
  final Duration duration;
  final DateTime createdAt;
  final String eraTag;
  final String sources;
  final bool isExclusive;
  final int listensCount;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final PodcastStatus status;
  final String? rejectReason;
  final double? aiModerationScore; // 0.0 -> 1.0
  final String? categoryId;
  final String? seriesId;
  final String? seriesTitle;
  final String? mediaType;
  final String? videoUrl;

  const CreatorPodcast({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    this.audioFileName,
    required this.duration,
    required this.createdAt,
    required this.eraTag,
    required this.sources,
    required this.isExclusive,
    required this.listensCount,
    required this.likesCount,
    required this.commentsCount,
    this.likedByMe = false,
    required this.status,
    this.rejectReason,
    this.aiModerationScore,
    this.categoryId,
    this.seriesId,
    this.seriesTitle,
    this.mediaType,
    this.videoUrl,
  });

  CreatorPodcast copyWith({
    String? id,
    String? title,
    String? description,
    String? coverUrl,
    String? audioFileName,
    Duration? duration,
    DateTime? createdAt,
    String? eraTag,
    String? sources,
    bool? isExclusive,
    int? listensCount,
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
    PodcastStatus? status,
    String? rejectReason,
    double? aiModerationScore,
    String? categoryId,
    String? seriesId,
    String? seriesTitle,
    String? mediaType,
    String? videoUrl,
  }) {
    return CreatorPodcast(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      audioFileName: audioFileName ?? this.audioFileName,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      eraTag: eraTag ?? this.eraTag,
      sources: sources ?? this.sources,
      isExclusive: isExclusive ?? this.isExclusive,
      listensCount: listensCount ?? this.listensCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      aiModerationScore: aiModerationScore ?? this.aiModerationScore,
      categoryId: categoryId ?? this.categoryId,
      seriesId: seriesId ?? this.seriesId,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      mediaType: mediaType ?? this.mediaType,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  StatusType get statusType {
    switch (status) {
      case PodcastStatus.published:
        return StatusType.success;
      case PodcastStatus.aiModerating:
        return StatusType.info;
      case PodcastStatus.pendingAdmin:
        return StatusType.warning;
      case PodcastStatus.rejected:
        return StatusType.error;
      case PodcastStatus.draft:
        return StatusType.neutral;
    }
  }

  String get statusDisplay {
    switch (status) {
      case PodcastStatus.published:
        return 'Đã đăng';
      case PodcastStatus.aiModerating:
        return 'AI đang kiểm duyệt';
      case PodcastStatus.pendingAdmin:
        return 'Chờ Admin duyệt';
      case PodcastStatus.rejected:
        return 'Bị từ chối';
      case PodcastStatus.draft:
        return 'Bản nháp';
    }
  }

  bool get isVideo {
    final name = audioFileName?.toLowerCase() ?? '';
    if (name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.m4a') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg') ||
        name.endsWith('.flac')) {
      return false;
    }
    if (mediaType != null) {
      final mt = mediaType!.toLowerCase();
      if (mt.contains('audio')) return false;
      return mt.contains('video');
    }
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm') ||
        name.endsWith('.avi') ||
        name.contains('video');
  }
}

// --- CUSTOM PODCAST REQUEST (ESCROW & STATE MACHINE) ---

class RequestMilestone {
  final String id;
  final String title;
  final int percentage;
  final int amount;
  final bool isCompleted;
  final bool isApproved;

  const RequestMilestone({
    required this.id,
    required this.title,
    required this.percentage,
    required this.amount,
    required this.isCompleted,
    required this.isApproved,
  });

  RequestMilestone copyWith({bool? isCompleted, bool? isApproved}) {
    return RequestMilestone(
      id: id,
      title: title,
      percentage: percentage,
      amount: amount,
      isCompleted: isCompleted ?? this.isCompleted,
      isApproved: isApproved ?? this.isApproved,
    );
  }
}

class RequestChatMessage {
  final String id;
  final String senderName;
  final bool isCreator;
  final String message;
  final DateTime timestamp;
  final String? attachmentName;

  const RequestChatMessage({
    required this.id,
    required this.senderName,
    required this.isCreator,
    required this.message,
    required this.timestamp,
    this.attachmentName,
  });
}

class PodcastRequest {
  final String id;
  final String listenerName;
  final String listenerAvatar;
  final String topic;
  final String description;
  final int targetDurationMinutes;
  final DateTime deadline;
  final int totalBudget; // VND
  final List<RequestMilestone> milestones;
  final CustomRequestStatus status;
  final String? rejectionReason;
  final String? revisionNote;
  final String? deliveryFileUrl;
  final String? deliveryNote;
  final DateTime createdAt;
  final List<RequestChatMessage> messages;

  const PodcastRequest({
    required this.id,
    required this.listenerName,
    required this.listenerAvatar,
    required this.topic,
    required this.description,
    required this.targetDurationMinutes,
    required this.deadline,
    required this.totalBudget,
    required this.milestones,
    required this.status,
    this.rejectionReason,
    this.revisionNote,
    this.deliveryFileUrl,
    this.deliveryNote,
    required this.createdAt,
    this.messages = const [],
  });

  StatusType get statusType {
    switch (status) {
      case CustomRequestStatus.completed:
      case CustomRequestStatus.approved:
        return StatusType.success;
      case CustomRequestStatus.sent:
      case CustomRequestStatus.inProduction:
      case CustomRequestStatus.delivered:
        return StatusType.warning;
      case CustomRequestStatus.rejected:
      case CustomRequestStatus.revisionRequested:
        return StatusType.error;
      case CustomRequestStatus.disputed:
        return StatusType.error;
      default:
        return StatusType.info;
    }
  }

  String get statusDisplay {
    switch (status) {
      case CustomRequestStatus.sent:
        return 'Yêu cầu mới';
      case CustomRequestStatus.accepted:
        return 'Đã nhận đơn';
      case CustomRequestStatus.inProduction:
        return 'Đang thực hiện';
      case CustomRequestStatus.delivered:
        return 'Đã nộp bài';
      case CustomRequestStatus.approved:
        return 'Người nghe đã duyệt';
      case CustomRequestStatus.revisionRequested:
        return 'Yêu cầu sửa đổi';
      case CustomRequestStatus.completed:
        return 'Đã hoàn tất';
      case CustomRequestStatus.rejected:
        return 'Đã từ chối';
      case CustomRequestStatus.disputed:
        return 'Đang khiếu nại';
    }
  }

  PodcastRequest copyWith({
    CustomRequestStatus? status,
    String? rejectionReason,
    String? revisionNote,
    String? deliveryFileUrl,
    String? deliveryNote,
    List<RequestMilestone>? milestones,
    List<RequestChatMessage>? messages,
  }) {
    return PodcastRequest(
      id: id,
      listenerName: listenerName,
      listenerAvatar: listenerAvatar,
      topic: topic,
      description: description,
      targetDurationMinutes: targetDurationMinutes,
      deadline: deadline,
      totalBudget: totalBudget,
      milestones: milestones ?? this.milestones,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      revisionNote: revisionNote ?? this.revisionNote,
      deliveryFileUrl: deliveryFileUrl ?? this.deliveryFileUrl,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      createdAt: createdAt,
      messages: messages ?? this.messages,
    );
  }
}

// --- WALLET & BANK ACCOUNTS ---

class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final bool isDefault;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.isDefault = false,
  });
}

class WalletTransaction {
  final String id;
  final String title;
  final TransactionType type;
  final int amount; // VND
  final TransactionStatus status;
  final DateTime createdAt;
  final String? note;

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.note,
  });

  StatusType get statusType {
    switch (status) {
      case TransactionStatus.success:
        return StatusType.success;
      case TransactionStatus.processing:
        return StatusType.warning;
      case TransactionStatus.holding:
        return StatusType.info;
      case TransactionStatus.failed:
        return StatusType.error;
    }
  }

  String get statusDisplay {
    switch (status) {
      case TransactionStatus.success:
        return 'Thành công';
      case TransactionStatus.processing:
        return 'Đang xử lý';
      case TransactionStatus.holding:
        return 'Đang giữ';
      case TransactionStatus.failed:
        return 'Đã hoàn lại';
    }
  }
}

// --- COMMENTS MANAGEMENT ---

class StudioComment {
  final String id;
  final String podcastTitle;
  final String authorName;
  final String authorAvatar;
  final String content;
  final int timestampSeconds;
  final DateTime createdAt;
  final bool isPinned;
  final bool isHidden;
  final int likesCount;
  final bool likedByMe;
  final String? podcastId;

  const StudioComment({
    required this.id,
    required this.podcastTitle,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timestampSeconds,
    required this.createdAt,
    this.isPinned = false,
    this.isHidden = false,
    this.likesCount = 0,
    this.likedByMe = false,
    this.podcastId,
  });

  StudioComment copyWith({
    String? id,
    String? podcastTitle,
    String? authorName,
    String? authorAvatar,
    String? content,
    int? timestampSeconds,
    DateTime? createdAt,
    bool? isPinned,
    bool? isHidden,
    int? likesCount,
    bool? likedByMe,
    String? podcastId,
  }) {
    return StudioComment(
      id: id ?? this.id,
      podcastTitle: podcastTitle ?? this.podcastTitle,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      timestampSeconds: timestampSeconds ?? this.timestampSeconds,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      likesCount: likesCount ?? this.likesCount,
      likedByMe: likedByMe ?? this.likedByMe,
      podcastId: podcastId ?? this.podcastId,
    );
  }

  factory StudioComment.fromJson(
    Map<String, dynamic> json, {
    String? fallbackPodcastTitle,
    String? fallbackPodcastId,
  }) {
    final statusStr = json['status']?.toString().toUpperCase() ?? '';
    return StudioComment(
      id: json['commentId']?.toString() ?? json['id']?.toString() ?? '',
      podcastTitle: json['podcastTitle']?.toString() ?? fallbackPodcastTitle ?? 'Podcast',
      podcastId: json['podcastId']?.toString() ?? fallbackPodcastId,
      authorName: json['displayName']?.toString() ??
          json['username']?.toString() ??
          json['authorName']?.toString() ??
          'Thính giả',
      authorAvatar: json['avatarUrl']?.toString() ??
          json['authorAvatar']?.toString() ??
          '',
      content: json['content']?.toString() ?? '',
      timestampSeconds: (json['timestampSeconds'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isPinned: json['isPinned'] == true,
      isHidden: statusStr == 'HIDDEN' || json['isHidden'] == true,
      likesCount: (json['likeCount'] as num?)?.toInt() ??
          (json['likesCount'] as num?)?.toInt() ??
          0,
      likedByMe: json['likedByMe'] == true,
    );
  }
}

// --- INTERACTIVE FORM BUILDER (PREMIUM) ---

enum FormQuestionType { shortText, singleChoice, rating }

class FormQuestion {
  final String id;
  final String question;
  final FormQuestionType type;
  final List<String> options;

  const FormQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
  });
}

class InteractiveForm {
  final String id;
  final String title;
  final String description;
  final List<FormQuestion> questions;
  final int responsesCount;
  final DateTime createdAt;
  final bool isActive;

  const InteractiveForm({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.responsesCount,
    required this.createdAt,
    this.isActive = true,
  });
}

// --- CREATOR SERIES ---

class CreatorSeries {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String coverUrl;
  final String categoryId;
  final String categoryName;
  final String status;
  final DateTime createdAt;

  const CreatorSeries({
    required this.id,
    required this.title,
    required this.slug,
    this.description = '',
    this.coverUrl = '',
    this.categoryId = '',
    this.categoryName = '',
    this.status = 'ACTIVE',
    required this.createdAt,
  });

  factory CreatorSeries.fromJson(Map<String, dynamic> json) {
    return CreatorSeries(
      id: json['seriesId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// --- CREATOR CATEGORY ---

class CreatorCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;

  const CreatorCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
  });

  factory CreatorCategory.fromJson(Map<String, dynamic> json) {
    return CreatorCategory(
      id: json['categoryId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

// --- DASHBOARD MODELS ---

class GrowthDataPoint {
  final String date;
  final double value;

  const GrowthDataPoint({required this.date, required this.value});

  factory GrowthDataPoint.fromJson(Map<String, dynamic> json) {
    return GrowthDataPoint(
      date: json['label'] as String? ?? json['date'] as String? ?? '',
      value: (json['listens'] as num?)?.toDouble() ??
          (json['value'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

class DashboardMetrics {
  final int views;
  final int likes;
  final int followers;
  final double earnings;
  final double growthRate;
  final int trackCount;
  final int monthlyListens;
  final double availableBalance;
  final double pendingRelease;
  final String currency;

  const DashboardMetrics({
    this.views = 0,
    this.likes = 0,
    this.followers = 0,
    this.earnings = 0.0,
    this.growthRate = 0.0,
    this.trackCount = 0,
    this.monthlyListens = 0,
    this.availableBalance = 0.0,
    this.pendingRelease = 0.0,
    this.currency = 'USD',
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      views: (json['totalListens'] as num?)?.toInt() ??
          (json['views'] as num?)?.toInt() ??
          0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      followers: (json['followerCount'] as num?)?.toInt() ??
          (json['followers'] as num?)?.toInt() ??
          0,
      earnings: (json['monthlyRevenue'] as num?)?.toDouble() ??
          (json['earnings'] as num?)?.toDouble() ??
          0.0,
      growthRate: (json['growthRate'] as num?)?.toDouble() ?? 0.0,
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
      monthlyListens: (json['monthlyListens'] as num?)?.toInt() ?? 0,
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
      pendingRelease: (json['pendingRelease'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
    );
  }
}

class CreatorDashboardData {
  final String creatorProfileId;
  final String channelName;
  final String bio;
  final String avatarUrl;
  final String verificationStatus;
  final DashboardMetrics metrics;
  final List<GrowthDataPoint> growthSeries;

  const CreatorDashboardData({
    this.creatorProfileId = '',
    this.channelName = '',
    this.bio = '',
    this.avatarUrl = '',
    this.verificationStatus = '',
    this.metrics = const DashboardMetrics(),
    this.growthSeries = const [],
  });

  factory CreatorDashboardData.fromJson(Map<String, dynamic> json) {
    final prof = json['profile'] as Map<String, dynamic>? ?? {};
    final met = json['metrics'] as Map<String, dynamic>? ?? {};
    final rawGrowth = (json['growth'] ?? json['growthSeries']) as List?;
    final seriesList = rawGrowth
            ?.whereType<Map<String, dynamic>>()
            .map(GrowthDataPoint.fromJson)
            .toList() ??
        [];

    return CreatorDashboardData(
      creatorProfileId: prof['creatorProfileId']?.toString() ?? '',
      channelName: prof['channelName'] as String? ?? '',
      bio: prof['description'] as String? ?? prof['bio'] as String? ?? '',
      avatarUrl: prof['avatarUrl'] as String? ?? '',
      verificationStatus: prof['verificationStatus'] as String? ?? '',
      metrics: DashboardMetrics.fromJson(met),
      growthSeries: seriesList,
    );
  }
}

