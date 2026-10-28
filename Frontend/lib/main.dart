import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import 'core/services/session_storage/session_storage.dart';
import 'core/package_features.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/image_url_helper.dart';
import 'features/creator_studio/presentation/controllers/creator_controller.dart';
import 'features/creator_studio/presentation/views/creator_main_shell.dart';
import 'features/creator_studio/presentation/views/registration/creator_registration_screen.dart';
import 'features/livestream/listener_livestream_screen.dart';

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

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'role': role.name,
    'session': {
      'user': {
        'id': session.user.id,
        'username': session.user.username,
        'email': session.user.email,
        'displayName': session.user.displayName,
        'role': session.user.role,
        'avatarUrl': session.user.avatarUrl,
        'bio': session.user.bio,
      },
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'tokenType': session.tokenType,
      'expiresIn': session.expiresIn,
      'refreshExpiresIn': session.refreshExpiresIn,
    },
  };

  factory Account.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'listener';
    final role = UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
      orElse: () => UserRole.listener,
    );
    final sessionMap = json['session'] as Map<String, dynamic>;
    return Account(
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: role,
      session: AuthSession.fromJson(sessionMap),
    );
  }
}

class VietCastApp extends StatefulWidget {
  const VietCastApp({super.key});
  @override
  State<VietCastApp> createState() => _AppState();
}

