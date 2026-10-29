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

class ContractStageModel {
  final String milestoneId;
  final String name;
  final String description;
  final DateTime dueAt;
  final int amount;
  final String status; // 'NOT_STARTED', 'SUBMITTED', 'REVISION_REQUESTED', 'DISPUTED', 'APPROVED', 'CANCELLED'

  const ContractStageModel({
    required this.milestoneId,
    required this.name,
    required this.description,
    required this.dueAt,
    required this.amount,
    required this.status,
  });

  factory ContractStageModel.fromJson(Map<String, dynamic> json) {
    return ContractStageModel(
      milestoneId: json['milestoneId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueAt: DateTime.tryParse(json['dueAt']?.toString() ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String? ?? 'NOT_STARTED').toUpperCase(),
    );
  }

  bool get isApproved => status == 'APPROVED';
  bool get isSubmitted => status == 'SUBMITTED';
  bool get isRevisionRequested => status == 'REVISION_REQUESTED';
  bool get isDisputed => status == 'DISPUTED';
  bool get isNotStarted => status == 'NOT_STARTED';
  bool get isCancelled => status == 'CANCELLED';
}

class ContractAgreement {
  final String requestId;
  final String contractId;
  final String contractStatus; // PENDING_SIGNATURE, IN_PROGRESS, DISPUTED, COMPLETED, TERMINATED, CANCELLED
  final int contractVersion;
  final String contentHash;
  final String contentSnapshot;
  final DateTime? creatorSignedAt;
  final DateTime? listenerSignedAt;
  final int budgetAmount;
  final int remainingHeld;
  final List<ContractStageModel> milestones;

  const ContractAgreement({
    required this.requestId,
    required this.contractId,
    required this.contractStatus,
    required this.contractVersion,
    required this.contentHash,
    required this.contentSnapshot,
    this.creatorSignedAt,
    this.listenerSignedAt,
    required this.budgetAmount,
    required this.remainingHeld,
    this.milestones = const [],
  });

  factory ContractAgreement.fromJson(Map<String, dynamic> json) {
    final stagesJson = json['milestones'];
    final stages = <ContractStageModel>[];
    if (stagesJson is List) {
      for (final s in stagesJson) {
        if (s is Map<String, dynamic>) {
          stages.add(ContractStageModel.fromJson(s));
        }
      }
    }
    return ContractAgreement(
      requestId: json['requestId']?.toString() ?? '',
      contractId: json['contractId']?.toString() ?? '',
      contractStatus: (json['contractStatus'] as String? ?? 'PENDING_SIGNATURE').toUpperCase(),
      contractVersion: (json['contractVersion'] as num?)?.toInt() ?? 1,
      contentHash: json['contentHash'] as String? ?? '',
      contentSnapshot: json['contentSnapshot'] as String? ?? '',
      creatorSignedAt: json['creatorSignedAt'] != null
          ? DateTime.tryParse(json['creatorSignedAt'].toString())
          : null,
      listenerSignedAt: json['listenerSignedAt'] != null
          ? DateTime.tryParse(json['listenerSignedAt'].toString())
          : null,
      budgetAmount: (json['budgetAmount'] as num?)?.toInt() ?? 0,
      remainingHeld: (json['remainingHeld'] as num?)?.toInt() ?? 0,
      milestones: stages,
    );
  }

  bool get isCreatorSigned => creatorSignedAt != null;
  bool get isListenerSigned => listenerSignedAt != null;
  bool get isBothSigned => isCreatorSigned && isListenerSigned;
  bool get isPendingSignature => contractStatus == 'PENDING_SIGNATURE';
  bool get isInProgress => contractStatus == 'IN_PROGRESS';
  bool get isCompleted => contractStatus == 'COMPLETED';
  bool get isDisputed => contractStatus == 'DISPUTED';
  bool get isTerminated => contractStatus == 'TERMINATED';
  bool get isCancelled => contractStatus == 'CANCELLED';
}

class ContractProposalStageInput {
  final String name;
  final String description;
  final DateTime dueAt;
  final int amount;

  const ContractProposalStageInput({
    required this.name,
    required this.description,
    required this.dueAt,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'dueAt': dueAt.toUtc().toIso8601String(),
      'amount': amount,
    };
  }
}

class ContractTerminationStatus {
  final String disputeId;
  final String contractId;
  final String status;
  final String? decision;
  final DateTime createdAt;
  final DateTime negotiationEndsAt;
  final DateTime? resolvedAt;

