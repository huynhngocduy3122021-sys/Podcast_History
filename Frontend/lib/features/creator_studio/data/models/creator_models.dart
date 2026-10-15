import 'package:podcast_history/core/widgets/status_chip.dart';

// --- ENUMS & STATUSES ---

enum CreatorStatus {
  pending,
  approved,
  rejected,
}

enum PodcastStatus {
  draft,
  aiModerating,
  pendingAdmin,
  published,
  rejected,
}

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

enum TransactionType {
  requestEarning,
  membership,
  withdrawal,
  refund,
}

enum TransactionStatus {
  success,
  processing,
  holding,
  failed,
}

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
  final PodcastStatus status;
  final String? rejectReason;
  final double? aiModerationScore; // 0.0 -> 1.0

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
    required this.status,
    this.rejectReason,
    this.aiModerationScore,
  });

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

  RequestMilestone copyWith({
    bool? isCompleted,
    bool? isApproved,
  }) {
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
  });

  StudioComment copyWith({
    bool? isPinned,
    bool? isHidden,
  }) {
    return StudioComment(
      id: id,
      podcastTitle: podcastTitle,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      timestampSeconds: timestampSeconds,
      createdAt: createdAt,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      likesCount: likesCount,
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