class _AppState extends State<VietCastApp> with WidgetsBindingObserver {
  ThemeMode mode = ThemeMode.light;
  Account? account;
  Timer? _tokenRefreshTimer;
  bool _isRefreshingToken = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSavedSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final current = account;
      if (current != null && current.session.refreshToken.isNotEmpty) {
        if (_isTokenExpiringSoon(current.session.accessToken)) {
          _autoRefreshToken();
        }
      }
    }
  }

  int _getTokenRemainingSeconds(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 600;
      var output = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (output.length % 4) {
        case 0:
          break;
        case 2:
          output += '==';
          break;
        case 3:
          output += '=';
          break;
        default:
          return 600;
      }
      final decoded = utf8.decode(base64Url.decode(output));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = payload['exp'] as num?;
      if (exp != null) {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        return exp.toInt() - nowSec;
      }
    } catch (_) {}
    return 600;
  }

  bool _isTokenExpiringSoon(String token, {int thresholdSeconds = 120}) {
    final remaining = _getTokenRemainingSeconds(token);
    return remaining <= thresholdSeconds;
  }

  void _scheduleTokenRefresh(Account acc) {
    _tokenRefreshTimer?.cancel();
    final remaining = _getTokenRemainingSeconds(acc.session.accessToken);
    // Refresh 2 minutes (120s) before token expires, or at least in 15 seconds if already near expiry
    final delaySeconds = math.max(15, remaining - 120);
    _tokenRefreshTimer = Timer(Duration(seconds: delaySeconds), () {
      _autoRefreshToken();
    });
  }

  Future<void> _autoRefreshToken() async {
    if (_isRefreshingToken) return;
    final current = account;
    if (current == null || current.session.refreshToken.isEmpty) return;

    _isRefreshingToken = true;
    try {
      final newSession = await AuthApi().refresh(current.session.refreshToken);
      final updated = Account(
        email: current.email,
        name: current.name,
        role: current.role,
        session: newSession,
      );
      _saveSession(updated);
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        logout();
      } else {
        // Transient network or server failure: retry in 30 seconds
        _tokenRefreshTimer?.cancel();
        _tokenRefreshTimer = Timer(const Duration(seconds: 30), () {
          _autoRefreshToken();
        });
      }
    } finally {
      _isRefreshingToken = false;
    }
  }

  void _restoreSavedSession() {
    try {
      final raw = SessionStorage.getItem('vietcast_saved_account');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final restored = Account.fromJson(decoded);
        setState(() => account = restored);
        if (_isTokenExpiringSoon(restored.session.accessToken)) {
          _autoRefreshToken();
        } else {
          _scheduleTokenRefresh(restored);
        }
      }
    } catch (_) {}
  }

  void _saveSession(Account? acc) {
    setState(() => account = acc);
    if (acc != null) {
      try {
        SessionStorage.setItem(
          'vietcast_saved_account',
          jsonEncode(acc.toJson()),
        );
      } catch (_) {}
      _scheduleTokenRefresh(acc);
    } else {
      _tokenRefreshTimer?.cancel();
      SessionStorage.removeItem('vietcast_saved_account');
    }
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      creatorAccessTokenProvider.overrideWithValue(
        account?.session.accessToken,
      ),
      creatorRefreshTokenProvider.overrideWithValue(
        account?.session.refreshToken,
      ),
      creatorSessionRefreshCallbackProvider.overrideWithValue((
        newAccessToken,
        newRefreshToken,
      ) {
        final current = account;
        if (current != null) {
          _saveSession(
            Account(
              email: current.email,
              name: current.name,
              role: current.role,
              session: AuthSession(
                user: current.session.user,
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
                tokenType: current.session.tokenType,
                expiresIn: current.session.expiresIn,
                refreshExpiresIn: current.session.refreshExpiresIn,
              ),
            ),
          );
        }
      }),
      creatorSessionExpiredCallbackProvider.overrideWithValue(() {
        logout();
      }),
    ],
    child: MaterialApp(
      title: 'VietCast',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final mediaQuery = MediaQuery.of(context);
        final safeInsets = EdgeInsets.only(
          left: math.max(0.0, mediaQuery.viewInsets.left),
          top: math.max(0.0, mediaQuery.viewInsets.top),
          right: math.max(0.0, mediaQuery.viewInsets.right),
          bottom: math.max(0.0, mediaQuery.viewInsets.bottom),
        );
        return MediaQuery(
          data: mediaQuery.copyWith(viewInsets: safeInsets),
          child: ColoredBox(
            color: isDark ? const Color(0xFF121212) : const Color(0xFFEFE8DE),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: account == null
          ? AuthPage(onAuthenticated: (value) => _saveSession(value))
          : switch (account!.role) {
              UserRole.listener => Shell(
                session: account!.session,
                onSessionRefreshed: (session) {
                  final current = account;
                  if (current != null &&
                      current.session.user.id == session.user.id) {
                    _saveSession(
                      Account(
                        email: current.email,
                        name: current.name,
                        role: current.role,
                        session: session,
                      ),
                    );
                  }
                },
                onProfileUpdated: (user) {
                  final current = account;
                  if (current != null) {
                    _saveSession(
                      Account(
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
                      ),
                    );
                  }
                },
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
    _saveSession(null);
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
    this.seriesTitle,
    this.description = '',
    this.categoryId,
    this.categoryName = '',
    this.thumbnailUrl,
  });
  final String title, channel, period, duration;
  final List<Color> colors;
  final bool member;
  final String? id;
  final String? creatorId;
  final int? durationSeconds;
  final String? seriesTitle;
  final String description;
  final String? categoryId;
  final String categoryName;
  final String? thumbnailUrl;

  Show copyWith({
    String? duration,
    int? durationSeconds,
    String? thumbnailUrl,
  }) => Show(
    title,
    channel,
    period,
    duration ?? this.duration,
    colors,
    member: member,
    id: id,
    creatorId: creatorId,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    categoryId: categoryId,
    categoryName: categoryName,
    seriesTitle: seriesTitle,
    description: description,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
  );
}

String _formatVnd(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} VND';

final fallbackShows = <Show>[
  Show(
    'Nhung ngay dau cua nen doc lap',
    'Sử Việt kể chuyện',
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
    'Đổi Mới: Từ ý tưởng đến bước ngoặt',
    'VietCast Originals',
    '1986 - nay',
    '28:44',
    [Color(0xFF803E31), Color(0xFFE0B84A)],
    member: true,
  ),
  Show(
    'Nhân vật: Nguyễn An Ninh',
    'Góc nhìn Việt Nam',
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
  late final AudioPlayer _audioPlayer;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration>? _audioDurationSubscription;
  StreamSubscription<PlayerState>? _audioStateSubscription;
  StreamSubscription<void>? _audioCompleteSubscription;
  int _playRequest = 0;
  int _lastSavedSecond = -1;
  Duration _latestPosition = Duration.zero;
  bool apiLoading = true;
  bool usingSamplePodcasts = true;
  List<Map<String, dynamic>> categories = const [];
  String? apiError;
  final commentsByPodcast = <String, List<CommentData>>{};
  final likeCountsByPodcast = <String, int>{};
  final commentCountsByPodcast = <String, int>{};
  final creatorDetails = <String, Map<String, dynamic>>{};
  StreamSubscription<String>? commentSubscription;
  int tab = 0;
  Show? current;
  bool playing = false;
  final progressByShow = <String, double>{shows[0].title: .42};
  final likedShowTitles = <String>{shows[0].title};
  final savedShowTitles = <String>{};
  int walletBalance = 350000;
  final notifications = <AppNotification>[];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioDurationSubscription = _audioPlayer.onDurationChanged.listen((
      duration,
    ) {
      final show = current;
      if (!mounted || show == null || duration.inSeconds <= 0) return;
      final updated = show.copyWith(
        duration: _formatDuration(duration.inSeconds),
        durationSeconds: duration.inSeconds,
      );
      setState(() {
        current = updated;
        final index = shows.indexWhere((item) => item.id == show.id);
        if (index >= 0) shows[index] = updated;
      });
    });
    _audioPositionSubscription = _audioPlayer.onPositionChanged.listen((
      position,
    ) {
      final show = current;
      if (!mounted || show == null) return;
      _latestPosition = position;
      final duration = show.durationSeconds ?? 0;
      if (duration <= 0) return;
      setState(() {
        final progress = (position.inSeconds / duration).clamp(0.0, 1.0);
        progressByShow[show.title] = progress;
        if (show.id != null &&
            (position.inSeconds - _lastSavedSecond).abs() >= 5) {
          _lastSavedSecond = position.inSeconds;
          unawaited(
            api.saveProgress(
              show.id!,
              progressSeconds: position.inSeconds,
              completed: progress >= .99,
            ),
          );
        }
      });
    });
    _audioStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => playing = state == PlayerState.playing);
    });
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted || current == null) return;
      setState(() {
        playing = false;
        progressByShow[current!.title] = 1;
      });
    });
    api = ListenerApi(
      accessToken: widget.session.accessToken,
      refreshToken: widget.session.refreshToken,
      onSessionRefreshed: widget.onSessionRefreshed,
    );
    shows = List<Show>.of(fallbackShows);
    _loadListenerFlow();
  }

  @override
  void didUpdateWidget(covariant Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.accessToken != widget.session.accessToken ||
        oldWidget.session.refreshToken != widget.session.refreshToken) {
      api.accessToken = widget.session.accessToken;
      api.refreshToken = widget.session.refreshToken;
    }
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
        _optionalList(api.notifications()),
      ]);
      final podcasts = results[0] as List<ListenerPodcast>;
      categories = results[7] as List<Map<String, dynamic>>;
      final creatorList = results[8] as List<Map<String, dynamic>>;
      notifications
        ..clear()
        ..addAll(
          (results[9] as List<Map<String, dynamic>>).map(
            AppNotification.fromJson,
          ),
        );
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
            categoryId: podcast.categoryId,
            categoryName: podcast.categoryName,
            seriesTitle: podcast.seriesTitle,
            description: podcast.description,
            thumbnailUrl: podcast.thumbnailUrl,
          );
        }).toList();
        final interactionResponses = await Future.wait(
          podcasts.map(
            (podcast) async => (
              likes: await api.likes(podcast.id),
              comments: await api.comments(podcast.id),
              commentCount: await api.commentCount(podcast.id),
            ),
          ),
        );
        for (var index = 0; index < podcasts.length; index++) {
          final podcast = podcasts[index];
          final interaction = interactionResponses[index];
          if (interaction.likes['likedByMe'] == true) {
            likedShowTitles.add(podcast.title);
          }
          likeCountsByPodcast[podcast.id] =
              (interaction.likes['likeCount'] as num?)?.toInt() ?? 0;
          commentCountsByPodcast[podcast.id] = interaction.commentCount;
          commentsByPodcast[podcast.id] = interaction.comments
              .map(
                (comment) => CommentData.fromJson(
                  comment,
                  durationSeconds: podcast.durationSeconds,
                ),
              )
              .toList();
        }
      }
      for (final item in results[1] as List<Map<String, dynamic>>) {
        final title = '${item['podcastTitle'] ?? ''}';
        final seconds = (item['progressSeconds'] as num?)?.toInt() ?? 0;
        final show = shows.where((item) => item.title == title).firstOrNull;
        final duration = show?.durationSeconds ?? 0;
        if (title.isNotEmpty && duration > 0) {
          progressByShow[title] = (seconds / duration).clamp(0.0, 1.0);
        }
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

  void play(Show s) {
    setState(() {
      current = s;
      playing = true;
    });
    unawaited(_startPlayback(s));
  }

  Future<void> _startPlayback(Show show) async {
    final request = ++_playRequest;
    if (show.id == null) {
      if (mounted) {
        setState(() => playing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podcast này chưa có audio trên máy chủ.'),
          ),
        );
      }
      return;
    }

    try {
      final playback = await api.playback(show.id!);
      final playbackUrl = playback['playbackUrl']?.toString().trim();
      if (playbackUrl == null || playbackUrl.isEmpty) {
        throw const FormatException('API không trả về playbackUrl.');
      }
      if (request != _playRequest) return;
      final resumeSeconds =
          (playback['resumeFromSeconds'] as num?)?.toInt() ?? 0;
      _lastSavedSecond = resumeSeconds;
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(playbackUrl));
      if (resumeSeconds > 0 && request == _playRequest) {
        await _audioPlayer.seek(Duration(seconds: resumeSeconds));
      }
    } catch (error) {
      if (!mounted || request != _playRequest) return;
      setState(() => playing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể phát audio: $error')));
    }
  }

  Future<void> togglePlayback() async {
    final show = current;
    if (show == null) return;
    if (playing) {
      await _audioPlayer.pause();
      return;
    }
    if (_audioPlayer.state == PlayerState.paused) {
      await _audioPlayer.resume();
      return;
    }
    await _startPlayback(show);
  }

  void openShow(Show show) {
    play(show);
    commentSubscription?.cancel();
    if (show.id != null) {
      commentSubscription = api
          .commentStream(show.id!)
          .listen((_) {}, onError: (_) {});
    }
    _showPlayer(show);
  }

  @override
  void dispose() {
    commentSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioStateSubscription?.cancel();
    _audioCompleteSubscription?.cancel();
    final show = current;
    if (show?.id != null) {
      final seconds = _latestPosition.inSeconds;
      unawaited(
        api.saveProgress(show!.id!, progressSeconds: seconds, completed: false),
      );
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<CommentData> _toggleCommentLike(CommentData comment) async {
    final id = comment.id;
    if (id == null) return comment;
    if (comment.likedByMe) {
      await api.unlikeComment(id);
    } else {
      await api.likeComment(id);
    }
    final likes = await api.commentLikes(id);
    final updated = comment.copyWith(
      likeCount: (likes['likeCount'] as num?)?.toInt() ?? comment.likeCount,
      likedByMe: likes['likedByMe'] == true,
    );
    for (final items in commentsByPodcast.values) {
      final index = items.indexWhere((item) => item.id == id);
      if (index >= 0) items[index] = updated;
    }
    return updated;
  }

  void updateLiked(Show show, bool liked) => setState(() {
    if (liked) {
      likedShowTitles.add(show.title);
    } else {
      likedShowTitles.remove(show.title);
    }
    if (show.id != null) {
      final currentCount = likeCountsByPodcast[show.id!] ?? 0;
      likeCountsByPodcast[show.id!] = (currentCount + (liked ? 1 : -1))
          .clamp(0, 1 << 31)
          .toInt();
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
                SnackBar(content: Text('Đã gửi báo cáo "$reason" cho admin.')),
              );
            })
            .catchError((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không thể gửi báo cáo lúc này.')),
              );
            });
      },
    ),
  );

  Future<void> _showMembership(Show show) async {
    if (show.creatorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podcast này chưa có Creator ID.')),
      );
      return;
    }
    try {
      final plans = await api.membershipPlans(show.creatorId!);
      if (!mounted) return;
      if (plans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creator chưa có gói membership đang hoạt động.'),
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
          title: Text('Đăng ký $planName'),
          content: Text(
            'Goi cua ${show.channel}: $price. Backend se tao checkout o trang thai cho thanh toan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final checkout = await api.checkout(
                    planId,
                    paymentMethod: 'SEPAY',
                  );
                  if (!mounted) return;
                  final paid = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => PaymentDialog(
                      api: api,
                      checkout: checkout,
                      planName: planName,
                    ),
                  );
                  if (paid == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Thanh toán thành công. Membership đã được kích hoạt.',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Không thể tạo phiên thanh toán.'),
                    ),
                  );
                }
              },
              child: const Text('Tạo phiên thanh toán'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải gói membership.')),
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
    barrierLabel: 'Đóng trình phát',
    backgroundColor: Colors.transparent,
    builder: (_) => Player(
      show: show,
      api: api,
      audioPlayer: _audioPlayer,
      playing: playing,
      initialProgress: progressByShow[show.title] ?? 0,
      initialLiked: likedShowTitles.contains(show.title),
      initialLikeCount: show.id == null
          ? 0
          : (likeCountsByPodcast[show.id!] ?? 0),
      initialCommentCount: show.id == null
          ? 0
          : (commentCountsByPodcast[show.id!] ?? 0),
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
      onSeek: (position) => _audioPlayer.seek(position),
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
      onCommentLike: _toggleCommentLike,
      onSavedChanged: (value) => updateSaved(show, value),
      onReport: () => _showReport(show),
      onMembership: () => _showMembership(show),
      onCreatorProfile: () => _showCreatorProfile(show),
      onToggle: togglePlayback,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      Home(
        displayName: widget.displayName,
        categories: categories,
        onPlay: play,
        onOpen: openShow,
        onSearch: () => setState(() => tab = 1),
        onWallet: _openWallet,
        hasUnreadNotifications: notifications.any((item) => !item.read),
        onNotifications: _showNotifications,
        onProfile: () => setState(() => tab = 4),
      ),
      Discover(
        api: api,
        categories: categories,
        onOpen: openShow,
        onOpenCreator: _showCreatorProfile,
      ),
      LivestreamPage(api: api),
      LibraryPage(
        api: api,
        likedTitles: likedShowTitles,
        savedTitles: savedShowTitles,
        onOpen: openShow,
        onOpenCreator: _showCreatorProfile,
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
                  onToggle: togglePlayback,
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
        label: 'Khám phá',
      ),
      NavigationDestination(
        icon: Icon(Icons.live_tv_outlined),
        selectedIcon: Icon(Icons.live_tv),
        label: 'Livestream',
      ),
      NavigationDestination(
        icon: Icon(Icons.library_music_outlined),
        selectedIcon: Icon(Icons.library_music),
        label: 'Thu vien',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Cá nhân',
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
            unawaited(api.markNotificationRead(id));
          }
        });
      },
    ),
  );

  void _openWallet() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ListenerWalletPage(
        balance: walletBalance,
        onTopUp: () => setState(() => walletBalance += 200000),
      ),
    ),
  );
  void openPlayer() => _showPlayer(current!);
}

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.api,
    required this.checkout,
    required this.planName,
  });

  final ListenerApi api;
  final Map<String, dynamic> checkout;
  final String planName;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  Timer? _pollTimer;
  late Map<String, dynamic> _payment;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _payment = Map<String, dynamic>.from(widget.checkout);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkPayment();
    });
  }

  String? get _paymentId => _payment['paymentId']?.toString();
  String get _status =>
      '${_payment['paymentStatus'] ?? _payment['status'] ?? 'PENDING'}'
          .toUpperCase();

  Future<void> _checkPayment() async {
    final paymentId = _paymentId;
    if (_checking || paymentId == null || paymentId.isEmpty || !mounted) return;
    _checking = true;
    try {
      final latest = await widget.api.paymentStatus(paymentId);
      if (!mounted) return;
      setState(() {
        _payment = {..._payment, ...latest};
        _error = null;
      });
      if (_status == 'PAID' &&
          '${_payment['subscriptionStatus'] ?? ''}'.toUpperCase() == 'ACTIVE') {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
      } else if (_status == 'EXPIRED' || _status == 'CANCELLED') {
        _pollTimer?.cancel();
      } else {
        // Keep polling while the payment is still pending.
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa kiểm tra được trạng thái thanh toán.');
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = _payment['qrImageUrl']?.toString();
    final paymentCode = _payment['paymentCode']?.toString();
    final amount = _payment['amount']?.toString() ?? '';
    final terminal = _status == 'EXPIRED' || _status == 'CANCELLED';
    return AlertDialog(
      title: Text('Thanh toán $_status'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.planName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (qrUrl != null && qrUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Image.network(
                qrUrl,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.qr_code_2, size: 160),
              ),
            ],
            if (amount.isNotEmpty) Text('Số tiền: $amount VND'),
            if (paymentCode != null && paymentCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText('Nội dung chuyển khoản: $paymentCode'),
            ],
            const SizedBox(height: 12),
            Text(
              terminal
                  ? 'Phiên thanh toán đã kết thúc. Vui lòng tạo giao dịch mới.'
                  : 'Quét QR và chờ hệ thống xác nhận. Màn hình tự kiểm tra mỗi 4 giây.',
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(terminal ? 'Đóng' : 'Để sau'),
        ),
        if (!terminal)
          FilledButton(
            onPressed: _checking ? null : _checkPayment,
            child: const Text('Kiểm tra ngay'),
          ),
      ],
    );
  }
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
        label: 'Thông báo',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
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
    required this.categories,
    required this.onPlay,
    required this.onOpen,
    required this.onSearch,
    required this.onWallet,
    required this.hasUnreadNotifications,
    required this.onNotifications,
    required this.onProfile,
  });
  final String displayName;
  final List<Map<String, dynamic>> categories;
  final ValueChanged<Show> onPlay;
  final ValueChanged<Show> onOpen;
  final VoidCallback onSearch, onWallet, onNotifications, onProfile;
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
                    Text('Chào buổi tối,'),
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
                tooltip: 'Tìm kiếm',
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: onWallet,
                tooltip: 'Ví',
                icon: const Icon(Icons.account_balance_wallet_outlined),
              ),
              IconButton(
                onPressed: onNotifications,
                tooltip: 'Thông báo',
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
          title: 'Tiếp tục nghe',
          child: Resume(show: shows[0], onOpen: onOpen),
        ),
      ),
      SliverToBoxAdapter(
        child: Section(
          title: 'Dành cho bạn',
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
        child: TopicFilter(
          categories: categories,
          onOpen: onOpen,
          onPlay: onPlay,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );
}

class TopicFilter extends StatefulWidget {
  const TopicFilter({
    super.key,
    required this.categories,
    required this.onOpen,
    required this.onPlay,
  });
  final List<Map<String, dynamic>> categories;
  final ValueChanged<Show> onOpen;
  final ValueChanged<Show> onPlay;

  @override
  State<TopicFilter> createState() => _TopicFilterState();
}

class _TopicFilterState extends State<TopicFilter> {
  String? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final filtered = selectedCategoryId == null
        ? shows
        : shows.where((show) => show.categoryId == selectedCategoryId).toList();
    final topicItems = [
      const <String, dynamic>{'categoryId': null, 'name': 'Tất cả'},
      ...widget.categories,
    ];
    return Section(
      title: 'Theo chủ đề',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topicItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final category = topicItems[index];
                final categoryId =
                    category['categoryId']?.toString() ??
                    category['id']?.toString();
                final categoryName = category['name']?.toString() ?? '';
                return ChoiceChip(
                  label: Text(categoryName),
                  selected: categoryId == selectedCategoryId,
                  onSelected: (_) =>
                      setState(() => selectedCategoryId = categoryId),
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
                  tooltip: 'Phát',
                  icon: const Icon(Icons.play_circle_outline),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Chưa có podcast trong chủ đề này.'),
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
            tooltip: 'Mở và phát tiếp',
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
              tooltip: 'Mở và phát',
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
  Widget build(BuildContext context) {
    final thumbnailUrl = resolveImageUrl(show.thumbnailUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: show.colors),
        ),
        child: thumbnailUrl.isEmpty
            ? _fallbackArt()
            : thumbnailUrl.startsWith('data:image')
            ? Image.memory(
                base64Decode(thumbnailUrl.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackArt(),
              )
            : Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackArt(),
              ),
      ),
    );
  }

  Widget _fallbackArt() => Stack(
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
          child: Chip(label: Text('MEM'), visualDensity: VisualDensity.compact),
        ),
    ],
  );
}