  const ContractTerminationStatus({
    required this.disputeId,
    required this.contractId,
    required this.status,
    this.decision,
    required this.createdAt,
    required this.negotiationEndsAt,
    this.resolvedAt,
  });

  factory ContractTerminationStatus.fromJson(Map<String, dynamic> json) {
    return ContractTerminationStatus(
      disputeId: json['disputeId']?.toString() ?? '',
      contractId: json['contractId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      decision: json['decision'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      negotiationEndsAt: DateTime.tryParse(json['negotiationEndsAt']?.toString() ?? '') ?? DateTime.now(),
      resolvedAt: json['resolvedAt'] != null ? DateTime.tryParse(json['resolvedAt'].toString()) : null,
    );
  }
}

class MilestoneSubmissionItem {
  final String submissionId;
  final String milestoneId;
  final int revisionNumber;
  final DateTime submittedAt;
  final String? note;
  final String? fileKey;
  final String? mediaUrl;

  const MilestoneSubmissionItem({
    required this.submissionId,
    required this.milestoneId,
    required this.revisionNumber,
    required this.submittedAt,
    this.note,
    this.fileKey,
    this.mediaUrl,
  });

  factory MilestoneSubmissionItem.fromJson(Map<String, dynamic> json) {
    return MilestoneSubmissionItem(
      submissionId: json['submissionId']?.toString() ?? '',
      milestoneId: json['milestoneId']?.toString() ?? '',
      revisionNumber: (json['revisionNumber'] as num?)?.toInt() ?? 1,
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? '') ?? DateTime.now(),
      note: json['note'] as String?,
      fileKey: json['fileKey'] as String?,
      mediaUrl: json['publicUrl'] as String?,
    );
  }

