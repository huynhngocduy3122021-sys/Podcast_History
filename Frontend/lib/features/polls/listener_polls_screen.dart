import 'package:flutter/material.dart';
import 'package:podcast_history/api_service.dart';
import 'package:podcast_history/core/widgets/top_notification.dart';

class ListenerPollsScreen extends StatefulWidget {
  const ListenerPollsScreen({super.key, required this.api});

  final ListenerApi api;

  @override
  State<ListenerPollsScreen> createState() => _ListenerPollsScreenState();
}

class _ListenerPollsScreenState extends State<ListenerPollsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _polls = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final creators = await widget.api.creators();
      final creatorIds = creators
          .map(
            (creator) =>
                creator['creatorProfileId']?.toString() ??
                creator['profileId']?.toString() ??
                creator['id']?.toString(),
          )
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final pollLists = await Future.wait(
        creatorIds.map((creatorId) => widget.api.listenerPolls(creatorId)),
      );
      final polls = pollLists.expand((items) => items).toList();
      final seen = <String>{};
      polls.removeWhere((poll) {
        final pollId = poll['pollId']?.toString() ?? '';
        return pollId.isEmpty || !seen.add(pollId);
      });
      polls.sort((a, b) => '${b['createdAt'] ?? ''}'.compareTo(
            '${a['createdAt'] ?? ''}',
          ));

      if (mounted) {
        setState(() {
          _polls = polls;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bình Chọn từ các Creator',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text('Bình chọn để góp ý cho nội dung của cộng đồng.'),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _PollStateCard(
            icon: Icons.cloud_off,
            message: 'Không thể tải danh sách bình chọn.\n$_error',
            action: TextButton(onPressed: _load, child: const Text('Thử lại')),
          )
        else if (_polls.isEmpty)
          const _PollStateCard(
            icon: Icons.poll_outlined,
            message: 'Hiện chưa có bình chọn nào từ các Creator.',
          )
        else
          ..._polls.map(
            (poll) => _ListenerPollCard(api: widget.api, poll: poll),
          ),
      ],
    ),
  );
}

class _ListenerPollCard extends StatefulWidget {
  const _ListenerPollCard({required this.api, required this.poll});

  final ListenerApi api;
  final Map<String, dynamic> poll;

  @override
  State<_ListenerPollCard> createState() => _ListenerPollCardState();
}

class _ListenerPollCardState extends State<_ListenerPollCard> {
  late Map<String, dynamic> _poll = Map<String, dynamic>.from(widget.poll);
  String? _selectedOptionId;
  bool _loading = false;
  bool _loadingDetails = false;
  bool _loadingResults = false;
  bool _showResults = false;
  Map<String, dynamic>? _results;

  String get _pollId => _poll['pollId']?.toString() ?? '';

  List<Map<String, dynamic>> get _options => (_poll['options'] is List)
      ? (_poll['options'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : const [];

  bool get _isOpen {
    final status = '${_poll['status'] ?? ''}'.toUpperCase();
    return _poll['acceptingResponses'] == true || status == 'OPEN';
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_pollId.isEmpty) return;
    setState(() => _loadingDetails = true);
    try {
      final detail = await widget.api.listenerPoll(_pollId);
      String? selected;
      try {
        final response = await widget.api.myListenerPollResponse(_pollId);
        selected = response['optionId']?.toString();
      } catch (_) {
        // Chưa bình chọn là trạng thái bình thường.
      }
      if (mounted) {
        setState(() {
          _poll = {..._poll, ...detail};
          _selectedOptionId = selected;
          _loadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _vote(String optionId) async {
    if (!_isOpen || _loading || optionId.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (_selectedOptionId == null) {
        await widget.api.answerListenerPoll(_pollId, optionId);
      } else {
        await widget.api.changeListenerPollAnswer(_pollId, optionId);
      }
      if (!mounted) return;
      setState(() {
        _selectedOptionId = optionId;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('Đã ghi nhận bình chọn của bạn.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(content: Text('Không thể bình chọn: $error')),
      );
    }
  }

  Future<void> _toggleResults() async {
    if (_showResults) {
      setState(() => _showResults = false);
      return;
    }
    setState(() => _loadingResults = true);
    try {
      final results = await widget.api.listenerPollResults(_pollId);
      if (!mounted) return;
      setState(() {
        _results = results;
        _showResults = true;
        _loadingResults = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingResults = false);
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(content: Text('Không thể tải kết quả bình chọn: $error')),
      );
    }
  }

  Future<void> _withdrawVote() async {
    if (_selectedOptionId == null || _loading) return;
    setState(() => _loading = true);
    try {
      await widget.api.withdrawListenerPollResponse(_pollId);
      if (!mounted) return;
      setState(() {
        _selectedOptionId = null;
        _loading = false;
        _results = null;
        _showResults = false;
      });
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('Đã rút bình chọn.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(content: Text('Không thể rút bình chọn: $error')),
      );
    }
  }

  Widget _buildResults() {
    final resultOptions = _results?['options'];
    if (resultOptions is! List) return const SizedBox.shrink();
    final total = (_results?['totalResponses'] as num?)?.toInt() ?? 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kết quả ($total lượt bình chọn)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...resultOptions.whereType<Map>().map((rawOption) {
            final option = Map<String, dynamic>.from(rawOption);
            final percentage =
                (option['percentage'] as num?)?.toDouble() ?? 0;
            final count = (option['responseCount'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${option['text'] ?? ''}')),
                      Text('${percentage.toStringAsFixed(0)}% ($count)'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: (percentage / 100).clamp(0, 1)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_poll['channelName'] ?? _poll['creatorChannelName'] ?? 'Creator'}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_poll['question'] ?? _poll['title'] ?? 'Bình chọn'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (_loadingDetails && _options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_options.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Bình chọn chưa có lựa chọn.'),
            )
          else
            ..._options.map(
              (option) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: option['optionId']?.toString() ?? '',
                groupValue: _selectedOptionId,
                title: Text('${option['text'] ?? ''}'),
                onChanged: _isOpen && !_loading
                    ? (value) {
                        if (value != null) _vote(value);
                      }
                    : null,
              ),
            ),
          if (_options.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadingResults ? null : _toggleResults,
                    icon: _loadingResults
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bar_chart_outlined),
                    label: Text(_showResults ? 'Ẩn kết quả' : 'Xem kết quả'),
                  ),
                  if (_selectedOptionId != null)
                    TextButton.icon(
                      onPressed: _loading ? null : _withdrawVote,
                      icon: const Icon(Icons.undo),
                      label: const Text('Rút bình chọn'),
                    ),
                ],
              ),
            ),
          if (_showResults) _buildResults(),
          if (!_isOpen)
            const Text(
              'Bình chọn đã đóng, không thể bình chọn.',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    ),
  );
}

class _PollStateCard extends StatelessWidget {
  const _PollStateCard({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (action != null) action!,
        ],
      ),
    ),
  );
}
