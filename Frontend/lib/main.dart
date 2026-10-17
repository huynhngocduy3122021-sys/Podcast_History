import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/creator_studio/presentation/controllers/creator_controller.dart';
import 'features/creator_studio/presentation/views/creator_main_shell.dart';
import 'features/creator_studio/presentation/views/registration/creator_registration_screen.dart';

import 'api_service.dart';

void main() => runApp(const VietCastApp());

enum UserRole { listener, creator, admin }

class Account {
  const Account({
    required this.email,
    required this.name,
    required this.role,
    required this.session,
  });
  final String email, name;
  final UserRole role;
  final AuthSession session;
}

class VietCastApp extends StatefulWidget {
  const VietCastApp({super.key});
  @override
  State<VietCastApp> createState() => _AppState();
}

class _AppState extends State<VietCastApp> {
  ThemeMode mode = ThemeMode.light;
  Account? account;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      creatorAccessTokenProvider.overrideWithValue(
        account?.session.accessToken,
      ),
    ],
    child: MaterialApp(
      title: 'VietCast',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ColoredBox(
          color: isDark ? const Color(0xFF121212) : const Color(0xFFEFE8DE),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: account == null
          ? AuthPage(
              onAuthenticated: (value) => setState(() => account = value),
            )
          : switch (account!.role) {
              UserRole.listener => Shell(
                session: account!.session,
                onSessionRefreshed: (session) => setState(() {
                  final current = account;
                  if (current != null &&
                      current.session.user.id == session.user.id) {
                    account = Account(
                      email: current.email,
                      name: current.name,
                      role: current.role,
                      session: session,
                    );
                  }
                }),
                onProfileUpdated: (user) => setState(() {
                  final current = account;
                  if (current != null) {
                    account = Account(
                      email: user.email,
                      name: user.displayName,
                      role: current.role,
                      session: AuthSession(
                        user: user,
                        accessToken: current.session.accessToken,
                        refreshToken: current.session.refreshToken,
                        tokenType: current.session.tokenType,
                        expiresIn: current.session.expiresIn,
                        refreshExpiresIn: current.session.refreshExpiresIn,
                      ),
                    );
                  }
                }),
                displayName: account!.name,
                onTheme: toggleTheme,
                onLogout: logout,
              ),
              UserRole.creator => CreatorShell(
                displayName: account!.name,
                onTheme: toggleTheme,
                onLogout: logout,
              ),
              UserRole.admin => AdminShell(
                displayName: account!.name,
                onTheme: toggleTheme,
                onLogout: logout,
              ),
            },
    ),
  );

  void toggleTheme() => setState(
    () => mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
  );

  Future<void> logout() async {
    final session = account?.session;
    setState(() => account = null);
    if (session != null) {
      try {
        await AuthApi().logout(session.refreshToken);
      } catch (_) {
        // The local session is already cleared even if the network is offline.
      }
    }
  }
}

class Show {
  const Show(
    this.title,
    this.channel,
    this.period,
    this.duration,
    this.colors, {
    this.member = false,
    this.id,
    this.creatorId,
    this.durationSeconds,
  });
  final String title, channel, period, duration;
  final List<Color> colors;
  final bool member;
  final String? id;
  final String? creatorId;
  final int? durationSeconds;
}

String _formatVnd(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} VND';

final fallbackShows = <Show>[
  Show(
    'Nhung ngay dau cua nen doc lap',
    'Su Viet ke chuyen',
    '1945 - 1954',
    '32:18',
    [Color(0xFF6D3026), Color(0xFFC68C58)],
  ),
  Show(
    'Duong Truong Son - mot ky tich',
    'Chuyen ben dong lich su',
    '1954 - 1975',
    '41:06',
    [Color(0xFF254A50), Color(0xFF93B4A4)],
  ),
  Show(
    'Doi Moi: Tu y tuong den buoc ngoat',
    'VietCast Originals',
    '1986 - nay',
    '28:44',
    [Color(0xFF803E31), Color(0xFFE0B84A)],
    member: true,
  ),
  Show(
    'Nhan vat: Nguyen An Ninh',
    'Goc nhin Viet Nam',
    '1858 - 1945',
    '24:10',
    [Color(0xFF273B5A), Color(0xFFA3B4D0)],
  ),
];

