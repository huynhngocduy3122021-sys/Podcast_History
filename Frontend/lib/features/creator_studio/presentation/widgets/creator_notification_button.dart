import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class CreatorNotificationButton extends ConsumerWidget {
  const CreatorNotificationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCreatorNotificationsCountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const CreatorNotificationSheet(),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3ECE4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.outlineDark : const Color(0xFFDFD4C8),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  unreadCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 20,
                  color: unreadCount > 0
                      ? AppColors.primaryLight
                      : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreatorNotificationSheet extends ConsumerStatefulWidget {
  const CreatorNotificationSheet({super.key});

  @override
  ConsumerState<CreatorNotificationSheet> createState() =>
      _CreatorNotificationSheetState();
}

class _CreatorNotificationSheetState
    extends ConsumerState<CreatorNotificationSheet> {
  bool _onlyUnread = false;

  IconData _iconForType(String type) {
    final t = type.toUpperCase();
    if (t.contains('PODCAST') || t.contains('REVIEW') || t.contains('SUBMIT')) {
      return Icons.mic_none_rounded;
    }
    if (t.contains('COMMENT') || t.contains('LIKE')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (t.contains('REQUEST') || t.contains('SERIES')) {
      return Icons.assignment_outlined;
    }
    if (t.contains('MEMBERSHIP') || t.contains('SUBSCRIPTION')) {
      return Icons.card_membership_rounded;
    }
    if (t.contains('WALLET') || t.contains('WITHDRAW') || t.contains('PAYMENT')) {
      return Icons.account_balance_wallet_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(creatorNotificationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allNotifications = notificationsAsync.value ?? [];
    final filteredNotifications = _onlyUnread
        ? allNotifications.where((n) => !n.read).toList()
        : allNotifications;
    final unreadCount = allNotifications.where((n) => !n.read).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Thanh kéo
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Thông báo Studio',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount mới',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      TextButton(
                        onPressed: () {
                          ref
                              .read(creatorNotificationsProvider.notifier)
                              .markAllAsRead();
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Đã đọc tất cả', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),

              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Tất cả (${allNotifications.length})'),
                      selected: !_onlyUnread,
                      onSelected: (val) => setState(() => _onlyUnread = false),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: !_onlyUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Chưa đọc ($unreadCount)'),
                      selected: _onlyUnread,
                      onSelected: (val) => setState(() => _onlyUnread = true),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _onlyUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              // Danh sách thông báo
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(creatorNotificationsProvider.notifier)
                      .loadNotifications(),
                  child: notificationsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
                            const SizedBox(height: 8),
                            const Text('Không thể tải thông báo'),
                            TextButton(
                              onPressed: () => ref
                                  .read(creatorNotificationsProvider.notifier)
                                  .loadNotifications(),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (_) {
                      if (filteredNotifications.isEmpty) {
                        return ListView(
                          controller: scrollController,
                          children: [
                            SizedBox(
                              height: 240,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_off_outlined,
                                      size: 48,
                                      color: isDark ? Colors.white24 : Colors.black26,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _onlyUnread
                                          ? 'Bạn đã đọc hết tất cả thông báo!'
                                          : 'Chưa có thông báo nào dành cho bạn.',
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredNotifications.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 68,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredNotifications[index];
                          return InkWell(
                            onTap: () {
                              if (!item.read) {
                                ref
                                    .read(creatorNotificationsProvider.notifier)
                                    .markAsRead(item.id);
                              }
                            },
                            child: Container(
                              color: item.read
                                  ? Colors.transparent
                                  : (isDark
                                      ? AppColors.primaryDark.withValues(alpha: 0.08)
                                      : const Color(0xFFFAF1E8)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: item.read
                                        ? (isDark ? Colors.white12 : Colors.black12)
                                        : AppColors.primaryLight.withValues(alpha: 0.15),
                                    foregroundColor: item.read
                                        ? (isDark ? Colors.white60 : Colors.black54)
                                        : AppColors.primaryLight,
                                    child: Icon(_iconForType(item.type), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: item.read
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (item.message.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            item.message,
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontSize: 12.5,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatTime(item.createdAt),
                                          style: TextStyle(
                                            color: isDark ? Colors.white38 : Colors.black38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!item.read)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 6),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