class Discover extends StatefulWidget {
  const Discover({
    super.key,
    required this.api,
    required this.categories,
    required this.onOpen,
    required this.onOpenCreator,
  });
  final ListenerApi api;
  final List<Map<String, dynamic>> categories;
  final ValueChanged<Show> onOpen;
  final ValueChanged<Show> onOpenCreator;
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  String query = '';
  String? selectedCategoryId;
  final searchController = TextEditingController();
  final searchHistory = <String>['lịch sử Việt Nam', 'Đổi Mới', 'Trường Sơn'];
  Timer? creatorSearchTimer;
  int creatorSearchRequest = 0;
  bool creatorSearchLoading = false;
  String? creatorSearchError;
  List<Map<String, dynamic>> creatorResults = const [];

  @override
  void dispose() {
    creatorSearchTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void updateQuery(String value) {
    creatorSearchTimer?.cancel();
    final next = value.trim();
    setState(() {
      query = next;
      creatorSearchRequest++;
      creatorResults = const [];
      creatorSearchLoading = next.isNotEmpty;
      creatorSearchError = null;
    });
    if (next.isNotEmpty) {
      creatorSearchTimer = Timer(
        const Duration(milliseconds: 300),
        () => loadCreators(next),
      );
    }
  }

  Future<void> loadCreators(String value) async {
    final request = ++creatorSearchRequest;
    setState(() {
      creatorSearchLoading = true;
      creatorSearchError = null;
    });
    try {
      final results = await widget.api.creators(query: value);
      if (!mounted || request != creatorSearchRequest) return;
      setState(() {
        creatorResults = results;
        creatorSearchLoading = false;
      });
    } catch (_) {
      if (!mounted || request != creatorSearchRequest) return;
      setState(() {
        creatorResults = const [];
        creatorSearchLoading = false;
        creatorSearchError = 'Không tải được danh sách kênh.';
      });
    }
  }

  void search(String value) {
    final next = value.trim();
    creatorSearchTimer?.cancel();
    setState(() {
      query = next;
      if (next.isNotEmpty) {
        searchHistory.remove(next);
        searchHistory.insert(0, next);
        if (searchHistory.length > 6) searchHistory.removeLast();
      }
    });
    if (next.isEmpty) {
      creatorSearchRequest++;
      setState(() {
        creatorResults = const [];
        creatorSearchLoading = false;
        creatorSearchError = null;
      });
    } else {
      loadCreators(next);
    }
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
          (s) =>
              '${s.title} ${s.channel}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (selectedCategoryId == null ||
                  s.categoryId == selectedCategoryId),
        )
        .toList();
    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Khám phá'), pinned: true),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: updateQuery,
              onSubmitted: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm podcast, kênh, playlist',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          updateQuery('');
                        },
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
        ),
        if (widget.categories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String?>(
                value: selectedCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Chủ đề',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả chủ đề'),
                  ),
                  ...widget.categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value:
                          category['categoryId']?.toString() ??
                          category['id']?.toString(),
                      child: Text(category['name']?.toString() ?? ''),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => selectedCategoryId = value),
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
                    'Lịch sử tìm kiếm',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => setState(() => searchHistory.clear()),
                    child: const Text('Xóa lịch sử'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: searchHistory.isEmpty
                  ? const Text('Chưa có lịch sử tìm kiếm.')
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
                'Audio gợi ý',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _AudioResultTile(
                show: result[i],
                onOpen: () => widget.onOpen(result[i]),
              ),
              childCount: result.length,
            ),
          ),
        ] else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Kênh Creator',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (creatorSearchLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            )
          else if (creatorSearchError != null || creatorResults.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  creatorSearchError ?? 'Không tìm thấy kênh phù hợp.',
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final creator = creatorResults[i];
                final creatorId = creator['creatorProfileId']?.toString();
                final name =
                    creator['channelName']?.toString() ?? 'Content Creator';
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(name),
                    subtitle: Text(creator['description']?.toString() ?? ''),
                    onTap: creatorId == null
                        ? null
                        : () => widget.onOpenCreator(
                            Show(name, name, 'Creator', '', const [
                              Color(0xFF254A50),
                              Color(0xFF93B4A4),
                            ], creatorId: creatorId),
                          ),
                  ),
                );
              }, childCount: creatorResults.length),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                '${result.length} audio tìm thấy',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (result.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Không tìm thấy audio phù hợp.'),
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
        tooltip: 'Mở và phát',
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
    description: 'Những podcast bạn đã lưu để nghe sau',
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
        title: const Text('Tạo playlist mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên playlist'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              nameController.text.trim(),
              descriptionController.text.trim(),
            )),
            child: const Text('Tạo playlist'),
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
              ? 'Playlist cá nhân của bạn'
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
      const SliverAppBar(title: Text('Thư viện'), pinned: true),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'liked', label: Text('Đã thích')),
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
                  'Playlist của bạn',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.tonalIcon(
                  onPressed: createPlaylist,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo mới'),
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
                child: Text('Bạn chưa theo dõi Content Creator nào.'),
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
              tooltip: 'Mở playlist',
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
              ? 'Chưa có audio yêu thích'
              : 'Playlist này chưa có podcast',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Khám phá podcast mới và lưu lại để nghe sau.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () {},
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Khám phá podcast'),
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
        title: const Text('Chỉnh sửa playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên playlist'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              nameController.text.trim(),
              descriptionController.text.trim(),
            )),
            child: const Text('Lưu'),
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
              tooltip: 'Chỉnh sửa playlist',
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
                            tooltip: 'Đổi ảnh bìa',
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
                      label: const Text('Phát tất cả'),
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
                    tooltip: 'Phát ngẫu nhiên',
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
                          child: Text('Xóa khỏi playlist'),
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
    appBar: AppBar(title: const Text('Thông báo')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.mic_none),
          title: Text('Sử Việt kể chuyện đã đăng tập mới'),
          subtitle: Text('12 phút trước'),
        ),
        ListTile(
          leading: Icon(Icons.workspace_premium_outlined),
          title: Text('Bạn đã trở thành thành viên'),
          subtitle: Text('Hôm qua'),
        ),
        ListTile(
          leading: Icon(Icons.favorite_border),
          title: Text('Lan Anh đã thích bình luận của bạn'),
          subtitle: Text('2 ngày trước'),
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

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = '${json['type'] ?? ''}'.toUpperCase();
    final createdAt = DateTime.tryParse('${json['createdAt'] ?? ''}')
        ?.toLocal();
    final message = '${json['message'] ?? ''}'.trim();
    final time = _notificationTime(createdAt);
    return AppNotification(
      id: '${json['notificationId'] ?? ''}',
      title: '${json['title'] ?? 'Thông báo'}',
      subtitle: [message, time].where((item) => item.isNotEmpty).join(' • '),
      icon: type.contains('COMMENT') || type.contains('LIKE')
          ? Icons.favorite_border
          : type.contains('MEMBERSHIP')
          ? Icons.workspace_premium_outlined
          : type.contains('PODCAST')
          ? Icons.mic_none
          : Icons.notifications_none,
      read: json['read'] == true,
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    subtitle: subtitle,
    icon: icon,
    read: read ?? this.read,
  );
}

