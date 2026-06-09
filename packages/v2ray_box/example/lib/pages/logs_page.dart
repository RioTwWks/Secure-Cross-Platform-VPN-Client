import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v2ray_box/v2ray_box.dart';

class LogsPage extends StatefulWidget {
  final V2rayBox v2rayBox;
  const LogsPage({super.key, required this.v2rayBox});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final List<String> _logs = [];
  StreamSubscription<Map<String, dynamic>>? _logSub;
  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingLogs();
    _startStream();
  }

  Future<void> _loadExistingLogs() async {
    try {
      final logs = await widget.v2rayBox.getLogs();
      if (mounted) {
        setState(() {
          _logs.addAll(logs);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startStream() {
    _logSub = widget.v2rayBox.watchLogs().listen((event) {
      if (event['cleared'] == true && mounted) {
        setState(() => _logs.clear());
        return;
      }
      final msg = event['message'] as String?;
      if (msg != null && mounted) {
        setState(() {
          _logs.add(msg);
          if (_logs.length > 1000) _logs.removeAt(0);
        });
        if (_autoScroll) _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Logs copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearLogs() async {
    setState(() => _logs.clear());
    await widget.v2rayBox.clearLogs();
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _getLogColor(String log) {
    final lower = log.toLowerCase();
    if (lower.contains('error') || lower.contains('fatal'))
      return const Color(0xFFE74C3C);
    if (lower.contains('warn')) return const Color(0xFFFFA502);
    if (lower.contains('debug') || lower.contains('trace')) return Colors.grey;
    if (lower.contains('info')) return const Color(0xFF00D9FF);
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Logs',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _autoScroll
                            ? Icons.vertical_align_bottom
                            : Icons.vertical_align_top,
                        color: _autoScroll
                            ? const Color(0xFF00D9FF)
                            : Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _autoScroll = !_autoScroll),
                      tooltip: _autoScroll
                          ? 'Auto-scroll ON'
                          : 'Auto-scroll OFF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copyLogs,
                      tooltip: 'Copy',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: _clearLogs,
                      tooltip: 'Clear',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No logs yet',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect to a server to see logs',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: _getLogColor(log),
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${_logs.length} entries',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
