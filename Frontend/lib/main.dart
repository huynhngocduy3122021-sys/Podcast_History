import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/creator_studio/presentation/views/creator_main_shell.dart';
import 'features/creator_studio/presentation/views/registration/creator_registration_screen.dart';

void main() => runApp(const ProviderScope(child: VietCastApp()));

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
  Widget build(BuildContext context) => ProviderScope(
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
          ? AuthPage(onAuthenticated: (value) => setState(() => account = value))
        : switch (account!.role) {
            UserRole.listener => Shell(
              onTheme: toggleTheme,
              onLogout: logout,
            ),
            UserRole.creator => CreatorShell(
              onTheme: toggleTheme,
              onLogout: logout,
            ),
            UserRole.admin => AdminShell(
              onTheme: toggleTheme,
              onLogout: logout,
            ),
          },
    ),
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
  void play(Show s) => setState(() {
    current = s;
    playing = true;
  });
  @override
  Widget build(BuildContext context) {
    final pages = [
      Home(onPlay: play, onSearch: () => setState(() => tab = 1)),
      Discover(onPlay: play),
      const LibraryPage(),
      const AlertPage(),
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
        icon: Icon(Icons.notifications_none),
        selectedIcon: Icon(Icons.notifications),
        label: 'Thong bao',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Ca nhan',
      ),
    ],
  );
  void openPlayer() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Player(
      show: current!,
      playing: playing,
      onToggle: () => setState(() => playing = !playing),
    ),
  );
}

class CreatorShell extends StatelessWidget {
  const CreatorShell({super.key, required this.onTheme, required this.onLogout});
  final VoidCallback onTheme, onLogout;

  @override
  Widget build(BuildContext context) => CreatorMainShell(
    onTheme: onTheme,
    onLogout: onLogout,
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
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.notifications_none), label: 'Thong bao'),
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
  const Home({super.key, required this.onPlay, required this.onSearch});
  final ValueChanged<Show> onPlay;
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
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
              const CircleAvatar(
                backgroundColor: Color(0xFFE0B84A),
                child: Text('MA'),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Section(
          title: 'Tiep tuc nghe',
          child: Resume(show: shows[0], onPlay: onPlay),
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
                child: ShowCard(show: shows[i], onPlay: () => onPlay(shows[i])),
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Section(
          title: 'Theo dong thoi gian',
          child: SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children:
                  [
                        '1858 - 1945',
                        '1945 - 1954',
                        '1954 - 1975',
                        '1975 - 1986',
                        '1986 - nay',
                      ]
                      .map(
                        (x) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(x),
                            selected: x == '1945 - 1954',
                            onSelected: (_) {},
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );
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
  const Resume({super.key, required this.show, required this.onPlay});
  final Show show;
  final ValueChanged<Show> onPlay;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Art(show: show, size: 72),
        title: Text(show.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(show.channel),
        trailing: IconButton(
          onPressed: () => onPlay(show),
          tooltip: 'Phat',
          icon: const Icon(Icons.play_circle_filled, size: 38),
        ),
      ),
    ),
  );
}

class ShowCard extends StatelessWidget {
  const ShowCard({super.key, required this.show, required this.onPlay});
  final Show show;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        children: [
          Art(show: show, size: 156),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filled(
              onPressed: onPlay,
              tooltip: 'Phat',
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
  const Discover({super.key, required this.onPlay});
  final ValueChanged<Show> onPlay;
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  String query = '';
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
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tim podcast, kenh, playlist',
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => ListTile(
              leading: Art(show: result[i], size: 64),
              title: Text(result[i].title),
              subtitle: Text('${result[i].channel} • ${result[i].duration}'),
              trailing: IconButton(
                onPressed: () => widget.onPlay(result[i]),
                tooltip: 'Phat',
                icon: const Icon(Icons.play_circle_outline),
              ),
            ),
            childCount: result.length,
          ),
        ),
      ],
    );
  }
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      const SliverAppBar(title: Text('Thu vien'), pinned: true),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'liked', label: Text('Da thich')),
              ButtonSegment(value: 'playlist', label: Text('Playlist')),
            ],
            selected: const {'liked'},
            onSelectionChanged: (_) {},
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => ListTile(
            leading: Art(show: shows[i], size: 64),
            title: Text(shows[i].title),
            subtitle: Text(shows[i].channel),
            trailing: const Icon(Icons.more_horiz),
          ),
          childCount: shows.length,
        ),
      ),
    ],
  );
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
          icon: Icons.mic_rounded,
          title: 'Dang ky lam Creator',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatorRegistrationScreen()),
          ),
        ),
        Setting(
          icon: Icons.dark_mode_outlined,
          title: 'Giao dien toi',
          onTap: onTheme,
        ),
        Setting(
          icon: Icons.logout,
          title: 'Dang xuat',
          onTap: onLogout,
        ),
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
        const SnackBar(content: Text('Dang ky mock thanh cong. Ban co the dang nhap ngay.')),
      );
      setState(() => register = false);
      return;
    }
    final account = mockAccounts.where(
      (item) => item.email == emailController.text.trim() &&
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
        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
            icon: Icon(
              switch (account.role) {
                UserRole.listener => Icons.headphones,
                UserRole.creator => Icons.mic,
                UserRole.admin => Icons.admin_panel_settings,
              },
            ),
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

class Player extends StatelessWidget {
  const Player({
    super.key,
    required this.show,
    required this.playing,
    required this.onToggle,
  });
  final Show show;
  final bool playing;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .9,
    builder: (_, controller) => Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Thu nho',
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          Center(
            child: Art(show: show, size: MediaQuery.sizeOf(context).width - 48),
          ),
          const SizedBox(height: 20),
          Text(show.title, style: Theme.of(context).textTheme.headlineSmall),
          Text(show.channel),
          const SizedBox(height: 24),
          const Waveform(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.replay_10)),
              IconButton.filled(
                onPressed: onToggle,
                tooltip: playing ? 'Tam dung' : 'Phat',
                icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 34),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.forward_10)),
            ],
          ),
          const Comment(
            name: 'Thu Ha',
            text: 'Mot lat cat lich su rat dang nghe.',
            time: '02:35',
          ),
          const Comment(
            name: 'Quang Minh',
            text: 'Cach ke chuyen gan gui va nhieu tu lieu.',
            time: '08:12',
          ),
        ],
      ),
    ),
  );
}

class Waveform extends StatelessWidget {
  const Waveform({super.key});
  @override
  Widget build(BuildContext context) {
    const bars = [
      12,
      28,
      20,
      36,
      18,
      44,
      30,
      54,
      24,
      40,
      32,
      58,
      22,
      48,
      30,
      38,
      18,
      52,
      26,
      42,
      20,
      34,
      17,
      30,
    ];
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: bars
            .asMap()
            .entries
            .map(
              (e) => Container(
                width: 4,
                height: e.value.toDouble(),
                color: e.key < 10
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            )
            .toList(),
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
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const CircleAvatar(child: Icon(Icons.person)),
    title: Text('$name  $time'),
    subtitle: Text(text),
    trailing: const Icon(Icons.favorite_border),
  );
}