List<Show> shows = List<Show>.of(fallbackShows);

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.session,
    this.onSessionRefreshed,
    this.onProfileUpdated,
    required this.displayName,
    required this.onTheme,
    required this.onLogout,
  });
  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionRefreshed;
  final ValueChanged<AuthUser>? onProfileUpdated;
  final String displayName;
  final VoidCallback onTheme;
  final VoidCallback onLogout;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final ListenerApi api;
  bool apiLoading = true;
  bool usingSamplePodcasts = true;
  String? apiError;
  final commentsByPodcast = <String, List<CommentData>>{};
  final creatorDetails = <String, Map<String, dynamic>>{};
  StreamSubscription<String>? commentSubscription;
  int tab = 0;
  Show? current;
  bool playing = false;
  final progressByShow = <String, double>{shows[0].title: .42};
  final likedShowTitles = <String>{shows[0].title};
  final savedShowTitles = <String>{};
  int walletBalance = 350000;
  final notifications = <AppNotification>[
    const AppNotification(
      id: 'new-episode',
      title: 'Su Viet ke chuyen da dang tap moi',
      subtitle: '12 phut truoc',
      icon: Icons.mic_none,
    ),
    const AppNotification(
      id: 'membership',
      title: 'Ban da tro thanh thanh vien',
      subtitle: 'Hom qua',
      icon: Icons.workspace_premium_outlined,
    ),
    const AppNotification(
      id: 'liked-comment',
      title: 'Lan Anh da thich binh luan cua ban',
      subtitle: '2 ngay truoc',
      icon: Icons.favorite_border,
      read: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    api = ListenerApi(
      accessToken: widget.session.accessToken,
      refreshToken: widget.session.refreshToken,
      onSessionRefreshed: widget.onSessionRefreshed,
    );
    shows = List<Show>.of(fallbackShows);
    _loadListenerFlow();
  }

  Future<void> _loadListenerFlow() async {
    if (mounted) {
      setState(() {
        apiLoading = true;
        apiError = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        api.searchPodcasts(),
        _optionalList(api.listeningHistory()),
        _optionalList(api.savedPodcasts()),
        _optionalList(api.follows()),
        _optionalList(api.reports()),
        _optionalList(api.subscriptions()),
        _optionalList(api.seriesRequests()),
        _optionalList(api.categories()),
        _optionalList(api.creators()),
      ]);
      final podcasts = results[0] as List<ListenerPodcast>;
      final creatorList = results[8] as List<Map<String, dynamic>>;
      final creatorIds = creatorList
          .map((item) => item['creatorProfileId']?.toString())
          .whereType<String>()
          .toSet();
      final creatorResponses = await Future.wait(
        creatorIds.map((id) async {
          try {
            return MapEntry(id, await api.creator(id));
          } catch (_) {
            return MapEntry(id, <String, dynamic>{});
          }
        }),
      );
      creatorDetails.addEntries(creatorResponses);
      if (podcasts.isNotEmpty) {
        usingSamplePodcasts = false;
        shows = podcasts.asMap().entries.map((entry) {
          final podcast = entry.value;
          final colorSets = [
            [const Color(0xFF6D3026), const Color(0xFFC68C58)],
            [const Color(0xFF254A50), const Color(0xFF93B4A4)],
            [const Color(0xFF803E31), const Color(0xFFE0B84A)],
          ];
          final colors = colorSets[entry.key % colorSets.length];
          final duration = podcast.durationSeconds;
          return Show(
            podcast.title,
            podcast.creatorChannelName,
            'Podcast',
            _formatDuration(duration),
            colors,
            member: podcast.visibility == 'MEMBERS_ONLY',
            id: podcast.id,
            creatorId: podcast.creatorId,
            durationSeconds: duration,
          );
        }).toList();
        final interactionResponses = await Future.wait(
          podcasts.map(
            (podcast) async => (
              likes: await api.likes(podcast.id),
              comments: await api.comments(podcast.id),
            ),
          ),
        );
        for (var index = 0; index < podcasts.length; index++) {
          final podcast = podcasts[index];
          final interaction = interactionResponses[index];
          if (interaction.likes['likedByMe'] == true) {
            likedShowTitles.add(podcast.title);
          }
          commentsByPodcast[podcast.id] = interaction.comments
              .map(
                (comment) => CommentData(
                  '${comment['displayName'] ?? comment['username'] ?? 'Listener'}',
                  '${comment['content'] ?? ''}',
                  comment['timestampSeconds'] == null
                      ? ''
                      : _formatDuration(
                          (comment['timestampSeconds'] as num).toInt(),
                        ),
                  id: comment['commentId']?.toString(),
                  durationSeconds: podcast.durationSeconds,
                ),
              )
              .toList();
        }
      }
      for (final item in results[1] as List<Map<String, dynamic>>) {
        final title = '${item['podcastTitle'] ?? ''}';
        final seconds = (item['progressSeconds'] as num?)?.toInt() ?? 0;
        if (title.isNotEmpty) progressByShow[title] = seconds / 86400;
      }
      for (final item in results[2] as List<Map<String, dynamic>>) {
        final title = '${item['title'] ?? ''}';
        if (title.isNotEmpty) savedShowTitles.add(title);
      }
      if (mounted) setState(() => apiLoading = false);
    } catch (exception) {
      if (mounted) {
        setState(() {
          apiLoading = false;
          apiError = exception.toString();
        });
      }
    }
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> _optionalList(
    Future<List<Map<String, dynamic>>> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return [];
    }
  }

  void play(Show s) => setState(() {
    current = s;
    playing = true;
  });

  void openShow(Show show) {
    play(show);
    commentSubscription?.cancel();
    if (show.id != null) {
      unawaited(api.playback(show.id!));
      unawaited(api.listeningHistoryForPodcast(show.id!));
      commentSubscription = api
          .commentStream(show.id!)
          .listen((_) {}, onError: (_) {});
    }
    _showPlayer(show);
  }

  @override
  void dispose() {
    commentSubscription?.cancel();
    super.dispose();
  }

  void updateLiked(Show show, bool liked) => setState(() {
    if (liked) {
      likedShowTitles.add(show.title);
    } else {
      likedShowTitles.remove(show.title);
    }
    if (show.id != null) {
      unawaited(liked ? api.like(show.id!) : api.unlike(show.id!));
    }
  });

  void updateSaved(Show show, bool saved) => setState(() {
    if (saved) {
      savedShowTitles.add(show.title);
    } else {
      savedShowTitles.remove(show.title);
    }
    if (show.id != null) {
      unawaited(
        saved ? api.savePodcast(show.id!) : api.unsavePodcast(show.id!),
      );
    }
  });

  void _showReport(Show show) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFF181818),
    builder: (_) => ReportPanel(
      show: show,
      onSubmitted: (reason) {
        Navigator.pop(context);
        final future = show.id == null
            ? Future<void>.value()
            : api.createReport(
                targetType: 'PODCAST',
                targetId: show.id!,
                reasonCode: 'INAPPROPRIATE',
                description: reason,
              );
        future
            .then((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Da gui bao cao "$reason" cho admin.')),
              );
            })
            .catchError((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Khong the gui bao cao luc nay.')),
              );
            });
      },
    ),
  );

  Future<void> _showMembership(Show show) async {
    if (show.creatorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podcast nay chua co creator ID.')),
      );
      return;
    }
    try {
      final plans = await api.membershipPlans(show.creatorId!);
      if (!mounted) return;
      if (plans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creator chua co goi membership active.'),
          ),
        );
        return;
      }
      final plan = plans.first;
      final planId = '${plan['membershipPlanId']}';
      final planName = '${plan['name'] ?? 'Membership'}';
      final price = '${plan['price'] ?? ''} ${plan['currency'] ?? 'VND'}';
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Dang ky $planName'),
          content: Text(
            'Goi cua ${show.channel}: $price. Backend se tao checkout o trang thai cho thanh toan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final checkout = await api.checkout(planId);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Checkout ${checkout['subscriptionStatus'] ?? 'PENDING'} - chua xac nhan thanh toan.',
                      ),
                    ),
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Khong the tao checkout.')),
                  );
                }
              },
              child: const Text('Tao checkout'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Khong the tai goi membership.')),
        );
      }
    }
  }

  void _showCreatorProfile(Show creatorShow) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CreatorProfilePanel(
        show: creatorShow,
        api: api,
        onMembership: () => _showMembership(creatorShow),
        onOpen: (audio) {
          Navigator.pop(context);
          openShow(audio);
        },
      ),
    ),
  );

  void _showPlayer(Show show) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    barrierColor: Colors.black54,
    barrierLabel: 'Dong player',
    backgroundColor: Colors.transparent,
    builder: (_) => Player(
      show: show,
      playing: playing,
      initialProgress: progressByShow[show.title] ?? 0,
      initialLiked: likedShowTitles.contains(show.title),
      initialSaved: savedShowTitles.contains(show.title),
      initialComments: show.id == null ? null : commentsByPodcast[show.id!],
      loadComments: show.id == null
          ? null
          : () async => (await api.comments(show.id!))
                .map(
                  (json) => CommentData.fromJson(
                    json,
                    durationSeconds: show.durationSeconds ?? 0,
                  ),
                )
                .toList(),
      displayName: widget.displayName,
      onProgressChanged: (value) {
        progressByShow[show.title] = value;
        if (show.id != null) {
          unawaited(
            api.saveProgress(
              show.id!,
              progressSeconds: ((show.durationSeconds ?? 0) * value).round(),
              completed: value >= .99,
            ),
          );
        }
      },
      onComment: show.id == null
          ? null
          : (text, timestampSeconds) async {
              final saved = await api.createComment(
                show.id!,
                text,
                timestampSeconds: timestampSeconds,
              );
              final comment = CommentData.fromJson(
                saved,
                durationSeconds: show.durationSeconds ?? 0,
              );
              final cached = commentsByPodcast.putIfAbsent(show.id!, () => []);
              cached.removeWhere((item) => item.id == comment.id);
              cached.insert(0, comment);
              return comment;
            },
      onLikedChanged: (value) => updateLiked(show, value),
      onSavedChanged: (value) => updateSaved(show, value),
      onReport: () => _showReport(show),
      onMembership: () => _showMembership(show),
      onCreatorProfile: () => _showCreatorProfile(show),
      onToggle: () => setState(() => playing = !playing),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      Home(
        displayName: widget.displayName,
        onPlay: play,
        onOpen: openShow,
        onSearch: () => setState(() => tab = 1),
        hasUnreadNotifications: notifications.any((item) => !item.read),
        onNotifications: _showNotifications,
        onProfile: () => setState(() => tab = 4),
      ),
      Discover(onOpen: openShow),
      LibraryPage(
        api: api,
        likedTitles: likedShowTitles,
        savedTitles: savedShowTitles,
        onOpen: openShow,
        onOpenCreator: _showCreatorProfile,
      ),
      ListenerWalletPage(
        balance: walletBalance,
        onTopUp: () => setState(() => walletBalance += 200000),
      ),
      Profile(
        displayName: widget.displayName,
        onTheme: widget.onTheme,
        onLogout: widget.onLogout,
        session: widget.session,
        onProfileUpdated: widget.onProfileUpdated,
        onSessionChanged: widget.onSessionRefreshed,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (apiLoading) const LinearProgressIndicator(),
            if (!apiLoading && (apiError != null || usingSamplePodcasts))
              MaterialBanner(
                content: Text(
                  apiError != null ? 'Không tải đầy đủ dữ liệu: $apiError' : 'Chưa có podcast được duyệt. Nội dung mẫu không thể lưu bình luận.',
                ),
                actions: [
                  TextButton(
                    onPressed: _loadListenerFlow,
                    child: const Text('Tải lại'),
                  ),
                ],
              ),
            Expanded(child: pages[tab]),
          ],
        ),
      ),
      bottomNavigationBar: current == null
          ? nav
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiniPlayer(
                  show: current!,
                  playing: playing,
                  onToggle: () => setState(() => playing = !playing),
                  onOpen: openPlayer,
                ),
                nav,
              ],
            ),
    );
  }

  Widget get nav => NavigationBar(
    selectedIndex: tab,
    onDestinationSelected: (i) => setState(() => tab = i),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Trang chu',
      ),
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore),
        label: 'Kham pha',
      ),
      NavigationDestination(
        icon: Icon(Icons.library_music_outlined),
        selectedIcon: Icon(Icons.library_music),
        label: 'Thu vien',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: 'Vi',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Ca nhan',
      ),
    ],
  );

  void _showNotifications() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NotificationPanel(
      notifications: notifications,
      onRead: (id) {
        setState(() {
          final index = notifications.indexWhere((item) => item.id == id);
          if (index >= 0) {
            notifications[index] = notifications[index].copyWith(read: true);
          }
        });
      },
    ),
  );
  void openPlayer() => _showPlayer(current!);
}

class CreatorShell extends StatelessWidget {
  const CreatorShell({
    super.key,
    required this.displayName,
    required this.onTheme,
    required this.onLogout,
  });
  final String displayName;
  final VoidCallback onTheme, onLogout;

