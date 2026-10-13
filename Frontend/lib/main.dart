import 'package:flutter/material.dart';

void main() => runApp(const VietCastApp());

enum UserRole { listener, creator, admin }

class MockAccount {
  const MockAccount(this.email, this.password, this.name, this.role);
  final String email, password, name;
  final UserRole role;
}

const mockAccounts = <MockAccount>[
  MockAccount(
    'listener@vietcast.local',
    'Listener@123',
    'Nguoi nghe',
    UserRole.listener,
  ),
  MockAccount(
    'creator@vietcast.local',
    'Creator@123',
    'Nguoi sang tao',
    UserRole.creator,
  ),
  MockAccount(
    'admin@vietcast.local',
    'Admin@123',
    'Quan tri vien',
    UserRole.admin,
  ),
];

class VietCastApp extends StatefulWidget {
  const VietCastApp({super.key});
  @override
  State<VietCastApp> createState() => _AppState();
}

class _AppState extends State<VietCastApp> {
  ThemeMode mode = ThemeMode.light;
  MockAccount? account;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VietCast',
    debugShowCheckedModeBanner: false,
    themeMode: mode,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB3261E),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFBF7F0),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE8665D),
        brightness: Brightness.dark,
      ),
    ),
    home: account == null
        ? AuthPage(onAuthenticated: (value) => setState(() => account = value))
        : switch (account!.role) {
            UserRole.listener => Shell(onTheme: toggleTheme, onLogout: logout),
            UserRole.creator => CreatorShell(
              onTheme: toggleTheme,
              onLogout: logout,
            ),
            UserRole.admin => AdminShell(
              onTheme: toggleTheme,
              onLogout: logout,
            ),
          },
  );

  void toggleTheme() => setState(
    () => mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
  );

  void logout() => setState(() => account = null);
}

class Show {
  const Show(
    this.title,
    this.channel,
    this.period,
    this.duration,
    this.colors, {
    this.member = false,
  });
  final String title, channel, period, duration;
  final List<Color> colors;
  final bool member;
}

String _formatVnd(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} VND';

const shows = <Show>[
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

class Shell extends StatefulWidget {
  const Shell({super.key, required this.onTheme, required this.onLogout});
  final VoidCallback onTheme;
  final VoidCallback onLogout;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
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

  void play(Show s) => setState(() {
    current = s;
    playing = true;
  });

  void openShow(Show show) {
    play(show);
    _showPlayer(show);
  }

  void updateLiked(Show show, bool liked) => setState(() {
    if (liked) {
      likedShowTitles.add(show.title);
    } else {
      likedShowTitles.remove(show.title);
    }
  });

  void updateSaved(Show show, bool saved) => setState(() {
    if (saved) {
      savedShowTitles.add(show.title);
    } else {
      savedShowTitles.remove(show.title);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Da gui bao cao "$reason" cho admin.')),
        );
      },
    ),
  );

  void _showMembership(Show show) {
    const price = 79000;
    if (walletBalance < price) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('So du khong du'),
          content: Text(
            'Goi thanh vien co gia 79.000 VND. Vi cua ban con ${_formatVnd(walletBalance)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('De sau'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  walletBalance += 200000;
                  tab = 3;
                });
              },
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Nap them'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xac nhan dang ky'),
        content: Text(
          'Ban co chac chan dang ky goi thanh vien cua ${show.channel} voi gia 79.000 VND khong?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => walletBalance -= price);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dang ky thanh vien thanh cong.')),
              );
            },
            child: const Text('Xac nhan'),
          ),
        ],
      ),
    );
  }

  void _showCreatorProfile(Show creatorShow) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CreatorProfilePanel(
        show: creatorShow,
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
      onProgressChanged: (value) => progressByShow[show.title] = value,
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
        onPlay: play,
        onOpen: openShow,
        onSearch: () => setState(() => tab = 1),
        hasUnreadNotifications: notifications.any((item) => !item.read),
        onNotifications: _showNotifications,
        onProfile: () => setState(() => tab = 4),
      ),
      Discover(onOpen: openShow),
      LibraryPage(
        likedTitles: likedShowTitles,
        savedTitles: savedShowTitles,
        onOpen: openShow,
      ),
      ListenerWalletPage(
        balance: walletBalance,
        onTopUp: () => setState(() => walletBalance += 200000),
      ),
      Profile(onTheme: widget.onTheme, onLogout: widget.onLogout),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[tab]),
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
    required this.onTheme,
    required this.onLogout,
  });
  final VoidCallback onTheme, onLogout;

  @override
  Widget build(BuildContext context) => ActorShell(
    title: 'Creator Studio',
    pages: [
      const CreatorPage(),
      const RequestPage(),
      const WalletPage(),
      Profile(onTheme: onTheme, onLogout: onLogout),
    ],
    destinations: const [
      NavigationDestination(icon: Icon(Icons.mic), label: 'Studio'),
      NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        label: 'Yeu cau',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        label: 'Vi',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Ca nhan'),
    ],
  );
}

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.onTheme, required this.onLogout});
  final VoidCallback onTheme, onLogout;

  @override
  Widget build(BuildContext context) => ActorShell(
    title: 'Admin VietCast',
    pages: [
      const AdminPage(),
      const AlertPage(),
      Profile(onTheme: onTheme, onLogout: onLogout),
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
    required this.onPlay,
    required this.onOpen,
    required this.onSearch,
    required this.hasUnreadNotifications,
    required this.onNotifications,
    required this.onProfile,
  });
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
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFE0B84A),
                  child: Text('MA'),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chao buoi toi,'),
                    Text(
                      'Minh Anh',
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
    required this.likedTitles,
    required this.savedTitles,
    required this.onOpen,
  });
  final Set<String> likedTitles;
  final Set<String> savedTitles;
  final ValueChanged<Show> onOpen;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String selected = 'liked';
  final customPlaylists = <PlaylistData>[];

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
      ] else ...[
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
  const Profile({super.key, required this.onTheme, required this.onLogout});
  final VoidCallback onTheme;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ca nhan')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(
          radius: 42,
          backgroundColor: Color(0xFFE0B84A),
          child: Text('MA', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Minh Anh',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const Center(child: Text('Nguoi nghe lich su Viet Nam')),
        const SizedBox(height: 20),
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
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});
  final ValueChanged<MockAccount> onAuthenticated;
  @override
  State<AuthPage> createState() => _AuthState();
}