String _notificationTime(DateTime? createdAt) {
  if (createdAt == null) return '';
  final difference = DateTime.now().difference(createdAt);
  if (difference.inMinutes < 1) return 'Vừa xong';
  if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
  if (difference.inDays < 1) return '${difference.inHours} giờ trước';
  if (difference.inDays < 7) return '${difference.inDays} ngày trước';
  return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
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
            'Không có thông báo.',
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
                  tooltip: 'Về trang chủ',
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                const Text(
                  'Thông báo',
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
                  tooltip: 'Đánh dấu đã đọc',
                  icon: const Icon(Icons.done_all),
                ),
              ],
            ),
            section('Chưa đọc', unread),
            section('Đã đọc', read),
          ],
        ),
      ),
    );
  }
}

class LivestreamPage extends StatelessWidget {
  const LivestreamPage({super.key, required this.api});

  final ListenerApi api;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Livestream')),
    body: ListenerLivestreamScreen(api: api),
  );
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
    title: 'Ví của bạn',
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Số dư VietCast'),
              Text(
                _formatVnd(balance),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text('Dùng để ủng hộ creator và đăng ký membership'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onTopUp,
                icon: const Icon(Icons.add_card),
                label: const Text('Nạp tiền'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Giao dịch gần đây'),
      const Transaction(
        title: 'Membership VietCast Originals',
        amount: '-79.000 VND',
      ),
      const Transaction(title: 'Nạp tiền vào ví', amount: '+200.000 VND'),
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
    appBar: AppBar(title: const Text('Cá nhân')),
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
        const Center(child: Text('Người nghe lịch sử Việt Nam')),
        const SizedBox(height: 20),
        Setting(
          icon: Icons.account_circle_outlined,
          title: 'Hồ sơ của tôi',
          subtitle: 'Xem và chỉnh sửa thông tin, đổi mật khẩu',
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
          title: 'Đăng ký làm Creator',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreatorRegistrationScreen(),
            ),
          ),
        ),
        Setting(
          icon: Icons.dark_mode_outlined,
          title: 'Giao diện tối',
          onTap: onTheme,
        ),
        Setting(icon: Icons.logout, title: 'Đăng xuất', onTap: onLogout),
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
    _message('API hiện tại chưa cung cấp endpoint cập nhật hồ sơ.');
  }

  Future<void> _changePassword() async {
    _message('API hiện tại chưa cung cấp endpoint đổi mật khẩu.');
  }

  InputDecoration _decoration(String label, {Widget? suffix}) =>
      InputDecoration(labelText: label, suffixIcon: suffix);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ của tôi')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Thông tin cá nhân',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: displayNameController,
          decoration: _decoration('Tên hiển thị'),
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
          decoration: _decoration('Giới thiệu'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: savingProfile ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(savingProfile ? 'Đang lưu...' : 'Lưu thay đổi'),
          ),
        ),
        const Divider(height: 40),
        Text('Bảo mật', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: currentPasswordController,
          obscureText: obscureCurrent,
          decoration: _decoration(
            'Mật khẩu hiện tại',
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
            'Mật khẩu mới',
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
          decoration: _decoration('Xác nhận mật khẩu mới'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: changingPassword ? null : _changePassword,
            icon: const Icon(Icons.lock_reset_outlined),
            label: Text(changingPassword ? 'Đang cập nhật...' : 'Đổi mật khẩu'),
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
            'Vui lòng điền đầy đủ thông tin đăng ký.',
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
      if (mounted) setState(() => error = 'Không thể kết nối đến máy chủ API.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: register ? 'Đăng ký VietCast' : 'Đăng nhập VietCast',
    children: [
      const Icon(Icons.mic_external_on, size: 56, color: Color(0xFFB3261E)),
      Text(
        register ? 'Tạo tài khoản VietCast' : 'Chào mừng bạn trở lại',
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
          decoration: const InputDecoration(labelText: 'Tên hiển thị'),
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: emailController,
        keyboardType: register
            ? TextInputType.emailAddress
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: register ? 'Email' : 'Username hoặc email',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        decoration: InputDecoration(
          labelText: 'Mật khẩu',
          suffixIcon: IconButton(
            tooltip: obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
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
      const SizedBox(height: 20),
      FilledButton(
        onPressed: loading ? null : submit,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(register ? 'Đăng ký' : 'Đăng nhập'),
      ),
      TextButton(
        onPressed: () => setState(() => register = !register),
        child: Text(register ? 'Đã có tài khoản?' : 'Chưa có tài khoản?'),
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
        label: const Text('Đăng podcast'),
      ),
      const SizedBox(height: 16),
      ...shows
          .take(3)
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Art(show: s, size: 56),
              title: Text(s.title),
              subtitle: Text('Đã đăng • ${s.duration}'),
              trailing: const Chip(label: Text('Đã đăng')),
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
          'Tạo podcast mới',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const TextField(decoration: InputDecoration(labelText: 'Tieu de')),
        const SizedBox(height: 12),
        const TextField(
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Mô tả'),
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
          child: const Text('Lưu bản nháp'),
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
                'Kể chuyện về Đổi Mới',
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
        label: const Text('Mở chat'),
      ),
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Tạo yêu cầu mới'),
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
              const Text('Đang chờ giải ngân: 3.200.000 VND'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: pending
                    ? null
                    : () => setState(() => pending = true),
                icon: const Icon(Icons.account_balance),
                label: Text(pending ? 'Đang xử lý...' : 'Rút tiền'),
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
    subtitle: const Text('Đang xử lý'),
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
          Metric(label: 'Báo cáo', value: '7'),
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
                'Nội dung độc quyền\nGửi yêu cầu podcast\nHuy hiệu thành viên',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: paid ? null : () => setState(() => paid = true),
                child: Text(paid ? 'Đã là thành viên' : 'Đăng ký membership'),
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
              tooltip: playing ? 'Tạm dừng' : 'Phát',
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
    required this.api,
    required this.audioPlayer,
    required this.displayName,
    required this.playing,
    required this.initialProgress,
    required this.initialLiked,
    required this.initialLikeCount,
    required this.initialCommentCount,
    required this.initialSaved,
    this.initialComments,
    this.loadComments,
    required this.onProgressChanged,
    required this.onSeek,
    this.onComment,
    required this.onLikedChanged,
    required this.onCommentLike,
    required this.onSavedChanged,
    required this.onReport,
    required this.onMembership,
    required this.onCreatorProfile,
    required this.onToggle,
  });
  final Show show;
  final ListenerApi api;
  final AudioPlayer audioPlayer;
  final String displayName;
  final bool playing;
  final double initialProgress;
  final bool initialLiked;
  final int initialLikeCount;
  final int initialCommentCount;
  final bool initialSaved;
  final List<CommentData>? initialComments;
  final Future<List<CommentData>> Function()? loadComments;
  final ValueChanged<double> onProgressChanged;
  final Future<void> Function(Duration) onSeek;
  final Future<CommentData> Function(String, int)? onComment;
  final Future<CommentData> Function(CommentData) onCommentLike;
  final ValueChanged<bool> onLikedChanged, onSavedChanged;
  final VoidCallback onReport, onMembership, onCreatorProfile;
  final VoidCallback onToggle;

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late bool playing = widget.playing;
  late double progress = widget.initialProgress;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<void>? _completeSubscription;
  late bool liked = widget.initialLiked;
  late int likeCount = widget.initialLikeCount;
  late int commentCount = widget.initialCommentCount;
  final commentController = TextEditingController();
  late final comments = List<CommentData>.of(
    widget.initialComments ?? const [],
  );
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.audioPlayer.onPositionChanged.listen((
      value,
    ) {
      if (!mounted) return;
      setState(() {
        position = value;
        progress = _progressFor(value, duration);
      });
    });
    _durationSubscription = widget.audioPlayer.onDurationChanged.listen((
      value,
    ) {
      if (!mounted) return;
      setState(() {
        duration = value;
        progress = _progressFor(position, value);
      });
    });
    _playerStateSubscription = widget.audioPlayer.onPlayerStateChanged.listen((
      value,
    ) {
      if (!mounted) return;
      setState(() => playing = value == PlayerState.playing);
    });
    _completeSubscription = widget.audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        position = duration;
        progress = 1;
        playing = false;
      });
    });
    unawaited(_loadComments());
  }

  double _progressFor(Duration current, Duration total) {
    if (total.inMilliseconds <= 0) return progress;
    return (current.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
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
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _completeSubscription?.cancel();
    widget.onProgressChanged(_currentProgress);
    commentController.dispose();
    super.dispose();
  }

  void setProgress(double value) {
    final next = value.clamp(0.0, 1.0);
    final total = _effectiveDuration;
    final nextPosition = total > Duration.zero
        ? Duration(milliseconds: (total.inMilliseconds * next).round())
        : Duration.zero;
    setState(() {
      progress = next;
      position = nextPosition;
    });
    widget.onProgressChanged(next);
    if (total > Duration.zero) {
      unawaited(widget.onSeek(nextPosition));
    }
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
    final seconds = (_currentProgress * _effectiveDuration.inSeconds).floor();
    setState(() => _sendingComment = true);
    try {
      final saved = await send(text.trim(), seconds);
      if (!mounted) return false;
      setState(() {
        comments.removeWhere((comment) => comment.id == saved.id);
        comments.insert(0, saved);
        commentCount = commentCount < comments.length
            ? comments.length
            : commentCount + 1;
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

  Duration get _effectiveDuration =>
      duration > Duration.zero ? duration : Duration(seconds: _durationSeconds);

  double get _currentProgress {
    if (duration > Duration.zero) {
      return _progressFor(position, duration);
    }
    return progress;
  }

  String get _timestamp {
    final seconds = duration > Duration.zero
        ? position.inSeconds
        : (progress * _durationSeconds).floor();
    return _formatDuration(seconds);
  }

  String _formatDuration(num seconds) {
    final wholeSeconds = seconds.round();
    return '${(wholeSeconds ~/ 60).toString().padLeft(2, '0')}:${(wholeSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _formatCount(int value) {
    if (value < 1000) return '$value';
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K';
  }

  CommentData? get timelineComment {
    final nearby = comments
        .where(
          (comment) =>
              comment.time.isNotEmpty &&
              (comment.positionForDuration(_effectiveDuration.inSeconds) -
                          _currentProgress)
                      .abs() <=
                  .04,
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
    builder: (_) => CommentsPanel(
      comments: comments,
      onSubmit: addComment,
      onLike: _toggleCommentLike,
    ),
  );

  Future<CommentData> _toggleCommentLike(CommentData comment) async {
    final updated = await widget.onCommentLike(comment);
    if (!mounted) return updated;
    setState(() {
      final index = comments.indexWhere((item) => item.id == updated.id);
      if (index >= 0) comments[index] = updated;
    });
    return updated;
  }

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
      title: const Text('Chia sẻ podcast'),
      content: SelectableText(
        'https://vietcast.local/podcast/${widget.show.title.toLowerCase().replaceAll(' ', '-')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã sao chép đường dẫn chia sẻ.')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Sao chép'),
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
      loadTranscript: widget.show.id == null
          ? null
          : () => widget.api.podcastTranscript(widget.show.id!),
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
                  tooltip: 'Thu nhỏ',
                  color: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                const Text(
                  'Đang phát',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  tooltip: 'Thêm tùy chọn',
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
                  _formatDuration(_effectiveDuration.inSeconds),
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
                    child: Waveform(progress: _currentProgress),
                  ),
                  if (timelineComment != null)
                    Positioned(
                      left:
                          (constraints.maxWidth *
                                  timelineComment!.positionForDuration(
                                    _effectiveDuration.inSeconds,
                                  ))
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
                value: _currentProgress,
                min: 0,
                max: 1,
                onChanged: setProgress,
                semanticFormatterCallback: (value) =>
                    'Vị trí phát ${_formatDuration(value * _effectiveDuration.inSeconds)}',
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
                  tooltip: playing ? 'Tạm dừng' : 'Phát',
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
                  label: _formatCount(likeCount),
                  active: liked,
                  onTap: () {
                    setState(() {
                      liked = !liked;
                      likeCount += liked ? 1 : -1;
                      if (likeCount < 0) likeCount = 0;
                    });
                    widget.onLikedChanged(liked);
                  },
                ),
                _PlayerAction(
                  icon: Icons.chat_bubble_outline,
                  label: _formatCount(commentCount),
                  onTap: _showComments,
                ),
                _PlayerAction(
                  icon: Icons.ios_share,
                  label: 'Chia sẻ',
                  onTap: _showShare,
                ),
                _PlayerAction(
                  icon: Icons.playlist_add,
                  label: 'Lưu',
                  onTap: _showPlaylist,
                ),
                _PlayerAction(
                  icon: Icons.more_horiz,
                  label: 'Thêm',
                  onTap: _showMore,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white24),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Bình luận theo thời gian',
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
                likeCount: comment.likeCount,
                likedByMe: comment.likedByMe,
                onLike: () => _toggleCommentLike(comment),
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
          tooltip: 'Gửi bình luận',
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
    this.likeCount = 0,
    this.likedByMe = false,
  });
  final String name, text, time;
  final String? id;
  final int durationSeconds;
  final int likeCount;
  final bool likedByMe;

  CommentData copyWith({int? likeCount, bool? likedByMe}) => CommentData(
    name,
    text,
    time,
    id: id,
    durationSeconds: durationSeconds,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
  );

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
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
    );
  }

  double get position {
    return positionForDuration(durationSeconds);
  }

  double positionForDuration(int actualDurationSeconds) {
    final parts = time.split(':');
    final seconds = parts.fold<int>(
      0,
      (total, part) => total * 60 + (int.tryParse(part) ?? 0),
    );
    return actualDurationSeconds <= 0
        ? 0
        : (seconds / actualDurationSeconds).clamp(0.0, 1.0);
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
    required this.onLike,
  });
  final List<CommentData> comments;
  final Future<bool> Function(String) onSubmit;
  final Future<CommentData> Function(CommentData) onLike;

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
            'Bình luận',
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
                      likeCount: comment.likeCount,
                      likedByMe: comment.likedByMe,
                      onLike: () => widget.onLike(comment),
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

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ListTile(
          title: Text(
            'Lưu vào playlist',
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
          title: const Text('Nghe sau', style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            'Lưu để quay lại sau',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.add, color: Colors.white),
          title: const Text(
            'Tạo playlist mới',
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
  String reason = 'Nội dung sai sự thật';
  final customController = TextEditingController();
  static const reasons = [
    'Nội dung sai sự thật',
    'Vi phạm bản quyền',
    'Ngôn từ không phù hợp',
    'Spam hoặc quảng cáo',
    'Khác',
  ];

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  void submit() {
    final report = reason == 'Khác' ? customController.text.trim() : reason;
    if (report.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung báo cáo.')),
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
            'Báo cáo podcast',
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
          if (reason == 'Khác') ...[
            const SizedBox(height: 12),
            TextField(
              controller: customController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Viết nội dung bạn muốn báo cáo cho admin...',
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
              label: const Text('Gửi báo cáo cho admin'),
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
  bool isMember = false;

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
      final results = await Future.wait<dynamic>([
        widget.api.follows(size: 100),
        widget.api.subscriptions(),
      ]);
      final follows = results[0] as List<Map<String, dynamic>>;
      final subscriptions = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        following = follows.any(
          (item) => '${item['creatorProfileId']}' == creatorId,
        );
        isMember = subscriptions.any(
          (item) =>
              '${item['creatorProfileId']}' == creatorId &&
              '${item['status']}'.toUpperCase() == 'ACTIVE',
        );
        loadingFollow = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingFollow = false);
    }
  }

  Future<void> _showRequestDialog() async {
    final creatorId = widget.show.creatorId;
    if (creatorId == null) return;
    if (!isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần là thành viên của kênh để gửi yêu cầu.'),
        ),
      );
      return;
    }
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yêu cầu audio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Chủ đề / tiêu đề audio',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Mô tả yêu cầu',
                  hintText: 'Bạn muốn Creator làm nội dung gì?',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              titleController.text.trim(),
              descriptionController.text.trim(),
            )),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    if (!mounted || result == null) return;
    if (result.$1.isEmpty || result.$2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ chủ đề và mô tả.')),
      );
      return;
    }
    try {
      await widget.api.createSeriesRequest(
        creatorId,
        requestedTitle: result.$1,
        description: result.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu audio tới Creator.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể gửi yêu cầu: $error')));
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
            following ? 'Đã theo dõi creator.' : 'Đã bỏ theo dõi creator.',
          ),
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      setState(() => loadingFollow = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật theo dõi: $exception')),
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
                      'Content creator lịch sử Việt Nam',
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
              label: Text(following ? 'Đang theo dõi' : 'Theo dõi creator'),
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
              label: const Text('Đăng ký gói thành viên'),
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
              onPressed: loadingFollow || widget.show.creatorId == null
                  ? null
                  : _showRequestDialog,
              icon: const Icon(Icons.record_voice_over_outlined),
              label: const Text('Gửi yêu cầu'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Audio đã đăng',
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
            'Playlist của creator',
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
              'Lịch sử Việt Nam',
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
              'Tuyển tập nổi bật',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Playlist công khai',
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
    this.loadTranscript,
    required this.onReport,
    required this.onMembership,
    required this.onCreatorProfile,
  });
  final Show show;
  final Future<Map<String, dynamic>> Function()? loadTranscript;
  final VoidCallback onReport, onMembership, onCreatorProfile;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.white),
          title: const Text(
            'Thông tin podcast',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Series, mô tả, chủ đề và script',
            style: TextStyle(color: Colors.white60),
          ),
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              backgroundColor: const Color(0xFF181818),
              builder: (_) =>
                  PodcastInfoPanel(show: show, loadTranscript: loadTranscript),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.white),
          title: const Text(
            'Báo cáo podcast',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            Navigator.pop(context);
            onReport();
          },
        ),
        if (kPackagesEnabled)
          ListTile(
            leading: const Icon(
              Icons.workspace_premium_outlined,
              color: Colors.white,
            ),
            title: const Text(
              'Đăng ký thành viên',
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
            'Xem hồ sơ Content Creator',
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

class PodcastInfoPanel extends StatefulWidget {
  const PodcastInfoPanel({super.key, required this.show, this.loadTranscript});
  final Show show;
  final Future<Map<String, dynamic>> Function()? loadTranscript;

  @override
  State<PodcastInfoPanel> createState() => _PodcastInfoPanelState();
}

class _PodcastInfoPanelState extends State<PodcastInfoPanel> {
  late final Future<Map<String, dynamic>>? transcriptFuture = widget
      .loadTranscript
      ?.call();
  bool _isTranscriptExpanded = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .35,
      maxChildSize: .92,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Thông tin podcast',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _PodcastInfoRow(
            icon: Icons.queue_music_outlined,
            label: 'Series',
            value: widget.show.seriesTitle?.isNotEmpty == true
                ? widget.show.seriesTitle!
                : 'Podcast độc lập',
          ),
          _PodcastInfoRow(
            icon: Icons.short_text,
            label: 'Mô tả ngắn',
            value: widget.show.description.isNotEmpty
                ? widget.show.description
                : 'Chưa có mô tả.',
          ),
          _PodcastInfoRow(
            icon: Icons.category_outlined,
            label: 'Chủ đề và thể loại',
            value: widget.show.categoryName.isNotEmpty
                ? widget.show.categoryName
                : 'Chưa xác định',
          ),
          const SizedBox(height: 14),
          const Text(
            'Script của podcast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (transcriptFuture == null)
            const Text(
              'Chưa có script cho podcast này.',
              style: TextStyle(color: Colors.white70),
            )
          else
            FutureBuilder<Map<String, dynamic>>(
              future: transcriptFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text(
                    'Script chưa sẵn sàng.',
                    style: TextStyle(color: Colors.white70),
                  );
                }
                final transcript = snapshot.data?['fullText']?.toString() ?? '';
                final status = snapshot.data?['status']?.toString() ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transcript.isNotEmpty
                          ? transcript
                          : (status.isNotEmpty
                                ? 'Script đang được xử lý ($status).'
                                : 'Chưa có nội dung script.'),
                      maxLines: _isTranscriptExpanded ? null : 5,
                      overflow: _isTranscriptExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                    if (transcript.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(
                          () => _isTranscriptExpanded = !_isTranscriptExpanded,
                        ),
                        child: Text(
                          _isTranscriptExpanded ? 'Thu gọn' : 'Mở rộng',
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
}

class _PodcastInfoRow extends StatelessWidget {
  const _PodcastInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
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
    this.likeCount = 0,
    this.likedByMe = false,
    this.onLike,
  });
  final String name, text, time;
  final int likeCount;
  final bool likedByMe;
  final Future<CommentData> Function()? onLike;
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
        trailing: _CommentLikeButton(
          likeCount: likeCount,
          likedByMe: likedByMe,
          onLike: onLike,
          color: mutedForeground,
        ),
      ),
    );
  }
}

class _CommentLikeButton extends StatefulWidget {
  const _CommentLikeButton({
    required this.likeCount,
    required this.likedByMe,
    required this.onLike,
    required this.color,
  });
  final int likeCount;
  final bool likedByMe;
  final Future<CommentData> Function()? onLike;
  final Color color;

  @override
  State<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<_CommentLikeButton> {
  late bool liked = widget.likedByMe;
  late int count = widget.likeCount;
  bool pending = false;

  @override
  void didUpdateWidget(covariant _CommentLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!pending) {
      liked = widget.likedByMe;
      count = widget.likeCount;
    }
  }

  Future<void> toggle() async {
    final action = widget.onLike;
    if (action == null || pending) return;
    setState(() => pending = true);
    try {
      final updated = await action();
      if (mounted) {
        setState(() {
          liked = updated.likedByMe;
          count = updated.likeCount;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KhĂ´ng thá»ƒ cáº­p nháº­t like: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: pending ? null : toggle,
        tooltip: liked ? 'Bỏ thích' : 'Thích bình luận',
        icon: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? Colors.deepOrange : widget.color,
          size: 20,
        ),
      ),
      if (count > 0)
        Text('$count', style: TextStyle(color: widget.color, fontSize: 12)),
    ],
  );
}