  @override
  Widget build(BuildContext context) =>
      CreatorMainShell(onTheme: onTheme, onLogout: onLogout);
}

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.displayName,
    required this.onTheme,
    required this.onLogout,
  });
  final String displayName;
  final VoidCallback onTheme, onLogout;

  @override
  Widget build(BuildContext context) => ActorShell(
    title: 'Admin VietCast',
    pages: [
      const AdminPage(),
      const AlertPage(),
      Profile(displayName: displayName, onTheme: onTheme, onLogout: onLogout),
    ],
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.notifications_none),
        label: 'Thong bao',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Ca nhan'),
    ],
  );
}

class ActorShell extends StatefulWidget {
  const ActorShell({
    super.key,
    required this.title,
    required this.pages,
    required this.destinations,
  });
  final String title;
  final List<Widget> pages;
  final List<NavigationDestination> destinations;

  @override
  State<ActorShell> createState() => _ActorShellState();
}

class _ActorShellState extends State<ActorShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(child: widget.pages[tab]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (index) => setState(() => tab = index),
      destinations: widget.destinations,
    ),
  );
}

class Home extends StatelessWidget {
  const Home({
    super.key,
    required this.displayName,
    required this.onPlay,
    required this.onOpen,
    required this.onSearch,
    required this.hasUnreadNotifications,
    required this.onNotifications,
    required this.onProfile,
  });
  final String displayName;
  final ValueChanged<Show> onPlay;
  final ValueChanged<Show> onOpen;
  final VoidCallback onSearch, onNotifications, onProfile;
  final bool hasUnreadNotifications;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              InkWell(
                onTap: onProfile,
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  backgroundColor: Color(0xFFE0B84A),
                  child: Text(
                    displayName.isEmpty
                        ? '?'
                        : displayName.substring(0, 1).toUpperCase(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chao buoi toi,'),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSearch,
                tooltip: 'Tim kiem',
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: onNotifications,
                tooltip: 'Thong bao',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_none),
                    ),
                    if (hasUnreadNotifications)
                      Positioned(
                        top: 1,
                        right: 1,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(0xFFFBF7F0),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Section(
          title: 'Tiep tuc nghe',
          child: Resume(show: shows[0], onOpen: onOpen),
        ),
      ),
      SliverToBoxAdapter(
        child: Section(
          title: 'Danh cho ban',
          child: SizedBox(
            height: 224,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: shows.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 156,
                child: ShowCard(show: shows[i], onOpen: () => onOpen(shows[i])),
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: TimelineFilter(onOpen: onOpen, onPlay: onPlay),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );
}

class TimelineFilter extends StatefulWidget {
  const TimelineFilter({super.key, required this.onOpen, required this.onPlay});
  final ValueChanged<Show> onOpen;
  final ValueChanged<Show> onPlay;

  @override
  State<TimelineFilter> createState() => _TimelineFilterState();
}

class _TimelineFilterState extends State<TimelineFilter> {
  String selected = '1945 - 1954';
  static const periods = [
    'Tat ca',
    '1858 - 1945',
    '1945 - 1954',
    '1954 - 1975',
    '1975 - 1986',
    '1986 - nay',
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = selected == 'Tat ca'
        ? shows
        : shows.where((show) => show.period == selected).toList();
    return Section(
      title: 'Theo dong thoi gian',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: periods.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final period = periods[index];
                return ChoiceChip(
                  label: Text(period),
                  selected: period == selected,
                  onSelected: (_) => setState(() => selected = period),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          ...filtered.map(
            (show) => Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: ListTile(
                onTap: () => widget.onOpen(show),
                contentPadding: const EdgeInsets.all(10),
                leading: Art(show: show, size: 58),
                title: Text(
                  show.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${show.channel}  •  ${show.duration}'),
                trailing: IconButton(
                  onPressed: () => widget.onPlay(show),
                  tooltip: 'Phat',
                  icon: const Icon(Icons.play_circle_outline),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Chua co podcast trong moc thoi gian nay.'),
            ),
        ],
      ),
    );
  }
}

class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class Resume extends StatelessWidget {
  const Resume({super.key, required this.show, required this.onOpen});
  final Show show;
  final ValueChanged<Show> onOpen;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(show),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Art(show: show, size: 72),
          title: Text(show.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(show.channel),
          trailing: IconButton(
            onPressed: () => onOpen(show),
            tooltip: 'Mo va phat tiep',
            icon: const Icon(Icons.play_circle_filled, size: 38),
          ),
        ),
      ),
    ),
  );
}

class ShowCard extends StatelessWidget {
  const ShowCard({super.key, required this.show, required this.onOpen});
  final Show show;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        children: [
          GestureDetector(
            onTap: onOpen,
            child: Art(show: show, size: 156),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filled(
              onPressed: onOpen,
              tooltip: 'Mo va phat',
              icon: const Icon(Icons.play_arrow),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(show.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      Text(
        show.channel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class Art extends StatelessWidget {
  const Art({super.key, required this.show, required this.size});
  final Show show;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(colors: show.colors),
    ),
    child: Stack(
      children: [
        const Positioned(
          top: 12,
          left: 12,
          child: Icon(Icons.mic_none, color: Colors.white, size: 30),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Text(
            'VIETCAST',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * .075,
            ),
          ),
        ),
        if (show.member)
          const Positioned(
            top: 8,
            right: 8,
            child: Chip(
              label: Text('MEM'),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  );
}

class Discover extends StatefulWidget {
  const Discover({super.key, required this.onOpen});
  final ValueChanged<Show> onOpen;
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  String query = '';
  final searchController = TextEditingController();
  final searchHistory = <String>['lich su Viet Nam', 'Doi Moi', 'Truong Son'];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void search(String value) {
    final next = value.trim();
    setState(() {
      query = next;
      if (next.isNotEmpty) {
        searchHistory.remove(next);
        searchHistory.insert(0, next);
        if (searchHistory.length > 6) searchHistory.removeLast();
      }
    });
  }

  void pickHistory(String value) {
    searchController.text = value;
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
    search(value);
  }

  @override
  Widget build(BuildContext context) {
    final result = shows
        .where(
          (s) => '${s.title} ${s.channel}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Kham pha'), pinned: true),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (v) => setState(() => query = v),
              onSubmitted: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tim podcast, kenh, playlist',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        tooltip: 'Xoa tim kiem',
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
        ),
        if (query.isEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lich su tim kiem',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => setState(() => searchHistory.clear()),
                    child: const Text('Xoa lich su'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: searchHistory.isEmpty
                  ? const Text('Chua co lich su tim kiem.')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: searchHistory
                          .map(
                            (item) => ActionChip(
                              avatar: const Icon(Icons.history, size: 18),
                              label: Text(item),
                              onPressed: () => pickHistory(item),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
              child: Text(
                'Audio goi y',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _AudioResultTile(
                show: shows[i],
                onOpen: () => widget.onOpen(shows[i]),
              ),
              childCount: shows.length,
            ),
          ),
        ] else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '${result.length} audio tim thay',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (result.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Khong tim thay audio phu hop.'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _AudioResultTile(
                  show: result[i],
                  onOpen: () => widget.onOpen(result[i]),
                ),
                childCount: result.length,
              ),
            ),
        ],
      ],
    );
  }
}

class _AudioResultTile extends StatelessWidget {
  const _AudioResultTile({required this.show, required this.onOpen});
  final Show show;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.all(10),
      leading: Art(show: show, size: 64),
      title: Text(show.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${show.channel} • ${show.duration}'),
      trailing: IconButton(
        onPressed: onOpen,
        tooltip: 'Mo va phat',
        icon: const Icon(Icons.play_circle_outline),
      ),
    ),
  );
}

class PlaylistData {
  PlaylistData({
    required this.name,
    required this.description,
    required this.showTitles,
    required this.colors,
    this.isDefault = false,
    this.coverIndex = 0,
  });
  String name;
  String description;
  final List<String> showTitles;
  final List<Color> colors;
  final bool isDefault;
  int coverIndex;
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.api,
    required this.likedTitles,
    required this.savedTitles,
    required this.onOpen,
    required this.onOpenCreator,
  });
  final ListenerApi api;
  final Set<String> likedTitles;
  final Set<String> savedTitles;
  final ValueChanged<Show> onOpen;
  final ValueChanged<Show> onOpenCreator;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String selected = 'liked';
  final customPlaylists = <PlaylistData>[];
  List<Map<String, dynamic>> followedCreators = const [];
  bool loadingCreators = true;

  @override
  void initState() {
    super.initState();
    _loadFollowedCreators();
  }

  Future<void> _loadFollowedCreators() async {
    try {
      final result = await widget.api.follows(size: 100);
      if (!mounted) return;
      setState(() {
        followedCreators = result;
        loadingCreators = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingCreators = false);
    }
  }

  Show _creatorShow(Map<String, dynamic> creator) => Show(
    '${creator['channelName'] ?? 'Content Creator'}',
    '${creator['channelName'] ?? 'Content Creator'}',
    'Creator',
    '',
    const [Color(0xFF254A50), Color(0xFF93B4A4)],
    creatorId: '${creator['creatorProfileId']}',
  );

  List<Show> get liked =>
      shows.where((show) => widget.likedTitles.contains(show.title)).toList();

  PlaylistData get listenLater => PlaylistData(
    name: 'Nghe sau',
    description: 'Nhung podcast ban da luu de nghe sau',
    showTitles: widget.savedTitles.toList(),
    colors: const [Color(0xFF7A3F31), Color(0xFFE0B84A)],
    isDefault: true,
  );

  List<PlaylistData> get allPlaylists => [listenLater, ...customPlaylists];

  Future<void> createPlaylist() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tao playlist moi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ten playlist'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Mo ta'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              nameController.text.trim(),
              descriptionController.text.trim(),
            )),
            child: const Text('Tao playlist'),
          ),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (!mounted || result == null || result.$1.isEmpty) return;
    setState(() {
      customPlaylists.add(
        PlaylistData(
          name: result.$1,
          description: result.$2.isEmpty
              ? 'Playlist ca nhan cua ban'
              : result.$2,
          showTitles: widget.savedTitles.toList(),
          colors: const [Color(0xFF254A50), Color(0xFF93B4A4)],
        ),
      );
    });
  }

  Future<void> openPlaylist(PlaylistData playlist) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlaylistDetailScreen(playlist: playlist, onOpen: widget.onOpen),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      const SliverAppBar(title: Text('Thu vien'), pinned: true),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'liked', label: Text('Da thich')),
              ButtonSegment(value: 'playlist', label: Text('Playlist')),
              ButtonSegment(value: 'creators', label: Text('Content Creator')),
            ],
            selected: {selected},
            onSelectionChanged: (value) =>
                setState(() => selected = value.first),
          ),
        ),
      ),
      if (selected == 'liked') ...[
        if (liked.isEmpty)
          const SliverToBoxAdapter(child: PlaylistEmptyState(kind: 'liked'))
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, index) => _LikedAudioTile(
                show: liked[index],
                onOpen: () => widget.onOpen(liked[index]),
              ),
              childCount: liked.length,
            ),
          ),
      ] else if (selected == 'playlist') ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Playlist cua ban',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.tonalIcon(
                  onPressed: createPlaylist,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tao moi'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: PlaylistList(playlists: allPlaylists, onOpen: openPlaylist),
        ),
      ] else ...[
        if (loadingCreators)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (followedCreators.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text('Ban chua theo doi Content Creator nao.'),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((_, index) {
              final creator = followedCreators[index];
              final show = _creatorShow(creator);
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: show.colors.first,
                    child: const Icon(Icons.mic, color: Colors.white),
                  ),
                  title: Text(show.channel),
                  subtitle: Text(
                    '${creator['description'] ?? 'Content Creator VietCast'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onOpenCreator(show),
                ),
              );
            }, childCount: followedCreators.length),
          ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );
}

