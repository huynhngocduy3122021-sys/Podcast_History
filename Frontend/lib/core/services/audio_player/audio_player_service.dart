import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class AudioPlaybackState {
  final String? podcastId;
  final CreatorPodcast? podcast;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isLoading;
  final double progress; // 0.0 -> 1.0

  const AudioPlaybackState({
    this.podcastId,
    this.podcast,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isLoading = false,
    this.progress = 0.0,
  });

  AudioPlaybackState copyWith({
    String? podcastId,
    CreatorPodcast? podcast,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isLoading,
    double? progress,
  }) {
    return AudioPlaybackState(
      podcastId: podcastId ?? this.podcastId,
      podcast: podcast ?? this.podcast,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
    );
  }
}

class AudioPlayerNotifier extends Notifier<AudioPlaybackState> {
  late final AudioPlayer _player;
  final Map<String, Uint8List> _cachedBytes = {};
  final Map<String, Duration> _knownDurations = {};
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  @override
  AudioPlaybackState build() {
    _player = AudioPlayer();
    _initListeners();
    ref.onDispose(() {
      _posSub?.cancel();
      _durSub?.cancel();
      _stateSub?.cancel();
      _completeSub?.cancel();
      _player.dispose();
    });
    return const AudioPlaybackState();
  }

  void _initListeners() {
    _posSub = _player.onPositionChanged.listen((pos) {
      final dur = state.duration.inMilliseconds > 0 ? state.duration : const Duration(seconds: 1);
      final frac = (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
      state = state.copyWith(position: pos, progress: frac);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (dur.inMilliseconds > 0) {
        if (state.podcastId != null) {
          _knownDurations[state.podcastId!] = dur;
        }
        final frac = (state.position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
        state = state.copyWith(duration: dur, progress: frac);
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((playerState) {
      final isPlaying = playerState == PlayerState.playing;
      state = state.copyWith(isPlaying: isPlaying, isLoading: false);
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      state = state.copyWith(
        isPlaying: false,
        position: Duration.zero,
        progress: 0.0,
      );
    });
  }

  void cacheBytes(String podcastId, List<int> bytes) {
    final u8 = Uint8List.fromList(bytes);
    _cachedBytes[podcastId] = u8;
    probeDuration(podcastId, bytes: u8);
  }

  Uint8List? getCachedBytes(String podcastId) => _cachedBytes[podcastId];

  Duration? getKnownDuration(String podcastId) => _knownDurations[podcastId];

  void setKnownDuration(String podcastId, Duration duration) {
    if (duration > Duration.zero) {
      _knownDurations[podcastId] = duration;
    }
  }

  Future<Duration?> probeDuration(String podcastId, {String? url, List<int>? bytes}) async {
    if (_knownDurations.containsKey(podcastId) && _knownDurations[podcastId]! > Duration.zero) {
      return _knownDurations[podcastId];
    }
    final cached = bytes ?? _cachedBytes[podcastId];
    AudioPlayer? probePlayer;
    try {
      probePlayer = AudioPlayer();
      final completer = Completer<Duration?>();
      final sub = probePlayer.onDurationChanged.listen((d) {
        if (!completer.isCompleted && d.inMilliseconds > 0) {
          completer.complete(d);
        }
      });

      if (cached != null && cached.isNotEmpty) {
        await probePlayer.setSource(BytesSource(Uint8List.fromList(cached)));
      } else if (url != null && url.isNotEmpty) {
        await probePlayer.setSource(UrlSource(url));
      } else {
        await sub.cancel();
        await probePlayer.dispose();
        return null;
      }

      final detected = await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => probePlayer?.getDuration(),
      );

      await sub.cancel();
      await probePlayer.dispose();

      if (detected != null && detected > Duration.zero) {
        _knownDurations[podcastId] = detected;
        return detected;
      }
    } catch (_) {
      try {
        await probePlayer?.dispose();
      } catch (_) {}
    }
    return null;
  }

  Future<Duration?> resolveDurationForPodcast(CreatorPodcast podcast) async {
    if (_knownDurations.containsKey(podcast.id) && _knownDurations[podcast.id]! > Duration.zero) {
      return _knownDurations[podcast.id];
    }

    if (_cachedBytes.containsKey(podcast.id)) {
      return probeDuration(podcast.id, bytes: _cachedBytes[podcast.id]);
    }

    if (podcast.videoUrl != null && podcast.videoUrl!.startsWith('http')) {
      return probeDuration(podcast.id, url: podcast.videoUrl);
    }

    try {
      final detail = await ref.read(creatorRepositoryProvider).getPodcastById(podcast.id);
      if (detail?.videoUrl != null && detail!.videoUrl!.startsWith('http')) {
        return await probeDuration(podcast.id, url: detail.videoUrl);
      }
    } catch (_) {}

    return null;
  }

  Future<void> togglePlay(CreatorPodcast podcast, {List<int>? fileBytes}) async {
    if (state.podcastId == podcast.id) {
      if (state.isPlaying) {
        await pause();
      } else {
        await resume();
      }
    } else {
      await play(podcast, fileBytes: fileBytes);
    }
  }

  Future<void> play(CreatorPodcast podcast, {List<int>? fileBytes}) async {
    final knownDur = _knownDurations[podcast.id];
    final effectiveDur = (knownDur != null && knownDur > Duration.zero)
        ? knownDur
        : (podcast.duration.inSeconds > 0 ? podcast.duration : Duration.zero);

    state = state.copyWith(
      podcastId: podcast.id,
      podcast: podcast,
      isLoading: true,
      duration: effectiveDur,
      position: Duration.zero,
      progress: 0.0,
    );

    if (fileBytes != null && fileBytes.isNotEmpty) {
      _cachedBytes[podcast.id] = Uint8List.fromList(fileBytes);
    }

    try {
      final cached = _cachedBytes[podcast.id];
      if (cached != null && cached.isNotEmpty) {
        await _player.stop();
        await _player.play(BytesSource(cached));
        return;
      }

      String? remoteUrl = (podcast.videoUrl?.isNotEmpty == true && podcast.videoUrl!.startsWith('http'))
          ? podcast.videoUrl
          : null;

      if (remoteUrl == null) {
        try {
          final detail = await ref.read(creatorRepositoryProvider).getPodcastById(podcast.id);
          if (detail?.videoUrl?.isNotEmpty == true && detail!.videoUrl!.startsWith('http')) {
            remoteUrl = detail.videoUrl;
          }
        } catch (_) {}
      }

      if (remoteUrl != null) {
        await _player.stop();
        await _player.play(UrlSource(remoteUrl));
        return;
      }

      state = state.copyWith(isLoading: false, isPlaying: false);
      throw Exception('Tập podcast này chưa có tệp âm thanh trên máy chủ.');
    } catch (e) {
      state = state.copyWith(isLoading: false, isPlaying: false);
      rethrow;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    await _player.resume();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    final dur = state.duration.inMilliseconds > 0 ? state.duration : const Duration(seconds: 1);
    final frac = (position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    state = state.copyWith(position: position, progress: frac);
  }

  Future<void> seekFraction(double fraction) async {
    final targetMs = (state.duration.inMilliseconds * fraction.clamp(0.0, 1.0)).toInt();
    await seek(Duration(milliseconds: targetMs));
  }

  Future<void> seekBySeconds(int seconds) async {
    final nextMs = (state.position.inMilliseconds + seconds * 1000).clamp(0, state.duration.inMilliseconds);
    await seek(Duration(milliseconds: nextMs));
  }
}

final audioPlayerServiceProvider = NotifierProvider<AudioPlayerNotifier, AudioPlaybackState>(
  AudioPlayerNotifier.new,
);
