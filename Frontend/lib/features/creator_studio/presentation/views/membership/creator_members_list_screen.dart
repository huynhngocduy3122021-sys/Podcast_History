import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/utils/image_url_helper.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class CreatorMembersListScreen extends ConsumerStatefulWidget {
  const CreatorMembersListScreen({super.key});

  @override
  ConsumerState<CreatorMembersListScreen> createState() =>
      _CreatorMembersListScreenState();
}

class _CreatorMembersListScreenState
    extends ConsumerState<CreatorMembersListScreen> {
  String _selectedStatus = 'ACTIVE'; // 'ACTIVE' or 'ALL'
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final membersAsync = ref.watch(creatorMembershipsProvider(_selectedStatus));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành viên Kênh'),
      ),
      body: Column(
        children: [
          // Filter Chips
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
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Đang hoạt động (ACTIVE)'),
                  selected: _selectedStatus == 'ACTIVE',
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedStatus = 'ACTIVE');
                  },
                  selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _selectedStatus == 'ACTIVE'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _selectedStatus == 'ACTIVE'
                        ? AppColors.primaryLight
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: _selectedStatus == 'ALL',
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedStatus = 'ALL');
                  },
                  selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _selectedStatus == 'ALL'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _selectedStatus == 'ALL'
                        ? AppColors.primaryLight
                        : null,
                  ),
                ),
              ],
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
                        'Không thể tải danh sách thành viên: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          creatorMembershipsProvider(_selectedStatus),
                        ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (pageData) {
                final members = pageData.content;

                if (members.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                        creatorMembershipsProvider(_selectedStatus),
                      );
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
                                    Icons.group_off_rounded,
                                    size: 48,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedStatus == 'ACTIVE'
                                      ? 'Chưa có thành viên nào đang hoạt động'
                                      : 'Chưa có thành viên nào đăng ký kênh',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Khi thính giả đăng ký Gói thành viên của kênh, danh sách sẽ xuất hiện tại đây.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
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
                    ref.invalidate(creatorMembershipsProvider(_selectedStatus));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    itemCount: members.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                'Tổng cộng: ${pageData.totalElements} thành viên',
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

                      final member = members[index - 1];
                      final isActive = member.isActive;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF211F1D)
                              : const Color(0xFFF9F7F3),
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
                              backgroundColor: AppColors.primaryLight
                                  .withValues(alpha: 0.15),
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
                                              ? AppColors.success
                                                  .withValues(alpha: 0.15)
                                              : Colors.grey
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isActive
                                              ? 'ĐANG HOẠT ĐỘNG'
                                              : member.status,
                                          style: TextStyle(
                                            color: isActive
                                                ? AppColors.success
                                                : Colors.grey,
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
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB800)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                                  if (member.startAt != null &&
                                      member.endAt != null)
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
}