class PlaylistList extends StatelessWidget {
  const PlaylistList({
    super.key,
    required this.playlists,
    required this.onOpen,
  });
  final List<PlaylistData> playlists;
  final ValueChanged<PlaylistData> onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: playlists
          .map(
            (playlist) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PlaylistCard(
                playlist: playlist,
                onTap: () => onOpen(playlist),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, required this.onTap});
  final PlaylistData playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PlaylistArtwork(playlist: playlist, size: 76),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.showTitles.length} podcast',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              tooltip: 'Mo playlist',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    ),
  );
}

class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork({
    super.key,
    required this.playlist,
    required this.size,
  });
  final PlaylistData playlist;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        colors: playlist.coverIndex.isEven
            ? playlist.colors
            : playlist.colors.reversed.toList(),
      ),
    ),
    child: const Icon(Icons.queue_music, color: Colors.white, size: 30),
  );
}

class PlaylistEmptyState extends StatelessWidget {
  const PlaylistEmptyState({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 80, 32, 40),
    child: Column(
      children: [
        Icon(
          kind == 'liked' ? Icons.favorite_border : Icons.queue_music,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          kind == 'liked'
              ? 'Chua co audio yeu thich'
              : 'Playlist nay chua co podcast',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Kham pha podcast moi va luu lai de nghe sau.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () {},
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Kham pha podcast'),
        ),
      ],
    ),
  );
}

class _LikedAudioTile extends StatelessWidget {
  const _LikedAudioTile({required this.show, required this.onOpen});
  final Show show;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.all(10),
      leading: Art(show: show, size: 64),
      title: Text(show.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${show.channel}  •  ${show.duration}'),
      trailing: IconButton(
        onPressed: onOpen,
        icon: const Icon(Icons.play_circle_outline),
      ),
    ),
  );
}

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.onOpen,
  });
  final PlaylistData playlist;
  final ValueChanged<Show> onOpen;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Show> get playlistShows => widget.playlist.showTitles
      .map((title) => shows.where((show) => show.title == title).firstOrNull)
      .whereType<Show>()
      .toList();

  String get totalDuration {
    final minutes = playlistShows.fold<int>(0, (sum, show) {
      final parts = show.duration.split(':');
      return sum + (int.tryParse(parts.first) ?? 0);
    });
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  Future<void> editPlaylist() async {
    final nameController = TextEditingController(text: widget.playlist.name);
    final descriptionController = TextEditingController(
      text: widget.playlist.description,
    );
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chinh sua playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Ten playlist'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Mo ta'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              nameController.text.trim(),
              descriptionController.text.trim(),
            )),
            child: const Text('Luu'),
          ),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (!mounted || result == null || result.$1.isEmpty) return;
    setState(() {
      widget.playlist.name = result.$1;
      widget.playlist.description = result.$2;
    });
  }

  void removeAt(int index) => setState(() {
    widget.playlist.showTitles.removeAt(index);
  });

  void reorder(int oldIndex, int newIndex) => setState(() {
    final title = widget.playlist.showTitles.removeAt(oldIndex);
    widget.playlist.showTitles.insert(newIndex, title);
  });

  @override
  Widget build(BuildContext context) {
    final items = playlistShows;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          if (!widget.playlist.isDefault)
            IconButton(
              onPressed: editPlaylist,
              tooltip: 'Chinh sua playlist',
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      PlaylistArtwork(playlist: widget.playlist, size: 120),
                      if (!widget.playlist.isDefault)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: IconButton.filledTonal(
                            onPressed: () => setState(
                              () => widget.playlist.coverIndex =
                                  (widget.playlist.coverIndex + 1) % 4,
                            ),
                            tooltip: 'Doi anh bia',
                            icon: const Icon(Icons.image_outlined, size: 18),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playlist.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(widget.playlist.description),
                        const SizedBox(height: 8),
                        Text(
                          '${items.length} podcast  •  $totalDuration',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: items.isEmpty
                          ? null
                          : () => widget.onOpen(items.first),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Phat tat ca'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: items.isEmpty
                        ? null
                        : () {
                            final shuffled = [...items]..shuffle();
                            widget.onOpen(shuffled.first);
                          },
                    tooltip: 'Phat ngau nhien',
                    icon: const Icon(Icons.shuffle),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            const SliverToBoxAdapter(
              child: PlaylistEmptyState(kind: 'playlist'),
            )
          else
            SliverReorderableList(
              itemCount: items.length,
              itemBuilder: (_, index) {
                final show = items[index];
                return Card(
                  key: ValueKey('${widget.playlist.name}-${show.title}'),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Art(show: show, size: 56),
                    ),
                    title: Text(
                      show.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${show.channel}  •  ${show.duration}'),
                    onTap: () => widget.onOpen(show),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'remove') removeAt(index);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Xoa khoi playlist'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              onReorderItem: reorder,
            ),
        ],
      ),
    );
  }
}

class AlertPage extends StatelessWidget {
  const AlertPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thong bao')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.mic_none),
          title: Text('Su Viet ke chuyen da dang tap moi'),
          subtitle: Text('12 phut truoc'),
        ),
        ListTile(
          leading: Icon(Icons.workspace_premium_outlined),
          title: Text('Ban da tro thanh thanh vien'),
          subtitle: Text('Hom qua'),
        ),
        ListTile(
          leading: Icon(Icons.favorite_border),
          title: Text('Lan Anh da thich binh luan cua ban'),
          subtitle: Text('2 ngay truoc'),
        ),
      ],
    ),
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.read = false,
  });
  final String id, title, subtitle;
  final IconData icon;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    subtitle: subtitle,
    icon: icon,
    read: read ?? this.read,
  );
}

