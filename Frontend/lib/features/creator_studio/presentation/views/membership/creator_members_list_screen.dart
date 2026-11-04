import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/utils/image_url_helper.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class _ChannelFollower {
  final String displayName;
  final String username;
  final String avatarUrl;
  final DateTime followedAt;

  const _ChannelFollower({
    required this.displayName,
    required this.username,
    this.avatarUrl = '',
    required this.followedAt,
  });
}

class CreatorMembersListScreen extends ConsumerStatefulWidget {
  const CreatorMembersListScreen({super.key});

  @override
  ConsumerState<CreatorMembersListScreen> createState() =>
      _CreatorMembersListScreenState();
}

class _CreatorMembersListScreenState
    extends ConsumerState<CreatorMembersListScreen> {
  String _selectedTab = 'ALL'; // 'ALL', 'MEMBERS', 'FOLLOWERS'
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final membersAsync = ref.watch(creatorMembershipsProvider('ACTIVE'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành viên Kênh'),
      ),
      body: Column(
        children: [
          // Filter Chips: Tất cả, Thành viên, Người theo dõi
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tất cả'),
                    selected: _selectedTab == 'ALL',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'ALL');
                    },
                    selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _selectedTab == 'ALL'
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedTab == 'ALL'
                          ? AppColors.primaryLight
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Thành viên'),
                    selected: _selectedTab == 'MEMBERS',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'MEMBERS');
                    },
                    selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _selectedTab == 'MEMBERS'
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedTab == 'MEMBERS'
                          ? AppColors.primaryLight
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Người theo dõi'),
                    selected: _selectedTab == 'FOLLOWERS',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'FOLLOWERS');
                    },
                    selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _selectedTab == 'FOLLOWERS'
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedTab == 'FOLLOWERS'
                          ? AppColors.primaryLight
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content List
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Không thể tải danh sách: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          creatorMembershipsProvider('ACTIVE'),
                        ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (pageData) {
                final members = pageData.content;
                final notifications =
                    ref.watch(creatorNotificationsProvider).value ?? [];
                final followers = notifications
                    .where((n) => n.type == 'NEW_FOLLOWER')
                    .map((n) {
                      final title = n.title
                          .replaceAll(' vừa theo dõi kênh của bạn', '')
                          .trim();
                      final msg = n.message
                          .replaceAll(' vừa theo dõi kênh của bạn.', '')
                          .trim();
                      final name = title.isNotEmpty
                          ? title
                          : (msg.isNotEmpty ? msg : 'Người nghe');
                      return _ChannelFollower(
                        displayName: name,
                        username: name.toLowerCase().replaceAll(' ', ''),
                        avatarUrl: n.payload?['avatarUrl']?.toString() ?? '',
                        followedAt: n.createdAt ?? DateTime.now(),
                      );
                    })
                    .toList();

                final int totalItems;
                final bool isEmpty;
                if (_selectedTab == 'MEMBERS') {
                  totalItems = members.length;
                  isEmpty = members.isEmpty;
                } else if (_selectedTab == 'FOLLOWERS') {
                  totalItems = followers.length;
                  isEmpty = followers.isEmpty;
                } else {
                  totalItems = members.length + followers.length;
                  isEmpty = totalItems == 0;
                }

                if (isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(creatorMembershipsProvider('ACTIVE'));
                      ref
                          .read(creatorNotificationsProvider.notifier)
                          .loadNotifications();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _selectedTab == 'FOLLOWERS'
                                        ? Icons.person_off_rounded
                                        : Icons.group_off_rounded,
                                    size: 48,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedTab == 'MEMBERS'
                                      ? 'Chưa có thành viên nào đăng ký gói kênh'
                                      : (_selectedTab == 'FOLLOWERS'
                                          ? 'Chưa có người theo dõi nào'
                                          : 'Chưa có thành viên hay người theo dõi nào'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _selectedTab == 'MEMBERS'
                                      ? 'Khi thính giả đăng ký Gói thành viên của kênh, danh sách sẽ xuất hiện tại đây.'
                                      : (_selectedTab == 'FOLLOWERS'
                                          ? 'Khi thính giả bấm theo dõi kênh của bạn, danh sách sẽ xuất hiện tại đây.'
                                          : 'Danh sách thành viên và người theo dõi của kênh sẽ xuất hiện tại đây.'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(creatorMembershipsProvider('ACTIVE'));
                    ref
                        .read(creatorNotificationsProvider.notifier)
                        .loadNotifications();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    itemCount: totalItems + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final String countText;
                        if (_selectedTab == 'MEMBERS') {
                          countText = 'Tổng cộng: ${members.length} thành viên';
                        } else if (_selectedTab == 'FOLLOWERS') {
                          countText = 'Tổng cộng: ${followers.length} người theo dõi';
                        } else {
                          countText =
                              'Tổng cộng: $totalItems người (${members.length} thành viên, ${followers.length} người theo dõi)';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                countText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final itemIndex = index - 1;

                      if (_selectedTab == 'MEMBERS') {
                        return _buildMemberCard(
                          context: context,
                          member: members[itemIndex],
                          isDark: isDark,
                        );
                      }

                      if (_selectedTab == 'FOLLOWERS') {
                        return _buildFollowerCard(
                          context: context,
                          follower: followers[itemIndex],
                          isDark: isDark,
                        );
                      }

                      // Tab Tất cả (ALL): hiển thị Thành viên trước, sau đó là Người theo dõi
                      if (itemIndex < members.length) {
                        return _buildMemberCard(
                          context: context,
                          member: members[itemIndex],
                          isDark: isDark,
                        );
                      } else {
                        final followerIndex = itemIndex - members.length;
                        return _buildFollowerCard(
                          context: context,
                          follower: followers[followerIndex],
                          isDark: isDark,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard({
    required BuildContext context,
    required CreatorMemberItem member,
    required bool isDark,
  }) {
    final isActive = member.isActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211F1D) : const Color(0xFFF9F7F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? (isDark
                  ? const Color(0xFF4C3626)
                  : const Color(0xFFEAD8C7))
              : (isDark ? Colors.white12 : Colors.black12),
          width: isActive ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
            backgroundImage: member.avatarUrl.trim().isNotEmpty
                ? NetworkImage(
                    resolveImageUrl(member.avatarUrl),
                  )
                : null,
            child: member.avatarUrl.trim().isEmpty
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.success.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'ĐANG HOẠT ĐỘNG' : member.status,
                        style: TextStyle(
                          color: isActive ? AppColors.success : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (member.username.isNotEmpty &&
                    member.username != member.displayName) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${member.username}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Subscription & Plan details
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 13,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.planName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFFB800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (member.price > 0)
                      Text(
                        AppFormatters.formatVND(
                          member.price.toInt(),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Date range
                if (member.startAt != null && member.endAt != null)
                  Text(
                    'Hiệu lực: ${_dateFormat.format(member.startAt!)} - ${_dateFormat.format(member.endAt!)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey,
                    ),
                  )
                else if (member.endAt != null)
                  Text(
                    'Hạn đến: ${_dateFormat.format(member.endAt!)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerCard({
    required BuildContext context,
    required _ChannelFollower follower,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211F1D) : const Color(0xFFF9F7F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
            backgroundImage: follower.avatarUrl.trim().isNotEmpty
                ? NetworkImage(
                    resolveImageUrl(follower.avatarUrl),
                  )
                : null,
            child: follower.avatarUrl.trim().isEmpty
                ? Text(
                    follower.displayName.isNotEmpty
                        ? follower.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Follower Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        follower.displayName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ĐANG THEO DÕI',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (follower.username.isNotEmpty &&
                    follower.username != follower.displayName) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${follower.username}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Follower Badge
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 13,
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Người theo dõi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Date
                Text(
                  'Theo dõi từ: ${_dateFormat.format(follower.followedAt)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