  MilestoneSubmissionItem copyWith({String? mediaUrl}) {
    return MilestoneSubmissionItem(
      submissionId: submissionId,
      milestoneId: milestoneId,
      revisionNumber: revisionNumber,
      submittedAt: submittedAt,
      note: note,
      fileKey: fileKey,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}

class RequestMilestone {
  final String id;
  final String title;
  final String? description;
  final int order;
  final int percentage;
  final int amount;
  final String status; // 'NOT_STARTED', 'SUBMITTED', 'REVISION_REQUESTED', 'DISPUTED', 'APPROVED'
  final bool isCompleted;
  final bool isApproved;
  final String? publicUrl;
  final String? submissionNote;

  const RequestMilestone({
    required this.id,
    required this.title,
    this.description,
    this.order = 1,
    required this.percentage,
    required this.amount,
    this.status = 'NOT_STARTED',
    this.isCompleted = false,
    this.isApproved = false,
    this.publicUrl,
    this.submissionNote,
  });

  bool get isSubmitted => status == 'SUBMITTED';
  bool get isRevisionRequested => status == 'REVISION_REQUESTED';
  bool get isDisputed => status == 'DISPUTED';
  bool get isNotStarted => status == 'NOT_STARTED';

  RequestMilestone copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    int? percentage,
    int? amount,
    String? status,
    bool? isCompleted,
    bool? isApproved,
    String? publicUrl,
    String? submissionNote,
  }) {
    return RequestMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      percentage: percentage ?? this.percentage,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      isCompleted: isCompleted ?? this.isCompleted,
      isApproved: isApproved ?? this.isApproved,
      publicUrl: publicUrl ?? this.publicUrl,
      submissionNote: submissionNote ?? this.submissionNote,
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
  final int? targetDurationMinutes;
  final DateTime? deadline;
  final int totalBudget; // VND
  final List<RequestMilestone> milestones;
  final CustomRequestStatus status;
  final String? rejectionReason;
  final String? revisionNote;
  final String? deliveryFileUrl;
  final String? deliveryNote;
  final DateTime createdAt;
  final List<RequestChatMessage> messages;

  // Escrow & Contract fields
  final bool hasEscrow;
  final ContractAgreement? contract;
  final ContractTerminationStatus? termination;
  final String? productType;
  final String? fileFormat;
  final String? duration;
  final String? acceptanceCriteria;
  final bool autoAcceptEnabled;
  final List<MilestoneSubmissionItem> submissions;

  const PodcastRequest({
    required this.id,
    required this.listenerName,
    required this.listenerAvatar,
    required this.topic,
    required this.description,
    this.targetDurationMinutes,
    this.deadline,
    required this.totalBudget,
    required this.milestones,
    required this.status,
    this.rejectionReason,
    this.revisionNote,
    this.deliveryFileUrl,
    this.deliveryNote,
    required this.createdAt,
    this.messages = const [],
    this.hasEscrow = false,
    this.contract,
    this.termination,
    this.productType,
    this.fileFormat,
    this.duration,
    this.acceptanceCriteria,
    this.autoAcceptEnabled = false,
    this.submissions = const [],
  });

  StatusType get statusType {
    if (hasEscrow && contract != null) {
      if (contract!.isPendingSignature) {
        return contract!.isCreatorSigned ? StatusType.info : StatusType.warning;
      }
      if (contract!.isInProgress) {
        if (milestones.any((m) => m.isRevisionRequested)) return StatusType.error;
        if (milestones.any((m) => m.isSubmitted)) return StatusType.warning;
        return StatusType.info;
      }
      if (contract!.isCompleted) return StatusType.success;
      if (contract!.isDisputed || contract!.isTerminated) return StatusType.error;
      if (contract!.isCancelled) return StatusType.error;
    }

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
    if (hasEscrow) {
      if (status == CustomRequestStatus.rejected) {
        return 'Đã từ chối';
      }
      if (contract == null) {
        return 'Chờ đề xuất mốc (Escrow)';
      }
      if (contract!.isPendingSignature) {
        if (contract!.isCreatorSigned && !contract!.isListenerSigned) {
          return 'Chờ người nghe ký';
        }
        if (!contract!.isCreatorSigned) {
          return 'Cần ký hợp đồng';
        }
        return 'Hợp đồng đã ký';
      }
      if (contract!.isInProgress) {
        if (milestones.any((m) => m.isRevisionRequested)) {
          return 'Cần sửa đổi';
        }
        if (milestones.any((m) => m.isSubmitted)) {
          return 'Chờ nghiệm thu';
        }
        return 'Đang thực hiện';
      }
      if (contract!.isCompleted) {
        return 'Đã hoàn tất';
      }
      if (contract!.isDisputed) {
        return 'Đang tranh chấp';
      }
      if (contract!.isTerminated) {
        return 'Đã chấm dứt';
      }
      if (contract!.isCancelled) {
        return 'Đã hủy';
      }
    }

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
    int? targetDurationMinutes,
    DateTime? deadline,
    bool? hasEscrow,
    ContractAgreement? contract,
    ContractTerminationStatus? termination,
    String? productType,
    String? fileFormat,
    String? duration,
    String? acceptanceCriteria,
    bool? autoAcceptEnabled,
    List<MilestoneSubmissionItem>? submissions,
  }) {
    return PodcastRequest(
      id: id,
      listenerName: listenerName,
      listenerAvatar: listenerAvatar,
      topic: topic,
      description: description,
      targetDurationMinutes: targetDurationMinutes ?? this.targetDurationMinutes,
      deadline: deadline ?? this.deadline,
      totalBudget: totalBudget,
      milestones: milestones ?? this.milestones,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      revisionNote: revisionNote ?? this.revisionNote,
      deliveryFileUrl: deliveryFileUrl ?? this.deliveryFileUrl,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      createdAt: createdAt,
      messages: messages ?? this.messages,
      hasEscrow: hasEscrow ?? this.hasEscrow,
      contract: contract ?? this.contract,
      termination: termination ?? this.termination,
      productType: productType ?? this.productType,
      fileFormat: fileFormat ?? this.fileFormat,
      duration: duration ?? this.duration,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      autoAcceptEnabled: autoAcceptEnabled ?? this.autoAcceptEnabled,
      submissions: submissions ?? this.submissions,
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

// --- CREATOR SYSTEM PLANS & SUBSCRIPTIONS ---

class CreatorSystemBenefit {
  final String key;
  final String value;
  final String description;

  const CreatorSystemBenefit({
    required this.key,
    required this.value,
    required this.description,
  });

  factory CreatorSystemBenefit.fromJson(Map<String, dynamic> json) {
    return CreatorSystemBenefit(
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'description': description,
  };
}

class CreatorSystemPlan {
  final String planId;
  final String code;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int? durationDays;
  final String status;
  final List<CreatorSystemBenefit> benefits;

  const CreatorSystemPlan({
    required this.planId,
    required this.code,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    this.durationDays,
    required this.status,
    required this.benefits,
  });

  bool get isPaid => price > 0;
  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory CreatorSystemPlan.fromJson(Map<String, dynamic> json) {
    final rawBenefits = json['benefits'] as List? ?? [];
    return CreatorSystemPlan(
      planId: json['planId']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'VND',
      durationDays: (json['durationDays'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'ACTIVE',
      benefits: rawBenefits
          .whereType<Map<String, dynamic>>()
          .map(CreatorSystemBenefit.fromJson)
          .toList(),
    );
  }
}

class CreatorSystemSubscription {
  final String? planCode;
  final String? planId;
  final String? planName;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? uploadLimit;
  final int uploadsUsed;
  final int? uploadsRemaining;
  final bool canLivestream;
  final String? subscriptionId;
  final double? lastPaymentAmount;
  final String? lastPaymentStatus;
  final String? lastPaymentReference;
  final List<CreatorSystemBenefit> benefits;

  const CreatorSystemSubscription({
    this.planCode,
    this.planId,
    this.planName,
    this.startAt,
    this.endAt,
    this.uploadLimit,
    this.uploadsUsed = 0,
    this.uploadsRemaining,
    this.canLivestream = false,
    this.subscriptionId,
    this.lastPaymentAmount,
    this.lastPaymentStatus,
    this.lastPaymentReference,
    this.benefits = const [],
  });

  bool get isPaidPlan =>
      planCode != null &&
      planCode!.toUpperCase() != 'FREE' &&
      planCode!.toUpperCase() != 'DISABLED';

  bool get isActive {
    if (!isPaidPlan) return false;
    if (endAt == null) return true;
    return endAt!.isAfter(DateTime.now());
  }

  bool get isPendingPayment => lastPaymentStatus?.toUpperCase() == 'PENDING';

  factory CreatorSystemSubscription.fromJson(Map<String, dynamic> json) {
    final rawBenefits = json['benefits'] as List? ?? [];
    return CreatorSystemSubscription(
      planCode: json['planCode'] as String?,
      planId: json['planId']?.toString(),
      planName: json['planName'] as String?,
      startAt: json['startAt'] != null
          ? DateTime.tryParse(json['startAt'].toString())
          : null,
      endAt: json['endAt'] != null
          ? DateTime.tryParse(json['endAt'].toString())
          : null,
      uploadLimit: (json['uploadLimit'] as num?)?.toInt(),
      uploadsUsed: (json['uploadsUsed'] as num?)?.toInt() ?? 0,
      uploadsRemaining: (json['uploadsRemaining'] as num?)?.toInt(),
      canLivestream: json['canLivestream'] as bool? ?? false,
      subscriptionId: json['subscriptionId']?.toString(),
      lastPaymentAmount: (json['lastPaymentAmount'] as num?)?.toDouble(),
      lastPaymentStatus: json['lastPaymentStatus'] as String?,
      lastPaymentReference: json['lastPaymentReference'] as String?,
      benefits: rawBenefits
          .whereType<Map<String, dynamic>>()
          .map(CreatorSystemBenefit.fromJson)
          .toList(),
    );
  }
}

class CreatorCheckoutPayment {
  final String checkoutId;
  final String? creatorSubscriptionId;
  final String purpose;
  final String paymentCode;
  final String qrImageUrl;
  final double amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final DateTime? expiresAt;

  const CreatorCheckoutPayment({
    required this.checkoutId,
    this.creatorSubscriptionId,
    required this.purpose,
    required this.paymentCode,
    required this.qrImageUrl,
    required this.amount,
    required this.currency,
    required this.status,
    this.paidAt,
    this.expiresAt,
  });

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get isPending => status.toUpperCase() == 'PENDING';

  factory CreatorCheckoutPayment.fromJson(Map<String, dynamic> json) {
    return CreatorCheckoutPayment(
      checkoutId: json['checkoutId']?.toString() ?? '',
      creatorSubscriptionId: json['creatorSubscriptionId']?.toString(),
      purpose: json['purpose'] as String? ?? '',
      paymentCode: json['paymentCode'] as String? ?? '',
      qrImageUrl: json['qrImageUrl'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'VND',
      status: json['status'] as String? ?? 'PENDING',
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }
}

class CreatorChannelPlan {
  final String planId;
  final String creatorId;
  final String templateCode;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int durationDays;
  final String status;

  const CreatorChannelPlan({
    required this.planId,
    required this.creatorId,
    required this.templateCode,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.status,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory CreatorChannelPlan.fromJson(Map<String, dynamic> json) {
    return CreatorChannelPlan(
      planId: json['planId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      templateCode: json['templateCode']?.toString() ?? '',
      name: json['name'] as String? ?? 'Gói Hội viên Kênh',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'VND',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}

class CreatorPlanTemplate {
  final String code;
  final String name;
  final double suggestedPrice;
  final String currency;
  final int durationDays;
  final String benefit;

  const CreatorPlanTemplate({
    required this.code,
    required this.name,
    required this.suggestedPrice,
    required this.currency,
    required this.durationDays,
    required this.benefit,
  });

  factory CreatorPlanTemplate.fromJson(Map<String, dynamic> json) {
    String parsedBenefit = '';
    if (json['benefit'] != null) {
      parsedBenefit = json['benefit'].toString();
    } else if (json['benefits'] is List) {
      parsedBenefit = (json['benefits'] as List)
          .map((b) => b is Map ? (b['description'] ?? b['name'] ?? '').toString() : b.toString())
          .where((s) => s.isNotEmpty)
          .join(' • ');
    }

    return CreatorPlanTemplate(
      code: json['code']?.toString() ?? json['templateCode']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      suggestedPrice: (json['suggestedPrice'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
      currency: json['currency'] as String? ?? 'VND',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      benefit: parsedBenefit,
    );
  }
}

class CreatorStudioNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? payload;

  const CreatorStudioNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.read = false,
    this.createdAt,
    this.readAt,
    this.payload,
  });

  CreatorStudioNotification copyWith({bool? read}) {
    return CreatorStudioNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      read: read ?? this.read,
      createdAt: createdAt,
      readAt: readAt,
      payload: payload,
    );
  }

  factory CreatorStudioNotification.fromJson(Map<String, dynamic> json) {
    return CreatorStudioNotification(
      id: json['notificationId']?.toString() ?? json['id']?.toString() ?? '',
      type: json['notificationType']?.toString() ?? json['type']?.toString() ?? 'SYSTEM',
      title: json['title'] as String? ?? 'Thông báo Studio',
      message: json['message'] as String? ?? '',
      read: json['read'] == true || json['isRead'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())?.toLocal()
          : null,
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : null,
    );
  }
}

class CreatorMemberItem {
  final String subscriptionId;
  final String listenerId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String membershipPlanId;
  final String planName;
  final double price;
  final String currency;
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;

  const CreatorMemberItem({
    required this.subscriptionId,
    required this.listenerId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.membershipPlanId,
    required this.planName,
    required this.price,
    required this.currency,
    required this.status,
    this.startAt,
    this.endAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory CreatorMemberItem.fromJson(Map<String, dynamic> json) {
    return CreatorMemberItem(
      subscriptionId: json['subscriptionId']?.toString() ?? '',
      listenerId: json['listenerId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ??
          json['username']?.toString() ??
          'Thính giả',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      membershipPlanId: json['membershipPlanId']?.toString() ?? '',
      planName: json['planName']?.toString() ?? 'Gói thành viên',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'VND',
      status: json['status']?.toString() ?? 'ACTIVE',
      startAt: json['startAt'] != null
          ? DateTime.tryParse(json['startAt'].toString())?.toLocal()
          : null,
      endAt: json['endAt'] != null
          ? DateTime.tryParse(json['endAt'].toString())?.toLocal()
          : null,
    );
  }
}

class PageCreatorMembers {
  final int totalPages;
  final int totalElements;
  final int size;
  final int number;
  final List<CreatorMemberItem> content;

  const PageCreatorMembers({
    required this.totalPages,
    required this.totalElements,
    required this.size,
    required this.number,
    required this.content,
  });

  factory PageCreatorMembers.fromJson(Map<String, dynamic> json) {
    final rawList = json['content'];
    final content = (rawList is List)
        ? rawList
            .whereType<Map<String, dynamic>>()
            .map(CreatorMemberItem.fromJson)
            .toList()
        : <CreatorMemberItem>[];

    return PageCreatorMembers(
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? content.length,
      size: (json['size'] as num?)?.toInt() ?? 20,
      number: (json['number'] as num?)?.toInt() ?? 0,
      content: content,
    );
  }
}