class NotificationPanel extends StatefulWidget {
  const NotificationPanel({
    super.key,
    required this.notifications,
    required this.onRead,
  });
  final List<AppNotification> notifications;
  final ValueChanged<String> onRead;

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  void markRead(AppNotification item) {
    if (!item.read) {
      widget.onRead(item.id);
      setState(() {});
    }
  }

  Widget section(String title, List<AppNotification> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Khong co thong bao.',
            style: TextStyle(color: Colors.white60),
          ),
        )
      else
        ...items.map(
          (item) => InkWell(
            onTap: () => markRead(item),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.read ? Colors.white10 : const Color(0x33FF6B1A),
                border: Border.all(
                  color: item.read ? Colors.white12 : const Color(0x88FF6B1A),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: item.read
                        ? Colors.white12
                        : const Color(0xFFFF6B1A),
                    foregroundColor: Colors.white,
                    child: Icon(item.icon, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: item.read
                                ? FontWeight.w500
                                : FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!item.read)
                    const Icon(Icons.circle, color: Colors.deepOrange, size: 9),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final unread = widget.notifications.where((item) => !item.read).toList();
    final read = widget.notifications.where((item) => item.read).toList();
    return DraggableScrollableSheet(
      initialChildSize: .7,
      minChildSize: .2,
      maxChildSize: .92,
      shouldCloseOnMinExtent: true,
      builder: (_, controller) => Material(
        color: const Color(0xFF181818),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  color: Colors.white,
                  tooltip: 'Ve trang chu',
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                const Text(
                  'Thong bao',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    for (final item in unread) {
                      widget.onRead(item.id);
                    }
                    setState(() {});
                  },
                  color: Colors.white,
                  tooltip: 'Danh dau da doc',
                  icon: const Icon(Icons.done_all),
                ),
              ],
            ),
            section('Chua doc', unread),
            section('Da doc', read),
          ],
        ),
      ),
    );
  }
}

class ListenerWalletPage extends StatelessWidget {
  const ListenerWalletPage({
    super.key,
    required this.balance,
    required this.onTopUp,
  });
  final int balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Vi cua ban',
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('So du VietCast'),
              Text(
                _formatVnd(balance),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text('Dung de ung ho creator va dang ky membership'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onTopUp,
                icon: const Icon(Icons.add_card),
                label: const Text('Nap tien'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Giao dich gan day'),
      const Transaction(
        title: 'Membership VietCast Originals',
        amount: '-79.000 VND',
      ),
      const Transaction(title: 'Nap tien vao vi', amount: '+200.000 VND'),
    ],
  );
}

class Profile extends StatelessWidget {
  const Profile({
    super.key,
    required this.displayName,
    required this.onTheme,
    required this.onLogout,
    this.session,
    this.onProfileUpdated,
    this.onSessionChanged,
  });
  final String displayName;
  final VoidCallback onTheme;
  final VoidCallback onLogout;
  final AuthSession? session;
  final ValueChanged<AuthUser>? onProfileUpdated;
  final ValueChanged<AuthSession>? onSessionChanged;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ca nhan')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: Color(0xFFE0B84A),
          child: Text(
            displayName.isEmpty
                ? '?'
                : displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const Center(child: Text('Nguoi nghe lich su Viet Nam')),
        const SizedBox(height: 20),
        Setting(
          icon: Icons.account_circle_outlined,
          title: 'Ho so cua toi',
          subtitle: 'Xem va chinh sua thong tin, doi mat khau',
          onTap: session == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileEditor(
                      session: session!,
                      onProfileUpdated: onProfileUpdated,
                      onSessionChanged: onSessionChanged,
                    ),
                  ),
                ),
        ),
        Setting(
          icon: Icons.mic_rounded,
          title: 'Dang ky lam Creator',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreatorRegistrationScreen(),
            ),
          ),
        ),
        Setting(
          icon: Icons.dark_mode_outlined,
          title: 'Giao dien toi',
          onTap: onTheme,
        ),
        Setting(icon: Icons.logout, title: 'Dang xuat', onTap: onLogout),
      ],
    ),
  );
}

class Setting extends StatelessWidget {
  const Setting({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.session,
    this.onProfileUpdated,
    this.onSessionChanged,
  });

  final AuthSession session;
  final ValueChanged<AuthUser>? onProfileUpdated;
  final ValueChanged<AuthSession>? onSessionChanged;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final displayNameController = TextEditingController(
    text: widget.session.user.displayName,
  );
  late final bioController = TextEditingController(
    text: widget.session.user.bio,
  );
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool savingProfile = false;
  bool changingPassword = false;
  bool obscureCurrent = true;
  bool obscureNew = true;

  @override
  void dispose() {
    displayNameController.dispose();
    bioController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  Future<void> _saveProfile() async {
    _message('API hien tai chua cung cap endpoint cap nhat ho so.');
  }

  Future<void> _changePassword() async {
    _message('API hien tai chua cung cap endpoint doi mat khau.');
  }

  InputDecoration _decoration(String label, {Widget? suffix}) =>
      InputDecoration(labelText: label, suffixIcon: suffix);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ho so cua toi')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Thong tin ca nhan',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: displayNameController,
          decoration: _decoration('Ten hien thi'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: widget.session.user.username,
          readOnly: true,
          decoration: _decoration('Username'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: widget.session.user.email,
          readOnly: true,
          decoration: _decoration('Email'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: bioController,
          maxLines: 3,
          decoration: _decoration('Gioi thieu'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: savingProfile ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(savingProfile ? 'Dang luu...' : 'Luu thay doi'),
          ),
        ),
        const Divider(height: 40),
        Text('Bao mat', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: currentPasswordController,
          obscureText: obscureCurrent,
          decoration: _decoration(
            'Mat khau hien tai',
            suffix: IconButton(
              icon: Icon(
                obscureCurrent
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: newPasswordController,
          obscureText: obscureNew,
          decoration: _decoration(
            'Mat khau moi',
            suffix: IconButton(
              icon: Icon(
                obscureNew
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => obscureNew = !obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: obscureNew,
          decoration: _decoration('Xac nhan mat khau moi'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: changingPassword ? null : _changePassword,
            icon: const Icon(Icons.lock_reset_outlined),
            label: Text(changingPassword ? 'Dang cap nhat...' : 'Doi mat khau'),
          ),
        ),
      ],
    ),
  );
}

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});
  final ValueChanged<Account> onAuthenticated;
  @override
  ConsumerState<AuthPage> createState() => _AuthState();
}

class _AuthState extends ConsumerState<AuthPage> {
  bool register = false;
  bool loading = false;
  final usernameController = TextEditingController();
  final displayNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  String? error;
  final authApi = AuthApi();

  @override
  void dispose() {
    usernameController.dispose();
    displayNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  UserRole _roleFromApi(String role) => switch (role) {
    'ADMIN' => UserRole.admin,
    'CREATOR' => UserRole.creator,
    _ => UserRole.listener,
  };

  void _completeLogin(AuthSession session) {
    widget.onAuthenticated(
      Account(
        email: session.user.email,
        name: session.user.displayName,
        role: _roleFromApi(session.user.role),
        session: session,
      ),
    );
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (register) {
        final username = usernameController.text.trim();
        final displayName = displayNameController.text.trim();
        final email = emailController.text.trim();
        if (username.length < 3 || displayName.isEmpty || email.isEmpty) {
          throw const ApiException(
            'Vui long dien day du thong tin dang ky.',
            400,
          );
        }
        await authApi.register(
          username: username,
          email: email,
          password: passwordController.text,
          displayName: displayName,
        );
        final session = await authApi.login(
          identifier: username,
          password: passwordController.text,
        );
        _completeLogin(session);
      } else {
        final session = await authApi.login(
          identifier: emailController.text.trim(),
          password: passwordController.text,
        );
        _completeLogin(session);
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Khong the ket noi den may chu API.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: register ? 'Dang ky VietCast' : 'Dang nhap VietCast',
    children: [
      const Icon(Icons.mic_external_on, size: 56, color: Color(0xFFB3261E)),
      Text(
        register ? 'Tao tai khoan VietCast' : 'Chao mung ban tro lai',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 20),
      if (register) ...[
        TextField(
          controller: usernameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: displayNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Ten hien thi'),
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: emailController,
        keyboardType: register
            ? TextInputType.emailAddress
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: register ? 'Email' : 'Username hoac email',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        decoration: InputDecoration(
          labelText: 'Mat khau',
          suffixIcon: IconButton(
            tooltip: obscurePassword ? 'Hien mat khau' : 'An mat khau',
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => obscurePassword = !obscurePassword),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 8),
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (register) ...[
        const SizedBox(height: 16),
        const Text('Chu de quan tam'),
        Wrap(
          spacing: 8,
          children: ['Khang Phap', 'Nhan vat', 'Doi Moi', 'Doi song']
              .map(
                (x) => FilterChip(
                  label: Text(x),
                  selected: x == 'Nhan vat',
                  onSelected: (_) {},
                ),
              )
              .toList(),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: loading ? null : submit,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(register ? 'Dang ky' : 'Dang nhap'),
      ),
      TextButton(
        onPressed: () => setState(() => register = !register),
        child: Text(register ? 'Da co tai khoan?' : 'Chua co tai khoan?'),
      ),
    ],
  );
}

class CreatorPage extends StatelessWidget {
  const CreatorPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Creator Studio',
    children: [
      Text('Dashboard CC', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      const Row(
        children: [
          Metric(label: 'Luot nghe', value: '24,8K'),
          Metric(label: 'Doanh thu', value: '4,2M'),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (_) => const UploadSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Dang podcast'),
      ),
      const SizedBox(height: 16),
      ...shows
          .take(3)
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Art(show: s, size: 56),
              title: Text(s.title),
              subtitle: Text('Da dang • ${s.duration}'),
              trailing: const Chip(label: Text('Da dang')),
            ),
          ),
    ],
  );
}

class UploadSheet extends StatelessWidget {
  const UploadSheet({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tao podcast moi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const TextField(decoration: InputDecoration(labelText: 'Tieu de')),
        const SizedBox(height: 12),
        const TextField(
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Mo ta'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.audio_file),
          label: const Text('Chon file am thanh'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Luu ban nhap'),
        ),
      ],
    ),
  );
}

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});
  @override
  State<RequestPage> createState() => _RequestState();
}

class _RequestState extends State<RequestPage> {
  int state = 2;
  final stages = ['DRAFT', 'SENT', 'ACCEPTED', 'IN_PRODUCTION', 'DELIVERED'];
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Yeu cau podcast',
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ke chuyen ve Doi Moi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Ngan sach 2.500.000 VND • Han 28/10/2026'),
              const SizedBox(height: 12),
              ...List.generate(
                stages.length,
                (i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    i <= state
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: i <= state ? Colors.green : null,
                  ),
                  title: Text(stages[i]),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Buoc tiep theo: CC dang hoan thien ban nhap',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      FilledButton.icon(
        onPressed: () =>
            setState(() => state = state < stages.length - 1 ? state + 1 : 0),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Cap nhat trang thai'),
      ),
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.chat_outlined),
        label: const Text('Mo chat'),
      ),
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Tao yeu cau moi'),
      ),
    ],
  );
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletState();
}