class _AuthState extends State<AuthPage> {
  bool register = false;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login(MockAccount account) => widget.onAuthenticated(account);

  void submit() {
    if (register) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dang ky mock thanh cong. Ban co the dang nhap ngay.'),
        ),
      );
      setState(() => register = false);
      return;
    }
    final account = mockAccounts.where(
      (item) =>
          item.email == emailController.text.trim() &&
          item.password == passwordController.text,
    );
    if (account.isEmpty) {
      setState(() => error = 'Email hoac mat khau mock khong dung.');
      return;
    }
    login(account.first);
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
      TextField(
        controller: emailController,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: passwordController,
        obscureText: true,
        decoration: InputDecoration(labelText: 'Mat khau'),
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
        onPressed: submit,
        child: Text(register ? 'Dang ky' : 'Dang nhap'),
      ),
      if (!register) ...[
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Dang nhap nhanh bang tai khoan mock'),
        ),
        const SizedBox(height: 8),
        ...mockAccounts.map(
          (account) => OutlinedButton.icon(
            onPressed: () => login(account),
            icon: Icon(switch (account.role) {
              UserRole.listener => Icons.headphones,
              UserRole.creator => Icons.mic,
              UserRole.admin => Icons.admin_panel_settings,
            }),
            label: Text('${account.name} (${account.email})'),
          ),
        ),
      ],
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
    required this.playing,
    required this.initialProgress,
    required this.initialLiked,
    required this.initialSaved,
    required this.onProgressChanged,
    required this.onLikedChanged,
    required this.onSavedChanged,
    required this.onReport,
    required this.onMembership,
    required this.onCreatorProfile,
    required this.onToggle,
  });
  final Show show;
  final bool playing;
  final double initialProgress;
  final bool initialLiked, initialSaved;
  final ValueChanged<double> onProgressChanged;
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
  final comments = <CommentData>[
    const CommentData('Thu Ha', 'Mot lat cat lich su rat dang nghe.', '02:35'),
    const CommentData(
      'Quang Minh',
      'Cach ke chuyen gan gui va nhieu tu lieu.',
      '08:12',
    ),
  ];

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

  void submitComment() {
    final text = commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      comments.insert(0, CommentData('Minh Anh', text, _timestamp));
      commentController.clear();
    });
  }

  String get _timestamp {
    final seconds = (progress * 32 * 60).round();
    return _formatDuration(seconds);
  }

  String _formatDuration(num seconds) {
    final wholeSeconds = seconds.round();
    return '${(wholeSeconds ~/ 60).toString().padLeft(2, '0')}:${(wholeSeconds % 60).toString().padLeft(2, '0')}';
  }

  CommentData? get timelineComment {
    final nearby = comments
        .where((comment) => (comment.position - progress).abs() <= .04)
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
    builder: (_) => CommentsPanel(
      comments: comments,
      onSubmit: (text) => setState(
        () => comments.insert(0, CommentData('Minh Anh', text, _timestamp)),
      ),
    ),
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
                const Text(
                  '32:18',
                  style: TextStyle(
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
                    'Vi tri phat ${_formatDuration(value * 32 * 60)}',
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
  const _CommentComposer({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

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
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              hintText: 'Comment...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
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
  const CommentData(this.name, this.text, this.time);
  final String name, text, time;

  double get position {
    final parts = time.split(':');
    final seconds = parts.length == 2
        ? (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0)
        : 0;
    return (seconds / (32 * 60)).clamp(0.02, .9);
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
  final ValueChanged<String> onSubmit;

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

  void submit() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    setState(() => controller.clear());
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
          _CommentComposer(controller: controller, onSubmit: submit),
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

class CreatorProfilePanel extends StatelessWidget {
  const CreatorProfilePanel({
    super.key,
    required this.show,
    required this.onOpen,
  });
  final Show show;
  final ValueChanged<Show> onOpen;

  @override
  Widget build(BuildContext context) {
    final creatorShows = shows
        .where((item) => item.channel == show.channel)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      appBar: AppBar(
        title: Text(show.channel),
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
                backgroundColor: show.colors.first,
                child: const Icon(Icons.mic, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.channel,
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
              onTap: () => onOpen(audio),
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(24),
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFD8D2),
        foregroundColor: Color(0xFF733B35),
        child: Icon(Icons.person),
      ),
      title: Text(
        '$name  $time',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(text, style: const TextStyle(color: Colors.white70)),
      trailing: const Icon(Icons.favorite_border, color: Colors.white70),
    ),
  );
}
