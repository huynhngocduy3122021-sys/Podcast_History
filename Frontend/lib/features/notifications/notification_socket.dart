import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

typedef NotificationMessageHandler = void Function(
  Map<String, dynamic> notification,
);

class NotificationSocket {
  NotificationSocket({
    required this.url,
    required this.accessToken,
    required this.onNotification,
    required this.onRealtime,
    required this.onReconnected,
  });

  final String url;
  final NotificationMessageHandler onNotification;
  final NotificationMessageHandler onRealtime;
  final void Function() onReconnected;
  String accessToken;
  late final StompClient _client = StompClient(
    config: StompConfig(
      url: url,
      reconnectDelay: const Duration(seconds: 5),
      stompConnectHeaders: {'Authorization': 'Bearer $accessToken'},
      onConnect: _onConnect,
      onWebSocketError: (_) {},
      onStompError: (_) {},
    ),
  );
  StompUnsubscribe? _unsubscribe;
  final _topicHandlers = <String, NotificationMessageHandler>{};
  final _topicSubscriptions = <String, StompUnsubscribe>{};
  final _realtimeListeners = <NotificationMessageHandler>[];
  final _reconnectListeners = <void Function()>[];
  bool _connectedOnce = false;

  void connect() => _client.activate();

  void updateAccessToken(String accessToken) {
    this.accessToken = accessToken;
    _client.config.stompConnectHeaders?['Authorization'] =
        'Bearer $accessToken';
  }

  void listen(String destination, NotificationMessageHandler handler) {
    _topicHandlers[destination] = handler;
    if (_client.connected) _subscribeTopic(destination);
  }

  void Function() addRealtimeListener(NotificationMessageHandler handler) {
    _realtimeListeners.add(handler);
    return () => _realtimeListeners.remove(handler);
  }

  void Function() addReconnectListener(void Function() handler) {
    _reconnectListeners.add(handler);
    return () => _reconnectListeners.remove(handler);
  }

  void unlisten(String destination) {
    _topicHandlers.remove(destination);
    _topicSubscriptions.remove(destination)?.call();
  }

  void _onConnect(StompFrame _) {
    _unsubscribe?.call();
    _unsubscribe = _client.subscribe(
      destination: '/user/queue/notifications',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;
        try {
          final value = jsonDecode(body);
          if (value is Map) {
            onNotification(Map<String, dynamic>.from(value));
          }
        } catch (_) {
          // Ignore malformed events; REST remains the source of truth.
        }
      },
    );
    _client.subscribe(
      destination: '/user/queue/realtime',
      callback: (frame) {
        _dispatch(frame, onRealtime);
        final body = frame.body;
        if (body == null || body.isEmpty) return;
        try {
          final value = jsonDecode(body);
          if (value is Map) {
            final event = Map<String, dynamic>.from(value);
            for (final listener in List.of(_realtimeListeners)) {
              listener(event);
            }
          }
        } catch (_) {}
      },
    );
    for (final destination in _topicHandlers.keys) {
      _subscribeTopic(destination);
    }
    if (_connectedOnce) {
      onReconnected();
      for (final listener in List.of(_reconnectListeners)) {
        listener();
      }
    }
    _connectedOnce = true;
  }

  void _subscribeTopic(String destination) {
    _topicSubscriptions.remove(destination)?.call();
    final handler = _topicHandlers[destination];
    if (handler == null) return;
    _topicSubscriptions[destination] = _client.subscribe(
      destination: destination,
      callback: (frame) => _dispatch(frame, handler),
    );
  }

  void _dispatch(StompFrame frame, NotificationMessageHandler handler) {
    final body = frame.body;
    if (body == null || body.isEmpty) return;
    try {
      final value = jsonDecode(body);
      if (value is Map) handler(Map<String, dynamic>.from(value));
    } catch (_) {}
  }

  void dispose() {
    _unsubscribe?.call();
    for (final subscription in _topicSubscriptions.values) {
      subscription.call();
    }
    _topicSubscriptions.clear();
    _client.deactivate();
  }
}