class _WalletState extends State<WalletPage> {
  bool pending = false;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Vi Creator',
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('So du kha dung'),
              Text(
                '12.450.000 VND',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text('Dang cho release: 3.200.000 VND'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: pending
                    ? null
                    : () => setState(() => pending = true),
                icon: const Icon(Icons.account_balance),
                label: Text(pending ? 'Dang xu ly...' : 'Rut tien'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Transaction(
        title: 'Release yeu cau podcast',
        amount: '+1.500.000 VND',
      ),
      const Transaction(title: 'Membership thang 10', amount: '+350.000 VND'),
      const Transaction(title: 'Rut ve ngan hang', amount: '-2.000.000 VND'),
    ],
  );
}

class Transaction extends StatelessWidget {
  const Transaction({super.key, required this.title, required this.amount});
  final String title, amount;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.receipt_long_outlined),
    title: Text(title),
    subtitle: const Text('Dang xu ly'),
    trailing: Text(amount),
  );
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Admin',
    children: [
      const Row(
        children: [
          Metric(label: 'Cho duyet', value: '18'),
          Metric(label: 'Bao cao', value: '7'),
        ],
      ),
      const SizedBox(height: 20),
      const Text('Hang doi kiem duyet'),
      ...[
        'Nhung ngay dau cua nen doc lap',
        'Tu lieu Doi Moi 1986',
        'Nhan vat Nguyen An Ninh',
      ].map(
        (x) => Card(
          child: ListTile(
            title: Text(x),
            subtitle: const Text('AI score 92% • Cho Admin duyet'),
            trailing: Wrap(
              children: [
                IconButton(
                  onPressed: () {},
                  tooltip: 'Duyet',
                  icon: const Icon(Icons.check, color: Colors.green),
                ),
                IconButton(
                  onPressed: () {},
                  tooltip: 'Tu choi',
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});
  @override
  State<MembershipPage> createState() => _MembershipState();
}

class _MembershipState extends State<MembershipPage> {
  bool paid = false;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Membership kenh',
    children: [
      const CircleAvatar(
        radius: 34,
        backgroundColor: Color(0xFFB8860B),
        child: Icon(Icons.workspace_premium, color: Colors.white),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'VietCast Originals',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goi Nguoi ke chuyen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('79.000 VND / thang'),
              const SizedBox(height: 12),
              const Text(
                'Noi dung doc quyen\nGui yeu cau podcast\nBadge thanh vien',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: paid ? null : () => setState(() => paid = true),
                child: Text(paid ? 'Da la thanh vien' : 'Dang ky membership'),
              ),
            ],
          ),
        ),
      ),
      if (paid) const Chip(label: Text('Thanh toan thanh cong')),
    ],
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(padding: const EdgeInsets.all(16), children: children),
  );
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.show,
    required this.playing,
    required this.onToggle,
    required this.onOpen,
  });
  final Show show;
  final bool playing;
  final VoidCallback onToggle, onOpen;
  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    child: InkWell(
      onTap: onOpen,
      child: Column(
        children: [
          const LinearProgressIndicator(value: .42, minHeight: 2),
          ListTile(
            leading: Art(show: show, size: 48),
            title: Text(
              show.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(show.channel),
            trailing: IconButton(
              onPressed: onToggle,
              tooltip: playing ? 'Tam dung' : 'Phat',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ],
      ),
    ),
  );
}

class Player extends StatefulWidget {
  const Player({
    super.key,
    required this.show,
    required this.displayName,
    required this.playing,
    required this.initialProgress,
    required this.initialLiked,
    required this.initialSaved,
    this.initialComments,
    this.loadComments,
    required this.onProgressChanged,
    this.onComment,
    required this.onLikedChanged,
    required this.onSavedChanged,
    required this.onReport,
    required this.onMembership,
    required this.onCreatorProfile,
    required this.onToggle,
  });
  final Show show;
  final String displayName;
  final bool playing;
  final double initialProgress;
  final bool initialLiked, initialSaved;
  final List<CommentData>? initialComments;
  final Future<List<CommentData>> Function()? loadComments;
  final ValueChanged<double> onProgressChanged;
  final Future<CommentData> Function(String, int)? onComment;
  final ValueChanged<bool> onLikedChanged, onSavedChanged;
  final VoidCallback onReport, onMembership, onCreatorProfile;
  final VoidCallback onToggle;

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late bool playing = widget.playing;
  late double progress = widget.initialProgress;
  late bool liked = widget.initialLiked;
  final commentController = TextEditingController();
  late final comments = List<CommentData>.of(
    widget.initialComments ?? const [],
  );
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadComments());
  }

  Future<void> _loadComments() async {
    final load = widget.loadComments;
    if (load == null) return;
    final idsAtStart = comments.map((comment) => comment.id).toSet();
    try {
      final loaded = await load();
      if (!mounted) return;
      setState(() {
        final ids = loaded.map((c) => c.id).toSet();
        final recent = comments
            .where(
              (c) =>
                  c.id != null &&
                  !idsAtStart.contains(c.id) &&
                  !ids.contains(c.id),
            )
            .toList();
        comments
          ..clear()
          ..addAll([...recent, ...loaded]);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được bình luận: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    widget.onProgressChanged(progress);
    commentController.dispose();
    super.dispose();
  }

  void setProgress(double value) {
    final next = value.clamp(0.0, 1.0);
    setState(() => progress = next);
    widget.onProgressChanged(next);
  }

  void seekBy(double amount) {
    setProgress(progress + amount);
  }

  Future<void> submitComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;
    if (await addComment(text) &&
        mounted &&
        commentController.text.trim() == text) {
      commentController.clear();
    }
  }

  Future<bool> addComment(String text) async {
    if (_sendingComment || text.trim().isEmpty) return false;
    final send = widget.onComment;
    if (send == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Podcast mẫu chưa có ID trên server. Hãy chọn podcast đã được duyệt từ backend.',
          ),
        ),
      );
      return false;
    }
    final seconds = (progress * _durationSeconds).floor();
    setState(() => _sendingComment = true);
    try {
      final saved = await send(text.trim(), seconds);
      if (!mounted) return false;
      setState(() {
        comments.removeWhere((comment) => comment.id == saved.id);
        comments.insert(0, saved);
      });
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chưa lưu được bình luận: $error')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  int get _durationSeconds {
    if (widget.show.durationSeconds != null) {
      return widget.show.durationSeconds!;
    }
    return widget.show.duration
        .split(':')
        .fold<int>(0, (total, part) => total * 60 + (int.tryParse(part) ?? 0));
  }

  String get _timestamp {
    final seconds = (progress * _durationSeconds).floor();
    return _formatDuration(seconds);
  }

  String _formatDuration(num seconds) {
    final wholeSeconds = seconds.round();
    return '${(wholeSeconds ~/ 60).toString().padLeft(2, '0')}:${(wholeSeconds % 60).toString().padLeft(2, '0')}';
  }

  CommentData? get timelineComment {
    final nearby = comments
        .where(
          (comment) =>
              comment.time.isNotEmpty &&
              (comment.position - progress).abs() <= .04,
        )
        .toList();
    if (nearby.isEmpty) return null;
    // Comments are inserted newest-first, so the first one wins when a
    // timestamp has multiple comments in the same time window.
    return nearby.first;
  }

  void _showComments() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF181818),
    builder: (_) => CommentsPanel(comments: comments, onSubmit: addComment),
  );

  void _showPlaylist() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFF181818),
    builder: (_) => PlaylistPanel(
      initialSaved: widget.initialSaved,
      onChanged: widget.onSavedChanged,
    ),
  );

  void _showShare() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Chia se podcast'),
      content: SelectableText(
        'https://vietcast.local/podcast/${widget.show.title.toLowerCase().replaceAll(' ', '-')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dong'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Da sao chep duong dan chia se.')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Sao chep'),
        ),
      ],
    ),
  );

  void _showMore() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFF181818),
    builder: (_) => MorePanel(
      show: widget.show,
      onReport: widget.onReport,
      onMembership: widget.onMembership,
      onCreatorProfile: widget.onCreatorProfile,
    ),
  );

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .9,
    minChildSize: .2,
    maxChildSize: .96,
    shouldCloseOnMinExtent: true,
    builder: (_, controller) => Material(
      color: const Color(0xFF111111),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.show.colors.first.withAlpha(125),
              const Color(0xFF202126),
              widget.show.colors.last.withAlpha(95),
            ],
          ),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Thu nho',
                  color: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                const Text(
                  'Dang phat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  tooltip: 'Them tuy chon',
                  color: Colors.white,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Art(show: widget.show, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.show.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.show.channel,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _timestamp,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('|', style: TextStyle(color: Colors.white38)),
                ),
                Text(
                  _formatDuration(_durationSeconds),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTapDown: (details) => setProgress(
                      details.localPosition.dx / constraints.maxWidth,
                    ),
                    onPanUpdate: (details) => setProgress(
                      details.localPosition.dx / constraints.maxWidth,
                    ),
                    child: Waveform(progress: progress),
                  ),
                  if (timelineComment != null)
                    Positioned(
                      left: (constraints.maxWidth * timelineComment!.position)
                          .clamp(4.0, constraints.maxWidth - 210),
                      top: 4,
                      child: CommentMarker(comment: timelineComment!),
                    ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFF6B1A),
                inactiveTrackColor: Colors.white30,
                thumbColor: Colors.white,
                overlayColor: const Color(0x33FF6B1A),
                trackHeight: 3,
              ),
              child: Slider(
                value: progress,
                min: 0,
                max: 1,
                onChanged: setProgress,
                semanticFormatterCallback: (value) =>
                    'Vi tri phat ${_formatDuration(value * _durationSeconds)}',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => seekBy(-.05),
                  color: Colors.white,
                  icon: const Icon(Icons.replay_10),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    fixedSize: const Size(58, 58),
                  ),
                  onPressed: () {
                    setState(() => playing = !playing);
                    widget.onToggle();
                  },
                  tooltip: playing ? 'Tam dung' : 'Phat',
                  icon: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                ),
                IconButton(
                  onPressed: () => seekBy(.05),
                  color: Colors.white,
                  icon: const Icon(Icons.forward_10),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CommentComposer(
              controller: commentController,
              onSubmit: submitComment,
              sending: _sendingComment,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PlayerAction(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  label: liked ? '17.1K' : '17K',
                  active: liked,
                  onTap: () {
                    setState(() => liked = !liked);
                    widget.onLikedChanged(liked);
                  },
                ),
                _PlayerAction(
                  icon: Icons.chat_bubble_outline,
                  label: '${comments.length + 464}',
                  onTap: _showComments,
                ),
                _PlayerAction(
                  icon: Icons.ios_share,
                  label: 'Chia se',
                  onTap: _showShare,
                ),
                _PlayerAction(
                  icon: Icons.playlist_add,
                  label: 'Luu',
                  onTap: _showPlaylist,
                ),
                _PlayerAction(
                  icon: Icons.more_horiz,
                  label: 'Them',
                  onTap: _showMore,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white24),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Binh luan theo thoi gian',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...comments.map(
              (comment) => Comment(
                name: comment.name,
                text: comment.text,
                time: comment.time,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.onSubmit,
    this.sending = false,
  });
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool sending;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(70),
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !sending,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Comment...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF191717),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: const BorderSide(color: Color(0xFF5A504B)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: const BorderSide(color: Color(0xFF5A504B)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: const BorderSide(color: Color(0xFFB3261E)),
              ),
              isDense: true,
            ),
          ),
        ),
        for (final emoji in ['🔥', '👏', '🥹'])
          InkWell(
            onTap: () {
              controller.text = '${controller.text}$emoji';
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
        IconButton(
          onPressed: sending ? null : onSubmit,
          tooltip: 'Gui binh luan',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.send_rounded, size: 18),
        ),
      ],
    ),
  );
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Icon(icon, color: active ? Colors.redAccent : Colors.white, size: 25),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class CommentData {
  const CommentData(
    this.name,
    this.text,
    this.time, {
    this.id,
    this.durationSeconds = 1920,
  });
  final String name, text, time;
  final String? id;
  final int durationSeconds;

  factory CommentData.fromJson(
    Map<String, dynamic> json, {
    required int durationSeconds,
  }) {
    final id = json['commentId']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('Server không trả về ID bình luận đã lưu.');
    }
    final seconds = (json['timestampSeconds'] as num?)?.toInt();
    final time = seconds == null
        ? ''
        : '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return CommentData(
      '${json['displayName'] ?? json['username'] ?? 'Listener'}',
      '${json['content'] ?? ''}',
      time,
      id: id,
      durationSeconds: durationSeconds,
    );
  }

  double get position {
    final parts = time.split(':');
    final seconds = parts.fold<int>(
      0,
      (total, part) => total * 60 + (int.tryParse(part) ?? 0),
    );
    return durationSeconds <= 0
        ? 0
        : (seconds / durationSeconds).clamp(0.0, 1.0);
  }
}

class CommentMarker extends StatelessWidget {
  const CommentMarker({super.key, required this.comment});
  final CommentData comment;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 204),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF45484D),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
    ),
    child: Text(
      comment.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

class CommentsPanel extends StatefulWidget {
  const CommentsPanel({
    super.key,
    required this.comments,
    required this.onSubmit,
  });
  final List<CommentData> comments;
  final Future<bool> Function(String) onSubmit;

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool sending = false;

  Future<void> submit() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final saved = await widget.onSubmit(text);
      if (saved && mounted && controller.text.trim() == text) {
        controller.clear();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        8,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Binh luan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 310),
            child: ListView(
              shrinkWrap: true,
              children: widget.comments
                  .map(
                    (comment) => Comment(
                      name: comment.name,
                      text: comment.text,
                      time: comment.time,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          _CommentComposer(
            controller: controller,
            onSubmit: submit,
            sending: sending,
          ),
        ],
      ),
    ),
  );
}

class PlaylistPanel extends StatefulWidget {
  const PlaylistPanel({
    super.key,
    required this.initialSaved,
    required this.onChanged,
  });
  final bool initialSaved;
  final ValueChanged<bool> onChanged;

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel> {
  late bool favorites = widget.initialSaved;
  bool listenLater = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ListTile(
          title: Text(
            'Luu vao playlist',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        CheckboxListTile(
          value: favorites,
          onChanged: (value) {
            final next = value ?? false;
            setState(() => favorites = next);
            widget.onChanged(next);
          },
          activeColor: Colors.deepOrange,
          title: const Text(
            'Podcast yeu thich',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Playlist ca nhan',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        CheckboxListTile(
          value: listenLater,
          onChanged: (value) {
            final next = value ?? false;
            setState(() => listenLater = next);
            widget.onChanged(next);
          },
          activeColor: Colors.deepOrange,
          title: const Text('Nghe sau', style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            'Luu de quay lai sau',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.add, color: Colors.white),
          title: const Text(
            'Tao playlist moi',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 10),
      ],
    ),
  );
}

class ReportPanel extends StatefulWidget {
  const ReportPanel({super.key, required this.show, required this.onSubmitted});
  final Show show;
  final ValueChanged<String> onSubmitted;

  @override
  State<ReportPanel> createState() => _ReportPanelState();
}

class _ReportPanelState extends State<ReportPanel> {
  String reason = 'Noi dung sai su that';
  final customController = TextEditingController();
  static const reasons = [
    'Noi dung sai su that',
    'Vi pham ban quyen',
    'Ngon tu khong phu hop',
    'Spam hoac quang cao',
    'Khac',
  ];

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  void submit() {
    final report = reason == 'Khac' ? customController.text.trim() : reason;
    if (report.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui long nhap noi dung bao cao.')),
      );
      return;
    }
    widget.onSubmitted(report);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bao cao podcast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.show.title,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reasons
                .map(
                  (item) => ChoiceChip(
                    label: Text(item),
                    selected: item == reason,
                    onSelected: (_) => setState(() => reason = item),
                  ),
                )
                .toList(),
          ),
          if (reason == 'Khac') ...[
            const SizedBox(height: 12),
            TextField(
              controller: customController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Viet noi dung ban muon bao cao cho admin...',
                hintStyle: TextStyle(color: Colors.white60),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.send),
              label: const Text('Gui bao cao cho admin'),
            ),
          ),
        ],
      ),
    ),
  );
}

class CreatorProfilePanel extends StatefulWidget {
  const CreatorProfilePanel({
    super.key,
    required this.show,
    required this.api,
    required this.onMembership,
    required this.onOpen,
  });
  final Show show;
  final ListenerApi api;
  final VoidCallback onMembership;
  final ValueChanged<Show> onOpen;

  @override
  State<CreatorProfilePanel> createState() => _CreatorProfilePanelState();
}

class _CreatorProfilePanelState extends State<CreatorProfilePanel> {
  bool following = false;
  bool loadingFollow = true;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final creatorId = widget.show.creatorId;
    if (creatorId == null) {
      if (mounted) setState(() => loadingFollow = false);
      return;
    }
    try {
      final follows = await widget.api.follows(size: 100);
      if (!mounted) return;
      setState(() {
        following = follows.any(
          (item) => '${item['creatorProfileId']}' == creatorId,
        );
        loadingFollow = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingFollow = false);
    }
  }

  Future<void> _toggleFollow() async {
    final creatorId = widget.show.creatorId;
    if (creatorId == null || loadingFollow) return;
    setState(() => loadingFollow = true);
    try {
      if (following) {
        await widget.api.unfollow(creatorId);
      } else {
        await widget.api.follow(creatorId);
      }
      if (!mounted) return;
      setState(() {
        following = !following;
        loadingFollow = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            following ? 'Da theo doi creator.' : 'Da bo theo doi creator.',
          ),
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      setState(() => loadingFollow = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khong the cap nhat theo doi: $exception')),
      );
    }
  }

  Future<void> _showRequestDialog() async {
    final creatorId = widget.show.creatorId;
    if (creatorId == null) return;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var sending = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Gửi yêu cầu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gửi ý tưởng podcast đến ${widget.show.channel}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    enabled: !sending,
                    maxLength: 220,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Chủ đề yêu cầu',
                      hintText: 'Ví dụ: Lịch sử thành nhà Hồ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    enabled: !sending,
                    maxLength: 10000,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả yêu cầu',
                      hintText: 'Bạn muốn creator thực hiện nội dung gì?',
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton.icon(
                onPressed: sending
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final description = descriptionController.text.trim();
                        if (title.isEmpty || description.isEmpty) {
                          setDialogState(() {
                            errorMessage =
                                'Vui lòng nhập đầy đủ chủ đề và mô tả.';
                          });
                          return;
                        }
                        setDialogState(() {
                          sending = true;
                          errorMessage = null;
                        });
                        try {
                          await widget.api.createSeriesRequest(
                            creatorId,
                            requestedTitle: title,
                            description: description,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (exception) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            sending = false;
                            errorMessage = 'Không thể gửi yêu cầu: $exception';
                          });
                        }
                      },
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(sending ? 'Đang gửi...' : 'Gửi yêu cầu'),
              ),
            ],
          ),
        );
      },
    );
    titleController.dispose();
    descriptionController.dispose();

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu đến creator.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final creatorShows = shows
        .where((item) => item.channel == widget.show.channel)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      appBar: AppBar(
        title: Text(widget.show.channel),
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: widget.show.colors.first,
                child: const Icon(Icons.mic, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.show.channel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Content creator lich su Viet Nam',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.show.creatorId == null ? null : _toggleFollow,
              icon: loadingFollow
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(following ? Icons.person_remove : Icons.person_add),
              label: Text(following ? 'Dang theo doi' : 'Theo doi creator'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.show.creatorId == null
                  ? null
                  : widget.onMembership,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Dang ky thanh vien'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.show.creatorId == null
                  ? null
                  : _showRequestDialog,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Gửi yêu cầu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Audio da dang',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...creatorShows.map(
            (audio) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Art(show: audio, size: 52),
              title: Text(
                audio.title,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                audio.duration,
                style: const TextStyle(color: Colors.white60),
              ),
              trailing: const Icon(
                Icons.play_circle_outline,
                color: Colors.white,
              ),
              onTap: () => widget.onOpen(audio),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Playlist cua creator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.queue_music, color: Colors.white),
            ),
            title: const Text(
              'Lich su Viet Nam',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${creatorShows.length} audio',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.queue_music, color: Colors.white),
            ),
            title: const Text(
              'Tuyen tap noi bat',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Playlist cong khai',
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}

class MorePanel extends StatelessWidget {
  const MorePanel({
    super.key,
    required this.show,
    required this.onReport,
    required this.onMembership,
    required this.onCreatorProfile,
  });
  final Show show;
  final VoidCallback onReport, onMembership, onCreatorProfile;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.white),
          title: const Text(
            'Bao cao podcast',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            Navigator.pop(context);
            onReport();
          },
        ),
        ListTile(
          leading: const Icon(
            Icons.workspace_premium_outlined,
            color: Colors.white,
          ),
          title: const Text(
            'Dang ky thanh vien',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            Navigator.pop(context);
            onMembership();
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_outline, color: Colors.white),
          title: const Text(
            'Xem profile Content creator',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            show.channel,
            style: const TextStyle(color: Colors.white60),
          ),
          onTap: () {
            Navigator.pop(context);
            onCreatorProfile();
          },
        ),
        const SizedBox(height: 10),
      ],
    ),
  );
}

class Waveform extends StatelessWidget {
  const Waveform({super.key, this.progress = .42});
  final double progress;
  @override
  Widget build(BuildContext context) {
    const bars = [
      22,
      34,
      48,
      30,
      60,
      38,
      72,
      46,
      88,
      55,
      74,
      94,
      58,
      84,
      68,
      102,
      62,
      90,
      52,
      76,
      110,
      64,
      94,
      78,
      56,
      84,
      68,
      98,
      60,
      74,
      92,
      52,
      76,
      108,
      66,
      88,
      58,
      96,
      72,
      84,
      62,
      100,
      54,
      78,
      94,
      68,
      86,
      58,
      72,
      48,
      82,
      64,
      96,
      54,
      74,
      46,
      68,
      38,
      58,
      34,
      52,
      28,
      44,
      22,
    ];
    return SizedBox(
      height: 164,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: bars.asMap().entries.map((entry) {
          final active = entry.key / bars.length < progress;
          final color = active ? const Color(0xFFFF6B1A) : Colors.white70;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: entry.value.toDouble() * .65,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 3,
                  height: entry.value.toDouble() * .42,
                  decoration: BoxDecoration(
                    color: color.withAlpha(190),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class Comment extends StatelessWidget {
  const Comment({
    super.key,
    required this.name,
    required this.text,
    required this.time,
  });
  final String name, text, time;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : theme.colorScheme.onSurface;
    final mutedForeground = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(24)
            : theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: isDark
              ? Colors.white24
              : theme.colorScheme.outline.withAlpha(90),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: CircleAvatar(
          backgroundColor: isDark
              ? const Color(0xFFFFD8D2)
              : theme.colorScheme.primaryContainer,
          foregroundColor: isDark
              ? const Color(0xFF733B35)
              : theme.colorScheme.onPrimaryContainer,
          child: const Icon(Icons.person),
        ),
        title: Text(
          '$name  $time',
          style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(text, style: TextStyle(color: mutedForeground)),
        trailing: Icon(Icons.favorite_border, color: mutedForeground),
      ),
    );
  }
}
